# The Emacs mode

`ernest-mode` edits `.ern` files. It is in `emacs/`, the only Elisp in the repository, and
its own header says how to load it. It needs Emacs 29 or later, the first with
`font-lock-operator-face`, and its tests pass on Emacs 29.3 and 31.1. The roadmap entry is MVP 2.9 in
[`implementation_plan.md`](implementation_plan.md); the arguments that settled it are in
[`decisions.md`](decisions.md).

## What it is

Derived from `prog-mode`, not from CC Mode.

- A syntax table for `//` and `/* */` comments, `///` doc comments with a face of their own, `////` being an ordinary comment,
  strings, backtick raw strings that may span lines, and a `syntax-propertize-function` for
  char literals.
- Font lock from report §2: reserved words, uppercase-initial names as types and
  constructors, the name a declaration introduces, qualified names, operators, and the
  numeric literals of §2.5.
- Indentation to [`style.md`](style.md), which owns it.
- `imenu`, `beginning-of-defun`, `end-of-defun`, `add-log-current-defun-function`.
- `compilation-error-regexp-alist` for `file:line:col: message`, since Emacs's own `gnu`
  entry refuses a file name with a space in it.
- `auto-mode-alist` for `.ern`.

It never calls the compiler; `M-x compile` does.

## What it leaves to the user

A major mode sets buffer-local variables and turns nothing else on. `fill-column` is 100 and
`indent-tabs-mode` is nil, so the mode's own indentation writes no tab. A tab pasted in, or a
line past 100 characters, is shown only by what the user enables. These lines in an init
file show both:

```elisp
(add-hook 'ernest-mode-hook #'display-fill-column-indicator-mode)
(add-hook 'ernest-mode-hook
          (lambda ()
            (setq-local whitespace-style '(face tabs lines-tail)
                        whitespace-line-column nil)
            (whitespace-mode)))
```

The indicator stands at `fill-column`. `whitespace-line-column` nil makes `whitespace-mode`
mark lines past `fill-column` rather than past its default of 80. Nothing converts a tab on
save: `untabify` would also rewrite a tab inside a string, which is part of the string's
value (report §2.5). `no_tab_test` and `line_length_test` in `test/ern_style_tests.erl`
enforce both rules in the repository.

The mode's reserved words and operators restate Appendix A, so
`emacs_mode_mirrors_the_lexer_test` in `test/ern_style_tests.erl` checks them against the
lexer: the reserved words are the lexer's, and every operator the mode paints is one of the
lexer's symbols.

## How it is judged

Seven tests under `emacs/test/`. `make test-emacs` runs them and `make test` runs them last;
a machine without Emacs skips them. `make test-emacs EMACS=path` runs them under another
Emacs. Each prints what it measured.

| Test | What must hold |
| --- | --- |
| `lint.el` | the mode byte-compiles and passes `checkdoc` without a warning, as the Erlang builds with `-Werror` |
| `reindent.el` | every `.ern` source in the repository reindents unchanged |
| `flatten.el` | the same sources, every line moved to column zero, reindent to what they were, so no line's place depends on the indentation it has |
| `typing.el` | the same sources, cut every 25 lines (`STEP` sets it), keep every line above the cut |
| `broken.el` over `broken/` | each half-typed buffer keeps its indentation, and a fresh line at its end takes the column a person expects |
| `colour.el` | one check for each kind of face, and what must not be painted |
| `editing.el` | `imenu`, declaration movement, the diagnostic regexp |

`reindent.el` and `flatten.el` cannot find a defect in a line the mode itself placed. A case in `broken/`,
written to [`style.md`](style.md) by hand, can.

## What it does not do

Stated so that nobody looks for it.

- **A constructor is painted as a type.** Both are uppercase and the difference is
  positional.
- **Nothing knows the language, only its shape.** No `eldoc`, no `xref`, no completion in
  the buffer, no jump to a definition in another module. `imenu`, `C-M-a` and `C-M-e` work
  inside the file. What a name means is `M-x compile`'s answer.
- **No `comint` mode over `ern shell`**, no folding, no `prettify-symbols`, and no keymap
  of its own: it takes `prog-mode`'s.
- **It is installed by path, not as a package.** No `Version:` or `Package-Requires:`
  headers, and it is not on MELPA.
- **Indentation is line by line.** There is no `indent-region-function`.
- **It never changes the buffer on its own.** Nothing runs on save, and no minor mode is
  turned on.
