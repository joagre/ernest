# Paper Program 2: File Sync

Written against the Ernest report, September 2026. Two directories are kept identical; changes are sent to the peer; conflicts are saved as an extra file. The peer is an `Address`, and the code is the same whether it lives on the same node or not.

## Assumptions About the Runtime's System Processes

```
type FsMsg
    = List(path : Path, reply : Address(Either(FsError, List(Entry))))
    | Read(path : Path, reply : Reply(Either(FsError, Bytes)))
    | Write(path : Path, bytes : Bytes, reply : Reply(Either(FsError, ())))

type FsError = NotFound | Denied | Io(Text)
type Entry   = Entry(path : Path, mtime : Mtime)
```

`ClockMsg` and `Sys` are the report's; `Ordering` is in the prelude. This paper program additionally assumes:

- `type Path = Path(Text)`, a filesystem path with helpers `Path.join : (Path, Path) -> Path`, `Path.toText : (Path) -> Text`, and `Path.withSuffix : (Path, Text) -> Path`.
- `Mtime`, an opaque modification time, with `Mtime.compare : (Mtime, Mtime) -> Ordering`.
- `FsError.toText : (FsError) -> Text` for rendering error messages.

`sys : Sys` is threaded as the first argument to every function that does IO. Three hand-written field functions, what records would have generated:

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
            List.foreach(diff(seen, entries), fn(c) = { let _ = spawn(Local, fn() = pusher(sys, dir, peer, c)); () });
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
