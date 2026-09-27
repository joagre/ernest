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

Ernest is order-independent at top level; these are style choices, not correctness. Follow them consistently. `test/ern_style_tests.erl` checks four of them: a blank line between declarations, one statement a line and a block of more than one, and a function's head. Two are not yet the code's form, `then` and `else` over lines and a bracket closed on its own line; the formatter brings the code to them (plan, MVP 2.95), and each says so.

- **Top-down layout.** Types first. Then the module's service bindings, each followed by its helpers, since what comes after uses them. Then `main` (in program modules) or exported functions (in library modules). Each root's helpers follow immediately below it, before the next root. Shared helpers go with the first user, or in a bottom utilities section if genuinely shared.
- **A blank line stands between top-level declarations.** A declaration's comment or doc block stands directly above it, and the blank line stands above that.

      // Report §11.2: the parser cannot finish what is typed, so another line
      // may. The parser is the compiler's, and only it knows.
      foreign fn needsMore(input : String) -> Bool =
          "ern_shell:needs_more/1"

      // Report §11.2: every name completion may reach, as the session stands.
      foreign fn names() -> List(Shell.Complete.Name) with m =
          "ern_shell:names/0"

- **Indentation is a step, never an alignment.** A body, a continuation and an argument list broken over lines are each one step in from the line the construct begins on. Never line a token up under a bracket, an `->`, an `=` or a trailing comment.

      let commands = [
          Entry(
              name = "type", command = Type,
              about = " e   the type of e, which is not run"
          )
      ]

  A line that opens with a binary operator (report §2.6) carries the line above on, one step in from where that line's expression begins; every further such line stands at the same step.

      let bytes = Response(status = StatusCode.ok, headers = [], body = body)
          |> withCookie("sid", SessionId.text(id))
          |> render;

- **One statement a line, and a block holds more than one.** One expression is written bare, without braces around it. A block is written over lines, one statement to a line: its opening brace ends the line the block begins on, and its closing brace stands alone at that line's indentation, in a clause as anywhere. An input at the shell's prompt, which without a terminal is one line, is written as it is typed.

      else {
          send(to, Item(next));
          produce(to, next + 1, last, credit - 1)
      }

      | Get(reply = r) -> {
            answer(r, n);
            counter(n)
        }

      | Some(path) -> match Fs.read(path, wait) {
            Left(why) -> Left(why)
          | Right(bytes) -> Right(inputs(bytes))
        }

- **`then` and `else` end their lines, and each branch begins the next line, one step in.** `then` stays on the line its `if` begins on. `else` returns to that line's indentation, and `else if` is written on one line. The code takes this form with the formatter (plan, MVP 2.95) and keeps the older one until then, `then` and `else` returning to the `if`'s line with their branches beside them.

      if from < 1 || from > List.size(history) then
          None
      else if String.indexOf(entry(history, from), query) != None then
          Some(from)
      else
          find(history, query, from + step, step)

- **A function's head ends at `=`, and its body begins on the next line, one step in.** A body of one short line is no exception.

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

- **A signature broken over lines continues one step in**, which is where its body goes too. A parameter list that runs over lines is a bracket, and closes as the next rule says.

      fn merge(left : List(a), right : List(a), compare : (a, a) -> Ordering with e)
          -> List(a) with e =
          match #(left, right) { ... }

- **A bracket whose contents run over lines closes on a line of its own**, at the indentation of the line it opened on, as a block's brace does. What follows the bracket, a return type, a `;` or an operator, follows it on that line. Brackets opened on one line close together on one line. The code takes this form with the formatter (plan, MVP 2.95) and keeps the older one until then, a closing bracket ending the line of the contents' last.

      fn handler(
          sessions : Address(SessionMsg),
          seq : Int,
          sock : Address(Tcp.SockMsg)
      ) -> Unit with m =
          match Tcp.read(sock, 5000) { ... }

      let words = Test(name = "a word ends where a name cannot go on", run = fn() = {
          let seen = word("1 + List.ma");
          if seen == "List.ma" then
              Passed
          else
              Failed(seen)
      })

- **A clause bar sits two spaces left of its arms.** A type whose alternatives run past the line breaks after the `=`.

      match xs {
          [] -> None
        | y :: rest -> get(rest, i - 1)
      }

      type ShellMsg =
          Typed(String) | Eof | Interrupted | Done(Outcome) | Reported(Process.FaultReport)
        | ReaderDied(Down) | Ready | NoKeys

- **Split a long expression rather than let a line run past 100 characters.**
- **Block-comment banners for sections.** Open with `//` on its own line, one or more `// text` lines, close with `//` on its own line. Blank line before the opening, blank line after the closing. Not `// Section ----------`.
- **A module with a doc block has no header banner.** The module's `///` block is its header (report §2.2); a banner in such a file marks a section, never the file.
