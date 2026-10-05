;;; typing.el --- Indent the repository's sources as they were typed  -*- lexical-binding: t; -*-

;; The second corpus at scale.  A file truncated at line n is the buffer
;; a person had when they had typed that far: unbalanced brackets, a
;; clause with no arms, a string not yet closed.  The lines above the cut
;; are known good, so the mode must leave them where they are, but for a
;; line whose place is read from what follows the cut: a comment's last
;; line, and the contents of a brace in a bracket's first item, which align
;; with the bracket's items where a further item follows.  This reports
;; every other line it would move, by how far, and at which cut.  Run
;; from `emacs/':
;;
;;     emacs -Q -batch -l test/typing.el ../stdlib/*.ern
;;
;; A file costs the square of its length, so the Makefile runs the corpus
;; in parts side by side: with PARTS=4 and PART=0 to 3, each part takes
;; every fourth file, the largest first, so that the largest files fall in
;; different parts.

;;; Code:

(require 'cl-lib)
(add-to-list 'load-path (expand-file-name "."))
(require 'ernest-mode)

(defvar ernest-typing-step (string-to-number (or (getenv "STEP") "25"))
  "How many lines lie between one cut and the next.")

(defun ernest-typing-part (files)
  "The FILES of this part, as PART and PARTS name it, every file without them."
  (let ((part (string-to-number (or (getenv "PART") "0")))
        (parts (string-to-number (or (getenv "PARTS") "1")))
        (largest (sort (copy-sequence files)
                       (lambda (a b) (> (file-attribute-size (file-attributes a))
                                        (file-attribute-size (file-attributes b)))))))
    (cl-loop for file in largest
             for i from 0
             when (= (mod i parts) part) collect file)))

(defun ernest-typing-aligned-below-p (whole line cut)
  "Whether LINE of WHOLE steps from a bracket's item that the cut at CUT hides.
A brace in the first item of a bracket opened on its line steps from that
item where the bracket holds a further item, and from the line where it
holds none (`ernest--brace-base').  Where the further item lies below the
cut, the buffer at the cut holds none, and the line's place is read from
text it does not have."
  (with-current-buffer whole
    (save-excursion
      (let ((limit (progn (goto-char (point-min)) (forward-line cut) (point)))
            (found nil)
            (brace (progn (goto-char (point-min))
                          (forward-line (1- line))
                          (back-to-indentation)
                          (nth 1 (syntax-ppss)))))
        (while (and brace (not found))
          (when (eq (char-after brace) ?{)
            (let ((inner brace)
                  (open (nth 1 (syntax-ppss brace))))
              (while (and open (not found)
                          (save-excursion (goto-char brace) (ernest--opened-here-p open)))
                (when (and (ernest--first-item-p open inner)
                           (not (ernest--comma-between-p open inner limit))
                           (ernest--comma-between-p
                            open limit (or (ignore-errors (scan-lists open 1 0)) (point-max))))
                  (setq found t))
                (setq inner open
                      open (nth 1 (syntax-ppss open))))))
          (setq brace (nth 1 (syntax-ppss brace))))
        found))))

(let ((cuts 0) (moved 0) (last-moved nil))
  (dolist (file (ernest-typing-part command-line-args-left))
    (let* ((source (generate-new-buffer " *typing*"))
           (whole (with-current-buffer source
                    (insert-file-contents file)
                    (ernest-mode)
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
                     ;; a line whose brace a bracket's further item below
                     ;; the cut aligns has its place from text the cut
                     ;; removed, as a comment has; that too is the rule
                     (cl-loop for b in before
                              for a in (split-string (buffer-string) "\n")
                              for line from 1
                              unless (or (string= a b)
                                         (ernest-typing-aligned-below-p source line cut))
                              do (setq moved (1+ moved))
                              and do (setq last-moved
                                           (format "%s:%d cut at %d: %d -> %d |%s"
                                                   (file-name-nondirectory file) line cut
                                                   (- (length b) (length (string-trim-left b)))
                                                   (- (length a) (length (string-trim-left a)))
                                                   (string-trim-left a))))))))
      (kill-buffer source)))
  (message "%d lines moved over %d cuts%s" moved cuts
           (if last-moved (concat "\n  last: " last-moved) ""))
  (unless (zerop moved) (kill-emacs 1)))

;;; typing.el ends here
