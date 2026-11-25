;;; format.el --- Laying out a buffer with `ern format', and on save  -*- lexical-binding: t; -*-

;; `ernest-format-buffer' and `ernest-format-on-save-mode' run the
;; toolchain's `ern format' (report §11.6), so the toolchain is
;; built first.  Run from `editors/emacs/':
;;
;;     emacs -Q -batch -l test/format.el

;;; Code:

(add-to-list 'load-path (expand-file-name "."))
(require 'ernest-mode)
(load (expand-file-name "test/check.el") nil t)

(setq ernest-format-command (expand-file-name "../../bin/ern"))

(defun ernest-test-diagnostic ()
  "The first line of the buffer that shows the formatter's diagnostic, or nil."
  (let ((errors (get-buffer ernest--format-errors-buffer)))
    (and errors
         (with-current-buffer errors
           (goto-char (point-min))
           (buffer-substring-no-properties (point) (line-end-position))))))

;; a loose buffer is laid out, and point stays on its token
(with-temp-buffer
  (ernest-mode)
  (insert "fn f(x) = x+1\n")
  (search-backward "1")
  (ernest-format-buffer)
  (ernest-test-want "a loose buffer, laid out" (buffer-string) "fn f(x) =\n    x + 1\n")
  (ernest-test-want "point, after laying out" (looking-at-p "1\n") t))

;; a large source, its indentation taken away, comes back as it was, and
;; point stays where it was in the text
(let ((source (with-temp-buffer
                (insert-file-contents "../../src/shell/ernest/shell.ern")
                (buffer-string))))
  (with-temp-buffer
    (ernest-mode)
    (insert source)
    (goto-char (point-min))
    (while (re-search-forward "^ +" nil t)
      (replace-match ""))
    (goto-char (point-min))
    (search-forward "type State =")
    (push-mark (match-beginning 0) t)
    (search-forward "fn execute(")
    (let ((start (float-time)))
      (ernest-format-buffer)
      (message "format: shell.ern laid out in the buffer in %.2f s" (- (float-time) start)))
    (ernest-test-want "shell.ern without its indentation, laid out"
                      (string= (buffer-string) source) t)
    (ernest-test-want "point in shell.ern" (looking-back "fn execute(" (line-beginning-position))
                      t)
    (ernest-test-want "the mark in shell.ern"
                      (save-excursion (goto-char (mark t)) (looking-at-p "type State =")) t)))

;; a formatter's text that differs in more than white space is refused,
;; and the buffer left as it was
(with-temp-buffer
  (insert "fn f(x) = x+1\n")
  (let ((out (generate-new-buffer " *out*" t)))
    (with-current-buffer out
      (insert "fn f(y) =\n    y + 1\n"))
    (ernest-test-want "a difference beyond white space"
                      (condition-case nil
                          (progn
                            (ernest--format-apply out)
                            'applied)
                        (error 'refused))
                      'refused)
    (ernest-test-want "the buffer it was refused for" (buffer-string) "fn f(x) = x+1\n")
    (kill-buffer out)))

;; a buffer that does not parse is left as it is, and the diagnostic
;; names the buffer where the formatter names standard input `-'
(with-temp-buffer
  (rename-buffer "broken.ern" t)
  (ernest-mode)
  (insert "fn h( = 1\n")
  (ernest-format-buffer)
  (ernest-test-want "a broken buffer, after laying out" (buffer-string) "fn h( = 1\n")
  (ernest-test-want "the diagnostic" (ernest-test-diagnostic)
                    (concat (buffer-name) ":1:7: expected a pattern instead of `=`"))
  (ernest-test-want "the diagnostic's mode"
                    (buffer-local-value 'major-mode (get-buffer ernest--format-errors-buffer))
                    'compilation-mode))

;; a buffer laid out takes the diagnostic away
(with-temp-buffer
  (ernest-mode)
  (insert "fn g(y) = y\n")
  (ernest-format-buffer)
  (ernest-test-want "the diagnostic, after a buffer laid out" (ernest-test-diagnostic) nil))

;; the init file's line lays out a buffer as it is saved; a buffer that
;; does not parse, or a formatter that is not there, is saved as it was
;; typed
(add-hook 'ernest-mode-hook #'ernest-format-on-save-mode)
(let ((directory (make-temp-file "ernest-format" t)))
  (unwind-protect
      (dolist (case `(("loose.ern" "fn f(x) = x+1\n" "fn f(x) =\n    x + 1\n" nil)
                      ("broken.ern" "fn h( = 1\n" "fn h( = 1\n" nil)
                      ("missing.ern" "fn f(x) = x+1\n" "fn f(x) = x+1\n"
                       ,(expand-file-name "no-such-ern" directory))))
        (let* ((file (expand-file-name (nth 0 case) directory))
               (buffer (find-file-noselect file))
               (ernest-format-command (or (nth 3 case) ernest-format-command)))
          (with-current-buffer buffer
            (ernest-test-want (concat "the mode of " (nth 0 case)) major-mode 'ernest-mode)
            (insert (nth 1 case))
            (save-buffer)
            (ernest-test-want (concat (nth 0 case) ", saved")
                              (with-temp-buffer
                                (insert-file-contents file)
                                (buffer-string))
                              (nth 2 case))
            (when (equal (nth 0 case) "broken.ern")
              (ernest-test-want "the diagnostic on save" (ernest-test-diagnostic)
                                "broken.ern:1:7: expected a pattern instead of `=`"))
            ;; a formatter that cannot run is shown where a diagnostic is,
            ;; since the save's own message would hide a message at once
            (when (equal (nth 0 case) "missing.ern")
              (ernest-test-want "why a save was not laid out"
                                (string-prefix-p "Not laid out: Searching for program"
                                                 (ernest-test-diagnostic))
                                t)))
          (kill-buffer buffer)))
    (delete-directory directory t)))

(ernest-test-finish "format")

;;; format.el ends here
