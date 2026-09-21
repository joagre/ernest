Ernest is the functional language for concurrent programs designed in this repository: two concepts, pure functions with Hindley–Milner types and processes with typed mailboxes. `ernest_report.md` is the normative document and Appendix A is its grammar; the toolchain is Erlang/OTP 29 (`ernc` compiles, `ern` runs), source files end in `.ern`, and `docs/style.md` sets the style for both languages. What I want now is **an Emacs major mode for Ernest**, so that `.ern` files are edited with highlighting, indentation and jump-to-error instead of in `fundamental-mode`.

Write it as `ernest-mode` in `editor/emacs/ernest-mode.el`, derived from `prog-mode` and not from `cc-mode`: Ernest is expression-structured (`fn f(x : Int) -> Int = expr`, `match e { P -> e | P -> e }`, `{ let x = 1; e }` where `;` sequences rather than terminates), and CC Mode's engine assumes C's statements and declarations.

Scope for this step:
- syntax table: `//` and `/* */` comments, `///` doc comments with a face of their own, `"` strings, backtick raw strings that may span lines, and a `syntax-propertize-function` for char literals (`'a'`, `'\n'`, `'\u{...}'`) so an apostrophe in prose cannot unbalance a buffer;
- font-lock from the report's lexical rules (§2): reserved words, uppercase-initial names as types and constructors, lowercase as values, qualified names such as `Net.Http.parse`, operators, and the numeric literals of §2.5 with their based forms and digit separators;
- indentation: four spaces, no tabs, `fill-column` 100, `match` and `receive` arms led by `|`, bodies after `->` and `=`. Keep it simple, and add no alignment padding of `->`, `=` or trailing comments, which `docs/style.md` forbids;
- `compilation-error-regexp-alist` for `file:line:col: message`, so `M-x compile` over `ernc` jumps to the diagnostic;
- `auto-mode-alist` for `.ern`.

Not in this step: a `comint` mode over `ern --shell`, and completion.

Rules that apply. The report does not change; this is a tool, not the language. The reserved-word and operator lists restate Appendix A, so add a test keeping them equal to the lexer's, as the other mirror tests do — a restatement without one is a wart. `docs/style.md` covers Erlang, Python and Ernest but not Elisp: add the one rule that file needs (lines ≤ 100, no tabs) and say the mode is the only Elisp in the repository. Put the file in the README's layout section and the item in the plan with its date.

Before writing code, answer two things. Where does this belong in the roadmap — a detour now, or an item after MVP 2.6? And would you rather write a tree-sitter grammar with `ernest-ts-mode`, given that Appendix A is already complete EBNF and §0.4 keeps the grammar recursive-descent-shaped with bounded lookahead? If tree-sitter is the better long-run answer, say what the plain mode costs in the meantime.
