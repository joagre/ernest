# The Ernest Shell: Design

How `ern shell` is built. What the shell does is report §11.2, cited here by the names of its paragraphs, *Inputs*, *Scope*, *Editing* and the rest; how its code reads is [`shell/README.md`](../shell/README.md); why it is built so, and how it came to be, is the decisions log's; when each part was built is the plan's.

## Shape

The shell is an Ernest program over a front end in Erlang. Its source is a tree of its own, `shell/`, beside `stdlib/` and `examples/`, which `make` compiles into `build/shell/`, where `ern shell` finds it. It is the toolchain's own program: not standard library, and not a library under `libs/`.

`Shell`, in `shell/shell.ern`, holds the processes and the front end's declarations: everything that sends, receives, or reaches the host, but the history file. The decisions are pure functions in modules of their own, each tested by its `Test` values (§9.3): `Shell.Editor` decides what a key does, `Shell.Region` what the screen shows, `Shell.Complete` what a word completes to, `Shell.Command` what a command line selects, and `Shell.Style` how a line is coloured. `Shell.History` reads and writes the history file. A process only carries messages and writes bytes.

## Processes

The shell runs as three processes of its own, and each input in one more.

- **The session** is the entry process (§8.1), `Shell.main`. It holds the `State`: the front end's `Env`, the settings `:set` changes, whether it colours, decided once at start (§11.2 *Colour*), its own processes by their `Process`, and the last hundred fault reports. It runs no user code. Its mailbox is `ShellMsg`.
- **The reader** owns the keys, at a terminal. It records itself as the terminal's holder with `holdTerminal` before it subscribes, so that anything else that asks for the keys or a line faults, and the interrupt reaches the reader as a key (§11.2 *The shell*, §8.2 *Interrupt*). Each event goes through `Shell.Editor.edit`; the reader sends the screen the line to show and the session what was entered. It draws nothing, and it stays live while an input runs. Its mailbox is `ReaderMsg`.
- **The screen** is the only process that writes to the terminal. It holds a `Shell.Region.Region` and writes the bytes the region answers, through the foreign `write` rather than `Io.print`, since the sinks are bound to the screen and its own bytes would come back to it. Without a terminal it runs `plainLoop`, which writes what it is sent as it comes. Its mailbox is `ScreenMsg`.
- **An input's process** is spawned by the front end (`spawnInput`), since its mailbox type, the input's own inferred effect, is known only once the input is checked. It catches its own fault and answers the session with `Done(Ok(env, value))` or `Done(Faulted(cause))`, so nothing monitors it. Its address is what the interrupt kills.

**The screen's messages.** The shell's own text is `Said`, which takes the prompt with it, an input having finished, or `Noted`, which leaves the prompt, the input still being typed. A program's text is `Wrote`. `Typing` carries the line, the cursor, and the rows shown under the line, so every key says what stands there, and the line and its listing are painted in one write. The reader's `Entered` commits the line. The session's `Taken` says it has taken an input, which spends the prompt said after the previous answer when the input was typed ahead. `Flush` is a call, answered once everything sent before it is written.

**Ordering.** The session drains the screen with `Flush` before each prompt and before it ends. A program's text reaches the screen from the program's own processes, not through the session, so without the drain a prompt could come before what the input printed. The screen writes to the terminal itself, so the runtime's flush at the end of a program (§8.6) does not reach it.

**Queueing.** While an input runs, the session waits in `await`, which receives `Done`, `Interrupted` and `Reported` alone. An input typed meanwhile, and `Eof`, wait in the mailbox and are taken after the run. The queue holds text, so a queued input is checked when it runs, after the input before it has bound what it may use. `Interrupted` kills the input's process and says `Killed`; a `Done` that still arrives is dropped by `keyLoop`.

### Start and end

