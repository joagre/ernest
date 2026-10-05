# The Ernest Shell: Design

How `ern shell` is built. What the shell does is report §11.2, cited here by the names of its paragraphs, *Inputs*, *Scope*, *Editing* and the rest; how its code reads is [`shell/README.md`](../shell/README.md); why it is built so, and how it came to be, is the decisions log's; when each part was built is the plan's.

## Shape

The shell is an Ernest program over a front end in Erlang. Its source is a tree of its own, `shell/`, beside `stdlib/` and `examples/`, which `make` compiles into `build/shell/`, where `ern shell` finds it. It is the toolchain's own program: not standard library, and not a library under `libs/`.

`Shell`, in `shell/shell.ern`, holds the processes and the front end's declarations: everything that sends, receives, or reaches the host, but the history file and the questions `Shell.Complete` asks of the front end and of `Fs`. The decisions are pure functions in modules of their own, each tested by its `Test` values (§9.3): `Shell.Editor` decides what a key does, `Shell.Region` what the screen shows, `Shell.Complete.complete` what a word completes to, `Shell.Command` what a command line selects, and `Shell.Style` how a line is coloured. `Shell.History` reads and writes the history file. A process only carries messages and writes bytes.

## Processes

The shell runs as three processes of its own, and each input in one more.

- **The session** is the entry process (§8.1), `Shell.main`. It holds the `State`: the front end's `Session`, the settings `:set` changes, whether it colours, decided once at start (§11.2 *Colour*), its own processes by their `Process`, the last hundred fault reports, how many things were entered at the prompt (`entered`), the startup file and line of an input running from one (`startupLine`), and the serial of the last input run (`serial`). It runs no user code. Its mailbox is `ShellMsg`.
- **The reader** owns the keys, at a terminal. It records itself as the terminal's holder with `holdTerminal` before it subscribes, so that anything else that asks for the keys or a line faults, and the interrupt reaches the reader as a key (§11.2 *The shell*, §8.2 *Interrupt*). Each event goes through `Shell.Editor.edit`; the reader sends the screen the line to show and the session what was entered. It draws nothing, and it stays live while an input runs. Its mailbox is `ReaderMsg`.
- **The screen** is the only process that writes to the terminal. It holds a `Shell.Region.Region` and writes the bytes the region answers, through the foreign `write` rather than `Io.print`, since the sinks are bound to the screen and its own bytes would come back to it. In line mode it runs `plainLoop`, which writes what it is sent as it comes. Its mailbox is `ScreenMsg`.
- **An input's process** is spawned by the front end (`spawnInput`), since its mailbox type, the input's own inferred effect, is known only once the input is checked. It catches its own fault and answers the session with `Done(Ok(session, serial, value))` or `Done(Faulted(cause, serial))`, `serial` the number the session gave the input, so nothing monitors it. Its address is what the interrupt kills.

**The screen's messages.** The shell's own text is `Said`, which takes the prompt with it, an input having finished, or `Noted`, which leaves the prompt, the input still being typed. A program's text is `Wrote`. `ShowInput` carries the line, the cursor, and the rows shown under the line, so every key says what stands there, and the line and its listing are painted in one write. The reader's `Entered` commits the line. The session's `Taken` says it has taken an input, which spends the prompt said after the previous answer when the input was typed ahead. `Flush` is a call, answered once everything sent before it is written.

**Ordering.** The session drains the screen with `Flush` before each prompt and before it ends. A program's text reaches the screen from the program's own processes, not through the session, so without the drain a prompt could come before what the input printed. The screen writes to the terminal itself, so the runtime's flush at the end of a program (§8.6) does not reach it.

**Queueing.** While an input runs, the session waits in `await`, which receives `Done`, `Interrupted`, `Reported`, and the reader's and the screen's ends alone. An input typed meanwhile, and `InputEnded`, wait in the mailbox and are taken after the run. The queue holds text, so a queued input is checked when it runs, after the input before it has bound what it may use. `Interrupted` kills the input's process and says `Killed`. Each input's outcome carries its serial, so a `Done` that still arrives from a killed input is dropped, by `keyLoop` or by the next input's `await`. The serial is an argument of `spawnInput`, and the address the outcome goes to is the one `via(self(), Done)`, since an address a foreign function is given is exposed through a proxy, one for each distinct address.

