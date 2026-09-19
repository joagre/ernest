# The Ernest Shell: Design Notes

The shell of MVP 2.6, `ern --shell`: an Ernest program over `Io.readLine`, with the checker's incremental entry reached through a `foreign fn` (report §8.4, §11.2). The plan owns when it is built; this document owns what it is. It is a first draft, begun 2026-09-19, and much more will be added: line editing, completion, multi-line input, how a declaration typed at the prompt is compiled and loaded, what the shell's mailbox type is, and how the evaluator is restarted.

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
- **`:reload Module`**: recompiles and reloads a module during development. It is a toolchain convenience and does not compete with §6.10's `Upgrade`.
- **`:help`** and **`:quit`**.

## What the Ernest shell leaves out

- **`pid(X, Y, Z)`.** An address is a capability; building one from numbers breaks the guarantee about who can send.
- **`regs()`.** Ernest has no registered names.
- **The records commands.** Ernest has no records; a `type` declaration typed at the prompt does their work.
- **`rp`.** The shell prints results in full, and `Io.debug` covers the rest.
- **`cd`, `pwd`, `ls`.** The `Fs` module does this in the language; a command would be a second way (principle 2).
- **`v(N)`, `e(N)`, `bt`, `memory`, `uptime`, and job control.** Power tooling a first shell does not need; each may come later on its own merits.

## A line that faults

A line that faults reports the fault and leaves the shell running with its bindings intact. Erlang restarts its evaluator for the same reason: the death of the shell's own process is the one failure a user cannot recover from at the prompt.