The runner, `ern_cli`, loads the file and its dependencies and runs their initializers (§8.5). Through `ern_shell:loaded/1` it hands the front end the load path, the source root, the loaded modules' interfaces, the entry point to spawn, and the paths of the startup files. It then runs `Shell.main` as the entry point, with standard output and standard error bound to `ern_shell:to_screen`.

`main` is ordered by what each step needs from the one before:

1. Where `Terminal.size()` answers a size, it spawns the reader and waits for `Ready` or `NoKeys`. The reader answers once its subscription is granted, and so once the terminal no longer echoes (§8.2 *Keys*); what was typed at a prompt written earlier would be echoed and read as a line.
2. It spawns the screen, and binds the sinks to it with `setScreen(via(Wrote, screen))`.
3. It subscribes to `Process.faults(Reported)`, and only then spawns the file's entry point (`program`), so that a fault in the entry point is reported.
4. At a terminal it reads the history, sends the reader `Start` with the screen, the history and whether to colour, and monitors the reader: the reader's end is the session's.
5. It runs the startup inputs, and writes the first `> `.

`finish` takes the region away with `Height(0)` and an empty `Typing`, leaves the cursor on a fresh line, and drains the screen. When `main` returns, every process the session spawned ends with `ProgramEnd` (§8.6).

### Line mode

Where standard output has no size, or the reader's subscription is refused because standard input is not a terminal (`Left(NotATerminal)`, E.16), there is no reader. The session records itself as the terminal's holder and reads lines with `Io.readLine` in `lineLoop`, and the screen runs `plainLoop`. The session blocks in `Io.readLine`, so a fault report waits in its mailbox; `pending` says every waiting one before each prompt. Line mode reads and writes no history.

## The front end

`erl/cli/src/ern_shell.erl` answers every foreign function the shell declares but `holdTerminal`, which the runtime answers (`ern_rt:hold_terminal/1`). The declarations stand at the top of `shell/shell.ern`, each naming its Erlang function.

### The foreign interface

The front end's values reach the shell as handles of three foreign types, `Env`, `Checked` and `Value`, so the shell cannot pass one kind where another is expected. The shell never looks inside them, and types reach it as text.

- **The environment.** `start` makes the first `Env`. `check` answers §11.5's text for an input that does not check, and otherwise the next `Env` with a `Checked`; its file and line name where the input came from, `input` and 1 for one typed. `spawnInput` runs a `Checked`, and its outcome carries the `Env` after the run. `load`, `reload` and `forget` answer the `Env` they made.
- **A result.** `typeText`, `isUnit`, `declared` and `unbound` read a `Checked`: the type printed, whether the value is printed at all, what a declaration prints, and whether `it` was left as it was. `show` prints a `Value` to a depth and a length.
- **The commands** that reach past the shell: `bindings`, `browse`, `doc` and `output`.
- **The reader's questions**: `names`, `sessionNames`, `sessionTexts`, `sourceRoot`, `context`, `needsMore`, `fields`, `documentation`, `signature` and `segment`. None takes an `Env`; those that read the session read the front end's copy.
- **The host's alone**: `version`, `startupFiles`, `program`, `write`, `setScreen` and `holdTerminal`.

`spawnInput` takes an address, `via(Done, self())`, and not the wrap E.0 shape rule 8 gives a function that delivers later: foreign code may pass a function value back but not call it (§8.4), so the shell wraps at its end and the front end only sends. `NO_COLOR` and `HOME` are read in Ernest, from `Os.environment`, and what runs and what faulted through `Process` (E.21), as any program reads them.

**The front end's copy.** The front end keeps the latest `Env` of its own (`remember`), besides the one the session holds. The reader completes and documents while an input runs, when the session waits in `await` and answers nothing, so the reader's questions cannot be messages to the session. The copy is set when an input is checked and again when it has run, since what an input declares joins the session when it has run.

### An input as a module

