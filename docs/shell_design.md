# The Ernest Shell: Design

The shell of MVP 2.6, `ern --shell` (report §11.2). The plan owns when it is built, the decisions log why it is as it is; this document owns what it is. First written 2026-09-19; it grows as the checkpoints settle what is marked open.

## Structure

The shell is an Ernest program. Its parts:

- **The reader** reads keystrokes through `Keys` and edits the line itself; §8.2 lets a program read keys or lines, never both. When input is not a terminal it reads lines with `Io.readLine`, without editing: line mode.
- **The shell owns the terminal, and the runner records the holder.** The runner starts the shell's process, so it marks that process as the terminal's holder before anything else runs; `Keys.subscribe` and `Io.readLine` from any other process end the caller with the fault `Fault("the shell holds the terminal; run the program with ern to give it the keyboard")`. §8.2 gains no notion of a shell: a holder is recorded, and the runner is the one that can record it, because it made the process. The shell itself reads through `Keys` and `Io.readLine` as any program does. In line mode the holder holds standard input, and the fault is the same. §11.2 states it. Taking it from first come instead would have forbidden a second `Keys` subscriber, which E.16 allows, and that is changing the language to solve the shell's problem.
- **A program under the shell prints to stdout as any other does**, and that is all it gets. The shell reports the terminal fault like any other, so a person who types `Snake.main()` is told why it will not run here, and how to run it.
- **The front end** is the Erlang toolchain, reached through the foreign interface below: checking, compiling, running, printing, listing exports, documentation.
- **The evaluator** runs each input in a fresh process, whose mailbox type is the input's own inferred effect, a polymorphic one instantiated to `Never` as an entry point's is (§8.1). The front end starts that process, since its mailbox type is known only once the input is checked, and delivers the outcome to the shell as a message; a fault comes back as an outcome, so nothing needs monitoring. A fault or an interruption ends that process only; the shell reports it and keeps its bindings. The shell's own process never runs user code.
- **The printer** prints results as below.
- **The commands** are below.

## Starting it

`ern [--config-dir dir] [--load-path dir ...] [--main Qualified.name] [--shell] [--source-root dir] [file.erc]`, report §11.2. The shell adds the last two: `--shell` takes no argument and makes the file optional, and `--source-root` says where `:load` finds a module's source, the working directory by default, as `ernc` defaults it.

- **`ern --shell`** starts the runtime with the standard library and the load path, and nothing else running.
- **`ern --shell file.erc`** loads the module and its dependencies and spawns its entry point beside the prompt, every loaded module in scope. The program's processes are the session's: `:processes` sees them, `:faults` reports their faults, and `:quit` ends them with `ProgramEnd` (§8.6).
- **The shell is the entry process under `--shell`** (§8.1), and the loaded module's entry point is spawned, not entered. §8.6 then says what it always said: the program ends when the entry process returns, and that process is the shell. The spawned entry returning ends nothing, its processes keep running and the prompt stays; a fault in it is one more fault reported at the prompt; and `--main Q.name` names the function to spawn rather than the one to be. The alternative was an exception in §8.6, a hole in one of the plainest rules in the report to serve a tool.
- **An input cannot reach a process the program spawned.** There is no registry (§6.3), so what the prompt has of a running program is its modules, its output, and the report of its faults. A program that means to be driven from the prompt returns an address from the function that starts it.
- **`ern` takes no file when `--shell` is given**, which today it demands; the usage line changes with the shell.

## Input

