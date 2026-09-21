# The Ernest Shell: Design

The shell of MVP 2.6, `ern --shell` (report §11.2). The plan owns when it is built, the decisions log why it is as it is; this document owns what it is, as a specification to build from. First written 2026-09-19, rewritten 2026-09-20 once its decisions were settled; it grows as the checkpoints settle what is marked open.

## Shape

The shell is an Ernest program of three processes over a front end. Its source is a tree of its own, `shell/`, beside `stdlib/` and `examples/`, compiled by `make` into `build/shell/` where `ern --shell` finds it. It is not standard library, which E.0 would not admit it to, and not a library, which `libs/` holds from MVP 2.7; it is the toolchain's own program, written in Ernest.

- **The session** is the entry process (§8.1). It holds the `Env`, the queue of inputs, the settings, and the faults `:faults` prints. It receives inputs from the reader and outcomes and fault notices from the front end, and sends the screen what to print. It runs no user code.
- **The reader** owns the terminal's keys and edits the input. It stays live while an evaluation runs. It sends a submitted input, and the interrupt, to the session; it draws nothing itself.
- **The screen** is the only process that writes to the terminal, and the session drains it before it prompts and before it returns: the screen writes to the terminal itself, so the runtime's flush at the end of a program (§8.6) does not reach it, and the prompt must come after what an input printed whatever order two processes sent in. Its mailbox carries what a program printed, what the session prints, and the line and cursor the reader draws, so its type is the shell's own and not `String`; the runner binds `Sys.stdout` and `Sys.stderr` to `via(Output, screen)`, which §9.7's `Address(String)` requires and which costs no process (§6.5). What arrives there goes to the tail; what the session sends is committed to the transcript. A program's output and the shell's own reach one mailbox and are handled in its order, and the screen draws the line being typed again below whatever it has just written.
- **The front end** is the Erlang toolchain behind the foreign interface: checking, compiling, running, printing, exports, documentation, and the fault notices.

## Starting and quitting

`ern [--config-dir dir] [--load-path dir ...] [--main Qualified.name] [--shell] [--source-root dir] [file.erc]` (§11.2). The shell adds the last two: `--shell` takes no argument and makes the file optional; `--source-root` says where `:load` finds a module's source, the working directory by default, as `ernc` defaults it.

- **`ern --shell`** starts the runtime with the standard library and the load path, nothing else running.
- **`ern --shell file.erc`** loads the module and its dependencies and spawns its entry point beside the prompt, every loaded module in scope. The runner loads them, runs their initializers (§8.5), and hands the front end their interfaces; the shell spawns the entry point itself, so that it can monitor it.
- **The shell is the entry process** (§8.1); the file's entry point is spawned, not entered. §8.6 then reads as it always did, of the shell: the spawned entry returning ends nothing, its processes keep running, a fault in it is one more fault reported at the prompt, and `--main Q.name` names the function to spawn rather than the one to be.
- **The program's processes are the session's.** `:processes` sees them, `:faults` reports their faults, `:quit` ends them with `ProgramEnd` (§8.6). Until the door onto what the runtime knows about processes is built, the shell reports the entry point's own fault, which it monitors, and no other death.
- **An input cannot reach a process the program spawned.** There is no registry (§6.3), so the prompt has a running program's modules, its output, and its faults. A program meant to be driven from the prompt returns an address from the function that starts it.
- **At start the shell prints one line**, the version and how to leave, `:quit` or `C-d`, with `:help` for the rest.
- **Then it runs the startup inputs**, the person's and then the node's, after the file's entry point has been spawned, so a startup input sees what is running, and before the first prompt. On a terminal it waits for the reader to hold the keyboard first, so that a startup input which reads keys is refused as any other program would be (§8.2). A startup input that fails is reported as any input is and the session goes on.
- **On `:quit`, or `C-d` on an empty line**, every process the session spawned ends with `ProgramEnd`. The history is already on disk, each input appended as it was taken.

## The terminal

