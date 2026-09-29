# Reading the shell

The Ernest shell is an Ernest program: `Shell` in [`shell.ern`](shell.ern), six modules under [`shell/`](shell/), and a front end in Erlang for what only the compiler knows. This page guides an Ernest programmer through its code. What the shell does is report §11.2, cited here by the names of its paragraphs. How it is built is the design note, [`docs/shell_design.md`](../docs/shell_design.md), cited by the names of its sections.

## Where to start

Start at `main` in `shell.ern`. The file reads top to bottom, in six parts:

1. **The front end**: the foreign types and functions through which the shell reaches the host.
2. **The session**: the types of all three processes, `main`, and the session's own functions.
3. **Commands**: what a `:` line does.
4. **The screen**: the one process that writes to the terminal.
5. **The reader**: the keys, completion, and documentation.
6. **Line mode**: `lineLoop`, where the shell reads lines rather than keys (§11.2 *Editing*).

Then read the modules in any order. A file's path under the source root `shell/` gives its module's name: `shell/command.ern` there, `shell/shell/command.ern` in the repository, is `Shell.Command`. Each module but `Shell` has its tests at the foot of its file.

## The processes

The comments on the three mailbox types, `ShellMsg`, `ReaderMsg` and `ScreenMsg`, say who sends each message.

- **The session** is `main`, then `keyLoop`, or `lineLoop` in line mode. It holds the `State` and takes one input at a time. It runs an Ernest input in a new process and waits for the run in `await`.
- **The reader** is `reader`, then `readLoop`. It passes a change of the terminal's size to the screen as `Resize`. Every other event from the terminal goes through `Shell.Editor.edit`, whose `Edit` says what to do: show the line, submit it, cancel it, clear the screen, complete, document, or leave.
- **The screen** is `screenLoop`, the only process that writes to the terminal. For each message it writes the bytes its `Shell.Region.Region` gives back. In line mode it runs `plainLoop` instead, which writes text as it comes.

What each process holds, and how the session orders and queues its work, is the design note's *Processes*.

`Typing`, `Clear` and `Leave` are constructors of `Shell.Editor.Edit` and of types in `Shell`, and `State` is a type of both modules. In `shell.ern`, `Shell.Editor.Typing` is the editor's answer and a bare `Typing` is the screen's message.

## Start and end

`main` runs in the order the design note's *Start and end* gives.

- The reader records itself as the terminal's holder (`holdTerminal`) before it subscribes to the keys. In line mode `main` records the session instead.
- Once the sinks are bound to the screen (`setScreen`), `main` says the greeting, which names the version, `:help` and `:quit`. It does so in either mode.
- At a terminal, `main` writes the first `> ` itself, after the startup files. `prompt` writes each later one, after draining the screen. In line mode `lineLoop` writes every prompt through `prompt`, the first among them.

`finish` ends the session, in either mode.

## One input, end to end

At a terminal:

1. A key reaches the reader as `K(event)`, and `Shell.Editor.edit` answers `Submit`.
2. `continues` asks the parser (`needsMore`) whether the input takes another line. It does not, so the reader appends the input to the history (`remember`), sends the screen `Entered` and the session `Typed(text)`, and starts the next line.
3. `keyLoop` receives `Typed`, sends the screen `Taken`, and calls `taking`. `taking` passes a line that is not blank to `submit`, which sends a `:` line to `perform` and any other to `evaluate`.
4. A command: `Shell.Command.parse` answers the action and its argument, or a refusal. `obey` carries out the action.
5. Ernest: `evaluate` calls `run`, which checks the input (`check`) and starts it (`spawnInput`). `await` waits for the run's `Done` and says what it came to. A fault report of the input's own process is its answer too: such a fault is one a signal brought, and no `Done` follows it.
6. `say` sends the screen `Said`, and the screen writes the bytes `Shell.Region.said` gives back.
7. `prompt` drains the screen with a `Flush` call and writes the next `> ` (the design note's *Ordering*).

An input typed while another runs waits in the session's mailbox, and `C-c` kills the run (the design note's *Queueing*).

