;;; colour.el --- What ernest-mode paints, and what it must not  -*- lexical-binding: t; -*-

;; Indentation can be measured against the repository; colour cannot, so
;; it is pinned here.  Two silent defects were found by writing this:
;; every face was named as a variable where Emacs 31 has only the face,
;; which made font-lock error out on every buffer, and the two rules for
;; a declaration's own name never matched.  Run from `emacs/':
;;
;;     emacs -Q -batch -l test/colour.el

;;; Code:

(add-to-list 'load-path (expand-file-name "."))
(require 'ernest-mode)

(defvar ernest-colour--failures 0)

(defconst ernest-colour--source "\
/// A list in order, smallest first.
type Shape = Dot | Circle(radius : Int)

// It isn't a string, and neither is what follows it.
export fn merge(left : List(a), right : List(a)) -> List(a) =
    let tag = 'a';
    let name = \"circle\";
    let flag = true;
    let size = 0x1F_2A;
    merge(left, right)
"
  "A buffer holding one of everything the keywords claim to paint.")

(defun ernest-colour--check (text want)
  "Check that the first occurrence of TEXT is painted WANT."
  (goto-char (point-min))
  (if (not (search-forward text nil t))
      (progn (setq ernest-colour--failures (1+ ernest-colour--failures))
             (message "FAIL %-16s is not in the source" text))
    (let ((got (get-text-property (match-beginning 0) 'face)))
      (unless (eq got want)
        (setq ernest-colour--failures (1+ ernest-colour--failures))
        (message "FAIL %-16s painted %s, wanted %s" text got want)))))

(with-temp-buffer
  (insert ernest-colour--source)
  (ernest-mode)
  (font-lock-ensure)
  (ernest-colour--check "/// A list" 'ernest-doc-comment-face)
  (ernest-colour--check "type" 'font-lock-keyword-face)
  (ernest-colour--check "Shape" 'font-lock-type-face)
  (ernest-colour--check "// It isn't" 'font-lock-comment-delimiter-face)
  (ernest-colour--check "merge" 'font-lock-function-name-face)
  (ernest-colour--check "List(a)" 'font-lock-type-face)
  (ernest-colour--check "->" 'font-lock-operator-face)
  (ernest-colour--check "'a'" 'font-lock-string-face)
  (ernest-colour--check "\"circle\"" 'font-lock-string-face)
  (ernest-colour--check "true" 'font-lock-constant-face)
  (ernest-colour--check "0x1F_2A" 'font-lock-constant-face)
  ;; the apostrophe in the comment above must not leave the rest of the
  ;; buffer inside a string
  (goto-char (point-min))
  (search-forward "merge(left, right)")
  (when (nth 3 (syntax-ppss (match-beginning 0)))
    (setq ernest-colour--failures (1+ ernest-colour--failures))
    (message "FAIL an apostrophe in prose left the buffer in a string")))

(message "%s" (if (zerop ernest-colour--failures)
                  "colour: all checks passed"
                (format "colour: %d checks failed" ernest-colour--failures)))
(unless (zerop ernest-colour--failures) (kill-emacs 1))

;;; colour.el ends here
