# Reading the shell

The Ernest shell is an Ernest program. It runs as three processes, is split into seven modules, and has a front end in Erlang for what only the compiler knows. This page is a guide for an Ernest programmer who wants to read it. What the shell does is report §11.2; why it is built as it is, [`docs/shell_design.md`](../docs/shell_design.md). This page says where things are and how they fit together.

## Where to start

Start at `main` in [`shell.ern`](shell.ern). The file reads top to bottom:

1. **The front end**: the `foreign type`s and `foreign fn`s the shell reaches in the host.
2. **The session**: the types of all three processes, then `main`, then the session's own functions: running an input, the startup files, and the loop that waits for input.
3. **Commands**: what a `:` line does.
4. **The screen**: the one process that writes to the terminal.
5. **The reader**: the keys, the line editor, completion, and documentation.
6. **Line mode**: without a terminal there is no reader, and the session reads lines itself.

Then read the modules under [`shell/`](shell/) in any order. A file's path is its module's name: `shell/command.ern` is `Shell.Command`. Every module but `Shell` and `Shell.History` is pure, and each has its tests at the foot of its file.

## Three processes

- **The session** holds the `State`: the front end's environment, the settings of `:set`, and whether to colour. It takes one input at a time. It checks the input, runs it in a process of its own, and waits in `await` for the run to end. Its mailbox is `ShellMsg`.
- **The reader** owns the keys. It holds a `Reading`, which is mostly the line being edited. Each key goes through `Shell.Editor.edit`, and the `Edit` it answers says what to do: show the line, send the input, cancel it, clear the screen, complete, document, or leave. Its mailbox is `ReaderMsg`, the terminal's events wrapped in `K`.
- **The screen** is the only process that writes to the terminal. The session, the reader, and running programs all send it text. It keeps a `Shell.Region.Region` and writes the bytes the region gives back. Its mailbox is `ScreenMsg`. Without a terminal it runs `plainLoop` instead, which writes text as it comes.

The three message types, `ShellMsg`, `ScreenMsg` and `ReaderMsg`, stand at the top of `shell.ern`; their comments say what each message means and who sends it.

The same short names recur across modules. `Typing`, `Clear` and `Leave` are both `Shell.Editor.Edit` constructors and `Shell`'s own, and `State` is a type in `Shell` and in `Shell.Editor`. A name qualified with its module is that module's. An unqualified name is the file's own, or else the prelude's: `Event`, `Size`, `Down`, `IoError`, `Path`, and `Test` are the prelude's. The prelude also declares an `Entry`, so a module that declares its own writes the prelude's as `Prelude.Entry`.

### Start and end

`main` calls `mine()` first. So does each process it spawns. The shell's own processes are then left out of the fault reports and `:processes`. `main` then does the following, in order:

1. It spawns the screen.
2. It sends what programs write to the screen as `Wrote` (`setScreen`).
3. It watches for deaths (`watchDeaths`).
4. It starts the file's entry point, if the shell was started with one (`program`).
5. It reads the history.
6. It spawns the reader, which subscribes to the terminal and sends `Ready`.
7. It records the reader as the terminal's holder (`holdTerminal`), so that an input asking for the keys faults rather than taking them. It monitors the reader.
8. It waits for `Ready`, runs the startup files, and writes the first prompt.

`finish` ends the session. It takes the region away with `Height(0)` and an empty `Typing`, leaves the cursor on a fresh line, and drains the screen.

### One input, end to end

1. A key reaches the reader as `K(event)`, and `Shell.Editor.edit` answers `Submit(state)`.
2. `continues` asks the parser whether the input needs another line. It does not, so the reader appends the input to the history (`remember`). It sends `Entered` to the screen, which commits the line to the transcript, and `Typed(text)` to the session. Then it starts the next line with `Shell.Editor.next`.
3. The session's `keyLoop` receives `Typed`. It sends `Taken` to the screen and calls `taking`, which skips a blank line and calls `submit`. `submit` sends a `:` line to `perform` and anything else to `evaluate`.
4. A command: `Shell.Command.parse` gives the action and its argument, or the text of a refusal. `obey` carries out the action.
5. Ernest: `run` checks the input through the front end (`check`) and starts it with `spawnInput`. `await` then waits for `Done(Ok(...))` or `Done(Faulted(...))`, and prints the value and its type with `say`.
6. `say` sends `Said(text)` to the screen. The screen passes it to `Shell.Region.said` and writes the bytes it gets back.
7. `prompt` drains the screen with a `Flush` call before it writes the next `> `. A program's text reaches the screen from the program's own processes, not through the session, so without the drain the prompt could come before it.

While an input runs, the reader goes on reading keys. `await` receives only `Done`, `Interrupted` and `Died`. So an input typed meanwhile, or `Eof`, stays in the mailbox and is taken after the run. `C-c` travels the other way. The editor answers `Cancel`, and the reader sends `Entered` to the screen and `Interrupted` to the session. `await` kills the input's process and says `Killed`. The run's own `Done` may still arrive after that, and `keyLoop` drops it.

## The modules