In line mode `lineLoop` takes the place of steps 1 to 3. It says the fault reports that waited (`pending`), writes the prompt, reads a line with `Io.readLine`, with the lines after it that `moreLines` takes while the parser cannot finish the input, and passes it to `submit` (the design note's *Line mode*).

## The modules

| Module | File | What it is |
|---|---|---|
| `Shell` | [`shell.ern`](shell.ern) | The processes and the front end's declarations: all that sends, receives, or reaches the host, but the history file. |
| `Shell.Command` | [`shell/command.ern`](shell/command.ern) | The table of commands, and the parsing of a command line and of `:set`'s argument. |
| `Shell.Editor` | [`shell/editor.ern`](shell/editor.ern) | The line editor: Readline's Emacs keys, the walk through the history, and the incremental search. |
| `Shell.Complete` | [`shell/complete.ern`](shell/complete.ern) | Completion: what may stand at the cursor, the names that may, gathered from the session and the source root, and matching a word against them. |
| `Shell.Region` | [`shell/region.ern`](shell/region.ern) | The live region at the foot of the terminal, and the bytes each event writes. |
| `Shell.History` | [`shell/history.ern`](shell/history.ern) | The history file, over `Os` and `Fs`. |
| `Shell.Style` | [`shell/style.ern`](shell/style.ern) | The colours. Each function is given whether colour is on. |
| `Markdown` | [`libs/markdown`](../libs/markdown/markdown.ern) | A library, not part of the shell, which renders documentation. |

`Shell` uses all the others. Of the others, only `Shell.Editor` uses another: it reads the history's length, `Shell.History.kept`.

Every module but `Shell`, `Shell.History` and `Shell.Complete` is pure, and `Shell.Complete`'s matching is. `Shell.Editor.State` and `Shell.Region.Region` are abstract (§4.4), so the shell reads them through their modules' functions, such as `Shell.Editor.text`. Each pure module is tested by its `Test` values (§9.3). `make test-shell` runs them with the tests of the session and the terminal (the design note's *Testing*).

## The front end

The shell reaches the host as any program does: through the system modules `Terminal`, `Io`, `Fs`, `Os` and `Clock` (§8.2), and through the standard library's `Process` (E.21). Beyond them it declares `foreign fn`s (§4.7). Each declaration's string names the Erlang function that answers it, whose name may differ: `spawnInput` is `ern_shell:run/3`. [`erl/cli/src/ern_shell.erl`](../erl/cli/src/ern_shell.erl) answers every one but `holdTerminal`, which the runtime answers. The design note's *The foreign interface* groups them by what they are for.

`Env`, `Checked` and `Value` are foreign types (§3.8), handles the shell never looks inside. The session keeps the `Env` in its `State` and passes it to `check`, `spawnInput`, and each command's function that needs it. The reader's questions, such as `names` and `documentation`, take no `Env`. They read the front end's own copy of the session, which the design note's *The front end's copy* explains.

## Idioms to notice

- **`Address(Never)`** is the address of a process that receives nothing, such as an input's. Nothing can be sent to it, but it can be killed (§6.8).
- **A constructor as a function.** `Process.faults(Reported)` delivers each fault report as `Reported(report)` (E.21), and `monitor(reader, ReaderDied)` delivers the reader's end as `ReaderDied(down)`. `via(Wrote, screen)` is the screen's address seen through `Wrote`, so what the sinks send arrives as `Wrote(text)` (§6.5).
- **`Process.fromAddress(a)`** is the process behind an address. It has equality where an address has none. So the session keeps its own processes, whose faults are not reported (§11.2 *Faults*), in a `Set(Process)`, and knows an input's fault by comparing processes.
- **`Address.call` with a `Reply`** is request-reply (§6.6). `drain` calls the screen with `Flush` and waits up to five seconds for its answer.

## Building and trying it

```
make                                        # builds the shell into build/shell
bin/ern shell                               # a session
bin/ern build --build-root build/modules examples/modules
bin/ern shell build/modules/main.erc        # a session beside a running program
bin/ern test build/shell/shell/editor.erc   # one module's tests
make test-shell                             # every module's tests, and the terminal sessions
```
