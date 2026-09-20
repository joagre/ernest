# The Ernest Shell: Design

The shell of MVP 2.6, `ern --shell` (report §11.2). The plan owns when it is built, the decisions log why it is as it is; this document owns what it is. First written 2026-09-19; it grows as the checkpoints settle what is marked open.

## Structure

The shell is an Ernest program. Its parts:

- **The reader** reads keystrokes through `Keys` and edits the line itself; §8.2 lets a program read keys or lines, never both. When input is not a terminal it reads lines with `Io.readLine`, without editing: line mode.
- **The shell owns the terminal, and the runner says so.** When `--shell` is given the terminal belongs to the shell, and `Keys.subscribe` and `Io.readLine` from anything else end the calling process with the fault `Fault("the shell holds the terminal; run the program with ern to give it the keyboard")`. It is a fact about how `ern` was invoked, not about who is asking: the runtime cannot tell the shell from the program it runs, since they are one program in one node. §11.2 states it and §8.2 gains the case. Taking it from first come instead would have forbidden a second `Keys` subscriber, which E.16 allows, and that is changing the language to solve the shell's problem.
- **A program under the shell prints to stdout as any other does**, and that is all it gets. The shell reports the terminal fault like any other, so a person who types `Snake.main()` is told why it will not run here, and how to run it.
- **The front end** is the Erlang toolchain, reached through the foreign interface below: checking, compiling, running, printing, listing exports, documentation.
- **The evaluator** runs each input in a fresh process, whose mailbox type is the input's own inferred effect, a polymorphic one instantiated to `Never` as an entry point's is (§8.1). The shell monitors it (§6.9). A fault or an interruption ends that process only; the shell reports it and keeps its bindings. The shell's own process never runs user code.
- **The printer** prints results as below.
- **The commands** are below.

## Starting it

`ern [--shell] [file.erc]`, report §11.2. The flag takes no argument, and with it the file is optional.

- **`ern --shell`** starts the runtime with the standard library and the load path, and nothing else running.
- **`ern --shell file.erc`** loads the module and its dependencies, runs its entry point, and gives a prompt beside it, every loaded module in scope. The program's processes are the session's: `:processes` sees them, `:faults` reports their faults, and `:quit` ends them with `ProgramEnd` (§8.6).
- **An input cannot reach a process the program spawned.** There is no registry (§6.3), so what the prompt has of a running program is its modules, its output, and the report of its faults. A program that means to be driven from the prompt returns an address from the function that starts it.
- **`ern` takes no file when `--shell` is given**, which today it demands; the usage line changes with the shell.

## Input

- **A line that is complete by itself is submitted by `Enter`.**
- **An incomplete line starts a multi-line input**, which ends at a blank line. A line is incomplete when a bracket is open or an expression or declaration is unfinished. The blank line is required because a type whose alternatives follow on later lines, led by `|`, parses as complete after its first.
- **A paste is one input.** The shell turns on the terminal's bracketed paste; a pasted text, blank lines included, is submitted by the `Enter` after it.
- **Each input is compiled as a module of its own** against the interfaces of the bindings so far, and loaded.
- **Functions that call each other are entered in one input.**
- **The prompt is `> `**; a multi-line input continues after `... `.

## Bindings

- **A declaration or a `let` at the prompt binds for the inputs after it.**
- **A `let` at the prompt generalizes as a top-level `let` does** (§4.6): after `let id = fn(x) = x`, both `id(1)` and `id("a")` check.
- **A later declaration of a name is seen by later inputs.** A function or closure made before it keeps the one it was compiled against.
- **The value of the last expression is bound to `it`.**
- **Bindings survive a fault and an interruption.** Only `:forget` removes them.
- **A member of an abstract type is declared with the type.** Two inputs are two modules, and §4's ownership rule keeps a type's members in the module that owns it, so a later input cannot add one; the type and its members are declared in one input or loaded from a file.
- **`self()` names the input's own process**, which ends with the input. An address bound to it reaches no one on a later input; a message is received inside the input that expects it.

## Output

