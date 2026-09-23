;;; ernest-mode.el --- Major mode for Ernest  -*- lexical-binding: t; -*-

;; The mode for `.ern' files, designed in docs/emacs_mode.md.  It is
;; derived from `prog-mode' and not from CC Mode: Ernest is
;; expression-structured, where CC Mode's engine assumes C's statements
;; and declarations.
;;
;; Nothing here calls `ernc'.  A buffer being edited is broken most of
;; the time, so colouring and indentation are the buffer's own work;
;; `ernc' is reached through `M-x compile', and
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
;;; test/ernest-mode-tests.el keeps them equal to the lexer's.

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
  "Mark the quotes of char literals between START and END as string quotes.
An apostrophe is punctuation otherwise, so prose in a comment cannot
unbalance a buffer.  A quote marked inside a comment or a string is
harmless: a scanner already in one ignores it."
  (funcall
   (syntax-propertize-rules
    ;; a char literal, report section 2.5: 'a', '\n', '\u{1b}'
    ("\\('\\)\\(?:\\\\u{[[:xdigit:]]+}\\|\\\\.\\|[^'\\\\\n]\\)\\('\\)"
     (1 "\"") (2 "\"")))
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
      (,(concat "\\_<\\(?:let\\|foreign[ \t]+fn\\)\\_>[ \t]+\\(" lower "\\)")
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
      ("\\_<0[xX][0-9a-fA-F_]+\\_>" . 'font-lock-constant-face)
      ("\\_<0[oO][0-7_]+\\_>" . 'font-lock-constant-face)
      ("\\_<0[bB][01_]+\\_>" . 'font-lock-constant-face)
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
  (concat "\(?:->\|<-\|<>\|||\||>\|&&\|::\|[-+*/%.]\|=[^=]"
          "\|\_<with\_>\|\_<then\_>\)")
  "What a line opens with when it carries the line above on.")

(defun ernest--line-empty-p ()
  "Whether the current line holds only whitespace."
  (save-excursion
    (beginning-of-line)
    (looking-at-p "[ \t]*$")))

(defun ernest--clause-bar-p ()
  "Whether point is on a `|' that leads a clause, and not on `||'."
  (and (eq (char-after) ?|)
       (not (eq (char-after (1+ (point))) ?|))
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
  "The end of the code on this line, comments and strings left out."
  (save-excursion
    (let* ((start (line-beginning-position))
           (limit (line-end-position))
           (state (syntax-ppss start))
           (end limit))
      (goto-char start)
      ;; `parse-partial-sexp' stops where a comment or a string opens, so
      ;; the line is walked in a few jumps and not a character at a time
      (catch 'done
        (while (< (point) limit)
          (setq state (parse-partial-sexp (point) limit nil nil state t))
          (cond ((nth 4 state)                  ; a comment opens: code ends
                 (setq end (nth 8 state))
                 (throw 'done nil))
                ((nth 3 state)                  ; a string opens: walk past it
                 nil)
                (t (throw 'done nil)))))
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
        (let ((state (syntax-ppss (1- (point)))))
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
             (not (ernest--clause-bar-p)))
        (ernest--in-head-p))))

(defun ernest--anchor-base ()
  "The base column of the logical line point is on.
A continuation is anchored where the line it continues begins, so a
signature broken over lines does not carry its body out to the right."
  (save-excursion
    (let ((seen 0))
      (while (and (ernest--continues-p)
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
  "The start of the nearest declaration at or above point.
A declaration begins in column zero, which is the one thing a broken
buffer still says plainly."
  (save-excursion
    (beginning-of-line)
    (while (and (not (bobp)) (not (looking-at-p "[^ \t\n]")))
      (forward-line -1))
    (point)))

(defun ernest--matching-if-base (limit depth)
  "The base column of the `if' this `else' belongs to, or nil.
LIMIT bounds the search and DEPTH is the bracket depth the `else' sits
at; an `if' deeper in brackets, or in a string or a comment, is skipped."
  (save-excursion
    (let ((pending 0) (base nil))
      (while (and (null base)
                  (re-search-backward "\\_<\\(if\\|else\\)\\_>" limit t))
        (let ((state (syntax-ppss (point))))
          (unless (or (nth 8 state) (/= (car state) depth))
            (if (equal (match-string 1) "else")
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
       ;; a comment goes where the code it introduces goes
       ((and (looking-at-p "//")
             (save-excursion (ernest--next-code-line)))
        (save-excursion (ernest--next-code-line) (ernest-calculate-indent)))
       ;; a closing bracket returns to the line its opener began on
       ((and open (memq first '(?\) ?\] ?\})))
        (save-excursion (goto-char open) (ernest--anchor-base)))
       ;; a clause's bar sits two spaces to the left of its arms
       ((ernest--clause-bar-p)
        (max 0 (- content ernest-clause-offset)))
       ;; an `else' returns to its `if'
       ((looking-at-p "\\_<else\\_>")
        (or (ernest--matching-if-base (or open (ernest--declaration-start))
                                      (car state))
            content))
       ;; a body or a continuation opened on the line before, or this line
       ;; opens with an operator and carries the line above on
       ((or (ernest--continues-p)
            (save-excursion
              (and (ernest--previous-code-line)
                   (or (null open) (> (point) open))
                   (ernest--opens-body-p))))
        (+ (save-excursion (ernest--previous-code-line) (ernest--anchor-base))
           ernest-indent-offset))
       (t content)))))

(defun ernest-indent-line ()
  "Indent the current line as Ernest.
A line whose place cannot be decided keeps the indentation it has."
  (interactive)
  (let ((indent (ernest-calculate-indent))
        (offset (- (point) (save-excursion (back-to-indentation) (point)))))
    (when indent
      (save-excursion
        (indent-line-to indent))
      (when (> offset 0)
        (goto-char (+ (save-excursion (back-to-indentation) (point)) offset))))))

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
  (setq-local electric-indent-chars
              (append '(?} ?\) ?\] ?|) electric-indent-chars)))

;;;###autoload
(with-eval-after-load 'compile
  (add-to-list 'compilation-error-regexp-alist-alist
               '(ernest "^\\([^ \n:]+\\):\\([0-9]+\\):\\([0-9]+\\): " 1 2 3))
  (add-to-list 'compilation-error-regexp-alist 'ernest))

(provide 'ernest-mode)

;;; ernest-mode.el ends here