- **A line that is complete by itself is submitted by `Enter`.**
- **An incomplete line starts a multi-line input**, which ends at a blank line. A line is incomplete when the parser runs out of input where more was expected, which it answers as such rather than as a diagnostic; the shell never counts brackets itself, which would be a second parser to disagree with the first.
- **A blank line always submits**, incomplete or not: what does not parse gives the error it would give anyway, and `Enter` twice is always the way out of a multi-line input. `M-Enter` is the way further in.
- **`M-Enter` adds a line to an input the parser thinks is finished.** `type Shape = Dot` parses complete, so `Enter` would run it and the next line, led by `|`, would be an error; `M-Enter` keeps the input open instead. It is what an `else`, an alternative, or a longer body on the next line needs.
- **The reminder is on the continuation line.** The first multi-line input of a session prints `M-Enter adds a line, Enter runs.` above the `... ` prompt, once; `:help` lists it. A prompt that says it every time is noise.
- **A paste is one input.** The shell turns on the terminal's bracketed paste; a pasted text, blank lines included, is submitted by the `Enter` after it.
- **Each input is compiled as a module of its own** against the environment so far, and loaded. Its namespace is `Input<n>`, counting from 1 in the session, which a person sees: a fault in a process spawned at the prompt reads `Input3.main:1 faulted: division by zero`, naming the input it came from (§6.9). A module on the load path called `Input3` is unreachable in a session that has got that far, which is rare enough to say rather than guard against.
- **Functions that call each other are entered in one input.**
- **The prompt is `> `**; a multi-line input continues after `... `.
- **A queued input is checked when it runs, not when it is typed**, since the input before it may bind the name it uses; the queue holds text.
- **The reader stays live while an evaluation runs.** What is typed is echoed and edited as usual, and `Enter` queues the input to run when the one before it finishes; several queue in order. Output arriving meanwhile is printed above the line and the line redrawn, as any other process's output is.

## Bindings

- **A declaration or a `let` at the prompt binds for the inputs after it.**
- **An input is a block: the prompt is `main`.** A `let` binds as a block `let` does, monomorphic and allowed to be effectful, which is what `let a = Chat.start()` and `let a = spawn(Local, f)` need. A top-level `let` would be neither: §4.6 generalizes it and requires a pure initializer, and generalizing `spawn` is the value restriction, `Address(n)` for every `n` and a later input free to send it anything. No new rule is needed for this, only the one Ernest has: at the prompt you are writing `main`.
- **A `fn` declaration generalizes** as a `fn` does anywhere (§3.9), local ones included. So `fn id(x) = x` is polymorphic and `let id = fn(x) = x` is not; when a `let`-bound function is used at a second type, the error says to declare it with `fn`. Type declarations are a module's and sit beside both.
- **A later declaration of a name is seen by later inputs.** A function or closure made before it keeps the one it was compiled against.
- **The session is a scope, and §11.2 says so, not §4.2.** An unqualified name is looked up in the input's own declarations, then the type-member namespace of the enclosing declaration, then the session's declarations, then the prelude; a prompt declaration may shadow a prelude name exactly as a module's may. Without the sentence the report would have a prompt name in no scope at all and require it written qualified. It lives in §11.2 because that is where the shell is normative; §4.2 does not learn about tools.
- **A type declared in the session prints unqualified.** §11.5 prints another module's type qualified, and `Input3.Shape` is an implementation detail in every later line of output; the session is the reader's own scope.
- **The value of the last expression is bound to `it`.** It is the one binding a person did not write, and it does not breach principle 3: the principle asks that a top-level binding be visible where its name appears at the use site, and `it` is written at its use site. What is implicit is its making, not its use. `:bindings` lists it and `:help` says it.
- **Bindings survive a fault and an interruption.** Only `:forget` removes them.
- **A member of an abstract type is declared with the type.** Two inputs are two modules, and §4's ownership rule keeps a type's members in the module that owns it, so a later input cannot add one; the type and its members are declared in one input or loaded from a file.
- **An input whose value is reply-carrying does not check** (§6.6): a reply-carrying value neither bound nor consumed is a type error, and the prompt drops an input's value once it is printed, so the checker refuses it and `it` is never such a value. No rule of the shell's own is needed.
- **`self()` names the input's own process**, which ends with the input. An address bound to it reaches no one on a later input; a message is received inside the input that expects it.

## Output

