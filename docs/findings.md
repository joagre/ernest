# Findings of the first review

The findings of the twelve readers of 2026-09-28 still open, one line each, by area; each is planned in MVP 2.98. The readers: the report's principles (P), the cold reader (K), the register (G), the guide (U), the newcomer (N), the documents (D), the code (C), the Ernest code (E), the tools (T), the diagnostics (X), security (S), the shell's README (H). The 143 lines done by 2026-09-29, each with what was done, are at commit b7d34c0. Each reader's whole list, as it was handed in, stands below the lines, since a line is too short to fix from ([`full_review.md`](full_review.md)); the lists keep the paths and line numbers of the tree they read. This file goes when every line is done or in the plan.

## The guide and the README

- 2.98 — the language: no bounded mailbox, and the small things of N-L6 (N-L5, N-L6)

## The runtime


## The standard library, the libraries, the examples

- 2.98 — the language: a list of functions as a binding, `kill` and `monitor` on `Process`, "no limit" unnamed, `Io.debug` a shim, every program's `errorText`, no word of a restart's end, `Tcp.close` and `closeListener` (E-C1..C7)

## The documents


## The readers' lists

The lists of the readers whose findings are still open, each as its reader handed it in on 2026-09-28. A finding's number is its place in its reader's list: P10 is the principles reader's tenth.

### N, the newcomer

Reader c10 (newcomer; README, then the guide alone; program: a TCP chat server)

I did the guide's exercises and ran its programs with `bin/ern`: hello and the §1.4 pair, greet, upper, the shell inputs of §1–§4, counter, queue, resend, message, ping-pong, jobs, the counter service, first([]), the two modules of §7.1, and `ern test`. Each one behaved as the guide says, and the §13 answers matched what I saw. I then wrote the chat server. It works: two `nc` clients see each other's lines, and it also held up under the load tests below. All my files are under `.../scratchpad/readers/c10/`, and the program is `.../readers/c10/chat/chat.ern`. I edited nothing in the checkout. `git status` there shows `ernest_report.md` and `test/ern_docs_tests.erl` as modified, and neither change is mine.

#### Findings on the README and the guide, most serious first

1. **Guide: `Tcp` is never taught, although a server needs it.** §2.9 only lists it ("the system modules `Io`, `Clock`, `Terminal`, `Fs`, and `Tcp`"). §14 points at `webserver.ern`. §9.5 even shows a systemd unit for "The chat server" and a log line `Chat.room:31 faulted`, but no chat server appears anywhere. I learned the module from `:browse Tcp` and `:doc Tcp.*`, which the guide does teach, and those docs are good.
   - **Fix:** add a short worked section on a TCP server: a listen/accept loop, a process per connection, and reading and writing.

2. **Guide §5.5 leads you to expect the wrong I/O model.** It says "the system modules take one [a wrap] wherever something arrives later: `Clock.alarm` … `Terminal.subscribe`." So I expected socket data to arrive in my mailbox. It doesn't: `Tcp.read(sock, ms)` is a blocking pull. That means one process cannot wait for its socket and its mailbox at once, and every connection needs a reader process and a writer process. The guide never says this, and it shapes the whole program. It also never says whether two processes may use one socket at the same time (one blocked in `Tcp.read`, the other calling `Tcp.write`), or what a pending read sees when another process calls `Tcp.close`. I had to try both. Both work: the concurrent use is fine, and the pending read gets `Left(Closed)`.
   - **Fix:** in §5.5, say that `Tcp` is the exception and is pulled by blocking calls. State that a socket may be read and written by different processes.

3. **Guide §8.6 points to a slow way of reading bytes.** It says "A `Bytes` value is read with the `Bytes` module: `Bytes.size`, `Bytes.get` for one octet". My first newline scan used `Bytes.get` and took 16.1 s for 10 MB. The same scan written as a bitstring pattern (`<<10, _:bytes>>` / `<<_, rest:bytes>>`) took 0.13 s. With the first version the server topped out near 3,000 lines/s; with the pattern it reached 23,000 lines/s. (The cause is the per-call overhead in language finding 4.) The guide also says nothing about framing lines over a byte stream.
   - **Fix:** recommend bitstring patterns for scanning, and show a line splitter.

