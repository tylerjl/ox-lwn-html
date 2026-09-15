;;; -*- lexical-binding: t; -*-
;; * LWN HTML Exporter Tests

;; **** Helpers

(when (require 'undercover nil t)
  (undercover "*.el"
	      (:send-report nil)
	      (:report-file "lcov.info")
	      (:merge-report nil)
	      (:report-format 'lcov)))

(require 'ox-lwn-html)
(require 'buttercup)
(require 'coverage)

(defun org->html (org-markup &optional ext-plist)
  "Helper to convert org markup into parsed HTML structure."
  (with-temp-buffer
    (insert org-markup)
    (let ((html-buffer (org-lwn-html-export-as-html nil nil nil t ext-plist)))
      (with-current-buffer html-buffer
	(goto-char (point-min))
	(while (re-search-forward "\n" nil t)
	  (replace-match "" nil nil))
	(list html-buffer (libxml-parse-html-region))))))

(buttercup-define-matcher :parses-into (org-text html-text)
  (let ((formatted (with-temp-buffer
                     (insert (concat "<html><body>"
                                     (funcall html-text)
                                     "</body></html>"))
                     (libxml-parse-xml-region)))
	(exported (org->html (funcall org-text) nil)))
    (cl-destructuring-bind (buf html) exported
      ;; Cleanup
      (when (buffer-live-p buf)
	(when-let ((win (get-buffer-window buf)))
	  (delete-window win))
	(kill-buffer buf))
      ;; Report
      (if (equal html formatted) t
	(cons nil (format "got %s, expected %s" html formatted))))))

(defun run-tests ()
  "Minor helper when running in emacs"
  (interactive)
  (let ((buttercup-suites nil))
    (buttercup-run t))
  (when-let ((buf (get-buffer "*Buttercup*")))
    (let ((win (get-buffer-window buf)))
      (when (not win)
	(setq win (split-window nil nil t))
	(set-window-buffer win buf)
	(set-window-dedicated-p win t)
	(select-window win)))))

;; **** Tests

(describe "ox-lwn-html"
  (describe "export-as"
    (describe "code"
      (describe "inline"
	(it "formats as tt"
	  (expect "A ~sample~ paragraph." :parses-into "<p>A <tt>sample</tt> paragraph.</p>")))
      (describe "inline src"
	(it "formats as tt"
	  (expect "Some src_emacs-lisp[:exports code]{nil} code" :parses-into "<p>Some <tt>nil</tt> code</p>")))
      (describe "block"
	(it "indents code <pre> tags"
	  (expect "#+begin_src elisp\nt\n#+end_src" :parses-into "<pre>    t</pre>")))
      (describe "literal"
	(it "indents literal <pre> tags"
	  (expect ": literal" :parses-into "<pre>    literal</pre>"))))
    (describe "verbatim"
      (it "formats as tt"
        (expect "A =sample= paragraph." :parses-into "<p>A <tt>sample</tt> paragraph.</p>")))
    (describe "link"
      (describe "fallback"
	:var ((link "https://www.example.com"))
	(it "constructs anchors"
	  (expect (format "[[%s]]" link) :parses-into (format "<p><a href=\"%s\">%s</a></p>" link link))))
      (describe "images"
	(it "populates alt and src"
	  (expect "[[file:foo.png]]" :parses-into "<img src=\"foo.png\" alt=\"foo.png\"/>"))
	(it "honors CAPTION"
	  (expect "#+CAPTION: bar\n[[file:foo.png]]" :parses-into "<img src=\"foo.png\" alt=\"bar\" />"))
	(it "honors :alt"
	  (expect "#+ATTR_HTML: :alt baz\n[[file:foo.png]]" :parses-into "<img src=\"foo.png\" alt=\"baz\" />"))
	(it "prefers :alt over CAPTION"
	  (expect "#+CAPTION: quux\n#+ATTR_HTML: :alt baz\n[[file:foo.png]]" :parses-into "<img src=\"foo.png\" alt=\"baz\" />"))))
    (describe "headlines"
      (it "renders headings at the right level"
	(expect "* Headline" :parses-into "<h4>Headline</h4>")
	(expect "** Headline" :parses-into "<h4>Headline</h4>")
	(expect "***** Headline" :parses-into "<h4>Headline</h4>")))
    (describe "quotes"
      (describe "inline"
	(it "converts double quotes into <q> tags"
	  (expect "A \"\"direct\"\" quote." :parses-into "<p>A \"<q>direct</q>\" quote.</p>")))
      (describe "block"
	(it "amends the css class without <p> tags"
	  (expect "#+begin_quote\nQuote\n#+end_quote" :parses-into "<blockquote class=\"bq\">Quote</blockquote>")))))
  (describe "export-to"
    (it "writes formatted files"
      (let* ((temp-file (make-temp-file "ox-lwn-html-test" nil ".html"))
	     (example "Example.")
	     (exported-file (with-temp-buffer
                              (org-mode)
                              (insert (format "#+EXPORT_FILE_NAME: %s\n%s" temp-file example))
                              (org-lwn-html-export-to-html nil nil nil t)))
	     (html (with-temp-buffer
		     (insert-file-contents exported-file)
		     (libxml-parse-html-region)))
	     (formatted (with-temp-buffer
                          (insert (format "<p>\n%s</p>" example))
                          (libxml-parse-html-region))))
	(expect html :to-equal formatted)))))

(provide 't-ox-lwn-html)
