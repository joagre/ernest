# Reading the shell

The Ernest shell is an Ernest program: `Shell` in [`shell.ern`](shell.ern), six modules under [`shell/`](shell/), and a front end in Erlang for what only the compiler or the host can answer. This page guides an Ernest programmer through its code. What the shell does is report §11.2, cited here by the names of its paragraphs. How it is built is the design note, [`docs/design/shell.md`](../../docs/design/shell.md), cited by the names of its sections and paragraphs.

## Where to start

Start at `main` in `shell.ern`. The file reads top to bottom, in seven parts:

1. **The session**: the types of every process and the front end's handles, `main`, `attach`, the session's start, `session`, and its own functions.
2. **Commands**: what a `:` line does, but `:output`'s `output` and `cannotWrite`, which stand in the session's part after `trouble`, among the startup files' functions.
3. **The screen**: the one process that draws.
4. **The reader**: the keys, completion, and documentation.
5. **Line mode**: `lineLoop`, where the shell reads lines rather than keys (§11.2 *Editing*).
6. **The local half**: `localHalf`, on the shell's own node, which holds the terminal and the operator's files.
7. **The front end**: the foreign functions through which the shell reaches the host.

Then read the modules in any order. A file's path under the source root, `src/shell/`, gives its module's name: `shell/command.ern` there, `src/shell/shell/command.ern` in the repository, is `Shell.Command`. Each module but `Shell` has its tests at the foot of its file.

## The processes

The comments on the mailbox types, `ShellMsg`, `ReaderMsg`, `ScreenMsg`, `LocalMsg` and `LinesMsg`, say who sends each message.

- **The session** is `session`, then `keyLoop`, or `lineLoop` in line mode. It holds the `State` and takes one input at a time. It runs an Ernest input in a new process and waits for it in `await`. A plain shell's `main` spawns the local half and waits for what it read, `Begun`; an attached shell's session is spawned on the node by `attached`, the root of its chain, which lives while it does.
- **The local half** is `localHalf`, then `attaching` and `served`, on the shell's own node. It holds the terminal, reads what the session needs, starts the session, and then forwards each key, writes what the screen sends, and reads and appends the operator's files. In line mode `linesRead`, its reader of lines, reads a line each time the session asks.
- **The reader** is `readLoop`, which receives a key the local half forwards and hands it to `read`. It passes a change of the terminal's size to the screen as `Resized`. Every other event from the terminal goes through `Shell.Editor.edit`, whose `Edit` says what to do: show the line, show the bracket a closing one closes, submit it, cancel it, clear the screen, complete, document, or leave. `matching` stands the cursor on that bracket and waits for the next key, or half a second, before it puts it back.
- **The screen** is `screenLoop`, the only process that draws. For each message that changes what is shown it sends the local half the bytes `Shell.Region`'s function for that message gives back, and it holds where `:output` sends what programs write, which the local half appends there in place of the terminal. In line mode it runs `plainLoop` instead, which sends text as it comes.

What each process holds, and how the session orders and queues its work, is the design note's *Processes*.

`Terminal.Resized` is the terminal's event and a bare `Resized` in `shell.ern` the screen's message, which the reader sends on taking the event.

## Start and end

`main` runs in the order the design note's *Start and end* gives.

- `keysHeld` has the local half record itself as the terminal's holder (`holdTerminal`) and subscribe to the keys where standard output has a size, and line mode is chosen where there is no size or the subscription is refused. In line mode the local half's reader of lines records itself as the holder instead.
- The local half reads the startup files and the history, and gives the session what it read, a `Desk`: by `Begun` in a plain shell, and in an attached one in its spawn of `attached` on the peer.
- The session spawns its screen and, at a terminal, its reader (`keysRead`), and tells the local half the address its keys go to and the screen's process, which its node's own output goes to, `Attached`, a call; the local half binds its node's sinks to the screen (`setScreen`). Then the session says the greeting, which names the version, `:help`, and `:quit` or `:detach`. It does so in either mode.
- `prompt` writes every `> `, after draining the screen: at a terminal `main` calls it after the startup files, `taking` after each input and `keyLoop` after `C-c`; in line mode `lineLoop` calls it before each line, and `moreLines` writes `... ` itself.