- **One module owns the terminal, `Terminal`.** It replaces `Keys`, which spoke for the keyboard alone: the terminal is the resource, and it sends two kinds of event. `Terminal.subscribe(wrap)` delivers `Event`, §9.3's one list of what the terminal sent — the characters and keys, and `Resized(Size)` — and `Terminal.size()` answers `Size(rows, columns)` now. §8.2's system process is the same one renamed, and `Sys.keys` becomes `Sys.terminal`.
- **The shell owns it, and the runner records the holder.** The runner starts the session's processes, so it marks the reader as the terminal's holder before anything else runs. `Terminal.subscribe` and `Io.readLine` from any other process end the caller with `Fault("the shell holds the terminal; run the program with ern to give it the keyboard")`. §8.2 gains no notion of a shell: a holder is recorded, and the runner is the one that can record it, because it made the process. The shell reads through `Terminal` and `Io.readLine` as any program does.
- **In line mode the holder holds standard input**, and the fault is the same. Line mode is what the reader uses when input is not a terminal: `Io.readLine`, no editing.
- **A program under the shell prints and nothing more.** Its terminal fault is reported like any other, so a person who types `Snake.main()` is told why it will not run here and how to run it.
- **The first prompt waits for the reader to hold the keyboard.** A subscription is answered once the terminal is in the mode the keys need (§8.2), and the reader says so; until then the terminal is still echoing lines, and what was typed at a prompt printed too early would be echoed twice and read as a line.
- **The interrupt is a key to the shell while it reads**, not §8.6's signal, and §11.2 says so. Every other program keeps §8.6's rule, so the interrupt still stops a game that reads keys. The shell is left with `:quit` or `C-d`.
- **The screen writes and nothing else does.** A program's print is an ordinary send; ordering is the screen's mailbox order. §8.2 is untouched: the runtime starts the system processes and binds their addresses, and a `String` sent to `Sys.stdout` still reaches standard output.
- **The size is asked for at each redraw, and a resize is an event.** `Terminal.size()` gives the size the redraw uses; `Resized` arrives on the same stream as the keys, so a window that changes while the session is idle is repainted then and not at the next keystroke.

## The screen

A line the shell has finished with is *committed*: written into the terminal, scrolled by the terminal, never touched again, so that the scrollback, the search and the selection stay the terminal's own. The last rows of the screen are *live*: the shell owns them and repaints them. **Nothing is ever written below the live region**, which is what makes the drawing correct.

- **The live region is the line being typed, and above it a tail of what programs have written.** Everything else — inputs, values, diagnostics, command output, fault reports — is committed to the transcript as it is produced.
- **The shell never addresses a row.** It did not clear the screen, so it does not know where on it the region sits, and never asks. Four operations do all the drawing:
  - **erase**: `\r`, then `ESC[nA` up from the row the input is typed on to the region's first row, then `ESC[0J`, which clears the region and everything below it — correct because nothing is written below it;
  - **paint**: the region's rows separated by line feeds, the terminal scrolling if the region sits at the bottom, then `\r` and `ESC[nC` to put the cursor after what has been typed, which is the row the painting ended on;
  - **commit**: erase, the line and its line feed, paint again;
  - and the count of rows painted, which is what the next erase moves up by.
  Between messages the cursor rests where the caret belongs, after the line being typed, since that is where a person looks for it.
- **The terminal's width is the only measurement.** It clips a row that would wrap; `Terminal.size` answers it and `Resized` says when it changed, which repaints the region.
- **The tail is five rows by default.** It is a window and not a pane: a line that leaves it is committed, so a small one costs nothing and keeps the prompt near the bottom. `:set output n` sets the rows, and `:set output 0` is no tail at all, a program's output committed as it arrives and interleaved with the transcript in the order it was written.
- **The region never takes more than half the screen.** The tail shrinks to what is left when the window is short or the input is long, since the line being typed must be visible; `:set output n` asks for rows and does not command them.
- **The tail keeps no scrollback of its own**, and no offset. The terminal holds the history, a person scrolls it with the terminal, and the shell's own `PageUp` has nothing left to do.
- **A program's partial line waits in the tail.** A write that does not end in a line feed is the tail's last row until the line feed comes.
- **The tail is committed before the session says anything.** A line of the transcript is written after whatever the tail holds, so the terminal's scrollback reads in the order the lines were written and the tail holds only what has arrived since the last thing the shell said.
- **A line the shell writes while an input is being typed keeps the prompt.** What the session says takes the prompt with it, an input having finished; a note made mid-input, such as the hint above, is committed above the region and the prompt stays where it is. Two messages, `Said` and `Noted`, because they are two acts.
- **The reader does not echo.** It tells the screen the line being typed, and the screen paints it, since a region that is repainted must draw that line again. It is also what the line editor needs.
- **A fault report is the shell speaking**, so it is committed to the transcript like the session's other lines.
- **With no terminal there is no live region.** Everything is written as it arrives, which is what a session read from a pipe wants, and what the session golden tests read.
- **On `:quit` the region is erased and the cursor left on a fresh line**, so that the terminal is as the shell found it and the transcript above it stays.

## Input

