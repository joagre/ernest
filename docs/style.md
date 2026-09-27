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

Ernest is order-independent at top level; these are style choices, not correctness. Follow them consistently. `test/ern_style_tests.erl` checks four of them: a blank line between declarations, one statement a line and a block of more than one, and a function's head. Five are not yet the code's form: a bracket's items aligned, a brace over lines, a bracket that does not fit broken one item a line, an `if` broken whole, and a body broken where it does not fit. Each says so. The formatter brings the code to them (plan, MVP 2.8). Until its first run the code keeps the form it has, and new code is written in that form too, so that no file holds two.

- **Top-down layout.** Types first. Then the module's service bindings, each followed by its helpers, since what comes after uses them. Then `main` (in program modules) or exported functions (in library modules). Each root's helpers follow immediately below it, before the next root. Shared helpers go with the first user, or in a bottom utilities section if genuinely shared.
- **A blank line stands between top-level declarations.** A declaration's comment or doc block stands directly above it, and the blank line stands above that.

      // Report §11.2: the parser cannot finish what is typed, so another line
      // may. The parser is the compiler's, and only it knows.
      foreign fn needsMore(input : String) -> Bool =
          "ern_shell:needs_more/1"

      // Report §11.2: every name completion may reach, as the session stands.
      foreign fn names() -> List(Shell.Complete.Name) with m =
          "ern_shell:names/0"

- **Indentation is a step, and only a bracket's items align.** A line stands one step in from the line on which the innermost construct still open around it began. A construct is a bracket or a brace, a body after a `=`, `->`, `then` or `else` that ends a line, or an expression that an operator carries on. A line that begins by closing a construct, with a closing bracket or brace or with `else`, stands at the line the construct began on. A line stands where its first token stands; a clause's bar is not counted, and the line stands where the pattern after the bar begins. The items of a bracket that breaks align under its first item (below), and an item counts as beginning a line where it stands. Nothing else is lined up: not under an `->`, an `=` or a trailing comment. The formatter brings the code to the alignment; the code still steps a bracket's items in.

  A line that opens with a binary operator (report §2.6) carries on the expression above it. It stands one step in from the line that expression begins on, and every further such line stands at the same step.

      let bytes = Response(status = StatusCode.ok, headers = [], body = body)
          |> withCookie("sid", SessionId.text(id))
          |> render;

- **One statement a line, and a block holds more than one.** One expression is written bare, without braces around it. A block holds its statements one to a line, as the next rule says. An input at the shell's prompt, which without a terminal is one line, is written as it is typed.

- **A brace runs over lines.** A block, a `match` and a `receive` are written over lines however short they are. The opening brace ends the line it stands on. The statements or the arms stand one to a line, one step in. The closing brace begins a line at the indentation of the line the brace opened on, and what follows it, an `else`, a `then`, a `;`, a `)` or an operator, follows it on that line. The formatter brings the code to this rule; the code still holds matches on one line.

      let readers = match keys {
          Some(#(reader, _)) -> [Process.fromAddress(reader)]
        | None -> []
      };

      } else {
          send(to, Item(next));
          produce(to, next + 1, last, credit - 1)
      }

      | Get(reply = r) -> {
            answer(r, n);
            counter(n)
        }

