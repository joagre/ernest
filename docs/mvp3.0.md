# Ernest: MVP 3.0, Peers

Status: a proposal, to be read back and discussed before anything is planned or built. Section 9 holds what is unsolved.

## 1. What it is

MVP 3.0 lets one program run on several nodes. A *node* is one running runtime, and a *peer* is another node it knows by name. A process on one node spawns a process on a peer, sends to it, calls it, monitors it and kills it, with the operations a program already uses on one node.

Three things bound the milestone:

- **One build.** Every node runs the same compiled program. No code crosses between nodes.
- **No change in place.** A deploy stops every node and starts every node.
- **A few nodes with one owner.** Every node lists its peers by hand, and trusts each of them completely.

## 2. What a program sees

**The operations across nodes.** Each behaves on a process of another node as it does on a local one, with the differences this document states.

| Operation | Across nodes |
|---|---|
| `send(address, value)` | carries the value to the process's node; returns at once and promises nothing |
| `Address.call(address, request, ms)` | waits for the answer; `None` where none came in time, the callee ended or restarted, or its node went out of reach |
| `Address.callForever(address, request)` | waits without a limit; faults where the callee ended or its node went out of reach |
| `answer(reply, value)` | carries the answer to the caller's node |
| `monitor(process, wrap)` | one `Down` when the process ends, or when its node goes out of reach |
| `kill(address)` | kills the process on its node |
| `via(address, f)` | the adapted address may cross; `f` runs on the node that made it |

**What is new.**

- `Peer.spawn(name, f)` starts a process that runs `f` on the peer of that name and returns its address. `Peer.spawnMonitored(name, f, wrap)` monitors it from its start.
- `Peer.find(name, fn() = M.service)` answers the address a top-level binding holds on that peer, or a failure.
- `Reason` gains `Unreachable`: the process's node is out of reach, and the process may live on.

**What may cross.**

| Value | Crosses |
|---|---|
| `Int`, `Float`, `Bool`, `Char`, `String`, `Bytes`, tuples, lists, `Map`, `Set`, a declared type's values | yes |
| an address, a `Process`, a `Reply` | yes |
| an adapted address of a process on the node that made it | yes |
| the function a spawn on a peer starts, with the values it captured | yes |
| any other function, alone or inside a value | no |
| a foreign value | no |
| the address of a socket, a listener or a program the runtime started | no |
| a single value larger than a connection's outgoing queue can hold (section 6, *Messages*) | no |

An operation that would carry a value that may not cross faults the process that makes it, at that operation.

## 3. Examples

A counter runs on a node named `store`.

```ernest-fragment
// counter.ern

export type Msg = Add(Int) | Get(reply : Reply(Int))

export let counter : Address(Msg) =
    spawn(restarting(RestartLimit(restarts = 3, within = 5000), fn() = count(0)))

fn count(total : Int) : Unit with Msg =
    receive {
        Add(amount) -> count(total + amount)
      | Get(reply = reply) -> {
            answer(reply, total);
            count(total)
        }
    }

// The store's entry point. It is in the module that declares `counter`,
// so the counter runs on the node that starts here.
export fn main() : Unit with Never =
    receive {
        after 60000 -> main()
    }
```

**A program that asks once.** It finds the counter, adds to it, asks for the total and ends. It needs no monitor: the call answers `None` where the counter has ended or the store is out of reach.

```ernest-fragment
// desk.ern

export fn main() : Unit with Never =
    match Peer.find("store", fn() = Counter.counter) {
        Left(_) -> Io.println("the store is not there")
      | Right(counter) -> {
            send(counter, Counter.Add(5));
            report(Address.call(counter, fn(reply) = Counter.Get(reply = reply), 1000))
        }
    }

fn report(total : Optional(Int)) : Unit with m =
    match total {
        Some(n) -> Io.println("the counter is at " <> Int.toString(n))
      | None -> Io.println("no answer")
    }
```

**A program that stays.** It shows the total every second for as long as it runs. It keeps the counter's address, so it monitors the counter, and when the store goes out of reach it finds the counter again.

