# Feed recipe texts directly into emacs
set script-interpreter := [
	"emacs",
	"--quick",
	"--batch",
	"-L", ".",
	"-L", "tests",
	"-l", "buttercup",
	"-l", "buttercup-junit",
	"-l", "all.el",
	"-l"
]

[script]
[env("UNDERCOVER_FORCE", "true")]
test:
	(message "emacs %s" emacs-version)
	(let* ((buttercup-junit-result-file "tests/results.xml")
	       (passed (buttercup-junit--with-reporter (buttercup-run t))))
	  (kill-emacs (if (or (not passed) (my/undercover-check-coverage 100))
					   1 0)))