Each input is compiled as a module of its own and loaded. Its namespace is `$Input<n>`; the module that holds what a `let` bound is `$Bindings<n>`; and the ones a text is checked in for `fields` and `signature` are `$Fields` and `$Signature`. No identifier holds a `$` (§2.3), so no input can name one. The number of an input or a holder the session has let go is given again, so an input's own module costs no new atom.

`input/1` reads the text as an expression, whose value is `it`; failing that, as declarations, where a lone `let` binds its name; and failing that, as a `let` with a pattern, which becomes the block `{ let p = e; #(names) }`. An expression or a `let` becomes the body of `export fn '$input'()`, whose effect is left a variable, so the input's process takes the input's own mailbox type (§8.1). No Ernest identifier is spelled `'$input'`, so it shadows no name the session declares, `main` among them. Declarations are the module's own, each exported; an input that declares runs its module's initializers (§8.5) in its own process, and its value is `Unit`.

### The session's scope

The checker takes the session as its fourth argument, `ern_typecheck:check/4`: three maps, of values, types and constructors, each from an unqualified name to the qualified name of the input that declared it, a type's member under `{Type, name}`. It is a scope of its own, looked in where §11.2 *Scope* puts it, not the module's own maps seeded with the session's. A reference to a name the session declared is resolved to the input that declared it, so the emitter sees an ordinary reference to another module and knows nothing of a session. A later declaration of a name replaces its entry, and a type declared again drops the members of the type it shadows.

A module's own values live in the runtime's store, keyed by the module and the name, behind a getter the emitter compiles (§8.5), and a reference from another module calls that getter. What a `let` at the prompt binds, `it` among it, is computed in the input's process and not by an initializer, so the input publishes it as it ends: it writes each value to the store and loads a holder, `$Bindings<n>`, whose getters read them. A later input reads a binding with the call the emitter already makes. A value is kept with the descriptor of its type, `#value{term, desc}`, so a value made before its type was declared again still prints by its own.

`#env{}` holds the load path and the source root; the interfaces of the modules behind the session, loaded modules, inputs and holders alike; the scope the checker takes; the compiled module of each input that declared and of each module `:load` compiled, which `:doc` reads, neither having a file; the source hash of each loaded module, which `:reload` compares; and the numbers given to inputs and holders, with those free to give again.

### What the session lets go

An expression's or a `let`'s module is deleted once its answer is in, unless its value holds one of its functions. It is purged unless a process it spawned still runs it, and a later input tries the purge again.

An input that declares, a holder, and an input whose value holds its functions are kept while the session can reach them. Each records, as it is loaded, the session's modules it calls, read from its imports, and those whose types it names. A collection runs as an input's bindings join the session and at each `:forget`. It starts from the names in the session's scope, the input running, and every module whose old code a process is still inside, follows what each needs, and frees the rest: its values in the store, its code, its interface, and its number. Shadowing is by name in the scope, not by replacing code, so a closure made before a declaration keeps the code it was compiled against. How the session's memory is checked is [`memory.md`](memory.md)'s.

### Loading and reloading

`:load` finds the module's source under the source root and compiles it in memory with `ern build`'s compiler (`ern_cli:compile_source`), writing nothing; with no source there, it loads the `.erc` from the load path or the source root. The modules it uses that the session has not loaded are loaded first. `initialize` evaluates each module's top-level bindings (§8.5), dependencies first, each module's in a process of the front end's own, spawned at the site `Shell.load`. That process catches a binding's fault and answers it, so the fault is `:load`'s answer and not a fault report; a kill, which nothing catches, is seen by a monitor. Where a binding faults, every module the load installed is unloaded.

`:reload` compares each loaded module's source with the hash its compiled module carries (§11.1), compiles every changed one before it installs any, and loads each as a new version of the same module, the host keeping the old code for a process still inside it (§6.10). What becomes of the previous version's processes and bindings is §11.2 *Loading and reloading*.

### Output

