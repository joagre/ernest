# The Ernest Shell: Design

The shell of MVP 2.6, `ern --shell` (report §11.2). The plan owns when it is built, the decisions log why it is as it is; this document owns what it is. First written 2026-09-19; it grows as the checkpoints settle what is marked open.

## Structure

The shell is an Ernest program. Its parts:

- **The reader** reads keystrokes through `Keys` and edits the line itself; §8.2 lets a program read keys or lines, never both. When input is not a terminal it reads lines with `Io.readLine`, without editing: line mode.
- **The front end** is the Erlang toolchain, reached through the foreign interface below: checking, compiling, running, printing, listing exports, documentation.
- **The evaluator** runs each input in a fresh process, whose mailbox type is the input's own inferred effect, a polymorphic one instantiated to `Never` as an entry point's is (§8.1). The shell monitors it (§6.9). A fault or an interruption ends that process only; the shell reports it and keeps its bindings. The shell's own process never runs user code.
- **The printer** prints results as below.
- **The commands** are below.

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
- **`self()` names the input's own process**, which ends with the input. An address bound to it reaches no one on a later input; a message is received inside the input that expects it.

## Output

- **An expression prints its value and its type**, the type as the checker prints it (§11.5): `3 : Int`. A declaration prints its name and type, `double : (Int) -> Int`; a `let` its name and type, `xs : List(Int)`.
- **A value is printed as `Io.debug` prints it** (Appendix E.1), by its type; the shell and `Io.debug` share one printer, `ern_show`.
- **A large value is printed to a depth and a length,** the rest as `...`. The defaults are open; `:set` changes them.
- **An input that does not check is shown as `ernc` shows an error** (§11.5), the input as the source and the span underlined. Nothing is run.
- **A fault in an input is printed as `fault: ` and its text,** an interruption as `Killed`.
- **A process spawned at the prompt that faults is reported** with its spawn site and cause: `a process spawned at input 3 faulted: division by zero`.
- **With timing on, each result is followed by its elapsed time.**
- **Colour:** types dimmed, errors red, the history suggestion greyed. None when output is not a terminal or `NO_COLOR` is set.
- **Output from another process while a line is being typed** is printed above it, and the prompt and the partial line are drawn again below.

## Line editing

GNU Readline's Emacs bindings.

- **Moving:** `C-a`, `C-e` to the start and end of the line; `C-b`, `C-f` a character; `M-b`, `M-f` a word; the arrow keys.
- **Deleting:** `Backspace` and `C-h` back, `C-d` forward; on an empty line `C-d` quits.
- **Killing:** `C-k` to the end of the line, `C-u` to the start, `C-w` and `M-Backspace` the word before, `M-d` the word after. A kill goes to the kill ring; `C-y` yanks the last, `M-y` cycles.
- **Transposing and case:** `C-t` two characters, `M-t` two words; `M-u`, `M-l`, `M-c` upcase, downcase, capitalize a word.
- **History:** `C-p`, `C-n`, up and down step through earlier inputs; `M-<` and `M->` go to the first and the current; `C-r` searches back incrementally, `C-s` forward, `C-g` abandons the search. The history is kept in the configuration directory (§11.2), `history`.
- **Suggestion:** the most recent earlier input that begins with the text typed is shown greyed after the cursor; the right arrow, or `C-e` at the end of the line, accepts it.
- **Interrupting:** `C-c` abandons the line being typed, and during an evaluation kills the input's process.
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

A command is `:` and a name; it is not an Ernest function. Any prefix of a name selects the command, and an ambiguous prefix selects the first in the order below: `:t` is `:type`, `:b` `:browse`, `:l` `:load`, `:r` `:reload`, `:q` `:quit`, `:d` `:doc`, `:f` `:forget`.

- **`:type e`**: the type of `e`, which is not run.
- **`:browse Module`**: the exports of `Module` with their types.
- **`:load file`**: the file's declarations, as if typed at the prompt.
- **`:reload Module`**: recompiles and reloads `Module`; without a name, every loaded module whose source changed since it was loaded.
- **`:quit`**: quits.
- **`:doc Name`**: the documentation of `Name`, as `ernc --doc` renders it (§11.4), the declaration included.
- **`:help`**: the commands and their prefixes; it says that `:doc` is what GHCi calls `:info`.
- **`:forget x`**: forgets the binding `x`; without a name, all bindings.
- **`:bindings`**: the bindings, with their types.
- **`:processes`**: the live processes with their spawn sites (§6.9).
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
- **Custom printers:** a value has one rendering.
- **User-defined commands, system commands, job control, a step debugger, and watch expressions.**
- **Later, each on its own merits:** re-running an earlier input by number, `:trace f` to print each call and return of `f`, and, with MVP 3's peers, a shell attached to a running node. The design does not assume the shell runs on the node whose code it evaluates.

## Foreign interface

A sketch, settled at checkpoint 1. The user's values are handles of distinct foreign types, so the shell cannot pass one kind where another is expected; types reach the shell as text.

```
foreign type Env      // the bindings, with their types
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

- **`Keys`** delivers the arrows, `Enter`, `Escape`, and characters since MVP 2.5 step 4 (§9.3's `Key`). `Shift-Tab`, `Meta` combinations, and `C-c` as a key are not in `Key` and land with the shell, report first (MVP 2.6).
- **The terminal's width**, for redrawing a wrapped line and laying out candidates. Not in the report; it lands with the shell, report first (MVP 2.6).
- **Whether input is a terminal**, for line mode. Not in the report; it lands with the shell, report first (MVP 2.6).
- **A notice that another process printed**, for redrawing the line. Not in the report; it lands with the shell, report first (MVP 2.6).
- **Documentation in the `.erc`**, with each function's parameters as written, for `:doc` and `Shift-Tab` (MVP 2.5, step 6).
- **The report's §11.2** states the shell's normative core: types on every result, a module and a process per input, bindings that survive a fault, the commands and their prefix rule, and line mode (MVP 2.6).

## Open

- **The depth and length defaults.**
- **How the line editor measures wide characters.**
- **The exact foreign interface.**

## Testing

- **A session is a golden test:** a file of inputs run in line mode, `ern --shell < session.ern`, against a file of expected output, under `test/`.
- **The line editor is a pure function** from a state and a key to a new state and what to draw; tests feed key lists and compare line, cursor, and output.
- **Completion is tested on the foreign entries' answers:** a prefix and an environment in, candidates out.

## Checkpoints

The plan's item stops at each; each is a shell a user can try.

1. **Line mode.** The foreign interface; every input checked, run, and printed; bindings, `it`, faults, errors, timing, fault reports from spawned processes, the startup file, quitting, the commands; the session golden tests.
2. **The line editor.** The bindings above, history, the suggestion, interruption, redrawing after other output, bracketed paste, the prompts, colour; the key-stream tests.
3. **Completion and documentation.** `Tab`, `Shift-Tab`, command arguments.
