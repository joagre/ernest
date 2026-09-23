;;; lint.el --- Byte-compile ernest-mode.el and run checkdoc on it  -*- lexical-binding: t; -*-

;; A warning from either fails, as a warning fails the Erlang build.
;; The compiled file goes to a temporary directory, so the mode is always
;; loaded from source.  Run from `emacs/':
;;
;;     emacs -Q -batch -l test/lint.el

;;; Code:

(require 'checkdoc)

(defvar ernest-lint--failures 0)

(let* ((dir (make-temp-file "ernest-lint-" t))
       (byte-compile-error-on-warn t)
       (byte-compile-dest-file-function
        (lambda (_) (expand-file-name "ernest-mode.elc" dir))))
  (unwind-protect
      (unless (byte-compile-file "ernest-mode.el")
        (setq ernest-lint--failures (1+ ernest-lint--failures))
        (message "FAIL ernest-mode.el does not byte-compile without a warning"))
    (delete-directory dir t)))

(let ((checkdoc-create-error-function
       (lambda (text &rest _)
         (setq ernest-lint--failures (1+ ernest-lint--failures))
         (message "FAIL checkdoc: %s" text)
         nil)))
  (checkdoc-file "ernest-mode.el"))

(message "%s" (if (zerop ernest-lint--failures)
                  "lint: all checks passed"
                (format "lint: %d checks failed" ernest-lint--failures)))
(unless (zerop ernest-lint--failures) (kill-emacs 1))

;;; lint.el ends here