4. **Guide §4.4 "Pacing" does not cover a broadcast to a consumer that stalls.** I found and fixed two unbounded mailboxes:
   - **The room's own mailbox.** At first each reader `send`s its lines to the room. Three clients flooding it built a room mailbox of 123,555 messages. `:processes` then showed about 190 leftover writers, which looked like a leak until `Process.info` showed they were only waiting in that backlog. §4.4's own sentence "A call paces its caller" fixed it: each line became an `Address.callForever`.
   - **A writer's mailbox.** A client that never reads made its writer's mailbox grow from 7,718 to 19,340 queued messages in 4 s. Credits do not apply to a TCP peer. I drop the client when `Process.info(p).queued > 1000`. But §5.2 presents `Process.info` as "for seeing what runs, and a program is still written with the addresses it was given", so I don't know whether this is the intended way.
   - **Fix:** add a paragraph on fan-out to a consumer that may stall, either dropping it or counting acknowledgements.

5. **A compiler message I didn't understand.** `type RoomMsg = Join(Process, Member) | …` gives:
   ```
   chat.ern:9:28: expected `)` instead of `,`
   ```
   The guide does state the rule, but only in one clause of a bullet in §2.3. A programmer from Gleam, Haskell or Rust writes this form first.
   - **Fix:** the message should say "a constructor takes one positional value; name its fields, or carry a tuple `Join(#(Process, Member))`".

6. **Guide §2.9 gives no way to wait indefinitely.** It says "A function that waits takes a timeout in milliseconds last" and that stdin reads wait without a limit. It does not say how a server waits for connections with no limit. In practice `Tcp.accept(l, -1)` and `Tcp.accept(l, 0)` both return `Left(Timeout)` at once, so the accept loop and the read loop must repeat on `Left(Io.Timeout)`.
   - **Fix:** one sentence saying so.

7. **Error text for a user is not covered.** A port already in use prints `chat: cannot listen on port 7440: Other("eaddrinuse")`. The only way I found to show an `Io.Error` was `Io.show`, and the guide doesn't say how to report one.
   - **Fix:** name the idiom, or add a function that turns an `Io.Error` into text.

8. **Guide §9.5: fault lines on a pipe carry a timestamp too.** It says "Where standard error is a file instead, each fault line begins with its time". A pipe also gets the stamp: `ern run jobs.erc 2>&1 | cat` prints `2026-09-28T…Z Jobs.supervise:9 faulted…`. So the §6 transcripts do not match what a reader sees through `| less`.
   - **Fix:** "where standard error is not a terminal or the journal".

9. **README: what put me off.**
   - It has no code at all.
   - The longest of the four "what Ernest adds" bullets is about distribution, which is "planned and not yet built".
   - It assumes you know Gleam and Unison ("Gleam types the channel a message travels on").
   - It gives no clone URL for "a checkout of this repository".
   - **Fix:** a five-line program, and the unbuilt bullet moved last or shortened.

10. **Minor points.**
    - `ern format` re-joined my deliberately split `type RoomMsg` (one constructor per line) into a 97-character line plus a lone `| Gone(Process)`. It follows the style rule, but it reads worse.
    - `Clock.now` is never taught; I only used it for timing.
    - The guide doesn't say that `ern shell prog.erc` cannot pass `Os.arguments`. `:doc Os.arguments` says so.

#### Where the language itself made the program harder than I expected

1. **Sockets are pull-only.** There is no way to wait on a socket and a mailbox together (Erlang has `{active, once}`). So each connection costs two processes, and each member carries a `Process` as its key plus two addresses: its writer and its socket.
2. **Timeouts are mandatory on `accept` and `read`.** Every server writes a loop that repeats on `Left(Io.Timeout)`.
3. **`Bytes` has no search or split.** `String` has `split`, `lines` and `indexOf`, but a chunk can end in the middle of a UTF-8 character, so converting chunks to `String` is unsafe. I wrote the line framing by hand.
4. **Standard library calls are slow.** Measured per call in a loop of 100,000: `Bytes.get` about 1.2 µs, `Bytes.size` about 0.4 µs, `Bytes.slice` about 1.5 µs, `Map.get` about 0.6 µs. An equivalent bitstring pattern costs about 20 ns. So the obvious code is up to 120 times slower than code written with patterns.
5. **No bounded mailbox and no send with a limit.** Protecting a server from a slow client needs `Process.info` polling or hand-written acknowledgements.
6. **Small things I expected from the guide but still found awkward.** With no `if` without `else`, I wrote `if who == from then Unit else send(…)`. Because addresses have no equality, I keep a `Process` beside each address. Named fields are forced as soon as a constructor carries two values.

#### The program: `.../readers/c10/chat/chat.ern`, after `ern format`

