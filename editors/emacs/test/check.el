;;; check.el --- The count of failed checks the mode's tests share  -*- lexical-binding: t; -*-

;; A test loads this, says each failure with `ernest-test-fail' or
;; `ernest-test-want', and ends with `ernest-test-finish', which prints how
;; it went and exits non-zero where a check failed.

;;; Code:

(defvar ernest-test-failures 0
  "How many checks have failed.")

(defun ernest-test-fail (format &rest args)
  "Count a failure and say it, FORMAT and ARGS as `message' takes them."
  (setq ernest-test-failures (1+ ernest-test-failures))
  (apply #'message (concat "FAIL " format) args))

(defun ernest-test-want (what got want)
  "Check that WHAT came out as GOT, which should be WANT."
  (unless (equal got want)
    (ernest-test-fail "%s is %S, wanted %S" what got want)))

(defun ernest-test-finish (name)
  "Print how the test NAME went, and exit with its status."
  (message "%s" (if (zerop ernest-test-failures)
                    (format "%s: all checks passed" name)
                  (format "%s: %d checks failed" name ernest-test-failures)))
  (kill-emacs (if (zerop ernest-test-failures) 0 1)))

;;; check.el ends here
