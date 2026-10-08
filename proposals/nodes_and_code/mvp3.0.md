# Ernest: MVP 3.0, Peers

Status: the proposal for MVP 3.0, peers, settled on 2026-10-07 after a read-back against its four rules; it changes only by a question raised against it. Changed on 2026-10-07 by [`mvp3.2.md`](mvp3.2.md), whose reasons are [`deploy.md`](deploy.md)'s: a key's peers in `ernest.conf` and a find by the key alone, and the limit that a `send` waits for a dial; `Peer.standing`, added the same day, was withdrawn on 2026-10-08 for a library of MVP 3.2's. MVP 3.2 changes two more things, which it states and this document keeps as they are until it is built: termination becomes the planned stop, four steps before the end, and an offer is withdrawn at that stop. Section 9 holds what is unsolved. The reasons for what it says are in [`nodes.md`](nodes.md).

## 1. What it is

MVP 3.0 lets one program run on several nodes. A *node* is one running runtime, and a *peer* is another node it knows by name. A process on one node spawns a process on a peer, sends to it, calls it, monitors it and kills it, with the operations a program already uses on one node.

Three things bound the milestone:

- **One build.** Every node carries the same compiled program, whole, and runs one entry point of it. No code crosses between nodes.
- **No change in place.** A deploy stops every node and starts every node.
- **A few nodes with one owner.** Every node lists its peers by hand, and trusts each of them completely.

**What rules the design.** Four things decide every sentence that follows, and MVP 3.1's as well.

Erlang's process semantics, taken whole. A process is isolated and owns its state. A message is asynchronous, arrives at most once, and in order for each sender and receiver. A process learns of another's end through a monitor, once. A loss is a connection's, and both sides learn of it. The runtime sends nothing twice and waits for nothing on the program's behalf, except that a plain `send` waits where the network itself is behind; an operation with a time keeps its time.

Nothing invisible, and the program decides. What the network does is a value the program matches on; a fault is the program's own mistake, on a peer as on one node. No identity moves, no cluster votes, nothing is retried, and a policy, finding a service again, placing work, is a library's. The runtime says what is true and does nothing more. A process changes its code only by its own act.

A protocol is a type. The mailbox's type is the contract between two processes, wherever they are: an address carries it, a key carries it, a service is found by it, and a version of a service is a type with another identity.

What crosses is identified, never named. A node is its key, a process is its address, a protocol is its type's identity, and code, when it crosses, is its hash. A name is one node's own word, the alias in its configuration or a binding's name, and moves without changing what it named. Three names cross all the same: a key's, which is the program's word and is checked by the type's identity; in MVP 3.0 a function's module and place, which the one build makes mean the same everywhere and which MVP 3.1 replaces by a hash; and a foreign declaration's qualified name with its type, since what it names is the host's and has no hash.

These are Erlang's rules with identity made explicit and typed. Where this document departs from Erlang, a typed address, a failure answered as a value, a peer refused unless listed, the departure comes from the second and third of the four.

**The building block.** An *address* names one process for as long as that process lives, on whichever node it is. A *connection* carries what two nodes send each other, for as long as it lasts. A *loss* of the connection ends what was in flight and nothing else: what waited to be sent is dropped, each monitor gets its one `Down`, and each waiting call ends. The address is as good as before, and when the two nodes connect again it reaches its process again. What carries all of it is Erlang's own distribution, with what hurts in it turned off and Ernest's types put on it (section 6).

## 2. What a program sees

**The operations across nodes.** Each behaves on a process of another node as it does on a local one, with the differences this document states.

| Operation | Across nodes |
|---|---|
| `send(address, value)` | carries the value to the process's node, over a connection it asks for where there is none; returns at once while the network keeps up, and promises nothing |
| `Address.call(address, request, ms)` | waits for the answer; `None` where none came in time, the callee ended or restarted, or its node went out of reach |
| `Address.callForever(address, request)` | waits without a limit; faults where the callee ended or its node went out of reach |
| `answer(reply, value)` | carries the answer to the caller's node; never waits |
| `monitor(process, wrap)` | one `Down` when the process ends, or when its node goes out of reach; its `site` is the spawn's, which crosses in the `Down`, and empty in `Unreachable` |
| `kill(address)` | kills the process on its node |
| `via(address, f)` | the adapted address may cross; `f` runs on the node that made it |

**What is new.** The module `Peer`, one constructor of `Reason`, and three commands, `ern config`, `ern reload` and `ern stop`.

```
type Peer.Key(m)
type Peer.Failure = NotListed | Unreachable | Refused(String) | Timeout
                  | NotOffered | OtherType | NotLoaded

Peer.key            : (String) -> Peer.Key(m)
Peer.offer          : (Peer.Key(m), Address(m)) -> Unit with n
Peer.find           : (Peer.Key(m), Int) -> Either(Peer.Failure, Address(m)) with n
Peer.spawn          : (String, () -> Unit with m, Int) -> Either(Peer.Failure, Address(m)) with n
Peer.spawnMonitored : (String, () -> Unit with m, (Down) -> n, Int)
                        -> Either(Peer.Failure, Address(m)) with n
Peer.nodes          : () -> List(String) with n
```