- **An expression prints its value and its type**, the type as the checker prints it (§11.5): `3 : Int`. An expression of type `Unit` prints nothing, since `Io.println("hi")` would otherwise answer `hi` and then `Unit : Unit` after every effectful input. A declaration prints its name and type, `double : (Int) -> Int`; a `let` its name and type, `xs : List(Int)`.
- **A value is printed as `Io.debug` prints it** (Appendix E.1), by its type; the shell and `Io.debug` share one printer, `ern_show`, which grows a depth and a length that `Io.debug` passes unbounded. E.1 is unchanged: a program's `debug` prints the value.
- **A large value is printed to a depth and a length,** the rest as `...`. The defaults are open; `:set` changes them.
- **An input that does not check is shown as `ernc` shows an error** (§11.5), the input as the source and the span underlined. Nothing is run.
- **A fault in an input is printed as `fault: ` and its text,** an interruption as `Killed`.
- **A process that faults is reported** with its spawn site and cause: `Counter.worker:23 faulted: division by zero`. Which deaths are reported, and how the shell learns of them, is "Failing processes".
- **With timing on, each result is followed by its elapsed time.**
- **Output from another process while a line is being typed** is printed above it, and the prompt and the partial line are drawn again below. Under `--shell` the runner binds `Sys.stdout` and `Sys.stderr` to the shell's own writer, the same act by which it records the terminal's holder, so the shell is the only writer by construction and not by assertion, `stderr` included. A program's print is then an ordinary send, its order the writer's mailbox order, with no handshake and no round trip; nothing is told before a write, since the write is the telling. §8.2 is untouched: the runtime starts the system processes and binds their addresses, and a `String` sent to `Sys.stdout` still reaches standard output. Erlang's shell races writers it does not control; here there are none.
- **A write that does not end in a line feed is ended before the prompt is drawn**, so the prompt starts at column 0 and the next write starts a new line. The transcript then shows a break the program did not write, which is the price of not holding output back until a line feed that may never come.

## Failing processes

A program that loses a worker to a fault says nothing: there is no automatic supervision, and a program learns of a death only by monitoring (§6.9). At the prompt that silence is wrong, since a person is watching and a fault that vanishes is the hardest kind to find. The shell reports it; a compiled program keeps its silence, and `monitor` stays the one way a program learns.

- **The shell cannot monitor what it cannot address.** There is no registry, and a process is reached only through an address someone holds (§6.3). The shell holds the address of the process it starts for each input and nothing deeper, so monitoring is not the mechanism.
- **The runtime already knows.** It remembers how every process it started ended (§6.9), and `Down` carries the spawn site with its line. Erlang needs `proc_lib` to carry that much, because it keeps no record of who spawned what; Ernest has it in the report. What is missing is a way for the shell to be told, which is a prerequisite below.
- **Faults only.** `Returned`, `Killed`, and `ProgramEnd` are not news, and a program that spawns a process for each connection would scroll the session away.
- **The processes of the program the shell is running**, not the shell's own; a fault inside the shell is a defect in the shell and is reported as one. The shell cannot tell them apart, since addresses have no equality (§6.3) and it could not compare a notice against what it holds. The front end can, having started both: it subscribes to the runtime's door and forwards what the shell should show, leaving out the processes the runner started for the shell and the input's own process, whose fault is already `run`'s outcome. So an input's fault is reported once, as the answer to that input, and the notice is for everything else.
- **One line, written by the shell itself**, as any output is under `--shell` (Output), so its order against the program's own printing is the order every other print has.
- **The last faults are kept** and `:faults` prints them. How many is open.
- **`Deadlock` does not fire under `--shell`** (§8.6). The shell always holds a subscription to the keys, or a read outstanding on standard input in line mode, and a system process holding one is a source that can still deliver, so detection is off for the node for the whole session. A program whose processes all block gets no report, and `:processes` lists them as live with no hint. It is said here because unsaid it costs someone an afternoon.
- **Reporting the program's own quiescence is later.** The door built for the faults and the live list can grow a third question, whether every process but the shell's own is waiting with nothing that could deliver, and answer it at the prompt. It is not built now because a person at a prompt finds a hung program by its not answering, where a fault gives no sign at all.