- **An expression prints its value and its type**, the type as the checker prints it (§11.5): `3 : Int`. A declaration prints its name and type, `double : (Int) -> Int`; a `let` its name and type, `xs : List(Int)`.
- **A value is printed as `Io.debug` prints it** (Appendix E.1), by its type; the shell and `Io.debug` share one printer, `ern_show`.
- **A large value is printed to a depth and a length,** the rest as `...`. The defaults are open; `:set` changes them.
- **An input that does not check is shown as `ernc` shows an error** (§11.5), the input as the source and the span underlined. Nothing is run.
- **A fault in an input is printed as `fault: ` and its text,** an interruption as `Killed`.
- **A process that faults is reported** with its spawn site and cause: `Counter.worker:23 faulted: division by zero`. Which deaths are reported, and how the shell learns of them, is "Failing processes".
- **With timing on, each result is followed by its elapsed time.**
- **Colour:** types dimmed, errors red, the history suggestion greyed. None when output is not a terminal or `NO_COLOR` is set.
- **Output from another process while a line is being typed** is printed above it, and the prompt and the partial line are drawn again below. Every write goes through `Sys.stdout`, one process (§8.2), and the shell holds the terminal, so the shell is told before the write lands, clears the input line, lets the output through, and redraws. Erlang's shell is racing writers it does not control; here there is no second path to the screen, so the prompt is the last thing on the terminal and stays correct.
- **A write that does not end in a line feed is ended before the prompt is drawn**, so the prompt starts at column 0 and the next write starts a new line. The transcript then shows a break the program did not write, which is the price of not holding output back until a line feed that may never come.

## Failing processes

A program that loses a worker to a fault says nothing: there is no automatic supervision, and a program learns of a death only by monitoring (§6.9). At the prompt that silence is wrong, since a person is watching and a fault that vanishes is the hardest kind to find. The shell reports it; a compiled program keeps its silence, and `monitor` stays the one way a program learns.

- **The shell cannot monitor what it cannot address.** There is no registry, and a process is reached only through an address someone holds (§6.3). The shell holds the address of the process it starts for each input and nothing deeper, so monitoring is not the mechanism.
- **The runtime already knows.** It remembers how every process it started ended (§6.9), and `Down` carries the spawn site with its line. Erlang needs `proc_lib` to carry that much, because it keeps no record of who spawned what; Ernest has it in the report. What is missing is a way for the shell to be told, which is a prerequisite below.
- **Faults only.** `Returned`, `Killed`, and `ProgramEnd` are not news, and a program that spawns a process for each connection would scroll the session away.
- **The processes of the program the shell is running**, not the shell's own; a fault inside the shell is a defect in the shell and is reported as one.
- **One line, through `Sys.stdout`**, printed as output from another process is printed and the line redrawn below it (Output), so its order against the program's own printing is the order every other print has.
- **The last faults are kept** and `:faults` prints them. How many is open.

## Line editing

GNU Readline's Emacs bindings.

- **Moving:** `C-a`, `C-e` to the start and end of the line; `C-b`, `C-f` a character; `M-b`, `M-f` a word; the arrow keys.
- **Deleting:** `Backspace` and `C-h` back, `C-d` forward; on an empty line `C-d` quits.
- **Killing:** `C-k` to the end of the line, `C-u` to the start, `C-w` and `M-Backspace` the word before, `M-d` the word after. A kill goes to the kill ring; `C-y` yanks the last, `M-y` cycles.
- **Transposing and case:** `C-t` two characters, `M-t` two words; `M-u`, `M-l`, `M-c` upcase, downcase, capitalize a word.
- **History:** `C-p`, `C-n`, up and down step through earlier inputs; `M-<` and `M->` go to the first and the current; `C-r` searches back incrementally, `C-s` forward, `C-g` abandons the search. The history is kept in the configuration directory (§11.2), `history`.
- **Suggestion:** the most recent earlier input that begins with the text typed is shown greyed after the cursor; the right arrow, or `C-e` at the end of the line, accepts it.
- **Interrupting:** `C-c` abandons the line being typed, and during an evaluation kills the input's process, leaving the bindings. While the shell is reading, the terminal's interrupt is a key to it and not the signal that ends a program (§8.6); the shell is left with `:quit` or `C-d`. Every other program keeps §8.6's rule, so the interrupt still stops a game that reads keys. §11.2 says it, since §11.2 owns the shell.
- **`C-l`** clears the screen.

## Completion

- **`Tab` completes a qualified name segment by segment:** `Li` to `List.`, `List.ma` to `List.map`.
- **A second `Tab` lists the candidates**; at `List.` it lists the exports of `List` with their types.
- **Candidates are matched by prefix and by abbreviation:** `L.fM` and `List.fm` complete to `List.filterMap`, matching capitals and segment starts.
- **What completes, by position:**
  - in an expression, the bindings, the modules on the load path, and their values and constructors;
  - after `:` in a type annotation, types;
  - inside a named constructor, in construction, update (`Player(..p, `), or pattern, its remaining fields;
  - at the start of an input, after `:`, a command; after a command, its argument: names for `:type` and `:doc`, modules for `:browse` and `:reload`, file paths for `:load`, the bindings for `:forget`, `depth`, `length`, and `timing` for `:set`.