### Start and end

The runner, `ern_cli`, loads the file and its dependencies and runs their initializers (§8.5). Through `ern_shell:loaded/1` it hands the front end the load path, the source root, the loaded modules' interfaces, the entry point to spawn, and the paths of the startup files. It then runs `Shell.main` as the entry point, with standard output and standard error bound to `ern_shell:to_screen`.

`main` is ordered by what each step needs from the one before:

1. Where `Terminal.size()` answers a size, it spawns the reader and waits for `Subscribed` or `SubscriptionRefused`. The reader answers once its subscription is granted, and so once the terminal no longer echoes (§8.2 *Keys*); what was typed at a prompt written earlier would be echoed and read as a line.
2. It spawns the screen, binds the sinks to it with `setScreen(via(screen, Wrote))`, and says the greeting, the version and where the commands are.
3. It subscribes to `Process.faults(Reported)`, and only then spawns the file's entry point (`spawnProgram`), so that a fault in the entry point is reported.
4. It checks and reads the startup files as it finds them (`ownInputs`), and only then makes the person's directory its owner's alone (`Shell.History.keepOwn`), so that a directory found open to others is seen as found.
5. At a terminal it reads the history, sends the reader `Start` with the screen, the history, whether the history file takes what is typed, which it does not where it could not be read, and whether to colour, and monitors the reader: the reader's end is the session's, an input it runs killed with it, since no key can interrupt that input any more.
6. It runs the startup inputs, and writes the first `> ` with `prompt`, which drains the screen first, as before every prompt.

`finish` takes the region away with `SetHeight(0)` and an empty `ShowInput`, leaves the cursor on a fresh line, and drains the screen. When `main` returns, every process the session spawned ends with `ProgramEnd` (§8.6).

### Line mode

Where standard output has no size, or the reader's subscription is refused because standard input is not a terminal (`Left(NotATerminal)`, E.16), there is no reader. The session records itself as the terminal's holder and reads lines with `Io.readLine` in `lineLoop`, and the screen runs `plainLoop`. `moreLines` takes the next line while `continues` says the parser cannot finish the input, the rule `Enter` follows at a terminal. The session blocks in `Io.readLine`, so a fault report waits in its mailbox; `reportPending` says every waiting one before each prompt. Line mode reads and writes no history.

## The front end

`erl/cli/src/ern_shell.erl` answers every foreign function the shell declares but `holdTerminal`, which the runtime answers (`ern_rt:hold_terminal/1`). The shell's foreign functions stand at the foot of `shell/shell.ern`, and those `Shell.Complete` asks before its matching in `shell/shell/complete.ern`, each naming its Erlang function.

### The foreign interface

The front end's values reach the shell as handles of three foreign types, `Session`, `Checked` and `Value`, so the shell cannot pass one kind where another is expected. The shell never looks inside them, and types reach it as text.

- **The session.** `start` makes the first `Session`. `check` answers §11.5's text for an input that does not check, and otherwise the next `Session` with a `Checked`; its `Origin` names where the input came from, `Prompt(n)` for the `n`th thing entered at the prompt, which the session's `State` counts in `entered`, and `Startup(file, line, column)` for a line of a startup file and the column the input begins in. `spawnInput` runs a `Checked`, and its outcome carries the `Session` after it. `load`, `reload` and `forget` answer the `Session` they made, and `collect` the `Session` with what nothing reaches let go.
- **A result.** `typeText`, `isUnit`, `isExpression`, `declared` and `leavesItUnchanged` read a `Checked`: the type printed, whether the value is printed at all, whether `:type` takes the input, what a declaration prints, and whether `it` was left as it was; `declaredType` answers the type an input that is one name prints, as its declaration writes it. `show` prints a `Value` to a depth and a length.
- **The commands** that reach past the shell: `bindings`, `browse` and `doc`.
- **The questions the reader and `Shell.Complete` ask**: `names`, `sessionNames`, `sessionTexts`, `sourceRoot`, `slot`, `needsMore`, `fields`, `documentation`, `signature` and `segment`. None takes a `Session`; those that read the session read the front end's copy.
- **The host's alone**: `version`, `configStartup`, `isSameFile`, `spawnProgram`, `write`, `setScreen` and `holdTerminal`.

