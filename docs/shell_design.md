# The Ernest Shell: Design Notes

The shell of MVP 2.6, `ern --shell`: an Ernest program over `Keys`, with its own line editor, and with the checker's incremental entry reached through a `foreign fn` (report §8.4, §11.2). The plan owns when it is built; this document owns what it is. It is a first draft, begun 2026-09-19, and much more will be added: multi-line input, how a declaration typed at the prompt is compiled and loaded, what the shell's mailbox type is, and the exact interface of the foreign entries.

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
- **Completion by type is a later step.** After `xs |> `, only functions whose first parameter fits the type of `xs` would be offered; the checker can compute it.
- **`Shift-Tab` shows the documentation of the name at the cursor,** as Jupyter does: the type, the first sentence, and `Since`. A second `Shift-Tab` shows the whole section `:doc` prints.
- **Completion reads the compiled interfaces** that every `.erc` carries, so it knows exactly what the checker knows.
- **Documentation must be in the `.erc`.** `Shift-Tab` and `:doc` work on compiled modules, whose source may not be at hand, so `ernc` writes the doc blocks into a chunk of the `.erc`, after Erlang's `Docs` chunk (EEP 48). This is a toolchain step the shell depends on, and a companion to the standard library of MVP 2.5.
- **The `Key` type must express `Shift-Tab`.** A terminal sends it as its own escape sequence; `Keys` in MVP 2.5 must deliver it.

## The commands

A command is written with a `:` prefix, as in GHCi, and is not a function. It cannot collide with a program's names, and it cannot be mistaken for Ernest code (principles 1 and 3).

- **`:type e`**: the type of an expression, without evaluating it, printed as the checker prints types (§11.5). In a typed language this is the command used most.
- **`:doc Name`**: a declaration's documentation, rendered as `ernc --doc` renders it (§11.4): the declaration, with a type's constructors and a function's type, and its text. The documentation norm, Appendix E.0 rule 6, makes it worth more than Erlang's `h`.
- **`:browse Module`**: every export of a module with its type, the compact overview beside `:doc`'s text.
- **`:bindings`** and **`:forget x`**: the bindings made at the prompt, and forgetting one or all of them.
- **`:flush`**: prints and empties the shell's mailbox. Without it a message sent to `self()` at the prompt is invisible.
- **`:processes`**: the live processes with their spawn sites, which the runtime's process table already records (§6.9).
- **`:load file`**: brings a source file's declarations into the session, as if typed at the prompt.
- **`:reload Module`**: recompiles and reloads a module during development. It is a toolchain convenience and does not compete with §6.10's `Upgrade`.
- **`:set depth n`** and **`:set length n`**: the printing limits above.
- **`:help`** and **`:quit`**.

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
- **`:info`**, GHCi's. `:doc` already shows the declaration; a second command for one lookup would be two ways (principle 2).
- **`cd`, `pwd`, `ls`.** The `Fs` module does this in the language; a command would be a second way (principle 2).
- **`v(N)`, `e(N)`, `bt`, `memory`, `uptime`, and job control.** Power tooling a first shell does not need; each may come later on its own merits.
- **Custom printers**, OCaml's `#install_printer`. A value has one rendering, `Io.debug`'s.
- **`:!` system commands and `:def` user commands**, GHCi's. The terminal and `Fs` already exist, and a shell with user-defined commands is a second language.
- **A step debugger.** A project of its own. OCaml shows that call tracing is most of what a shell debugger is used for; `:trace f`, printing each call and return of a function, is a later item for that reason.
- **Watch expressions**, Unison's. They belong to an editor integration, not to the shell.

## A line that faults

A line that faults reports the fault and leaves the shell running with its bindings intact. Erlang restarts its evaluator for the same reason: the death of the shell's own process is the one failure a user cannot recover from at the prompt.
