# Paper Program 2: File Sync

Written against the Ernest report, September 2026, to see where the specification chafes. Two directories are kept identical; changes are sent to the peer; conflicts are saved as an extra file. The peer is an `Address`, and the code is the same whether it lives on the same node or not.

## Assumptions About the Runtime's System Processes

```
type FsMsg
    = List(path : Path, reply : Address(Either(FsError, List(Entry))))
    | Read(path : Path, reply : Reply(Either(FsError, Bytes)))
    | Write(path : Path, bytes : Bytes, reply : Reply(Either(FsError, ())))

type FsError = NotFound | Denied | Io(Text)
type Entry   = Entry(path : Path, mtime : Mtime)
```

`Ordering = Less | Equal | Greater` and `Mtime.compare : (Mtime, Mtime) -> Ordering` are assumed in the prelude. `ClockMsg` and `Sys` are the report's; `sys : Sys` is threaded as the first argument to every function that does IO. Three hand-written field functions, what records would have generated:

```
fn Sys.fs(Sys(fs = a) : Sys) = a
fn Sys.clock(Sys(clock = a) : Sys) = a
fn Sys.stdout(Sys(stdout = a) : Sys) = a
```

## The Program

```
// Pure code ----------------------------------------------------

type Change = Change(path : Path, mtime : Mtime)

// What has changed since the last snapshot?
fn diff(old : Map(Path, Mtime), entries : List(Entry)) -> List(Change) =
    List.filterMap(entries, fn(e) = changed(old, e))

fn changed(old : Map(Path, Mtime), Entry(path = p, mtime = m) : Entry) -> Optional(Change) =
    match Map.get(old, p) {
        None     -> Some(Change(path = p, mtime = m))
      | Some(m0) -> match Mtime.compare(m, m0) {
            Greater -> Some(Change(path = p, mtime = m))
          | _       -> None
        }
    }

fn snapshot(entries : List(Entry)) -> Map(Path, Mtime) =
    List.foldLeft(entries, Map.empty, fn(acc, Entry(path = p, mtime = m)) = Map.put(acc, p, m))

fn conflictPath(p : Path) -> Path = Path.withSuffix(p, ".conflict")

// Protocol between two syncers --------------------------------

type Ack = Stored | Conflict | Failed(FsError)

type SyncMsg
    = Link(Address(SyncMsg))
    | Tick
    | Listed(Either(FsError, List(Entry)))
    | Put(path : Path, mtime : Mtime, bytes : Bytes, ack : Reply(Ack))

// Waiting phase: receive the peer's address, then the loop.
fn start(sys : Sys, dir : Path) -> () with SyncMsg = recv {
    Link(peer) -> { send(self(), Tick); syncer(sys, dir, peer, Map.empty) }
}

// The sync process: one per directory -------------------------

fn syncer(sys : Sys, dir : Path, peer : Address(SyncMsg), seen : Map(Path, Mtime)) -> () with SyncMsg = recv {
    Tick -> {
        send(Sys.fs(sys), List(path = dir, reply = via(Listed, self())));
        listing(sys, dir, peer, seen)
    }
  | Put(path = p, mtime = m, bytes = bytes, ack = ack) -> {
        store(sys, dir, seen, p, m, bytes, ack);
        syncer(sys, dir, peer, Map.put(seen, p, m))
    }
  | Listed(_) -> syncer(sys, dir, peer, seen)      // late listing, ignore
  | Link(_)   -> syncer(sys, dir, peer, seen)      // already connected
}

// Between List and Listed: accept Put, but not Tick.
fn listing(sys : Sys, dir : Path, peer : Address(SyncMsg), seen : Map(Path, Mtime)) -> () with SyncMsg = {
    let tick = fn() = send(Sys.clock(sys), After(ms = 5000, to = via(fn(_) = Tick, self())));
    recv {
        Listed(Right(entries)) -> {
            List.foreach(diff(seen, entries), fn(c) = { _ = spawn(Local, fn() = pusher(sys, dir, peer, c)); () });
            tick();
            syncer(sys, dir, peer, snapshot(entries))
        }
      | Listed(Left(e)) -> {
            send(Sys.stdout(sys), Line("cannot list " ++ Path.toText(dir) ++ ": " ++ FsError.toText(e)));
            tick();
            syncer(sys, dir, peer, seen)
        }
      | Put(path = p, mtime = m, bytes = bytes, ack = ack) -> {
            store(sys, dir, seen, p, m, bytes, ack);
            listing(sys, dir, peer, Map.put(seen, p, m))
        }
      | after 10000 -> {
            send(Sys.stdout(sys), Line("fs is not answering"));
            tick();
            syncer(sys, dir, peer, seen)
        }
    }
}

// Store a file from the peer. Newer local file: conflict.
fn store(sys : Sys, dir : Path, seen : Map(Path, Mtime), p : Path, m : Mtime, bytes : Bytes, ack : Reply(Ack)) -> () with SyncMsg =
    match Map.get(seen, p) {
        Some(local) when Mtime.compare(local, m) == Greater -> {
            let _ = spawn(Local, fn() = writer(Sys.fs(sys), Path.join(dir, conflictPath(p)), bytes, ack, Conflict));
            ()
        }
      | _ -> {
            let _ = spawn(Local, fn() = writer(Sys.fs(sys), Path.join(dir, p), bytes, ack, Stored));
            ()
        }
    }

// One process per write: waits for fs and answers the peer.
fn writer(fs : Address(FsMsg), p : Path, bytes : Bytes, ack : Reply(Ack), okAck : Ack) -> () with n =
    match Address.call(fs, fn(r) = Write(path = p, bytes = bytes, reply = r), 10000) {
        Some(Right(())) -> answer(ack, okAck)
      | Some(Left(e))   -> answer(ack, Failed(e))
      | None            -> answer(ack, Failed(Io("timeout")))
    }

// One process per changed file: reads and sends to the peer.
fn pusher(sys : Sys, dir : Path, peer : Address(SyncMsg), Change(path = p, mtime = m) : Change) -> () with n =
    match Address.call(Sys.fs(sys), fn(r) = Read(path = Path.join(dir, p), reply = r), 10000) {
        Some(Right(bytes)) -> push(Sys.stdout(sys), peer, p, m, bytes)
      | Some(Left(_))      -> send(Sys.stdout(sys), Line("cannot read " ++ Path.toText(p)))
      | None               -> send(Sys.stdout(sys), Line("fs is not answering: " ++ Path.toText(p)))
    }

fn push(out : Address(Line), peer : Address(SyncMsg), p : Path, m : Mtime, bytes : Bytes) -> () with n =
    match Address.call(peer, fn(r) = Put(path = p, mtime = m, bytes = bytes, ack = r), 30000) {
        Some(Stored)    -> ()
      | Some(Conflict)  -> send(out, Line("conflict: " ++ Path.toText(p)))
      | Some(Failed(e)) -> send(out, Line("the peer failed: " ++ Path.toText(p)))
      | None            -> send(out, Line("the peer is not answering: " ++ Path.toText(p)))
    }

// Start ----------------------------------------------------------

fn main(sys : Sys) -> () with () = {
    let a = spawn(Local, fn() = start(sys, Path("a")));
    let b = spawn(Local, fn() = start(sys, Path("b")));
    send(a, Link(b));
    send(b, Link(a))
}
```