- A *key* names a service to a node's peers and carries the service's message type: `Peer.key("counter")`, bound at the type `Peer.Key(Msg)`. It is a value, and starts nothing.
- `Peer.offer(key, address)` lets this node's peers find `address` under the key.
- `Peer.find(key, ms)` asks the peers `ernest.conf` lists as the key's, in order, and answers the first address offered under the key, typed by the key. Where a service lives is the configuration's, never the program's: a key with no entry answers `NotListed`, and a service on one node is an entry of one peer.
- `Peer.spawn(name, f, ms)` starts a process that runs `f` on the peer of that name and answers its address. `Peer.spawnMonitored(name, f, wrap, ms)` monitors it from its start.
- A find and a spawn wait at most `ms` milliseconds, from the operation itself, and answer the address or a failure, which the program matches on. Neither faults for what the network or the peer does.
- `Peer.nodes()` answers the names of the peers this node lists, in the configuration's order, but those marked `coordinator`, which run no program (`mvp3.2.md`). The running node is no peer of itself.
- `Reason` gains `Unreachable`: the process's node is out of reach, and the process may live on.
- `ern reload --config-dir dir` makes the node started with that directory read its `ernest.conf` again, and `ern stop --config-dir dir` ends it in order.

The failures, in the order a request meets them. One type serves a find and a spawn, since §4.2 lets no two types of one module share a constructor: a find answers `NotListed`, `Unreachable`, `Timeout`, `NotOffered` and `OtherType`, a spawn `NotListed`, `Unreachable`, `Timeout`, `Refused` and `NotLoaded`, and a program writes `_` for what its operation cannot meet, the one cost of the one type.

| Failure | Says |
|---|---|
| `NotListed` | the key's name has no peers in this node's configuration, or the name is no peer's |
| `Unreachable` | no connection could be opened, or it was lost while waiting |
| `Refused(text)` | the peer refused what was sent, a closure it could not load (MVP 3.1); a connection the peer's handshake refused is `Unreachable`, since the host tells the dialer nothing of the reason |
| `Timeout` | no answer came in time |
| `NotOffered` | the peer offers nothing under the key's name |
| `OtherType` | what it offers has another message type |
| `NotLoaded` | the function's bindings have no values on the peer |

**What may cross.** A type is *bound* to its node where it holds a function type, a foreign type, a resource, or an `Address(m)` or `Reply(m)` whose `m` is bound; a resource is `Ets.Table` or the address of a socket, a listener or a program the runtime started. Every other type crosses: `Int`, `Float`, `Bool`, `Char`, `String`, `Bytes`, tuples, lists, `Map`, `Set`, a declared type's values, an address, a `Process` and a `Reply` of an unbound type, and an adapted address of a process on the node that made it.

A value of a bound type never crosses. The compiler refuses the three operations that would start one on its way: a `Peer.key` of a bound type; a `Peer.spawn` or `Peer.spawnMonitored` whose function captured a value of a bound type; and a `Peer.spawn` or `Peer.spawnMonitored` whose function's mailbox type is bound, since the spawner would hold a remote address of that type. A spawn whose captured values have a type variable in their type is refused as well. No other operation is checked: an adapted address crosses with the values its function captured as payload, touched only on the node that made it, where the function runs (section 6), so nothing is checked and nothing looked through.

## 3. Examples

A counter runs on a node named `store`. Three modules share one more, which holds what a client needs to reach the counter and starts nothing.

```ernest-fragment
// counter.ern, what the store and its clients share

export type Msg = Add(Int) | Get(reply : Reply(Int))

export let key : Peer.Key(Msg) = Peer.key("counter")
```

```ernest-fragment
// store.ern

let counter : Address(Counter.Msg) =
    spawn(restarting(RestartLimit(restarts = 3, within = 5000), fn() = count(0)))

fn count(total : Int) : Unit with Counter.Msg =
    receive {
        Counter.Add(amount) -> count(total + amount)
      | Counter.Get(reply = reply) -> {
            answer(reply, total);
            count(total)
        }
    }

export fn main() : Unit with Never = {
    Peer.offer(Counter.key, counter);
    wait()
}

fn wait() : Unit with Never =
    receive {
        after 60000 -> wait()
    }
```

**A program that asks once.** It finds the counter, adds to it, asks for the total and ends. It needs no monitor: the call answers `None` where the counter has ended or the store is out of reach.

```ernest-fragment
// desk.ern

export fn main() : Unit with Never =
    match Peer.find(Counter.key, 5000) {
        Left(Peer.Timeout) -> Io.println("the store did not answer")
      | Left(_) -> Io.println("the store is not there")
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

**A program that stays.** It shows the total every second for as long as it runs. It finds the counter once and keeps its address.

```ernest-fragment
// board.ern

