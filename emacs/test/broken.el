;;; broken.el --- Indent half-typed Ernest and say what happens  -*- lexical-binding: t; -*-

;; The second corpus of docs/emacs_mode.md.  Each file under test/broken
;; is a buffer caught mid-keystroke, written with the indentation a
;; person would expect.  For each one this reports the lines the mode
;; would move, which should be none, and the column a fresh line at the
;; end would be given, which is what the person feels when they press
;; RET.  Run from `emacs/':
;;
;;     emacs -Q -batch -l test/broken.el test/broken/*.ern

;;; Code:

(require 'cl-lib)
(add-to-list 'load-path (expand-file-name "."))
(require 'ernest-mode)

(defun ernest-broken--next-column ()
  "The column a fresh line at the end of the buffer would be given."
  (goto-char (point-max))
  (unless (bolp) (insert "\n"))
  (let ((indent (ernest-calculate-indent)))
    (if indent (number-to-string indent) "kept")))

(dolist (file command-line-args-left)
  (with-temp-buffer
    (insert-file-contents file)
    (ernest-mode)
    (let ((before (buffer-string)) (moved 0))
      (indent-region (point-min) (point-max))
      (cl-loop for b in (split-string before "\n")
               for a in (split-string (buffer-string) "\n")
               unless (string= a b) do (setq moved (1+ moved)))
      ;; a quote in prose must not leave the rest of the buffer in a string
      (let ((poisoned (cl-loop for pos from (point-min) below (point-max)
                               count (nth 3 (syntax-ppss pos)))))
        (message "%-12s %d moved, next line at %s, %d chars in a string"
                 (file-name-nondirectory file) moved
                 (ernest-broken--next-column) poisoned)))))

;;; broken.el ends here
