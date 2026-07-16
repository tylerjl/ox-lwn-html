;; * LWN HTML Exporter Tests

;; **** Helpers

(require 'ox-lwn-html)

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

(provide 't-ox-lwn-html)
