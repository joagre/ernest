# Style

The style guides for the two languages of this repository, Erlang and Ernest. CLAUDE.md imports this file; the rules are read every session.

Four rules hold whatever the language, and `test/ern_style_tests.erl` checks the second, the third, and the fourth's Erlang half:

- A step of indentation is four spaces.
- No file holds a tab.
- A line of code is at most 100 characters. Prose in markdown may be longer.
- A name in a namespace the repository shares with other code carries the repository's name: an Erlang module begins `ern`, an Emacs Lisp symbol `ernest-`.

## Erlang style guide

For the toolchain's own code under `erl/`.

- **Every Erlang module is `ern_<thing>`**, where `<thing>` is unique across the repository; a vendored file keeps its upstream name. A module compiled from an Ernest source is `ern@<namespace>`, the path with `@` for `/`, so `stdlib/io.ern` becomes `ern@io`. The directory says which application a module belongs to, so the module name does not repeat it. The decisions log's *One Token for the Project* is the record of why.
- **One `-export` list at the top**, in the order the functions appear.
- **`-spec` on every exported function.** Types shared between modules are `-type`s in the owning module.
- **Records live in `include/*.hrl`** when shared, else in the module. No macros beyond record definitions and the few constants that need a name.
- **Tests are EUnit, in `test/<module>_tests.erl`**, one test function per behaviour, named after the behaviour. A comment above each names what it tests: `%% report §x.y` for the report, the document's path for any other.
- **No OTP behaviours, no rebar3.** `make` builds with `+debug_info -Werror`; a warning is an error.
- **Tokens and AST nodes are plain tuples and records**, never closures or ETS state.

## Ernest style guide

Ernest is order-independent at top level; these are style choices, not correctness. Follow them consistently.

- **Top-down layout.** Types first. Then `main` (in program modules) or exported functions (in library modules). Each root's helpers follow immediately below it, before the next root. Shared helpers go with the first user, or in a bottom utilities section if genuinely shared.
- **Indentation is a step, never an alignment.** A body, a continuation and an argument list broken over lines are each one step in from the line the construct begins on. Never line a token up under a bracket, an `->`, an `=` or a trailing comment.

      let commands = [
          Entry(name = "type", command = Type,
              about = " e   the type of e, which is not run"),
      ]

  A line that opens with a binary operator (report §2.6) carries the line above on, one step in from where that line's expression begins; every further such line stands at the same step.

      let bytes = Response(status = StatusCode.ok, headers = [], body = body)
          |> withCookie("sid", SessionId.text(id))
          |> render;

- **`then` and `else` return to the line their `if` begins on.**

      if from < 1 || from > List.size(history) then None
      else if String.indexOf(entry(history, from), query) != None then Some(from)
      else find(history, query, from + step, step)

      if List.any(Map.values(ps), fn(q) = List.contains(tailOf(q), head))
      then Player(..p, alive = false) else p

- **A signature broken over lines continues one step in**, which is where its body goes too.

      fn merge(left : List(a), right : List(a), compare : (a, a) -> Ordering with e)
          -> List(a) with e =
          match #(left, right) { ... }

- **A clause bar sits two spaces left of its arms.** A type whose alternatives run past the line breaks after the `=`.

      match xs {
          [] -> None
        | y :: rest -> get(rest, i - 1)
      }

      type ShellMsg =
          Typed(String) | Eof | Interrupted | Done(Outcome) | Died(Down)
        | ReaderDied(Down) | Ready

- **Split a long expression rather than let a line run past 100 characters.**
- **Block-comment banners for sections.** Open with `//` on its own line, one or more `// text` lines, close with `//` on its own line. Blank line before the opening, blank line after the closing. Not `// Section ----------`.
- **A module with a doc block has no header banner.** The module's `///` block is its header (report §2.2); a banner in such a file marks a section, never the file.