- **A bracket that does not fit holds one item a line, aligned under the first.** A bracket is a parenthesis, a square bracket or a bitstring's `<<`: a call's arguments, a function's parameters, a constructor's fields where it is declared and where it is built, a tuple, a list and a bitstring. A bracket and its items stay on one line when the whole line fits in 100 characters. Otherwise the first item stays on the bracket's line, each further item stands on a line of its own under the first, and the closing bracket ends the last item's line. What follows the closing bracket, a return type, a `;` or an operator, follows it on that line. The outermost bracket of a line breaks first, and each line that results is laid out again by these rules. A bracket that holds one item does not break. The formatter brings the code to this rule.

      fn run(state : State,
             screen : Address(ScreenMsg),
             from : String,
             line : Int,
             input : String,
             printing : Bool) -> State with ShellMsg =
          match check(state.env, from, line, input) { ... }

      readLoop(session,
               screen,
               Reading(editing = Shell.Editor.start(earlier),
                       keeping = true,
                       hinted = false,
                       last = Ordinary,
                       colour = colour))

  A last item whose first line ends in a brace, a lambda whose body is a block, a `match` or a `receive`, stays on the bracket's line when that line fits up to the brace. The brace's contents stand one step in from that line, and the brace and the bracket close together.

      let screen = spawn(Local, fn() = match keys {
          Some(#(_, size)) -> screenLoop(Shell.Region.new(size))
        | None -> plainLoop()
      });

- **An `if` stays on one line when it fits, and otherwise breaks at `then` and `else`.** Each branch then begins the next line, one step in. `else` returns to the indentation of the line the `if` began on, whether that line begins with the `if`, a `let`, a pattern or a lambda's `fn`. A branch whose first line ends in a brace or a `then` stays on its `then` or `else` line when that line fits: `then {`, `else {`, `else match x {`, and `else if`, which is written on one line. The formatter brings the code to this rule; the code still holds `then` and `else` returning to the `if`'s line with their branches beside them.

      let rows = if listed then listing(completion, reading.colour) else [];

      if from < 1 || from > List.size(history) then
          None
      else if String.indexOf(entry(history, from), query) != None then
          Some(from)
      else
          find(history, query, from + step, step)

- **The body of an arm or a lambda stays on its line when it fits.** The body after an arm's `->`, or after a lambda's `=`, stays on that line when it fits there whole, or when its first line ends in a brace or a `then` and that line fits. Otherwise it begins the next line, one step in. A lambda has no other rule of its own. The formatter brings the code to this rule.

      | Some(path) -> match Fs.read(path, wait) {
            Left(why) -> Left(why)
          | Right(bytes) -> Right(inputs(bytes))
        }

      match b {
          Markdown.Paragraph([Markdown.Emphasis([Markdown.Text(text)])]) ->
              String.startsWith(text, "Since ")
        | _ -> false
      }

- **A function's head ends at `=`, and its body begins on the next line, one step in.** A body of one short line is no exception. The head's parameters are a bracket, and break as one does.

      fn walk(state : State, step : Int) -> State =
          walkTo(state, state.back + step)

      export fn midSequence(state : State) -> Bool =
          match state {
              State(pending = Plain) -> false
            | _ -> true
          }

  A body that is a block is written as every block is: its brace ends the head's line.

      fn run(state : State, input : String) -> State with ShellMsg = {
          let checked = check(state.env, input);
          await(state, checked)
      }

  A `foreign fn`'s implementation string is its body, and stands where a body does.

      export foreign fn toUpper(s : String) -> String =
          "ern_string:to_upper/1"

- **A clause bar sits two spaces left of its arms.** A type whose alternatives run past the line breaks after the `=`.

      match xs {
          [] -> None
        | y :: rest -> get(rest, i - 1)
      }

      type ShellMsg =
          Typed(String) | Eof | Interrupted | Done(Outcome) | Reported(Process.FaultReport)
        | ReaderDied(Down) | Ready | NoKeys

- **Split a long expression by these rules, and name a part of it where the split reads worse than a name.** The formatter will split, but only the writer can name.

      | other -> {
            let text = "the shell stopped reading the keyboard: " <> faultLine(other);
            finish(screen, Shell.Style.fault(colour, text) <> "\n")
        }

- **Block-comment banners for sections.** Open with `//` on its own line, one or more `// text` lines, close with `//` on its own line. Blank line before the opening, blank line after the closing.
- **A module with a doc block has no header banner.** The module's `///` block is its header (report §2.2); a banner in such a file marks a section, never the file.
