# The Ernest Shell: Design

Status: the shell's design note, which changes when the shell does. It is not a proposal, and not authoritative: the report states what the shell does.

How `ern shell` is built. What the shell does is report §11.2, cited here by the names of its paragraphs, *Inputs*, *Scope*, *Editing* and the rest. How its code reads is [`src/shell/README.md`](../../src/shell/README.md). Why it is built so, and how it came to be, is the decisions log's; when each part was built is the plan's.

## Shape

The shell is an Ernest program over a front end in Erlang. Its source is a tree of its own, `src/shell/`, beside `src/stdlib/` and `src/libs/`, which `make` compiles into `build/shell/`, where `ern shell` finds it. It is the toolchain's own program, neither standard library nor a library under `src/libs/`.

`Shell`, in `src/shell/shell.ern`, holds the processes and the front end's declarations: everything that sends, receives or reaches the host, but the history file and the questions `Shell.Complete` asks of the front end and of `Fs`. A process only carries messages and writes bytes.

The decisions are pure functions in modules of their own, each tested by its `Test` values (Appendix E.24). `Shell.Editor` decides what a key does, `Shell.Region` what the screen shows, `Shell.Complete.complete` what a word completes to, `Shell.Command` what a command line selects, and `Shell.Style` how a line is colored. `Shell.History` reads and writes the history file.

## Processes

The shell runs as three processes, the session, the reader and the screen. Each input runs in one more, and so does each module a load evaluates (*Loading and reloading*).

**The session** is the entry process (§8.1), `Shell.main`, and runs no user code. Its `State` holds the front end's `Session`, the settings, whether it colors, its own processes, the fault reports `:faults` lists, and what names an input: the count of what was entered at the prompt, the serial of the last input run, and the file and line of a startup input while one runs.

**The reader** owns the keys at a terminal. It records itself as the terminal's holder before it subscribes, so that the keys are its alone and the interrupt reaches it as a key (§11.2 *The shell*, §8.2 *Interrupt*). Each event goes through `Shell.Editor.edit`, and the reader sends the screen the line to show and the session what was entered. It draws nothing, and it stays live while an input runs.

**The screen** is the only process that writes to the terminal. It holds a `Shell.Region.Region` and writes the bytes the region answers. It writes through the foreign `write` rather than `Io.print`, since the sinks are bound to the screen and its own bytes would come back to it. In line mode it writes what it is sent as it comes.

**An input's process** runs the input at its own inferred mailbox type (the log's *The Shell's Design*). That type is known only once the input is checked, so the front end spawns the process. It catches its own fault and answers the session with its outcome and the serial the session gave the input, so nothing monitors it. Its address is what the interrupt kills.

### The screen's messages

The shell's own text is `Said` once an input has finished and `Noted` while one is being typed, two messages since only the sender knows which a line is (the log's *An Input That Spans Lines*). A program's text is `Wrote`. `ShowInput` carries the line, the cursor and the rows shown under it, so that every key paints all that stands there in one write. `Flush` is a call, answered once everything sent before it is written. What each message commits is the region's, *What is committed*.

### Ordering

