;;; org-colview.el --- Column View in Org            -*- lexical-binding: t; -*-

;; Copyright (C) 2004-2016 Free Software Foundation, Inc.

;; Author: Carsten Dominik <carsten at orgmode dot org>
;; Keywords: outlines, hypermedia, calendar, wp
;; Homepage: http://orgmode.org
;;
;; This file is part of GNU Emacs.
;;
;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:

;; This file contains the column view for Org.

;;; Code:

(require 'cl-lib)
(require 'org)

(declare-function org-agenda-redo "org-agenda" ())
(declare-function org-agenda-do-context-action "org-agenda" ())
(declare-function org-clock-sum-today "org-clock" (&optional headline-filter))
(declare-function org-element-extract-element "org-element" (element))
(declare-function org-element-interpret-data "org-element" (data))
(declare-function org-element-map "org-element" (data types fun &optional info first-match no-recursion with-affiliated))
(declare-function org-element-parse-secondary-string "org-element" (string restriction &optional parent))
(declare-function org-element-restriction "org-element" (element))

(defvar org-agenda-columns-add-appointments-to-effort-sum)
(defvar org-agenda-columns-compute-summary-properties)
(defvar org-agenda-columns-show-summaries)
(defvar org-agenda-view-columns-initially)
(defvar org-inlinetask-min-level)


;;; Configuration

(defcustom org-columns-modify-value-for-display-function nil
  "Function that modifies values for display in column view.
For example, it can be used to cut out a certain part from a time stamp.
The function must take 2 arguments:

column-title    The title of the column (*not* the property name)
value           The value that should be modified.

The function should return the value that should be displayed,
or nil if the normal value should be used."
  :group 'org-properties
  :type '(choice (const nil) (function)))

(defcustom org-columns-summary-types nil
  "Alist between operators and summarize functions.

Each association follows the pattern (LABEL . SUMMARIZE) where

  LABEL is a string used in #+COLUMNS definition describing the
  summary type.  It can contain any character but \"}\".  It is
  case-sensitive.

  SUMMARIZE is a function called with two arguments.  The first
  argument is a non-empty list of values, as non-empty strings.
  The second one is a format string or nil.  It has to return
  a string summarizing the list of values.

Note that the return value can become one value for an higher
order summary, so the function is expected to handle its own
output.

Types defined in this variable take precedence over those defined
in `org-columns-summary-types-default', which see."
  :group 'org-properties
  :version "25.1"
  :package-version '(Org . "9.0")
  :type '(alist :key-type (string :tag "       Label")
		:value-type (function :tag "Summarize")))



;;; Column View

(defvar org-columns-overlays nil
  "Holds the list of current column overlays.")

(defvar org-columns--time 0.0
  "Number of seconds since the epoch, as a floating point number.")

(defvar-local org-columns-current-fmt nil
  "Local variable, holds the currently active column format.")
(defvar-local org-columns-current-fmt-compiled nil
  "Local variable, holds the currently active column format.
This is the compiled version of the format.")
(defvar-local org-columns-current-maxwidths nil
  "Loval variable, holds the currently active maximum column widths.")
(defvar org-columns-begin-marker (make-marker)
  "Points to the position where last a column creation command was called.")
(defvar org-columns-top-level-marker (make-marker)
  "Points to the position where current columns region starts.")

(defvar org-columns-map (make-sparse-keymap)
  "The keymap valid in column display.")

(defconst org-columns-summary-types-default
  '(("+"     . org-columns--summary-sum)
    ("$"     . org-columns--summary-currencies)
    ("X"     . org-columns--summary-checkbox)
    ("X/"    . org-columns--summary-checkbox-count)
    ("X%"    . org-columns--summary-checkbox-percent)
    ("max"   . org-columns--summary-max)
    ("mean"  . org-columns--summary-mean)
    ("min"   . org-columns--summary-min)
    (":"     . org-columns--summary-sum-times)
    (":max"  . org-columns--summary-max-time)
    (":mean" . org-columns--summary-mean-time)
    (":min"  . org-columns--summary-min-time)
    ("@max"  . org-columns--summary-max-age)
    ("@mean" . org-columns--summary-mean-age)
    ("@min"  . org-columns--summary-min-age)
    ("est+"  . org-columns--summary-estimate))
  "Map operators to summarize functions.
See `org-columns-summary-types' for details.")

(defun org-columns-content ()
  "Switch to contents view while in columns view."
  (interactive)
  (org-overview)
  (org-content))

(org-defkey org-columns-map "c" 'org-columns-content)
(org-defkey org-columns-map "o" 'org-overview)
(org-defkey org-columns-map "e" 'org-columns-edit-value)
(org-defkey org-columns-map "\C-c\C-t" 'org-columns-todo)
(org-defkey org-columns-map "\C-c\C-c" 'org-columns-set-tags-or-toggle)
(org-defkey org-columns-map "\C-c\C-o" 'org-columns-open-link)
(org-defkey org-columns-map "v" 'org-columns-show-value)
(org-defkey org-columns-map "q" 'org-columns-quit)
(org-defkey org-columns-map "r" 'org-columns-redo)
(org-defkey org-columns-map "g" 'org-columns-redo)
(org-defkey org-columns-map [left] 'backward-char)
(org-defkey org-columns-map "\M-b" 'backward-char)
(org-defkey org-columns-map "a" 'org-columns-edit-allowed)
(org-defkey org-columns-map "s" 'org-columns-edit-attributes)
(org-defkey org-columns-map "\M-f"
	    (lambda () (interactive) (goto-char (1+ (point)))))
(org-defkey org-columns-map [right]
	    (lambda () (interactive) (goto-char (1+ (point)))))
(org-defkey org-columns-map [down]
	    (lambda () (interactive)
	      (let ((col (current-column)))
		(beginning-of-line 2)
		(while (and (org-invisible-p2) (not (eobp)))
		  (beginning-of-line 2))
		(move-to-column col)
		(if (eq major-mode 'org-agenda-mode)
		    (org-agenda-do-context-action)))))
(org-defkey org-columns-map [up]
	    (lambda () (interactive)
	      (let ((col (current-column)))
		(beginning-of-line 0)
		(while (and (org-invisible-p2) (not (bobp)))
		  (beginning-of-line 0))
		(move-to-column col)
		(if (eq major-mode 'org-agenda-mode)
		    (org-agenda-do-context-action)))))
(org-defkey org-columns-map [(shift right)] 'org-columns-next-allowed-value)
(org-defkey org-columns-map "n" 'org-columns-next-allowed-value)
(org-defkey org-columns-map [(shift left)] 'org-columns-previous-allowed-value)
(org-defkey org-columns-map "p" 'org-columns-previous-allowed-value)
(org-defkey org-columns-map "<" 'org-columns-narrow)
(org-defkey org-columns-map ">" 'org-columns-widen)
(org-defkey org-columns-map [(meta right)] 'org-columns-move-right)
(org-defkey org-columns-map [(meta left)] 'org-columns-move-left)
(org-defkey org-columns-map [(shift meta right)] 'org-columns-new)
(org-defkey org-columns-map [(shift meta left)] 'org-columns-delete)
(dotimes (i 10)
  (org-defkey org-columns-map (number-to-string i)
	      `(lambda () (interactive)
		 (org-columns-next-allowed-value nil ,i))))

(easy-menu-define org-columns-menu org-columns-map "Org Column Menu"
  '("Column"
    ["Edit property" org-columns-edit-value t]
    ["Next allowed value" org-columns-next-allowed-value t]
    ["Previous allowed value" org-columns-previous-allowed-value t]
    ["Show full value" org-columns-show-value t]
    ["Edit allowed values" org-columns-edit-allowed t]
    "--"
    ["Edit column attributes" org-columns-edit-attributes t]
    ["Increase column width" org-columns-widen t]
    ["Decrease column width" org-columns-narrow t]
    "--"
    ["Move column right" org-columns-move-right t]
    ["Move column left" org-columns-move-left t]
    ["Add column" org-columns-new t]
    ["Delete column" org-columns-delete t]
    "--"
    ["CONTENTS" org-columns-content t]
    ["OVERVIEW" org-overview t]
    ["Refresh columns display" org-columns-redo t]
    "--"
    ["Open link" org-columns-open-link t]
    "--"
    ["Quit" org-columns-quit t]))

(defun org-columns--displayed-value (property value)
  "Return displayed value for PROPERTY in current entry.

VALUE is the real value of the property, as a string.

This function assumes `org-columns-current-fmt-compiled' is
initialized."
  (cond
   ((and (functionp org-columns-modify-value-for-display-function)
	 (funcall
	  org-columns-modify-value-for-display-function
	  (nth 1 (assoc property org-columns-current-fmt-compiled))
	  value)))
   ((equal property "ITEM")
    (concat (make-string (1- (org-current-level))
			 (if org-hide-leading-stars ?\s ?*))
	    "* "
	    (org-columns-compact-links value)))
   (value)))

(defun org-columns--collect-values (&optional agenda)
  "Collect values for columns on the current line.

When optional argument AGENDA is non-nil, assume the value is
meant for the agenda, i.e., caller is `org-agenda-columns'.

Return a list of triplets (PROPERTY VALUE DISPLAYED) suitable for
`org-columns--display-here'.

This function assumes `org-columns-current-fmt-compiled' is
initialized."
  (mapcar
   (lambda (spec)
     (let* ((p (car spec))
	    (v (or (cdr (assoc p (get-text-property (point) 'org-summaries)))
		   (org-entry-get (point) p 'selective t)
		   (and agenda
			;; Effort property is not defined.  Try to use
			;; appointment duration.
			org-agenda-columns-add-appointments-to-effort-sum
			(string= p (upcase org-effort-property))
			(get-text-property (point) 'duration)
			(org-propertize
			 (org-minutes-to-clocksum-string
			  (get-text-property (point) 'duration))
			 'face 'org-warning))
		   "")))
       (list p v (org-columns--displayed-value p v))))
   org-columns-current-fmt-compiled))

(defun org-columns--autowidth-alist (cache)
  "Derive the maximum column widths from the format and the cache.
Return an alist (PROPERTY . WIDTH), with PROPERTY as a string and
WIDTH as an integer greater than 0."
  (mapcar
   (lambda (spec)
     (pcase spec
       (`(,property ,name ,width . ,_)
	(if width (cons property width)
	  ;; No width is specified in the columns format.  Compute it
	  ;; by checking all possible values for PROPERTY.
	  (let ((width (length name)))
	    (dolist (entry cache (cons property width))
	      (let ((value (nth 2 (assoc property (cdr entry)))))
		(setq width (max (length value) width)))))))))
   org-columns-current-fmt-compiled))

(defun org-columns-new-overlay (beg end &optional string face)
  "Create a new column overlay and add it to the list."
  (let ((ov (make-overlay beg end)))
    (overlay-put ov 'face (or face 'secondary-selection))
    (org-overlay-display ov string face)
    (push ov org-columns-overlays)
    ov))

(defun org-columns--summarize (operator)
  "Return summary function associated to string OPERATOR."
  (cdr (or (assoc operator org-columns-summary-types)
	   (assoc operator org-columns-summary-types-default))))

(defun org-columns--overlay-text (value fmt width property original)
  "Return text "
  (format fmt
          (let ((v (org-columns-add-ellipses value width)))
            (pcase property
              ("PRIORITY"
               (propertize v 'face (org-get-priority-face original)))
              ("TAGS"
               (if (not org-tags-special-faces-re)
                   (propertize v 'face 'org-tag)
                 (replace-regexp-in-string
                  org-tags-special-faces-re
                  (lambda (m) (propertize m 'face (org-get-tag-face m)))
                  v nil nil 1)))
              ("TODO" (propertize v 'face (org-get-todo-face original)))
              (_ v)))))

(defun org-columns--display-here (columns &optional dateline)
  "Overlay the current line with column display.
COLUMNS is an alist (PROPERTY VALUE DISPLAYED).  Optional
argument DATELINE is non-nil when the face used should be
`org-agenda-column-dateline'."
  (save-excursion
    (beginning-of-line)
    (let* ((level-face (and (looking-at "\\(\\**\\)\\(\\* \\)")
			    (org-get-level-face 2)))
	   (ref-face (or level-face
			 (and (eq major-mode 'org-agenda-mode)
			      (org-get-at-bol 'face))
			 'default))
	   (color (list :foreground (face-attribute ref-face :foreground)))
	   (font (list :height (face-attribute 'default :height)
		       :family (face-attribute 'default :family)))
	   (face (list color font 'org-column ref-face))
	   (face1 (list color font 'org-agenda-column-dateline ref-face)))
      ;; Each column is an overlay on top of a character.  So there has
      ;; to be at least as many characters available on the line as
      ;; columns to display.
      (let ((columns (length org-columns-current-fmt-compiled))
	    (chars (- (line-end-position) (line-beginning-position))))
	(when (> columns chars)
	  (save-excursion
	    (end-of-line)
	    (let ((inhibit-read-only t))
	      (insert (make-string (- columns chars) ?\s))))))
      ;; Display columns.  Create and install the overlay for the
      ;; current column on the next character.
      (let ((limit (+ (- (length columns) 1) (line-beginning-position))))
	(dolist (column columns)
	  (pcase column
	    (`(,property ,original ,value)
	     (let* ((width (cdr (assoc property org-columns-current-maxwidths)))
		    (fmt (format (if (= (point) limit) "%%-%d.%ds |"
				   "%%-%d.%ds | ")
				 width width))
		    (ov (org-columns-new-overlay
			 (point) (1+ (point))
			 (org-columns--overlay-text
			  value fmt width property original)
			 (if dateline face1 face))))
	       (overlay-put ov 'keymap org-columns-map)
	       (overlay-put ov 'org-columns-key property)
	       (overlay-put ov 'org-columns-value original)
	       (overlay-put ov 'org-columns-value-modified value)
	       (overlay-put ov 'org-columns-format fmt)
	       (overlay-put ov 'line-prefix "")
	       (overlay-put ov 'wrap-prefix "")
	       (forward-char))))))
      ;; Make the rest of the line disappear.
      (let ((ov (org-columns-new-overlay (point) (line-end-position))))
	(overlay-put ov 'invisible t)
	(overlay-put ov 'keymap org-columns-map)
	(overlay-put ov 'line-prefix "")
	(overlay-put ov 'wrap-prefix ""))
      (let ((ov (make-overlay (1- (line-end-position))
			      (line-beginning-position 2))))
	(overlay-put ov 'keymap org-columns-map)
	(push ov org-columns-overlays))
      (org-with-silent-modifications
       (let ((inhibit-read-only t))
	 (put-text-property
	  (line-end-position 0)
	  (line-beginning-position 2)
	  'read-only
	  (substitute-command-keys
	   "Type \\<org-columns-map>\\[org-columns-edit-value] \
to edit property")))))))

(defun org-columns-add-ellipses (string width)
  "Truncate STRING with WIDTH characters, with ellipses."
  (cond
   ((<= (length string) width) string)
   ((<= width (length org-columns-ellipses))
    (substring org-columns-ellipses 0 width))
   (t (concat (substring string 0 (- width (length org-columns-ellipses)))
	      org-columns-ellipses))))

(defvar org-columns-full-header-line-format nil
  "The full header line format, will be shifted by horizontal scrolling." )
(defvar org-previous-header-line-format nil
  "The header line format before column view was turned on.")
(defvar org-columns-inhibit-recalculation nil
  "Inhibit recomputing of columns on column view startup.")
(defvar org-columns-flyspell-was-active nil
  "Remember the state of `flyspell-mode' before column view.
Flyspell-mode can cause problems in columns view, so it is turned off
for the duration of the command.")

(defvar header-line-format)
(defvar org-columns-previous-hscroll 0)

(defun org-columns--display-here-title ()
  "Overlay the newline before the current line with the table title."
  (interactive)
  (let ((title ""))
    (dolist (column org-columns-current-fmt-compiled)
      (pcase column
	(`(,property ,name . ,_)
	 (let* ((width (cdr (assoc property org-columns-current-maxwidths)))
		(fmt (format "%%-%d.%ds | " width width)))
	   (setq title (concat title (format fmt (or name property))))))))
    (setq-local org-previous-header-line-format header-line-format)
    (setq org-columns-full-header-line-format
	  (concat
	   (org-add-props " " nil 'display '(space :align-to 0))
	   (org-add-props (substring title 0 -1) nil 'face 'org-column-title)))
    (setq org-columns-previous-hscroll -1)
    (org-add-hook 'post-command-hook 'org-columns-hscoll-title nil 'local)))

(defun org-columns-hscoll-title ()
  "Set the `header-line-format' so that it scrolls along with the table."
  (sit-for .0001) ; need to force a redisplay to update window-hscroll
  (when (not (= (window-hscroll) org-columns-previous-hscroll))
    (setq header-line-format
	  (concat (substring org-columns-full-header-line-format 0 1)
		  (substring org-columns-full-header-line-format
			     (1+ (window-hscroll))))
	  org-columns-previous-hscroll (window-hscroll))
    (force-mode-line-update)))

(defvar org-colview-initial-truncate-line-value nil
  "Remember the value of `truncate-lines' across colview.")

;;;###autoload
(defun org-columns-remove-overlays ()
  "Remove all currently active column overlays."
  (interactive)
  (when (marker-buffer org-columns-begin-marker)
    (with-current-buffer (marker-buffer org-columns-begin-marker)
      (when (local-variable-p 'org-previous-header-line-format)
	(setq header-line-format org-previous-header-line-format)
	(kill-local-variable 'org-previous-header-line-format)
	(remove-hook 'post-command-hook 'org-columns-hscoll-title 'local))
      (move-marker org-columns-begin-marker nil)
      (move-marker org-columns-top-level-marker nil)
      (org-with-silent-modifications
       (mapc 'delete-overlay org-columns-overlays)
       (setq org-columns-overlays nil)
       (let ((inhibit-read-only t))
	 (remove-text-properties (point-min) (point-max) '(read-only t))))
      (when org-columns-flyspell-was-active
	(flyspell-mode 1))
      (when (local-variable-p 'org-colview-initial-truncate-line-value)
	(setq truncate-lines org-colview-initial-truncate-line-value)))))

(defun org-columns-compact-links (s)
  "Replace [[link][desc]] with [desc] or [link]."
  (while (string-match org-bracket-link-regexp s)
    (setq s (replace-match
	     (concat "[" (match-string (if (match-end 3) 3 1) s) "]")
	     t t s)))
  s)

(defun org-columns-show-value ()
  "Show the full value of the property."
  (interactive)
  (let ((value (get-char-property (point) 'org-columns-value)))
    (message "Value is: %s" (or value ""))))

(defvar org-agenda-columns-active) ;; defined in org-agenda.el

(defun org-columns-quit ()
  "Remove the column overlays and in this way exit column editing."
  (interactive)
  (org-with-silent-modifications
   (org-columns-remove-overlays)
   (let ((inhibit-read-only t))
     (remove-text-properties (point-min) (point-max) '(read-only t))))
  (when (eq major-mode 'org-agenda-mode)
    (setq org-agenda-columns-active nil)
    (message
     "Modification not yet reflected in Agenda buffer, use `r' to refresh")))

(defun org-columns-check-computed ()
  "Check if this column value is computed.
If yes, throw an error indicating that changing it does not make sense."
  (let ((val (get-char-property (point) 'org-columns-value)))
    (when (and (stringp val)
	       (get-char-property 0 'org-computed val))
      (error "This value is computed from the entry's children"))))

(defun org-columns-todo (&optional _arg)
  "Change the TODO state during column view."
  (interactive "P")
  (org-columns-edit-value "TODO"))

(defun org-columns-set-tags-or-toggle (&optional _arg)
  "Toggle checkbox at point, or set tags for current headline."
  (interactive "P")
  (if (string-match "\\`\\[[ xX-]\\]\\'"
		    (get-char-property (point) 'org-columns-value))
      (org-columns-next-allowed-value)
    (org-columns-edit-value "TAGS")))

(defvar org-agenda-overriding-columns-format nil
  "When set, overrides any other format definition for the agenda.
Don't set this, this is meant for dynamic scoping.")

(defun org-columns-edit-value (&optional key)
  "Edit the value of the property at point in column view.
Where possible, use the standard interface for changing this line."
  (interactive)
  (org-columns-check-computed)
  (let* ((col (current-column))
	 (key (or key (get-char-property (point) 'org-columns-key)))
	 (value (get-char-property (point) 'org-columns-value))
	 (bol (point-at-bol)) (eol (point-at-eol))
	 (pom (or (get-text-property bol 'org-hd-marker)
		  (point)))	     ; keep despite of compiler waring
	 (org-columns--time (float-time (current-time)))
	 nval eval allowed)
    (cond
     ((equal key "CLOCKSUM")
      (error "This special column cannot be edited"))
     ((equal key "ITEM")
      (setq eval `(org-with-point-at ,pom
		    (org-edit-headline))))
     ((equal key "TODO")
      (setq eval `(org-with-point-at ,pom
		    (call-interactively 'org-todo))))
     ((equal key "PRIORITY")
      (setq eval `(org-with-point-at ,pom
		    (call-interactively 'org-priority))))
     ((equal key "TAGS")
      (setq eval `(org-with-point-at ,pom
		    (let ((org-fast-tag-selection-single-key
			   (if (eq org-fast-tag-selection-single-key 'expert)
			       t org-fast-tag-selection-single-key)))
		      (call-interactively 'org-set-tags)))))
     ((equal key "DEADLINE")
      (setq eval `(org-with-point-at ,pom
		    (call-interactively 'org-deadline))))
     ((equal key "SCHEDULED")
      (setq eval `(org-with-point-at ,pom
		    (call-interactively 'org-schedule))))
     ((equal key "BEAMER_env")
      (setq eval `(org-with-point-at ,pom
		    (call-interactively 'org-beamer-select-environment))))
     (t
      (setq allowed (org-property-get-allowed-values pom key 'table))
      (if allowed
	  (setq nval (completing-read
		      "Value: " allowed nil
		      (not (get-text-property 0 'org-unrestricted
					      (caar allowed)))))
	(setq nval (read-string "Edit: " value)))
      (setq nval (org-trim nval))
      (when (not (equal nval value))
	(setq eval `(org-entry-put ,pom ,key ,nval)))))
    (when eval
      (cond
       ((equal major-mode 'org-agenda-mode)
	(org-columns-eval eval)
	;; The following let preserves the current format, and makes sure
	;; that in only a single file things need to be updated.
	(let* ((org-agenda-overriding-columns-format org-columns-current-fmt)
	       (buffer (marker-buffer pom))
	       (org-agenda-contributing-files
		(list (with-current-buffer buffer
			(buffer-file-name (buffer-base-buffer))))))
	  (org-agenda-columns)))
       (t
	(let ((inhibit-read-only t))
	  (org-with-silent-modifications
	   (remove-text-properties
	    (max (point-min) (1- bol)) eol '(read-only t)))
	  (org-columns-eval eval))
	(org-move-to-column col)
	(org-columns-update key))))))

(defun org-edit-headline () ; FIXME: this is not columns specific.  Make interactive?????  Use from agenda????
  "Edit the current headline, the part without TODO keyword, TAGS."
  (org-back-to-heading)
  (when (looking-at org-todo-line-regexp)
    (let ((pos (point))
	  (pre (buffer-substring (match-beginning 0) (match-beginning 3)))
	  (txt (match-string 3))
	  (post "")
	  txt2)
      (if (string-match (org-re "[ \t]+:[[:alnum:]:_@#%]+:[ \t]*$") txt)
	  (setq post (match-string 0 txt)
		txt (substring txt 0 (match-beginning 0))))
      (setq txt2 (read-string "Edit: " txt))
      (when (not (equal txt txt2))
	(goto-char pos)
	(insert pre txt2 post)
	(delete-region (point) (point-at-eol))
	(org-set-tags nil t)))))

(defun org-columns-edit-allowed ()
  "Edit the list of allowed values for the current property."
  (interactive)
  (let* ((pom (or (org-get-at-bol 'org-marker)
		  (org-get-at-bol 'org-hd-marker)
		  (point)))
	 (key (get-char-property (point) 'org-columns-key))
	 (key1 (concat key "_ALL"))
	 (allowed (org-entry-get pom key1 t))
	 nval)
    ;; FIXME: Cover editing TODO, TAGS etc in-buffer settings.????
    ;; FIXME: Write back to #+PROPERTY setting if that is needed.
    (setq nval (read-string "Allowed: " allowed))
    (org-entry-put
     (cond ((marker-position org-entry-property-inherited-from)
	    org-entry-property-inherited-from)
	   ((marker-position org-columns-top-level-marker)
	    org-columns-top-level-marker)
	   (t pom))
     key1 nval)))

(defun org-columns-eval (form)
  (let (hidep)
    (save-excursion
      (beginning-of-line 1)
      ;; `next-line' is needed here, because it skips invisible line.
      (condition-case nil (org-no-warnings (next-line 1)) (error nil))
      (setq hidep (org-at-heading-p 1)))
    (eval form)
    (and hidep (outline-hide-entry))))

(defun org-columns-previous-allowed-value ()
  "Switch to the previous allowed value for this column."
  (interactive)
  (org-columns-next-allowed-value t))

(defun org-columns-next-allowed-value (&optional previous nth)
  "Switch to the next allowed value for this column.
When PREVIOUS is set, go to the previous value.  When NTH is
an integer, select that value."
  (interactive)
  (org-columns-check-computed)
  (let* ((col (current-column))
	 (key (get-char-property (point) 'org-columns-key))
	 (value (get-char-property (point) 'org-columns-value))
	 (bol (point-at-bol)) (eol (point-at-eol))
	 (pom (or (get-text-property bol 'org-hd-marker)
		  (point)))	     ; keep despite of compiler waring
	 (allowed
	  (or (org-property-get-allowed-values pom key)
	      (and (member (nth 3 (assoc key org-columns-current-fmt-compiled))
			   '("X" "X/" "X%"))
		   '("[ ]" "[X]"))
	      (org-colview-construct-allowed-dates value)))
	 nval)
    (when (integerp nth)
      (setq nth (1- nth))
      (if (= nth -1) (setq nth 9)))
    (when (equal key "ITEM")
      (error "Cannot edit item headline from here"))
    (unless (or allowed (member key '("SCHEDULED" "DEADLINE" "CLOCKSUM")))
      (error "Allowed values for this property have not been defined"))
    (if (member key '("SCHEDULED" "DEADLINE" "CLOCKSUM"))
	(setq nval (if previous 'earlier 'later))
      (if previous (setq allowed (reverse allowed)))
      (cond
       (nth
	(setq nval (nth nth allowed))
	(if (not nval)
	    (error "There are only %d allowed values for property `%s'"
		   (length allowed) key)))
       ((member value allowed)
	(setq nval (or (car (cdr (member value allowed)))
		       (car allowed)))
	(if (equal nval value)
	    (error "Only one allowed value for this property")))
       (t (setq nval (car allowed)))))
    (cond
     ((equal major-mode 'org-agenda-mode)
      (org-columns-eval `(org-entry-put ,pom ,key ,nval))
      ;; The following let preserves the current format, and makes sure
      ;; that in only a single file things need to be updated.
      (let* ((org-agenda-overriding-columns-format org-columns-current-fmt)
	     (buffer (marker-buffer pom))
	     (org-agenda-contributing-files
	      (list (with-current-buffer buffer
		      (buffer-file-name (buffer-base-buffer))))))
	(org-agenda-columns)))
     (t
      (let ((inhibit-read-only t))
	(remove-text-properties (max (1- bol) (point-min)) eol '(read-only t))
	(org-columns-eval `(org-entry-put ,pom ,key ,nval)))
      (org-move-to-column col)
      (org-columns-update key)))))

(defun org-colview-construct-allowed-dates (s)
  "Construct a list of three dates around the date in S.
This respects the format of the time stamp in S, active or non-active,
and also including time or not.  S must be just a time stamp, no text
around it."
  (when (and s (string-match (concat "^" org-ts-regexp3 "$") s))
    (let* ((time (org-parse-time-string s 'nodefaults))
	   (active (equal (string-to-char s) ?<))
	   (fmt (funcall (if (nth 1 time) 'cdr 'car) org-time-stamp-formats))
	   time-before time-after)
      (unless active (setq fmt (concat "[" (substring fmt 1 -1) "]")))
      (setf (car time) (or (car time) 0))
      (setf (nth 1 time) (or (nth 1 time) 0))
      (setf (nth 2 time) (or (nth 2 time) 0))
      (setq time-before (copy-sequence time))
      (setq time-after (copy-sequence time))
      (setf (nth 3 time-before) (1- (nth 3 time)))
      (setf (nth 3 time-after) (1+ (nth 3 time)))
      (mapcar (lambda (x) (format-time-string fmt (apply 'encode-time x)))
	      (list time-before time time-after)))))

(defun org-columns-open-link (&optional arg)
  (interactive "P")
  (let ((value (get-char-property (point) 'org-columns-value)))
    (org-open-link-from-string value arg)))

;;;###autoload
(defun org-columns-get-format-and-top-level ()
  (let ((fmt (org-columns-get-format)))
    (org-columns-goto-top-level)
    fmt))

(defun org-columns-get-format (&optional fmt-string)
  (interactive)
  (let (fmt-as-property fmt)
    (when (condition-case nil (org-back-to-heading) (error nil))
      (setq fmt-as-property (org-entry-get nil "COLUMNS" t)))
    (setq fmt (or fmt-string fmt-as-property org-columns-default-format))
    (setq-local org-columns-current-fmt fmt)
    (org-columns-compile-format fmt)
    fmt))

(defun org-columns-goto-top-level ()
  "Move to the beginning of the column view area.
Also sets `org-columns-top-level-marker' to the new position."
  (goto-char
   (move-marker
    org-columns-top-level-marker
    (cond ((org-before-first-heading-p) (point-min))
	  ((org-entry-get nil "COLUMNS" t) org-entry-property-inherited-from)
	  (t (org-back-to-heading) (point))))))

;;;###autoload
(defun org-columns (&optional global columns-fmt-string)
  "Turn on column view on an Org mode file.

Column view applies to the whole buffer if point is before the
first headline.  Otherwise, it applies to the first ancestor
setting \"COLUMNS\" property.  If there is none, it defaults to
the current headline.  With a \\[universal-argument] prefix \
argument, turn on column
view for the whole buffer unconditionally.

When COLUMNS-FMT-STRING is non-nil, use it as the column format."
  (interactive "P")
  (org-columns-remove-overlays)
  (move-marker org-columns-begin-marker (point))
  (org-columns-goto-top-level)
  ;; Initialize `org-columns-current-fmt' and
  ;; `org-columns-current-fmt-compiled'.
  (let ((org-columns--time (float-time (current-time))))
    (org-columns-get-format columns-fmt-string)
    (unless org-columns-inhibit-recalculation (org-columns-compute-all))
    (save-excursion
      (save-restriction
	(when (and (not global) (org-at-heading-p))
	  (narrow-to-region (point) (org-end-of-subtree t t)))
	(when (assoc "CLOCKSUM" org-columns-current-fmt-compiled)
	  (org-clock-sum))
	(when (assoc "CLOCKSUM_T" org-columns-current-fmt-compiled)
	  (org-clock-sum-today))
	(let ((cache
	       ;; Collect contents of columns ahead of time so as to
	       ;; compute their maximum width.
	       (org-map-entries
		(lambda () (cons (point) (org-columns--collect-values)))
		nil nil (and org-columns-skip-archived-trees 'archive))))
	  (when cache
	    (setq-local org-columns-current-maxwidths
			(org-columns--autowidth-alist cache))
	    (org-columns--display-here-title)
	    (when (setq-local org-columns-flyspell-was-active
			      (org-bound-and-true-p flyspell-mode))
	      (flyspell-mode 0))
	    (unless (local-variable-p 'org-colview-initial-truncate-line-value)
	      (setq-local org-colview-initial-truncate-line-value
			  truncate-lines))
	    (setq truncate-lines t)
	    (dolist (entry cache)
	      (goto-char (car entry))
	      (org-columns--display-here (cdr entry)))))))))

(defun org-columns-new (&optional prop title width operator &rest _)
  "Insert a new column, to the left of the current column."
  (interactive)
  (let* ((automatic (org-string-nw-p prop))
	 (prop (or prop (completing-read
			 "Property: "
			 (mapcar #'list (org-buffer-property-keys t nil t)))))
	 (title (if automatic title
		  (read-string (format "Column title [%s]: " prop) prop)))
	 (width
	  ;; WIDTH may be nil, but if PROP is provided, assume this is
	  ;; the expected width.
	  (if automatic width
	    ;; Use `read-string' instead of `read-number' to allow
	    ;; empty width.
	    (let ((w (read-string "Column width: ")))
	      (and (org-string-nw-p w) (string-to-number w)))))
	 (operator
	  (if automatic operator
	    (org-string-nw-p
	     (completing-read
	      "Summary: "
	      (delete-dups
	       (mapcar (lambda (x) (list (car x)))
		       (append org-columns-summary-types
			       org-columns-summary-types-default)))
	      nil t))))
	 (summarize (and prop operator (org-columns--summarize operator)))
	 (edit
	  (and prop (assoc-string prop org-columns-current-fmt-compiled t))))
    (if edit (setcdr edit (list title width operator nil summarize))
      (push (list prop title width operator nil summarize)
	    (nthcdr (current-column) org-columns-current-fmt-compiled)))
    (org-columns-store-format)
    (org-columns-redo)))

(defun org-columns-delete ()
  "Delete the column at point from columns view."
  (interactive)
  (let* ((n (current-column))
	 (title (nth 1 (nth n org-columns-current-fmt-compiled))))
    (when (y-or-n-p
	   (format "Are you sure you want to remove column \"%s\"? " title))
      (setq org-columns-current-fmt-compiled
	    (delq (nth n org-columns-current-fmt-compiled)
		  org-columns-current-fmt-compiled))
      (org-columns-store-format)
      (org-columns-redo)
      (if (>= (current-column) (length org-columns-current-fmt-compiled))
	  (backward-char 1)))))

(defun org-columns-edit-attributes ()
  "Edit the attributes of the current column."
  (interactive)
  (let* ((n (current-column))
	 (info (nth n org-columns-current-fmt-compiled)))
    (apply 'org-columns-new info)))

(defun org-columns-widen (arg)
  "Make the column wider by ARG characters."
  (interactive "p")
  (let* ((n (current-column))
	 (entry (nth n org-columns-current-fmt-compiled))
	 (width (or (nth 2 entry)
		    (cdr (assoc (car entry) org-columns-current-maxwidths)))))
    (setq width (max 1 (+ width arg)))
    (setcar (nthcdr 2 entry) width)
    (org-columns-store-format)
    (org-columns-redo)))

(defun org-columns-narrow (arg)
  "Make the column narrower by ARG characters."
  (interactive "p")
  (org-columns-widen (- arg)))

(defun org-columns-move-right ()
  "Swap this column with the one to the right."
  (interactive)
  (let* ((n (current-column))
	 (cell (nthcdr n org-columns-current-fmt-compiled))
	 e)
    (when (>= n (1- (length org-columns-current-fmt-compiled)))
      (error "Cannot shift this column further to the right"))
    (setq e (car cell))
    (setcar cell (car (cdr cell)))
    (setcdr cell (cons e (cdr (cdr cell))))
    (org-columns-store-format)
    (org-columns-redo)
    (forward-char 1)))

(defun org-columns-move-left ()
  "Swap this column with the one to the left."
  (interactive)
  (let* ((n (current-column)))
    (when (= n 0)
      (error "Cannot shift this column further to the left"))
    (backward-char 1)
    (org-columns-move-right)
    (backward-char 1)))

(defun org-columns-store-format ()
  "Store the text version of the current columns format in appropriate place.
This is either in the COLUMNS property of the node starting the current column
display, or in the #+COLUMNS line of the current buffer."
  (let (fmt (cnt 0))
    (setq fmt (org-columns-uncompile-format org-columns-current-fmt-compiled))
    (setq-local org-columns-current-fmt fmt)
    (if (marker-position org-columns-top-level-marker)
	(save-excursion
	  (goto-char org-columns-top-level-marker)
	  (if (and (org-at-heading-p)
		   (org-entry-get nil "COLUMNS"))
	      (org-entry-put nil "COLUMNS" fmt)
	    (goto-char (point-min))
	    ;; Overwrite all #+COLUMNS lines....
	    (while (re-search-forward "^[ \t]*#\\+COLUMNS:.*" nil t)
	      (setq cnt (1+ cnt))
	      (replace-match (concat "#+COLUMNS: " fmt) t t))
	    (unless (> cnt 0)
	      (goto-char (point-min))
	      (or (org-at-heading-p t) (outline-next-heading))
	      (let ((inhibit-read-only t))
		(insert-before-markers "#+COLUMNS: " fmt "\n")))
	    (setq-local org-columns-default-format fmt))))))

(defun org-columns-update (property)
  "Recompute PROPERTY, and update the columns display for it."
  (org-columns-compute property)
  (org-with-wide-buffer
   (let ((p (upcase property)))
     (dolist (ov org-columns-overlays)
       (when (let ((key (overlay-get ov 'org-columns-key)))
	       (and key (equal key p) (overlay-start ov)))
	 (goto-char (overlay-start ov))
	 (let ((value (cdr
		       (assoc-string
			property
			(get-text-property (line-beginning-position)
					   'org-summaries)
			t))))
	   (when value
	     (let ((displayed (org-columns--displayed-value property value))
		   (format (overlay-get ov 'org-columns-format))
		   (width (cdr (assoc-string property
					     org-columns-current-maxwidths
					     t))))
	       (overlay-put ov 'org-columns-value value)
	       (overlay-put ov 'org-columns-value-modified displayed)
	       (overlay-put ov
			    'display
			    (org-columns--overlay-text
			     displayed format width property value))))))))))

(defun org-columns-redo ()
  "Construct the column display again."
  (interactive)
  (message "Recomputing columns...")
  (let ((line (org-current-line))
	(col (current-column)))
    (save-excursion
      (if (marker-position org-columns-begin-marker)
	  (goto-char org-columns-begin-marker))
      (org-columns-remove-overlays)
      (if (derived-mode-p 'org-mode)
	  (call-interactively 'org-columns)
	(org-agenda-redo)
	(call-interactively 'org-agenda-columns)))
    (org-goto-line line)
    (move-to-column col))
  (message "Recomputing columns...done"))

(defun org-columns-uncompile-format (compiled)
  "Turn the compiled columns format back into a string representation.
COMPILED is an alist, as returned by
`org-columns-compile-format', which see."
  (mapconcat
   (lambda (spec)
     (pcase spec
       (`(,prop ,title ,width ,op ,printf ,_)
	(concat "%"
		(and width (number-to-string width))
		prop
		(and title (not (equal prop title)) (format "(%s)" title))
		(cond ((not op) nil)
		      (printf (format "{%s;%s}" op printf))
		      (t (format "{%s}" op)))))))
   compiled " "))

(defun org-columns-compile-format (fmt)
  "Turn a column format string FMT into an alist of specifications.

The alist has one entry for each column in the format.  The elements of
that list are:
property    the property name, as an upper-case string
title       the title field for the columns, as a string
width       the column width in characters, can be nil for automatic width
operator    the summary operator, as a string, or nil
printf      a printf format for computed values, as a string, or nil
fun         the lisp function to compute summary values, derived from operator

This function updates `org-columns-current-fmt-compiled'."
  (setq org-columns-current-fmt-compiled nil)
  (let ((start 0))
    (while (string-match
	    "%\\([0-9]+\\)?\\([[:alnum:]_-]+\\)\\(?:(\\([^)]+\\))\\)?\
\\(?:{\\([^}]+\\)}\\)?\\s-*"
	    fmt start)
      (setq start (match-end 0))
      (let* ((width (and (match-end 1) (string-to-number (match-string 1 fmt))))
	     (prop (match-string-no-properties 2 fmt))
	     (title (or (match-string-no-properties 3 fmt) prop))
	     (operator (match-string-no-properties 4 fmt)))
	(push (if (not operator) (list (upcase prop) title width nil nil nil)
		(let (printf)
		  (when (string-match ";" operator)
		    (setq printf (substring operator (match-end 0)))
		    (setq operator (substring operator 0 (match-beginning 0))))
		  (let* ((summary
			  (or (org-columns--summarize operator)
			      (user-error "Cannot find %S summary function"
					  operator))))
		    (list (upcase prop) title width operator printf summary))))
	      org-columns-current-fmt-compiled)))
    (setq org-columns-current-fmt-compiled
	  (nreverse org-columns-current-fmt-compiled))))


;;;; Column View Summary

(defconst org-columns--duration-re
  (concat "[0-9.]+ *" (regexp-opt (mapcar #'car org-effort-durations)))
  "Regexp matching a duration.")

(defun org-columns--time-to-seconds (s)
  "Turn time string S into a number of seconds.
A time is expressed as HH:MM, HH:MM:SS, or with units defined in
`org-effort-durations'.  Plain numbers are considered as hours."
  (cond
   ((string-match "\\([0-9]+\\):\\([0-9]+\\)\\(?::\\([0-9]+\\)\\)?" s)
    (+ (* 3600 (string-to-number (match-string 1 s)))
       (* 60 (string-to-number (match-string 2 s)))
       (if (match-end 3) (string-to-number (match-string 3 s)) 0)))
   ((string-match-p org-columns--duration-re s)
    (* 60 (org-duration-string-to-minutes s)))
   (t (* 3600 (string-to-number s)))))

(defun org-columns--age-to-seconds (s)
  "Turn age string S into a number of seconds.
An age is either computed from a given time-stamp, or indicated
as days/hours/minutes/seconds."
  (cond
   ((string-match-p org-ts-regexp s)
    (floor
     (- org-columns--time
	(float-time (apply #'encode-time (org-parse-time-string s))))))
   ;; Match own output for computations in upper levels.
   ((string-match "\\([0-9]+\\)d \\([0-9]+\\)h \\([0-9]+\\)m \\([0-9]+\\)s" s)
    (+ (* 86400 (string-to-number (match-string 1 s)))
       (* 3600 (string-to-number (match-string 2 s)))
       (* 60 (string-to-number (match-string 3 s)))
       (string-to-number (match-string 4 s))))
   (t (user-error "Invalid age: %S" s))))

(defun org-columns--summary-apply-times (fun times)
  "Apply FUN to time values TIMES.
If TIMES contains any time value expressed as a duration, return
the result as a duration.  If it contains any H:M:S, use that
format instead.  Otherwise, use H:M format."
  (let* ((hms-flag nil)
	 (duration-flag nil)
	 (seconds
	  (apply fun
		 (mapcar
		  (lambda (time)
		    (cond
		     (duration-flag)
		     ((string-match-p org-columns--duration-re time)
		      (setq duration-flag t))
		     (hms-flag)
		     ((string-match-p "\\`[0-9]+:[0-9]+:[0-9]+\\'" time)
		      (setq hms-flag t)))
		    (org-columns--time-to-seconds time))
		  times))))
    (cond (duration-flag (org-minutes-to-clocksum-string (/ seconds 60.0)))
	  (hms-flag (format-seconds "%h:%.2m:%.2s" seconds))
	  (t (format-seconds "%h:%.2m" seconds)))))

;;;###autoload
(defun org-columns-compute (property)
  "Summarize the values of property PROPERTY hierarchically."
  (interactive)
  (let* ((lmax (if (org-bound-and-true-p org-inlinetask-min-level)
		   org-inlinetask-min-level
		 29))			;Hard-code deepest level.
	 (lvals (make-vector (1+ lmax) nil))
	 (spec (assoc-string property org-columns-current-fmt-compiled t))
	 (printf (nth 4 spec))
	 (summarize (nth 5 spec))
	 (level 0)
	 (inminlevel lmax)
	 (last-level lmax))
    (org-with-wide-buffer
     ;; Find the region to compute.
     (goto-char org-columns-top-level-marker)
     (goto-char (condition-case nil (org-end-of-subtree t) (error (point-max))))
     ;; Walk the tree from the back and do the computations.
     (while (re-search-backward
	     org-outline-regexp-bol org-columns-top-level-marker t)
       (unless (or (= level 0) (eq level inminlevel))
	 (setq last-level level))
       (setq level (org-reduced-level (org-outline-level)))
       (let* ((pos (match-beginning 0))
	      (value (org-entry-get nil property))
	      (value-set (org-string-nw-p value)))
	 (cond
	  ((< level last-level)
	   ;; Collect values from lower levels and inline tasks here
	   ;; and summarize them using SUMMARIZE.  Store them as text
	   ;; property.
	   (let* ((summary
		   (let ((all (append (and (/= last-level inminlevel)
					   (aref lvals last-level))
				      (aref lvals inminlevel))))
		     (and all (funcall summarize all printf)))))
	     (let* ((summaries-alist (get-text-property pos 'org-summaries))
		    (old (assoc-string property summaries-alist t))
		    (new
		     (cond
		      (summary (propertize summary 'org-computed t 'face 'bold))
		      (value-set value)
		      (t ""))))
	       (if old (setcdr old new)
		 (push (cons property new) summaries-alist)
		 (org-with-silent-modifications
		  (add-text-properties pos (1+ pos)
				       (list 'org-summaries summaries-alist)))))
	     ;; When PROPERTY is set in current node, but its value
	     ;; doesn't match the one computed, use the latter
	     ;; instead.
	     (when (and value summary (not (equal value summary)))
	       (org-entry-put nil property summary))
	     ;; Add current to current level accumulator.
	     (when (or summary value-set)
	       (push (or summary value) (aref lvals level)))
	     ;; Clear accumulators for deeper levels.
	     (cl-loop for l from (1+ level) to lmax do
		      (aset lvals l nil))))
	  (value-set (push value (aref lvals level)))
	  (t nil)))))))

(defun org-columns-compute-all ()
  "Compute all columns that have operators defined."
  (org-with-silent-modifications
   (remove-text-properties (point-min) (point-max) '(org-summaries t)))
  (let ((org-columns--time (float-time (current-time))))
    (dolist (spec org-columns-current-fmt-compiled)
      (pcase spec
	(`(,property ,_ ,_ ,operator . ,_)
	 (when operator (save-excursion (org-columns-compute property))))))))

(defun org-columns--summary-sum (values printf)
  "Compute the sum of VALUES.
When PRINTF is non-nil, use it to format the result."
  (format (or printf "%s") (apply #'+ (mapcar #'string-to-number values))))

(defun org-columns--summary-currencies (values _)
  "Compute the sum of VALUES, with two decimals."
  (format "%.2f" (apply #'+ (mapcar #'string-to-number values))))

(defun org-columns--summary-checkbox (check-boxes _)
  "Summarize CHECK-BOXES with a check-box."
  (let ((done (cl-count "[X]" check-boxes :test #'equal))
	(all (length check-boxes)))
    (cond ((= done all) "[X]")
	  ((> done 0) "[-]")
	  (t "[ ]"))))

(defun org-columns--summary-checkbox-count (check-boxes _)
  "Summarize CHECK-BOXES with a check-box cookie."
  (format "[%d/%d]"
	  (cl-count "[X]" check-boxes :test #'equal)
	  (length check-boxes)))

(defun org-columns--summary-checkbox-percent (check-boxes _)
  "Summarize CHECK-BOXES with a check-box percent."
  (format "[%d%%]"
	  (round (* 100.0 (cl-count "[X]" check-boxes :test #'equal))
		 (float (length check-boxes)))))

(defun org-columns--summary-min (values printf)
  "Compute the minimum of VALUES.
When PRINTF is non-nil, use it to format the result."
  (format (or printf "%s")
	  (apply #'min (mapcar #'string-to-number values))))

(defun org-columns--summary-max (values printf)
  "Compute the maximum of VALUES.
When PRINTF is non-nil, use it to format the result."
  (format (or printf "%s")
	  (apply #'max (mapcar #'string-to-number values))))

(defun org-columns--summary-mean (values printf)
  "Compute the mean of VALUES.
When PRINTF is non-nil, use it to format the result."
  (format (or printf "%s")
	  (/ (apply #'+ (mapcar #'string-to-number values))
	     (float (length values)))))

(defun org-columns--summary-sum-times (times _)
  "Sum TIMES."
  (org-columns--summary-apply-times #'+ times))

(defun org-columns--summary-min-time (times _)
  "Compute the minimum time among TIMES."
  (org-columns--summary-apply-times #'min times))

(defun org-columns--summary-max-time (times _)
  "Compute the maximum time among TIMES."
  (org-columns--summary-apply-times #'max times))

(defun org-columns--summary-mean-time (times _)
  "Compute the mean time among TIMES."
  (org-columns--summary-apply-times
   (lambda (&rest values) (/ (apply #'+ values) (float (length values))))
   times))

(defun org-columns--summary-min-age (ages _)
  "Compute the minimum time among TIMES."
  (format-seconds
   "%dd %.2hh %mm %ss"
   (apply #'min (mapcar #'org-columns--age-to-seconds ages))))

(defun org-columns--summary-max-age (ages _)
  "Compute the maximum time among TIMES."
  (format-seconds
   "%dd %.2hh %mm %ss"
   (apply #'max (mapcar #'org-columns--age-to-seconds ages))))

(defun org-columns--summary-mean-age (ages _)
  "Compute the minimum time among TIMES."
  (format-seconds
   "%dd %.2hh %mm %ss"
   (/ (apply #'+ (mapcar #'org-columns--age-to-seconds ages))
      (float (length ages)))))

(defun org-columns--summary-estimate (estimates printf)
  "Combine a list of estimates, using mean and variance.
The mean and variance of the result will be the sum of the means
and variances (respectively) of the individual estimates."
  (let ((mean 0)
        (var 0))
    (dolist (e estimates)
      (pcase (mapcar #'string-to-number (split-string e "-"))
	(`(,low ,high)
	 (let ((m (/ (+ low high) 2.0)))
	   (cl-incf mean m)
	   (cl-incf var (- (/ (+ (* low low) (* high high)) 2.0) (* m m)))))
	(`(,value) (cl-incf mean value))))
    (let ((sd (sqrt var)))
      (format "%s-%s"
	      (format (or printf "%.0f") (- mean sd))
	      (format (or printf "%.0f") (+ mean sd))))))



;;; Dynamic block for Column view

(defun org-columns--capture-view (maxlevel skip-empty format local)
  "Get the column view of the current buffer.

MAXLEVEL sets the level limit.  SKIP-EMPTY tells whether to skip
empty rows, an empty row being one where all the column view
specifiers but ITEM are empty.  FORMAT is a format string for
columns, or nil.  When LOCAL is non-nil, only capture headings in
current subtree.

This function returns a list containing the title row and all
other rows.  Each row is a list of fields, as strings, or
`hline'."
  (org-columns (not local) format)
  (goto-char org-columns-top-level-marker)
  (let ((columns (length org-columns-current-fmt-compiled))
	(has-item (assoc "ITEM" org-columns-current-fmt-compiled))
	table)
    (org-map-entries
     (lambda ()
       (when (get-char-property (point) 'org-columns-key)
	 (let (row)
	   (dotimes (i columns)
	     (let* ((col (+ (line-beginning-position) i))
		    (p (get-char-property col 'org-columns-key)))
	       (push (org-quote-vert
		      (get-char-property col
					 (if (string= p "ITEM")
					     'org-columns-value
					   'org-columns-value-modified)))
		     row)))
	   (unless (and skip-empty
			(let ((r (delete-dups (remove "" row))))
			  (or (null r) (and has-item (= (length r) 1)))))
	     (push (cons (org-reduced-level (org-current-level)) (nreverse row))
		   table)))))
     (and maxlevel (format "LEVEL<=%d" maxlevel))
     (and local 'tree)
     'archive 'comment)
    (org-columns-quit)
    ;; Add column titles and a horizontal rule in front of the table.
    (cons (mapcar #'cadr org-columns-current-fmt-compiled)
	  (cons 'hline (nreverse table)))))

(defun org-columns--clean-item (item)
  "Remove sensitive contents from string ITEM.
This includes objects that may not be duplicated within
a document, e.g., a target, or those forbidden in tables, e.g.,
an inline src-block."
  (let ((data (org-element-parse-secondary-string
	       item (org-element-restriction 'headline))))
    (org-element-map data
	'(footnote-reference inline-babel-call inline-src-block target
			     radio-target statistics-cookie)
      #'org-element-extract-element)
    (org-no-properties (org-element-interpret-data data))))

;;;###autoload
(defun org-dblock-write:columnview (params)
  "Write the column view table.
PARAMS is a property list of parameters:

:id       the :ID: property of the entry where the columns view
	  should be built.  When the symbol `local', call locally.
	  When `global' call column view with the cursor at the beginning
	  of the buffer (usually this means that the whole buffer switches
	  to column view).  When \"file:path/to/file.org\", invoke column
	  view at the start of that file.  Otherwise, the ID is located
	  using `org-id-find'.
:hlines   When t, insert a hline before each item.  When a number, insert
	  a hline before each level <= that number.
:indent   When non-nil, indent each ITEM field according to its level.
:vlines   When t, make each column a colgroup to enforce vertical lines.
:maxlevel When set to a number, don't capture headlines below this level.
:skip-empty-rows
	  When t, skip rows where all specifiers other than ITEM are empty.
:width    apply widths specified in columns format using <N> specifiers.
:format   When non-nil, specify the column view format to use."
  (let ((table
	 (let ((id (plist-get params :id))
	       view-file view-pos)
	   (pcase id
	     (`global nil)
	     ((or `local `nil) (setq view-pos (point)))
	     ((and (let id-string (format "%s" id))
		   (guard (string-match "^file:\\(.*\\)" id-string)))
	      (setq view-file (match-string-no-properties 1 id-string))
	      (unless (file-exists-p view-file)
		(user-error "No such file: %S" id-string)))
	     ((and (let idpos (org-find-entry-with-id id)) idpos)
	      (setq view-pos idpos))
	     ((let `(,filename . ,position) (org-id-find id))
	      (setq view-file filename)
	      (setq view-pos position))
	     (_ (user-error "Cannot find entry with :ID: %s" id)))
	   (with-current-buffer (if view-file (get-file-buffer view-file)
				  (current-buffer))
	     (org-with-wide-buffer
	      (when view-pos (goto-char view-pos))
	      (org-columns--capture-view (plist-get params :maxlevel)
					 (plist-get params :skip-empty-rows)
					 (plist-get params :format)
					 view-pos))))))
    (when table
      ;; Prune level information from the table.  Also normalize
      ;; headings: remove stars, add indentation entities, if
      ;; required, and possibly precede some of them with a horizontal
      ;; rule.
      (let ((item-index
	     (let ((p (assoc "ITEM" org-columns-current-fmt-compiled)))
	       (and p (cl-position p
				   org-columns-current-fmt-compiled
				   :test #'equal))))
	    (hlines (plist-get params :hlines))
	    (indent (plist-get params :indent))
	    new-table)
	;; Copy header and first rule.
	(push (pop table) new-table)
	(push (pop table) new-table)
	(dolist (row table (setq table (nreverse new-table)))
	  (let ((level (car row)))
	    (when (and (not (eq (car new-table) 'hline))
		       (or (eq hlines t)
			   (and (numberp hlines) (<= level hlines))))
	      (push 'hline new-table))
	    (when item-index
	      (let ((item (org-columns--clean-item (nth item-index (cdr row)))))
		(setf (nth item-index (cdr row))
		      (if (and indent (> level 1))
			  (concat "\\_" (make-string (* 2 (1- level)) ?\s) item)
			item))))
	    (push (cdr row) new-table))))
      (when (plist-get params :width)
	(setq table
	      (append table
		      (list
		       (mapcar (lambda (spec)
				 (let ((w (nth 2 spec)))
				   (if w (format "<%d>" (max 3 w)) "")))
			       org-columns-current-fmt-compiled)))))
      (when (plist-get params :vlines)
	(setq table
	      (let ((size (length org-columns-current-fmt-compiled)))
		(append (mapcar (lambda (x) (if (eq 'hline x) x (cons "" x)))
				table)
			(list (cons "/" (make-list size "<>")))))))
      (let ((content-lines (org-split-string (plist-get params :content) "\n"))
	    recalc)
	;; Insert affiliated keywords before the table.
	(when content-lines
	  (while (string-match-p "\\`[ \t]*#\\+" (car content-lines))
	    (insert (pop content-lines) "\n")))
	(save-excursion
	  ;; Insert table at point.
	  (insert
	   (mapconcat (lambda (row)
			(if (eq row 'hline) "|-|"
			  (format "|%s|" (mapconcat #'identity row "|"))))
		      table
		      "\n"))
	  ;; Insert TBLFM lines following table.
	  (let ((case-fold-search t))
	    (dolist (line content-lines)
	      (when (string-match-p "\\`[ \t]*#\\+TBLFM:" line)
		(insert "\n" line)
		(unless recalc (setq recalc t))))))
	(when recalc (org-table-recalculate 'all t))
	(org-table-align)))))

;;;###autoload
(defun org-columns-insert-dblock ()
  "Create a dynamic block capturing a column view table."
  (interactive)
  (let ((id (completing-read
	     "Capture columns (local, global, entry with :ID: property) [local]: "
	     (append '(("global") ("local"))
		     (mapcar #'list (org-property-values "ID"))))))
    (org-create-dblock
     (list :name "columnview"
	   :hlines 1
	   :id (cond ((string= id "global") 'global)
		     ((member id '("" "local")) 'local)
		     (id)))))
  (org-update-dblock))

(define-obsolete-function-alias 'org-insert-columns-dblock
  'org-columns-insert-dblock "Org 9.0")



;;; Column view in the agenda

;;;###autoload
(defun org-agenda-columns ()
  "Turn on or update column view in the agenda."
  (interactive)
  (org-columns-remove-overlays)
  (move-marker org-columns-begin-marker (point))
  (let ((org-columns--time (float-time (current-time)))
	(fmt
	 (cond
	  ((org-bound-and-true-p org-agenda-overriding-columns-format))
	  ((let ((m (org-get-at-bol 'org-hd-marker)))
	     (and m
		  (or (org-entry-get m "COLUMNS" t)
		      (with-current-buffer (marker-buffer m)
			org-columns-default-format)))))
	  ((and (local-variable-p 'org-columns-current-fmt)
		org-columns-current-fmt))
	  ((let ((m (next-single-property-change (point-min) 'org-hd-marker)))
	     (and m
		  (let ((m (get-text-property m 'org-hd-marker)))
		    (or (org-entry-get m "COLUMNS" t)
			(with-current-buffer (marker-buffer m)
			  org-columns-default-format))))))
	  (t org-columns-default-format))))
    (setq-local org-columns-current-fmt fmt)
    (org-columns-compile-format fmt)
    (when org-agenda-columns-compute-summary-properties
      (org-agenda-colview-compute org-columns-current-fmt-compiled))
    (save-excursion
      ;; Collect properties for each headline in current view.
      (goto-char (point-min))
      (let (cache)
	(while (not (eobp))
	  (let ((m (or (org-get-at-bol 'org-hd-marker)
		       (org-get-at-bol 'org-marker))))
	    (when m
	      (push (cons (line-beginning-position)
			  (org-with-point-at m
			    (org-columns--collect-values 'agenda)))
		    cache)))
	  (forward-line))
	(when cache
	  (setq-local org-columns-current-maxwidths
		      (org-columns--autowidth-alist cache))
	  (org-columns--display-here-title)
	  (when (setq-local org-columns-flyspell-was-active
			    (org-bound-and-true-p flyspell-mode))
	    (flyspell-mode 0))
	  (dolist (entry cache)
	    (goto-char (car entry))
	    (org-columns--display-here (cdr entry)))
	  (when org-agenda-columns-show-summaries
	    (org-agenda-colview-summarize cache)))))))

(defun org-agenda-colview-summarize (cache)
  "Summarize the summarizable columns in column view in the agenda.
This will add overlays to the date lines, to show the summary for each day."
  (let ((fmt (mapcar
	      (lambda (spec)
		(pcase spec
		  (`(,property ,title ,width . ,_)
		   (if (member property '("CLOCKSUM" "CLOCKSUM_T"))
		       (let ((summarize (org-columns--summarize ":")))
			 (list property title width ":" nil summarize))
		     spec))))
	      org-columns-current-fmt-compiled))
	entries)
    ;; Ensure there's at least one summation column.
    (when (cl-some (lambda (spec) (nth 3 spec)) fmt)
      (goto-char (point-max))
      (while (not (bobp))
	(when (or (get-text-property (point) 'org-date-line)
		  (eq (get-text-property (point) 'face)
		      'org-agenda-structure))
	  ;; OK, this is a date line that should be used.
	  (let (rest)
	    (dolist (c cache (setq cache rest))
	      (if (> (car c) (point))
		  (push c entries)
		(push c rest))))
	  ;; Now ENTRIES contains entries below the current one.
	  ;; CACHE is the rest.  Compute the summaries for the
	  ;; properties we want, set nil properties for the rest.
	  (when (setq entries (mapcar 'cdr entries))
	    (org-columns--display-here
	     (mapcar
	      (lambda (spec)
		(pcase spec
		  (`("ITEM" . ,_)
		   ;; Replace ITEM with current date.  Preserve
		   ;; properties for fontification.
		   (let ((date (buffer-substring
				(line-beginning-position)
				(line-end-position))))
		     (list "ITEM" date date)))
		  (`(,prop ,_ ,_ nil . ,_) (list prop "" ""))
		  (`(,prop ,_ ,_ ,_ ,printf ,summarize)
		   (let* ((values
			   ;; Use real values for summary, not those
			   ;; prepared for display.
			   (delq nil
				 (mapcar
				  (lambda (e)
				    (org-string-nw-p (nth 1 (assoc prop e))))
				  entries)))
			  (final (if values (funcall summarize values printf)
				   "")))
		     (unless (equal final "")
		       (put-text-property 0 (length final) 'face 'bold final))
		     (list prop final final)))))
	      fmt)
	     'dateline)
	    (setq-local org-agenda-columns-active t)))
	(forward-line -1)))))

(defun org-agenda-colview-compute (fmt)
  "Compute the relevant columns in the contributing source buffers."
  (let ((files org-agenda-contributing-files)
	(org-columns-begin-marker (make-marker))
	(org-columns-top-level-marker (make-marker)))
    (dolist (f files)
      (let ((b (find-buffer-visiting f)))
	(with-current-buffer (or (buffer-base-buffer b) b)
	  (org-with-wide-buffer
	   (org-with-silent-modifications
	    (remove-text-properties (point-min) (point-max) '(org-summaries t)))
	   (goto-char (point-min))
	   (org-columns-get-format-and-top-level)
	   (dolist (spec fmt)
	     (let ((prop (car spec)))
	       (cond
		((equal prop "CLOCKSUM") (org-clock-sum))
		((equal prop "CLOCKSUM_T") (org-clock-sum-today))
		((and (nth 3 spec)
		      (let ((a (assoc prop org-columns-current-fmt-compiled)))
			(equal (nth 3 a) (nth 3 spec))))
		 (org-columns-compute prop)))))))))))


(provide 'org-colview)

;;; org-colview.el ends here