## Line editing

GNU Readline's Emacs bindings.

- **`Escape` and `Meta`:** §8.2 delivers `Escape` alone once no sequence can follow it, so an `Escape` followed at once by a character is `Meta` and an `Escape` that stands alone is the key. The pause rule was built for exactly this.
- **Moving:** `C-a`, `C-e` to the start and end of the line; `C-b`, `C-f` a character; `M-b`, `M-f` a word; the arrow keys.
- **Deleting:** `Backspace` and `C-h` back, `C-d` forward; on an empty line `C-d` quits.
- **Killing:** `C-k` to the end of the line, `C-u` to the start, `C-w` and `M-Backspace` the word before, `M-d` the word after; `C-y` yanks the last kill.
- **Colour and the suggestion, later.** Types dimmed, errors red, and the most recent earlier input shown greyed after the cursor for the right arrow to accept. They go together: grey is how a suggestion is told from what was typed. Colour also asks something of the front end, since a §11.5 diagnostic crosses as rendered text and only its renderer can colour the spans it laid out; the shell would say whether colour is wanted and `ernc` could take the same path. None of it is why a person tries a language.
- **Later, each a day's work once the editor stands:** the kill ring with `M-y` cycling, `C-t` and `M-t` transposing characters and words, and `M-u`, `M-l`, `M-c` for case. They are left out of the checkpoint because each needs its own key-stream tests and none of them is why a person tries a language; a reader who has them everywhere else will miss them, which is the argument for the day.
- **History:** `C-p`, `C-n`, up and down step through earlier inputs, a multi-line one coming back whole, its lines under their continuation prompts and the cursor at the end; `M-<` and `M->` go to the first and the current; `C-r` searches back incrementally, `C-s` forward, `C-g` abandons the search. The history is kept per user, in `$HOME/.ernest/history`, as a person expects when they type the same thing in two projects; with `HOME` unset nothing is saved and the shell says so once. It is not in the configuration directory, which §11.3 gives a job of its own, the node's address and its keys.
- **Adding a line:** `M-Enter`, when the input parses complete and is not.
- **Interrupting:** `C-c` kills the running evaluation when there is one, and abandons the input being typed only when there is not, every line of it, its text kept in the history to recall and mend; the bindings and the partial line both survive the kill, since the line was being typed and losing it would be its own surprise. A queued input is dropped with the evaluation it waited for, its text kept in the history. While the shell is reading, the terminal's interrupt is a key to it and not the signal that ends a program (§8.6); the shell is left with `:quit` or `C-d`. Every other program keeps §8.6's rule, so the interrupt still stops a game that reads keys. §11.2 says it, since §11.2 owns the shell.
- **`C-l`** clears the screen.

## Completion

