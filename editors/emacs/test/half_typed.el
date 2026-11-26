;;; half_typed.el --- Indent half-typed Ernest and check what happens  -*- lexical-binding: t; -*-

;; Half-typed buffers (docs/design/emacs_mode.md, the table of tests).
;; Each file under test/half_typed is a buffer caught mid-keystroke,
;; written with the indentation a person would expect.  The mode must
;; leave every line where it is, and must give a fresh line at the end
;; the column below.  Run from `editors/emacs/':
;;
;;     emacs -Q -batch -l test/half_typed.el

;;; Code:

(require 'cl-lib)
(add-to-list 'load-path (expand-file-name "."))
(require 'ernest-mode)
(load (expand-file-name "test/check.el") nil t)

(defconst ernest-half-typed-columns
  '(("after_comment.ern" . "33")        ; a call's first item after a block comment
    ("bar.ern" . "4")                   ; a receive whose next line is a bare |
    ("block.ern" . "kept")              ; an unclosed block comment
    ("brace.ern" . "4")                 ; a block whose } is missing
    ("clause.ern" . "8")                ; a match with no closing brace
    ("comma.ern" . "22")                ; a constructor with a trailing comma
    ("comment.ern" . "0")               ; a comment before a closing brace
    ("comment_ends.ern" . "8")          ; a block comment that ends a call's line
    ("constructor.ern" . "0")           ; constructors spelled as reserved words
    ("equals.ern" . "4")                ; a line ending in =
    ("list.ern" . "13")                 ; a match in a list in a call
    ("minus.ern" . "15")                ; a negative element after a comma
    ("pipe.ern" . "4")                  ; lines an operator carries on
    ("prose.ern" . "0")                 ; an apostrophe in a comment
    ("raw.ern" . "kept")                ; an unclosed raw string
    ("rawif.ern" . "0")                 ; a raw string's line in column zero
    ("then.ern" . "4"))                 ; a then under its if
  "The column a fresh line at the end of each buffer must be given.
`kept' means the mode decides nothing and the line stays where it is,
which is the answer inside an unclosed string or comment.")

(defun ernest-half-typed-next-column ()
  "The column a fresh line at the end of the buffer would be given."
  (goto-char (point-max))
  (unless (bolp) (insert "\n"))
  (let ((indent (ernest-calculate-indent)))
    (if indent (number-to-string indent) "kept")))

(dolist (want ernest-half-typed-columns)
  (let ((file (expand-file-name (car want) "test/half_typed")))
    (with-temp-buffer
      (insert-file-contents file)
      (ernest-mode)
      (let ((before (buffer-string)) (moved 0))
        (let ((inhibit-message t)) (indent-region (point-min) (point-max)))
        (cl-loop for b in (split-string before "\n")
                 for a in (split-string (buffer-string) "\n")
                 unless (string= a b) do (setq moved (1+ moved)))
        (unless (zerop moved)
          (ernest-test-fail "%s: %d lines moved" (car want) moved))
        (let ((got (ernest-half-typed-next-column)))
          (unless (equal got (cdr want))
            (ernest-test-fail "%s: a fresh line at %s, wanted %s"
                              (car want) got (cdr want))))))))

;; a declaration typed a step in, after the one above has closed, goes
;; back to column zero
(with-temp-buffer
  (insert "fn f() = {\n    1\n}\n\n    fn g() = 2\n")
  (ernest-mode)
  (goto-char (point-min))
  (search-forward "fn g")
  (ernest-indent-line)
  (unless (zerop (current-indentation))
    (ernest-test-fail "a declaration a step in stays at %d" (current-indentation))))

;; the apostrophe in prose.ern's comment must not leave the rest in a string
(with-temp-buffer
  (insert-file-contents (expand-file-name "prose.ern" "test/half_typed"))
  (ernest-mode)
  (goto-char (point-min))
  (search-forward "decode(bytes)")
  (when (nth 3 (syntax-ppss (match-beginning 0)))
    (ernest-test-fail "an apostrophe in prose left the buffer in a string")))

(ernest-test-finish "half_typed")

;;; half_typed.el ends here
