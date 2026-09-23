;;; flatten.el --- Indent the repository's sources from column zero  -*- lexical-binding: t; -*-

;; Every line of a source is moved to column zero, outside strings and
;; comments, and the mode must put each back where it was.  A line's
;; place must not depend on the indentation it already has, which is what
;; a pasted block or a line typed at the margin tests.  Run from `emacs/':
;;
;;     emacs -Q -batch -l test/flatten.el ../stdlib/*.ern

;;; Code:

(require 'cl-lib)
(add-to-list 'load-path (expand-file-name "."))
(require 'ernest-mode)

(let ((total 0) (moved 0) (worst nil))
  (dolist (file command-line-args-left)
    (with-temp-buffer
      (insert-file-contents file)
      (let ((before (buffer-string)))
        (ernest-mode)
        (goto-char (point-min))
        (while (re-search-forward "^[ \t]+" nil t)
          ;; `syntax-ppss' moves point and may change the match data
          (unless (nth 8 (save-excursion
                           (save-match-data (syntax-ppss (match-beginning 0)))))
            (replace-match "")))
        (let ((inhibit-message t)) (indent-region (point-min) (point-max)))
        (cl-loop for b in (split-string before "\n")
                 for a in (split-string (buffer-string) "\n")
                 for line from 1
                 do (setq total (1+ total))
                 unless (string= a b)
                 do (setq moved (1+ moved))
                 and do (setq worst (format "%s:%d: %s" (file-name-nondirectory file)
                                            line a))))))
  (message "%d of %d lines misplaced from column zero%s" moved total
           (if worst (concat "\n  last: " worst) ""))
  (unless (zerop moved) (kill-emacs 1)))

;;; flatten.el ends here
