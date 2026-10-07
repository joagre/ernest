# The counter, written twice

The first program of [`code_update.md`](../../code_update.md)'s section 4, written and run on 2026-10-07 on one node with the toolchain as it stands, Ernest 0.3.1: a counter with its total as its state, first as the restart alone has it, then as a step function the library runs. Row C1, a change of logic behind an unchanged protocol and state type, runs both ways; row C2, a change of the state's shape, is where the second way stops, and its diagnostic is the experiment's finding.

## The files

- `restart/v1/counter.ern`, `restart/v2/counter.ern`: the counter as a loop with its state in its arguments (report §6.5); version 2 logs each `Add`.
- `service/service.ern`: the library, `Service`, written for this experiment: an `Envelope(m, s)` of the protocol's messages and one `Upgrade`, a `Handle` of the loop's address and the clients' adapted address, `start`, `run`, `address` and `upgrade`. No envelope tag yet, since no protocol changes here.
- `service/v1/counter.ern`, `service/v2/counter.ern`: the counter as a `step` the library runs; version 2 logs each `Add`.
- `service/v3/counter.ern`: version 3, the state's shape changed to a record that also counts the adds, with `migrate`; it compiles.
- `service/v3/upgrade_v3.ern`: the upgrade of a running version 1 or 2 counter to version 3, which does not compile.

## How it was run

Each version is built over a directory holding `service.ern` and the version's `counter.ern`, and each session below is the shell in line mode over such a directory, the source rewritten between inputs with `Fs.write`, as `test/ern_shell_tests.erl` drives a reload:

```console
$ ern build --source-root dir --build-root dir/build dir
$ ern shell --source-root dir < session.in
```

## The restart alone

```console
Ernest 0.3.1. :help for the commands, :quit to leave.
> Counter, compiled from counter.ern
> > 3 : Int
> Right(Unit) : Either(Io.Error, Unit)
> Counter, compiled again
Counter: the previous version is held by the process spawned at Counter.counter:7; the next reload of Counter ends it
> 0 : Int
> add 1
> 1 : Int
>
```

The reload evaluates the service binding again (report §11.2), so a second counter starts at 0 and the module's functions reach it: the total of 3 is lost. The first counter runs on, unreachable, until the next reload ends it. A deploy by restart does the same with a node.

## The service upgraded in place

```console
Ernest 0.3.1. :help for the commands, :quit to leave.
> Service, compiled from service.ern
Counter, compiled from counter.ern
> h : Service.Handle(Counter.Msg, Int)
> > 3 : Int
> Right(Unit) : Either(Io.Error, Unit)
> Counter, compiled again
> > 3 : Int
> add 1
> 4 : Int
> 0 : Int
>
```

`h` holds the version 1 service. After the reload, `Service.upgrade(h, Counter.step)` hands it version 2's `step`; its total of 3 is kept, the next `Add` is logged by the new code, and the total is 4. `Counter.total()` answers 0 from the second service the reload's re-evaluation of the binding started, which is today's §11.2; under the concept the plan would send the `Upgrade` instead of evaluating the binding again.

## Row C2 does not compile

`upgrade_v3.ern` sends the running loop an `Upgrade` whose `next` migrates the `Int` to a `Count` and runs version 3's step:

```console
upgrade_v3.ern:10:47: field next: expected (a) -> Unit with Service.Envelope(e, a), found (Int) -> Unit with Service.Envelope(Counter.Msg, Counter.Count)
 9 |         Service.Handle(loop = loop) ->
10 |             send(loop, Service.Upgrade(next = fn(total) = Service.run(Counter.step, Counter.migrate(total))))
   |                        --------------- Upgrade declares next : (s) -> Unit with Service.Envelope(m, s)
   |                                               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   | = help: the types differ at Service.Envelope(a, b) and Service.Envelope(Counter.Msg, Counter.Count)
```