- **`Tab` completes a qualified name segment by segment:** `Li` to `List.`, `List.ma` to `List.map`.
- **A second `Tab` lists the candidates**; at `List.` it lists the exports of `List` with their types.
- **Candidates are matched by prefix and by abbreviation:** `L.fM` and `List.fm` complete to `List.filterMap`, matching capitals and segment starts.
- **What completes, by position:**
  - in an expression, the bindings, the modules on the load path, and their values and constructors;
  - after `:` in a type annotation, types;
  - inside a named constructor, in construction, update (`Player(..p, `), or pattern, its remaining fields;
  - at the start of an input, after `:`, a command; after a command, its argument: names for `:type` and `:doc`, modules for `:browse` and `:load`, the bindings for `:forget`, `depth`, `length`, and `timing` for `:set`.
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
- **`:load Module`**: the module by its namespace, never a path, as the host's shell takes a module name. Its source is found under the shell's source root, the working directory unless `--source-root` says otherwise, which is `ernc`'s own rule; it is compiled as `ernc` would compile it and loaded, and a module with no source there, the standard library's or a library's, is loaded from its compiled form. A source under the source root wins over an `.erc` on the load path, which is the point of compiling at all. The compiled form goes to a directory of the shell's own and never beside the source, where it would land in the project's build and meet §11.1's cleanup sweep. Afterwards it is in scope by its qualified name, like anything else on the load path.
- **`:reload`**: every loaded module whose source is newer than what was loaded, as `:load` would take each. It takes no name, since `:load Module` is that already and two names for one job is one too many. A call from another module reaches the new code. A process running the module's own loop does not: it keeps the version it is in until it returns, which is the case §6.10 exists for, where a process switches by receiving the new loop and tail-calling it. A closure made from the previous code keeps that code while the version lives. The first reload says how many processes and bindings are in the previous version and that another reload will end them; the second ends them, and the shell says which, by spawn site, with the cause "its code was replaced". Refusing to reload while a process is in the old version would fit §6.10 best and is unusable: there is no registry, so that process has no address at the prompt and the session would be stuck until `:quit`.
- **`:quit`**: quits.
- **`:doc Name`**: the documentation of `Name`, as `ernc --doc` renders it (§11.4), the declaration included.
- **`:help`**: the commands and their prefixes; it says that `:doc` is what GHCi calls `:info`.
- **`:forget name`**: forgets any name the session declared, a value, a `fn`, or a type; a name is required, and `:forget *` clears the session, `it` included. Forgetting a type needs no rule of its own, since a value carries the type it was made with and still prints. A wildcard typed on purpose is the confirmation: a prompt would have to fight the live reader and the queue, and the prefix rule hands `:f` to this command.
- **`:bindings`**: the bindings, with their types.
- **`:processes`**: the live processes with their spawn sites (§6.9), read through the same reference as the faults; a name and a site, never an address.
- **`:faults`**: the faults reported since the session began, oldest first.
- **`:set depth n`**, **`:set length n`**, **`:set timing on`** and **`off`**; `:set` alone shows what they are.

A program is started by calling it; there is no command for it. A module meant for the shell exports a function that spawns its processes and returns. Modules are not imported: every module on the load path is in scope by its qualified name (§4.2).

## Starting and quitting

- **At start the shell prints one line**, the version and how to leave, `:quit` or `C-d`, with `:help` for the rest. Not knowing the way out is the oldest complaint about an interactive tool.
- **At start the shell runs the inputs in `$HOME/.ernest/startup`**, if it exists: per user, as the history is. It is a file of inputs, commands included, and not a module, so it has no `.ern` extension: a `.ern` file under a source root is compiled with the project, and one in the configuration directory breaks the project's build outright, since `ernc` reads dotted directories and then rejects the path. A startup input that fails is reported as any input is and the session goes on.
- **On `:quit` or `C-d` on an empty line** the history is saved and every process the session spawned ends with `ProgramEnd` (§8.6).

## Not in the shell

