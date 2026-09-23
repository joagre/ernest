# The Emacs mode

`ernest-mode` edits `.ern` files: colouring, indentation and jump-to-error. It lives in
`emacs/` and is the only Elisp in the repository. `docs/implementation_plan.md` holds its
place in the roadmap, MVP 2.9.

## What it is

Derived from `prog-mode`, not from CC Mode: Ernest is expression-structured, where CC Mode's
engine assumes C's statements and declarations.

- A syntax table for `//` and `/* */` comments, `///` doc comments with a face of their own,
  `"` strings, backtick raw strings that may span lines, and a `syntax-propertize-function`
  for char literals, so an apostrophe in prose cannot unbalance a buffer.
- Font lock from the report's §2: reserved words, uppercase-initial names as types and
  constructors, lowercase as values, qualified names, operators, and the numeric literals of
  §2.5 with their based forms and digit separators.
- Indentation to `docs/style.md`, which owns it.
- `compilation-error-regexp-alist` for `file:line:col: message`, so `M-x compile` over `ernc`
  jumps to the diagnostic.
- `auto-mode-alist` for `.ern`.

Not in this step: a `comint` mode over `ern --shell`, and completion.

**The mode never calls `ernc` to indent or colour.** A per-keystroke call on a broken buffer
cannot work. `ernc` is reached through `M-x compile`, and `compilation-error-regexp-alist` is
all that needs.

## How it is judged

The mode is used almost only on broken code: between keystrokes a buffer is unbalanced, a
clause is half typed, a string is open. Two corpora settle it, and both are independent of
the technique.

1. **The repository's own sources**, which are written to `docs/style.md`. Reindenting one
   must leave it unchanged. `emacs/test/reindent.el`.
2. **Broken buffers**: a `match` with no closing brace, a bare `|`, a line ending in `->` or
   `=`, a trailing comma, a missing `}`, an unclosed raw string, an unclosed block comment,
   an apostrophe in prose. Each keeps its indentation, and a fresh line at the end takes the
   column a person expects. `emacs/test/broken.el` over `emacs/test/broken/`, and
   `emacs/test/typing.el`, which cuts every source in the repository and reindents what
   survives.

Colouring cannot be measured against the repository, so it is pinned by
`emacs/test/colour.el`, one check for each kind of face, and what the mode gives beyond
colour and indentation by `emacs/test/editing.el`.

`make emacs-mode` runs all five, and `make test` runs them last. A machine without Emacs
skips them and says so.

## What the corpora measured

23 September 2026, on the regexp and syntax-table mode.

| Corpus | Result |
| --- | --- |
| The repository's sources | 0 of 6,090 lines moved |
| Broken buffers | 8 of 8 held |
| Sources cut at every third line | 1 line over 2,005 cuts, the harness's own edge |
| Colour | passes after two defects were fixed |

The first run of corpus 1 said 624 lines, and every rule that closed part of the gap made
another file worse. The cause was not the mode: the corpus held four constructs two ways
each. `docs/style.md` gained four rules, the sources were reindented to them, and three of
the four rules took a special case out of the mode.

The two colour defects were invisible to any indentation run: every face was named as a
variable where Emacs 31 has only the face, so font lock raised an error on every buffer, and
the two rules for a declaration's own name used a substring that cut one character too many,
so they had never matched.

**Verdict: the regexp and syntax-table mode holds both corpora, and tree-sitter is not
bought.** What a grammar would still give is `Foo` as a type in one position and a
constructor in another, which regexps cannot reach. It costs a grammar restating Appendix A
in a fourth language with no mirror test, a C toolchain and a per-platform object. That one
distinction does not buy it. Revisit if a second reason appears.

## What it does not do

Stated so that nobody looks for it.

- **A constructor is painted as a type.** Both are uppercase and the difference is
  positional, which is what a regexp cannot see. This is the one thing a grammar would add.
- **Nothing knows the language, only its shape.** No `eldoc`, no `xref`, no completion in the
  buffer, no jump to a definition in another module. `imenu`, `C-M-a` and `C-M-e` work inside
  the file, from the declarations' own shape. What a name means is `M-x compile`'s answer.
- **No `comint` mode over `ern --shell`.** The shell is run in a terminal.
- **No folding**, no `prettify-symbols`, no bindings of its own: the mode adds no keymap and
  takes `prog-mode`'s.
- **It is installed by path, not as a package.** No `Version:` or `Package-Requires:`
  headers, and it is not on MELPA; the three lines that load it are in the file's header.
- **Indentation is line by line.** There is no `indent-region-function`, which costs three
  seconds over the six thousand lines of this repository.

## What remains

- A test keeping the mode's reserved-word and operator lists equal to the lexer's. Until it
  exists those lists are an unmirrored restatement of Appendix A, which is a wart.
- The Elisp rule in `docs/style.md`: lines ≤ 100, no tabs, and the mode is the only Elisp
  here.
- `emacs/` in the README's layout section.
