;;; ernest-mode.el --- Major mode for Ernest  -*- lexical-binding: t; -*-

;;; Commentary:

;; The mode for `.ern' files.  docs/emacs_mode.md designs it, and says
;; what it does and what it does not do.
;;
;; Nothing here calls the compiler.  A buffer being edited is broken most
;; of the time, so colouring and indentation are the buffer's own work;
;; the compiler is reached through `M-x compile', and
;; `compilation-error-regexp-alist' takes its diagnostics.

;;; Installation:

;; Put these three lines in your init file, with the path to this
;; directory.  Opening a `.ern' file then loads the mode.
;;
;;     (add-to-list 'load-path "~/src/ernest/emacs")
;;     (autoload 'ernest-mode "ernest-mode" "Major mode for Ernest." t)
;;     (add-to-list 'auto-mode-alist '("\\.ern\\'" . ernest-mode))

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

;;; Words and operators.  These restate Appendix A, so
;;; `emacs_mode_mirrors_the_lexer_test' in test/ern_style_tests.erl
;;; checks them against the lexer's.

(defconst ernest-reserved-words
  '("type" "abstract" "with" "foreign" "match" "when" "receive" "after" "or"
    "as" "if" "then" "else" "fn" "let" "export")
  "Ernest's reserved words, Appendix A.")

(defconst ernest-operators
  '("->" "<-" "::" "<>" "|>" "==" "!=" "<=" ">=" "&&" "||" "..")
  "The operators font lock paints, a subset of Appendix A's symbols.")

(defconst ernest-constants
  '("true" "false")
  "The literals that read as words (report section 2.5).")

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
A comment opening with `///' is a doc comment (report section 2.2)."
  (cond ((nth 3 state) 'font-lock-string-face)
        ((nth 4 state)
         (save-excursion
           (goto-char (nth 8 state))
           (if (looking-at-p "///")
               'ernest-doc-comment-face
             'font-lock-comment-face)))))

(defconst ernest-font-lock-keywords
  (let ((upper "[A-Z][A-Za-z0-9_]*")
        (lower "[a-z_][A-Za-z0-9_]*"))
    `(;; a declaration's name, so the eye finds definitions
      (,(concat "\\_<fn\\_>[ \t]+\\(" lower "\\)")
       1 'font-lock-function-name-face)
      (,(concat "\\_<let\\_>[ \t]+\\(" lower "\\)")
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
  "Whether the current line holds only whitespace."
  (save-excursion
    (beginning-of-line)
    (looking-at-p "[ \t]*$")))

(defun ernest--clause-bar-p ()
  "Whether point is on a `|' that leads a clause, and not on `||' or `|>'."
  (and (eq (char-after) ?|)
       (not (memq (char-after (1+ (point))) '(?| ?>)))
       (not (eq (char-before) ?|))))

(defun ernest--line-base ()
  "The column this line's content starts at, a leading clause bar skipped.
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

(defun ernest--continues-p ()
  "Whether this line carries the line above on rather than starting something.
A line opening with an operator carries on, and so does a declaration's
head broken over lines.  A body under `=' or `then' does not: it is a new
logical line, one step in."
  (save-excursion
    (back-to-indentation)
    (or (and (looking-at-p ernest--continuation-re)
             (not (ernest--clause-bar-p))
             (not (ernest--after-separator-p)))
        (ernest--in-head-p))))

(defun ernest--declaration-p ()
  "Whether point, at a line's first token, opens a declaration.
`fn' before a bracket opens a lambda, not a declaration."
  (and (looking-at-p ernest--declaration-re)
       (not (looking-at-p "fn[ \t]*("))))

(defun ernest--anchor-base (&optional carried)
  "The base column of the logical line point is on.
A declaration's head broken over lines is one logical line, so its body
is not carried out to the right.  With CARRIED, so is a line an operator
carries on, which puts every such line at one step; a bracket opened on
one steps in from where it stands."
  (save-excursion
    (let ((seen 0))
      (while (and (if carried (ernest--continues-p) (ernest--in-head-p))
                  (< seen 100)                  ; a broken buffer ends the walk
                  (save-excursion (ernest--previous-code-line)))
        (setq seen (1+ seen))
        (ernest--previous-code-line))
      (ernest--line-base))))

(defun ernest--content-column (open)
  "The column ordinary content sits at inside the bracket at OPEN.
With OPEN nil it is a declaration's body, which is a step in from the
declaration's own line; the style guide says a step and never an
alignment, so nothing here looks at what follows the bracket."
  (if open
      (save-excursion
        (goto-char open)
        (+ (ernest--anchor-base) ernest-indent-offset))
    (let ((start (ernest--declaration-start)))
      (if (< start (line-beginning-position))
          ernest-indent-offset
        0))))

(defun ernest--declaration-start ()
  "The start of the declaration the line point is on belongs to.
A line opening a declaration outside every bracket starts one itself.
Otherwise the nearest line above in column zero does, which is the one
thing a broken buffer still says plainly.  The line's own indentation
is not read, so a line typed in column zero is placed as any other."
  (save-excursion
    (back-to-indentation)
    (if (and (zerop (car (syntax-ppss))) (ernest--declaration-p))
        (line-beginning-position)
      (beginning-of-line)
      (while (and (not (bobp))
                  (progn (forward-line -1) (not (looking-at-p "[^ \t\n]")))))
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
                (setq base (ernest--anchor-base)))))))
      base)))

(defun ernest-calculate-indent ()
  "The column this line belongs at, or nil when it cannot be decided."
  (save-excursion
    (back-to-indentation)
    (let* ((state (syntax-ppss (point)))
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
       ((and open (memq first '(?\) ?\] ?\})))
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
        (+ (save-excursion (ernest--previous-code-line) (ernest--anchor-base t))
           ernest-indent-offset))
       ;; a body opened at the end of the line before
       ((save-excursion
          (and (ernest--previous-code-line)
               (or (null open) (> (point) open))
               (ernest--opens-body-p)))
        (+ (save-excursion (ernest--previous-code-line) (ernest--anchor-base))
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

(defun ernest-beginning-of-defun (&optional count)
  "Move back to the start of a declaration, COUNT of them.
A negative COUNT moves forward.  Return non-nil when every one was found."
  (interactive "p")
  (let ((re (concat "^" ernest--declaration-re))
        (count (or count 1))
        (found t))
    (if (< count 0)
        (dotimes (_ (- count))
          (end-of-line)
          (if (re-search-forward re nil 'move)
              (goto-char (match-beginning 0))
            (setq found nil)))
      (dotimes (_ count)
        (unless (re-search-backward re nil 'move)
          (setq found nil))))
    found))

(defun ernest-end-of-defun ()
  "Move past the end of the declaration point is at.
A doc block or a blank line before the next declaration belongs to it,
not to this one."
  (forward-line 1)
  (if (not (re-search-forward (concat "^" ernest--declaration-re) nil 'move))
      (goto-char (point-max))
    (goto-char (match-beginning 0))
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
    (when (looking-at (concat "^" ernest--declaration-re "[ \t]+\\([A-Za-z_][A-Za-z0-9_]*\\)"))
      (match-string-no-properties 1))))

(defconst ernest-imenu-generic-expression
  (let ((exported "^\\(?:export[ \t]+\\)?")
        (lower "\\([a-z_][A-Za-z0-9_]*\\)")
        (upper "\\([A-Z][A-Za-z0-9_]*\\)"))
    `(("Function" ,(concat exported "\\(?:foreign[ \t]+\\)?fn[ \t]+" lower) 1)
      ("Type" ,(concat exported "\\(?:abstract[ \t]+\\|foreign[ \t]+\\)?type[ \t]+" upper) 1)
      ("Value" ,(concat exported "let[ \t]+" lower) 1)))
  "What `imenu' offers: the declarations, by kind.")

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