- **Building an address from numbers:** an address is a capability.
- **A mailbox that persists between inputs, and a command to flush it:** each input has its own process.
- **Commands for records and registered names:** Ernest has neither.
- **A second lookup command beside `:doc`, and a kinds command:** `:doc` shows the declaration, and Ernest exposes no kinds.
- **Commands for the file system and the terminal:** `Fs` does this in the language.
- **Declarations read from a file into the session:** `:load` takes a module and makes it reachable by its qualified name, as every module is (§4.2). Ernest has no imports, so names arriving unqualified from a file would have been the one place they did; a module's private declarations are not reachable from the prompt, as they are not from anywhere else.
- **A pager:** the terminal's own scrollback, search and copy are the pager, and keeping them is half the reason the transcript scrolls rather than splitting. One would also fight the live reader for the keyboard.
- **Running a terminal program from the prompt:** the shell holds the terminal, so a program that reads keys or lines is run with `ern` instead. The fault says so.
- **Custom printers:** a value has one rendering.
- **User-defined commands, system commands, job control, a step debugger, and watch expressions.**
- **Later, each on its own merits:** re-running an earlier input by number, `:trace f` to print each call and return of `f`, and, with MVP 3's peers, a shell attached to a running node. The design does not assume the shell runs on the node whose code it evaluates.
- **A split screen, later and as a mode**, `:set split on`: a scrolling transcript above, the shell's output and the program's together, and the input alone at the bottom. It reads better while a program prints, and it costs three things the scrolling terminal gives for nothing — the terminal's own scrollback, search and copy, since lines leaving a scroll region are not kept by most terminals; the terminal's height and a notice when it changes, neither of which is in §8.2; and a scroll region that shrinks and grows with every multi-line input. Splitting the other way, the program above and the shell below, is refused outright: the shell's own output is the large one, `:browse` and `:doc` being pages, and pinning it into a small pane is worse than the problem it solves.

## The environment

The front end owns the session, and the shell holds it as one opaque `Env`. The type system decides this rather than taste: bindings differ in type, and Ernest has no heterogeneous collection, so a shell that held the values itself could hold them only as `Foreign` with their types as text beside them.

An input may declare anything a module may, so `Env` holds four things:

- **Types**: `type`, `abstract type`, and `foreign type`, each with its constructors, its fields, and an abstract type's members. They persist because later bindings hold their values and the printer renders a value by its type.
- **Value bindings**, each with its type, `it` among them; a `let` at the prompt is a block `let`, so the type is monomorphic, and what generalizes is a `fn` declaration. A value carries the type it was made with, so one made before a type's shape changed still prints by its own descriptor rather than by the new one.
- **Declarations that are code**: `fn` and `foreign fn`, with their types and their targets.
- **The compiled modules behind all of it.** Each input is a module of its own and stays loaded: a function or closure made before a name was redeclared keeps the one it was compiled against, so its module may not go. Names collide never, since each input's module has its own name.

`Env` is a module interface plus the values behind it. The first half exists already, `#iface{namespace, types, values}`, which is what an `.erc` carries (§11.1); the shell's is that accumulated across inputs, with a value store and the loaded modules alongside.

Two consequences, stated rather than discovered:

- **A session never shrinks.** Code cannot be unloaded while a closure may reference it, so `:forget` removes a name from the environment and frees nothing. The module and atom tables grow with it, each input being a module of its own name and each constructor an atom, neither of which the host reclaims. It is a property and not a defect: a session of thousands of inputs grows both, and one that runs for days is restarted. Inputs never displace each other, each being a module of its own name; only `:reload` of a module on the load path replaces code, and it is the host's rule that governs there.
- **Shadowing is by name in the environment**, not by replacing code, which is why an old closure keeps working.

What `Env` does not hold: the shell's own settings, which are ordinary Ernest values; the history, a `List(String)`; and the modules on the load path, which are found by namespace (§4.2) and never enter the environment.

## Foreign interface

A sketch, settled at checkpoint 1. The user's values are handles of distinct foreign types, so the shell cannot pass one kind where another is expected; types reach the shell as text.

```
foreign type Env      // the session so far: see "The environment"
foreign type Checked  // a checked input
foreign type Value    // a result, with its type
type Outcome = Ok(env : Env, value : Value) | Failed(String)

foreign fn check(env : Env, input : String) -> Either(String, Checked) = "..."
foreign fn typeText(c : Checked) -> String = "..."
foreign fn declared(c : Checked) -> List(#(String, String)) = "..."
foreign fn run(env : Env, c : Checked, wrap : (Outcome) -> m) -> Address(Never) with m = "..."
foreign fn show(v : Value, depth : Int, length : Int) -> String = "..."
foreign fn exports(module : String) -> List(#(String, String)) = "..."
foreign fn doc(name : String) -> Optional(String) = "..."
foreign fn faults(wrap : (Fault) -> m) -> Unit with m = "..."
```