The session drains the screen with `Flush` before each prompt and before it ends (the log's *Checkpoint 0 on a Terminal*). A program's text reaches the screen from the program's own processes, not through the session, so without the drain a prompt could come before what the input printed. The screen writes to the terminal itself, so the runtime's flush at the end of a program (§8.6) does not reach it.

### Queueing

While an input runs, the session waits in `await`, which takes only the input's outcome, the interrupt, fault reports, and the reader's and the screen's ends. An input typed meanwhile, and the end of input, wait in the mailbox and are taken after the run. The queue holds text, so a queued input is checked when it runs, after the input before it has bound what it may use.

Each outcome carries its input's serial, so an outcome that still arrives from a killed input is dropped. Every outcome comes to one address, `adapted(self(), Done)`, with the serial passed to `spawnInput` beside it. An address given to a foreign function is exposed through a checker, one for each distinct address (§8.4), so one address keeps the inputs to one checker.

### Start and end

The runner, `ern_cli`, loads the file and its dependencies and runs their initializers (§8.5). Through `ern_shell:loaded/1` it hands the front end the load path, the source root, the loaded modules' interfaces, the entry point to spawn, and the paths of the startup files. It then runs `Shell.main` as the entry point, with standard output and standard error bound to `ern_shell:to_screen`.

`main` is ordered by what each step needs from the one before:

1. Where the terminal answers a size, it spawns the reader and waits until the reader's subscription is granted or refused. A granted subscription means the terminal no longer echoes (§8.2 *Keys*), so nothing typed at an earlier prompt is echoed and read as a line.
2. It spawns the screen, binds the sinks to it, and says the greeting.
3. It subscribes to `Process.faults`, and only then spawns the file's entry point, so that a fault in the entry point is reported.
4. It checks and reads the startup files as it finds them, and only then makes the person's directory its owner's alone, so that a directory found open to others is seen as found.
5. At a terminal it hands the reader the screen, the history, whether the history file takes what is typed, and whether to color.
6. It monitors the reader. The reader's end is the session's, and an input running then is killed with it, since no key can interrupt that input any more.
7. It runs the startup inputs, and writes the first prompt, which drains the screen first, as before every prompt.

`finish` takes the region away, leaves the cursor on a fresh line, and drains the screen. When `main` returns, every process the session spawned ends with `ProgramEnd` (§8.6).

### Line mode

Where standard output has no size, or standard input is not a terminal and the reader's subscription is refused (E.16), there is no reader. The session holds the terminal itself and reads lines with `Io.readLine`, taking further lines by the rule `Enter` follows at a terminal (§11.2 *Editing*). The screen writes what it is sent as it comes.

The session blocks in `Io.readLine`, so a fault report waits in its mailbox. Every waiting one is said before the next prompt.

## The front end

`erl/cli/src/ern_shell.erl` answers every foreign function the shell declares, but `holdTerminal`, which the runtime answers. Where each is declared is [`src/shell/README.md`](../../src/shell/README.md)'s *The front end*.

### The foreign interface

The front end's values reach the shell as handles of three foreign types, `Session`, `Checked` and `Value`, so the shell cannot pass one kind where another is expected. The shell never looks inside them, and types reach it as text.

- **The session**: `start`, `check`, `spawnInput`, `load`, `reload`, `forget` and `collect`, each answering the `Session` it made, `spawnInput` in its outcome. `check` answers §11.5's text instead for an input that does not check, and a `Checked` beside the `Session` for one that does.
- **A result**: `typeText`, `isUnit`, `isExpression`, `declared`, `leavesItUnchanged` and `declaredType` read a `Checked` for what is printed and what `:type` and `it` do. `show` prints a `Value` to a depth and a length.
- **The commands** that reach past the shell: `bindings`, `browse`, `doc`, and `evaluators`, the processes `:processes` leaves out.
- **The questions the reader and `Shell.Complete` ask**: `names`, `sessionNames`, `sessionTexts`, `sourceRoot`, `slot`, `needsMore`, `opening`, `fields`, `documentation`, `signature`, `segment` and `component`. None takes a `Session`; those that read the session read the front end's copy.
- **The host's alone**: `version`, `configStartup`, `isSameFile`, `spawnProgram`, `write`, `setScreen` and `holdTerminal`.

`check` is told where the input came from: the count of what was entered at the prompt, or a startup file's line and the column the input begins in.

`spawnInput` takes an address, `adapted(self(), Done)`, and not the wrap E.0 shape rule 8 gives a function that delivers later. Foreign code may pass a function value back but not call it (§8.4), so the shell wraps at its end and the front end only sends (the log's *Checkpoint 0, in Line Mode*).

What any program reads, the shell reads as one: `NO_COLOR`, and `HOME` for the history, with `Os.environment`, and what runs and what faulted through `Process` (E.21).

### The front end's copy

The front end keeps the latest `Session` of its own, beside the one the session holds. The reader completes and documents while an input runs, when the session waits in `await` and answers nothing, so the reader's questions cannot be messages to the session. The copy is set when an input is checked, and again when it has run, since what an input declares joins the session when it has run.

The copy is a row of a table the runner owns, and so is everything else that changes as inputs run: the input numbers free to give again, the inputs not yet purged, what each session module needs, each input's name, and the modules whose last `:load` was refused, with the refusal. A persistent term replaced has the host scan every process, so only what is set once is one: what the runner loaded, and the screen. What a binding's holder keeps is one too, so that a read does not copy it, the scan paid once as the holder goes (the log's *The Hardening Built*).

### An input as a module

Each input is compiled as a module of its own, `$Input<n>`, and loaded (the log's *The Shell's Design*). What a `let` binds is held by a module `$Bindings<n>`, and the text `fields` and `signature` read is checked in `$Fields` and `$Signature`. No identifier holds a `$` (§2.3), so no input can name one.

The number of an input or a holder the session has let go is given again, so an input's module costs no new atom (the log's *An Input's Number Is Given Again*). Its number is therefore no input's count, and a type a later input shadows prints under the count instead (§11.2 *Scope*).

The text is read as an expression, whose value is `it`; failing that, as declarations; and failing that, as a `let` with a pattern, which becomes a block that answers the names it binds. An expression or a `let` becomes the body of `export fn '$input'()`, whose effect is left a variable, so that the input's process takes the input's own mailbox type (§8.1). No identifier is spelled `'$input'`, so it shadows no name the session declares, `main` among them (the log's *The Session's Names in Spawn Sites*).

An input's declarations are its module's own, each exported. An input that declares runs its module's initializers (§8.5) in its own process, and its value is `Unit`.

### Text read and not run

Text that is read and not run makes no name of the host's, since the host keeps a name forever (the log's *The Hardening Built*). The questions that read the line being typed lex it so that a name the host has not met is one stand-in, which names nothing. The standard library's interfaces are read once before, so that every name a completion offers has been met.

A name given to `:doc`, `:forget`, `:browse` or `:load` is made a name only where it can name something: each segment met before, or a module there is a file of.

### The session's scope

The checker takes the session as its fourth argument, `ern_typecheck:check/4`: three maps, of values, types and constructors, each from an unqualified name to the qualified name of the input that declared it. It is a scope of its own, looked in where §11.2 *Scope* puts it, and a later declaration of a name replaces its entry.

A reference to a name the session declared is resolved to the input that declared it, so the emitter sees an ordinary reference to another module and knows nothing of a session (the log's *The Spike: How an Input Sees the Session*).

What a `let` at the prompt binds is computed in the input's process, not by an initializer (§8.5), so the input publishes it as it ends. It writes each value to the runtime's store and loads its holder, whose getters read them, so a later input reads a binding with the call the emitter makes for any other module's value. The store holds the term alone; an input's outcome carries its value with the descriptor of its type, which `show` prints by.

`#session{}` holds what the checker and the commands need between inputs: the load path and the source root, the interfaces behind the session, the scope, the compiled modules `:doc` reads that no file holds, the source hashes `:reload` compares, and the holders' numbers.

### What the session lets go

An expression's or a `let`'s module is deleted once its answer is in, unless its value holds one of its functions (§11.2 *Inputs*). It is purged unless a process it spawned still runs it, and a later input tries the purge again.

An input that declares, a holder, and an input whose value holds its functions are kept while the session can reach them. Each records, as it is loaded, the session's modules it calls and those whose types it names. The session collects once an input has answered and at each `:forget`: from the names in its scope and every module whose old code a process is still inside, it follows what each needs, and frees the rest, its values, code, interface and number (the log's *What the Loads Found*).

Shadowing is by name in the scope, not by replacing code, so a closure made before a declaration keeps the code it was compiled against (the log's *A Binding That Holds a Function*). How the session's memory is checked is [`memory.md`](../memory.md)'s.

### Loading and reloading

`:load` compiles a source in memory with `ern build`'s compiler, writing nothing, and loads a compiled form where §11.2 *Loading and reloading* takes one. Each module is a unit of its Erlang name, or, where the node holds other code of that name, of a name of its own, `ern@counter$2`. A unit the node holds with the same code is taken as it is.

Each module's top-level bindings are evaluated (§8.5), dependencies first, in an evaluator of its own, which lives while the session runs. The evaluator catches a binding's fault, so the fault is `:load`'s answer and not a fault report; a kill, which nothing catches, is seen by a monitor.

Each evaluator is the root of what its evaluation started. So a refused load kills what each started, whatever code it runs, and erases what its bindings stored, while the units it brought stay loaded out of scope (§11.2).

`:reload` finds a changed source by the hash its compiled module carries (§11.1). It compiles every changed module, and every loaded module `ern build` would compile again for it, before it installs any. It loads each as a unit of its own beside the previous version's, unloading nothing, so that a process or a function value of the previous version keeps it (§6.10).

A type whose hash the reload changed moves, in the interfaces of the session's inputs and holders, to the previous version's namespace, `Counter$1`, whose interface reaches the previous unit. The checker is given those interfaces beside the loaded modules'.

## The screen and the region

A line the shell has finished with is committed: written into the terminal, scrolled by it, and never touched again. So the scrollback, the search and the selection stay the terminal's (the log's *The Panes Become a Live Region*). The last rows are the live region, which the shell repaints: the tail of what programs wrote, the input being typed, and the rows `Tab` and `Shift-Tab` show under it.

Nothing is ever written below the region, which is what makes the erase correct. The region never addresses a row: it does not know where on the screen it sits, and never asks.

`Shell.Region` is pure (the log's *The Region Is a Pure Function*). Each event takes the region and answers the region after it and the bytes to write, which the screen writes. The region is abstract (§4.4), so its module alone keeps the tail within its rows and the cursor within the input. Beside what it shows, it holds the row the cursor rests on, the terminal's size, and the rows the tail may take.

### Drawing

Each event's bytes are one write, so a redraw is never seen half done. The write has three parts:

- *erase*: `\r`, up by the row the cursor rests on, and a clear of the region and everything below it;
- *commit*: each line that leaves the region, with its line feed;
- *paint*: the region's rows joined by line feeds, then up from the last row painted to the row the cursor rests on, `\r`, and right to its column.

The row the cursor rests on is counted from the region's first: the tail's rows, the screen rows of the input's lines before the cursor's, and the rows the cursor's own line wraps onto before it. The next erase climbs by it. Between messages the cursor rests where the caret belongs (the log's *What the Live Region Cost to Build*).

Only `C-l` clears the screen, and paints the region at the top.

### What is committed

- `Said` commits the tail and then the session's complete lines, so the scrollback reads in the order the lines were written. What is left without a line feed is the prompt the next input is typed after.
- `Noted` commits the tail and the line, and keeps the prompt.
- `Wrote` commits a line the tail has no room for, as it leaves.
- `Entered` commits the input, a row a line with the prompt each was typed after, and takes away what was under it; with no prompt and nothing typed, it commits no row.
- `Taken`, which the session sends as it takes an input, drops a prompt no input was typed after, as when the input was typed ahead.
- A change of the size or of the tail's height commits what no longer fits.

### Rows

The tail takes at most the rows `:set rows` gives it, and at most half the screen less a row, so that the input has room. A line takes the rows it fills at the screen's width, each a line of the tail. A line not yet ended keeps its last row back, so the region holds one row of it at most, and the scrollback holds the rest as the rows the terminal would have wrapped it into (the log's *An Unfinished Line Leaves the Region a Row at a Time*).

Each of the input's lines is its prompt and its text, wrapped at the screen's width. A line whose width is a multiple of the screen's takes an empty row after it, where the cursor goes on. The rows under the input take the rows left, and the last counts the lines that did not fit (§11.2).

### Width

A row is measured with `Terminal.width` (E.16), a grapheme at a time, so a wide glyph takes two columns and is never split across rows. An escape sequence takes no column. A clipped row keeps its sequences whole and ends with the reset where one was cut short. Each row a line wraps onto begins with the sequences the rows before it held, so its color carries on as it would unbroken.

A tab is painted by the row it falls on (§11.2 *Editing*), and what is committed keeps it.

The size is asked for at start and at each resize, which the reader passes on, so a window that changes while the session is idle is repainted then.

## Output

The runner binds standard output and standard error to `ern_shell:to_screen`, so a program's bytes pass through the runtime's sinks (§8.2) and reach the screen as `Wrote`. Until the screen is named, they go to standard output. A character cut across two writes waits for its end in the writing sink's process.

Once the program's end has waited for its subscribers (§8.6), the runtime drains the screen as a prompt does, so that what a subscriber wrote after the session ended is written before the screen ends with the program.

`:output path` is the session's, in Ernest (the log's *What Erlang Held, Moved*). It tries the path with an append of nothing, which creates a file that is not there and refuses what is neither a file nor a device (E.17). A named pipe is refused so, since opening one no one reads would hold the session.