type Msg = Tick

export fn main() : Unit with Msg =
    match Peer.find(Counter.key, 5000) {
        Left(_) -> Io.println("the store is not there")
      | Right(counter) -> {
            Clock.alarm(1000, fn(_) = Tick);
            show(counter)
        }
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
    }
```

Each node has a configuration directory, made once with `ern config --config-dir dir`: the file `ernest.conf` and the node's private key. The desk's `ernest.conf` names the store, says that the counter is found there, and the store's names the desk in the same way, with no `keys`:

```json
{
  "listen": "0.0.0.0:8654",
  "public-key": "<the desk's public key>",
  "peers": [
    {
      "name": "store",
      "network-address": "store.example:8654",
      "public-key": "<the store's public key>"
    }
  ],
  "keys": { "counter": ["store"] }
}
```

The same compiled files are on all three machines, and each node is started with its directory:

```
ern run --config-dir /etc/ernest/store store.erc
ern run --config-dir /etc/ernest/desk desk.erc
ern run --config-dir /etc/ernest/board board.erc
```

The desk prints `the counter is at 5` and ends. The board prints the total every second.

A fourth machine is added by listing it in the others' `ernest.conf` and running `ern reload --config-dir /etc/ernest/store` on each, with the store and the board running on.

Where the cable to the store is pulled, each node finds the silence within 45 to 75 seconds. While the store is out of reach the board's calls answer `None`, and the board prints nothing. When the cable is back, the next call opens a connection and the totals appear again. The board holds the same address throughout and has written nothing for the loss. The counter runs on untouched all the while, and still holds its total.

Where the store's node is stopped and started, its counter is a new process, which the store offers again under the same key. The address the board holds names the one that is gone: its calls answer `None` from then on. A program that is to outlive that monitors the counter, and finds it again by the key when it is told that the counter has ended; a library can do that for it (section 10).

## 4. What holds

1. **Order.** What one process sends another arrives in the order it was sent, whichever addresses it was sent through, but one: a message to an adapted address made on the receiver's node takes one step more there, and a message sent straight after it can pass it.
2. **No gap while a connection lasts.** Between nodes a message is never dropped alone. Where one is dropped, the connection is lost, with everything that waited to be sent.
3. **At most once.** A message arrives once or not at all. The runtime sends nothing a second time.
4. **One `Down` for each monitor.** A monitor gives exactly one `Down`: the process's own end, told by its node, or `Unreachable`, made by the watcher's node when the process's node goes out of reach.
5. **Every call ends.** By its answer, by its time running out, by the callee's end or restart, or by the callee's node going out of reach. A find and a spawn end the same way.
6. **Both nodes learn of a loss.** When two nodes lose each other, each ends what it held with the other: at once where the connection is closed, and within 45 to 75 seconds where it only falls silent.
7. **An address outlives a loss.** When two nodes connect again, an address reaches the process it reached before, for as long as that process lives and its node has not been started again. A monitor and a waiting call do not outlive a loss: it ends them.
8. **A node's own processes are untouched.** A loss ends conversations with the peer and nothing else: no local process dies of it, but one waiting in `Address.callForever` on a process of the peer, which faults as it does when its callee ends.

## 5. What does not hold

1. **`Unreachable` is not death.** A watcher that replaces a process it was told is out of reach can have two. What must exist once lives on one node, and is unavailable while that node is out of reach.
2. **A call that ended without an answer may have run.** `None` says that no answer came, and nothing of why, or of whether the request ran; it is the same where the request was never sent. A request that may be sent again is written so that running twice does no harm. A program that wants to know why monitors the callee.
3. **A spawn that failed may have started its process.** Where the spawn's time runs out, or the connection is lost while the spawner waits, the spawner is told only that. Where the connection lasts, the process is ended as soon as its answer arrives; where it was lost, the process runs on, and no one holds its address.
4. **A sender to a stalled peer waits.** Where more waits to be sent to a peer than the host's buffer holds, a plain `send` to that peer waits until it drains, at the latest until the detector gives the peer up. A plain `send` to a peer with no connection open returns at once and its message waits behind the dial, up to the 7 seconds the host gives one that nothing answers, and is dropped where the dial fails; the sender waits only where what waits exceeds the buffer. A process that waits in a send serves nothing from its mailbox meanwhile. A call, a find, a spawn and an `answer` are held the same way. A service that pushes to many remote clients does it through a process for each.
5. **One large value delays what its sender sends after it.** Two nodes share one connection. A large value crosses in pieces, and other senders' messages pass between them. The function of an adapted address must finish, across nodes as on one: a slow one delays what that peer sends through the gateway, its spawns, its finds and its messages to adapted addresses, and one that never finishes holds them for good. A plain message passes the gateway by.
6. **A program that waits on itself across nodes hangs.** A node with peers declares no deadlock: `--config-dir` tells the detector that a monitor on a peer's process is no source of one, and the host's lost connection is `Unreachable` to it, never a fault.
7. **A silent failure takes 45 to 75 seconds to find.** A program that must know sooner puts a time on its calls.
8. **A `send` or a `kill` to a node out of reach vanishes.** So does one to a node the sender's configuration does not list. A monitor or a call on the same address shows it.
9. **A peer is trusted completely.** Any node in the configuration may do on this node whatever the host lets a connected node do: start, end and call anything. Ernest's checks hold against a peer's mistakes, and not against a peer that means harm. A faulty peer can send a value of the wrong type, caught only where the receiving process meets it, and names this node has never had, each kept as an atom for as long as the node runs.
10. **A loss can leave a hole.** What one process sent another while their nodes were out of reach of each other is gone, and what it sends after they connect again arrives. A protocol that must have none numbers its messages, or calls.
11. **Nothing is upgraded while it runs.** Two nodes whose builds differ by one line of code refuse each other, and so do two with different versions of `ern` or of OTP.
12. **Whoever holds an address can kill its process.** An address is the permission to send and to kill, across nodes as on one, and a node offers a service to all its peers alike. A service that is to outlive a mistaken `kill` is supervised on its own node, and its new process is offered under the same key.
13. **A node that cannot be dialled is reached only while it holds a connection open.** The node that can dial opens the connection, and both send over it. After a loss the other node cannot open it again: what it sends vanishes, and its monitors say `Unreachable`, until the first node next acts towards it. So the node that can dial monitors a process of the other, and where it is told `Unreachable` it tries again, after a time it chooses.
14. **Two nodes with one key are one node to their peers.** A configuration directory copied to a second machine gives two nodes one name, and each one's dial ends the other's connection: what is sent to the one not connected is dropped, and a monitor on its processes says `Unreachable`. The peer says so each time, on its standard error. Nothing prevents it.
15. **A find spends its time in the order of the list.** Each of a key's peers is given the time left, and a silent peer early in the list can take the whole of it before the next is asked.
16. **An adapted address is as large as what its function captured**, and carries it on every crossing.

## 6. How it works

**The carrier.** Nodes talk over Erlang's own distribution: its connections, its handshake, its heartbeat, its order, and its monitors across nodes. Ernest turns off what hurts in it, as the paragraphs below say, and puts three things of its own on it: a rule for which nodes connect, the start of a process on a peer, and a service found by its key. A program never sees the carrier.

**A node.** A node's identity is its TLS public key, and its name on the carrier is the key's SHA-256 digest with a constant after it: the same on every node, and holding no network address. A program never sees it; a peer's name in a program is the name this node's `ernest.conf` lists the peer under. `ern config --config-dir dir` makes the node's key, a certificate the node signs itself, whose name is a constant and whose validity is the longest the format allows, and `ernest.conf`; it prints the public key, which is what another node's configuration lists. A configuration directory is made for one machine and never copied. A node has a configuration only where `--config-dir` names one: a program started without one is no node, has no peers and listens to nothing. As it starts, a node refuses a directory others can write and a key others can read.

**Its configuration.** `ernest.conf` holds the node's `listen`, its public key, its peers, its `keys` and its `measures`. `listen` is what the node's listener binds to, an address of one interface, or `0.0.0.0` or `::` for all of them, and a port, or port 0, at which the host picks one and the node says on its standard error which it bound; a node without one does not listen, and only dials. A peer has a name, a public key and a `network-address`, `host:port`, the host a name or an address, an IPv6 one in brackets; a name is resolved by the host at each dial. A peer may be listed without an address, and is then never dialled: it is out of reach until it opens a connection itself. A node runs over one family of addresses, IPv4 or IPv6, the listener's, or IPv4 where there is none; a peer whose address is of the other family, or whose name resolves only to it, is refused when the configuration is read, with an error that names the peer. `keys` lists, for a key's name, the peers that may offer it, by their aliases, in the order a find asks them; a key not listed is found nowhere. `measures` names which of the host's measures run on the node, `cpu`, `memory` and `disk`, each with the host's parameters under it by their meaning, `check-interval`, `almost-full`; none runs where the section is absent. The host's own names for the services stay out of the file; the library `Load`'s page gives them.

**Its start and its end.** Each start of a node has a number of its own, which the host draws and puts in every address, so that an address of an earlier start is dead. A node runs, at its start, the top-level bindings of the standard library and of the modules its entry point depends on, as a program on one node does, and listens only once they all have their values. An initializer that faults ends the node, as it ends a program. A node writes its process number to `ernest.pid` in its directory at its start and removes it at its exit; a node that starts and finds the file naming a living process refuses to start, saying so, and overwrites a file left by one that died. A node ends when its program ends, or by termination, which `ern stop --config-dir dir` sends by `ernest.pid` and `kill -TERM` sends as well; MVP 3.2 puts its planned stop before that end (`mvp3.2.md`). A node that ends is no loss to its peers: its processes die with `ProgramEnd`, and the node stops the way the host stops a node, in order, so that every `Down` already on its way crosses before the connection closes. A peer's monitor on one of its processes gives `ProgramEnd`; only a monitor made after that gives `Unreachable`.

**What it says.** The host's own reports of its nodes are turned off. A node says on its standard error, one line each, that a peer connected; that a peer was lost, and whether it fell silent or closed; that a peer was refused for its key, by the rule, or for its build, by the cookie, which the host's handshake reports and is the one report of the host's the node keeps; that a living connection was replaced by another from the same name; and what a reload did. Each line names the peer by the alias in `ernest.conf`, and by the key's digest where the peer is not listed. Nothing is said for a message, a call or a spawn.

**A reload.** For a node, hangup is a reload and termination an end, as for any daemon; for a program that is no node, both end it, as the report has it. `ern reload --config-dir dir` sends the node named by `ernest.pid` the signal `SIGHUP`, which `kill -HUP` sends as well, and fails where there is no file or no such process. The node reads `ernest.conf` again and keeps its peers in a table, which the rule that accepts a peer and the dial both read. A peer added is a row, and nothing else happens until an operation dials it or it dials in. A peer removed, or one whose key changed, has its connection ended, both nodes run the loss, and the addresses a program holds of its processes are those of a node not listed. A peer whose address changed keeps an open connection, and the next dial uses the new address. A peer whose name changed under the same key keeps its connection; only the name a program uses changes. A change to `measures` starts or stops the host's services it names. The node's own key and `listen` cannot change while it runs: a file that changes either, or that does not parse, is refused, and the old configuration stays. The node says on its standard error which peers were added and removed, or why the file was refused. The signal carries nothing back: the command's exit status says only that it was delivered.

**Connections.** Two nodes have at most one connection, opened by the first operation that needs it, over TLS 1.3 with a certificate on each side, its key on the curve the experiment proved, prime256v1; whether ed25519 serves in the handshake with the rule is the build's first question. A node accepts a peer whose public key its configuration lists, and no other, by a rule of Ernest's in the TLS handshake. The rule goes by the key alone: the host's check of a certificate's name is turned off, and a certificate's dates mean nothing to it. There is no port-mapper daemon: a node finds a peer's address in its configuration. Connections are not transitive: that A knows B and B knows C connects A and C in no way. Where both dial at once, the host keeps one.

The host's cookie is the build's fingerprint: each node computes it at its start as the digest of the protocol's version, `ern`'s version, OTP's version and the checksum of its build, and the host's handshake proves both sides hold it before anything passes. Two nodes of different builds fail the handshake with nothing sent. The build's checksum covers what runs: every compiled module on the node's load path, in name order, each as its name and the host's own digest of its code, which leaves out documentation, line numbers and attributes. The entry point plays no part, and a node carries the whole build. The standard library is not in it: `ern`'s version stands for it. A find or a spawn whose connection the peer's handshake refused fails with `Unreachable`, since the host tells the dialer nothing of the reason; the refusing side says why on its standard error.

**What passes.** Ernest's own frames are seven, and the host carries the rest as it carries them on one node.

| What | Carried by |
|---|---|
| a message | the host's send, straight into the mailbox |
| a message to an adapted address | a frame of Ernest's, to the gateway of the node that made the address |
| a spawn on a peer, and its answer | a frame of Ernest's each |
| a find, with a key's name and its type's text, and its answer | a frame of Ernest's each |
| that a call waits, and that it gave up | a frame of Ernest's each |
| a monitor, and its `Down` | the host's monitor |
| a `kill` | the host's exit signal |
| the answer to a call | the host's alias, which takes one answer |
| a sign of life | the host's tick |
| that two nodes run one build | the host's handshake, by the cookie |

**The gateway.** A node has one registered process that takes every frame from every peer, its *gateway*, and hands each to a worker for the sender's node; one gateway, so that the frame which opens a connection finds it, where a name made per peer would not exist yet and the host would drop the frame without a word. A plain message does not pass through it: the host puts it in the mailbox, as on one node. Through the gateway goes what needs a process on the receiving node: a spawn, a find, and a message to an adapted address, which is carried, unconverted, to the node that made the address, whose gateway applies the function and hands on the result. A fault in that function is the target's, as §6.5 has it on one node: the process the address names dies of it, and the sender goes on. A frame the gateway cannot read is faulty, and the node ends the connection. A message between nodes costs what the host's send costs; one to an adapted address makes a step more, on the node that made the address.

**A loss.** A connection is lost when the network breaks it, when the detector finds it silent, or when a frame is faulty; in the last case the node ends the connection itself. Each node is told by its own host, watching hidden nodes as well as listening ones, since a node that does not listen is hidden to the host, and no frame announces it. The host gives a `Down` with `Unreachable` and an empty `site` for each monitor held on the peer's processes, and drops what waited to be sent. The calls waiting on those processes end. A node that dials a peer which still believes the old connection alive makes that peer run its loss first.

**The detector.** The host's. Any traffic is a sign of life, and a tick is sent where nothing else was for 15 seconds. A peer from which nothing came in four such intervals is lost, so a silence is found in 45 to 75 seconds. `ern` sets the same time on every node.

**Connecting again.** The host's. A connection is opened again when an operation needs it, never in the background, and with no delay between one attempt and the next. A dial that is refused fails at once. A dial that nothing answers is given up after 7 seconds, and what waited behind it is then dropped.

**Addresses.** An address is the host's own name for a process: the node's name, the number of that node's start, and the process's number there. An address names its process for as long as the process lives, and a loss does not end it: when the two nodes connect again, the same address reaches the same process. Two things end an address. Its process ends. Or its node is started again: what is sent to an address of an earlier start is dropped, a call through it ends at once, and a monitor on its process gives `Unknown`. An address is a value like any other, and is as good on a third node it is sent to as on the node that sent it. A monitor is not kept through a loss: the loss gave its `Down`, and a program that wants to go on watching calls `monitor` again, on the process the `Down` names. Where that process's node is still out of reach, or not listed, the new monitor gives its `Down` with `Unreachable`.

**Messages.** `send` hands the message to the host and returns, and the host puts it in the mailbox on the other node. Where no connection is open the host opens one, and the message waits: it is sent where the connection opens, and dropped where it does not. What waits to be sent to a peer waits in the host's buffer for that peer, and a `send` that finds the buffer full waits until it drains, at the latest until the detector gives the peer up. A large value crosses in pieces, and other senders' messages pass between them.

**Calls.** A `Reply` is the host's alias, which takes one answer and drops any other, as on one node; a second answer from another node crosses the wire before it is dropped, a message's cost. The caller monitors the callee for as long as it waits, so the callee's end and a loss both end the call. The request is sent as a plain send is: where the buffer for the peer is full the caller waits in the send, at most the detector's time (section 5, point 4), and its time bounds the wait for the answer and nothing before it, as §6.6 has it. A find, a spawn and an `answer` send the same way, so that everything one process sends keeps its order (section 4, point 1). Where the callee restarted, its node tells the caller's: a call across nodes sends the callee's node a note that this caller waits on that callee with this reply, and the callee's node keeps the row until the callee answers, which removes it, or restarts or ends, which uses it. A call whose time ran out sends a second note, and the row goes; a loss drops every row of that peer. A call to another node costs five of the host's signals where a `send` costs one.

**Serialization.** A value crosses in the host's external term format, written and read by the host. A message carries nothing of its type: the type is known at both ends and the same at both. A constructor crosses as the text of its name, as a string does, and on arrival the host looks the name up among the atoms the node has. The messages of a correct program make no new atom on the node that receives them. Nothing is looked through before a value is sent, and on arrival the value is not looked into; an adapted address's captured values cross inside it as payload, and are touched only on the node that made it, where its function runs.

**A spawn.** `Peer.spawn(name, f, ms)` sends the peer a frame with `f` as a reference to its code, its module and its place there, the values it captured, and the spawn's site, which the peer records for the process as it records a local spawn's. The peer starts the process and answers with its address. The spawner waits at most `ms` milliseconds, the opening of a connection among them. The wait ends when the peer answers, when no connection can be opened, when the connection is lost, or when the time runs out, with the failures of section 2. A monitored spawn that fails leaves no monitor. A spawn never faults. An answer that comes when the spawner no longer waits, its time having run out or the spawner having ended, makes the node kill the process it names; the node keeps what it needs for that until the answer arrives or the connection is lost.

**A service and its key.** On one node a service is a top-level binding that holds an address, and a process reaches it by the binding's name. A peer cannot name another node's binding, so a service that peers are to reach is offered under a key. A key holds a name and the text of a message type, as the compiler prints it, `Counter.Msg` or `Box(Int)`. The compiler takes the type where `Peer.key` is written, and refuses a key whose message type is not fully known there. `Peer.offer(key, address)` is accepted by the compiler only where the key and the address have one message type. The node keeps the address under the key's name and its type's identity for as long as the process lives; an offer under a key a living process holds faults the caller, `Fault("counter is offered by a living process")`, since two services under one key on one node are a program's error, and a `restarting` loop keeps its address and its offer while a supervisor's new child offers again because the old has ended. Nothing withdraws an offer: it ends with its process, until MVP 3.2's planned stop withdraws a node's offers before it ends (`mvp3.2.md`). Only a process of the offering node may be offered; an offer of any other address faults the caller. `Peer.find(key, ms)` asks the key's peers, in the order `keys` lists them, each given the time left, for what it offers under the key's name, and a peer answers the address where the type's text is the same. The find passes over `Unreachable`, `Refused`, `NotOffered` and `OtherType`, answers the first address, and otherwise the last failure met, or `Timeout` where the time ran out. A find that finds again when the service it found ends is a library's, written in Ernest over `Peer.find` and `monitor` (`mvp3.2.md`). The finder waits at most `ms` milliseconds, as a spawner does, with the failures of section 2. Only what a node offers can be found: its other bindings are closed to its peers. A find ships no code; the one operation that carries a function to a peer is a spawn.

**Bindings.** A function spawned on a node runs only where the bindings that function depends on have their values there; otherwise the peer starts nothing, and the spawn fails with `NotLoaded`. Nothing is initialized because a peer asked. A spawn that arrives before a node's bindings all have their values, over a connection the node dialled itself, is answered `NotLoaded`, and the spawner may try again. In spawned code a top-level binding is the peer's, and a captured value is the spawner's; the system processes are the peer's too, so `Io.println` in a process spawned on a peer writes to the peer's standard output.

**Placement by load.** Two libraries stand on `Peer`, written in Ernest. The library `Load` gives the host's measures of this node, each a shim: the run queue and the schedulers' utilisation, which any node has, and memory and disk, from the host's `memsup` and `disksup`, which answer a failure on a node whose `measures` did not start them. The library `Balancer` places work. A balancer is a process: `Balancer.start(places)` gives its address, a place being this node or a peer's name, a type of the library's, and `Balancer.spawn(balancer, f, ms)` asks it for a spawn. It is round robin unless given a measure. A measure is a function from the program, answering a load from 0.0 to 1.0; a program installs it on a place by `Balancer.measure(place, f)`, which spawns a measuring process there, by `Peer.spawn` where the place is a peer, and the process offers itself under `Balancer.key`. The function captures what it needs and names no binding of the program's, so that it runs on any node. Numbers are not spread: a pick draws two candidates at random, calls each one's measuring process, and takes the lower. A node that offers no measure, or is out of reach, is passed over.

**The shell.** `ern shell --config-dir dir` is a node like any other: what is typed at it finds, calls and sends to its peers' services. A function typed at the shell is in a module of the shell's own, which no peer has, so a spawn of it on a peer fails with `NotLoaded`; a function of the build spawns as from a program. `:load` and `:reload` are refused in a shell that is a node, with an error naming MVP 3.1, and so is `ern run --config-dir dir` with no `.erc`, since in MVP 3.0 a node runs a program.

**Other nodes' processes and resources.** `Process.info` answers for the running node's processes alone, and `None` for a process of another node. A supervisor's children run on its own node.

**The faults.** Each has a cause in the report's register. The faults of the report's older peer chapter, `peer lost`, `peer unreachable` and `peer resolution failed`, go.

| Fault | Cause |
|---|---|
| an offer under a key a living process holds | `counter is offered by a living process`, with the key's name |
| `Address.callForever` on a callee whose node is out of reach | `callee is unreachable` |
| an offer of a process that is not this node's | `an offer names a process on its own node` |

## 7. The numbers

| What | Value |
|---|---|
| a node's identity | SHA-256 of its TLS public key |
| the build's checksum | SHA-256 over every module on the load path in name order, each as its name and the host's digest of its code (`beam_lib:md5`) |
| the number of a node's start | the host's, drawn at each start |
| the detector's tick | every 15 s where nothing else is sent |
| a silence is found in | 45 to 75 s |
| a dial that nothing answers is given up after | 7 s, the host's |
| what waits to be sent before a sender waits | 1 MB, the host's own |

`ern` gives the host the same numbers on every node. None is set in `ernest.conf`, which holds no number of the carrier's.

## 8. How it is checked

The carrier is the host's and has its own long record. It is not checked again.

What is Ernest's is small: the rule that accepts a peer by its key, the cookie that is the build's fingerprint, the gateway for a spawn, a find and an adapted address, the find over a key's peers in the order and the time stated, passing over the failures it passes over, and the start of a process on a peer. It is tested with real nodes on one machine, as the experiment that tried the carrier is ([`other_systems.md`](other_systems.md), section 4): nodes with keys of their own, a peer stopped to stand for a silent one, a node started again, a node that does not listen, a node of another build, a node that ends, and a network parted through a proxy that drops what passes one way or both. Those tests hold the claims of section 4.

A program's own tests of two nodes need nothing new: `ern test --config-dir dir` makes the test run a node, and a test makes a second configuration directory with `ern config`, lists each node in the other's `ernest.conf` on two ports of this machine, starts the second node with `Os` as a child program on the same build, talks to it as to any peer, and ends it.

## 9. Unsolved

1. **What the carrier leaves open.** A connected node may start, end and call anything on the other, and nothing turns that off, so a peer's rights can never be narrowed on this carrier.
2. **What a key leaves open.** A key's name is a string the program chooses, so two services can take one name by mistake. Where their message types differ a find through the first key answers that, and where they are the same the later offer silently wins.
3. **Costs not measured:** the gateway's step for an adapted address, a call's five signals, and TLS.
4. **The soundness argument's section 7,** owed before peers are built: which two types are one across nodes, and what crosses a node.
5. **What the report must say anew.** Its one silence, an act on what has ended that asks nothing back, widens to a `send` or a `kill` to a process whose node is out of reach or not listed, which vanishes while the process lives (section 5, point 8); and its peer chapter, §8.6's sentences on peers and on hangup, §8.7 and §10, is rewritten from this proposal. The rewrite names the sections whose rules it changes: §3.8, §3.11 and §6.5's transport sentence, whose run-time faults become the compile-time refusals of section 2, and §6.5's requirement that an adapted address's captured values can cross, which goes; §6.2's `send` that returns at once and §6.7's shape of a spawn, for `Peer.spawn`; §6.9, for the site that crosses in a `Down`; §8.4, since a peer's message is not checked on arrival; §8.2's resolution failure, which is MVP 3.1's `NotLoaded`; §9.3, where `Unreachable` is a reason only a monitor on another node's process gives, so that a one-node program's arm for it is accepted as the cost; §6.5's "there is no registry", beside offers under keys, its `send` that returns at once, which may wait for the network to a process of another node up to the host's buffer, and §3.9 for the refusal of a spawn whose captures have a type variable; §11.3, where a program without `--config-dir` is no node and `./.ernest` is its directory, in which `kept` states are written at termination and read at the next start, and Appendix C, rewritten for the directory's shape; and §11's job list and §11.7's options, which gain `ern reload`, `ern stop`, `ern deploy`, `ern diff`, `ern status` and `ern state`.
6. **What other systems teach.** How Akka, Orleans, Erlang's ecosystem, Swift's distributed actors, Unison and the capability systems treat the same questions is in [`other_systems.md`](other_systems.md). The carrier and the rule that an address outlives a loss come from weighing it; the rest of it is not in this proposal yet.

## 10. Left out on purpose

- Code that crosses between nodes, and a change of code while a program runs.
- Discovery of nodes, and a registry that nodes share: a key is offered on one node and found there, and `Peer.nodes` answers what the configuration lists. A balancer that learns which nodes exist, and a placement that moves a running process.
- A function shipped to a peer to read one of its bindings.
- A message carried through a third node.
- A cluster's membership, an election, a lease: what must exist once is the program's or a library's.
- A second attempt by the runtime at anything.
- A sender that never waits, with the connection ended where the buffer is full; and a way to read how much waits.
- A protocol of Ernest's own beneath the frames, and a wire format of its own.
- A detector that adapts its patience.
- A delay of the runtime's before a connection is opened again.
- Rights for each peer beyond being listed.
- An address that dies with its connection, and an operation that renews one.
- An address that lets its holder send and not kill.
- An operation that withdraws an offer, and a set of addresses under one key.
- A name of the node's own in `ernest.conf`: a node that must know which of its kind it is gets that as an argument, `ern run --config-dir dir worker.erc 1`.
- A shell attached to a running node, inside its process space: a shell is a node of its own, and reaches a running node's services by key.

## 11. Room for what comes after

MVP 3.1 gives every definition a hash and lets code cross with a spawn, so that nodes of different builds work together. After it comes a change of code, and of a protocol, in a process that keeps running. MVP 3.0 is to leave room for both, as far as can be seen from here. Four rules do most of it.

1. **Refuse now what may be allowed later, and allow nothing that must later be refused.** A function inside a message would be harmless among nodes of one build, and is refused by the compiler, since it cannot be allowed once code crosses; a spawn whose captures have a type variable in their type is refused for now. A function whose bindings a node did not run is refused, where a later milestone may run them. Two builds that differ refuse each other, where a later milestone lets them meet. A refusal that becomes an answer breaks no program.

2. **Settle now what a program writes.** A program writes the types of `Peer`'s functions and matches on the constructors of `Reason` and of `Peer.Failure`. A change to any of them breaks programs, where a change beneath them does not. So `Peer.Failure` is settled with the later milestones in view: `OtherType` has room for a service that is at another version, `NotLoaded` for what the peer does not have and cannot be sent, a binding's value or a foreign declaration's module, and `Refused`'s text for what a later handshake refuses.

3. **Keep closed what will change beneath.** The protocol never looks inside a function's reference, which is a place in a module now and a hash later. It compares a type's identity, at a find, and never asks how it was made: the type's text in MVP 3.0, a hash with its members' hashes in MVP 3.1. A message carries nothing of its type, in MVP 3.0 and after: every remote address a program holds came from a find, a spawn or a message whose type was already agreed. The protocol allows that a process comes to accept more than one type's identity, as a process that has changed its protocol will. It speaks of the connection between two nodes and not of what carries it, so that another carrier can take the host's place. And it asks a table for a peer's address and key, and not a file, so that a table filled another way can replace it.

4. **The wire is not kept.** The protocol's version is in the cookie, so two nodes of different versions never connect, and MVP 3.1 is a new version: every node changes over at once. Nothing in MVP 3.0 promises that a node of one milestone talks to a node of the next.

Three places carry the most risk. How a service is named and found: a key is a name and the identity of a message type, and whether the two are enough to tell one version of a service from another across builds is not known. The sum types a program matches on, where a constructor added later breaks every `match` that lists them all. And whatever one build on every node lets a program assume without saying, which MVP 3.1 then has to keep true or break.