```ernest-fragment
// board.ern

type Msg = Tick | Lost(Down)

export fn main() : Unit with Msg = {
    Clock.alarm(1000, fn(_) = Tick);
    seek()
}

// Finds the counter and shows it. A store out of reach is tried again, and
// the runtime paces the tries. Any other failure will not mend by itself.
fn seek() : Unit with Msg =
    match Peer.find("store", fn() = Counter.counter) {
        Right(counter) -> {
            monitor(Process.fromAddress(counter), Lost);
            show(counter)
        }
      | Left(Peer.OutOfReach) -> seek()
      | Left(_) -> Io.println("the store has no counter for us")
    }

fn show(counter : Address(Counter.Msg)) : Unit with Msg =
    receive {
        Tick -> {
            match Address.call(counter, fn(reply) = Counter.Get(reply = reply), 1000) {
                Some(total) -> Io.println(Int.toString(total))
              | None -> Unit
            };
            Clock.alarm(1000, fn(_) = Tick);
            show(counter)
        }
      | Lost(Down(reason = Unreachable)) -> seek()
      | Lost(_) -> Io.println("the counter has ended")
    }
```

`Peer.OutOfReach` is a working name: what `Peer.find`'s failures are called is unsolved (section 9).

Each node has a configuration directory, made once with `ern config --config-dir dir`: the file `ernest.conf` and the node's private key. The desk's `ernest.conf` names the store, and the store's names the desk in the same way:

```json
{
  "network-address": "192.0.2.10:8654",
  "public-key": "<the desk's public key>",
  "peers": [
    {
      "name": "store",
      "network-address": "192.0.2.20:8654",
      "public-key": "<the store's public key>"
    }
  ]
}
```

The same compiled files are on all three machines, and each node is started with its directory:

```
ern run --config-dir /etc/ernest/store counter.erc
ern run --config-dir /etc/ernest/desk desk.erc
ern run --config-dir /etc/ernest/board board.erc
```

The desk prints `the counter is at 5` and ends. The board prints the total every second.

Where the cable to the store is then pulled, each node finds the silence within 45 to 75 seconds. Until then the board's calls answer `None`, each after its second. Then its monitor gives `Lost` with `Unreachable`, and it looks for the counter again, try after try, until the cable is back. The counter runs on untouched all the while, and still holds its total.

The desk's program and the board's name `Counter.counter`, to say which binding they want of the store. By the rule of section 6, *Bindings*, each of their nodes then starts a counter of its own as well, which nothing uses. Section 9 holds this as unsolved.

## 4. What holds

1. **Order.** What one process sends another arrives in the order it was sent, whichever addresses it was sent through.
2. **No gap.** Between nodes a message is never dropped alone. Where one is dropped, the connection is lost, and nothing sent after it arrives through an address held before the loss.
3. **At most once.** A message arrives once or not at all. The runtime sends nothing a second time.
4. **One `Down` for each monitor.** A monitor gives exactly one `Down`: the process's own end, told by its node, or `Unreachable`, made by the watcher's node when the process's node goes out of reach.
5. **Every call ends.** By its answer, by its time running out, by the callee's end or restart, or by the callee's node going out of reach.
6. **Both nodes learn of a loss.** When two nodes lose each other, each ends what it held with the other: at once where the connection is closed, and within 45 to 75 seconds where it only falls silent.
7. **What was held stays dead.** An address, a `Reply` or a monitor that crossed a connection is dead once that connection is lost, and stays dead when the two nodes connect again.
8. **A node's own processes are untouched.** A loss ends conversations with the peer and nothing else: no local process dies of it.

## 5. What does not hold

1. **`Unreachable` is not death.** A watcher that replaces a process it was told is out of reach can have two. What must exist once lives on one named node, and is unavailable while that node is out of reach.
2. **A call that ended without an answer may have run.** `None` says that no answer came. A request that may be sent again is written so that running twice does no harm.
3. **A spawn that failed may have started its process.** Where the connection is lost while the spawner waits, the spawner is told only that the peer is out of reach.
4. **A full queue ends everything with that peer.** Where more waits to be sent to a peer than the queue's limit, the connection is torn down, and every conversation with that peer ends, the innocent among them.
5. **One large value delays the rest.** Two nodes share one connection, and a frame crosses whole. A slow function of an adapted address delays what that peer sends in the same way.
6. **A program that waits on itself across nodes hangs.** A node with peers declares no deadlock, since work can always reach it from outside.
7. **A silent failure takes 45 to 75 seconds to find.** A program that must know sooner puts a time on its calls.
8. **A `send` to a node out of reach vanishes.** So does one to a node the sender's configuration does not list. A monitor or a call on the same address shows it.
9. **A peer is trusted completely.** Any node in the configuration may start any function of the program on this node, with any values. A faulty peer can send a value of the wrong type that is caught only where the receiving process meets it.
10. **Nothing is upgraded while it runs.** Two nodes whose builds differ by one line refuse each other, and so do two with different versions of `ern` or of OTP.

