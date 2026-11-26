;;; typing.el --- Indent the repository's sources as they were typed  -*- lexical-binding: t; -*-

;; The second corpus at scale.  A file truncated at line n is the buffer
;; a person had when they had typed that far: unbalanced brackets, a
;; match with no clauses, a string not yet closed.  The lines above the cut
;; are known good, so the mode must leave them where they are, but for a
;; line whose place is read from what follows the cut: a comment's last
;; line, and the contents of a brace in a bracket's first item, which align
;; with the bracket's items or hug them as the code after the item's own
;; bracket or brace says.  This reports every other line it would move, by
;; how far, and at which cut.  Run from `editors/emacs/':
;;
;;     emacs -Q -batch -l test/typing.el ../../src/stdlib/*.ern
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

(defun ernest-typing-read-below-p (whole line cut)
  "Whether LINE of WHOLE is placed from text below the cut at CUT.
A brace in the first item of a list or a call opened on its construct's
line steps from that item where the bracket aligns its items, and from
the line where it hugs them (`ernest--aligns-p').  Which it does is read
from the code after the item's own bracket or brace: a comma and whether
it ends its line, or what carries the item on.  Where that code lies
below the cut, the buffer at the cut does not have it."
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
              (save-excursion
                (goto-char brace)
                (ernest--climb open)
                (while (and open (not found) (ernest--opened-here-p open))
                  (when (and (memq (ernest--bracket-kind open) '(list call))
                             (ernest--first-item-p open inner)
                             (ernest-typing-followed-below-p inner limit))
                    (setq found t))
                  (setq inner open
                        open (nth 1 (syntax-ppss open)))))))
          (setq brace (nth 1 (syntax-ppss brace))))
        found))))

(defun ernest-typing-followed-below-p (inner limit)
  "Whether the code after INNER's closing bracket begins at LIMIT or below.
A closing bracket there is not counted: the bracket around INNER closing
is what the buffer at the cut takes for granted."
  (let ((close (ignore-errors (scan-lists inner 1 0))))
    (and close
         (save-excursion
           (goto-char close)
           (forward-comment (buffer-size))
           (and (>= (point) limit)
                (not (eobp))
                (/= (syntax-class (syntax-after (point))) 5))))))

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
                     ;; a line whose brace a bracket aligns or hugs as code
                     ;; below the cut says has its place from text the cut
                     ;; removed, as a comment has; that too is the rule
                     (cl-loop for b in before
                              for a in (split-string (buffer-string) "\n")
                              for line from 1
                              unless (or (string= a b)
                                         (ernest-typing-read-below-p source line cut))
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
  (kill-emacs (if (zerop moved) 0 1)))

;;; typing.el ends here