At a terminal `leave` ends the session: `reportRemaining` writes the faults reported until then, and `finish` takes the region away. In line mode `leaveLines` ends it, since the end of input and `:quit` come at a prompt whose line no input ended: it ends that line, and then `reportRemaining` writes the faults. A startup file's `:quit` comes before any prompt, and `leave` ends the session then, in either mode. An attached session then `detached`: its reader and screen end, and the front end's `detach` leaves what it started to the node; the local half's `sessionEnded` ends the screen where it last drew, but after a detach, and gives the runner its line and status (`endWith`).

## One input, end to end

At a terminal:

1. A key reaches the local half as `Pressed(event)`, which forwards it to the reader as `Key(event)`, and `Shell.Editor.edit` answers `Submit`.
2. `continues` asks the parser (`needsMore`) whether the input takes another line. It does not, so the reader has the local half append the input to the history (`remember`), sends the screen `Entered` and the session `Typed(text)`, and starts the next line.
3. `keyLoop` receives `Typed`, sends the screen `Taken`, and calls `taking`. `taking` passes a line that is not blank to `submit`, which sends a `:` line to `perform` and any other to `evaluate`.
4. A command: `Shell.Command.parse` answers the action and its argument, or a refusal. `obey` carries out the action.
5. Ernest: `evaluate` calls `execute`, which checks the input (`check`) and starts it (`spawnInput`). `await` waits for the input's `Done` and says what it came to. A fault report of the input's own process is its answer too: such a fault is one a signal brought, and no `Done` follows it.
6. `say` sends the screen `Said`, and the screen writes the bytes `Shell.Region.said` gives back.
7. `taking` calls `prompt`, which drains the screen with a `Flush` call and writes the next `> ` (the design note's *Ordering*).

An input typed while another runs waits in the session's mailbox, and `C-c` kills the run (the design note's *Queueing*).

In line mode `lineLoop` takes the place of steps 1 to 3. It says the fault reports that waited (`reportPending`), writes the prompt, asks the local half for a line (`nextLine`), and says the reports that came while it waited. `takingLine` then passes the line, with the lines after it that `moreLines` takes while the parser cannot finish the input, to `submit` (the design note's *Line mode*).

## The modules

| Module | File | What it is |
|---|---|---|
| `Shell` | [`shell.ern`](shell.ern) | The processes and the front end's declarations: all that sends, receives, or reaches the host, the local half among them, but the person's directory and the history file in it, and the questions `Shell.Complete` asks of the front end. |
| `Shell.Command` | [`shell/command.ern`](shell/command.ern) | The table of commands, and the parsing of a command line and of `:set`'s argument. |
| `Shell.Editor` | [`shell/editor.ern`](shell/editor.ern) | The line editor: Readline's Emacs keys, the walk through the history, and the incremental search. |
| `Shell.Complete` | [`shell/complete.ern`](shell/complete.ern) | Completion: what may stand at the cursor, the names that may, gathered from the session and the source root, and matching a word against them. |
| `Shell.Region` | [`shell/region.ern`](shell/region.ern) | The live region at the foot of the terminal, and the bytes each event writes. |
| `Shell.History` | [`shell/history.ern`](shell/history.ern) | The person's directory and the history file in it, over `Os` and `Fs`. |
| `Shell.Style` | [`shell/style.ern`](shell/style.ern) | The colors. Each function is given `Markdown.Styled` or `Markdown.Plain`, as documentation is rendered. |
| `Markdown` | [`libs/markdown`](../libs/markdown/markdown.ern) | A library, not part of the shell, which renders documentation. |
| `Ansi` | [`libs/ansi`](../libs/ansi/ansi.ern) | A library, not part of the shell, which writes the terminal's styles and the cursor's moves. |

`Shell` uses all the others but `Ansi`, which `Shell.Region`, `Shell.Style` and `Markdown` write with. Of the others, three use another: `Shell.Editor` reads the history's limit, `Shell.History.kept`; `Shell.Complete` reads `Shell.Command`'s table, what each command takes and where its word ends; and `Shell.Style` takes a `Markdown.Output`.

Every module but `Shell`, `Shell.History` and `Shell.Complete` is pure, and `Shell.Complete`'s matching is. `Shell.Editor.Editing` and `Shell.Region.Region` are abstract (§4.4), so the shell reads them through their modules' functions, such as `Shell.Editor.text`. Each module but `Shell` is tested by its `Test` values (Appendix E.24, §11.2), the impure ones' tests reaching their pure parts. `make test-shell` runs them with the tests of the session and the terminal (the design note's *Testing*).