## 6. How it works

**Nodes.** A node's identity is the SHA-256 hash of its TLS public key. A peer's name is one node's own word for it, and its identity is the same everywhere. Each start of a node draws a random number, its *incarnation*, so that an address of an earlier start is dead. A node has a configuration only where `--config-dir` names one: there is no default directory, and a program started without one is no node, has no peers and listens to nothing. As it starts, a node refuses a directory others can write and a key others can read. A node with a configuration listens at its network address from its start.

**Connections.** Two nodes have at most one connection, opened by the first operation that needs it, over mutual TLS 1.3. Where both dial at once, the connection that the node with the lower identity opened is kept. Each side accepts only a key its configuration lists. Connections are not transitive: that A knows B and B knows C connects A and C in no way. After TLS each side sends a *hello*: its identity, its incarnation, the protocol's version, a hash of the build, and the versions of `ern` and of OTP. Where any of the last four differs, the connection is refused, and the refusal says which.

**Frames.** What crosses is a sequence of frames, each whole, in order.

| Frame | Purpose |
|---|---|
| spawn | start a process from a function and the values it captured |
| spawned | the answer: the new process's address, or why it did not start |
| message | a value for an address |
| answer | a value for a waiting call |
| monitor | set a monitor, or the watch a call keeps on its callee |
| demonitor | remove one |
| down | a monitored process ended; or a watched call ended without an answer |
| kill | kill a process |
| heartbeat | sent when nothing else has been for a quarter of the timeout |

**A loss.** A connection is lost when the network breaks it, when its outgoing queue is full, when a frame is faulty, when the detector finds it silent, or when the peer dials again over it. Each node runs the loss for itself, and no frame announces it. The node delivers a `Down` with `Unreachable` and an empty `site` for each monitor it held on the peer's processes, ends the calls waiting on them, drops what was queued, and drops what the peer's processes were watching on this node.

**The detector.** A sign of life is bytes arriving. A timer fires every 15 seconds, and four firings in a row without progress are a loss. Without progress means that no bytes arrived, or that bytes wait to be sent and none left, or that deliveries wait and none was made. The firings are counted and not the time gone, so a node that was itself stalled does not lose every peer as it wakes.

**Connecting again.** A connection is opened again only when an operation needs it, never in the background. Before a dial the node waits a random time below a delay that doubles from 100 ms to 30 s. The delay grows after a dial that fails and after a connection that was lost young, and starts over once a connection has lived 60 seconds. An operation that comes meanwhile waits for the dial. A dial that arrives over an established connection is that connection's loss, run before the new one carries anything.

**Addresses.** An address on the wire is the node's identity, its incarnation, a random 128-bit number that names the process, and a hash of the process's mailbox type. A node draws the numbers of its own processes and of no other's. The receiving node checks the hash against the process's mailbox type, and a mismatch is a faulty frame. Each node numbers its connections with each peer, for itself, and holds a remote address together with the number of the connection it arrived over. An address is good for that connection alone: once it is lost, a `send`, an `answer` or a `kill` through the address does nothing, and a call ends at once. The same process may be reached again through an address that arrives later, from `Peer.find`, from a spawn, or in a new message. A `Process` holds no such number, so `monitor` may be called again on the process a `Down` names. Where that process's node is still out of reach, the new monitor gives its `Down` with `Unreachable` once the dial has failed, and at once where the node is not listed.

**Messages.** `send` hands the value to the connection and returns. What waits to be sent to a peer waits in that connection's outgoing queue, which has a limit in bytes. A value that is larger than the limit by itself can never be sent, and the operation that would send it faults. Where the queue is full of values that each fit, the connection is lost (section 5, point 4). A value sent to an adapted address is carried, unconverted, to the node that made the address, where the connection applies the function in the order the frames arrived. A fault in that function is the fault of the process the address leads to.

