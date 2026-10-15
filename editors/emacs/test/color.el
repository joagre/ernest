;;; color.el --- What ernest-mode paints, and what it must not  -*- lexical-binding: t; -*-

;; Indentation can be measured against the repository; color cannot, so
;; it is pinned here.  Two silent defects were found by writing this:
;; every face was named as a variable where Emacs 31 has only the face,
;; which made font-lock error out on every buffer, and the two rules for
;; a declaration's own name never matched.  Run from `editors/emacs/':
;;
;;     emacs -Q -batch -l test/color.el

;;; Code:

(add-to-list 'load-path (expand-file-name "."))
(require 'ernest-mode)

(defvar ernest-color--failures 0)

(defconst ernest-color--source "\
/// A list in order, smallest first.
type Shape = Dot | Circle(radius : Int)

// It isn't a string, and neither is what follows it.
//// A ruler, which is no doc comment.
export fn merge(left : List(a), right : List(a), less : (a, a) -> Bool) : List(a) =
    let tag = 'a';
    let name = \"circle\";
    let flag = true; /// refused after code, and no doc comment
    let size = 0x1F_2A;
    let big = 1.0e1_0;
    let upper = 0X1F;
    let raw = `C:\\`;
    merge(left, right)

export fn Int.<>(a : Int, b : Int) : Int = a

/* a note */ /// after a note, a doc comment as the lexer reads it
type Task = Task(needs : List(String), done : Bool) derives compare
fn largest(list : List(a)) : Optional(a) needs a.compare = List.last(list)
"
  "A buffer holding one of everything the keywords claim to paint.")

(defun ernest-color--check (text want)
  "Check that the first occurrence of TEXT, in its case, is painted WANT."
  (goto-char (point-min))
  (if (not (let ((case-fold-search nil)) (search-forward text nil t)))
      (progn (setq ernest-color--failures (1+ ernest-color--failures))
             (message "FAIL %-16s is not in the source" text))
    (let ((got (get-text-property (match-beginning 0) 'face)))
      (unless (eq got want)
        (setq ernest-color--failures (1+ ernest-color--failures))
        (message "FAIL %-16s painted %s, wanted %s" text got want)))))

(with-temp-buffer
  (insert ernest-color--source)
  (ernest-mode)
  (font-lock-ensure)
  (ernest-color--check "/// A list" 'ernest-doc-comment-face)
  (ernest-color--check "type" 'font-lock-keyword-face)
  (ernest-color--check "Shape" 'font-lock-type-face)
  (ernest-color--check "// It isn't" 'font-lock-comment-delimiter-face)
  (ernest-color--check "//// A ruler" 'font-lock-comment-delimiter-face)
  (ernest-color--check "/// refused" 'font-lock-comment-delimiter-face)
  (ernest-color--check "merge" 'font-lock-function-name-face)
  (ernest-color--check "List(a)" 'font-lock-type-face)
  (ernest-color--check "->" 'font-lock-operator-face)
  (ernest-color--check "'a'" 'font-lock-string-face)
  (ernest-color--check "\"circle\"" 'font-lock-string-face)
  (ernest-color--check "true" 'font-lock-constant-face)
  (ernest-color--check "0x1F_2A" 'font-lock-constant-face)
  ;; an exponent's digits are grouped as any decimal's, report section 2.5
  (ernest-color--check "e1_0" 'font-lock-constant-face)
  ;; a block comment before `///' leaves it a doc comment (section 2.2)
  (ernest-color--check "/// after a note" 'ernest-doc-comment-face)
  ;; an operator a type declares, report section 4.8
  (ernest-color--check "Int.<>" 'font-lock-type-face)
  (ernest-color--check "<>(a" 'font-lock-function-name-face)
  ;; the prefix is lowercase, report section 2.5
  (ernest-color--check "0X1F" nil)
  (ernest-color--check "`C:" 'font-lock-string-face)
  ;; `needs' and `derives' are words only where they stand (report
  ;; section 2.4): a field named `needs' is no keyword
  (ernest-color--check "needs :" nil)
  (ernest-color--check "derives compare" 'font-lock-keyword-face)
  (ernest-color--check "needs a.compare" 'font-lock-keyword-face)
  ;; neither the apostrophe in the comment above nor the backslash that
  ;; ends the raw string may leave the rest of the buffer inside a string
  (goto-char (point-min))
  (search-forward "merge(left, right)")
  (when (nth 3 (syntax-ppss (match-beginning 0)))
    (setq ernest-color--failures (1+ ernest-color--failures))
    (message "FAIL the buffer was left in a string")))

(message "%s" (if (zerop ernest-color--failures)
                  "color: all checks passed"
                (format "color: %d checks failed" ernest-color--failures)))
(unless (zerop ernest-color--failures) (kill-emacs 1))

;;; color.el ends here
