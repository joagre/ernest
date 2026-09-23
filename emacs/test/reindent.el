;;; reindent.el --- Reindent Ernest sources and report what moved  -*- lexical-binding: t; -*-

;; The first of the two corpora in docs/emacs_mode.md: the repository's
;; own sources are indented as the style guide says, so reindenting one
;; with the mode must leave it unchanged.  Run from `emacs/':
;;
;;     emacs -Q -batch -l test/reindent.el ../stdlib/*.ern
;;
;; With `-f ernest-reindent-show' after the files, every line that moved
;; is printed as `file:line: old -> new'.

;;; Code:

(require 'cl-lib)
(add-to-list 'load-path (expand-file-name "."))
(require 'ernest-mode)

(defvar ernest-reindent-show (getenv "SHOW")
  "Print every line that moved, not only the count.")

(let ((total 0) (moved 0) (files 0) (dirty 0))
  (dolist (file command-line-args-left)
    (with-temp-buffer
      (insert-file-contents file)
      (ernest-mode)
      (let* ((before (split-string (buffer-string) "\n"))
             (was moved))
        (let ((inhibit-message t)) (indent-region (point-min) (point-max)))
        (let ((after (split-string (buffer-string) "\n"))
              (line 0))
          (setq total (+ total (length before)) files (1+ files))
          (cl-loop for b in before for a in after
                   do (setq line (1+ line))
                   unless (string= a b)
                   do (setq moved (1+ moved))
                   and when ernest-reindent-show
                   do (message "%s:%d: %d -> %d |%s"
                               (file-name-nondirectory file) line
                               (- (length b) (length (string-trim-left b)))
                               (- (length a) (length (string-trim-left a)))
                               (string-trim-left a))))
        (unless (= was moved) (setq dirty (1+ dirty))))))
  (message "%d of %d lines moved, %d of %d files touched" moved total dirty files)
  (unless (zerop moved) (kill-emacs 1)))

;;; reindent.el ends here