## What Chafed

**1. Mutual addresses.** Two processes that must know each other: one is spawned first and does not know the other. Erlang solves it with `register` or with a `{peer, Pid}` message after start. Without a registry the answer is a start message, `Link(Address(SyncMsg))` in `SyncMsg`, and a waiting phase before the loop:

```
fn start(sys : Sys, dir : Path) -> () with SyncMsg = recv {
    Link(peer) -> { send(self(), Tick); syncer(sys, dir, peer, Map.empty) }
}
```

It works, it is selective receive that makes it work (a Put arriving before Link stays in the mailbox), and it is the same pattern as the handler in the web server. But it is the second time a program needs a "wait for my configuration" phase, and it should be recorded as an idiom, since it is the answer to "no registry."

**2. Without `?`: seven matches on `Either`, no nesting.** `pusher`, `push`, `writer`, `store`, `listing`, `changed`: each has one match, none has two levels. The rule "one function, one match" held without being felt. The difference from the web server is that the errors here are messages (`Failed(e)`, `Left(e)` in `Listed`), and a match on a message is what a process does anyway. It was in pure code that `?` tempted; in process code there is no temptation.

**3. The dead `Timeout` arm, third time.** First version: `syncer` and `start` waited `forever` and wrote `Timeout -> ...`, as the web server did twice. Five process loops in two programs with an arm that is never reached. That decided it, in two steps: first `recv` without a limit and `recvFor` with one, then, when the comparison with Erlang showed that the filter lambda was the only large cost, `recv` as a form with arms and `after`. The code above uses it. `listing` matches only `Listed` and `Put`; `Tick` and `Peer` stay in the mailbox, which the filter expressed in three lines.

