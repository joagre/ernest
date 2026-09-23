;;; editing.el --- What the mode gives beyond colour and indentation  -*- lexical-binding: t; -*-

;; Moving over declarations, `imenu', naming the declaration point is in,
;; and the regexp `M-x compile' reads `ernc' with.  Run from `emacs/':
;;
;;     emacs -Q -batch -l test/editing.el

;;; Code:

(require 'compile)
(require 'imenu)
(add-to-list 'load-path (expand-file-name "."))
(require 'ernest-mode)

(defvar ernest-editing--failures 0)

(defun ernest-editing--want (what got want)
  "Check that WHAT came out as GOT, which should be WANT."
  (unless (equal got want)
    (setq ernest-editing--failures (1+ ernest-editing--failures))
    (message "FAIL %s is %S, wanted %S" what got want)))

(with-temp-buffer
  (insert-file-contents "../stdlib/list.ern")
  (ernest-mode)
  ;; the declaration point is in, from the middle of a body
  (goto-char (point-min))
  (search-forward "y :: rest -> if i == 0")
  (ernest-editing--want "the declaration at the cursor" (ernest-current-defun) "get")
  ;; C-M-a from there lands on its own line
  (ernest-beginning-of-defun)
  (ernest-editing--want "beginning-of-defun"
                        (buffer-substring (point) (+ (point) 16)) "export fn get(xs")
  ;; C-M-e stops before the next declaration's doc block
  (ernest-end-of-defun)
  (forward-line -1)
  (ernest-editing--want "end-of-defun" (string-trim (thing-at-point 'line t)) "}")
  ;; imenu finds every exported function
  (let* ((index (let ((imenu-generic-expression ernest-imenu-generic-expression))
                  (imenu--generic-function ernest-imenu-generic-expression)))
         (names (mapcar #'car (cdr (assoc "Function" index)))))
    (dolist (want '("get" "map" "sort" "foreach"))
      (unless (member want names)
        (setq ernest-editing--failures (1+ ernest-editing--failures))
        (message "FAIL imenu has no %s" want)))))

;; the diagnostic `ernc' prints, read the way `M-x compile' reads it
(let* ((entry (assq 'ernest compilation-error-regexp-alist-alist))
       (re (nth 1 entry))
       (line "/home/a person/src/ernest/stdlib/list.ern:2:13: unknown name y"))
  (ernest-editing--want "the error regexp is registered" (and entry t) t)
  (ernest-editing--want "compilation-error-regexp-alist names it"
                        (and (memq 'ernest compilation-error-regexp-alist) t) t)
  (if (not (string-match re line))
      (progn (setq ernest-editing--failures (1+ ernest-editing--failures))
             (message "FAIL the error regexp does not match %S" line))
    (ernest-editing--want "the file" (match-string 1 line)
                          "/home/a person/src/ernest/stdlib/list.ern")
    (ernest-editing--want "the line" (match-string 2 line) "2")
    (ernest-editing--want "the column" (match-string 3 line) "13")))

(message "%s" (if (zerop ernest-editing--failures)
                  "editing: all checks passed"
                (format "editing: %d checks failed" ernest-editing--failures)))
(unless (zerop ernest-editing--failures) (kill-emacs 1))

;;; editing.el ends here
