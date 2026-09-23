# Style

The style guides for the two languages in this repository. CLAUDE.md imports this file; the rules are read every session.

## Erlang style guide

For the toolchain's own code under `erl/`.

- **Four-space indent, no tabs. Lines ≤ 100 characters,** which `test/ern_style_tests.erl` checks.
- **Every Erlang module is `ern_<thing>`**, where `<thing>` is unique across the repository; a vendored file keeps its upstream name. A module compiled from an Ernest source is `ern@<namespace>`, the path with `@` for `/`, so `stdlib/io.ern` becomes `ern@io`. The directory says which application a module belongs to, so the module name does not repeat it. The decisions log's *One Token for the Project* is the record of why.
- **One `-export` list at the top**, in the order the functions appear.
- **`-spec` on every exported function.** Types shared between modules are `-type`s in the owning module.
- **Records live in `include/*.hrl`** when shared, else in the module. No macros beyond record definitions and the few constants that need a name.
- **Tests are EUnit, in `test/<module>_tests.erl`**, one test function per behaviour, named after the behaviour, each with a `%% report §x.y` line.
- **No OTP behaviours, no rebar3.** `make` builds with `+debug_info -Werror`; a warning is an error.
- **Tokens and AST nodes are plain tuples and records**, never closures or ETS state.

## Python

One file only, `test/ern_pty.py`, the pseudo-terminal the terminal tests need and Erlang cannot open. It keeps the repository's name, `ern_`, and its lines are ≤ 100 characters like everything else; `test/ern_style_tests.erl` checks the length.

## Elisp

One file only, `emacs/ernest-mode.el`, the Emacs mode, with its corpora under `emacs/test/`. Lines ≤ 100 characters, no tabs, and the conventions of an Emacs major mode over these rules: `lexical-binding`, an `ernest-` prefix on every name and `ernest--` on the private ones, a docstring on everything, and the file byte-compiles and passes `checkdoc` without a warning.

## Ernest style guide

Ernest is order-independent at top level; these are style choices, not correctness. Follow them consistently.

- **Top-down layout.** Types first. Then `main` (in program modules) or exported functions (in library modules). Each root's helpers follow immediately below it, before the next root. Shared helpers go with the first user, or in a bottom utilities section if genuinely shared.
- **Four-space indent, no tabs.**
- **Indentation is a step, never an alignment.** A body, a continuation and an argument list broken over lines are each one step in from the line the construct begins on. Never line a token up under a bracket, an `->`, an `=` or a trailing comment.

      let commands = [
          Entry(name = "type", command = Type,
              about = " e   the type of e, which is not run"),
      ]

- **`else` returns to the line its `if` begins on.**

      if from < 1 || from > List.size(history) then None
      else if String.indexOf(entry(history, from), query) != None then Some(from)
      else find(history, query, from + step, step)

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

- **Code lines ≤ 100 characters,** which `test/ern_style_tests.erl` checks. Split long expressions rather than let one line run wide. Prose in markdown can be longer.
- **Block-comment banners for sections.** Open with `//` on its own line, one or more `// text` lines, close with `//` on its own line. Blank line before the opening, blank line after the closing. Not `// Section ----------`.
- **A module with a doc block has no header banner.** The module's `///` block is its header (report §2.2); a banner in such a file marks a section, never the file.