The runner binds standard output and standard error to `ern_shell:to_screen`, so a program's bytes still pass through the runtime's sinks (§8.2) and reach the screen as `Wrote`. A byte that is not UTF-8 becomes U+FFFD, and a character cut across two writes waits for its end in the writing sink's process. Before `setScreen` names the screen, what is written goes to standard output.

`:output path` opens the path in the front end, in append mode, so the shell gains no file system of its own. The device is not opened `raw`, since a raw device belongs to the process that opened it and what writes to it is the sink's process. While it is open, `to_screen` writes there instead of to the screen.

## The screen and the region

A line the shell has finished with is committed: written into the terminal, scrolled by it, and never touched again, so the scrollback, the search and the selection stay the terminal's. The last rows are the live region, which the shell repaints: the tail of what programs wrote, the input being typed, and the rows `Tab` and `Shift-Tab` show under it. Nothing is ever written below the region, which is what makes the erase correct. The region never addresses a row: it does not know where on the screen it sits, and never asks.

`Shell.Region` is pure. Each event takes the `Region` and answers the region after it and the bytes to write, `#(Region, String)`; the screen writes them and holds nothing else. The region is abstract (§4.4), so its module alone keeps the tail within its rows and the cursor within the input. Besides what it shows, it holds the row the cursor rests on and the terminal's size.

**Drawing.** Each event's bytes are one write, so a redraw is never seen half done, in three parts:

- *erase*: `\r`, up by the row the cursor rests on (`Terminal.up`), and `Terminal.clearBelow`, which clears the region and everything below it;
- *commit*: each line that leaves the region, with its line feed;
- *paint*: the region's rows joined by line feeds, then up from the last row painted to the row the cursor rests on, `\r`, and right to its column.

The row the cursor rests on is counted from the region's first: the tail's rows, the screen rows of the input's lines before the cursor's, and the rows the cursor's own line wraps onto before it. The next erase climbs by it. Between messages the cursor rests where the caret belongs. Only `C-l` clears the screen: `cleared` writes `Terminal.clearScreen` and paints the region at the top.

**The events.** `said` commits the tail and then the session's complete lines, so the scrollback reads in the order the lines were written; what is left without a line feed is the prompt the next input is typed after. `noted` commits the tail and the line, and keeps the prompt. `wrote` adds to the tail, and commits a line the tail has no room for as it leaves. `typing` sets the input, the cursor, and the rows under the input. `entered` commits the input, a row a line with the prompt each was typed after, and takes away what was under it; with no prompt and nothing typed, it commits no row. `taken` drops a prompt no input was typed after. `resized` and `output` change the size and the tail's height, and commit what no longer fits.

**Rows.** The tail takes at most the rows `:set output` gives it and at most half the screen less a row, so that the input has room. A tail row wider than the screen is clipped. Each of the input's lines is its prompt, `> ` or `... `, and its text, wrapped at the screen's width; a line whose width is a multiple of the screen's takes an empty row after it, where the cursor goes on. The rows under the input are wrapped too, and take the rows left; where they do not fit, the last row counts the lines that did not.

**Width.** A row is measured with `Terminal.columns` (E.16), a grapheme at a time, so a wide glyph takes two columns and is never split across rows. An escape sequence takes no column. A clipped row keeps its sequences whole and ends with the reset where one was cut short, and each row a line wraps onto begins with the sequences the rows before it held, so its colour carries on as it would unbroken. A tab is painted as the spaces to the next stop of eight, its width depending on where it falls; what is committed keeps the tab. The size is asked for at start and again at each `Resize`, which the reader sends when `Resized` arrives, so a window that changes while the session is idle is repainted then.

## The editor

`Shell.Editor` is a pure function, `edit(State, Terminal.Event) -> Edit`, whose answer tells the reader what to do. It writes nothing and knows no names; the reader completes and documents, and puts the line back with `typed`. The state is abstract (§4.4), so the editor alone keeps the cursor inside the line and a search inside the history. Its one kill outlives the line: `next` carries it to the next. Which of Readline's keys are bound is `plain`, `character` and `meta`.