The screen then holds where output goes, and appends each `Wrote` there instead of drawing it; where an append fails, it draws again (§11.2). An append opens the file each time, about 0.2 ms a line against the live region's 0.08, a cost the same entry weighs.

## The editor

`Shell.Editor` is a pure function from the state being edited and a `Terminal.Event` to an `Edit`, which tells the reader what to do. It writes nothing and knows no names: the reader completes and documents, and puts the line back. The state, `Editing`, is abstract (§4.4), so the editor alone keeps the cursor inside the line and a search inside the history. Its one kill outlives the line.

**Sequences.** §8.2 delivers a sequence it does not name as `Escape` and its characters. So `Escape` and a key is that key's Meta binding, and `Escape [ Z` is `Shift-Tab`. The reader keeps its record of the key before while a sequence is begun, so that `Shift-Tab` twice is two presses and not six keys.

**History.** The walk at 0 is the line being typed, kept while the walk is away from it. A search shows Readline's search prompt with its match in place of the line.

**Submit.** `Enter` asks whether the input continues: its text and its last line are not blank, and the parser ran out of input. The parser marks its diagnostic `incomplete`, and the front end tries the text as an expression, as declarations and as a statement, since an input that could still become any of them is unfinished (the log's *An Input That Spans Lines*).

**Matching.** The bracket a `)`, `]` or `}` closes is found by the compiler's lexer, so that a string, a character or a comment hides what it holds. The reader stands the cursor on it and waits for the next key with an `after` of 500 ms. A key that comes first puts the cursor back and is read, so typing is never held (the log's *The Shell Shows a Bracket's Match*).

**Cancel.** On `C-c` the reader appends what was typed to the history, sends the screen `Entered` and the session `Interrupted`, and starts a fresh line.

**The hint.** The first time an input takes a second line, the reader sends §11.2 *Editing*'s hint as `Noted`. It stands above the region, so the column the input is typed in does not move, and its wording is true where `Enter` has just added the line.

## The history file

`Shell.History` is Ernest over `Os`, `Fs`, `String` and `List`, with no foreign function; where the file is and what it holds is §11.2 *Startup and history*. It decodes a line left to right, since `\\n` is a backslash and an `n`, which two passes of `String.replace` would read as a newline. It answers the inputs newest first, the order the editor walks.

The session reads the file at start and hands the inputs to the reader. The reader appends each input it takes and each `C-c` abandons, where the editor says the input is kept, and writes no more once a write has failed.

## Completion and documentation

### Completion

`Shell.Complete` decides from the line what may stand at the cursor:

- in a command's name, a command, without asking the parser, since a command is not the language's;
- after a command, what `Shell.Command` says the command takes;
- anywhere else, what the parser says it wanted where it stopped, given the text before the word.

The names come from the front end, which `Shell.Complete` asks itself: every name in reach, read from the compiled interfaces and the session, each with its kind and the line a listing shows.

For the text before a `.`, the front end checks it as an input in `$Fields`, which does not enter the session, and answers the fields its type selects (§3.5). So a chain of selections is the checker's.

For `:load`, only the one directory of the source root the typed segments name is listed, so a large root is never walked. Each entry is named by the compiler's path-shape rule (§11.1).

Matching a word is pure (`Shell.Complete.complete`). It answers the word to stand in place of the one typed, and the candidates. The word replaces rather than extends, since an abbreviation is no prefix of what it reaches. The candidates are listed as the rows under the line, which the next key's `ShowInput` takes away.

### Documentation

`Shift-Tab` asks the front end for the page `:doc` shows of the whole name the cursor stands in, with its module's *Since* line added where the page has none of its own. The first press shows a brief read from the parsed page, its first sentence by `Markdown.firstSentence`, and the second press the whole page.

Where the name has no page, the front end answers the call or constructor the input stops inside, in three parts: before the parameter at the cursor, the parameter, and after it. The parser records the innermost call on its diagnostic. The text is tried as an expression, a statement and declarations, so a `let` and a `fn` body find it, and a command's word is cut off before, so a command's argument finds it too.

A function callee is checked as a one-name input in `$Signature`, and its declared type printed with the parameter names its documentation carries (`ern_types:format_call/4`).

Pages are rendered by `libs/markdown`, which the shell is built against, at the width §11.2 *Rendering* gives.

## Commands

`Shell.Command.commands` is the one table of commands: each command's name, its action, what it takes and what completes after it, and its help line. `commands_mirror_test`, in `test/ern_shell_tests.erl`, holds it equal to the list of §11.2 *Commands*. The session carries each action out, most through the foreign function of its name.

The settings are an Ernest value in the session's state, not the front end's. `:processes` lists `Process.live()` less the shell's own processes and the evaluators, and `:faults` reads the session's state.

## Faults

Beside its subscription to `Process.faults` (§11.2 *Faults*), the session monitors nothing but the reader and the screen. The screen's end leaves the session nothing to show itself on, so the session faults with the screen's cause, a failure of the shell's own (§11.8).

The session passes over a report of its own three processes, which it keeps as a `Set(Process)`, since a `Process` has equality where an address has none. It says every other report and keeps it for `:faults`.

An input's process catches its own fault and answers it as its outcome, so no report of it comes but for a fault a signal brought, which `await` takes as the input's answer. So an input's fault is reported once. An evaluator catches its own likewise.

A spawn site in an input's module is written as §11.2 *Faults* says. The emitter is told that it compiles an input and the line offset its diagnostics use, and writes a site in a declared function by the function's name. A site in the input's own expression is a call of `ern_shell:input_site/2`, which reads the name recorded for the input.

## Startup files

The shell finds the paths in Ernest: the person's beside the history's file, under the same rule for a `HOME` that is no absolute path, and then the configuration directory's, which the runner computes (§11.2). The host answers only what it alone knows, the configuration directory's file and whether two paths are one file, by device and node (the log's *The Full Review's Questions, One by One*). Each file is named from the working directory (§11.5).

The shell reads whose each file is itself, with `Fs.stat` and `Os.user`, by §11.2 *Startup and history*'s rule (the log's *The Hardening Built*). It reads the file with `Fs` too, and takes its inputs from its lines by line mode's rule, each carrying its file and the line it begins on.

While a startup input runs, the session holds its file and line, which a refusal and a fault's report put before what they say. A command runs as a typed one does. Any other input runs with printing off and its file and line passed to `check`, so that a diagnostic names them.

## Testing

**The modules but `Shell`** are tested by their `Test` values (Appendix E.24, §11.2), at the foot of each file, which `make test-shell` runs for every module. Each of the editor's tests plays a list of events onto a fresh line and reads the text and the cursor; the region's read the bytes a redraw writes and where the cursor rests.

**The session** is tested by `test/ern_shell_tests.erl`. A golden test is a file of inputs run in line mode, `test/fixtures/session/basic.in`, against its expected output. A session that drives a program is not one, since where a fault report lands among the inputs depends on when the process faults; that test asserts what must be true of it instead.

**The terminal** is tested through `test/ern_pty.py`, which gives the shell a pseudo-terminal and sends each key once the screen shows what the step waits for. With `--screen` it renders the writes onto a grid of the terminal's size, since a shell that repaints writes a line many times over, and what is painted is asserted on that grid.
