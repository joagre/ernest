# Style

The style guides for the two languages in this repository. CLAUDE.md imports this file; the rules are read every session.

## Erlang style guide

For the compiler's own code under `lib/`.

- **Four-space indent, no tabs. Lines ≤ 100 characters,** which `test/ern_style_tests.erl` checks.
- **Module names carry the `ern_` prefix**, except modules implementing Ernest namespaces, `ernest@io`. One `-export` list at the top, in the order the functions appear.
- **`-spec` on every exported function.** Types shared between modules are `-type`s in the owning module.
- **Records live in `include/*.hrl`** when shared, else in the module. No macros beyond record definitions and the few constants that need a name.
- **Tests are EUnit, in `test/<module>_tests.erl`**, one test function per behaviour, named after the behaviour, each with a `%% report §x.y` line.
- **No OTP behaviours, no rebar3.** `make` builds with `+debug_info -Werror`; a warning is an error.
- **Tokens and AST nodes are plain tuples and records**, never closures or ETS state.

## Ernest style guide

Ernest is order-independent at top level; these are style choices, not correctness. Follow them consistently.

- **Top-down layout.** Types first. Then `main` (in program modules) or exported functions (in library modules). Each root's helpers follow immediately below it, before the next root. Shared helpers go with the first user, or in a bottom utilities section if genuinely shared.
- **Four-space indent, no tabs.**
- **No alignment padding, anywhere.** Don't add spaces to align tokens across lines: `->`, `=`, trailing `//` comments, anything. Structural indentation (block bodies, clause separators) isn't padding — that stays. One space where a space is needed.
- **Code lines ≤ 100 characters,** which `test/ern_style_tests.erl` checks. Split long expressions rather than let one line run wide. Prose in markdown can be longer.
- **Block-comment banners for sections.** Open with `//` on its own line, one or more `// text` lines, close with `//` on its own line. Blank line before the opening, blank line after the closing. Not `// Section ----------`.
- **A module with a doc block has no header banner.** The module's `///` block is its header (report §2.2); a banner in such a file marks a section, never the file.