- **Sequences.** §8.2 delivers a sequence it does not name as `Escape` and its characters. So `Escape` and a key is that key's Meta binding, and `Escape [` begins the rest of a sequence, of which `Escape [ Z` is `Shift-Tab`. The reader keeps its record of the key before while a sequence is begun, so that `Shift-Tab` twice is two presses and not six keys.
- **History.** The walk at 0 is the line being typed, kept while the walk is away from it. A search keeps its query, its match, where the walk stood and what was typed when it began, and its direction; `shown` and `cursor` give Readline's search prompt with the match after it, which the reader sends in place of the line.
- **Submit.** On `Submit` the reader asks `continues`: the text is not blank, its last line is not blank, and `needsMore` says the parser ran out of input. The parser marks its diagnostic `incomplete`, and `needsMore` tries the text as an expression and as declarations, an input that could still become either being unfinished. The shell never counts brackets, which would be a second parser to disagree with the first. Where the input continues, the reader adds a line. Otherwise it appends the input to the history, sends the screen `Entered` and the session `Typed`, and starts the next line with `next`.
- **Cancel.** `C-c` answers `Cancel`: the reader appends what was typed to the history, sends `Entered` and `Interrupted`, and starts a fresh line.
- **The hint.** The first time an input of the session takes a second line, the reader sends `Noted("M-Enter adds a line, Enter runs.")`, which stands above the region, so the column the input is typed in does not move.

## The history file

`Shell.History`, in `shell/shell/history.ern`, is Ernest over `Os`, `Fs`, `String` and `List`, with no foreign function. The file is `$HOME/.ernest/history`, from `Os.environment`, and there is none where `HOME` is unset.

- **Format.** One input a line, oldest first, a newline in an input written `\n` and a backslash `\\`. Decoding reads left to right, since `\\n` is a backslash and an `n`, which two passes of `String.replace` would read as a newline. An empty line is passed over.
- **Reading.** `read` answers the inputs newest first, the order the editor walks. A file that holds more than `kept`, a thousand, is rewritten to the last thousand as it is read.
- **Writing.** `add` appends a line, making the directory first. The reader calls it as it takes an input and as `C-c` abandons one, where `Shell.Editor.keeps` says the input is kept. A write that fails is said once, and the reader keeps no more.

The session reads the file in `main` and hands the inputs to the reader in `Start`; the editor's history is those inputs and each input taken since, at most `kept` of them.

## Completion and documentation

The reader's `completing` decides from the line what may stand at the cursor:

- in a command's name, the table's names (`commandWord`), without asking the parser, since a command is not the language's;
- after a command, what `Shell.Command.completes` says the command takes (`argument`);
- with only spaces before the cursor on its row, nothing: `Tab` inserts four spaces;
- anywhere else, what `context` answers: the parser is given the text before the word, and says what it wanted where it stopped, a `Shell.Complete.Where`.

The names come from the front end. `names()` is every name in reach, read from the compiled interfaces and the session, each with its kind and the line a listing shows, and `Shell.Complete.withNamespaces` adds the namespaces they are in. For the text before a `.`, `fields` checks it as an input in `$Fields`, which does not enter the session, so a chain of selections is the checker's and a name the unfinished input binds is not in scope; it answers the fields the text's type selects, from `ern_typecheck:fields/2` over §3.5's rule. With nothing typed, `offered` leaves out the prelude's constructors, keeping those the session declares (`sessionTexts`). For `:load`, `sourceModules` lists the one directory of the source root the typed segments name, so a large root is never walked, and names each entry with `segment`, the compiler's path-shape rule (§11.1).