```ernest
// A chat server: every line a client sends goes to the other clients.
//
//     ern run chat.erc [port]

type WriterMsg = Out(Bytes) | Close

type Member = Member(name : String, out : Address(WriterMsg), sock : Address(Tcp.SockMsg))

// A client's line is a request, answered once the room has passed it on, so
// that no client sends faster than the room can take its lines.
type RoomMsg =
    Join(who : Process, member : Member) | Said(who : Process, line : Bytes, reply : Reply(Unit))
  | Gone(Process)

// A member whose writer has this many lines waiting reads too slowly to keep.
let backlog : Int = 1000

// The longest line a client may send, in bytes.
let longestLine : Int = 65536

// The room: who is connected, and where each one's lines go.
let room : Address(RoomMsg) = spawn(Local, fn() = roomLoop(Map.empty))

fn roomLoop(members : Map(Process, Member)) -> Unit with RoomMsg =
    receive {
        Join(who = w, member = m) -> {
            broadcast(members, w, String.toUtf8("* " <> m.name <> " joined"));
            roomLoop(Map.put(members, w, m))
        }
      | Said(who = w, line = l, reply = r) -> {
            match Map.get(members, w) {
                Some(m) -> broadcast(members, w, String.toUtf8(m.name <> ": ") <> l)
              | None -> Unit
            };
            answer(r, Unit);
            roomLoop(dropSlow(members))
        }
      | Gone(w) -> match Map.get(members, w) {
            Some(m) -> {
                send(m.out, Close);
                let rest = Map.remove(members, w);
                broadcast(rest, w, String.toUtf8("* " <> m.name <> " left"));
                roomLoop(rest)
            }
          | None -> roomLoop(members)
        }
    }

// Sends the line to every member but the one who said it.
fn broadcast(members : Map(Process, Member), from : Process, line : Bytes) -> Unit with m =
    Map.foreach(members,
                fn(who, member) = if who == from then
                    Unit
                else
                    send(member.out, Out(line <> <<10>>)))

// Disconnects every member whose writer is too far behind, and answers the
// members kept.
fn dropSlow(members : Map(Process, Member)) -> Map(Process, Member) with m = {
    let slow = Map.filter(members, fn(who, _) = lagging(who));
    let kept = Map.filter(members, fn(who, _) = !Map.contains(slow, who));
    Map.foreach(slow, fn(who, member) = {
        kill(member.out);
        Tcp.close(member.sock);
        broadcast(kept, who, String.toUtf8("* " <> member.name <> " was too slow, and left"))
    });
    kept
}

fn lagging(who : Process) -> Bool with m =
    match Process.info(who) {
        Some(info) -> info.queued > backlog
      | None -> false
    }

export fn main() -> Unit with Never =
    match port(Os.arguments) {
        Some(p) -> match Tcp.listen(p) {
            Right(listener) -> {
                Io.println("chat: listening on port " <> Int.toString(p));
                accept(listener)
            }
          | Left(reason) -> {
                Io.printlnError("chat: cannot listen on port "
                                    <> Int.toString(p)
                                    <> ": "
                                    <> Io.show(reason));
                Os.exit(1)
            }
        }
      | None -> {
            Io.printlnError("usage: ern run chat.erc [port]");
            Os.exit(2)
        }
    }

fn port(arguments : List(String)) -> Optional(Int) =
    match arguments {
        [] -> Some(7000)
      | [text] -> String.toInt(text)
      | _ -> None
    }

// Takes each connection as it comes, and gives it a process of its own.
fn accept(listener : Address(Tcp.ListenerMsg)) -> Unit with m =
    match Tcp.accept(listener, 60000) {
        Right(sock) -> {
            let _ = spawn(Local, fn() -> Unit with Never = client(sock));
            accept(listener)
        }
      | Left(Io.Timeout) -> accept(listener)
      | Left(reason) -> Io.printlnError("chat: accept failed: " <> Io.show(reason))
    }

// A client: joins the room, then reads its socket line by line until it
// closes. Its lines go to the room; the room's go to its writer.
fn client(sock : Address(Tcp.SockMsg)) -> Unit with Never = {
    let out = spawn(Local, fn() -> Unit with WriterMsg = writer(sock));
    let who = Process.fromAddress(out);
    let name = match Tcp.peer(sock) {
        Right(end) -> end.host <> ":" <> Int.toString(end.port)
      | Left(_) -> "someone"
    };
    send(room, Join(who = who, member = Member(name = name, out = out, sock = sock)));
    readLines(sock, who, <<>>)
}

// A client's writer: the only process that writes to its socket, and the
// one that closes it.
fn writer(sock : Address(Tcp.SockMsg)) -> Unit with WriterMsg =
    receive {
        Out(bytes) -> {
            Tcp.write(sock, bytes);
            writer(sock)
        }
      | Close -> Tcp.close(sock)
    }

// Reads until the connection closes, or the client sends a line longer than
// `longestLine`; `pending` is what came after the last newline.
fn readLines(sock : Address(Tcp.SockMsg), who : Process, pending : Bytes) -> Unit with m =
    match Tcp.read(sock, 60000) {
        Right(chunk) -> {
            let rest = sayLines(who, pending <> chunk, Bytes.size(pending));
            if Bytes.size(rest) > longestLine then
                send(room, Gone(who))
            else
                readLines(sock, who, rest)
        }
      | Left(Io.Timeout) -> readLines(sock, who, pending)
      | Left(_) -> {
            if Bytes.isEmpty(pending) then Unit else say(who, pending);
            send(room, Gone(who))
        }
    }

// Sends each whole line of `buffer` to the room, and answers what is left
// after the last newline. No newline comes before `from`.
fn sayLines(who : Process, buffer : Bytes, from : Int) -> Bytes with m =
    match newline(Bytes.slice(buffer, from, Bytes.size(buffer)), from) {
        Some(at) -> {
            say(who, Bytes.slice(buffer, 0, at));
            sayLines(who, Bytes.slice(buffer, at + 1, Bytes.size(buffer)), 0)
        }
      | None -> buffer
    }

fn say(who : Process, line : Bytes) -> Unit with m =
    Address.callForever(room, fn(r) = Said(who = who, line = line, reply = r))

// Where the first newline of `bytes` is, counting from `at`.
fn newline(bytes : Bytes, at : Int) -> Optional(Int) =
    match bytes {
        <<10, _:bytes>> -> Some(at)
      | <<_, rest:bytes>> -> newline(rest, at + 1)
      | _ -> None
    }
```

