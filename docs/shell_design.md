# The Ernest Shell: Design Notes

The shell of MVP 2.6, `ern --shell`: an Ernest program over `Keys`, with its own line editor, and with the checker's incremental entry reached through a `foreign fn` (report §8.4, §11.2). The plan owns when it is built; this document owns what it is. It is a first draft, begun 2026-09-19, and much more will be added. Three decisions are open, listed under "Open decisions" at the end; the foreign interface is sketched and is settled when it is built.

## Every result has a type

Every expression evaluated at the prompt prints its value and its type, the type as the checker prints it (§11.5):

```
> 1 + 2
3 : Int
> List.map([1, 2], fn(x) = x * 2)
[2, 4] : List(Int)
> fn double(n : Int) = n * 2
double : (Int) -> Int
> let xs = [1, 2]
xs : List(Int)
```

A declaration prints its name and its type; a `let` its name and type; an expression its value and type. The last expression's value is bound to `it`, as in every ML-family shell, so `it` at the next prompt is that value at that type.

A value is printed by its type, which the shell knows from the checker, and as the source writes it: a named constructor with its field names, `Snap(dir = "x", seen = 2) : Snap`; a `Char` as `'a'`; a `Map` and a `Set` as `Map.fromList` and `Set.fromList`; a value of an abstract type as `<abstract>`, so its representation stays private, as OCaml prints `<abstr>`; an address, a reply, a function, or a foreign value as `<address>`, `<reply>`, `<function>`, `<foreign>`. `Io.debug` prints by the runtime's representation instead, since at run time it cannot know the type (Appendix E.1).

A large value is printed up to a depth and a length, the rest shown as `...`. `:set depth n` and `:set length n` change the limits, and `Io.debug` prints a value in full.

## Bindings at the prompt

- **A `let` at the prompt generalizes as a top-level `let` does** (§4.6): `let id = fn(x) = x` stays polymorphic, so `id(1)` and `id("a")` both check on later lines.
- **A later declaration of a name is seen by later lines.** A closure or a function made before it keeps the one it was made with, as a block's shadowing does (§4.6).
- **Bindings survive a faulting or interrupted line**; only `:forget` removes them.

## The parts

The shell is an Ernest program, and one of the larger ones: an estimate is one to two thousand lines. It has five parts.

- **The reader.** It reads keystrokes through `Keys`, not lines through `Io.readLine`: line editing needs every key, and §8.2 lets a program use keys or lines, never both. The line editor below is Ernest over the key stream, with the line, the cursor, the kill ring, and the history carried through its loop. When the input is not a terminal, `ern --shell < script.ern`, there are no keys: the shell reads lines with `Io.readLine`, without editing, and prints each result as at the prompt.
- **The front end.** Lexing, parsing, type-checking, and compiling stay in the Erlang toolchain and are reached through a few `foreign fn`s: check a line against the bindings so far, compile a declaration, load a module, list a module's exports, fetch a declaration's documentation. The boundary is narrow by design, and it is the part to get right first.
- **The evaluator.** It runs each line in a process of its own. The shell monitors it (§6.9); a line that faults kills the evaluator, the shell reports the fault, and starts a new evaluator with the bindings kept.
- **The commands.** The `:` commands below, small once the front end exists, since they reuse the checker's printer and the documentation renderer.
- **The printer.** A result and its type, as above.

## What Ernest must provide

The shell is written in Ernest, and working through its parts shows what Ernest already offers and what it lacks.

- **Already there, or in MVP 2.5.** The line editor is data carried through a loop: the line as a `List(Char)`, the cursor, the kill ring, the history. Drawing is ANSI escape sequences written with `Io.print`, a string holding `\u{1B}[K`. Keys come through `Keys`, and `C-c` arrives as a key in raw mode, not as a signal, so interrupting is ordinary message handling. The history file uses `Fs`, and completing a path uses `Fs.list`. The evaluator is a process: `monitor` reports its death and `kill` stops it.
- **Results are `Foreign` to the shell.** The shell is a statically typed program handling values of every type a user can write, so a result, a binding, and a message in its mailbox are opaque handles to it, of type `Foreign`, passed back to the toolchain. The foreign entries do the typed work: check a line against the bindings, compile and run it, print a value by its type, list a module's exports, fetch documentation. The shell is the interface and the orchestration; evaluation and printing stay behind the boundary, as GHC stands behind GHCi. The foreign interface is therefore the real design, and larger than a few entries.
- **The terminal's width.** Redrawing a line that wraps and laying out a completion list need it. Nothing in the report provides it; Erlang has `io:columns`. An addition to `Io` or `Keys`, report first.
- **Whether input is a terminal.** The fall-back to reading lines, `ern --shell < script.ern`, needs to know. Nothing provides it. An addition to `Io`, report first.
- **Knowing that another process printed.** Redrawing the prompt after output from a spawned process needs the editor to learn that output happened: `Sys.stdout` notifies a subscriber, or the shell stands in front of it. A runtime hook to be designed, report first.

