;;; ox-lwn-html.el --- LWN-compatible HTML Back-End for Org Export Engine -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Tyler Langlois

;; Author: Tyler Langlois
;; Keywords: org, html

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Implements a backend derived from the basic HTML exporter that
;; honors the contribution guidelilnes for LWN article submissions.

;;; Code:

(require 'ox)
(require 'ox-html)

;;; User-Configurable Variables

(defgroup org-export-lwn-html nil
  "Options specific to LWN HTML export back-end."
  :tag "Org LWN HTML"
  :group 'org-export
  :prefix "org-lwn-html-"
  :version "30.2"
  :package-version '(Org . "9.8.7"))

(defcustom org-lwn-html-hlevel 4
  "Default heading level that headlines will scale to upon export"
  :type 'integer)

;;; Define Back-End

(org-export-define-derived-backend 'lwn-html 'html
  :menu-entry
  '(?L "LWN Compatible HTML export"
       ((?H "To temporary HTML buffer" org-lwn-html-export-as-html)
        (?h "To HTML file" org-lwn-html-export-to-html)
        (?o "To HTML file and open"
            (lambda (a s v b)
              (org-open-file (org-lwn-html-export-to-html a s v b))))))
  :translate-alist '((code . org-lwn-html-code)
                     (src-block . org-lwn-html-src-block)
                     (inline-src-block . org-lwn-html-code)
                     (fixed-width . org-lwn-html-src-block)
                     (link . org-lwn-html-link)
                     (headline . org-lwn-html-headline)
                     (paragraph . org-lwn-html-paragraph)
                     (quote-block . org-lwn-html-quote-block)
                     (section . org-lwn-html-section)
                     (verbatim . org-lwn-html-code)))

;;; Transcode Functions

;;;; Inline Code

(defun org-lwn-html-code (code contents info)
  "Format inline literals with tt rather than code tags."
  (format "<tt>%s</tt>"
          (org-html-encode-plain-text
           (org-element-property :value code))))

;;;; Src Block

(defun org-lwn-html-src-block (src-block _contents _info)
  "Strip away enclosing tags from source blocks, wrap in pre tags, and
indent with spacing per guidelines."
  (let* ((code (string-trim-right
                (org-html-encode-plain-text
                 (org-element-property :value src-block))))
	 (indented (replace-regexp-in-string "^" "    " code)))
    (format "<pre>\n%s\n</pre>" indented)))

;;;; Links

(defun org-lwn-html-link (link desc info)
  "Translate links with special treatment for standalone images.

For anything not single-file links, pass along to upstream org-html-link.

Otherwise, collapse potential alt text from HTML alt, CAPTION, or buffer
filename."
  (if (org-export-inline-image-p
       link (plist-get info :html-inline-image-rules))
      (let* ((path (org-element-property :path link))
	     ;; CAPTION is affiliated with the containing paragraph,
	     ;; rather than the link object itself.
	     (paragraph (org-element-lineage link '(paragraph) t))
	     (attrs (and paragraph
                         (org-export-read-attribute :attr_html paragraph)))
	     (caption (and paragraph
                           (org-export-get-caption paragraph)))
	     (caption-text
	      (and caption
		   (string-trim
		    (org-export-data-with-backend
		     caption 'ascii info))))
	     (alt (or (plist-get attrs :alt)
		      caption-text
		      desc
		      (file-name-nondirectory path))))
	(format "<img src=\"%s\" alt=\"%s\" />\n"
		(org-html-encode-plain-text (org-export-file-uri path))
		(org-html-encode-plain-text alt)))
    (org-html-link link desc info)))

;;;; Paragraph

(defun org-lwn-html--unwrap-q (text)
  (replace-regexp-in-string
   (rx ?\" ?\" (group (+ (not (any ?\" ?\n)))) ?\" ?\")
   (rx ?\" "<q>" (backref 1) "</q>" ?\")
   text))

(defun org-lwn-html-paragraph (paragraph contents info)
  "Export standalone images without paragraph or figure wrappers."
  (let ((wrapped-q (org-lwn-html--unwrap-q contents)))
    (if (org-html-standalone-image-p paragraph info)
	wrapped-q
      (if (eq (org-element-type (org-export-get-parent paragraph)) 'quote-block)
	  contents
	(->> (string-fill (org-html-paragraph paragraph wrapped-q info) 80)
	     (replace-regexp-in-string (rx "<p>" (+ blank)) "<p>")
	     (replace-regexp-in-string (rx (+ blank) "</p>") "</p>"))))))

;;;; Quotes

(defun org-lwn-html-quote-block (_quote-block contents _info)
  "Export QUOTE-BLOCK as a bare blockquote with class bq."
  (format "<blockquote class=\"bq\">\n%s</blockquote>" contents))

;;;; Section

(defun org-lwn-html-section (_section contents _info)
  "Simple section formatting without wrapping div tags."
  contents)

;;;; Headline

(defun org-lwn-html-headline (headline contents info)
  "Render HEADLINE as bare <hN> plus contents, no wrapper div, no id."
  (let* ((level (org-export-get-relative-level headline info))
         ;; top-level org heading -> this HTML level
         ;; e.g. set org-html-toplevel-hlevel to 4 for <h4>
         (hlevel (+ (1- (plist-get info :html-toplevel-hlevel))
                    level))
         ;; clamp to valid HTML heading range
         (hlevel (max 1 (min 6 hlevel)))
         (text (org-export-data (org-element-property :title headline) info)))
    (format "\n<h%d>%s</h%d>\n\n%s" hlevel text hlevel (or contents ""))))

;;; Interactive functions

;;;###autoload
(defun org-lwn-html-export-as-html (&optional async subtreep visible-only body-only ext-plist)
  "Export current buffer to an LWN-compatible temporary HTML buffer.

If narrowing is active in the current buffer, only export its
narrowed part.

If a region is active, export that region.

A non-nil optional argument ASYNC means the process should happen
asynchronously.  The resulting buffer should be accessible
through the `org-export-stack' interface.

When optional argument SUBTREEP is non-nil, export the sub-tree
at point, extracting information from the headline properties
first.

When optional argument VISIBLE-ONLY is non-nil, don't export
contents of hidden elements.

Export is done in a buffer named \"*Org LWN HTML Export*\", which will
be displayed when `org-export-show-temporary-export-buffer' is
non-nil."
  (interactive)
  (let ((org-export-with-toc nil)
        (org-html-htmlize-output-type nil)
	(org-html-toplevel-hlevel org-lwn-html-hlevel))
    (org-export-to-buffer 'lwn-html "*Org LWN HTML Export*"
      async subtreep visible-only body-only ext-plist
      (lambda () (html-mode)))))

;;;###autoload
(defun org-lwn-html-export-to-html (&optional async subtreep visible-only body-only ext-plist)
  "Export current buffer to an LWN-compatible HTML file.

If narrowing is active in the current buffer, only export its
narrowed part.

If a region is active, export that region.

A non-nil optional argument ASYNC means the process should happen
asynchronously.  The resulting file should be accessible through
the `org-export-stack' interface.

When optional argument SUBTREEP is non-nil, export the sub-tree
at point, extracting information from the headline properties
first.

When optional argument VISIBLE-ONLY is non-nil, don't export
contents of hidden elements.

Return output file's name."
  (interactive)
  (let ((outfile (org-export-output-file-name ".html" subtreep))
        (org-export-with-toc nil)
	(org-html-htmlize-output-type nil)
	(org-html-toplevel-hlevel org-lwn-html-hlevel))
    (org-export-to-file 'lwn-html outfile
      async subtreep visible-only body-only ext-plist)))

(provide 'ox-lwn-html)

;;; ox-lwn-html.el ends here