- **A line complete by itself is submitted by `Enter`.** The prompt is `> `; a multi-line input continues after `... `.
- **An incomplete line starts a multi-line input.** A line is incomplete when the parser runs out of input where more was expected, or the lexer ends inside a raw string or a block comment, both of which may span lines; a string or a char literal may not (§2.5), so an unfinished one is an error whatever follows. The parser marks its diagnostic, and the shell reads the mark. The shell never counts brackets itself: that is a second parser, to disagree with the first.
- **A blank line always submits**, incomplete or not; what does not parse gives its error. So `Enter` twice is the way out of a multi-line input. An input with nothing in it submits too, though the parser cannot finish it: `Enter` at an empty prompt gives a new prompt, as it always has.
- **The key decoder is ours.** OTP 29's `io_ansi:scan` scans terminal capabilities rather than keys: `\e[F` comes back as `cursor_previous_line`, which is not what the End key means, and a page key as a raw sequence. The decoder stays the runtime's own, and the measurement is in the decisions log, with the two flags of the host's raw mode that the runtime puts back.
- **`M-Enter` adds a line to an input the parser thinks is finished**, which `type Shape = Dot` is before its alternatives and an `if` is before its `else`.
- **The first multi-line input of a session prints `M-Enter adds a line, Enter runs.`** on a line of its own above the `... ` prompt, once; `:help` lists it. Not on the prompt itself: a hint there would shift the input's column for that line only, so the second line of a declaration would not line up with the third.
- **A paste is one input.** The shell turns on the terminal's bracketed paste; a pasted text, blank lines included, is submitted by the `Enter` after it. It is checkpoint 3's work: `\e[200~` and `\e[201~` have to reach the decoder, which is a §9.3 question when it is built.
- **Functions that call each other are entered in one input.**
- **Each input is compiled as a module of its own**, against the environment so far, and loaded. Its namespace is `Input<n>`, counting from 1 in the session, which a person sees: a fault in a process spawned at the prompt reads `Input3.main:1 faulted: division by zero` (§6.9). A module on the load path called `Input3` is unreachable in a session that has got that far.
- **The reader stays live while an evaluation runs.** What is typed is echoed and edited; `Enter` queues the input to run when the one before it finishes, and several queue in order.
- **A queued input is checked when it runs, not when it is typed**, since the input before it may bind the name it uses. The queue holds text.

## The session

An input is a block: the prompt is `main`. It may declare anything a module may, and its `let`s and expressions behave as they would in `main`.

- **A `let` binds as a block `let` does**, monomorphic and allowed to be effectful, which is what `let a = Chat.start()` and `let a = spawn(Local, f)` need. A top-level `let` would be neither: §4.6 generalizes it and requires a pure initializer.
- **An input that binds with `let` declares nothing else.** A block has one value, and the input's is what its `let` binds; a second `let`, or a `let` beside a declaration, would be a top-level `let`. The error says to run it on an input of its own. `let T.name` is a member declaration and is none of this.
- **Every declaration an input makes is exported**, since the session is what it is declared for; `export` at the prompt adds nothing.
- **A `fn` declaration generalizes** as a `fn` does anywhere (§3.9). So `fn id(x) = x` is polymorphic and `let id = fn(x) = x` is not; when a `let`-bound function is used at a second type, the error says to declare it with `fn`.
- **A declaration or a `let` binds for the inputs after it.** A later declaration of a name is seen by later inputs; a function or closure made before it keeps the one it was compiled against.
- **The session is a scope, and §11.2 says so, not §4.2.** An unqualified name is looked up in the input's own declarations, then the type-member namespace of the enclosing declaration, then the session's declarations, then the prelude. A prompt declaration may shadow a prelude name exactly as a module's may.
- **A type declared in the session prints unqualified**, where §11.5 prints another module's qualified. One a later declaration of its name has shadowed prints under the input that declared it, `Input1.T`, since two types of one name printing alike would give `expected T, found T`; it is §11.5's rule for a type that shadows a prelude name, applied to the session.
- **A member of an abstract type is declared with the type.** Two inputs are two modules and §4 keeps a type's members in the module that owns it, so a later input cannot add one.
- **The value of the last expression is bound to `it`.** It is the one binding a person did not write, and principle 3 is satisfied: a binding must be visible where its name appears at the use site, and `it` is written at its use site. `:bindings` lists it and `:help` says it.
- **Bindings survive a fault and an interruption.** Only `:forget` removes them.
- **An input whose value is reply-carrying does not check** (§6.6): such a value neither bound nor consumed is a type error, and the prompt drops an input's value once it is printed. So `it` is never one.
- **`self()` names the input's own process**, which ends with the input. An address bound to it reaches no one on a later input.

### The environment

The front end owns the session's state and the shell holds it as one opaque `Env`. The type system decides this: bindings differ in type, and Ernest has no heterogeneous collection, so a shell holding the values itself could hold them only as `Foreign`.

`Env` holds four things:

- **Types** — `type`, `abstract type`, `foreign type`, each with its constructors, its fields, and an abstract type's members. They persist because later bindings hold their values and the printer renders a value by its type.
- **Value bindings**, each with its type, `it` among them. A value carries the type it was made with, so one made before a type changed shape still prints by its own descriptor.
- **Declarations that are code** — `fn` and `foreign fn`, with their types and their targets.
- **The compiled modules behind all of it.** Each input's module stays loaded, since a closure made before a redeclaration keeps the code it was compiled against. Input modules never displace each other, each having its own name.

`Env` is a module interface plus the values behind it: `#iface{namespace, types, values}` is what an `.erc` carries (§11.1), and the shell's is that accumulated, with a value store and the loaded modules alongside.

### How an input reaches the session

Settled by the spike of 2026-09-20, which ran it end to end before any of this was built.