The three additions are questions for MVP 2.5, which builds `Keys` and `Io.readLine`, and are best answered when those are built.

## The foreign interface, a sketch

The shell's own code is typed Ernest; the user's values are handles to it (see above), and the checker's types reach it as text. A first sketch, to be settled at the first checkpoint:

```
foreign type Env      // the bindings so far, with their types
foreign type Checked  // a checked line
foreign type Value    // a result
foreign fn check(env : Env, line : String) -> Either(String, Checked) = "..."
foreign fn typeText(c : Checked) -> String = "..."
foreign fn run(env : Env, c : Checked) -> Either(String, #(Env, Value)) with m = "..."
foreign fn show(v : Value, depth : Int, length : Int) -> String = "..."
foreign fn exports(module : String) -> List(#(String, String)) = "..."
foreign fn doc(name : String) -> Optional(String) = "..."
```

The handle types are distinct foreign types, so the checker keeps the shell from passing an environment where a value is expected. `check` returns the diagnostic text of §11.5 on an error; `run` returns the fault's text on a fault; `exports` gives names with their types for `:browse` and completion; `doc` gives the section `:doc` prints.

## Line editing and history

The keys are GNU Readline's Emacs bindings, which every shell user's fingers already know.

- **Moving.** `C-a` and `C-e` to the start and end of the line, `C-b` and `C-f` a character back and forward, `M-b` and `M-f` a word back and forward, and the arrow keys.
- **Deleting and killing.** `Backspace` and `C-h` delete back, `C-d` deletes forward and quits on an empty line, `C-k` kills to the end of the line, `C-u` to the start, `C-w` and `M-Backspace` the word before, `M-d` the word after. A kill goes to the kill ring; `C-y` yanks the last kill and `M-y` cycles the ring.
- **Transposing and case.** `C-t` transposes two characters, `M-t` two words; `M-u`, `M-l`, and `M-c` upcase, downcase, and capitalize a word.
- **History.** `C-p` and `C-n`, and the up and down arrows, step through earlier lines; `M-<` and `M->` go to the first and the current. `C-r` searches back incrementally and `C-s` forward, `C-g` abandons the search. The history is kept between sessions in the configuration directory, `.ernest/history`.
- **Interrupting.** `C-c` abandons the line being typed. During an evaluation it kills the evaluator, which is reported as `Killed`, and the bindings are kept; a line that loops or waits in `receive` is stopped this way.
- **Output from other processes.** A process spawned at the prompt may print while a line is being typed. The editor then redraws the prompt and the partial line below the output, as Readline does.
- **The rest.** `C-l` clears the screen. `Enter` submits the line, or continues it when it is not yet complete.

## Completion and documentation at the cursor

- **`Tab` completes a qualified name segment by segment.** `Li` gives `List.`, and `List.ma` gives `List.map`. A second `Tab` where several names fit lists them; at `List.` it lists every export of `List` with its type.
- **Every kind of name completes:** bindings, the modules on the load path, types, constructors, the `:` commands, and the field names of a named constructor, so `Point(` offers `x =` and `y =`.
- **A command's argument completes by what the command takes.** `:doc` and `:type` complete names as at the prompt, `:browse` and `:reload` module names, `:load` file paths, `:forget` the bindings made at the prompt, and `:set` its settings, `depth` and `length`.
- **Completion by type is a later step.** After `xs |> `, only functions whose first parameter fits the type of `xs` would be offered; the checker can compute it.
- **`Shift-Tab` shows the documentation of the name at the cursor,** as Jupyter does: the type, the first sentence, and `Since`. A second `Shift-Tab` shows the whole section `:doc` prints.
- **Completion reads the compiled interfaces** that every `.erc` carries, so it knows exactly what the checker knows.
- **Documentation must be in the `.erc`.** `Shift-Tab` and `:doc` work on compiled modules, whose source may not be at hand, so `ernc` writes the doc blocks into a chunk of the `.erc`, after Erlang's `Docs` chunk (EEP 48). This is a toolchain step the shell depends on, and a companion to the standard library of MVP 2.5.
- **The `Key` type must express `Shift-Tab`.** A terminal sends it as its own escape sequence; `Keys` in MVP 2.5 must deliver it.

