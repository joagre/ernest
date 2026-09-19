# The Ernest Shell: Design Notes

The shell of MVP 2.6, `ern --shell`: an Ernest program over `Keys`, with its own line editor, and with the checker's incremental entry reached through a `foreign fn` (report §8.4, §11.2). The plan owns when it is built; this document owns what it is. It is a first draft, begun 2026-09-19, and much more will be added: multi-line input, completion in detail, how a declaration typed at the prompt is compiled and loaded, what the shell's mailbox type is, and the exact interface of the foreign entries.

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

A declaration prints its name and its type; a `let` its name and type; an expression its value and type. `:type e` prints the type alone and evaluates nothing. The last expression's value is bound to `it`, as in every ML-family shell, so `it` at the next prompt is that value at that type.

A large value is printed up to a depth and a length, the rest shown as `...`; `:set depth n` and `:set length n` change the limits, and `Io.debug` prints a value in full.

## The parts

The shell is an Ernest program, and one of the larger ones: an estimate is one to two thousand lines. It has five parts.

- **The reader.** It reads keystrokes through `Keys`, not lines through `Io.readLine`: line editing needs every key, and §8.2 lets a program use keys or lines, never both. The line editor below is Ernest over the key stream, with the line, the cursor, the kill ring, and the history carried through its loop.
- **The front end.** Lexing, parsing, type-checking, and compiling stay in the Erlang toolchain and are reached through a few `foreign fn`s: check a line against the bindings so far, compile a declaration, load a module. The boundary is narrow by design, and it is the part to get right first.
- **The evaluator.** It runs each line in a process of its own. The shell monitors it (§6.9); a line that faults kills the evaluator, the shell reports the fault, and starts a new evaluator with the bindings kept.
- **The commands.** The `:` commands below, small once the front end exists, since they reuse the checker's printer and the documentation renderer.
- **The printer.** A result and its type, as above.

## Line editing and history

The keys are GNU Readline's Emacs bindings, which every shell user's fingers already know.

- **Moving.** `C-a` and `C-e` to the start and end of the line, `C-b` and `C-f` a character back and forward, `M-b` and `M-f` a word back and forward, and the arrow keys.
- **Deleting and killing.** `Backspace` and `C-h` delete back, `C-d` deletes forward and quits on an empty line, `C-k` kills to the end of the line, `C-u` to the start, `C-w` and `M-Backspace` the word before, `M-d` the word after. A kill goes to the kill ring; `C-y` yanks the last kill and `M-y` cycles the ring.
- **Transposing and case.** `C-t` transposes two characters, `M-t` two words; `M-u`, `M-l`, and `M-c` upcase, downcase, and capitalize a word.
- **History.** `C-p` and `C-n`, and the up and down arrows, step through earlier lines; `M-<` and `M->` go to the first and the current. `C-r` searches back incrementally and `C-s` forward, `C-g` abandons the search. The history is kept between sessions in the configuration directory, `.ernest/history`.
- **The rest.** `Tab` completes a name from the bindings, the loaded modules, and the `:` commands. `C-l` clears the screen. `C-c` abandons the line being typed. `Enter` submits the line, or continues it when it is not yet complete.

## What the Erlang shell offers

A power user of the Erlang shell leans on its built-in commands, most from the `c` module, and on its history and job control.

- **Bindings and history.** `b()` lists bindings, `f()` and `f(X)` forget them, `v(N)` is the value of line N, `e(N)` re-runs line N, `h()` shows the history.
- **Code.** `c(File)` compiles and loads, `l(Mod)` loads, `lm()` reloads every modified module, `m(Mod)` shows a module's information.
- **Processes.** `i()` lists processes and `i(X, Y, Z)` shows one, `pid(X, Y, Z)` builds a pid, `regs()` lists registered names, `bt(Pid)` gives a backtrace, `flush()` prints and empties the shell's mailbox.
- **Documentation and types.** `h(Mod)` and `h(Mod, F)` show documentation, `ht(Mod, T)` a type.
- **Records.** `rr`, `rd`, `rl`, `rf`, and `rp(Term)`, which prints a term in full.
- **Environment.** `cd`, `pwd`, `ls`, `memory()`, `uptime()`, `q()` and `halt()`.
- **Job control.** Ctrl-G starts, switches, and kills shells; Ctrl-C opens the break menu.