- **The checker takes the session as a fourth argument**, three maps, one for values, one for types and one for constructors, each from an unqualified name to the qualified name of the input that declared it. It is a scope of its own, looked in after the input's own declarations and before the prelude, which is §11.2's order, and not the module's own maps seeded with the session's.
- **A declaration the session made is refused where a module's would be.** An abstract type's constructor is its input's alone (§4.4), so a later input neither builds with it nor matches on it.
- **Resolution rewrites the reference.** A name the session declared is rewritten, as it is typed, to the input that declared it, so that everything downstream sees an ordinary cross-module value. Without it the emitter meets a bare name it has no declaration for and refuses to emit; with it the emitter needs to know nothing about a session at all.
- **A value lives where a module's own values live.** The emitter already compiles a module-level value to a getter over the runtime's store, keyed by the module and the name, and a reference from another module to a call of that getter. A session binding is one of those, so reading one needs no new mechanism.
- **What is new is publishing.** A `let` at the prompt is a block `let`, so its value is computed in the input's process and not by the module's initializers (§8.5); the input's module writes it to the store as it ends, which is the initializers' own act moved to where the value is made.

It does not hold the shell's settings, which are ordinary Ernest values; the history, a `List(String)`; or the modules on the load path, which are found by namespace (§4.2).

**A session never shrinks.** Code cannot be unloaded while a closure may reference it, so `:forget` removes a name and frees nothing. The module and atom tables grow with it, each input being a module and each constructor an atom, neither of which the host reclaims. It is a property and not a defect: a session of thousands of inputs grows both, and one that runs for days is restarted. Shadowing is by name in the environment, not by replacing code, which is why an old closure keeps working.

## Running an input

- **Each input runs in a fresh process**, whose mailbox type is the input's own inferred effect, a polymorphic one instantiated to `Never` as an entry point's is (§8.1).
- **The front end starts that process**, since its mailbox type is known only once the input is checked, and answers with its address, which is what `C-c` kills.
- **The outcome arrives as a message**, `Ok` with the new `Env` and the value, or `Failed` with the fault's text. A fault comes back as an outcome, so nothing needs monitoring.
- **A fault or an interruption ends that process only.** The session reports it and keeps the bindings. The session process never runs user code.

## Output

- **An expression prints its value and its type**, the type as the checker prints it (§11.5): `3 : Int`. An expression of type `Unit` prints nothing, so `Io.println("hi")` answers `hi` and not `hi` then `Unit : Unit`. A declaration prints its name and type, `double : (Int) -> Int`; a `let` its name and type, `xs : List(Int)`; a type declaration its keyword and its name, `type Shape`. An input that declares several prints a line for each, in the order they were written.
- **A value is printed as `Io.debug` prints it** (E.1), by its type. The shell and `Io.debug` share one printer, `ern_show`, which takes a depth and a length that `Io.debug` passes unbounded; E.1 is unchanged, a program's `debug` printing the value.
- **A large value is printed to that depth and length**, the rest as `...`. The defaults are depth 10 and length 100, and `:set depth 0` or `:set length 0` is neither: the defaults print whole what a prompt is used for and stop a value that would scroll the session away. Depth counts the brackets a reader would open, so a number or a string is never `...`.
- **An input that does not check is shown as `ernc` shows an error** (§11.5), the input as the source and the span underlined. Nothing is run.
- **A fault in an input is printed as `fault: ` and its text**, an interruption as `Killed`.
- **A process that faults is reported** with its spawn site and cause: `Counter.worker:23 faulted: division by zero`. Which deaths are reported is "Failing processes".
- **With timing on, each result is followed by its elapsed time**, of the run alone: the check is not what is being measured.
- **Output from another process while a line is being typed** goes to the tail, above the line, which is drawn again below it.

## Failing processes

The shell reports a process that faults; a compiled program keeps its silence, and `monitor` stays the one way a program learns (§6.9).

- **The shell cannot monitor what it cannot address.** There is no registry, and a process is reached only through an address someone holds (§6.3).
- **The front end is told instead.** The runtime remembers how every process it started ended, and `Down` carries the spawn site with its line (§6.9); the front end registers a watcher, which is told of every death and decides which are news.
- **Faults only.** `Returned`, `Killed`, and `ProgramEnd` are not news, and a program that spawns a process for each connection would scroll the session away.
- **The program's processes, not the shell's own.** The shell cannot tell them apart, addresses having no equality (§6.3). Each of the shell's own processes says so from inside itself, since an address handed to a foreign function arrives as the checking proxy in front of it (§8.4) and the process behind it is not what the front end would hold. The input's own process is left out by the front end, which made it, its fault being the outcome already. So an input's fault is reported once.
- **One line, written by the screen**, as all output is.
- **The last hundred faults are kept** and `:faults` prints them, oldest first.
- **`Deadlock` does not fire under `--shell`** (§8.6): the shell always holds a subscription to the keys, or a read outstanding in line mode, and a system process holding one is a source that can still deliver. A program whose processes all block gets no report, and `:processes` lists them as live with no hint.
- **Reporting the program's own quiescence is later**, on the door built for the faults and the live list.