The `Upgrade` hands the state to new code through a function whose mailbox type is the loop's, `Envelope(Msg, Int)`, and version 3's loop runs under `Envelope(Msg, Count)`. The state's type is in the mailbox type, so a change of the state's shape in place is a change of the mailbox type, which only `become` makes. What `code_update.md` says of it is its section 2, *A changed state is a changed mailbox type*.

## A second finding, on today's shell

In the service session the reload did not list the version 1 process as holding the previous version, where the restart session's reload did. The library's loop runs `Service.run`, which the reload did not compile again, and holds version 1's `step` in its arguments; the host's `check_process_code` sees a process's code and not a function in its state (the survey's *B8*), so §11.2's listing missed it, and the reload that purges version 1 will leave it to fail at its next `Add` with the host's `undef`. The plan's standing gaps hold it; MVP 3.1 unloads nothing, which closes it.

## The count

| | lines |
|---|---|
| the counter as the restart has it, version 1 | 20 |
| the counter as a step function, version 1 | 20 |
| the library, written once | 34 |
| what version 2 adds, either way | 3 to 4 |
| what the upgrade in place cost the program | one line at the shell, `Service.upgrade(h, Counter.step)` |

What the step function saved here is the total, 3, and what it cost is the library. The store, the protocol change and the chat server are next, and the chat server is where `become` is weighed.

# The chat server, written twice

The loop column's program, written and run on 2026-10-07: a room, one process for each connection owning its socket, and a reader process for each that reads the socket and sends every line to its connection. The connection's address and its socket are what its clients hold, so a successor at another address is a loss, and the connection is upgraded in place by §6.10's case written by hand. The clients are processes too, since a socket an input opens ends with the input's process (report §11.2); `chat/client.ern` is the same in every version.

## The files

- `chat/v1/chat.ern`: version 1, lines broadcast as they are, `UpgradeAll` in the room's protocol and `Upgrade` in the connection's.
- `chat/v2/chat.ern`: version 2, each line said under the speaker's name; the protocol and the state unchanged (row C1).
- `chat/v3/chat.ern`: version 3, a connection can be kicked, a constructor added to the connection's protocol (row C3).
- `chat/restart/chat.ern`: the same room and connections with no upgrade case, as the restart alone has it.
- `chat/client.ern`: a client as a process that owns its socket, `start`, `say` and `hear`.

## The upgrade in place

```console
Ernest 0.3.1. :help for the commands, :quit to leave.
> Chat, compiled from chat.ern
> Client, compiled from client.ern
> r : Address(Chat.RoomMsg)
> p : Int
> c1 : Address(Client.Msg)
> c2 : Address(Client.Msg)
> > Some("hello") : Optional(String)
> Some("hello") : Optional(String)
> 2 : Int
> Right(Unit) : Either(Io.Error, Unit)
> Chat, compiled again
Chat: the previous version is held by the processes spawned at Chat.room:24, Chat.acceptor:27, Chat.accepting:51, Chat.connected:63, Chat.accepting:51 and Chat.connected:63; the next reload of Chat ends them
> > > Some("guest1: again") : Optional(String)
> Right(Unit) : Either(Io.Error, Unit)
> Chat, compiled again
Chat: the previous version is unloaded; the reload ended the processes spawned at Chat.room:24, Chat.acceptor:27, Chat.connected:63 and Chat.connected:63
Chat: the previous version is held by the processes spawned at Chat.acceptor:27, Chat.accepting:51, Chat.accepting:51 and Chat.room:24; the next reload of Chat ends them
Chat.ConnMsg changed: the binding r was checked against its previous version, which MVP 3.1 tells from the current one; the reload forgot it
Chat.acceptor:27 faulted: its code was unloaded
Chat.connected:63 faulted: its code was unloaded
Chat.connected:63 faulted: its code was unloaded
Chat.room:24 faulted: its code was unloaded
> input 18:1:6: unknown name r
1 | send(r, Chat.UpgradeAll(next = Chat.serving))
  |      ^
  | = help: r was forgotten by a reload: it was checked against a previous version of Chat.ConnMsg, which MVP 3.1 tells from the current one
> > Some("guest1: again") : Optional(String)
>
```