#### Did it work

Yes. It built with `ern build chat.ern` (the first version compiled first time), and `ern format --check` is clean.

- **Two clients with `nc`:** each saw the other's lines, prefixed `host:port:`, plus "joined" and "left" notices.
- **Python clients:** a line sent in two TCP writes arrived joined up, and UTF-8 (`snö och é`) came through intact. 50,000 lines were relayed in 2.2 s.
- **A client that never reads** was dropped as "too slow" and its connection closed, while a reading client still got all 43.6 MB.
- **A line of 100,000 bytes with no newline** made the server close that connection.
- **300 connections opened and closed, half of them with a reset, while three clients flooded the room:** no faults, and `:processes` afterwards shows only `Chat.main` and `Chat.room`.
- **Bad arguments:** a bad port argument exits 2 with a usage line, and a port in use exits 1.

The only thing I took from outside the guide's own text was the `Tcp` API, read through the shell's `:browse` and `:doc`, which the guide teaches.

### E, the Ernest code

C14 reader: the Ernest changed since b4278aa (50 .ern files, ~11,500 lines)

The fork agents could not start because the concurrent-subagent limit was reached, so I read every file myself, rendered the module pages, and ran each doubtful behaviour. The repository is unchanged. My scratch programs are in /tmp/claude-1001/-home-jocke-projects-ernest/5878ddea-cb10-40c7-a354-3f491e030515/scratchpad/readers/c14/.

#### A. Defects, most serious first

1. **String searches match inside a grapheme, and `split` and `replace` lose text.**
   - Where: /home/jocke/projects/ernest/stdlib/string.ern:117 (`indexOf`, which is `ern_string:index_of/2` over `string:find`, /home/jocke/projects/ernest/erl/runtime/src/ern_string.erl:19-35). `split` (290-301), `replace` (160), `contains` and `lines` are built on it.
   - What I ran:
     - `String.split("e\u{301}x", "\u{301}")` gives `["", "x"]`. The `e` is lost.
     - `String.replace("a\r\nb", "\n", "X")` gives `"aXb"`. The CR is lost.
     - `String.indexOf("a\r\nb", "\n")` gives `Some(1)`, but `indexOf(..., "\r")` gives `None`.
     - `String.contains("e\u{301}", "\u{301}")` gives `true`.
   - What is wrong: E.5 says "every search matches whole graphemes".
   - Fix: accept a match only where it starts and ends on a grapheme boundary of the first string, and add these cases as tests.

2. **The Supervisor's restart limit does not limit restarts.**
   - Where: /home/jocke/projects/ernest/stdlib/supervisor.ern:232-244 and 134-141.
   - Cause: a child restarts itself at once through `restarting(unlimited)`, and only afterwards tells the supervisor with an asynchronous `send(sup, Faulted(p))`.
   - What I ran: `OneForOne` with `RestartLimit(restarts = 2, within = 5000)`, and a child that prints and then faults. It printed "child starts" about 200 times, with about 200 "faulted, restarted" lines, before "supervisor restart limit reached". The report's rule allows 3 starts.
   - Second fault in the same code: the count is kept by one alarm per fault, so `within = 0`, which §6.9 says "sets no limit", still gives up. Three children faulting together under `RestartLimit(restarts = 1, within = 0)` ended with "supervisor restart limit reached".
   - Fix: make a fault a call that the supervisor answers (restart or give up) before `f` runs again, and count the window by time the way `restarting` does.