## The front end

The shell reaches the host as any program does: through the system modules `Terminal`, `Io`, `Fs`, `Os` and `Clock` (§8.2), and through the standard library's `Process` (E.21). Beyond them it declares `foreign fn`s (§4.7). Each declaration's string names the Erlang function that answers it, whose name may differ: `spawnInput` is `ern_shell:run/4`. [`erl/cli/src/ern_shell.erl`](../../erl/cli/src/ern_shell.erl) answers every one but `holdTerminal`, `markOwn` and `waitForDeliveries`, which the runtime answers. `Shell.Complete` declares its own questions of the front end, `names` among them, after `sourceModules` in `complete.ern`. The design note's *The foreign interface* groups them by what they are for.

`Session`, `Checked`, `Value` and `Bound` are foreign types (§3.8), handles the shell never looks inside. The session process keeps the `Session` in its `State` and passes it to `check`, `spawnInput`, `collect`, with the `Bound` an input's outcome carries, what the input bound, and each command's function that needs it. The reader's questions, such as `names` and `documentation`, take no `Session`. They read the front end's own copy of the session, which the design note's *The front end's copy* explains.

`start` begins the session on its node with its local half's address, its screen's process, the operator's source root and working directory, and whether it is attached; `detach` ends an attached one. The local half's own are `givenSourceRoot` and `attachTo`, what the runner was given, and `endWith`, its status and line, which the runner says at the end; `decoded` is the screen's, which turns a program's bytes into text and keeps a character a write cut.

## Idioms to notice

- **`Address(Never)`** is the address of a process that receives nothing, such as an input's. Nothing can be sent to it, but it can be killed (§6.8, §6.5).
- **A constructor as a function.** `Process.faults(Reported)` delivers each fault report as `Reported(report)` (E.21), and `monitor(Process.fromAddress(reader), ReaderDied)` delivers the reader's end as `ReaderDied(down)`. `adapted(given, Key)` is the reader's address seen through `Key`, so each event the local half forwards arrives as `Key(event)` (§6.5).
- **`Process.fromAddress(a)`** is the process behind an address. It has equality where an address has none. So the session keeps its own processes, whose faults are not reported (§11.2 *Faults*), in a `Set(Process)`, and knows an input's fault by comparing processes.
- **`Address.call` with a `Reply`** is request-reply (§6.6). `drain` calls the screen with `Flush` and waits up to five seconds for its answer.

## The shell's own names

The names that recur across the shell's modules beyond those [`guide/style.md`](../../guide/style.md) gives every program, `cursor`, `serial`, `color`, `rows` and `typedWord`, are the toolchain's glossary's, [`docs/style.md`](../../docs/style.md)'s *Ernest*.

## Building and trying it

```
make                                        # builds the shell into build/shell
bin/ern shell                               # a session
bin/ern build --build-root build/modules test/fixtures/programs/modules
bin/ern shell build/modules/main.erc        # a session beside a running program
bin/ern test build/shell/shell/editor.erc   # one module's tests
bin/ern test build/shell/shell/style.erc    # with the libraries, which the load path holds
make test-shell                             # every module's tests, and the terminal sessions
```
