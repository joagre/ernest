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

`ClockMsg` is the report's; `Ordering` is in the prelude. `Sys.stdout`, `Sys.stderr`, and `Sys.clock` are ambient runtime references (report §8); this paper program additionally assumes the runtime provides `Sys.fs : Address(FsMsg)`. Other assumptions:

- `type Path = Path(Text)`, a filesystem path with helpers `Path.join : (Path, Path) -> Path`, `Path.toText : (Path) -> Text`, and `Path.withSuffix : (Path, Text) -> Path`.
- `Mtime`, an opaque modification time, with `Mtime.compare : (Mtime, Mtime) -> Ordering`.
- `FsError.toText : (FsError) -> Text` for rendering error messages.

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
fn start(dir : Path) -> () with SyncMsg = recv {
    Link(peer) -> { send(self(), Tick); syncer(dir, peer, Map.empty) }
}

// The sync process: one per directory -------------------------

fn syncer(dir : Path, peer : Address(SyncMsg), seen : Map(Path, Mtime)) -> () with SyncMsg = recv {
    Tick -> {
        send(Sys.fs, List(path = dir, reply = via(Listed, self())));
        listing(dir, peer, seen)
    }
  | Put(path = p, mtime = m, bytes = bytes, ack = ack) -> {
        store(dir, seen, p, m, bytes, ack);
        syncer(dir, peer, Map.put(seen, p, m))
    }
  | Listed(_) -> syncer(dir, peer, seen)           // late listing, ignore
  | Link(_)   -> syncer(dir, peer, seen)           // already connected
}

// Between List and Listed: accept Put, but not Tick.
fn listing(dir : Path, peer : Address(SyncMsg), seen : Map(Path, Mtime)) -> () with SyncMsg = {
    let tick = fn() = send(Sys.clock, After(ms = 5000, to = via(fn(_) = Tick, self())));
    recv {
        Listed(Right(entries)) -> {
            List.foreach(diff(seen, entries), fn(c) = { let _ = spawn(Local, fn() = pusher(dir, peer, c)); () });
            tick();
            syncer(dir, peer, snapshot(entries))
        }
      | Listed(Left(e)) -> {
            Io.println("cannot list " ++ Path.toText(dir) ++ ": " ++ FsError.toText(e));
            tick();
            syncer(dir, peer, seen)
        }
      | Put(path = p, mtime = m, bytes = bytes, ack = ack) -> {
            store(dir, seen, p, m, bytes, ack);
            listing(dir, peer, Map.put(seen, p, m))
        }
      | after 10000 -> {
            Io.println("fs is not answering");
            tick();
            syncer(dir, peer, seen)
        }
    }
}

// Store a file from the peer. Newer local file: conflict.
fn store(dir : Path, seen : Map(Path, Mtime), p : Path, m : Mtime, bytes : Bytes, ack : Reply(Ack)) -> () with SyncMsg =
    match Map.get(seen, p) {
        Some(local) when Mtime.compare(local, m) == Greater -> {
            let _ = spawn(Local, fn() = writer(Path.join(dir, conflictPath(p)), bytes, ack, Conflict));
            ()
        }
      | _ -> {
            let _ = spawn(Local, fn() = writer(Path.join(dir, p), bytes, ack, Stored));
            ()
        }
    }

// One process per write: waits for fs and answers the peer.
fn writer(p : Path, bytes : Bytes, ack : Reply(Ack), okAck : Ack) -> () with n =
    match Address.call(Sys.fs, fn(r) = Write(path = p, bytes = bytes, reply = r), 10000) {
        Some(Right(())) -> answer(ack, okAck)
      | Some(Left(e))   -> answer(ack, Failed(e))
      | None            -> answer(ack, Failed(Io("timeout")))
    }

// One process per changed file: reads and sends to the peer.
fn pusher(dir : Path, peer : Address(SyncMsg), Change(path = p, mtime = m) : Change) -> () with n =
    match Address.call(Sys.fs, fn(r) = Read(path = Path.join(dir, p), reply = r), 10000) {
        Some(Right(bytes)) -> push(peer, p, m, bytes)
      | Some(Left(_))      -> Io.println("cannot read " ++ Path.toText(p))
      | None               -> Io.println("fs is not answering: " ++ Path.toText(p))
    }

fn push(peer : Address(SyncMsg), p : Path, m : Mtime, bytes : Bytes) -> () with n =
    match Address.call(peer, fn(r) = Put(path = p, mtime = m, bytes = bytes, ack = r), 30000) {
        Some(Stored)    -> ()
      | Some(Conflict)  -> Io.println("conflict: " ++ Path.toText(p))
      | Some(Failed(e)) -> Io.println("the peer failed: " ++ Path.toText(p))
      | None            -> Io.println("the peer is not answering: " ++ Path.toText(p))
    }

// Start ----------------------------------------------------------

fn main() -> () with () = {
    let a = spawn(Local, fn() = start(Path("a")));
    let b = spawn(Local, fn() = start(Path("b")));
    send(a, Link(b));
    send(b, Link(a))
}
```