3. **The shell's live region keeps an unfinished line whole, so a line without a line feed costs quadratic time and memory that is never reclaimed.**
   - Where: /home/jocke/projects/ernest/shell/shell/region.ern:80-83 (`wrote` keeps all of `writing`; `split` and `clip` scan it on every write).
   - What I measured:
     - 2000, 4000 and 8000 calls of `Shell.Region.wrote(r, ".")` took 3.2 s, 13.2 s and 54.5 s.
     - At a 24x80 pseudo-terminal, `List.foreach(List.range(1, 6000), fn(_) = Io.print("."))` held up the next answer for about 38 s.
   - Fix: commit the rows of `writing` that are wider than the window as the terminal wraps them, and keep only the last part-row.

4. **`Fs.list` fails for the whole directory when one entry cannot be stat'ed.**
   - Where: /home/jocke/projects/ernest/erl/runtime/src/ern_fs.erl:88-104, behind /home/jocke/projects/ernest/stdlib/fs.ern:96.
   - What I ran: a directory that exists and holds one dangling symlink gives `Fs.list(Path("dangling"), 1000)` = `Left(NotFound)`. A file removed between the listing and its stat does the same.
   - Consequence: it breaks `:load` completion (/home/jocke/projects/ernest/shell/shell.ern:1076) and filesync.
   - Fix: stat each entry with lstat as a fallback, or leave out an entry that has vanished.

5. **Styled Markdown rows leave a terminal style open, and the shell's listing cut then leaks it.**
   - Where: /home/jocke/projects/ernest/libs/markdown/markdown.ern:751-831; /home/jocke/projects/ernest/shell/shell/region.ern:190-203.
   - What I ran:
     - `render(parse("# A long heading here"), 8, Styled)` gives `["\e[1mA long", "heading", "here\e[22m"]`: bold is switched on in the first row and off only in the last.
     - `Shell.Region.typing` with those rows in a 4-row window wrote `"\e[1mA long\nheading\nand 5 more..."`. Bold is never closed, so the prompt and input painted afterwards are bold.
   - Fix: `render` should close and reopen each open style on every row, as `region.ern`'s `wrapped` does.

6. **The editor's cursor counts Chars inserted, while the text is indexed by graphemes.**
   - Where: /home/jocke/projects/ernest/shell/shell/editor.ern:334-339 (`at = at + String.size(what)`, once per key).
   - What I ran:
     - Keys `e` then `U+0301` give text `"é"` with the cursor at 2.
     - Keys 👍, `U+1F3FD`, `x` give two graphemes with the cursor at 3. Backspace then deletes nothing.
   - Fix: set `at` to the size of `slice(text, 0, at) <> what`.

7. **filesync never settles.**
   - Where: /home/jocke/projects/ernest/examples/filesync.ern:64-66 and 89-91.
   - Cause: after storing a file it records the peer's mtime, but the file's own mtime is now the write time. The next tick sees it as changed and sends it back.
   - What I ran: a/f.txt and b/f.txt were rewritten alternately every 5 s for as long as the program ran. The header says "Two directories are kept identical".
   - Fix: record the stored file's own mtime (stat it after writing).

8. **Markdown turns inline HTML at the start of a line into a Raw block, and that line ends the paragraph before it.**
   - Where: /home/jocke/projects/ernest/libs/markdown/markdown.ern:190-201 and 452-460.
   - What I ran:
     - `parse("Some text\n<b>bold</b> more")` gives `[Paragraph([Text("Some text")]), Raw(["<b>bold</b> more"])]`.
     - `parse("<em>hi</em> there")` gives `[Raw(...)]`.
   - What is wrong: G.2 says inline HTML stays in the text. In CommonMark this kind of HTML block (type 7) needs the tag alone on its line, and cannot interrupt a paragraph.
   - Fix: only a tag alone on its line begins an HTML block, and such a line does not interrupt a paragraph.

9. **An unreadable history file is reported twice, and the second report garbles the transcript.**
   - Where: /home/jocke/projects/ernest/shell/shell.ern:267-279 and 838-842 (the reader always starts with `keeping = true`), and 1246-1259 (`remember` reports through `say`/`Said`, which takes the prompt with it).
   - What I ran, at a pseudo-terminal with ~/.ernest/history a directory:
     - `the history could not be read: eisdir`
     - `> the history is not kept: eisdir`
     - `1 + 1`, on a row with no prompt.
   - What is wrong: §11.2 says such a file is "reported once".
   - Fix: start the reader with `keeping = false` when the read failed, and write the note with `Noted`.