## Line editing

GNU Readline's Emacs bindings.

- **The editor is a module of its own**, `Shell.Editor` in `shell/shell/editor.ern`: a pure function from the line being edited and an event to what the reader must do, `Typing`, `Submit`, `Cancel`, `Clear`, or `Leave`. The reader sends the screen the line and the session what was entered; the editor writes nothing.
- **`Escape` and `Meta`:** §8.2 delivers `Escape` alone once no sequence can follow it, so an `Escape` followed at once by a character is `Meta` and an `Escape` that stands alone is the key. `M-b` arrives as `Escape` then `Char('b')`, and `Shift-Tab` as `Escape` and its bytes.
- **Moving:** `C-a`, `C-e` to the start and end of the line; `C-b`, `C-f` a character; `M-b`, `M-f` a word; the arrow keys.
- **Deleting:** `Backspace` and `C-h` back, `C-d` forward; on an empty line `C-d` quits.
- **Killing:** `C-k` to the end of the line, `C-u` to the start, `C-w` and `M-Backspace` the word before, `M-d` the word after; `C-y` yanks the last kill, which outlives the line it was killed from.
- **History:** `C-p`, `C-n`, up and down step through earlier inputs, a multi-line one coming back whole, its lines under their continuation prompts and the cursor at the end; `M-<` and `M->` go to the first and the current; `C-r` searches back incrementally, `C-s` forward, `C-g` abandons the search and puts back the line it began from. A search shows Readline's prompt and the input it found in place of the line, after the shell's own `> `, with the cursor on the match; one that matches nothing says `failed` and keeps the input it last found.
- **The history file is the person's**, `$HOME/.ernest/history` (report §11.2), read at start and appended to as each input is taken, an input abandoned with the interrupt among them. `Shell.History` is the module: only the path is `foreign`, and the reading, the escaping and the trim are Ernest over `Fs` ([`decisions.md`](decisions.md)).
- **Adding a line:** `M-Enter`, when the input parses complete and is not.
- **Interrupting:** `C-c` kills the running evaluation when there is one, and abandons the input being typed, every line of it, only when there is not. The bindings and the partial line survive, and the text goes to the history to recall and mend. A queued input is dropped with the evaluation it waited for.
- **A paste is one event.** The runtime asks the terminal to bracket a paste while a program reads keys (§8.2), so pasted text arrives as `Pasted` with its line endings as line feeds; the editor puts it in the line at the cursor, and its line feeds add rows rather than running the input. A terminal that does not bracket a paste sends the characters, and each line feed in them runs what is typed so far, as typing does.
- **`C-l`** clears the screen and keeps the line being typed. What was committed before it stays in the terminal's scrollback.
- **Later:** colour and the suggestion, which go together since grey is how a suggestion is told from what was typed; and the kill ring with `M-y` cycling, `C-t` and `M-t` transposing, `M-u`, `M-l`, `M-c` for case.

## Completion

- **`Tab` completes a qualified name segment by segment:** `Li` to `List.`, `List.ma` to `List.map`.
- **A second `Tab` lists the candidates**; at `List.` it lists the exports of `List` with their types.
- **Candidates are matched by prefix and by abbreviation:** `L.fM` and `List.fm` complete to `List.filterMap`, matching capitals and segment starts.
- **What completes, by position:**
  - in an expression, the bindings, the modules on the load path, and their values and constructors;
  - after `:` in a type annotation, types;
  - inside a named constructor, in construction, update (`Player(..p, `), or pattern, its remaining fields;
  - at the start of an input, after `:`, a command; after a command, its argument: names for `:type` and `:doc`, modules for `:browse` and `:load`, the bindings for `:forget`, `depth`, `length`, `output`, and `timing` for `:set`.
- **Reserved words and operators do not complete.**
- **Completion reads the compiled interfaces**, held in memory once read.
- **`Shift-Tab` shows documentation.** On a name: its type, its first sentence, and its `Since`; a second `Shift-Tab`, the section `:doc` prints. Inside a call: the signature with its parameters as declared, `circle(centre : Point, radius : Int) -> Shape`, the parameter at the cursor marked.
- **Later, by type**, once the checker can check an unfinished input:
  - at `match e {`, `Tab` inserts one clause per constructor of `e`'s type, each body `todo("")`, and in a partial `match` the clauses the exhaustiveness check finds missing (§5.9);
  - in `send(a, ` and in a `receive` clause, the constructors of the mailbox type;
  - after `xs |> `, the functions whose first parameter fits `xs`;
  - as an argument, the bindings of the parameter's type.

## Commands

A command is `:` and a name; it is not an Ernest function. Any prefix selects the command, and an ambiguous prefix selects the first in the order below: `:t` is `:type`, `:b` `:browse`, `:l` `:load`, `:r` `:reload`, `:q` `:quit`, `:d` `:doc`, `:f` `:forget`, `:fa` `:faults`, `:o` `:output`.

