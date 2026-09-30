# Findings of the first review

The findings of the twelve readers of 2026-09-28 still open, one line each, by area; each is planned in MVP 2.98. The readers: the report's principles (P), the cold reader (K), the register (G), the guide (U), the newcomer (N), the documents (D), the code (C), the Ernest code (E), the tools (T), the diagnostics (X), security (S), the shell's README (H). The 143 lines done by 2026-09-29, each with what was done, are at commit b7d34c0. Each reader's whole list, as it was handed in, stands below the lines, since a line is too short to fix from ([`full_review.md`](full_review.md)); the lists keep the paths and line numbers of the tree they read. This file goes when every line is done or in the plan.

## The guide and the README


## The runtime


## The standard library, the libraries, the examples

- 2.98 — the language: no word of a restart's end, `Tcp.close` and `closeListener` (E-C6..C7)

## The documents


## The readers' lists

The lists of the readers whose findings are still open, each as its reader handed it in on 2026-09-28. A finding's number is its place in its reader's list: P10 is the principles reader's tenth.

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