10. **Startup files.** Where: /home/jocke/projects/ernest/shell/shell.ern:340-392.
    - (a) When the working directory is $HOME, `$HOME/.ernest/startup` and `./.ernest/startup` are the same file, and every line runs twice. I saw the diagnostic twice and the `let`s run twice; a service in the file would be spawned twice.
    - (b) A command that fails in a startup file is refused without its file and line: `:set depth x` gives only ":set depth takes a number". §11.2 says a failure is reported with the file and line.
    - (c) A startup file that is not UTF-8 is read as empty and nothing is said (line 353).
    - (d) The same file is named by its absolute path in one report and by a relative path in the other; §11.5 wants the path from the working directory.
    - Fix: run a file once by its real path; report command refusals with file:line; say "is not UTF-8".

11. **`List.partition` calls its predicate from the last element first.**
    - Where: /home/jocke/projects/ernest/stdlib/list.ern:304-311.
    - What I ran: `List.partition([1,2,3], fn(n) = { Io.println(Int.toString(n)); n > 1 })` prints 3, 2, 1. `filter`, `span`, `any`, `all` and `find` call it left to right, and the callback may have effects.
    - Fix: evaluate `p(y)` before the recursive call.

12. **`Path.withExtension` on dot-files and on the root.**
    - Where: /home/jocke/projects/ernest/stdlib/path.ern:100-127.
    - What I ran:
      - `withExtension(Path(".bashrc"), "")` gives `Path("")`.
      - `withExtension(Path("dir/.bashrc"), "txt")` gives `Path("dir/.txt")`.
      - `withExtension(Path("/"), "txt")` gives `Path("/.txt")`.
      - `extension(Path(".bashrc"))` gives `Some("bashrc")`.
    - Fix: a name whose only dot is its first character has no extension, and neither does the root. State this in E.14 and on the page.

13. **`Fs.Entry.mtime` is whole seconds.**
    - Where: /home/jocke/projects/ernest/erl/runtime/src/ern_fs.erl:99-101 (`Mtime * 1000` from `{time, posix}`).
    - What is wrong: E.17 and the page say "milliseconds since the epoch, as Clock.now". I saw `1790590774000`, and two writes within one second get equal mtimes.
    - Fix: read millisecond time, or state the resolution.

14. **`String.padStart` and `padEnd` break their promise when the Char joins its neighbours.**
    - Where: /home/jocke/projects/ernest/stdlib/string.ern:188-197.
    - What I ran:
      - `String.size(String.padStart("", 2, '\u{1F1F8}'))` gives 1 (two regional indicators make one flag).
      - `padStart("\u{301}", 2, 'e')` gives `"é"`, of size 1.
    - What is wrong: the page promises "at least that many graphemes long".
    - Fix: pad until the size is reached, or state which Chars the promise excludes.

15. **`Terminal.size`'s page example does not compile where a programmer writes it.**
    - Where: /home/jocke/projects/ernest/stdlib/terminal.ern:88, `Some(Size(rows = rows))`.
    - What I ran: outside the module this gives "unknown constructor Size".
    - Cause: /home/jocke/projects/ernest/erl/runtime/test/ern_doc_tests.erl:55-62 type-checks each example inside the module's own source, so an unqualified or private name passes.
    - I type-checked all 231 standard-library examples from outside their modules; this is the only one that fails.
    - Fix: write `Terminal.Size`, and check examples as a module that depends on this one.

16. **The history trim rewrites the file in place.**
    - Where: /home/jocke/projects/ernest/shell/shell/history.ern:40-48 (`Fs.write`, which is `file:write_file` and not atomic).
    - What is wrong: §11 says "A file a job writes is written whole or not at all." A signal during the trim leaves a truncated history.
    - Fix: write a sibling file and `Fs.rename` it into place.

17. **webserver answers a request it cannot parse with 404.**
    - Where: /home/jocke/projects/ernest/examples/webserver.ern:91-95.
    - What I ran: `"garbage\r\n\r\n"` and a malformed header line both got `HTTP/1.1 404 Not Found`. The right answer is 400 Bad Request.
    - Fix: add `StatusCode.badRequest`.

18. **services: stale line number and a sleep race.**
    - Where: /home/jocke/projects/ernest/examples/services.ern:9-10 says `Services.store:26`, but the run prints `Services.store:24 faulted, restarted: ...`.
    - Also: 62-66 sleep 500 ms so that `callForever` does not meet the restart. Under load it can still fault with "callee was restarted" (see C6).
    - Fix: change the header to 24.

