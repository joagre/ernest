# Ernest: MVP 3.0, Peers

Status: a proposal, to be read back and discussed before anything is planned or built. Section 9 holds what is unsolved.

## 1. What it is

MVP 3.0 lets one program run on several nodes. A *node* is one running runtime, and a *peer* is another node it knows by name. A process on one node spawns a process on a peer, sends to it, calls it, monitors it and kills it, with the operations a program already uses on one node.

Three things bound the milestone:

- **One build.** Every node carries the same compiled program, whole, and runs one entry point of it. No code crosses between nodes.
- **No change in place.** A deploy stops every node and starts every node.
- **A few nodes with one owner.** Every node lists its peers by hand, and trusts each of them completely.

**The building block** is small. An *address* names one process for as long as that process lives, on whichever node it is. A *connection* carries what two nodes send each other, for as long as it lasts. A *loss* of the connection ends what was in flight and nothing else: what waited to be sent is dropped, each monitor gets its one `Down`, and each waiting call ends. The address is as good as before, and when the two nodes connect again it reaches its process again. What carries all of it is Erlang's own distribution, with what hurts in it turned off and Ernest's types put on it (section 6).

## 2. What a program sees

**The operations across nodes.** Each behaves on a process of another node as it does on a local one, with the differences this document states.

| Operation | Across nodes |
|---|---|
| `send(address, value)` | carries the value to the process's node, over a connection it asks for where there is none; returns at once while the network keeps up, and promises nothing |
| `Address.call(address, request, ms)` | waits for the answer; `None` where none came in time, the callee ended or restarted, or its node went out of reach |
| `Address.callForever(address, request)` | waits without a limit; faults where the callee ended or its node went out of reach |
| `answer(reply, value)` | carries the answer to the caller's node |
| `monitor(process, wrap)` | one `Down` when the process ends, or when its node goes out of reach |
| `kill(address)` | kills the process on its node |
| `via(address, f)` | the adapted address may cross; `f` runs on the node that made it |

**What is new.** The module `Peer`, and one constructor of `Reason`.

```
type Peer.Key(m)
type Peer.Failure = NotListed | Unreachable | Refused(String) | Timeout
                  | NotOffered | OtherType | NotLoaded

Peer.key            : (String) -> Peer.Key(m)
Peer.offer          : (Peer.Key(m), Address(m)) -> Unit with n
Peer.find           : (String, Peer.Key(m), Int) -> Either(Peer.Failure, Address(m)) with n
Peer.spawn          : (String, () -> Unit with m, Int) -> Either(Peer.Failure, Address(m)) with n
Peer.spawnMonitored : (String, () -> Unit with m, (Down) -> n, Int)
                        -> Either(Peer.Failure, Address(m)) with n
```

- A *key* names a service to a node's peers and carries the service's message type: `Peer.key("counter")`, bound at the type `Peer.Key(Msg)`. It is a value, and starts nothing.
- `Peer.offer(key, address)` lets this node's peers find `address` under the key.
- `Peer.find(name, key, ms)` answers the address the peer of that name offers under the key, typed by the key.
- `Peer.spawn(name, f, ms)` starts a process that runs `f` on the peer of that name and answers its address. `Peer.spawnMonitored(name, f, wrap, ms)` monitors it from its start.
- A find and a spawn wait at most `ms` milliseconds, and answer the address or a failure, which the program matches on. Neither faults for what the network or the peer does. A spawn faults for one thing, a mistake of the program's own: a function that captured a value that may not cross.
- `Reason` gains `Unreachable`: the process's node is out of reach, and the process may live on.
- `ern reload --config-dir dir` makes the node started with that directory read its `ernest.conf` again, so that a peer is added or removed without stopping the node.

The failures, in the order a request meets them:

| Failure | Says |
|---|---|
| `NotListed` | the name is no peer's in this node's configuration |
| `Unreachable` | no connection could be opened, or it was lost while waiting |
| `Refused(text)` | the peer refused the hello; the text says what differed |
| `Timeout` | no answer came in time |
| `NotOffered` | the peer offers nothing under the key's name |
| `OtherType` | what it offers has another message type |
| `NotLoaded` | the function's bindings have no values on the peer |

