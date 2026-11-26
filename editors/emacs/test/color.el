;;; color.el --- What ernest-mode paints, and what it must not  -*- lexical-binding: t; -*-

;; Indentation can be measured against the repository; color cannot, so
;; it is pinned here: the face of one of each kind of token, and what
;; must not be painted.  Run from `editors/emacs/':
;;
;;     emacs -Q -batch -l test/color.el

;;; Code:

(add-to-list 'load-path (expand-file-name "."))
(require 'ernest-mode)
(load (expand-file-name "test/check.el") nil t)

(defconst ernest-color-sample "\
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

(defun ernest-color-painted (text want)
  "Check that the first occurrence of TEXT, in its case, is painted WANT."
  (goto-char (point-min))
  (if (not (let ((case-fold-search nil)) (search-forward text nil t)))
      (ernest-test-fail "%-16s is not in the source" text)
    (let ((got (get-text-property (match-beginning 0) 'face)))
      (unless (eq got want)
        (ernest-test-fail "%-16s painted %s, wanted %s" text got want)))))

(with-temp-buffer
  (insert ernest-color-sample)
  (ernest-mode)
  (font-lock-ensure)
  (ernest-color-painted "/// A list" 'ernest-doc-comment-face)
  (ernest-color-painted "type" 'font-lock-keyword-face)
  (ernest-color-painted "Shape" 'font-lock-type-face)
  (ernest-color-painted "// It isn't" 'font-lock-comment-delimiter-face)
  (ernest-color-painted "//// A ruler" 'font-lock-comment-delimiter-face)
  (ernest-color-painted "/// refused" 'font-lock-comment-delimiter-face)
  (ernest-color-painted "merge" 'font-lock-function-name-face)
  (ernest-color-painted "List(a)" 'font-lock-type-face)
  (ernest-color-painted "->" 'font-lock-operator-face)
  (ernest-color-painted "'a'" 'font-lock-string-face)
  (ernest-color-painted "\"circle\"" 'font-lock-string-face)
  (ernest-color-painted "true" 'font-lock-constant-face)
  (ernest-color-painted "0x1F_2A" 'font-lock-constant-face)
  ;; an exponent's digits are grouped as any decimal's, report §2.5
  (ernest-color-painted "e1_0" 'font-lock-constant-face)
  ;; a block comment before `///' leaves it a doc comment (report §2.2)
  (ernest-color-painted "/// after a note" 'ernest-doc-comment-face)
  ;; an operator a type declares, report §4.8
  (ernest-color-painted "Int.<>" 'font-lock-type-face)
  (ernest-color-painted "<>(a" 'font-lock-function-name-face)
  ;; the prefix is lowercase, report §2.5
  (ernest-color-painted "0X1F" nil)
  (ernest-color-painted "`C:" 'font-lock-string-face)
  ;; `needs' and `derives' are words only where they stand (report
  ;; §2.4): a field named `needs' is no keyword
  (ernest-color-painted "needs :" nil)
  (ernest-color-painted "derives compare" 'font-lock-keyword-face)
  (ernest-color-painted "needs a.compare" 'font-lock-keyword-face)
  ;; neither the apostrophe in the comment above nor the backslash that
  ;; ends the raw string may leave the rest of the buffer inside a string
  (goto-char (point-min))
  (search-forward "merge(left, right)")
  (when (nth 3 (syntax-ppss (match-beginning 0)))
    (ernest-test-fail "the buffer was left in a string")))

(ernest-test-finish "color")

;;; color.el ends here