`spawnInput` takes an address, `via(self(), Done)`, and not the wrap E.0 shape rule 8 gives a function that delivers later: foreign code may pass a function value back but not call it (§8.4), so the shell wraps at its end and the front end only sends. `NO_COLOR`, and `HOME` for the history, are read in Ernest, with `Os.environment`, and what runs and what faulted through `Process` (E.21), as any program reads them.

**The front end's copy.** The front end keeps the latest `Session` of its own (`keep_session`), besides the one the session holds. The reader completes and documents while an input runs, when the session waits in `await` and answers nothing, so the reader's questions cannot be messages to the session. The copy is set when an input is checked and again when it has run, since what an input declares joins the session when it has run. It is a row of a table the runner owns, which `loaded/1` makes, and so is what else changes as inputs run: the input numbers free to give again, the inputs not yet purged, what each session module needs, and each input's name, a row of its own since every spawn of the input reads it. A persistent term replaced has the host scan every process, so only what is set once or by a command is one, what the runner loaded, the screen and where output goes; and what a binding's holder keeps, which a read then does not copy (the log's *The Hardening Built*).

### An input as a module

Each input is compiled as a module of its own and loaded. Its namespace is `$Input<n>`; the module that holds what a `let` bound is `$Bindings<n>`; and the ones a text is checked in for `fields` and `signature` are `$Fields` and `$Signature`. No identifier holds a `$` (§2.3), so no input can name one. The number of an input or a holder the session has let go is given again, so an input's own module costs no new atom. Its number is therefore no input's count, and a type a later input shadows prints under the count instead, as §11.2 *Scope* says.

Text that is read and not run makes no name either, since the host keeps a name for ever. `slot` and `within`, which read the line being typed, lex it with `no_new_names`: a name the host has not met is the stand-in `'$unmet'`, which names nothing, and `stdlib_met/0` reads the standard library's interfaces once before, so that every name a completion offers has been met. A command's name, `:doc`'s, `:forget`'s, `:browse`'s and `:load`'s, is made a name only where it can name something (`segments/2`): each segment met before, or a module there is a file of; any other answers what a name that names nothing answers.

`input/1` reads the text as an expression, whose value is `it`; failing that, as declarations, where a lone `let` binds its name; and failing that, as a `let` with a pattern, which becomes the block `{ let p = e; #(names) }`. An expression or a `let` becomes the body of `export fn '$input'()`, whose effect is left a variable, so the input's process takes the input's own mailbox type (§8.1). No Ernest identifier is spelled `'$input'`, so it shadows no name the session declares, `main` among them. Declarations are the module's own, each exported; an input that declares runs its module's initializers (§8.5) in its own process, and its value is `Unit`.

### The session's scope

The checker takes the session as its fourth argument, `ern_typecheck:check/4`: three maps, of values, types and constructors, each from an unqualified name to the qualified name of the input that declared it, a type's member under `{Type, name}`. It is a scope of its own, looked in where §11.2 *Scope* puts it, not the module's own maps seeded with the session's. A reference to a name the session declared is resolved to the input that declared it, so the emitter sees an ordinary reference to another module and knows nothing of a session. A later declaration of a name replaces its entry, and a type declared again drops the members of the type it shadows.

A module's own values live in the runtime's store, keyed by the module and the name, behind a getter the emitter compiles (§8.5), and a reference from another module calls that getter. What a `let` at the prompt binds, `it` among it, is computed in the input's process and not by an initializer, so the input publishes it as it ends: it writes each value to the store and loads a holder, `$Bindings<n>`, whose getters read them. A later input reads a binding with the call the emitter already makes. The store holds the term alone. An input's outcome carries its value with the descriptor of its type, `#value{term, descriptor}`, which `show` prints by.

`#session{}` holds the load path and the source root; the interfaces of the modules behind the session, loaded modules, inputs and holders alike; the scope the checker takes; the compiled module of each input that declared and of each module `:load` compiled, which `:doc` reads, neither having a file; the source hash of each loaded module, which `:reload` compares; and the numbers given to holders, with those free to give again. The front end keeps the input numbers free to give again beside it.

### What the session lets go

An expression's or a `let`'s module is deleted once its answer is in, unless its value holds one of its functions. It is purged unless a process it spawned still runs it, and a later input tries the purge again.

An input that declares, a holder, and an input whose value holds its functions are kept while the session can reach them. Each records, as it is loaded, the session's modules it calls, read from its imports, and those whose types it names. The session collects (`collect`) once an input has answered, and at each `:forget`. A collection starts from the names in the session's scope and every module whose old code a process is still inside, follows what each needs, and frees the rest: its values in the store, its code, its interface, and its number. Shadowing is by name in the scope, not by replacing code, so a closure made before a declaration keeps the code it was compiled against. How the session's memory is checked is [`memory.md`](memory.md)'s.

### Loading and reloading

`:load` finds the module's source under the source root and compiles it in memory with `ern build`'s compiler (`ern_build:compile_source`), writing nothing; with no source there, it loads the `.erc` from the load path or the source root. The modules it uses that the session has not loaded are loaded first. `initialize` evaluates each module's top-level bindings (§8.5), dependencies first, each module's in a process of the front end's own, spawned at the site `Shell.load`. That process catches a binding's fault and answers it, so the fault is `:load`'s answer and not a fault report; a kill, which nothing catches, is seen by a monitor. Where a binding faults, every module the load installed is unloaded.

`:reload` compares each loaded module's source with the hash its compiled module carries (§11.1), compiles every changed one, and every loaded module that uses one whose interface changed, before it installs any, and loads each as a new version of the same module, the host keeping the old code for a process still inside it (§6.10). What becomes of the previous version's processes and bindings is §11.2 *Loading and reloading*.

### Output

The runner binds standard output and standard error to `ern_shell:to_screen`, so a program's bytes still pass through the runtime's sinks (§8.2) and reach the screen as `Wrote`. A byte that is not UTF-8 becomes U+FFFD, and a character cut across two writes waits for its end in the writing sink's process. Before `setScreen` names the screen, what is written goes to standard output.

`:output path` is the session's, in Ernest: it appends nothing to the path through `Fs.append`, which creates a file that is not there and refuses what is neither a file nor a device (E.17), a pipe among them, since opening a pipe no one reads would hold the session. It then sends the screen `Redirect`, and the screen, which holds where output goes, appends each `Wrote` there through `Fs.append` instead of drawing it, as the live region would show it. Where an append fails, the screen says why and draws again (§11.2). `:output` alone asks the screen with `Locate`. An append opens the file each time, about 0.2 ms a line at a terminal where the live region takes 0.08, which the log's *What Erlang Held, Moved* weighs.

## The screen and the region

A line the shell has finished with is committed: written into the terminal, scrolled by it, and never touched again, so the scrollback, the search and the selection stay the terminal's. The last rows are the live region, which the shell repaints: the tail of what programs wrote, the input being typed, and the rows `Tab` and `Shift-Tab` show under it. Nothing is ever written below the region, which is what makes the erase correct. The region never addresses a row: it does not know where on the screen it sits, and never asks.

`Shell.Region` is pure. Each event takes the `Region` and answers the region after it and the bytes to write, `#(Region, String)`; the screen writes them and holds nothing else. The region is abstract (§4.4), so its module alone keeps the tail within its rows and the cursor within the input. Besides what it shows, it holds the row the cursor rests on, the terminal's size, and the rows the tail may take.

**Drawing.** Each event's bytes are one write, so a redraw is never seen half done, in three parts:

- *erase*: `\r`, up by the row the cursor rests on (`Ansi.up`), and `Ansi.clearBelow`, which clears the region and everything below it;
- *commit*: each line that leaves the region, with its line feed;
- *paint*: the region's rows joined by line feeds, then up from the last row painted to the row the cursor rests on, `\r`, and right to its column.

The row the cursor rests on is counted from the region's first: the tail's rows, the screen rows of the input's lines before the cursor's, and the rows the cursor's own line wraps onto before it. The next erase climbs by it. Between messages the cursor rests where the caret belongs. Only `C-l` clears the screen: `cleared` writes `Ansi.clearScreen` and paints the region at the top.

**The events.** `said` commits the tail and then the session's complete lines, so the scrollback reads in the order the lines were written; what is left without a line feed is the prompt the next input is typed after. `noted` commits the tail and the line, and keeps the prompt. `wrote` adds to the tail, and commits a line the tail has no room for as it leaves; a line adds each row it fills at the window's width as a line of the tail, a row after the first beginning with the style in force, and one not yet ended keeps its last row back, so the region holds one row of it at most and the terminal's scrollback holds the rest as the rows it would have wrapped it into. `edited` sets the input, the cursor, and the rows under the input. `entered` commits the input, a row a line with the prompt each was typed after, and takes away what was under it; with no prompt and nothing typed, it commits no row. `taken` drops a prompt no input was typed after. `resized` and `outputSized` change the size and the tail's height, and commit what no longer fits.

**Rows.** The tail takes at most the rows `:set output` gives it and at most half the screen less a row, so that the input has room. A line in the tail takes the rows it fills at the screen's width, ended or not, as the terminal would wrap it. Each of the input's lines is its prompt, `> ` or `... `, and its text, wrapped at the screen's width; a line whose width is a multiple of the screen's takes an empty row after it, where the cursor goes on. The rows under the input are wrapped too, and take the rows left; where they do not fit, the last row counts the lines that did not.

**Width.** A row is measured with `Terminal.columns` (E.16), a grapheme at a time, so a wide glyph takes two columns and is never split across rows. An escape sequence takes no column. A clipped row keeps its sequences whole and ends with the reset where one was cut short, and each row a line wraps onto begins with the sequences the rows before it held, so its colour carries on as it would unbroken. A tab is painted as the spaces to the next stop of eight, counted from the start of the row it falls on, as the terminal counts, so its width depends on where it falls; what is committed keeps the tab. The size is asked for at start and again at each `Resized`, which the reader passes on when the terminal's arrives, so a window that changes while the session is idle is repainted then.

## The editor

`Shell.Editor` is a pure function, `edit(State, Terminal.Event) -> Edit`, whose answer tells the reader what to do. It writes nothing and knows no names; the reader completes and documents, and puts the line back with `withLine`. The state is abstract (§4.4), so the editor alone keeps the cursor inside the line and a search inside the history. Its one kill outlives the line: `next` carries it to the next. Which of Readline's keys are bound is `plain`, `character` and `meta`.

- **Sequences.** §8.2 delivers a sequence it does not name as `Escape` and its characters. So `Escape` and a key is that key's Meta binding, and `Escape [` begins the rest of a sequence, of which `Escape [ Z` is `Shift-Tab`. The reader keeps its record of the key before while a sequence is begun, so that `Shift-Tab` twice is two presses and not six keys.
- **History.** The walk at 0 is the line being typed, kept while the walk is away from it. A search keeps its query, its match, where the walk stood and what was typed when it began, and its direction; `shown` and `shownCursor` give Readline's search prompt with the match after it, which the reader sends in place of the line.
- **Submit.** On `Submit` the reader asks `continues`: the text is not blank, its last line is not blank, and `needsMore` says the parser ran out of input. The parser marks its diagnostic `incomplete`, and `needsMore` tries the text as an expression and as declarations, an input that could still become either being unfinished. The shell never counts brackets, which would be a second parser to disagree with the first. Where the input continues, the reader adds a line. Otherwise it appends the input to the history, sends the screen `Entered` and the session `Typed`, and starts the next line with `next`.
- **Cancel.** `C-c` answers `Cancel`: the reader appends what was typed to the history, sends `Entered` and `Interrupted`, and starts a fresh line.
- **The hint.** The first time an input of the session takes a second line, the reader sends `Noted("Enter runs a finished input, M-Enter adds a line.")`, a wording true where `Enter` has just added the line,, which stands above the region, so the column the input is typed in does not move.

## The history file

`Shell.History`, in `shell/shell/history.ern`, is Ernest over `Os`, `Fs`, `String` and `List`, with no foreign function. The file is `$HOME/.ernest/history`, from `Os.environment("HOME")`, and there is none where `HOME` is unset or is no absolute path (§11.2).

- **Format.** One input a line, oldest first, a newline in an input written `\n` and a backslash `\\`. Decoding reads left to right, since `\\n` is a backslash and an `n`, which two passes of `String.replace` would read as a newline. An empty line is passed over.
- **Reading.** `read` answers the inputs newest first, the order the editor walks. A file that holds more than `kept`, a thousand, is rewritten to the last thousand as it is read.
- **Writing.** `makeDirectory` makes the directory, its owner's alone, before the file is read or written, and `add` appends a line. The reader calls it as it takes an input and as `C-c` abandons one, where `Shell.Editor.keeps` says the input is kept. A write that fails is said once, and the reader keeps no more.

The session reads the file in `main` and hands the inputs to the reader in `Start`; the editor's history is those inputs and each input taken since, at most `kept` of them.

## Completion and documentation

`Shell.Complete.completion` decides from the line what may stand at the cursor, and the reader's `completing` asks it wherever `Tab` does not indent:

- in a command's name, the table's names (`commandWord`), without asking the parser, since a command is not the language's;
- after a command, what `Shell.Command.completes` says the command takes (`argument`);
- with only spaces before the cursor on its row, nothing: `Tab` inserts four spaces;
- anywhere else, what `slot` answers: the parser is given the text before the word, and says what it wanted where it stopped, a `Shell.Complete.Slot`.

The names come from the front end, which `Shell.Complete` asks, as `Shell.History` reads its file. `names()` is every name in reach, read from the compiled interfaces and the session, each with its kind and the line a listing shows, and `Shell.Complete.withNamespaces` adds the namespaces they are in. For the text before a `.`, `fields` checks it as an input in `$Fields`, which does not enter the session, so a chain of selections is the checker's and a name the unfinished input binds is not in scope; it answers the fields the text's type selects, from `ern_typecheck:fields/2` over §3.5's rule. With nothing typed, `namesFor` leaves out the prelude's constructors, keeping those the session declares (`sessionTexts`). For `:load`, `sourceModules` lists the one directory of the source root the typed segments name, so a large root is never walked, and names each entry with `segment`, the compiler's path-shape rule (§11.1).

`Shell.Complete.complete` is pure. It filters the names by the `Slot`, matches the typed word by prefix and by abbreviation, segment by segment, and answers a `Completion`: the word to stand in place of the one typed, and the candidates. The word replaces rather than extends, since an abbreviation is no prefix of what it reaches; `applied` puts it in the line. The reader's `offering` lists the candidates on a second `Tab`, on a `Tab` that changes nothing, and for a lone candidate, as the rows under the line in `ShowInput`; the next key's `ShowInput` carries none.

`Shift-Tab` is `documenting`. The whole name the cursor stands in (`Shell.Complete.wordAt`) is asked of `documentation`, which answers the page `:doc` shows, with its module's *Since* line added where the page has none of its own. A first press shows `brief`, read from the parsed page: the first line of its first code block, the first sentence of its prose (`Markdown.firstSentence`), and its *Since* line. A second press shows the whole page.

Where the name has no page, `signature` answers the call or constructor the input stops inside, in three parts: before the parameter at the cursor, the parameter, and after it. The parser records the innermost call on its diagnostic, `#diagnostic.within`, and the text is tried as an expression, a statement, and declarations, so a `let` and a `fn` body find it; the reader cuts a command's word off before it asks, so a command's argument finds it too. A function callee is checked as a one-name input in `$Signature`, and `ern_types:format_call/4` prints its declared type with the parameter names its documentation carries; the shell styles the middle part with `Shell.Style.emphasis`. Pages are rendered by `libs/markdown`, which the shell is built against, at the screen's width, or 80 columns where there is no terminal.

## Commands

`Shell.Command.commands` is the one table of commands: each command's name, its action, what it takes and what completes after it, and its help line. `commands_mirror_test`, in `test/ern_shell_tests.erl`, holds it equal to the list of §11.2 *Commands*. `parse` answers the refusal's text, or the action and the argument; `setting` parses `:set`'s argument. The session's `obey` carries each action out, most through the foreign function of its name. The settings are an Ernest value in the session's `State`, not the front end's, and `:set output n` sends the screen `SetHeight(n)`. `:processes` lists `Process.live()` less the session's own processes, by the site `Process.info` gives, and `:faults` reads the session's `State`.

## Faults

The session learns of every fault as a subscriber of `Process.faults` (E.21), and monitors nothing but the reader and the screen. The screen's end leaves the session nothing to show itself on, so the session faults with the screen's cause, a failure of the shell's own (§11.8). `reported` passes over a report of one of its own processes, the session, the screen and the reader, which it keeps as a `Set(Process)`, since a `Process` has equality where an address has none. It says every other report and keeps it, newest first, for `:faults`.

An input's process catches its own fault and answers it as its outcome, so no report of it comes but for a fault a signal brought, and `await` takes that report as the input's answer. `:load`'s initializing processes catch theirs likewise. So an input's fault is reported once.

A spawn site in an input's module is written as §11.2 *Faults* says. The emitter, told that it compiles an input and given the line offset its diagnostics use (`session_offset => 0`, or the lines before a startup input), writes a site in a declared function by the function's name. A site in `'$input'` is a call of `ern_shell:input_site/2`, which reads the name recorded for the input, `input 3` or the startup file's path. Each line is moved by the offset.

## Startup files

`startupFiles` finds the paths in Ernest: the person's, `Shell.History.startup`, beside the history's file and under the same rule for a HOME that is no absolute path, and then, where `--config-dir` names it, the configuration directory's `startup`, which the runner computes (§11.2) and `configStartup` answers. A file both name runs once, which `isSameFile` asks the host, by device and node. Each is named from the working directory (§11.5). Whose each is, the shell reads itself with `Fs.stat` and `Os.user` (`isUsersOwn`): the file and the directory that holds it owned by the user or the superuser, and writable by no one beyond owner and group (§11.2); one that is not is said and not run. Whether each is there, and what it holds, the shell reads with `Fs` too: a file that is not there is no error, one that cannot be read or is not UTF-8 is said, and `startupInputs` takes its inputs from its lines by line mode's rule, each carrying its file and the line it begins on. While a startup input runs, the session's `State` holds its file and line in `startupLine`, which `refuse` and a fault's report put before what they say. A `:` line goes to `perform`, as a typed command does; any other goes to `executeQuietly`, which is `execute` with printing off and the file and the line passed to `check`, so a diagnostic names them.

## Testing

- **The modules but `Shell`** are tested by their `Test` values (Appendix E.24, §11.2), at the foot of each file, which `make test-shell` runs for every module. Each of the editor's tests plays a list of events onto a fresh line and reads the text and the cursor; the region's read the bytes a redraw writes and where the cursor rests.
- **The session** is tested by `test/ern_shell_tests.erl`. A golden test is a file of inputs run in line mode, `test/session/basic.in`, against its expected output. A session that drives a program is not one, since where a fault report lands among the inputs depends on when the process faults; that test asserts what must be true of it instead.
- **The terminal** is tested through `test/ern_pty.py`, which gives the shell a pseudo-terminal and sends each key once the screen shows what the step waits for. With `--screen` it renders the writes onto a grid of the terminal's size, since a shell that repaints writes a line many times over, and what is painted is asserted on that grid.