| Module | File | What it is |
|---|---|---|
| `Shell` | [`shell.ern`](shell.ern) | The three processes and the front end's declarations. Everything that sends, receives, or reaches the host is here, except the history file. |
| `Shell.Command` | [`shell/command.ern`](shell/command.ern) | The table of commands, in one place: what each does, what it takes, what completes after it, and its help line. It also parses a command line and a `:set` argument. |
| `Shell.Editor` | [`shell/editor.ern`](shell/editor.ern) | The line editor. It takes a `State` and an `Event` and gives an `Edit`. It implements Readline's Emacs keys, the walk through the history, and the incremental search. |
| `Shell.Complete` | [`shell/complete.ern`](shell/complete.ern) | Completion: it matches a word against names, by prefix and by the starts of their words, and finds what the candidates share. |
| `Shell.Region` | [`shell/region.ern`](shell/region.ern) | The live region at the foot of the terminal. Each event takes the region and gives the region after it and the bytes to write. |
| `Shell.History` | [`shell/history.ern`](shell/history.ern) | The history file, over `Fs`: reading it, trimming it, appending to it, and the escaping that keeps each input on one line. Only the file's path is `foreign`. |
| `Shell.Style` | [`shell/style.ern`](shell/style.ern) | The colours. Each function takes whether colour is on. Without colour the text is unchanged, except that a marked parameter is put between asterisks. |
| `Markdown` | [`libs/markdown`](../libs/markdown/markdown.ern) | A library, not part of the shell. It renders documentation for `:doc` and `Shift-Tab`. |

`Shell` uses all the others. The others use only the standard library, and none of them uses another, so `Shell` is the hub.

## The pure core

Every part follows the same design: the decisions are pure functions, and the processes only carry messages and write bytes.

- `Shell.Editor.edit` does not draw. It returns an `Edit` that says what the reader should do.
- `Shell.Region` does not write. Each event function returns `#(Region, String)`, the next region and the escape sequences to write, and the screen process writes them.
- `Shell.Command.parse` refuses nothing itself. It returns `Either(String, #(Action, String))`, and the session says the refusal.
- `Shell.Complete.complete` does not know where names come from. The reader passes in the names, and a `Where` that says what may stand at the cursor. After a command the reader gives `Anything`. Elsewhere it asks the parser (`context`).

Two of the types are abstract (§4.4): `Shell.Editor.State` and `Shell.Region.Region`. The shell holds them and hands them back, and only their own modules take them apart, so the editor alone keeps the cursor inside the line and the region alone keeps the tail within its rows.

So each of these modules is tested by its `Test` values (§9.3). They are top-level `let`s of type `Test`, found by their type, wherever they stand. `ern --test` runs them, and `make test-shell` runs them for every module. The pure tests cannot reach the wiring between the processes. `test/ern_shell_tests.erl` covers that by running the shell under a pseudo-terminal (`test/ern_pty.py`).

## The front end

The shell reaches the host through `foreign fn`s (§4.7). Almost all of them are at the top of `shell.ern` and are answered by `erl/cli/src/ern_shell.erl`. Two are elsewhere. `holdTerminal` is the runtime's (`ern_rt`), and `Shell.History.file` declares the history file's path. The rule for what may be `foreign` is that it is only what the host alone can do. That covers the compiler's work: checking an input against the session, compiling and running it, reading the compiled interfaces for completion, and finding a name's documentation. The matching, the ranking, the rendering, the history file, and the parsing of commands are Ernest.

The session's state lives in two places:

- `Env` is the environment an input is checked against. The shell holds it in its `State` and passes it to `check`, `load`, `reload`, `forget`, `bindings`, `browse` and `doc`.
- The front end keeps its own copy of the session, for the reader. The reader completes and documents while an input runs, when the session cannot answer. `names`, `sessionNames`, `sessionTexts` and `documentation` read that copy. `processes` reads the runtime's table of live processes, and `faults` the watcher's record. None of them takes an `Env`.

`Env`, `Checked` and `Value` are foreign types (§3.8). The shell passes them back to the front end and never looks inside them. A `foreign fn` without `with m`, such as `typeText` or `show`, is pure: it only computes from its arguments.

## Idioms to notice

- **A loop is a function that receives and calls itself** with the next state, as in `screenLoop(next)` and `keyLoop(state2, screen)`. `receive` is an expression, so the screen writes `let #(next, bytes) = receive { ... }`.
- **Records.** The state is a record, read with a pattern that names only the fields it needs: `let State(env = env, colour = colour) = state;`. A record is updated with `..`: `State(..state, env = env2)`. A parameter may be a pattern too: `fn nameOf(Command(name = name) : Command)`.
- **`with ShellMsg`** in a signature says that the function acts through a process whose mailbox is `ShellMsg`: it receives there, or calls something that does. `with m` says that it uses its process, to send or to call the host, and runs in a process with any mailbox. A signature with neither is pure. See §6.1.
- **`spawn(Local, fn() = ...)`** starts a process on this node. The loop it calls fixes its mailbox type.
- **`Address(Never)`** is the address of a process that receives nothing, such as the input's process. No value has type `Never`, so nothing can be sent to it, but it can be killed and monitored (§6.8).
- **`via(Died, self())`** is the session's address seen through `Died`, so a `Down` sent there arrives as `Died(down)` (§6.5). `monitor(reader, ReaderDied)` wraps the reader's `Down` the same way.
- **`Address.call` with a `Reply`** is request-reply (§6.6). The caller passes a function that builds the message around the reply. `drain` uses it to wait until the screen has written everything sent before.
- **`<>`** joins strings and lists alike, and `#(a, b)` is a tuple.
- **Top-down layout**: types first, then `main`, and each function's helpers right after it ([`docs/style.md`](../docs/style.md)).

## Building and trying it

```
make                                          # builds the shell into build/shell
bin/ern --shell                               # a session
bin/ern --shell build/main.erc                # a session beside a running program
bin/ern --test build/shell/shell/editor.erc   # one module's tests
make test-shell                               # every module's tests, and the terminal sessions
```
