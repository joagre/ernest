# The Emacs mode

`ernest-mode` edits `.ern` files. It is in `emacs/`, the only Elisp in the repository, and
its own header says how to load it. The roadmap entry is MVP 2.9 in
[`implementation_plan.md`](implementation_plan.md); the arguments that settled it are in
[`decisions.md`](decisions.md).

## What it is

Derived from `prog-mode`, not from CC Mode.

- A syntax table for `//` and `/* */` comments, `///` doc comments with a face of their own,
  strings, backtick raw strings that may span lines, and a `syntax-propertize-function` for
  char literals.
- Font lock from report §2: reserved words, uppercase-initial names as types and
  constructors, lowercase as values, qualified names, operators, and the numeric literals of
  §2.5.
- Indentation to [`style.md`](style.md), which owns it.
- `imenu`, `beginning-of-defun`, `end-of-defun`, `add-log-current-defun-function`.
- `compilation-error-regexp-alist` for `file:line:col: message`.
- `auto-mode-alist` for `.ern`.

It never calls the compiler; `M-x compile` does. It byte-compiles and passes `checkdoc`
without a warning, as the Erlang builds with `-Werror`.

The mode's reserved words and operators restate Appendix A, so
`emacs_mode_mirrors_the_lexer_test` in `test/ern_style_tests.erl` keeps them equal to the
lexer's.

## How it is judged

Five corpora under `emacs/test/`. `make emacs-mode` runs them and `make test` runs them
last; a machine without Emacs skips them.

| Corpus | What it holds | Result |
| --- | --- | --- |
| `reindent.el` | the repository's sources reindent unchanged | 0 of 6,090 lines |
| `typing.el` | the same sources, cut mid-expression, still hold | 0 lines over 1,141 cuts |
| `broken.el` over `broken/` | eight half-typed buffers keep their indentation, and a fresh line at the end takes the column a person expects | 8 of 8 |
| `colour.el` | one check for each kind of face | passes |
| `editing.el` | `imenu`, declaration movement, the diagnostic regexp | passes |

## What it does not do

Stated so that nobody looks for it.

- **A constructor is painted as a type.** Both are uppercase and the difference is
  positional.
- **Nothing knows the language, only its shape.** No `eldoc`, no `xref`, no completion in
  the buffer, no jump to a definition in another module. `imenu`, `C-M-a` and `C-M-e` work
  inside the file. What a name means is `M-x compile`'s answer.
- **No `comint` mode over `ern --shell`**, no folding, no `prettify-symbols`, and no keymap
  of its own: it takes `prog-mode`'s.
- **It is installed by path, not as a package.** No `Version:` or `Package-Requires:`
  headers, and it is not on MELPA.
- **Indentation is line by line.** There is no `indent-region-function`.
