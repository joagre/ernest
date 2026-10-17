# The Emacs mode

Status: the Emacs mode's design note, which changes when the mode does. It is not a proposal, and not authoritative.

`ernest-mode` edits `.ern` files. It is `editors/emacs/ernest-mode.el`, the mode's one source file, and the lines an init file needs, to load it, to lay out each buffer as it is saved and to show a tab or a long line, are in that file's header and in [`editors/emacs/README.md`](../../editors/emacs/README.md) beside it, which a test holds equal. Emacs 29 is the first with `font-lock-operator-face`, which it uses. Its tests have run on Emacs 31.1 alone, so Emacs 29 and 30 are expected to work and are not yet verified; `make test-emacs EMACS=path` runs them under another. The plan's MVP 2.9 is its roadmap entry, and [`decisions.md`](../decisions.md) argues it.

## What it is

Derived from `prog-mode`, not from CC Mode.

- A syntax table for `//` and `/* */` comments, `///` doc comments with a face of their own, `////` being an ordinary comment, strings, and backtick raw strings that may span lines, and a `syntax-propertize-function` for char literals.
- Font lock from report §2: reserved words, uppercase-initial names as types and constructors, the name a declaration introduces, qualified names, operators, and the numeric literals of §2.5.
- Indentation to the layout `ern format` writes (report §11.6).
- `imenu`, `beginning-of-defun`, `end-of-defun` and `add-log-current-defun-function`.
- An entry of `compilation-error-regexp-alist` for `file:line:col: message`, which takes a file name with a space in it.
- `auto-mode-alist` for `.ern`.
- `ernest-format-buffer`, which lays out the buffer with `ern format -` (report §11.6). It replaces only the white space that differs, so point, the mark and every window stay on their text. A buffer that does not parse is left as it is, and the diagnostic is shown in the buffer `*ern format*`, naming the buffer's file, or the buffer where it visits none, where the formatter names standard input `-`. `ernest-format-on-save-mode` runs it as a buffer is saved and never refuses the save; a formatter that cannot run is reported in `*ern format*` too. `ernest-format-command` names the `ern` it runs, which is otherwise looked for on `exec-path`.

It calls the toolchain only to lay out a buffer; the compiler is `M-x compile`'s.

## What it leaves to the user

A major mode sets buffer-local variables and turns nothing on. `fill-column` is 100 and `indent-tabs-mode` is nil, so the mode's own indentation writes no tab. A tab pasted in, or a line past 100 characters, is shown only by what the user enables, and the README and the header give the lines that show both. `ern format`, which the header's line runs on save, replaces a tab between tokens and keeps one inside a string or a comment. `no_tab_test` and `line_length_test` in `test/ern_style_tests.erl` hold the repository to both rules.

An Emacs started from a desktop menu has the login session's `PATH`, not the one a shell's startup file sets, so the header's line that names `ern` by its path is the sure way to find it.

## How it is judged

Eight tests under `editors/emacs/test/`, which `make test-emacs` runs, or `make test-emacs EMACS=path` under another Emacs. Each prints what it measured.

| Test | What must hold |
| --- | --- |
| `lint.el` | the mode byte-compiles and passes `checkdoc` without a warning |
| `reindent.el` | every `.ern` source in the repository, which `ern format` has laid out, reindents unchanged |
| `flatten.el` | the same sources, every line outside a string or a comment moved to column zero, reindent to what they were, so no line's place depends on the indentation it has |
| `typing.el` | the same sources, cut every 25 lines (`STEP` sets it), keep every line above the cut, but one whose place is read from what follows the cut: a comment ending the cut, and the contents of a brace in a bracket's first item, which align with the bracket's items where a further item follows |
| `broken.el` over `broken/` | each half-typed buffer, written to report §11.6's layout by hand, keeps its indentation, and a fresh line at its end takes the column a person expects |
| `color.el` | one check for each kind of face, and what must not be painted |
| `editing.el` | `imenu`, declaration movement, the diagnostic regexp |
| `format.el` | a buffer is laid out with point on its token; `shell.ern`, every line moved to column zero, comes back as it was, point and mark in place; a buffer that does not parse is left as typed and its diagnostic names it; a formatter's text that differs beyond white space is refused; the header's line lays out a buffer as it is saved, and a buffer that does not parse, or an `ern` that is not there, is saved as typed, and `*ern format*` says why |

The mode restates two of the language's tables, and `test/ern_style_tests.erl` holds each to its source. `emacs_mode_mirrors_the_lexer_test` checks that the reserved words are the lexer's, §2.4's but `true` and `false`, which the mode paints as constants, and that every operator the mode paints is one of the lexer's symbols. `emacs_mode_mirrors_the_parser_test` holds the mode's table of how tightly each binary operator binds (report §2.6), which places a line an operator opens, equal to the parser's.