Two clients connect; a line from one reaches both, and the room counts two members. After the reload to version 2, `UpgradeAll` hands every connection version 2's `serving`: the next line arrives under the speaker's name, through the same connection and the same socket, with nothing dropped. After the reload to version 3, which changed `ConnMsg`, the room's old address `r` is forgotten by the shell's rule of this afternoon, since it was checked against the previous `ConnMsg`, and the `UpgradeAll` is refused: a running connection's mailbox type is the old `ConnMsg`, and nothing of the new protocol can reach it. The last line heard is the one the first client had not yet read; the connections' readers, spawned by version 1 and never upgraded, were ended by that third reload, see the findings.

## The restart alone

```console
Ernest 0.3.1. :help for the commands, :quit to leave.
> Chat, compiled from chat.ern
> Client, compiled from client.ern
> p : Int
> c1 : Address(Client.Msg)
> > Some("hello") : Optional(String)
> Right(Unit) : Either(Io.Error, Unit)
> Chat, compiled again
Chat: the previous version is held by the processes spawned at Chat.room:15, Chat.accepting:42, Chat.acceptor:18 and Chat.connected:54; the next reload of Chat ends them
> Right(Unit) : Either(Io.Error, Unit)
> Chat, compiled again
Chat: the previous version is unloaded; the reload ended the processes spawned at Chat.room:15, Chat.accepting:42, Chat.acceptor:18 and Chat.connected:54
Chat: the previous version is held by the processes spawned at Chat.acceptor:18 and Chat.room:15; the next reload of Chat ends them
Chat.acceptor:18 faulted: its code was unloaded
Chat.room:15 faulted: its code was unloaded
Chat.connected:54 faulted: its code was unloaded
Chat.accepting:42 faulted: its code was unloaded
> > None : Optional(String)
>
```

The second reload ends the previous version's processes, the connection among them, and the connection's socket closes with its owner (report Appendix E.18): the client's next read answers `None`. This is what a restart of the node does to every connection it holds.

## Findings

- **The loop column works today for rows C1 and C2.** A connection upgraded in place keeps its address and its socket, and its clients see nothing but the new behaviour. What it cost the program is the `Upgrade` constructor and its clause, written by hand in each loop, and the room's `UpgradeAll` to reach every connection.
- **Row C3 needs `become`.** A running loop's mailbox type is its old protocol; the shell refuses the new one at the binding, and the type would refuse it at the `Upgrade` as the counter's version 3 did. For a process whose address must be kept, a protocol change in place has one way, a change of the mailbox type under a translation, which is part two's `become`.
- **Every process of a module is a version holder.** The readers, spawned by a connection and never upgraded, ran version 1 until the shell's purge ended them, and the connections then heard nothing more. An upgrade must reach every long-running process of a module, helpers among them, or list them as still on old code, which is what the plan's list by code hash is for; under MVP 3.1 nothing is purged and they would run the old code until the node restarts.
- **A listener opened in a top-level binding dies at `:load`.** The first version opened its listener in a binding, and the acceptor found it ended: `:load` evaluates bindings in a process of the shell's own, which ends, and a listener ends with its owner (report §11.2, Appendix E.18), where `ern run` evaluates them in the entry process, which lives on. The program now has the acceptor own its listener, which is the right shape; the difference between the shell and a run is in `docs/language_feedback.md`.

## The count

| | lines |
|---|---|
| the chat server as the restart has it | 105 |
| the chat server with the upgrade case, version 1 | 120 |
| what the upgrade in place cost the program | 15 lines, the two constructors and their clauses |
| what version 2 changed, either way | 1 line |
| what the upgrade cost at the shell | one line, `send(r, Chat.UpgradeAll(next = Chat.serving))` |

# The store, written twice

