;;; lint.el --- Byte-compile ernest-mode.el and run checkdoc on it  -*- lexical-binding: t; -*-

;; A warning from either fails, as a warning fails the Erlang build.
;; The compiled file goes to a temporary directory, so the mode is always
;; loaded from source.  Run from `editors/emacs/':
;;
;;     emacs -Q -batch -l test/lint.el

;;; Code:

(require 'checkdoc)
(load (expand-file-name "test/check.el") nil t)

(let* ((dir (make-temp-file "ernest-lint-" t))
       (byte-compile-error-on-warn t)
       (byte-compile-dest-file-function
        (lambda (_) (expand-file-name "ernest-mode.elc" dir))))
  (unwind-protect
      (unless (byte-compile-file "ernest-mode.el")
        (ernest-test-fail "ernest-mode.el does not byte-compile without a warning"))
    (delete-directory dir t)))

(let ((checkdoc-create-error-function
       (lambda (text &rest _)
         (ernest-test-fail "checkdoc: %s" text)
         nil)))
  (checkdoc-file "ernest-mode.el"))

(ernest-test-finish "lint")

;;; lint.el ends here