19. **echo monitors a server it never watches.**
    - Where: /home/jocke/projects/ernest/examples/echo.ern:57 and 64 (`spawnMonitored(..., Served)`).
    - What is wrong: the `Down` is never received and `server` is unused. The header says "accepts one connection at a time", but the server accepts exactly one.
    - Fix: use `spawn`, or receive `Served` after closing; correct the header.

20. **repl's header promises recursion.**
    - Where: /home/jocke/projects/ernest/examples/repl.ern:4-6, "functions of one argument, and recursion".
    - What I ran: `let f = fun n -> f n` then `f 1` gives "error: unbound f".
    - Fix: drop the claim, or bind the name in the closure's environment.

21. **Markdown puts a lazy line after a heading into the quote.**
    - Where: /home/jocke/projects/ernest/libs/markdown/markdown.ern:337-354.
    - What I ran: `parse("> # Heading\nlazy")` gives `Quote([Heading, Paragraph("lazy")])`. In CommonMark the paragraph is outside the quote.
    - Fix: `continues` must require that the line before was paragraph text.

22. **Markdown expands tabs inside code content.**
    - Where: /home/jocke/projects/ernest/libs/markdown/markdown.ern:213-220, applied to every line.
    - What I ran: a fenced block containing `"\tx"` gives the line `"    x"`. CommonMark keeps tabs in code content, so a Makefile snippet is changed.
    - Fix: expand tabs only where they decide the block structure.

#### B. Clarity, surprise, and page gaps

1. **Tcp page.**
   - /home/jocke/projects/ernest/stdlib/tcp.ern:3-4 says "after its connection closes, from either end, each read answers Left(Closed)". After the program's own `Tcp.close`, a read faults instead (I saw "faulted: callee returned without answering").
   - `read`, `accept`, `port`, `peer` and `local` fault on an ended socket or listener (E.18) but have no Errors section; only `write` has one.
   - `ListenerMsg`'s example `Either.map(Tcp.listen(0), fn(l) = l)` is the identity and leaks a listener.

2. **Fs page.** /home/jocke/projects/ernest/stdlib/fs.ern:1-5 leaves out:
   - the U+0000 rule;
   - that a name that is not UTF-8 is left out of `list`;
   - that a relative path is resolved against `Os.workingDirectory`;
   - that a write, rename or remove that times out may still happen;
   - what `Other(text)` holds: the host's errno name, such as `"eexist"` for a directory that is not empty, `"eisdir"` or `"enotdir"`.

3. **Os page.** /home/jocke/projects/ernest/stdlib/os.ern:169-173, 201-204 and 273-277 put `Left` answers in Errors sections. Shape rule 6 keeps Errors for faults, and Fs puts its `Left`s in the prose. `start`'s list also lacks E.23's `Left(Other(text))`.

4. **Shape rule 6 gaps elsewhere.**
   - No Ets function has an Errors section, though every one faults on a table that is gone.
   - `Ets.Table`, `Random.Seed` and `Supervisor.Msg` have no Examples section.

5. **String page.**
   - The module doc's list of primitives leaves out `graphemes`, which E.5 names.
   - `toFloat` says "the float literal form of report §2.5". §2.5 allows `_`, but `toFloat("1_0.5")` is `None`. E.5's "without _", the finite-range rule and the subnormal rule are missing from the page.
   - `lines` does not say that `""` has no lines.

6. **Map and Set pages.**
   - `Map.toList`, `keys` and `values` do not state their order, so `:doc Map.toList` never says it is unspecified.
   - The order in which `map`, `filter`, `filterMap`, `any`, `all` and `mergeWith` call their callbacks is unstated.
   - Set's examples show a definite order (`union` gives `// => [1, 2]`) for results the page calls unordered.

7. **Wrong citation in Either.** /home/jocke/projects/ernest/stdlib/either.ern:96 cites "Appendix E.0 rule 4", which is admission rule 4 (compositions). The rule meant is shape rule 4.

8. **Page and report disagree on `Erl.atom`.** /home/jocke/projects/ernest/stdlib/erl.ern:77-80 shows `// => ready`. E.1 says a representation that reads as nothing in Ernest prints as `<foreign>`. One of them is wrong.

9. **`Process.faults` doc.** /home/jocke/projects/ernest/stdlib/process.ern:107-109, "It is no source that can deliver (report §8.6)". Say instead: "a subscription does not keep a deadlock from being detected".

10. **Supervisor page.**
    - The module example (supervisor.ern:35-38) uses a mailbox of bare `Reply(Int)`. A reader expects `Get(reply : ...)`.
    - `child`'s Errors section tells users about "MVP 3.0".

