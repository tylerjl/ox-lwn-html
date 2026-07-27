;; * LWN HTML Exporter Tests

;; **** Helpers

(when (require 'undercover nil t)
  (undercover "*.el"
	      (:send-report nil)
	      (:report-file "lcov.info")
	      (:merge-report nil)
	      (:report-format 'lcov)))

(require 'ox-lwn-html)
(require 'coverage)

(defun org->html (org-markup &optional ext-plist)
  "Helper to convert org markup into parsed HTML structure."
  (with-temp-buffer
    (insert org-markup)
    (with-current-buffer
	(org-lwn-html-export-as-html nil nil nil t ext-plist)
      (libxml-parse-html-region))) )

(defun as-xml (xs)
  (pcase xs
    (`(,a . ,rest)
     `(,a nil ,@(mapcar (lambda (x) (if (listp x) (as-xml x) x)) rest)))
    (_ xs)))

(defun into-xml (tags)
  (as-xml `(html (body ,tags))))

;; **** Tests

(ert-deftest org-lwn-html-export-code ()
  (let ((expected (into-xml '(p "\nA " (tt "sample") " paragraph.")))
	(html (org->html "A ~sample~ paragraph.")))
    (should (equal html expected))))

(ert-deftest org-lwn-html-export-src-block ()
  (let ((expected (into-xml '(pre "\n    t\n")))
	(html (org->html "#+begin_src elisp\nt\n#+end_src")))
    (should (equal html expected))))

(ert-deftest org-lwn-html-export-image ()
  (let ((expected '(html nil (body nil (img ((src . "foo.png") (alt . "foo.png"))))))
	(html (org->html "[[file:foo.png]]")))
    (should (equal html expected))))

(ert-deftest org-lwn-html-export-link-fallback ()
  (let* ((href "https://www.example.com")
	 (expected `(html nil (body nil (p nil "\n" (a ((href . ,href)) ,href)))))
	 (html (org->html (format "[[%s]]" href))))
    (should (equal html expected))))

(ert-deftest org-lwn-html-export-image-caption ()
  (let ((expected '(html nil (body nil (img ((src . "foo.png") (alt . "bar"))))))
	(html (org->html "#+CAPTION: bar\n[[file:foo.png]]")))
    (should (equal html expected))))

(ert-deftest org-lwn-html-export-image-alt ()
  (let ((expected '(html nil (body nil (img ((src . "foo.png") (alt . "baz"))))))
	(html (org->html "#+ATTR_HTML: :alt baz\n[[file:foo.png]]")))
    (should (equal html expected))))

(ert-deftest org-lwn-html-export-image-precedence ()
  (let ((expected '(html nil (body nil (img ((src . "foo.png") (alt . "baz"))))))
	(html (org->html "#+CAPTION: quux\n#+ATTR_HTML: :alt baz\n[[file:foo.png]]")))
    (should (equal html expected))))

(ert-deftest org-lwn-html-export-headline ()
  (let ((expected (into-xml '(h2 "Headline")))
	(html (org->html "** Headline" '(:with-toc nil))))
    (should (equal html expected))))

(ert-deftest org-lwn-html-export-paragraph-q ()
  (let ((expected (into-xml '(p "\nA \"" (q "direct") "\" quote.")))
	(html (org->html "A \"\"direct\"\" quote.")))
    (should (equal html expected))))

(ert-deftest org-lwn-html-export-to-html-test ()
  (let* ((temp-file (make-temp-file "ox-lwn-html-test" nil ".html"))
	 (exported-file (with-temp-buffer
			  (org-mode)
			  (insert (format "#+EXPORT_FILE_NAME: %s\nExample." temp-file))
			  (org-lwn-html-export-to-html nil nil nil t)))
	 (html (with-temp-buffer
		 (insert-file-contents exported-file)
		 (libxml-parse-html-region))))
    (should (equal html (into-xml '(p "\nExample."))))))

(provide 't-ox-lwn-html)