One type serves a find and a spawn, as `Io.Error` serves every operation on a file: a program writes `_` for what its operation cannot meet.

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

An operation that would carry a value that may not cross faults the process that makes it, at that operation.

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
    match Peer.find("store", Counter.key, 5000) {
        Left(Timeout) -> Io.println("the store did not answer")
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
    match Peer.find("store", Counter.key, 5000) {
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
ern run --config-dir /etc/ernest/store store.erc
ern run --config-dir /etc/ernest/desk desk.erc
ern run --config-dir /etc/ernest/board board.erc
```

The desk prints `the counter is at 5` and ends. The board prints the total every second.

A fourth machine is added by listing it in the others' `ernest.conf` and running `ern reload --config-dir /etc/ernest/store` on each, with the store and the board running on.

Where the cable to the store is then pulled, each node finds the silence within 45 to 75 seconds. For as long as the store is out of reach the board's calls answer `None`, and the board prints nothing. When the cable is back, the next call opens a connection and the totals appear again. The board holds the same address throughout and has written nothing for the loss. The counter runs on untouched all the while, and still holds its total.

Where the store's node is itself stopped and started, its counter is a new process, which the store offers again under the same key. The address the board holds names the one that is gone: its calls answer `None` from then on. A program that is to outlive that monitors the counter, and finds it again by the key when it is told that the counter has ended. A library can do that for it (section 10).

The desk and the board depend on the module `Counter` for the message type and the key. That module starts nothing, so neither of them runs a counter of its own.

## 4. What holds

1. **Order.** What one process sends another arrives in the order it was sent, whichever addresses it was sent through, but one: a message to an adapted address made on the receiver's node takes one step more there, and a message sent straight after it can pass it.
2. **No gap while a connection lasts.** Between nodes a message is never dropped alone. Where one is dropped, the connection is lost, with everything that waited to be sent.
3. **At most once.** A message arrives once or not at all. The runtime sends nothing a second time.
4. **One `Down` for each monitor.** A monitor gives exactly one `Down`: the process's own end, told by its node, or `Unreachable`, made by the watcher's node when the process's node goes out of reach.
5. **Every call ends.** By its answer, by its time running out, by the callee's end or restart, or by the callee's node going out of reach. A find and a spawn on a peer end too: by the peer's answer, by their time running out, or by the peer going out of reach.
6. **Both nodes learn of a loss.** When two nodes lose each other, each ends what it held with the other: at once where the connection is closed, and within 45 to 75 seconds where it only falls silent.
7. **An address outlives a loss.** When two nodes connect again, an address reaches the process it reached before, for as long as that process lives and its node has not been started again. A monitor and a waiting call do not outlive a loss: it ends them.
8. **A node's own processes are untouched.** A loss ends conversations with the peer and nothing else: no local process dies of it.

## 5. What does not hold

1. **`Unreachable` is not death.** A watcher that replaces a process it was told is out of reach can have two. What must exist once lives on one named node, and is unavailable while that node is out of reach.
2. **A call that ended without an answer may have run.** `None` says that no answer came. It says nothing of why, or of whether the request ran, and it is the same where the request was never sent. A request that may be sent again is written so that running twice does no harm. A program that wants to know why monitors the callee, whose `Down` says it.
3. **A spawn that failed may have started its process.** Where the spawn's time runs out, or the connection is lost while the spawner waits, the spawner is told only that. The process may run on the peer, and no one holds its address. Where the connection lasts, the process is ended as soon as its answer arrives.
4. **A sender to a stalled peer waits.** Where more waits to be sent to a peer than the host's buffer holds, a `send` to that peer waits until it drains, as the host has it. A program that sends faster than the network carries is slowed to the network's speed. The wait ends at the latest when the detector gives the peer up: the send then returns, and the loss runs. A process that waits in a send serves nothing from its mailbox meanwhile, so a stalled peer stalls the processes that send to it. A call's time runs from the moment its request is sent, so a call to a stalled peer can take the wait and then its time.
5. **One large value delays what its sender sends after it.** Two nodes share one connection. A large value crosses in pieces, and other senders' messages pass between them. A slow function of an adapted address delays what that peer sends through the gateway: its spawns, its finds, and its messages to adapted addresses. A plain message passes the gateway by.
6. **A program that waits on itself across nodes hangs.** A node with peers declares no deadlock, since work can always reach it from outside.
7. **A silent failure takes 45 to 75 seconds to find.** A program that must know sooner puts a time on its calls. A find and a spawn always have one.
8. **A `send` to a node out of reach vanishes.** So does one to a node the sender's configuration does not list. A monitor or a call on the same address shows it.
9. **A peer is trusted completely.** Any node in the configuration may do on this node whatever the host lets a connected node do: start, end and call anything. Ernest's checks hold against a peer's mistakes, and not against a peer that means harm. A faulty peer can send a value of the wrong type that is caught only where the receiving process meets it. It can also send names this node has never had, each of which the host keeps as an atom for as long as the node runs.
10. **A loss can leave a hole.** What one process sent another while their nodes were out of reach of each other is gone, and what it sends after they connect again arrives. Both nodes run the loss, so a process that monitors the other is told that a hole may be there. A protocol that must have none numbers its messages, or calls.
11. **Nothing is upgraded while it runs.** Two nodes whose builds differ by one line refuse each other, and so do two with different versions of `ern` or of OTP.
12. **Whoever holds an address can kill its process.** An address is the permission to send and to kill, across nodes as on one. A node offers a service to all its peers alike, so each peer that finds it can end it for the others. A service that is to outlive a mistaken `kill` is supervised on its own node, and its new process is offered under the same key.
13. **A node that cannot be dialled is reached only while it holds a connection open.** Where one of two nodes cannot dial the other, as behind a translated address, the one that can opens the connection, and both send over it once it is open. After a loss the other node cannot open it again: what it sends vanishes, and its monitors say `Unreachable`, until the first node next acts towards it. So the node that can dial monitors a process of the other, and where it is told `Unreachable` it tries again, after a time it chooses.
14. **Two nodes with one key are one node to their peers.** A configuration directory copied to a second machine gives two nodes one name. Each one's dial ends the other's connection: what is sent to the one not connected is dropped, and a monitor on its processes says `Unreachable`. The peer says on its standard error each time a living connection is replaced by another from the same name, which a restart says once and the mistake says again and again. Nothing prevents it, since the second node looks like the first one restarted.

## 6. How it works

**The carrier.** Nodes talk over Erlang's own distribution, which the host has: its connections, its handshake, its heartbeat, its order, and its monitors across nodes. Ernest turns off what hurts in it, as the paragraphs below say, and puts three things of its own on it: a check that two nodes run the same build, the start of a process on a peer, and a service found by its key. A program never sees the carrier, so another can take its place.

**Nodes.** A node's identity is the SHA-256 hash of its TLS public key, and its name on the carrier is that hash with a constant after it. So the name is the same on every node and holds no network address, and a node that moves to another machine keeps it. A peer's name in a program is one node's own word for it, the name its `ernest.conf` lists the peer under. A program never sees the name on the carrier, and what the runtime prints of a peer shows the listed name, and the hash only for a node that is not listed. `ern config` makes a node's key and a certificate that the node signs itself, for the machine it runs on, and prints the public key, which is what another node's configuration lists. A configuration directory is never copied. The certificate's name is a constant, which nothing reads. A node has a configuration only where `--config-dir` names one: there is no default directory, and a program started without one is no node, has no peers and listens to nothing. As it starts, a node refuses a directory others can write and a key others can read. A node whose configuration gives it a network address listens there from its start. A node without one does not listen, and only dials. Each start of a node has a number of its own, which the host draws and puts in every address, so that an address of an earlier start is dead. A node writes its process number to `ernest.pid` in its directory at its start and removes it at its exit.

**A reload.** `ern reload --config-dir dir` sends the node named by `ernest.pid` the signal `SIGHUP`, which `kill -HUP` sends as well, and fails where there is no file or no such process. The node reads `ernest.conf` again and keeps its peers in a table, which the rule that accepts a peer and the dial both read. A peer added is a row, and nothing else happens until an operation dials it or it dials in. A peer removed, or one whose key changed, has its connection ended, both nodes run the loss, and the addresses a program holds of its processes are those of a node not listed. A peer whose address changed keeps an open connection, and the next dial uses the new address. A peer whose name changed under the same key keeps its connection; only the name a program uses changes. The node's own key and address cannot change while it runs, since they are its name and its listener: a file that changes either, or that does not parse, is refused, and the old configuration stays. The node says on its standard error which peers were added and removed, or why the file was refused. The signal carries nothing back: the command's exit status says only that it was delivered.

**Connections.** Two nodes have at most one connection, opened by the first operation that needs it, over TLS 1.3 with a certificate on each side. A node accepts a peer whose public key its configuration lists, and no other, by a rule of Ernest's in the TLS handshake. The rule goes by the key alone, and the host's check of a certificate's name is turned off. There is no port-mapper daemon: a node finds a peer's address in its configuration. A peer may be listed without an address, and is then never dialled: it is out of reach until it opens a connection itself. Connections are not transitive: that A knows B and B knows C connects A and C in no way. Where both dial at once, the host keeps one. The host's cookie is a constant and proves nothing.

**The hello.** When a connection opens, and before anything else passes, each node tells the other the version of this protocol, the hash of its build, and the versions of `ern` and of OTP. The build's hash covers every compiled module on the node's load path, by name and content, in name order, and is taken when the node starts. The entry point plays no part, so three nodes started from three modules of one build have one hash, and a node carries the whole build, the modules its entry point never uses included. The standard library is not in it: `ern`'s version stands for it. Where one of the four differs, the node ends the connection, and a find or a spawn that asked for it fails with `Refused`, whose text says which.

**What passes.** Ernest's own frames are five, and the host carries the rest as it carries them on one node.

| What | Carried by |
|---|---|
| a message | the host's send, straight into the mailbox |
| a message to an adapted address | a frame of Ernest's, to the gateway of the node that made the address |
| a spawn on a peer | a frame of Ernest's |
| the answer to a spawn | a frame of Ernest's |
| a find, with a key's name and its type's hash | a frame of Ernest's |
| the answer to a find | a frame of Ernest's |
| a monitor, and its `Down` | the host's monitor |
| a `kill` | the host's exit signal |
| the answer to a call | the host's alias, which takes one answer |
| a sign of life | the host's tick |

**The gateway.** A node has, for each connected peer, one process that takes that peer's frames: its *gateway*. A plain message does not pass through it: the host puts it in the mailbox, as on one node, and nothing of Ernest's stands between the wire and the mailbox. Through the gateway goes what needs a process on the receiving node: a spawn, a find, and a message to an adapted address, which is carried, unconverted, to the node that made the address, whose gateway applies the function and hands on the result; a fault in that function is the fault of the process the address leads to. A frame the gateway cannot read is faulty, and the node ends the connection. So a message between nodes costs what the host's send costs, and only one to an adapted address makes a step more, on the node that made the address.

**A loss.** A connection is lost when the network breaks it, when the detector finds it silent, or when a frame is faulty. In the last the node ends the connection itself. Each node is told by its own host, and no frame announces it. The host gives a `Down` with `Unreachable` and an empty `site` for each monitor held on the peer's processes, and drops what waited to be sent. The calls waiting on those processes end. A node that dials a peer which still believes the old connection alive makes that peer run its loss first.

**The detector.** The host's. Any traffic is a sign of life, and a tick is sent where nothing else was for 15 seconds. A peer from which nothing came in four such intervals is lost, so a silence is found in 45 to 75 seconds. `ern` sets the same time on every node.

**Connecting again.** The host's. A connection is opened again when an operation needs it, never in the background, and the host puts no delay between one attempt and the next. A dial that is refused fails at once. A dial that nothing answers is given up after 7 seconds, and what waited behind it is then dropped.

**Addresses.** An address is the host's own name for a process. It holds the node's name, the number of that node's start, and the process's number there. An address names its process for as long as the process lives, and a loss does not end it: when the two nodes connect again, the same address reaches the same process. Two things end an address. Its process ends. Or its node is started again: what is sent to an address of an earlier start is dropped, a call through it ends at once, and a monitor on its process gives `Unknown`. An address is a value like any other, and is as good on a third node it is sent to as on the node that sent it. A monitor is not kept through a loss. The loss gave its `Down`, and a program that wants to go on watching calls `monitor` again, on the process the `Down` names. Where that process's node is still out of reach, the new monitor gives its `Down` with `Unreachable`, and so it does where the node is not listed.

**Messages.** `send` hands the message to the host and returns, and the host puts it in the mailbox on the other node. Where no connection is open the host opens one, and the frame waits: it is sent where the connection opens, and dropped where it does not. What waits to be sent to a peer waits in the host's buffer for that peer. A `send` that finds the buffer full waits until it drains, as the host has it, and at the latest until the detector gives the peer up (section 5, point 4). A large value crosses in pieces, and other senders' messages pass between them.

**Calls.** A `Reply` is the host's alias, which takes one answer and drops any other, as on one node. The caller monitors the callee for as long as it waits, so the callee's end and a loss both end the call. Where the callee restarted, its node tells the caller's. A call to another node costs four of the host's signals where a `send` costs one.

**Serialization.** A value crosses in the host's external term format, written and read by the host. A message carries no hash of its type: its type is known at both ends and the same at both, which the build's hash made sure of. A constructor crosses as the text of its name, as a string does, and on arrival the host looks the name up among the atoms the node has. Every constructor of the program is in the build, so the messages of a correct program make no new atom on the node that receives them, however many they are. Before a value is sent, Ernest looks through it for what may not cross (section 2), which the host would carry as it is. On arrival the value is not looked into.

**A spawn.** `Peer.spawn(name, f, ms)` sends the peer a frame with `f` as a reference to its code, its module and its place there, and the values it captured. The same build has the same modules, so the reference means the same on both nodes. The peer starts the process and answers with its address. The spawner waits at most `ms` milliseconds, the opening of a connection among them. The wait ends when the peer answers, when no connection can be opened, when the connection is lost, or when the time runs out. A spawn fails, as a value, where the name is no peer's (`NotListed`), where the peer is out of reach or refused the hello (`Unreachable`, `Refused`), where the bindings the function depends on have no values on the peer (`NotLoaded`, *Bindings*), and where no answer came in time (`Timeout`). A monitored spawn that fails leaves no monitor. A spawn faults its caller in one case, which is found before anything is sent: the function captured a value that may not cross (section 2). An answer that comes when the spawner no longer waits, its time having run out or the spawner having ended, makes the node kill the process it names: the spawner was told that no process came, and that becomes true. The node keeps what it needs for that until the answer arrives or the connection is lost.

**A service and its key.** On one node a service is a top-level binding that holds an address, and a process reaches it by the binding's name. A peer cannot name another node's binding, so a service that peers are to reach is offered under a key. A key holds a name and the hash of a message type; the type is the one its binding is written at, and the hash is taken there. `Peer.offer(key, address)` is accepted by the compiler only where the key and the address have one message type. The node then keeps the address under the key's name for as long as the process lives, and a later offer under the same name takes its place. An offer cannot fail for a name, and nothing withdraws one: it ends with its process. Only a process of the offering node may be offered; an offer of any other address faults the caller. `Peer.find(name, key, ms)` asks the peer for what it offers under the key's name, and the peer answers the address where the hash is the same. The finder waits at most `ms` milliseconds, as a spawner does. A find fails, as a value, where the name is no peer's (`NotListed`), where the peer is out of reach or refused the hello (`Unreachable`, `Refused`), where the peer offers nothing under that name (`NotOffered`), where what it offers there has another message type (`OtherType`), and where no answer came in time (`Timeout`). The last two are the ones that grow: a service at another version is `OtherType`, and code the peer does not have is `NotLoaded`. Only what a node offers can be found: its other bindings are closed to its peers. A find ships no code, so the one operation that carries a function to a peer is a spawn.

**Bindings.** A node runs, at its start, the top-level bindings of the standard library and of the modules its own entry point depends on, as a program on one node does. A function spawned on it runs only where the bindings that function depends on have their values there. Otherwise the peer starts nothing, and the spawn fails with `NotLoaded`. Nothing is initialized because a peer asked. In spawned code a top-level binding is the peer's, and a captured value is the spawner's.

**Other nodes' processes and resources.** `Process.info` answers for the running node's processes alone, and `None` for a process of another node. A supervisor's children run on its own node.

**The faults.** Each has a cause in the report's register, and the faults of the report's older peer chapter, `peer lost`, `peer unreachable` and `peer resolution failed`, go with it.

| Fault | Cause |
|---|---|
| a foreign value, a function, or the address of a socket, a listener or a program, about to cross | `foreign value cannot cross nodes`, `function cannot cross nodes`, `resource cannot cross nodes` |
| a spawned function that captured such a value | the same, for the value it was |
| `Address.callForever` on a callee whose node is out of reach | `callee is unreachable` |
| an offer of a process that is not this node's | `an offer names a process on its own node` |

## 7. The numbers

| What | Value |
|---|---|
| a node's identity | SHA-256 of its TLS public key |
| the build's hash | SHA-256 over every compiled module on the load path, by name and content, in name order |
| the number of a node's start | the host's, drawn at each start |
| the detector's tick | every 15 s where nothing else is sent |
| a silence is found in | 45 to 75 s |
| a dial that nothing answers is given up after | 7 s, the host's |
| what waits to be sent before a sender waits | 1 MB, the host's own |

`ern` gives the host the same numbers on every node. None is set in `ernest.conf`.

## 8. How it is checked

The carrier is the host's and has its own long record. It is not checked again.

What is Ernest's is small: the rule that accepts a peer by its key, the hello with the build's hash, the gateway for a spawn, a find and an adapted address, and the start of a process on a peer. It is tested with real nodes on one machine, as the experiment that tried the carrier was ([`other_systems.md`](other_systems.md), section 4): nodes with keys of their own, a peer stopped to stand for a silent one, a node started again, and a node that does not listen. Those tests hold the claims of section 4. What they cannot show is a network that really parts (section 9).

## 9. Unsolved

1. **What the carrier leaves open.** A connected node may start, end and call anything on the other, and nothing turns that off, so a peer's rights can never be narrowed on this carrier. A network that really parts was not tried.
2. **What a key leaves open.** A key's name is a string the program chooses, so two services can take one name by mistake. Where their message types differ a find through the first key answers that, and where they are the same the later offer silently wins.
3. **A key's type hash.** What exactly it is taken over, and how the type is described at run time for it.
4. **What the gateway leaves open.** A function of an adapted address that does not finish holds up that peer's spawns, finds and messages to adapted addresses, with no limit on what waits behind it. And how a callee's node knows which calls from other nodes wait on a process, to end them where it restarts.
5. **A network address.** A name or a number, and what the listener binds to.
6. **Testing a program of two nodes** with `ern test`. The experiment shows a way to run several nodes on one machine.
7. **The shell on a node.**
8. **Costs not measured:** the gateway's step for an adapted address, a call's four signals, TLS, and the look through each value before it is sent.
9. **What other systems teach.** How Akka, Orleans, Erlang's ecosystem, Swift's distributed actors, Unison and the capability systems treat the same questions is in [`other_systems.md`](other_systems.md). The carrier and the rule that an address outlives a loss come from weighing it; the rest of it is not in this proposal yet.

## 10. Left out on purpose

- Code that crosses between nodes, and a change of code while a program runs.
- Discovery of nodes, and a registry that nodes share: a key is offered on one node and found there. How a program learns which nodes there are, and places work by load, is not weighed.
- A standing address of a service, one that finds the service again after its node is started again. A library builds it: a process on the holder's node that forwards, finds by the key, monitors, and is held through `via`.
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

## 11. Room for what comes after

MVP 3.1 gives every definition a hash and lets code cross with a spawn, so that nodes of different builds work together. After it comes a change of code, and of a protocol, in a process that keeps running. MVP 3.0 is to leave room for both, as far as can be seen from here. Four rules do most of it.

1. **Refuse now what may be allowed later, and allow nothing that must later be refused.** A function inside a message would be harmless among nodes of one build, and is refused, since it cannot be allowed once code crosses. A function whose bindings a node did not run is refused, where a later milestone may run them. Two builds that differ refuse each other, where a later milestone lets them meet. A refusal that becomes an answer breaks no program.

2. **Settle now what a program writes.** A program writes the types of `Peer`'s functions and matches on the constructors of `Reason` and of the failures of a find and of a spawn. A change to any of them breaks programs, where a change beneath them does not. So `Peer.Failure` is settled with the later milestones in view: `OtherType` has room for a service that is at another version, `NotLoaded` for code the peer does not have, and `Refused`'s text for what a later hello refuses.

3. **Keep closed what will change beneath.** The protocol never looks inside a function's reference, which is a place in a module now and a hash later. It compares a type's hash, at a find, and never asks how the hash was made. A message carries no hash in MVP 3.0, and step B puts one on it, which the fourth rule allows; the protocol then allows that a process comes to accept more than one type's hash, as a process that has changed its protocol will. It speaks of the connection between two nodes and not of what carries it, so that another carrier can take the host's place. And it asks a table for a peer's address and key, and not a file, so that a table filled another way can replace it.

4. **The wire is not kept.** A hello whose protocol version differs ends the connection, and MVP 3.1 is a new version: every node changes over at once. Nothing in MVP 3.0 promises that a node of one milestone talks to a node of the next.

**Where new code comes in.** MVP 3.0 loads no new code: a new version is a stop of every node. Loading new code is four steps, of which MVP 3.0 is the first.

| Step | What it gives | Where |
|---|---|---|
| A | one build on every node, and a deploy that stops them all | MVP 3.0 |
| B | nodes of different builds connect; a message is accepted by its type's hash, and a spawned function only where the peer has its module, and all that module depends on, unchanged; no code crosses | a step after MVP 3.0, to be weighed |
| C | a hash for each definition; code crosses with a spawn; two versions stand side by side on a node | MVP 3.1 |
| D | a running process takes new code, and later a new protocol | after MVP 3.1 |

Step B parts two rules that step A holds as one: that no code crosses, and that every node is the same build. The second is what makes every deploy a stop of all nodes at once. Without it, nodes are restarted one at a time wherever a change does not touch what they exchange, and the build's hash falls away. A changed module that spawns or finds on a node still holding the old one fails until that node has it too, so a real upgrade waits for step C. Step B only relaxes step A, by rule 1, and can follow MVP 3.0 without breaking a program. Replacing a module under running processes, as Erlang's `code` module does, is none of these steps: it changes code with nothing to check its types against.

Three places carry the most risk, since a later milestone may find them wrong. How a service is named and found: a key is a name and the hash of a message type, which is what a later milestone needs to tell one version of a service from another, and whether the two are enough across builds is not known. The sum types a program matches on, where a constructor added later breaks every `match` that lists them all. And whatever one build on every node lets a program assume without saying, which MVP 3.1 then has to keep true or break.