- **Reserved words and operators do not complete.**
- **Completion reads the compiled interfaces**, held in memory once read.
- **`Shift-Tab` shows documentation.** On a name: its type, its first sentence, and its `Since`; a second `Shift-Tab`, the section `:doc` prints. Inside a call: the signature with its parameters as declared, `circle(centre : Point, radius : Int) -> Shape`, the parameter at the cursor marked.
- **Later, by type**, once the checker can check an unfinished input:
  - at `match e {`, `Tab` inserts one clause per constructor of `e`'s type, each body `todo("")`, and in a partial `match` the clauses the exhaustiveness check finds missing (§5.9);
  - in `send(a, ` and in a `receive` clause, the constructors of the mailbox type;
  - after `xs |> `, the functions whose first parameter fits `xs`;
  - as an argument, the bindings of the parameter's type.

## Commands

A command is `:` and a name; it is not an Ernest function. Any prefix of a name selects the command, and an ambiguous prefix selects the first in the order below: `:t` is `:type`, `:b` `:browse`, `:l` `:load`, `:r` `:reload`, `:q` `:quit`, `:d` `:doc`, `:f` `:forget`, `:fa` `:faults`.

- **`:type e`**: the type of `e`, which is not run.
- **`:browse Module`**: the exports of `Module` with their types.
- **`:load file`**: the file's declarations, as if typed at the prompt.
- **`:reload Module`**: recompiles and reloads `Module`; without a name, every loaded module whose source changed since it was loaded.
- **`:quit`**: quits.
- **`:doc Name`**: the documentation of `Name`, as `ernc --doc` renders it (§11.4), the declaration included.
- **`:help`**: the commands and their prefixes; it says that `:doc` is what GHCi calls `:info`.
- **`:forget x`**: forgets the binding `x`; without a name, all bindings.
- **`:bindings`**: the bindings, with their types.
- **`:processes`**: the live processes with their spawn sites (§6.9), read through the same reference as the faults; a name and a site, never an address.
- **`:faults`**: the faults reported since the session began, oldest first.
- **`:set depth n`**, **`:set length n`**, **`:set timing on`** and **`off`**.

A program is started by calling it; there is no command for it. A module meant for the shell exports a function that spawns its processes and returns. Modules are not imported: every module on the load path is in scope by its qualified name (§4.2).

## Starting and quitting

- **At start the shell runs the inputs in `shell.ern`** in the configuration directory, if it exists.
- **On `:quit` or `C-d` on an empty line** the history is saved and every process the session spawned ends with `ProgramEnd` (§8.6).

## Not in the shell

- **Building an address from numbers:** an address is a capability.
- **A mailbox that persists between inputs, and a command to flush it:** each input has its own process.
- **Commands for records and registered names:** Ernest has neither.
- **A second lookup command beside `:doc`, and a kinds command:** `:doc` shows the declaration, and Ernest exposes no kinds.
- **Commands for the file system and the terminal:** `Fs` does this in the language.
- **Running a terminal program from the prompt:** the shell holds the terminal, so a program that reads keys or lines is run with `ern` instead. The fault says so.
- **Custom printers:** a value has one rendering.
- **User-defined commands, system commands, job control, a step debugger, and watch expressions.**
- **Later, each on its own merits:** re-running an earlier input by number, `:trace f` to print each call and return of `f`, and, with MVP 3's peers, a shell attached to a running node. The design does not assume the shell runs on the node whose code it evaluates.
- **A split screen, later and as a mode**, `:set split on`: a scrolling transcript above, the shell's output and the program's together, and the input alone at the bottom. It reads better while a program prints, and it costs three things the scrolling terminal gives for nothing — the terminal's own scrollback, search and copy, since lines leaving a scroll region are not kept by most terminals; the terminal's height and a notice when it changes, neither of which is in §8.2; and a scroll region that shrinks and grows with every multi-line input. Splitting the other way, the program above and the shell below, is refused outright: the shell's own output is the large one, `:browse` and `:doc` being pages, and pinning it into a small pane is worse than the problem it solves.

## The environment

The front end owns the session, and the shell holds it as one opaque `Env`. The type system decides this rather than taste: bindings differ in type, and Ernest has no heterogeneous collection, so a shell that held the values itself could hold them only as `Foreign` with their types as text beside them.

An input may declare anything a module may, so `Env` holds four things:

- **Types**: `type`, `abstract type`, and `foreign type`, each with its constructors, its fields, and an abstract type's members. They persist because later bindings hold their values and the printer renders a value by its type.
- **Value bindings**, each with its generalized scheme (§4.6), `it` among them.
- **Declarations that are code**: `fn` and `foreign fn`, with their types and their targets.
- **The compiled modules behind all of it.** Each input is a module of its own and stays loaded: a function or closure made before a name was redeclared keeps the one it was compiled against, so its module may not go. Names collide never, since each input's module has its own name.