- **`:type e`** — the type of `e`, which is not run; it answers `e : T`, the expression as it was written.
- **`:browse Module`** — the exports of `Module` with their types.
- **`:load Module`** — the module by its namespace, never a path. Its source is found under the shell's source root and compiled as `ernc` would compile it; a module with no source there, the standard library's or a library's, is loaded from its compiled form. A source under the source root wins over an `.erc` on the load path. Afterwards the module is in scope by its qualified name, like anything else on the load path.
- **`:reload`** — every loaded module whose source differs from the one it was compiled from, as `:load` would take each; it takes no name, `:load Module` being that already. What is compared is the source's hash against the one the compiled module carries (§11.1), not a modification time. A call from another module reaches the new code. A process running the module's own loop does not: it keeps the version it is in until it returns, which is the case §6.10 exists for. A closure made from the previous code keeps that code while the version lives. The first reload names the processes and bindings in the previous version, by spawn site and by name, and says that a further reload of that module ends them; that reload ends them and says which, the processes with the cause of §7.3. A death `:reload` reports is not reported twice: the fault reports leave out a process it ended.
- **`:quit`** — quits, erasing the live region and leaving the cursor on a fresh line.
- **`:doc Name`** — the documentation of `Name`, as `ernc --doc` renders it (§11.4), the declaration included.
- **`:help`** — the commands and their prefixes; it says that `:doc` is what GHCi calls `:info`.
- **`:forget name`** — forgets any name the session declared, a value, a `fn`, or a type. A name is required; `:forget *` clears the session, `it` included. Forgetting a type needs no rule of its own, a value carrying the type it was made with; it takes the type's members and its constructors with it, except a constructor whose name a later type has taken.
- **`:bindings`** — what the session declares, with their types: its types first, then its values, `it` among them, and a type member under the type that owns it. It says so when the session declares nothing.
- **`:processes`** — the live processes with their spawn sites (§6.9), read through the same reference as the faults; a name and a site, never an address.
- **`:faults`** — the faults reported since the session began, oldest first.
- **`:output <path>`** — a program's output goes to that terminal or file instead of the tail, so a second window shows it with the terminal's own scrolling; `:output` alone says where it is going, and `:output -` brings it back. The path is opened by the front end and not by an Ernest program, so `Fs` is not involved and the shell gains no file system of its own. A file is appended to, never truncated, and the device is not opened `raw`: what writes to it is the sink's process and not the one that opened it.
- **`:set depth n`**, **`:set length n`**, **`:set output n`**, **`:set timing on`** and **`off`**; `:set` alone shows what they are. The settings are one Ernest value the session carries, not the front end's.
- **The order the prefix rule reads is the whole order, whatever is built.** A command built later would otherwise change what a prefix means, `:f` being `:faults` one day and `:forget` the next; every one was in the list and in `:help` from the first, and one not yet built said so and named the checkpoint that brings it. All twelve are built.

A program is started by calling it; there is no command for it. A module meant for the shell exports a function that spawns its processes and returns. Modules are not imported: every module the session has loaded is in scope by its qualified name (§4.2), which is the file's own modules and the standard library until `:load` brings in another.

## Files

- **`$HOME/.ernest/history`** — the history, per user, as a person expects when they type the same thing in two projects. With `HOME` unset nothing is saved and the shell says so once.
- **`$HOME/.ernest/startup`, then the configuration directory's `startup`** — the inputs run at start, commands included, a line an input and neither file required. The person's runs first and the node's after it, so a node adds to or overrides what a person always wants; `--config-dir` moves the second. Neither is a module and neither has a `.ern` extension: a `.ern` file under a source root is compiled with the project, and one in the configuration directory breaks the project's build, since `ernc` reads dotted directories and then rejects the path.
- **A startup input shows nothing unless it fails.** Its value is not printed, a startup file being setup rather than a session; what does not check, or faults, is reported as any input is, under the path of the file it came from rather than `input`.
- **The configuration directory** (§11.2, §11.3) is the node's, holding its address, its keys, and the node's own startup inputs.
- **`:load`'s compiled output** goes to a directory of the shell's own, never beside the source, where it would land in the project's build and meet §11.1's cleanup sweep.

## Not in the shell