**4. The clock.** The first version had `clock : Address (After Millis (Address Tick))` and every process wrote `reply (_ -> Tick)`. A version in between let the clock take the value, `After { ms, to, msg : a }`; that was an existential type, `a` is not a parameter of `ClockMsg`, and it was dropped. Now the clock sends `()` and the receiver writes `via(fn(_) = Tick, self())`, which `listing` does once in a local `tick` lambda. The verbosity is back, for a reason that holds.

**5. Ordering per type worked.** `Mtime.compare(m, m0)` with a match on `Ordering` reads well, and the guard `when Mtime.compare(local, m) == Greater` is the only place ordering was needed. Nobody missed `<` on Mtime. `Ordering` must be in the prelude.

**6. Backpressure, concretely.** A thousand changed files give a thousand `pusher` processes that read via `fs` at once and send a thousand `Put` with file contents to the peer. The peer's mailbox gets a thousand messages with Bytes in them at once. Nothing in the language slows it down. The conventional solution is for `listing` to spawn N pushers at a time and wait for `Acked` before the next batch; that is a counter in `syncer`, ten lines, and nothing in the report shows it is needed. This is the answer to the open question: a credit protocol by convention, and the idiom belongs beside the start message.

**7. Version mixing.** `peer : Address(SyncMsg)` is type-checked on one node. Over the network, if the peer runs an older `SyncMsg` without `Conflict`, nothing in MVP 1 and 2 detects it; `Put` is sent, the peer matches on the wrong type, and what happens is undefined. Erlang has the same problem and does not call it a problem. MVP 3 with hashes makes the type part of the message and can reject on receipt. That is the second argument for MVP 3, after code distribution, and it belongs in the plan.

**8. What did not chafe.** One process per write and per read was natural and freed `syncer` from waiting on `fs`. `listing` as its own phase with a filter that shuts out `Tick` is exactly what selective receive is for, and it could not be expressed any other way without a flag in the state. Pure code (`diff`, `changed`, `snapshot`) was pure and testable without a process.

**9. `Monitor` was untyped in the specification.** The peer's death is detected here only via the timeout in `push`. I wanted to write `monitor peer` in `syncer`, but the specification said `Monitor self` yields a `Down`, and `self : Address(SyncMsg)` cannot receive `Down`. The solution is the same as `via`, now adopted: `monitor : (Address(a), (Down) -> msg) -> () with msg` in the prelude, with a wrapper that turns `Down` into the process's type, and `kill : (Address(a)) -> () with msg`. Then "the runtime understands `Monitor` and `Kill`" is two functions, not two messages an address must receive without having declared them.

**10. System addresses on another node.** The first version had `fs` and `clock` as global names. If `start(Path("b"))` is spawned on node b: which node's `fs`? Dynamic binding per node would be the only one in the language and was rejected. Instead the system addresses are values in `Sys`, which `main` receives and threads; the code above does so. A function that closes over a's `fs` and runs on b talks to a's disk over the network, which is well-defined, and if b's syncer wants b's disk it gets b's `Sys` from the node. The price shows: `sys` is the first argument of six functions.

**11. Records.** `syncer(dir, peer, seen)` with three arguments was fine; with `store`'s six it began to chafe, and a state with five fields would have required named fields. The specification said "records" without saying how. Now: named fields in the constructor, partial patterns, base with `..st`, no generated functions. `Sys.fs` above is what it costs to want a field function: one line.

## Proposals for the Report

- Start message as an idiom for mutual addresses (finding 1).
- The clock takes an address and a value (finding 4). Adopted, then revised: the clock sends `()`.
- `Ordering` in the prelude (finding 5). Adopted.
- Credit protocol as an idiom under backpressure (finding 6).
- Type checking of messages on receipt over the network as an argument for MVP 3 in the plan (finding 7).
- `monitor` and `kill` as prelude functions with a wrapper (finding 9). Adopted.
- System addresses as values in `Sys` (finding 10). Adopted.
- Named fields in the constructor (finding 11). Adopted; later moved from braces to parentheses in the grammar audit, and `let` returned.
- The start message was first called `Peer`; when `Where = Local | Peer(Text)` entered the prelude, the file-local constructor would have shadowed it, and `spawn(Peer("b"), ...)` would have needed qualification. Renamed `Link`. A common word in the prelude takes a seat in every file.
- `Reply(a)` for `FsMsg.Read`, `FsMsg.Write`, and `SyncMsg.Put`'s `ack`; `pusher`, `push`, and `writer` all use `Address.call`, `PushMsg` disappears entirely. `FsMsg.List` remains `Address(...)` because `listing` accepts other messages while waiting for `Listed`. The `store`→`writer` chain drove the spawn-capture rule: `store` receives `ack : Reply(Ack)`, spawns `writer` with `ack` captured, and the linearity check propagates through the spawned function's body. (Adopted 2026-09-13.)