## The commands

A command is written with a `:` prefix, as in GHCi, and is not a function. It cannot collide with a program's names, and it cannot be mistaken for Ernest code (principles 1 and 3).

Any prefix of a command's name selects it, as in GHCi, and an ambiguous prefix selects the first command in the order of the list below. The order puts GHCi's habitual letters where GHCi puts them: `:t` is `:type`, `:b` is `:browse`, `:l` is `:load`, `:r` is `:reload`, `:q` is `:quit`, `:d` is `:doc`, `:f` is `:flush`.

- **`:type e`**: the type of an expression, without evaluating it, printed as the checker prints types (§11.5). In a typed language this is the command used most.
- **`:browse Module`**: every export of a module with its type, the compact overview beside `:doc`'s text.
- **`:load file`**: brings a source file's declarations into the session, as if typed at the prompt.
- **`:reload Module`**: recompiles and reloads a module during development; without a name, every loaded module whose source changed since it was loaded, as GHCi's `:r` and Erlang's `lm()` do. It is a toolchain convenience and does not compete with §6.10's `Upgrade`.
- **`:quit`**, as `C-d` on an empty line.
- **`:doc Name`**: a declaration's documentation, rendered as `ernc --doc` renders it (§11.4): the declaration, with a type's constructors and a function's type, and its text. The documentation norm, Appendix E.0 rule 6, makes it worth more than Erlang's `h`. A GHCi user's `:i` finds nothing; the help text says `:doc` is the command.
- **`:help`**, which lists the commands and their prefixes.
- **`:flush`**: prints and empties the shell's mailbox. Without it a message sent to `self()` at the prompt is invisible.
- **`:forget x`**: forgets one binding made at the prompt, or all of them without a name.
- **`:bindings`**: the bindings made at the prompt, with their types.
- **`:processes`**: the live processes with their spawn sites, which the runtime's process table already records (§6.9).
- **`:set depth n`** and **`:set length n`**: the printing limits above.

Two questions a Haskell user asks on the first day:

- **How is a module imported?** It is not. Every module on the load path is in scope by its qualified name (§4.2), so GHCi's `:module` has no counterpart.
- **How is a program started?** By calling it. A module meant to be used from a shell exports a function that spawns its processes and returns, as an Erlang user calls `server:start()`. `Server.main()` at the prompt runs an entry point in the evaluator, and `C-c` stops it; `spawn(Local, fn() = Server.main())` runs it beside the shell. There is no `:main` or `:run`: calling the function is the one way (principle 2).

## What other shells offer

- **Erlang.** Built-in commands, most from the `c` module. `b()` lists bindings, `f()` and `f(X)` forget them, `v(N)` is the value of line N, `e(N)` re-runs it, `h()` shows the history. `c(File)` compiles and loads, `l(Mod)` loads, `lm()` reloads every modified module, `m(Mod)` shows a module. `i()` lists processes, `pid(X, Y, Z)` builds a pid, `regs()` lists registered names, `bt(Pid)` gives a backtrace, `flush()` empties the mailbox. `h(Mod, F)` shows documentation and `ht(Mod, T)` a type. `rr`, `rd`, `rl`, `rf`, and `rp` handle records and print a term in full. `cd`, `pwd`, `ls`, `memory()`, `uptime()`, `q()`. Ctrl-G starts, switches, and kills shells; Ctrl-C opens the break menu.
- **GHCi, Haskell.** Commands with a `:` prefix, the convention taken here: `:type`, `:kind`, `:info` for a name's declaration, `:browse Module`, `:load` and `:reload`, `:module` for what is in scope, `:{` and `:}` around multi-line input, `it` for the last value, `:set +t` to print each result's type, a step debugger with `:break`, `:step`, `:trace`, and `:history`, `:sprint` to show a value without forcing it, `:def` for new commands, `:!` for a system command.
- **The OCaml toplevel and `utop`.** Directives with a `#` prefix. Every result prints with its type, `- : int = 3`, the choice taken here. `#use` loads a source file, `#load` and `#require` libraries; `#show` prints a declaration and `#typeof` a type; `#trace f` prints every call and return of a function; `#print_depth` and `#print_length` cap what a large value prints; `#install_printer` registers a printer for a type. `utop` adds completion, colours, and history.
- **SML/NJ.** `val it = 3 : int`: the value, its type, and `it` in one line; `use` loads a file; a setting caps the print depth.
- **`iex`, Elixir.** `h` for documentation, `i` to describe any value, `t` for types, `exports(Module)`, `v(n)` for earlier results, `recompile()`, and breakpoints with `IEx.pry`.
- **Jupyter.** `Shift-Tab` on a name shows its signature and the start of its documentation, and a second press expands it.
- **`ucm`, Unison.** Watch expressions: a line starting with `>` in a scratch file is evaluated and shown each time the file is saved.
- **Gleam** has no shell.

