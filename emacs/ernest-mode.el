;;; ernest-mode.el --- Major mode for Ernest  -*- lexical-binding: t; -*-

;;; Commentary:

;; The mode for `.ern' files.  docs/emacs_mode.md designs it, and says
;; what it does and what it does not do.
;;
;; A buffer being edited is broken most of the time, so colouring and
;; indentation are the buffer's own work.  The toolchain is reached in
;; two places: `ernest-format-buffer' runs `ern format', and `M-x
;; compile' the compiler, whose diagnostics
;; `compilation-error-regexp-alist' takes.

;;; Installation:

;; `make install' puts this file in `share/emacs/site-lisp' under its
;; prefix, which an Emacs built for that prefix has on its `load-path'.
;; Another Emacs, and one that loads the mode from a checkout, is given
;; the directory that holds it:
;;
;;     (add-to-list 'load-path "~/src/ernest/emacs")
;;
;; These two lines in your init file load the mode when a `.ern' file is
;; opened:
;;
;;     (autoload 'ernest-mode "ernest-mode" "Major mode for Ernest." t)
;;     (add-to-list 'auto-mode-alist '("\\.ern\\'" . ernest-mode))
;;
;; This line lays out each Ernest buffer as it is saved, with `ern
;; format':
;;
;;     (add-hook 'ernest-mode-hook #'ernest-format-on-save-mode)
;;
;; `ern' is looked for on `exec-path', where an Emacs started from a
;; desktop menu may not have the repository's `bin/'.  This line names it:
;;
;;     (setq ernest-format-command (expand-file-name "~/src/ernest/bin/ern"))

;;; Code:

(require 'compile)

(defgroup ernest nil
  "Editing Ernest source."
  :group 'languages)

(defcustom ernest-indent-offset 4
  "Spaces per level.  The style guide says four, and no tabs."
  :type 'integer
  :group 'ernest)

(defcustom ernest-clause-offset 2
  "Spaces before a `|' that leads a clause, so the clause aligns with the first."
  :type 'integer
  :group 'ernest)

(defcustom ernest-format-command "ern"
  "The `ern' to run: a name on the variable `exec-path', or a file."
  :type 'string
  :group 'ernest)

;;; Words and operators.  These restate Appendix A, so
;;; `emacs_mode_mirrors_the_lexer_test' in test/ern_style_tests.erl
;;; checks them against the lexer's.

(defconst ernest-reserved-words
  '("type" "abstract" "with" "foreign" "match" "when" "receive" "after" "or"
    "as" "if" "then" "else" "fn" "let" "export")
  "Ernest's reserved words, report §2.4, but `true' and `false'.")

(defconst ernest-operators
  '("->" "<-" "::" "<>" "|>" "==" "!=" "<=" ">=" "&&" "||" "..")
  "The operators font lock paints, a subset of Appendix A's symbols.")

(defconst ernest--precedence
  '(("*" . 7) ("/" . 7) ("%" . 7) ("+" . 6) ("-" . 6) ("<>" . 6) ("::" . 5)
    ("==" . 4) ("!=" . 4) ("<" . 4) ("<=" . 4) (">" . 4) (">=" . 4)
    ("&&" . 3) ("||" . 2) ("|>" . 1))
  "How tightly each binary operator binds, higher tighter (report section 2.6).
It restates the parser's table, which `emacs_mode_mirrors_the_parser_test'
in test/ern_style_tests.erl checks.")

(defconst ernest-constants
  '("true" "false")
  "The literals that read as words (report section 2.5).")

(defconst ernest--userop-re "\\(?:<>\\|[-+*/%]\\)"
  "An operator a type may declare, `userop' in report section 2.6.")

(defconst ernest--decl-name-re
  (concat "\\(?:[a-z_][A-Za-z0-9_]*"
          "\\|[A-Z][A-Za-z0-9_]*\\.\\(?:[a-z_][A-Za-z0-9_]*\\|" ernest--userop-re "\\)\\)")
  "The name a `fn' or a `let' declares, `DeclName' in Appendix A.
It is an identifier, or a type name, a dot, and an identifier or an
operator: `merge', `Int.+', `Distance.<>'.")

;;; Syntax

(defvar ernest-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; `//' to end of line, `/* */' nesting (report section 2.2)
    (modify-syntax-entry ?/ ". 124" table)
    (modify-syntax-entry ?* ". 23bn" table)
    (modify-syntax-entry ?\n ">" table)
    ;; a string, and a raw string that may span lines
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?` "\"" table)
    (modify-syntax-entry ?\\ "\\" table)
    ;; an apostrophe is punctuation until `ernest-syntax-propertize'
    ;; makes a char literal of it, so prose cannot unbalance a buffer
    (modify-syntax-entry ?' "." table)
    (modify-syntax-entry ?_ "_" table)
    (dolist (c '(?+ ?- ?< ?> ?= ?! ?& ?| ?: ?%))
      (modify-syntax-entry c "." table))
    table)
  "Syntax table for `ernest-mode'.")

(defun ernest-syntax-propertize (start end)
  "Give char literals and raw strings between START and END their syntax.
An apostrophe is punctuation until it is found to quote a char literal,
so prose in a comment cannot unbalance a buffer.  A quote marked inside
a comment or a string is harmless: a scanner already in one ignores it.
A backslash in a raw string is punctuation, since a raw string has no
escapes (report section 2.5)."
  (funcall
   (syntax-propertize-rules
    ;; a char literal, report section 2.5: 'a', '\n', '\u{1b}'
    ("\\('\\)\\(?:\\\\u{[[:xdigit:]]+}\\|\\\\.\\|[^'\\\\\n]\\)\\('\\)"
     (1 "\"") (2 "\""))
    ("\\\\"
     (0 (when (eq (nth 3 (save-excursion
                            (save-match-data (syntax-ppss (match-beginning 0)))))
                  ?`)
          (string-to-syntax ".")))))
   start end))

;;; Colour

(defface ernest-doc-comment-face
  '((t :inherit font-lock-doc-face))
  "Face for `///' doc comments."
  :group 'ernest)

(defun ernest-syntactic-face (state)
  "The face for the string or comment STATE describes.
A comment opening with `///', and no fourth slash, is a doc comment
where nothing stands before it on its line; `////' opens an ordinary
one, and a `///' after code is an error (report section 2.2)."
  (cond ((nth 3 state) 'font-lock-string-face)
        ((nth 4 state)
         (save-excursion
           (goto-char (nth 8 state))
           (if (and (looking-at-p "///\\(?:[^/]\\|$\\)")
                    (progn (skip-chars-backward " \t") (bolp)))
               'ernest-doc-comment-face
             'font-lock-comment-face)))))

(defconst ernest-font-lock-keywords
  (let ((upper "[A-Z][A-Za-z0-9_]*")
        (lower "[a-z_][A-Za-z0-9_]*"))
    `(;; a declaration's name, so the eye finds definitions; in `Int.+'
      ;; the type is painted as a type, below
      (,(concat "\\_<fn\\_>[ \t]+\\(?:" upper "\\.\\)?\\(" lower "\\|"
                ernest--userop-re "\\)")
       1 'font-lock-function-name-face)
      (,(concat "\\_<let\\_>[ \t]+\\(?:" upper "\\.\\)?\\(" lower "\\)")
       1 'font-lock-variable-name-face)
      (,(concat "\\_<\\(?:abstract[ \t]+\\|foreign[ \t]+\\)?type\\_>[ \t]+\\("
                upper "\\)")
       1 'font-lock-type-face)
      ;; reserved words and the two word literals
      (,(regexp-opt ernest-reserved-words 'symbols) . 'font-lock-keyword-face)
      (,(regexp-opt ernest-constants 'symbols) . 'font-lock-constant-face)
      ;; a qualified name: every uppercase segment is a namespace or a type
      (,(concat "\\_<" upper "\\(?:\\." upper "\\)*") . 'font-lock-type-face)
      ;; the numeric literals of section 2.5, with digit separators
      ("\\_<0x[0-9a-fA-F_]+\\_>" . 'font-lock-constant-face)
      ("\\_<0o[0-7_]+\\_>" . 'font-lock-constant-face)
      ("\\_<0b[01_]+\\_>" . 'font-lock-constant-face)
      ("\\_<[0-9][0-9_]*\\(?:\\.[0-9][0-9_]*\\)?\\(?:[eE][-+]?[0-9]+\\)?\\_>"
       . 'font-lock-constant-face)
      ;; the operators a reader looks for
      (,(regexp-opt ernest-operators) . 'font-lock-operator-face)))
  "Font-lock keywords for `ernest-mode'.")

;;; Indentation
;;
;; The line is placed from three things: the bracket that encloses it,
;; which `syntax-ppss' knows even where the buffer below is broken; the
;; line's own first token; and the previous line's last token.  Nothing
;; is parsed, so a half-typed buffer is placed as well as a whole one,
;; and a line whose place cannot be decided keeps the indentation it has.

(defconst ernest--body-opener-re
  (concat "\\(?:->\\|<-\\|[^=<>!+*/%-]="
          "\\|\\_<then\\_>\\|\\_<else\\_>\\)")
  "What a line ends with when a body follows on the next line.")

(defconst ernest--continuation-re
  (concat "\\(?:[-+*%=]\\|/[^/*]\\|<[^<]\\|>[^>]\\|!=\\|&&\\|||\\||>\\|::"
          "\\|\\_<with\\_>\\)")
  "What a line opens with when it carries the line above on.
That is a binary operator of report section 2.6, or the `->', `=' or
`with' of a signature broken over lines.  `//' and `/*' open comments,
and `<<' and `>>' are brackets.")

(defun ernest--line-empty-p ()
  "Whether the current line is only whitespace."
  (save-excursion
    (beginning-of-line)
    (looking-at-p "[ \t]*$")))

(defun ernest--clause-bar-p ()
  "Whether point is on a `|' that leads a clause, and not on `||' or `|>'."
  (and (eq (char-after) ?|)
       (not (memq (char-after (1+ (point))) '(?| ?>)))
       (not (eq (char-before) ?|))))

(defun ernest--line-base ()
  "The column of this line's content, a leading clause bar skipped.
A brace opened on a clause's line belongs to the clause and not to the
bar, so `| x -> {' anchors its body at `x'."
  (save-excursion
    (back-to-indentation)
    (when (ernest--clause-bar-p)
      (forward-char 1)
      (skip-chars-forward " \t"))
    (current-column)))

(defun ernest--code-line-end ()
  "The end of the code on this line, a trailing comment left out."
  (save-excursion
    (let* ((start (line-beginning-position))
           (limit (line-end-position))
           (state (syntax-ppss start))
           (end limit))
      ;; `parse-partial-sexp' stops just inside the first comment to open,
      ;; and a string on the way is walked past
      (setq state (parse-partial-sexp start limit nil nil state t))
      (when (nth 4 state)
        (setq end (nth 8 state)))
      (goto-char end)
      (skip-chars-backward " \t")
      (point))))

(defun ernest--previous-code-line ()
  "Move to the previous line holding code, and return non-nil when there is one."
  (let ((found nil))
    (while (and (not found) (zerop (forward-line -1)))
      (unless (or (ernest--line-empty-p)
                  (save-excursion
                    (back-to-indentation)
                    (or (looking-at-p "//")
                        (nth 8 (syntax-ppss (point))))))
        (setq found t)))
    found))

(defun ernest--next-code-line ()
  "Move to the next line holding code, and return non-nil when there is one."
  (let ((found nil))
    (while (and (not found) (zerop (forward-line 1)))
      (unless (or (ernest--line-empty-p)
                  (save-excursion
                    (back-to-indentation)
                    (or (looking-at-p "//")
                        (nth 8 (syntax-ppss (point))))))
        (setq found t)))
    found))

(defun ernest--closer-p ()
  "Whether this line opens with a closing bracket."
  (save-excursion
    (back-to-indentation)
    (memq (char-after) '(?\) ?\] ?\}))))

(defun ernest--after-separator-p ()
  "Whether the code line above ends where a new element begins.
After `,', `;' or an opening bracket a leading `-' is a negation, and
the line starts an element rather than carrying the line above on."
  (save-excursion
    (and (ernest--previous-code-line)
         (let ((end (ernest--code-line-end)))
           (and (> end (line-beginning-position))
                (memq (char-before end) '(?, ?\; ?\( ?\[ ?\{)))))))

(defun ernest--opens-body-p ()
  "Whether the code on this line ends where a body or a continuation follows."
  (let ((end (ernest--code-line-end)))
    (and (> end (line-beginning-position))
         (save-excursion
           (goto-char end)
           (looking-back ernest--body-opener-re (max (point-min) (- end 5)))))))

(defconst ernest--declaration-re
  "\\(?:export[ \t]+\\)?\\(?:foreign[ \t]+\\|abstract[ \t]+\\)*\\(?:fn\\|type\\|let\\)\\_>"
  "How a declaration opens, in column zero (report section 3).")

(defun ernest--head-ended-p (start end)
  "Whether the `=' that ends a declaration's head lies between START and END."
  (save-excursion
    (goto-char start)
    (let ((found nil) (depth (car (syntax-ppss start))))
      (while (and (not found) (re-search-forward "[^=<>!+*/%-]=[^=]" end t))
        (goto-char (1- (point)))
        (let ((state (save-excursion (syntax-ppss (1- (point))))))
          (when (and (not (nth 8 state)) (= (car state) depth))
            (setq found t))))
      found)))

(defun ernest--in-head-p ()
  "Whether this line carries a declaration's head on, its `=' not yet reached.
A signature broken over lines is the only place this happens."
  (save-excursion
    (beginning-of-line)
    (let ((here (point))
          (start (ernest--declaration-start)))
      (and (< start here)
           (save-excursion
             (goto-char start)
             (looking-at-p ernest--declaration-re))
           (not (ernest--head-ended-p start here))))))

(defun ernest--operator-line-p ()
  "Whether this line opens with an operator that carries the line above on."
  (save-excursion
    (back-to-indentation)
    (and (looking-at-p ernest--continuation-re)
         (not (ernest--clause-bar-p))
         (not (ernest--after-separator-p)))))

(defun ernest--continues-p ()
  "Whether this line carries the line above on rather than starting something.
A line opening with an operator carries on, and so does a declaration's
head broken over lines, but for an item of a bracket that aligns its
items.  A body under `=' or `then' does not: it is a new logical line,
one step in."
  (or (ernest--operator-line-p)
      (and (ernest--in-head-p)
           (save-excursion
             (back-to-indentation)
             (let ((open (nth 1 (syntax-ppss))))
               (not (and open (ernest--first-item-column open))))))))

(defun ernest--declaration-p ()
  "Whether point, at a line's first token, opens a declaration.
`fn' before a bracket opens a lambda, not a declaration."
  (and (looking-at-p ernest--declaration-re)
       (not (looking-at-p "fn[ \t]*("))))

(defun ernest--anchor-base (&optional carried open)
  "The base column of the logical line point is on.
A declaration's head broken over lines is one logical line, so its body
is not carried out to the right.  With CARRIED, so is a line an operator
carries on, which puts every such line at one step; a bracket opened on
one steps in from where it stands.  With OPEN, the walk stops at the
line OPEN opened on, where no construct inside it can have begun before,
and a bracket that aligns its items gives the column of its first item,
which stands as if it began the line."
  (save-excursion
    (let ((seen 0))
      (while (and (not (ernest--opened-here-p open))
                  (if carried
                      (or (ernest--operator-line-p) (ernest--in-head-p))
                    (ernest--in-head-p))
                  (< seen 100)                  ; a broken buffer ends the walk
                  (save-excursion (ernest--previous-code-line)))
        (setq seen (1+ seen))
        (ernest--previous-code-line))
      (or (and (ernest--opened-here-p open)
               (ernest--first-item-column open))
          (ernest--line-base)))))

(defun ernest--carried-base (open)
  "The base column of the expression the operator line point is on carries on.
The walk goes back past the lines an operator binding at least as tightly
opens, which carry the same expression on, and stops at the line an
operator binding more loosely opens, whose operand this line carries on:
`&& x' above `== y' begins the operand `x == y'.  It stops, too, at the
line OPEN opened on."
  (let ((binds (ernest--precedence-here))
        (seen 0))
    (ernest--expression-line open)
    (while (and (not (ernest--opened-here-p open))
                (or (and (ernest--operator-line-p) (>= (ernest--precedence-here) binds))
                    (ernest--in-head-p))
                (< seen 100)                    ; a broken buffer ends the walk
                (save-excursion (ernest--previous-code-line)))
      (setq seen (1+ seen))
      (ernest--expression-line open))
    (or (and (ernest--opened-here-p open) (ernest--first-item-column open))
        (ernest--line-base))))

(defun ernest--precedence-here ()
  "How tightly the operator this line opens with binds, or 0 for none."
  (save-excursion
    (back-to-indentation)
    (let ((best 0) (length 0))
      (dolist (entry ernest--precedence best)
        (when (and (> (length (car entry)) length)
                   (looking-at-p (regexp-quote (car entry))))
          (setq best (cdr entry)
                length (length (car entry))))))))

(defun ernest--opened-here-p (open)
  "Whether the bracket at OPEN opened on the line point is on."
  (and open (<= (line-beginning-position) open (line-end-position))))

(defun ernest--expression-line (open)
  "Move to the line the expression a line inside OPEN carries on begins on.
That is the previous code line, or, where that line begins inside a
bracket deeper than OPEN, the line that bracket opened on."
  (ernest--previous-code-line)
  (ernest--climb open))

(defun ernest--climb (open)
  "Move to the line the construct on this line began on, inside OPEN.
Where the line begins inside a bracket deeper than OPEN, that bracket
closed on it, and what it closes began on the line the bracket opened on."
  (let ((seen 0) inner)
    (while (and (setq inner (save-excursion (back-to-indentation) (nth 1 (syntax-ppss))))
                (or (null open) (> inner open))
                (< seen 100))                   ; a broken buffer ends the walk
      (setq seen (1+ seen))
      (goto-char inner)
      (beginning-of-line))))

(defun ernest--brace-base (brace)
  "The column the contents of the brace at BRACE step in from.
That is the line the construct holding the brace began on, past a
bracket closed before the brace, as a match's scrutinee broken over
lines.  A bracket opened on that line whose first item holds the brace,
and which holds a further item, aligns its items, and the brace steps
from its first item; one whose last item holds the brace hugs it, and
the brace steps from the line.  Where nothing follows the brace yet it
is taken as hugged."
  (save-excursion
    (goto-char brace)
    (let ((open (nth 1 (syntax-ppss brace)))
          (inner brace)
          (base nil))
      (ernest--climb open)
      (while (and (null base) open (ernest--opened-here-p open))
        (if (and (ernest--first-item-p open inner) (ernest--more-items-p open inner))
            (setq base (ernest--first-item-column open)))
        (setq inner open
              open (nth 1 (syntax-ppss open))))
      (or base (ernest--anchor-base)))))

(defun ernest--first-item-p (open pos)
  "Whether POS lies in the first item of the bracket at OPEN."
  (save-excursion
    (let ((found nil))
      (goto-char (1+ open))
      (while (and (not found) (re-search-forward "," pos t))
        (let ((state (save-excursion (syntax-ppss (match-beginning 0)))))
          (when (and (not (nth 8 state)) (eql (nth 1 state) open))
            (setq found t))))
      (not found))))

(defun ernest--more-items-p (open pos)
  "Whether the bracket at OPEN holds a further item after POS."
  (save-excursion
    (let ((found nil)
          (end (or (ignore-errors (scan-lists open 1 0)) (point-max))))
      (goto-char pos)
      (while (and (not found) (re-search-forward "," end t))
        (let ((state (save-excursion (syntax-ppss (match-beginning 0)))))
          (when (and (not (nth 8 state)) (eql (nth 1 state) open))
            (setq found t))))
      found)))

(defun ernest--first-item-column (open)
  "The column of the first item after the bracket at OPEN, or nil.
A parenthesis or a square bracket whose first item follows it on its
line aligns its items under that one.  A brace, and a bracket that ends
its line, align nothing."
  (save-excursion
    (goto-char open)
    (when (memq (char-after) '(?\( ?\[))
      (forward-char 1)
      (skip-chars-forward " \t")
      (unless (or (eolp) (looking-at-p "/[/*]"))
        (current-column)))))

(defun ernest--content-column (open)
  "The column ordinary content sits at inside the bracket at OPEN.
Under the bracket's first item when it aligns its items, and otherwise a
step in from the line the bracket opened on.  With OPEN nil it is a
declaration's body, which is a step in from the declaration's own line."
  (if open
      (or (ernest--first-item-column open)
          (if (eq (char-after open) ?{)
              (+ (ernest--brace-base open) ernest-indent-offset)
            (save-excursion
              (goto-char open)
              (+ (ernest--anchor-base) ernest-indent-offset))))
    (let ((start (ernest--declaration-start)))
      (if (< start (line-beginning-position))
          ernest-indent-offset
        0))))

(defun ernest--declaration-start ()
  "The start of the declaration the line point is on belongs to.
A line opening a declaration outside every bracket starts one itself.
Otherwise the nearest line above whose code begins in column zero does,
which is the one thing a broken buffer still says plainly; a line of a
string or a comment there does not.  The line's own indentation is not
read, so a line typed in column zero is placed as any other."
  (save-excursion
    (back-to-indentation)
    (if (and (zerop (car (syntax-ppss))) (ernest--declaration-p))
        (line-beginning-position)
      (beginning-of-line)
      (while (and (not (bobp))
                  (progn (forward-line -1)
                         (or (not (looking-at-p "[^ \t\n]"))
                             (nth 8 (save-excursion (syntax-ppss (point))))))))
      (point))))

(defun ernest--matching-if-base (limit depth word)
  "The base column of the `if' this WORD belongs to, or nil.
WORD is \"then\" or \"else\".  LIMIT bounds the search and DEPTH is the
bracket depth WORD sits at; an `if' deeper in brackets, or in a string
or a comment, is skipped, and so is one an earlier WORD has taken."
  (save-excursion
    (let ((pending 0) (base nil)
          (re (concat "\\_<\\(if\\|" word "\\)\\_>")))
      (while (and (null base) (re-search-backward re limit t))
        ;; the word is read before `syntax-ppss', which may propertize
        ;; and so change the match data
        (let* ((found (match-string 1))
               (state (save-excursion (syntax-ppss (point)))))
          (unless (or (nth 8 state) (/= (car state) depth))
            (if (equal found word)
                (setq pending (1+ pending))
              (if (> pending 0)
                  (setq pending (1- pending))
                (setq base (ernest--anchor-base nil (nth 1 state))))))))
      base)))

(defun ernest-calculate-indent ()
  "The column this line belongs at, or nil when it cannot be decided.
Case decides between a word and a constructor, `let' and `Let', so the
regexps here match it whatever `case-fold-search' the user has."
  (save-excursion
    (back-to-indentation)
    (let* ((case-fold-search nil)
           (state (syntax-ppss (point)))
           (open (nth 1 state))
           (first (char-after))
           (content (ernest--content-column open)))
      (cond
       ;; inside a string, including a raw one, or a block comment: the
       ;; line's indentation is the author's business
       ((nth 3 state) nil)
       ((nth 4 state) nil)
       ;; a comment goes where the code it introduces goes; before a
       ;; closing bracket it stays with the content it follows
       ((and (looking-at-p "//")
             (save-excursion
               (and (ernest--next-code-line) (not (ernest--closer-p)))))
        (save-excursion (ernest--next-code-line) (ernest-calculate-indent)))
       ;; a declaration begins in column zero
       ((and (null open) (ernest--declaration-p)) 0)
       ;; a closing bracket returns to the line its opener began on
       ((and open (eq first ?\}))
        (ernest--brace-base open))
       ((and open (memq first '(?\) ?\])))
        (save-excursion (goto-char open) (ernest--anchor-base)))
       ;; a clause's bar sits two spaces to the left of its arms
       ((ernest--clause-bar-p)
        (max 0 (- content ernest-clause-offset)))
       ;; a `then' or an `else' returns to its `if'
       ((looking-at "\\_<\\(then\\|else\\)\\_>")
        (let ((word (match-string 1)))
          (or (ernest--matching-if-base (or open (ernest--declaration-start))
                                        (car state) word)
              content)))
       ;; an operator or a broken head carries the line above on, a step
       ;; in from where that line's expression begins
       ((ernest--continues-p)
        (+ (save-excursion (ernest--carried-base open)) ernest-indent-offset))
       ;; a body opened at the end of the line before, a step in from the
       ;; line its construct began on
       ((save-excursion
          (and (ernest--previous-code-line)
               (ernest--opens-body-p)))
        (+ (save-excursion (ernest--expression-line open) (ernest--anchor-base t open))
           ernest-indent-offset))
       ;; inside a bracket, its content; outside every bracket, with no
       ;; body or continuation pending, the next declaration
       (open content)
       (t 0)))))

(defun ernest-indent-line ()
  "Indent the current line as Ernest.
A line whose place cannot be decided keeps the indentation it has."
  (interactive)
  (let ((indent (ernest-calculate-indent)))
    (when indent
      ;; point in the indentation ends up at the first word, as everywhere
      (if (<= (current-column) (current-indentation))
          (indent-line-to indent)
        (save-excursion (indent-line-to indent))))))

;;; Moving over declarations

(defun ernest--next-declaration (backward)
  "Move to the next line in column zero that opens a declaration.
Move back instead when BACKWARD, and return non-nil when there is one.
A line inside a string or a comment opens none, though a raw string's
line may begin in column zero with `fn'."
  (let ((re (concat "^" ernest--declaration-re))
        (case-fold-search nil)
        (found nil))
    (while (and (not found)
                (if backward
                    (re-search-backward re nil 'move)
                  (re-search-forward re nil 'move)))
      (goto-char (match-beginning 0))
      (if (and (not (nth 8 (save-excursion (syntax-ppss (point)))))
               (ernest--declaration-p))
          (setq found t)
        (unless backward (end-of-line))))
    found))

(defun ernest-beginning-of-defun (&optional count)
  "Move back to the start of a declaration, COUNT of them.
A negative COUNT moves forward.  Return non-nil when every one was found."
  (interactive "p")
  (let ((count (or count 1))
        (found t))
    (if (< count 0)
        (dotimes (_ (- count))
          (end-of-line)
          (unless (ernest--next-declaration nil)
            (setq found nil)))
      (dotimes (_ count)
        (unless (ernest--next-declaration t)
          (setq found nil))))
    found))

(defun ernest-end-of-defun ()
  "Move past the end of the declaration point is at.
A doc block or a blank line before the next declaration belongs to it,
not to this one."
  (forward-line 1)
  (if (not (ernest--next-declaration nil))
      (goto-char (point-max))
    (while (and (not (bobp))
                (save-excursion
                  (forward-line -1)
                  (or (ernest--line-empty-p)
                      (progn (back-to-indentation) (looking-at-p "//")))))
      (forward-line -1))))

(defun ernest-current-defun ()
  "The name of the declaration point is in, or nil.
`add-log' and `which-function-mode' ask for this."
  (save-excursion
    (ernest-beginning-of-defun)
    (when (let ((case-fold-search nil))
            (looking-at (concat "^" ernest--declaration-re "[ \t]+\\("
                                ernest--decl-name-re "\\|[A-Z][A-Za-z0-9_]*\\)")))
      (match-string-no-properties 1))))

(defconst ernest-imenu-generic-expression
  (let ((exported "^\\(?:export[ \t]+\\)?")
        (name (concat "\\(" ernest--decl-name-re "\\)"))
        (upper "\\([A-Z][A-Za-z0-9_]*\\)"))
    `(("Function" ,(concat exported "\\(?:foreign[ \t]+\\)?fn[ \t]+" name) 1)
      ("Type" ,(concat exported "\\(?:abstract[ \t]+\\|foreign[ \t]+\\)?type[ \t]+" upper) 1)
      ("Value" ,(concat exported "let[ \t]+" name) 1)))
  "What `imenu' offers: the declarations, by kind.")

;;; Formatting.  `ern format -' lays out the buffer from standard input,
;;; since a buffer being saved is not yet its file (report section 11.6).

(defconst ernest--format-errors "*ern format*"
  "The buffer that shows why the buffer last laid out was not.")

(defconst ernest--format-space " \t\r\n"
  "The white space between tokens, all that `ern format' changes.")

(defun ernest-format-buffer ()
  "Lay out the buffer as `ern format' does, keeping point on its text.
Only the white space that differs is replaced, so point, the mark and
every window stay where they were in the text.  A buffer that does not
parse is left as it is, and the formatter's diagnostic is shown in the
buffer `*ern format*'."
  (interactive)
  (let ((out (generate-new-buffer " *ern format output*" t))
        (err (make-temp-file "ern-format"))
        (name (if buffer-file-name
                  (file-name-nondirectory buffer-file-name)
                (buffer-name)))
        (coding-system-for-read 'utf-8)
        (coding-system-for-write 'utf-8))
    (unwind-protect
        (save-restriction
          (widen)
          (if (eql 0 (call-process-region (point-min) (point-max) ernest-format-command
                                          nil (list out err) nil "format" "-"))
              (progn
                (ernest--format-apply out)
                (ernest--format-clear))
            (ernest--format-show (with-temp-buffer
                                   (insert-file-contents err)
                                   (buffer-string))
                                 name default-directory)))
      (kill-buffer out)
      (delete-file err))))

(defun ernest--format-apply (out)
  "Make the buffer's text the text of the buffer OUT, the formatter's.
The two hold the same characters but for white space, so both are
walked together and each run of white space that differs is replaced.
Anything else that differs is an error, and the buffer is left as it
was."
  (let ((word (concat "^" ernest--format-space))
        (edits nil))
    (save-excursion
      (goto-char (point-min))
      (with-current-buffer out (goto-char (point-min)))
      ;; a run of white space, which may differ, then a run of the rest,
      ;; which may not
      (while (let ((start (point))
                   (want (ernest--format-take out ernest--format-space)))
               (skip-chars-forward ernest--format-space)
               (unless (string= (buffer-substring-no-properties start (point)) want)
                 (push (list start (point) want) edits))
               (not (and (eobp) (with-current-buffer out (eobp)))))
        (let* ((here (point))
               (there (with-current-buffer out (point)))
               (run (min (- (save-excursion (skip-chars-forward word) (point)) here)
                         (with-current-buffer out
                           (- (save-excursion (skip-chars-forward word) (point)) there)))))
          (unless (and (> run 0)
                       (eql 0 (compare-buffer-substrings nil here (+ here run)
                                                         out there (+ there run))))
            (error "The formatter changed more than white space at %d" here))
          (forward-char run)
          (with-current-buffer out (forward-char run)))))
    ;; from the last to the first, so each edit's positions still hold
    (save-excursion
      (dolist (edit edits)
        (apply #'ernest--format-replace edit)))))

(defun ernest--format-take (out chars)
  "The run of CHARS at point in the buffer OUT, which point moves past."
  (with-current-buffer out
    (let ((start (point)))
      (skip-chars-forward chars)
      (buffer-substring-no-properties start (point)))))

(defun ernest--format-replace (start end want)
  "Make the white space from START to END WANT, changing only what differs.
What the two share at either end stays, so a line whose indentation
alone changes keeps its line break, and a point after the change stays
on the token after it."
  (let* ((have (buffer-substring-no-properties start end))
         (prefix (1- (abs (compare-strings have nil nil want nil nil))))
         (limit (- (min (length have) (length want)) prefix))
         (suffix 0))
    (while (and (< suffix limit)
                (eq (aref have (- (length have) suffix 1))
                    (aref want (- (length want) suffix 1))))
      (setq suffix (1+ suffix)))
    (goto-char (+ start prefix))
    (delete-region (point) (- end suffix))
    (insert-before-markers (substring want prefix (- (length want) suffix)))))

(defun ernest--format-show (text name directory)
  "Show TEXT, why the buffer NAME in DIRECTORY was not laid out.
It is the formatter's diagnostic, or why the formatter did not run.
The formatter names standard input `-', so NAME takes its place, and
the diagnostic's position can be followed as a compilation's can."
  (let ((errors (get-buffer-create ernest--format-errors)))
    (with-current-buffer errors
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert text)
        (goto-char (point-min))
        (when (looking-at-p "-:")
          (delete-char 1)
          (insert name)))
      (compilation-mode)
      (setq default-directory directory))
    (display-buffer errors)))

(defun ernest--format-clear ()
  "Take away the diagnostic of a buffer not laid out, now that one was."
  (let ((errors (get-buffer ernest--format-errors)))
    (when errors
      (let ((window (get-buffer-window errors)))
        (if window
            (quit-window t window)
          (kill-buffer errors))))))

(defun ernest--format-before-save ()
  "Lay out the buffer as it is saved.  Nothing here refuses the save.
A formatter that cannot run is reported in the buffer `*ern format*',
since a message would be hidden at once by the save's own."
  (condition-case failure
      (ernest-format-buffer)
    (error
     (ernest--format-show (format "Not laid out: %s\n" (error-message-string failure))
                          (buffer-name) default-directory))))

(define-minor-mode ernest-format-on-save-mode
  "Lay out the buffer with `ernest-format-buffer' each time it is saved.
A buffer that does not parse is saved as it was typed."
  :group 'ernest
  (if ernest-format-on-save-mode
      (add-hook 'before-save-hook #'ernest--format-before-save nil t)
    (remove-hook 'before-save-hook #'ernest--format-before-save t)))

;;; The mode

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.ern\\'" . ernest-mode))

;;;###autoload
(define-derived-mode ernest-mode prog-mode "Ernest"
  "Major mode for Ernest source."
  :syntax-table ernest-mode-syntax-table
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "//+[ \t]*")
  (setq-local font-lock-defaults
              '(ernest-font-lock-keywords nil nil nil nil
                (font-lock-syntactic-face-function . ernest-syntactic-face)))
  (setq-local syntax-propertize-function #'ernest-syntax-propertize)
  (setq-local indent-line-function #'ernest-indent-line)
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width ernest-indent-offset)
  (setq-local fill-column 100)
  ;; `>' places a line again once `|' has become `|>'
  (setq-local electric-indent-chars
              (append '(?} ?\) ?\] ?| ?>) electric-indent-chars))
  (setq-local beginning-of-defun-function #'ernest-beginning-of-defun)
  (setq-local end-of-defun-function #'ernest-end-of-defun)
  (setq-local add-log-current-defun-function #'ernest-current-defun)
  (setq-local imenu-generic-expression ernest-imenu-generic-expression))

;; Emacs's own `gnu' entry refuses a file name with a space in it.  A `|'
;; before the first colon is the source gutter under a diagnostic, not a
;; file name (report section 11.5).
(add-to-list 'compilation-error-regexp-alist-alist
             '(ernest "^\\([^:|\n]+\\):\\([0-9]+\\):\\([0-9]+\\): " 1 2 3))
(add-to-list 'compilation-error-regexp-alist 'ernest)

(provide 'ernest-mode)

;;; ernest-mode.el ends here