The singleton's program, written and run on 2026-10-07: a store whose state is its items and the listener it owns, as a step function the library runs, with an acceptor helper that answers each connection the store's size. Row C1 in place, and row C2 as a handover to a successor, which is the node that stops done on one node. The restart alone is the counter's story again, the items lost, and is not run twice.

## The files

- `store/v1/store.ern`: version 1; the listener is opened in `init`, inside the loop, so that the loop owns it.
- `store/v2/store.ern`: version 2, each `Put` logged; the protocol and the state's type unchanged (row C1).
- `store/v3/store.ern`: version 3, the state's shape changed to `State2`, which counts the puts; `State` stays, the previous version's, so that `migrate` can be written; `handover` starts a successor from the migrated state and ends the old loop.
- The client is `chat/client.ern`.

## The run

```console
Ernest 0.3.1. :help for the commands, :quit to leave.
> Service, compiled from service.ern
Store, compiled from store.ern
> Client, compiled from client.ern
> h : Service.Handle(Store.Msg, Store.State)
> > > Some(1) : Optional(Int)
> p : Int
> c1 : Address(Client.Msg)
> Some("keys: 2") : Optional(String)
> Right(Unit) : Either(Io.Error, Unit)
> Store, compiled again
Store: the previous version is held by the process spawned at Store.init:19; the next reload of Store ends it
> > put c
> 3 : Int
> c2 : Address(Client.Msg)
> Some("keys: 3") : Optional(String)
> Right(Unit) : Either(Io.Error, Unit)
> Store, compiled again
Store: the previous version is unloaded; the reload ended the process spawned at Store.init:19
Store: the previous version is held by the process spawned at Store.init:18; the next reload of Store ends it
Store.init:19 faulted: its code was unloaded
> the successor listens on 37333 with 3 keys
> fault: callee had ended
> Client.start:7 faulted: cannot connect
c3 : Address(Client.Msg)
> fault: callee had ended
>
```

Two items are put and read back, and a connection is answered `keys: 2`. After the reload to version 2, `Service.upgrade(h, Store.step)` hands the running store the new step: the next put is logged by the new code, the size is 3, and a connection on the same port, through the same listener, is answered `keys: 3`; the store kept its items and its resource through an upgrade in place. After the reload to version 3, `Store.handover(h)` sends the old loop an `Upgrade` whose function starts a successor from `migrate` of the state and returns: the successor listens on a new port with the three keys, the old store has ended, and a connection to the old port is refused.

## Findings

- **A changed state is a replace today, and the replace is the library's one message.** `Upgrade`'s function takes the old state and may do anything with it: starting a successor from `migrate` of it and ending is the handover of code_update.md's section 2, written in six lines, with no new concept. Its price is the one the document names: a new address, which the old handle no longer reaches, and the resource reopened, since the listener ends with its owner. Across nodes the same function would start the successor by `Peer.spawn` and the state would cross as a value.
- **In place keeps the resource for nothing.** Row C1 kept the listener and its port through the upgrade, since the process is the same; nothing was given, nothing reopened.
- **The helpers are version holders here too.** Each version's acceptor runs the module's `accepting` and holds that version; the third reload ended version 1's acceptor, as the chat server's readers were ended. A successor's acceptor ends with the old listener, which is right; a helper of an upgraded loop must be upgraded or listed.
- **A first version of the program asked itself for its size.** `spawn(fn() = accepting(listener, via(self(), Service.Message)))` evaluates `self()` inside the spawned acceptor, so the acceptor's request went to the acceptor. The language is right and the program was wrong; the address is now bound outside the lambda. It is the kind of mistake the plan's generated test would have found, since the first connection answered nothing.

## The count

| | lines |
|---|---|
| the store as a step function, version 1 | 73 |
| what version 2 changed | 1 line |
| what version 3 added for the handover | `State2`, `migrate`, `opened` and `handover`, 25 lines, of which the handover is 8 |
| what the upgrade in place cost at the shell | one line, `Service.upgrade(h, Store.step)` |
| what the handover cost at the shell | one line, `Store.handover(h)` |