11. **`compare` is written with `<`.** /home/jocke/projects/ernest/stdlib/string.ern:89, char.ern:117, int.ern:178 and float.ern:82 define `compare` with `<`, and §3.10 defines `<` through `T.compare`. §9.6's "names the runtime's operation" covers operators only, so the report is silent here. There are also two spellings: `== then Equal` in String, `> then Greater` in the others.

12. **Tcp.write and others wait with no timeout, which shape rule 8's exceptions do not name.** `Tcp.write`, `Os.write`, `Os.read` and `Io.print` all wait. A `Tcp.write` to a client that stops reading blocks its handler forever, which leaks it in the webserver.

13. **`:type` of a declaration.** /home/jocke/projects/ernest/shell/shell.ern:613-621: `:type fn f() = 1` prints `fn f() = 1 : Unit`, and `:type type T = A | B` prints `: Unit`.

14. **NO_COLOR.** /home/jocke/projects/ernest/shell/shell.ern:301 colours when NO_COLOR is set to `""` (the no-color.org rule). §11.2 says "where the environment does not set NO_COLOR", and the comment says "to anything". Pick one rule and state it.

15. **The shell's colour choice is a Bool.** /home/jocke/projects/ernest/shell/shell/style.ern:10-45 (`fault(on : Bool, ...)` and the rest) is the `render(doc, false)` form that shape rule 9 refuses. The shell then converts it to `Markdown.Style` with `styleOf`; one type would do.

16. **"tail" versus "live region".** /home/jocke/projects/ernest/shell/shell/command.ern:68 and the `:output` answer say "the tail"; §11.2 says "the live region".

17. **The shell's module pages are bare.** Its exported declarations are documented with `//` comments, so `ern doc` renders signatures with no prose. Use `///`.

18. **template.** /home/jocke/projects/ernest/examples/template.ern: `checked(diameter)` computes a radius, not a check. The private `half` is rendered as `## ...Template.half` with nothing saying a caller cannot call it.

19. **webserver.** /home/jocke/projects/ernest/examples/webserver.ern:195 has the banner "Abstract-type definitions" over two private types that are not abstract, and `SessionId.parse("")` accepts an empty id.

20. **snake.** /home/jocke/projects/ernest/examples/snake.ern:56-77: without a terminal it says it needs one, then draws a frame with clear-screen escapes to stdout and exits 0. `Interrupt` (C-c) is ignored (line 111). The header says "multiplayer" but the program has one player.

21. **tools/manual.ern.** /home/jocke/projects/ernest/tools/manual.ern:73-88 builds Markdown text (`"**" <> n <> "**(3ern)"`) only to parse it back. It can build the blocks directly.

#### C. Where the language made the code harder

1. **A list of functions cannot be a top-level binding.** /home/jocke/projects/ernest/libs/markdown/markdown.ern:166-169: the block-starter list is `fn starts()` because a `let` naming functions that refer back to it is a §8.5 cycle. The list is rebuilt for every line.

2. **`kill` and `monitor` take `Address(a)`, not `Process`.** So the supervisor's watcher carries two closures per child, `stop` and `watch` (/home/jocke/projects/ernest/stdlib/supervisor.ern:63-80 and 236), as a way to hold children of different mailbox types.

3. **"No limit" has no name.** It is spelled `RestartLimit(restarts = 1, within = 0)` (supervisor.ern:246-248), a meaning that is invisible at the use site.

4. **`Io.show` depends on the type at the call.** So `Io.debug` cannot be written in Ernest and is a shim that builds Io's private `Write` message in Erlang (/home/jocke/projects/ernest/erl/runtime/src/ern_io.erl:19-23). A generic `fn f(x) = Io.show(x)` prints a Char as its Int.

5. **Every program writes its own `Io.Error` text table.** The same `errorText` is in filesync.ern:159-168 and webserver.ern:184-193, and the shell has a third (`trouble`, shell.ern:366-375). `Other` carries raw errno names, so none of them can word those cases.

6. **Nothing tells a program that a supervisor's restart has finished.** services.ern:62-66 sleeps 500 ms instead.

7. **No overloading, so one operation gets two verbs.** `Tcp.close` and `Tcp.closeListener` (shape rule 2).

8. **`Bytes.slice` is a shim though the bit syntax can express it.** /home/jocke/projects/ernest/stdlib/bytes.ern:68-74 uses `binary:part/3`, but `<<_:size(s)-bytes, p:size(n)-bytes, _:bytes>>` does the same job. E.20 names it a primitive, while CLAUDE.md admits a shim only where Ernest cannot express the work. `Bytes.get` is the same case.

