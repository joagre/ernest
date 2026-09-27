# Style

The style guides for the two languages of this repository, Erlang and Ernest. CLAUDE.md imports this file; the rules are read every session.

Four rules hold whatever the language, and `test/ern_style_tests.erl` checks the second, the third, and the fourth's Erlang half:

- A step of indentation is four spaces.
- No file holds a tab, but a Makefile, whose recipes need one.
- A line of code is at most 100 characters. Prose in markdown may be longer.
- A name in a namespace the repository shares with other code carries the repository's name: an Erlang module begins `ern`, an Emacs Lisp symbol `ernest-`.

## Erlang style guide

For the toolchain's own code under `erl/`.

- **Every Erlang module is `ern_<thing>`**, where `<thing>` is unique across the repository; a vendored file keeps its upstream name. A module compiled from an Ernest source is `ern@<namespace>`, the path with `@` for `/`, so `stdlib/io.ern` becomes `ern@io`. The directory says which application a module belongs to, so the module name does not repeat it. The decisions log's *One Token for the Project* is the record of why.
- **One `-export` list at the top**, in the order the functions appear.
- **`-spec` on every exported function.** Types shared between modules are `-type`s in the owning module.
- **Records live in `include/*.hrl`** when shared, else in the module. No macros beyond record definitions and the few constants that need a name.
- **Tests are EUnit, in `erl/<app>/test/<module>_tests.erl`**, or under `test/` for what spans applications, one test function per behaviour, named after the behaviour. A comment above each names what it tests: `%% report §x.y` for the report, the document's path for any other.
- **No OTP behaviour for a process of the toolchain's own, and no rebar3, by design.** A callback module one of OTP's own servers calls, a signal handler, is no such process. The decisions log's *No OTP in the Toolchain* says why. `make` builds with `+debug_info -Werror`; a warning is an error.
- **Tokens and AST nodes are plain tuples and records**, never closures or ETS state.
- **A precondition is `Cond orelse fail(...)` on one line.** Two or more conditions before the `fail` are a `case` on them, so that a reader sees at once which message goes with which failure.

## Ernest style guide

Ernest is order-independent at top level; these are style choices, not correctness. `ern format` writes the layout of the second list, and `make test` holds every module and every Ernest block of the report and the guide to it (report §11.6); `make format` lays out what is not. The Emacs mode indents as the formatter does ([`emacs_mode.md`](emacs_mode.md)). What no formatter can decide is the writer's, and comes first.

### What the writer decides

- **Top-down layout.** Types first. Then the module's service bindings, each followed by its helpers, since what comes after uses them. Then `main` (in program modules) or exported functions (in library modules). Each root's helpers follow immediately below it, before the next root. Shared helpers go with the first user, or in a bottom utilities section if genuinely shared.
- **A block holds more than one statement.** One expression is written bare, without braces around it. `test/ern_style_tests.erl` checks it.
- **A blank line groups.** A blank line inside a construct is the writer's, and the formatter keeps it. One stands between two top-level declarations always, a declaration's comment or doc block directly above it.
- **Name a part of a long expression where the formatter's split reads worse than a name.** The formatter splits, but only the writer can name.

      | other -> {
            let text = "the shell stopped reading the keyboard: " <> faultLine(other);
            finish(screen, Shell.Style.fault(colour, text) <> "\n")
        }

- **Block-comment banners for sections.** Open with `//` on its own line, one or more `// text` lines, close with `//` on its own line. Blank line before the opening, blank line after the closing.
- **A module with a doc block has no header banner.** The module's `///` block is its header (report §2.2); a banner in such a file marks a section, never the file.

### The layout `ern format` writes

- **Indentation is a step, and only a bracket's items align.** A line stands one step in from the line on which the innermost construct still open around it began: a bracket or a brace, a body after a `=`, `->`, `then` or `else` that ends a line, or an expression an operator carries on. A line that begins by closing a construct, with a closing bracket or brace or with `else`, stands at that construct's line. A clause's bar is not counted: the line stands where the pattern after it begins. An item standing after its bracket counts as beginning a line there. Nothing else is lined up: not under an `->`, an `=` or a trailing comment.
- **A line that opens with a binary operator carries on the expression above it**, one step in from the line that expression began on. A further line of the same expression stands at the same step; one that opens with an operator binding more tightly carries on the operand begun on the line above, and stands a step further.

      let bytes = Response(status = StatusCode.ok, headers = [], body = body)
          |> withCookie("sid", SessionId.text(id))
          |> render;

- **One statement a line, and a brace runs over lines.** A block, a `match` and a `receive` are written over lines however short, their statements or arms one a line, one step in, a further arm led by its bar two columns to the left. The closing brace begins its line at the indentation of the line the construct began on, and what follows it, an `else`, a `then`, a `;`, a `)` or an operator, follows it there.

      let readers = match keys {
          Some(#(reader, _)) -> [Process.fromAddress(reader)]
        | None -> []
      };

- **A bracket that does not fit holds one item a line, aligned under the first.** A bracket is a parenthesis, a square bracket or a bitstring's `<<`: a call's arguments, a function's parameters, a constructor's fields where it is declared and where it is built, a tuple, a list and a bitstring. A bracket stays on one line when the whole line fits in 100 characters. Otherwise its first item stays on the bracket's line, each further item stands under it, and the closing bracket ends the last item's line. The outermost bracket breaks first, and of two on a line the first; a bracket of one item does not break. A comment or a doc block before the first item puts it on a line of its own, and the items a step in.

      fn run(state : State,
             screen : Address(ScreenMsg),
             from : String,
             input : String) -> State with ShellMsg =
          match check(state.env, from, input) { ... }

- **A last item that opens a brace keeps the items on the bracket's line**, where that line fits up to the brace: a lambda whose body is a block, a `match` or a `receive`. The brace's contents stand a step in from that line, and the brace and the bracket close together.

      let screen = spawn(Local, fn() = match keys {
          Some(#(_, size)) -> screenLoop(Shell.Region.new(size))
        | None -> plainLoop()
      });

- **An `if` stays on one line when it fits, and otherwise breaks at every `then` and `else`.** A branch begins the next line, one step in, and `else` returns to the line the `if` began on, whether it begins with the `if`, a `let`, a pattern or a lambda's `fn`. A branch whose first line ends in a brace or a `then` stays beside its `then` or `else` when that fits: `then {`, `} else {`, `else match x {`, and `else if`, written on one line.

      if from < 1 || from > List.size(history) then
          None
      else if String.indexOf(entry(history, from), query) != None then
          Some(from)
      else
          find(history, query, from + step, step)

- **The body of an arm or a lambda stays on its line when it fits**, whole or up to a brace or a `then` that ends its first line, and otherwise begins the next line, one step in. A lambda has no other rule of its own.

      | Markdown.Paragraph([Markdown.Emphasis([Markdown.Text(text)])]) ->
            String.startsWith(text, "Since ")

- **A function's head ends at `=`, and its body begins on the next line, one step in**, however short; a body that is a block opens its brace at the end of the head's line, and a `foreign fn`'s implementation string stands where a body does.

      fn walk(state : State, step : Int) -> State =
          walkTo(state, state.back + step)

- **A type whose alternatives do not fit breaks after its `=`** and fills the lines, a further line led by its bar two columns to the left.

      type ShellMsg =
          Typed(String) | Eof | Interrupted | Done(Outcome) | Reported(Process.FaultReport) | Ready
        | NoKeys