## What the Ernest shell keeps

A command is written with a `:` prefix, as in GHCi, and is not a function. It cannot collide with a program's names, and it cannot be mistaken for Ernest code (principles 1 and 3).

- **`:type e`**: the inferred type of an expression, without running it, printed as the checker prints types (§11.5). In a typed language this is the command used most.
- **`:doc Name`**: a declaration's documentation, rendered as `ernc --doc` renders it (§11.4). The documentation norm, Appendix E.0 rule 6, makes it worth more than Erlang's `h`.
- **`:bindings`** and **`:forget x`**: the bindings made by `let` at the prompt, and forgetting one or all of them.
- **`:flush`**: prints and empties the shell's mailbox. Without it a message sent to `self()` at the prompt is invisible.
- **`:processes`**: the live processes with their spawn sites, which the runtime's process table already records (§6.9).
- **`:info Name`**: the declaration behind a name, where `:type` gives only the type. For a type it shows the constructors, for a function its type and the module it comes from.
- **`:browse Module`**: every export of a module with its type, the compact overview beside `:doc`'s text.
- **`:load file`**: brings a source file's declarations into the session, as if typed at the prompt.
- **`:reload Module`**: recompiles and reloads a module during development. It is a toolchain convenience and does not compete with §6.10's `Upgrade`.
- **`:set depth n`** and **`:set length n`**: the printing limits above.
- **`:help`** and **`:quit`**.

## What other shells offer

- **GHCi, Haskell.** Commands with a `:` prefix, the convention taken here: `:type`, `:kind`, `:info` for a name's declaration and where it came from, `:browse Module` for a module's exports, `:load` and `:reload`, `:module` for what is in scope, `:{` and `:}` around multi-line input, `it` for the last value, `:set +t` to print each result's type, a step debugger with `:break`, `:step`, `:trace`, and `:history`, `:sprint` to show a value without forcing it, `:def` for new commands, `:!` for a system command.
- **The OCaml toplevel and `utop`.** Directives with a `#` prefix. Every result prints with its type, `- : int = 3`, the choice taken here. `#use` loads a source file, `#load` and `#require` libraries; `#show` prints a declaration and `#typeof` a type; `#trace f` prints every call and return of a function; `#print_depth` and `#print_length` cap what a large value prints; `#install_printer` registers a printer for a type. `utop` adds completion, colours, and history.
- **SML/NJ.** `val it = 3 : int`: the value, its type, and `it` in one line; `use` loads a file; a setting caps the print depth.
- **`iex`, Elixir.** `h` for documentation, `i` to describe any value, `t` for types, `exports(Module)`, `v(n)` for earlier results, `recompile()`, and breakpoints with `IEx.pry`.
- **`ucm`, Unison.** Watch expressions: a line starting with `>` in a scratch file is evaluated and shown each time the file is saved.
- **Gleam** has no shell.

## What the Ernest shell leaves out

- **`pid(X, Y, Z)`.** An address is a capability; building one from numbers breaks the guarantee about who can send.
- **`regs()`.** Ernest has no registered names.
- **The records commands.** Ernest has no records; a `type` declaration typed at the prompt does their work.
- **`rp`.** The shell prints results in full, and `Io.debug` covers the rest.
- **`cd`, `pwd`, `ls`.** The `Fs` module does this in the language; a command would be a second way (principle 2).
- **`v(N)`, `e(N)`, `bt`, `memory`, `uptime`, and job control.** Power tooling a first shell does not need; each may come later on its own merits.
- **Custom printers**, OCaml's `#install_printer`. A value has one rendering, `Io.debug`'s.
- **`:!` system commands and `:def` user commands**, GHCi's. The terminal and `Fs` already exist, and a shell with user-defined commands is a second language.
- **A step debugger.** A project of its own. OCaml shows that call tracing is most of what a shell debugger is used for; `:trace f`, printing each call and return of a function, is a later item for that reason.
- **Watch expressions**, Unison's. They belong to an editor integration, not to the shell.

## A line that faults

A line that faults reports the fault and leaves the shell running with its bindings intact. Erlang restarts its evaluator for the same reason: the death of the shell's own process is the one failure a user cannot recover from at the prompt.