- **Building an address from numbers:** an address is a capability.
- **A mailbox that persists between inputs, and a command to flush it:** each input has its own process.
- **Commands for records and registered names:** Ernest has neither.
- **A second lookup command beside `:doc`, and a kinds command:** `:doc` shows the declaration, and Ernest exposes no kinds.
- **Commands for the file system and the terminal:** `Fs` does this in the language.
- **Declarations read from a file into the session:** `:load` takes a module and makes it reachable by its qualified name, as every module is (§4.2). Ernest has no imports, so names arriving unqualified from a file would have been the one place they did; a module's private declarations are no more reachable from the prompt than from anywhere else.
- **A pager:** the transcript is committed to the terminal, so the terminal's own scrolling and search read a long page. One with its own key bindings would fight the live reader for the keyboard.
- **Running a terminal program from the prompt:** the shell holds the terminal, so a program that reads keys or lines is run with `ern` instead. The fault says so.
- **Custom printers:** a value has one rendering.
- **User-defined commands, system commands, job control, a step debugger, and watch expressions.**
- **Later, each on its own merits:** re-running an earlier input by number, `:trace f` to print each call and return of `f`, and, with MVP 3's peers, a shell attached to a running node. The design does not assume the shell runs on the node whose code it evaluates.
- **Two panes were refused, built, and refused again.** The note first ruled them out for three costs; they were built on 2026-09-20 and replaced the next day by the live region, which pays none of them: the transcript is the terminal's, so its scrollback, search and selection keep working, nothing is cleared and nothing jolts, and the tail answers what the split was for. A second window is the one thing no single terminal can give, and `:output <path>` gives it outside.
- **Two terminals with the terminal's own behaviour:** that is `tmux`, or two pseudo-terminals and an emulator, and neither is a shell's work.

## Foreign interface

A sketch, settled at checkpoint 1. The user's values are handles of distinct foreign types, so the shell cannot pass one kind where another is expected; types reach the shell as text.

```
foreign type Env      // the session so far: see "The environment"
foreign type Checked  // a checked input
foreign type Value    // a result, with its type
type Outcome = Ok(env : Env, value : Value) | Failed(String)
type Fault = Fault(site : String, cause : String) // the spawn site of §6.9 and the cause

foreign fn start(loadPath : List(Path), sourceRoot : Path) -> Env with m = "..."
foreign fn check(env : Env, input : String) -> Either(String, Checked) = "..."
foreign fn typeText(c : Checked) -> String = "..."
foreign fn declared(c : Checked) -> List(#(String, String)) = "..."
foreign fn run(env : Env, c : Checked, to : Address(Outcome)) -> Address(Never) with m = "..."
foreign fn show(v : Value, depth : Int, length : Int) -> String = "..."
foreign fn exports(module : String) -> List(#(String, String)) = "..."
foreign fn doc(name : String) -> Optional(String) = "..."
foreign fn faults(wrap : (Fault) -> m) -> Unit with m = "..."
foreign fn isTerminal() -> Bool with m = "..."
foreign fn write(text : String) -> Unit with m = "..."        // the screen's own
foreign fn setScreen(to : Address(String)) -> Unit with m = "..."
foreign fn fields(env : Env, constructor : String) -> List(#(String, String)) = "..."

foreign fn load(env : Env, module : String) -> Either(String, Env) with m = "..."
foreign fn reload(env : Env) -> Either(String, #(Env, List(String))) with m = "..."
foreign fn bindings(env : Env) -> List(#(String, String)) = "..."
foreign fn forget(env : Env, name : String) -> Env = "..."
foreign fn processes() -> List(#(String, String)) with m = "..."
```

`start` makes the first `Env`, the load path and the source root in it, and every later one comes from an outcome. `check` returns §11.5's diagnostic text on an error. `run` starts the input's process, answers with its address, and delivers `Ok` or `Failed` when it ends, which is E.0 rule 8's shape for anything that arrives later. It takes the address rather than a wrap, as the sketch had it: §8.4 makes a function value a handle foreign code may pass back but not inspect, and calling one is not passing it back, so the shell wraps at its end, `run(env, c, via(Done, self()))`, and the front end only sends. `typeText` is the type of an expression, for `:type`, which does not run it; `declared` is the names and types an input declares, which the shell prints and cannot read from an opaque `Env`. `exports` gives names with types, `doc` the section `:doc` prints, `faults` subscribes to what "Failing processes" shows. `fields` gives a named constructor's fields with their types, which completion needs and cannot get from `exports`, types crossing as text and the shell owning no parser of its own. The last five are the commands that reach past the shell: `load` and `reload` answer with the environment they made, `reload` also naming the modules it took; `bindings` and `forget` read and shrink the environment the shell cannot look into; `processes` asks the runtime what is alive. The processes `reload` ends need no shape of their own, §7.3 giving them a cause, so they arrive through `faults` as any other end does.

## Prerequisites

Delivered before the shell. Those marked report first are written into the report before the code.