**Calls.** A `Reply` crosses as the caller's node and a number private to the call. The callee's node watches the call as it watches a local one, and tells the caller's node when the call ends other than by an answer: the callee ended, or it restarted. A call to another node costs four frames where a `send` costs one.

**Serialization.** A value crosses in the host's external term format. A constructor is the atom of its name, and no hash stands inside a value: its type is known at both ends, and the address carries the type's hash once. An atom is the host's constant for a name. The host keeps every atom ever made, in a table with room for about a million, so data that made new atoms could fill the table and bring a node down. The receiving node therefore reads the value with the host's safe decoding, which creates no atom. A type's description at run time names every constructor it has, so every atom of a well-typed value exists before the value is read, and an atom the node lacks is a faulty frame. The value is not checked further.

**A spawn.** `Peer.spawn(name, f)` sends `f` as a reference to its code, its module and its place there, with the values it captured. The same build has the same modules, so the reference means the same on both nodes. The peer starts the process, draws its number, and answers with its address. The spawner waits with no clock of its own: the wait ends when the peer answers, when the dial fails, or when the connection is lost. A name that is no peer's, and a peer out of reach, fault the spawner.

**Bindings.** A node runs, at its start, the top-level bindings of the standard library and of the modules its own entry point depends on, as a program on one node does. A function spawned on it runs only where the bindings that function depends on have their values there. Otherwise the spawn faults its spawner, and `Peer.find` answers a failure. Nothing is initialized because a peer asked. In spawned code a top-level binding is the peer's, and a captured value is the spawner's.

**Other nodes' processes and resources.** `Process.info` answers for the running node's processes alone, and `None` for a process of another node. A supervisor's children run on its own node.

## 7. The numbers

| What | Value |
|---|---|
| a node's identity | SHA-256 of its TLS public key |
| incarnation | 64 bits, random at each start |
| a process's number in an address | 128 bits, random |
| the detector's timer | every 15 s |
| a silence is found in | 45 to 75 s |
| the delay before a dial | random below a delay doubling from 100 ms to 30 s |
| the delay starts over | after a connection has lived 60 s |
| one dial may take | 5 s |
| the outgoing queue's limit | unsolved (section 9) |

All are constants of the protocol. None is set in `ernest.conf`.

## 8. How it is checked

The protocol is written as a state machine and nothing beside it: one function from a connection's state and an event, a frame, a timer, a close or a dial's result, to the new state and what to do. Sockets, timers and processes are at its edge.

A checker runs those machines themselves, two nodes and then three, over a network it plays: every order of events up to a bound, and long runs drawn from a seed that a failure prints and that runs again. It holds the first seven claims of section 4, which are the protocol's own. A few tests over real sockets cover what the played network leaves out: TLS, the socket's counts, and how a close is seen.

## 9. Unsolved

1. **Whether to stand on Erlang's own distribution.** The proposal builds node-to-node messaging in Erlang code over TLS. Ernest otherwise stands on the host wherever the host does the work, and the host's distribution is built into its runtime. What is gained and what it costs has not been weighed.
2. **A client that names a service starts it.** `Peer.find("store", fn() = Counter.counter)` makes the desk's program depend on the module `Counter`, so the desk's node runs that module's bindings and starts a counter of its own. For a service that owns a port or a file that is wrong.
3. **A spawn that cannot reach its peer faults.** `Peer.find` answers a failure as a value, and `Peer.spawn` kills its caller for the same condition, the network. Whether a spawn should answer a value, and take a time as other waits on a peer do, is to be weighed afresh.
4. **`Peer`'s exact shape.** The types of its functions and the names of `Peer.find`'s failures. How a program learns which nodes there are and places work by load is not weighed here.
5. **What the build's hash covers,** where two nodes are started from different entry points of one program.
6. **Adding a peer.** The configuration is read at a node's start. Whether a peer can be added or removed without stopping the others is not answered.
7. **A second hello from the same key.** A peer that restarted, and a second node started by mistake with the first one's key, look the same.
8. **The outgoing queue's limit.** Its value, and how it is measured.
9. **The texts of the new faults:** a peer out of reach, a value too large to cross, a resource's address that cannot cross, a function whose bindings have no values on the peer.
10. **The mailbox type's description.** How a process carries it at run time, and what exactly its hash is taken over.
11. **The detector's sending side.** Whether the host's TLS sockets show that bytes wait and do not leave has not been checked.
12. **A network address.** A name or a number, and what the listener binds to.
13. **Testing a program of two nodes** on one machine, and with `ern test`.
14. **The shell on a node.**
15. **Costs not measured:** a `send` across nodes beside the host's own, a call's four frames, everything between two nodes passing through one process, TLS, the safe decoding, and memory for each connection and each held address.
16. **What other systems teach.** How Akka, Orleans, Erlang's ecosystem, Swift's distributed actors, Unison and the capability systems treat the same questions is in [`other_systems.md`](other_systems.md), and nothing of it is in this proposal yet.