`check` returns §11.5's diagnostic text on an error. `run` starts the input's process and answers with its address, which is what `C-c` kills, and delivers `Ok` or `Failed` to the shell when it ends, which is E.0 rule 8's shape for anything that arrives later; a synchronous `run` would have blocked the shell, leaving the reader dead and the interrupt unseen. `typeText` is the type of an expression, for `:type`, which does not run it; `declared` is the names and types an input declares, which the shell prints after a declaration and cannot read from `Env`, that being opaque. `exports` gives names with types, `doc` the section `:doc` prints.

## Prerequisites

Delivered before the shell, each report first.

- **`Keys`** delivers the arrows, `Enter`, `Escape`, and characters since MVP 2.5 step 4 (§9.3's `Key`). `Shift-Tab` and `Meta` need nothing added: §8.2 already delivers a sequence that is not a key of §9.3 as `Escape` and the characters after it, so `M-b` arrives as `Escape` then `Char('b')` and `Shift-Tab` as `Escape` and its bytes, which the editor decodes as any line editor does. Growing `Key` for the shell would be the move refused for the terminal, and two ways to read one key.
- **`Key` gains one value for the terminal's interrupt** (§9.3, MVP 2.6), delivered only to the holder of the terminal, which §11.2 makes the shell. A subscriber receives `Key` values and nothing else (E.16), so without it the byte cannot arrive at all; one constructor, not a family.
- **`ern_show` takes a depth and a length**, which `Io.debug` passes unbounded, so the shell and E.1 keep one printer. A runtime change, not a report one (MVP 2.6).
- **The parser answers that an input is incomplete**, distinctly from a diagnostic: it ran out of input where more was expected. It knows already and does not say. A front-end change, not a report one (MVP 2.6).
- **The terminal's width**, for redrawing a wrapped line and laying out candidates, asked for at each redraw rather than delivered as a notice when it changes: a resize then takes effect on the next keystroke, and §8.2 gains one door instead of two. Not in the report; it lands with the shell, report first (MVP 2.6).
- **Whether input is a terminal**, for line mode. Not in the report; it lands with the shell, report first (MVP 2.6).
- **§7.3 gains the cause** a process ends with when its code is replaced under it, which its list of causes does not have; `:reload` reports it (MVP 2.6).
- **What the runtime knows about processes**, one system reference for two questions: subscribe me to the faults, for "Failing processes", and what is alive with its spawn site, for `:processes`. The runtime holds both facts (§6.9); neither hands out an address, so §6.3 stands. One addition rather than two. Not in the report; it lands with the shell, report first (MVP 2.6).
- **Documentation in the `.erc`**, with each function's parameters as written, for `:doc` and `Shift-Tab` (MVP 2.5, step 6).
- **The terminal is the shell's when `--shell` is given**, §11.2, and §8.2 gains the case: `Keys.subscribe` and `Io.readLine` from anything else fault with the remedy in the text (MVP 2.6).
- **The shell reads the terminal's interrupt as a key while it reads**, §11.2, which every other program does not: §8.6's signal stands for them (MVP 2.6).
- **The report's §11.2** states the shell's normative core: the flag without an argument and the file optional with it, the shell as the entry process (§8.1) with the file's entry point spawned beside it and what `--main` then names, the session as a scope in §4.2's lookup order with a session type printed unqualified (§11.5), the terminal's holder, the interrupt read as a key, and `Deadlock` not firing while a shell holds a source; types on every result, a module and a process per input, bindings that survive a fault, the commands and their prefix rule, and line mode (MVP 2.6).

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
2. **The line editor.** Moving, deleting, killing with a single yank, history and its search, interruption, redrawing after other output, bracketed paste, the prompts; the key-stream tests. What "Line editing" marks later is later, colour and the suggestion among it. What "Line editing" marks later is later.
3. **Completion and documentation.** `Tab`, `Shift-Tab`, command arguments.