- **`Terminal`** delivers the arrows, the page keys, `Enter`, `Escape`, and characters, and the window's size as `Resized` (§9.3's `Event`). A sequence that is none of those arrives as `Escape` and the characters after it, which is how `Meta` and `Shift-Tab` reach the editor.
- **`Key` gains one value for the terminal's interrupt** (§9.3), delivered only to the terminal's holder. A subscriber receives `Key` values and nothing else (E.16), so without it the byte cannot arrive. Report first.
- **§7.3 gains the cause** a process ends with when its code is replaced under it, which `:reload` reports. Report first.
- **The terminal is the shell's when `--shell` is given** (§11.2), and §8.2 gains the case: subscribing to the terminal and `Io.readLine` from anything else fault with the remedy in the text. Report first.
- **The shell reads the terminal's interrupt as a key while it reads** (§11.2), which no other program does; §8.6's signal stands for them. Report first.
- **The terminal's size**, asked for at each redraw, and a notice when it changes: `Terminal.size` and `Resized`, in checkpoint 2. Report first.
- **Whether input is a terminal**, for line mode. Not in the report; report first.
- **What the runtime knows about processes** — one system reference for two questions: subscribe me to the faults, and what is alive with its spawn site. The runtime holds both (§6.9); neither hands out an address, so §6.3 stands. Not in the report; report first.
- **§11.2 states the shell's normative core:** the flag without an argument and the file optional with it; the shell as the entry process (§8.1) with the file's entry point spawned beside it, and what `--main` then names; the session as a scope in §4.2's lookup order, with a session type printed unqualified (§11.5); the terminal's holder; the interrupt read as a key; `Deadlock` not firing while a shell holds a source; types on every result, a module and a process per input, bindings that survive a fault, the commands and their prefix rule, and line mode.
- **`ern_show` takes a depth and a length**, which `Io.debug` passes unbounded, so the shell and E.1 keep one printer. A runtime change, not a report one.
- **The parser answers that an input is incomplete**, distinctly from a diagnostic: it ran out of input where more was expected. It knows already and does not say. A front-end change; built 2026-09-21 as a flag on the diagnostic, since the parser has the diagnostic in hand and nothing else can tell.
- **`ern` takes no file when `--shell` is given**, which today it demands, and its usage line grows `--source-root`. A toolchain change.
- **Documentation in the `.erc`**, with each function's parameters as written, for `:doc` and `Shift-Tab` (MVP 2.5 step 6, done).

## Open

- **How the line editor measures wide characters.**

Settled since this list was written: the depth and length defaults are 10 and 100; a hundred faults are kept; `:load` compiles in memory and writes nothing, so there is no output to place; and the foreign interface is what `shell/shell.ern` declares.

## Testing

- **A session is a golden test:** a file of inputs run in line mode, `ern --shell < session.ern`, against a file of expected output, under `test/`. A session that drives a program is not one: where a fault report lands among the inputs depends on when the process faults, so that session asserts what must be true of it instead.
- **The line editor is tested on its own**, being the one part of the shell with no processes in it: its tests are top-level `Test` values in `Shell.Editor`, key lists played onto a fresh line with the text and the cursor read off, run by `ern --test` (§9.3) and by `make test` with it. The history file's escaping and the region's geometry, what rows an input takes and where the cursor rests in them, are tested the same way.
- **Completion is tested on the foreign entries' answers:** a prefix and an environment in, candidates out.
- **What is painted is asserted on the screen, not on the writes.** The harness renders the writes onto a grid of the terminal's size with `--screen`, since a shell that repaints writes a line many times over.
- **A paste is read a character at a time like everything else**, so the decoder keeps what has arrived until the terminal's end marker comes; the cost is that a very large paste is rescanned as it grows, which no paste at a prompt has felt.
- **The terminal itself is tested through the harness**, `test/ern_pty.py`, which gives a program a pseudo-terminal, sends keystrokes when the screen says the program is ready for them, and reads the screen back; built 2026-09-20, before the shell, and holding §8.2's rules, the shell's own keys, and `snake` under test. A test waits for what it expects on the screen before it sends; a wait on the clock is left only where no text marks the moment, such as letting the game run a few ticks.

## Checkpoints

The plan's item stops at each; each is a shell a user can try.

0. **Expressions only.** The `shell/` tree, its `make` rule into `build/shell/` with the guard the standard library's build has, and `build/shell` on `bin/ern`'s code path; the three processes and the foreign interface; an input checked against the load path, compiled, run in a process, its value and type printed; faults, errors, quitting. The reader is the floor and no more: characters, `Backspace`, `Enter`, `C-d`, and the interrupt; the line editor is checkpoint 2. No bindings, so no incremental checking: a calculator over the whole standard library, with the loop and the terminal harness proved end to end before the hard part begins.
1. **Bindings.** Every input checked against the accumulated environment; `it`, timing, fault reports from spawned processes, the startup file, the commands; the session golden tests.
2. **The terminal and the live region.** `Terminal` replaced `Keys` and gained `size` and `Resized`, and §9.3's `Key` folded into one flat `Event`, decoded by our own decoder: `io_ansi:scan` was measured and does not fit. The panes it was first built with were replaced the next day by the live region above: the transcript committed to the terminal, the shell painting only the bottom rows, and `:output <path>` for a second window.
3. **The line editor.** Moving, deleting, killing with a single yank, history and its search, interruption, redrawing after other output, bracketed paste, the prompts; the key-stream tests. What "Line editing" marks later is later.
4. **Completion and documentation.** `Tab`, `Shift-Tab`, command arguments.