`Shell.Complete.complete` is pure. It filters the names by the `Where`, matches the typed word by prefix and by abbreviation, segment by segment, and answers a `Completion`: the word to stand in place of the one typed, and the candidates. The word replaces rather than extends, since an abbreviation is no prefix of what it reaches; `applied` puts it in the line. The reader's `offering` lists the candidates on a second `Tab`, on a `Tab` that changes nothing, and for a lone candidate, as the rows under the line in `Typing`; the next key's `Typing` carries none.

`Shift-Tab` is `documenting`. The whole name the cursor stands in (`Shell.Complete.wordAt`) is asked of `documentation`, which answers the page `:doc` shows, with its module's *Since* line added where the page has none of its own. A first press shows `brief`, read from the parsed page: the first line of its first code block, the first sentence of its prose (`Markdown.firstSentence`), and its *Since* line. A second press shows the whole page.

Where the name has no page, `signature` answers the call or constructor the input stops inside, in three parts: before the parameter at the cursor, the parameter, and after it. The parser records the innermost call on its diagnostic, `#diag.within`, and the text is tried as an expression, a statement, and declarations, so a `let`, a `fn` body and a command's argument find it. A function callee is checked as a one-name input in `$Signature`, and `ern_types:format_call/4` prints its declared type with the parameter names its documentation carries; the shell styles the middle part with `Shell.Style.emphasis`. Pages are rendered by `libs/markdown`, which the shell is built against, at the screen's width, or 80 columns where there is no terminal.

## Commands

`Shell.Command.commands` is the one table of commands: each command's name, its action, what it takes and what completes after it, and its help line. `commands_mirror_test`, in `test/ern_shell_tests.erl`, holds it equal to the list of §11.2 *Commands*. `parse` answers the refusal's text, or the action and the argument; `setting` parses `:set`'s argument. The session's `obey` carries each action out, most through the foreign function of its name. The settings are an Ernest value in the session's `State`, not the front end's, and `:set output n` sends the screen `Height(n)`. `:processes` lists `Process.live()` less the session's own processes, by the site `Process.info` gives, and `:faults` reads the session's `State`.

## Faults

The session learns of every fault as a subscriber of `Process.faults` (E.21), and monitors nothing but the reader. `reported` passes over a report of one of its own processes, the session, the screen and the reader, which it keeps as a `Set(Process)`, since a `Process` has equality where an address has none. It says every other report and keeps it, newest first, for `:faults`.

An input's process catches its own fault and answers it as its outcome, so no report of it comes but for a fault a signal brought, and `await` takes that report as the input's answer. `:load`'s initializing processes catch theirs likewise. So an input's fault is reported once.

A spawn site in an input's module is written as §11.2 *Faults* says: the emitter, told that it compiles an input (`session => true`), names a site in `'$input'` by `input` and one in a declared function by the function's name.

## Startup files

`startupFiles()` answers the two paths, the person's `$HOME/.ernest/startup` and then the configuration directory's `startup`, which the runner computes. Whether each is there, and what it holds, the shell reads itself with `Fs`: a file that is not there is no error, one that cannot be read is said, and each line that is not blank is an input, carrying its file and its line. A `:` line goes to `perform`, as a typed command does; any other goes to `quietly`, which is `run` with printing off and the file and the line passed to `check`, so a diagnostic names them.

## Testing

- **The pure modules** are tested by their `Test` values (§9.3), at the foot of each file, which `make test-shell` runs for every module. The editor's play key lists onto a fresh line; the region's read the bytes a redraw writes and where the cursor rests.
- **The session** is tested by `test/ern_shell_tests.erl`. A golden test is a file of inputs run in line mode, `test/session/basic.in`, against its expected output. A session that drives a program is not one, since where a fault report lands among the inputs depends on when the process faults; that test asserts what must be true of it instead.
- **The terminal** is tested through `test/ern_pty.py`, which gives the shell a pseudo-terminal and sends each key once the screen shows what the step waits for. With `--screen` it renders the writes onto a grid of the terminal's size, since a shell that repaints writes a line many times over, and what is painted is asserted on that grid.