## What the Ernest shell leaves out

- **`pid(X, Y, Z)`.** An address is a capability; building one from numbers breaks the guarantee about who can send.
- **`regs()`.** Ernest has no registered names.
- **The records commands.** Ernest has no records; a `type` declaration typed at the prompt does their work.
- **`rp`.** The shell prints up to its limits, and `Io.debug` prints a value in full.
- **`:kind`**, GHCi's. Ernest exposes no kinds; `:doc` on a type shows its parameters.
- **`:info`**, GHCi's. `:doc` already shows the declaration; a second command for one lookup would be two ways (principle 2).
- **`cd`, `pwd`, `ls`.** The `Fs` module does this in the language; a command would be a second way (principle 2).
- **`v(N)`, `e(N)`, `bt`, `memory`, `uptime`, and job control.** Power tooling a first shell does not need; each may come later on its own merits.
- **Custom printers**, OCaml's `#install_printer`. A value has one rendering, `Io.debug`'s.
- **`:!` system commands and `:def` user commands**, GHCi's. The terminal and `Fs` already exist, and a shell with user-defined commands is a second language.
- **A step debugger.** A project of its own. OCaml shows that call tracing is most of what a shell debugger is used for; `:trace f`, printing each call and return of a function, is a later item for that reason.
- **Watch expressions**, Unison's. They belong to an editor integration, not to the shell.

## A line that faults

A line that faults reports the fault and leaves the shell running with its bindings intact. Erlang restarts its evaluator for the same reason: the death of the shell's own process is the one failure a user cannot recover from at the prompt.

## Testing

- **A session is a golden test.** Line mode, `ern --shell < session.ern`, reads lines and prints each result as at the prompt, so a file of input lines and a file of expected output test the whole shell: checking, compiling, running, printing, bindings, `it`, commands, and faults. Such tests go under `test/`, beside the integration tests.
- **The line editor is tested on key streams.** Its core is a pure function from a state and a key to a new state and what to draw; a test feeds a list of keys and compares the resulting line, cursor, and output. No terminal is involved.
- **Completion is tested on the foreign entries' answers**, a prefix and an environment in, the candidates out.

## Checkpoints

The shell is too large for one review at the end, so its item in the plan stops three times, each a working shell a user can try.

1. **The foreign interface and the line-mode shell.** Every line checked, run, and printed with its type; `it`, bindings, faults, and the commands that need no editor; the session golden tests.
2. **The line editor.** The Readline bindings, history kept between sessions, interruption, and the redraw after another process prints; the key-stream tests.
3. **Completion and documentation at the cursor.** `Tab` for names, commands, and arguments, `Shift-Tab`, and the documentation chunk in the `.erc` it depends on.

## Open decisions

These are the user's, and are settled here before MVP 2.6 starts.

1. **Multi-line input.** When a line is not complete, how the shell knows it and how the user ends it: a line continues while a bracket is open or the parser wants more, or an explicit form such as GHCi's `:{` and `:}`, or both.
2. **A declaration typed at the prompt.** How it is compiled and loaded: one throwaway module per line, or one growing module recompiled each time; and what a later declaration of the same name does to the functions already compiled against the old one.
3. **The shell's mailbox type.** What the shell's process, and the evaluator's, can receive: `Never`, so a line that calls `receive` is a type error; a fixed type; or the type of the entry point when `ern --shell` runs beside a program.
