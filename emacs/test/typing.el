;;; typing.el --- Indent the repository's sources as they were typed  -*- lexical-binding: t; -*-

;; The second corpus at scale.  A file truncated at line n is the buffer
;; a person had when they had typed that far: unbalanced brackets, a
;; clause with no arms, a string not yet closed.  The lines above the cut
;; are known good, so the mode must leave them where they are.  This
;; reports every line it would move, by how far, and at which cut.  Run
;; from `emacs/':
;;
;;     emacs -Q -batch -l test/typing.el ../stdlib/*.ern

;;; Code:

(require 'cl-lib)
(add-to-list 'load-path (expand-file-name "."))
(require 'ernest-mode)

(defvar ernest-typing-step (string-to-number (or (getenv "STEP") "25"))
  "How many lines lie between one cut and the next.")

(let ((cuts 0) (moved 0) (worst nil))
  (dolist (file command-line-args-left)
    (let* ((whole (with-temp-buffer
                    (insert-file-contents file)
                    (split-string (buffer-string) "\n")))
           (count (length whole)))
      (cl-loop for cut from ernest-typing-step below count by ernest-typing-step do
               (let ((before (cl-subseq whole 0 cut)))
                 ;; a comment takes the place of the code below it, and at a
                 ;; cut there is none; that is the rule, not a defect
                 (unless (string-match-p "\\`[ \t]*//" (car (last before)))
                 (with-temp-buffer
                   (insert (mapconcat #'identity before "\n"))
                   (ernest-mode)
                   (let ((inhibit-message t)) (indent-region (point-min) (point-max)))
                   (setq cuts (1+ cuts))
                   (cl-loop for b in before
                            for a in (split-string (buffer-string) "\n")
                            for line from 1
                            unless (string= a b)
                            do (setq moved (1+ moved))
                            and do (setq worst
                                         (format "%s:%d cut at %d: %d -> %d |%s"
                                                 (file-name-nondirectory file) line cut
                                                 (- (length b) (length (string-trim-left b)))
                                                 (- (length a) (length (string-trim-left a)))
                                                 (string-trim-left a))))))))))
  (message "%d lines moved over %d cuts%s" moved cuts
           (if worst (concat "\n  last: " worst) ""))
  (unless (zerop moved) (kill-emacs 1)))

;;; typing.el ends here