## 10. Left out on purpose

- Code that crosses between nodes, and a change of code while a program runs.
- Discovery of nodes, and a registry of names.
- A message carried through a third node.
- A cluster's membership, an election, a lease: what must exist once is the program's or a library's.
- A second attempt by the runtime at anything.
- A limit on the sender in place of a torn connection, and a way to read how much waits.
- A wire format of Ernest's own, and a large value sent in pieces.
- A detector that adapts its patience.
- Rights for each peer beyond being listed.

## 11. Room for what comes after

MVP 3.1 gives every definition a hash and lets code cross with a spawn, so that nodes of different builds work together. After it comes a change of code, and of a protocol, in a process that keeps running. MVP 3.0 is to leave room for both, as far as can be seen from here. Four rules do most of it.

1. **Refuse now what may be allowed later, and allow nothing that must later be refused.** A function inside a message would be harmless among nodes of one build, and is refused, since it cannot be allowed once code crosses. A function whose bindings a node did not run is refused, where a later milestone may run them. Two builds that differ refuse each other, where a later milestone lets them meet. A refusal that becomes an answer breaks no program.

2. **Settle now what a program writes.** A program writes the types of `Peer`'s functions and matches on the constructors of `Reason` and of `Peer.find`'s failure. A change to any of them breaks programs, where a change beneath them does not. So unsolved points 3 and 4 are settled with the later milestones in view: `Peer.find`'s failure, for one, has room for a service that is at another version.

3. **Keep closed what will change beneath.** The protocol never looks inside a function's reference, which is a place in a module now and a hash later. It compares a type's hash and never asks how the hash was made. It allows that a process comes to accept more than one type's hash, as a process that has changed its protocol will. It speaks of the connection between two nodes and not of a socket, so that a second stream, for code, can join it. And it asks a table for a peer's address and key, and not a file, so that a table filled another way can replace it.

4. **The wire is not kept.** A hello whose protocol version differs is refused, and MVP 3.1 is a new version: every node changes over at once. Nothing in MVP 3.0 promises that a node of one milestone talks to a node of the next.

**Where new code comes in.** MVP 3.0 loads no new code: a new version is a stop of every node. Loading new code is four steps, of which MVP 3.0 is the first.

| Step | What it gives | Where |
|---|---|---|
| A | one build on every node, and a deploy that stops them all | MVP 3.0 |
| B | nodes of different builds connect; a message is accepted by its type's hash, and a spawned function only where the peer has its module, and all that module depends on, unchanged; no code crosses | a step after MVP 3.0, to be weighed |
| C | a hash for each definition; code crosses with a spawn; two versions stand side by side on a node | MVP 3.1 |
| D | a running process takes new code, and later a new protocol | after MVP 3.1 |

Step B parts two rules that step A holds as one: that no code crosses, and that every node is the same build. The second is what makes every deploy a stop of all nodes at once. Without it, nodes are restarted one at a time wherever a change does not touch what they exchange, and unsolved point 5 falls away, there being no hash of a whole build. A changed module that spawns or finds on a node still holding the old one fails until that node has it too, so a real upgrade waits for step C. Step B only relaxes step A, by rule 1, and can follow MVP 3.0 without breaking a program. Replacing a module under running processes, as Erlang's `code` module does, is none of these steps: it changes code with nothing to check its types against.

Three places carry the most risk, since a later milestone may find them wrong. How a service is named and found: `Peer.find` reads a binding by its name in one build, and across builds a name alone does not say which service is meant (unsolved point 2 is its first sign). The sum types a program matches on, where a constructor added later breaks every `match` that lists them all. And whatever one build on every node lets a program assume without saying, which MVP 3.1 then has to keep true or break.