`Env` is a module interface plus the values behind it. The first half exists already, `#iface{namespace, types, values}`, which is what an `.erc` carries (§11.1); the shell's is that accumulated across inputs, with a value store and the loaded modules alongside.

Two consequences, stated rather than discovered:

- **A session never shrinks.** Code cannot be unloaded while a closure may reference it, so `:forget x` removes a name from the environment and frees nothing.
- **Shadowing is by name in the environment**, not by replacing code, which is why an old closure keeps working.

What `Env` does not hold: the shell's own settings, which are ordinary Ernest values; the history, a `List(String)`; and the modules on the load path, which are found by namespace (§4.2) and never enter the environment.

## Foreign interface

A sketch, settled at checkpoint 1. The user's values are handles of distinct foreign types, so the shell cannot pass one kind where another is expected; types reach the shell as text.

```
foreign type Env      // the session so far: see "The environment"
foreign type Checked  // a checked input
foreign type Value    // a result, with its type
foreign fn check(env : Env, input : String) -> Either(String, Checked) = "..."
foreign fn typeText(c : Checked) -> String = "..."
foreign fn run(env : Env, c : Checked) -> Either(String, #(Env, Value)) with m = "..."
foreign fn show(v : Value, depth : Int, length : Int) -> String = "..."
foreign fn exports(module : String) -> List(#(String, String)) = "..."
foreign fn doc(name : String) -> Optional(String) = "..."
```

`check` returns §11.5's diagnostic text on an error, `run` the fault's text on a fault, `exports` names with types, `doc` the section `:doc` prints.

## Prerequisites

Delivered before the shell, each report first.

- **`Keys`** delivers the arrows, `Enter`, `Escape`, and characters since MVP 2.5 step 4 (§9.3's `Key`). `Shift-Tab` and `Meta` combinations are not in `Key` and land with the shell, report first (MVP 2.6). The terminal's interrupt is not a `Key` value: it reaches the shell because §11.2 says the shell reads it as a key, which is the shell's exception and no other program's.
- **The terminal's width**, for redrawing a wrapped line and laying out candidates. Not in the report; it lands with the shell, report first (MVP 2.6).
- **Whether input is a terminal**, for line mode. Not in the report; it lands with the shell, report first (MVP 2.6).
- **A notice that another process printed**, for redrawing the line. Not in the report; it lands with the shell, report first (MVP 2.6).
- **What the runtime knows about processes**, one system reference for two questions: subscribe me to the faults, for "Failing processes", and what is alive with its spawn site, for `:processes`. The runtime holds both facts (§6.9); neither hands out an address, so §6.3 stands. One addition rather than two. Not in the report; it lands with the shell, report first (MVP 2.6).
- **Documentation in the `.erc`**, with each function's parameters as written, for `:doc` and `Shift-Tab` (MVP 2.5, step 6).
- **The report's §11.2** states the shell's normative core: types on every result, a module and a process per input, bindings that survive a fault, the commands and their prefix rule, and line mode (MVP 2.6).

## Open

- **How an input is checked against the environment.** `ern_typecheck:check/3` takes dependency interfaces; the accumulated environment is an interface with values behind it. Whether the checker takes it as one more interface or as an environment of its own is the spike's first question, before checkpoint 1.
- **How the emitted module reaches the values.** The front end holds them; the code compiled for an input must get at them, as arguments, through a table the emitted code reads, or by closing over them. It is an ABI decision and it constrains what follows, so the same spike answers it.
- **The depth and length defaults.**
- **How many faults the buffer keeps.**
- **How the line editor measures wide characters.**
- **The exact foreign interface.**

## Testing

- **A session is a golden test:** a file of inputs run in line mode, `ern --shell < session.ern`, against a file of expected output, under `test/`.
- **The line editor is a pure function** from a state and a key to a new state and what to draw; tests feed key lists and compare line, cursor, and output.
- **Completion is tested on the foreign entries' answers:** a prefix and an environment in, candidates out.

## Checkpoints

The plan's item stops at each; each is a shell a user can try.

0. **Expressions only.** The foreign interface; an input checked against the load path, compiled, run in a process, its value and type printed; faults, errors, quitting. No bindings, so no incremental checking: a calculator over the whole standard library, and the loop and the terminal harness proved end to end before the hard part begins.
1. **Bindings.** Every input checked against the accumulated environment; `it`, timing, fault reports from spawned processes, the startup file, the commands; the session golden tests.
2. **The line editor.** The bindings above, history, the suggestion, interruption, redrawing after other output, bracketed paste, the prompts, colour; the key-stream tests.
3. **Completion and documentation.** `Tab`, `Shift-Tab`, command arguments.
