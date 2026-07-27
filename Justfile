# Feed recipe texts directly into emacs
set script-interpreter := [
	"emacs",
	"--batch",
	"-L", ".", "-L", "tests",
	"-l", "all.el", "-l"
]

[script]
[env("UNDERCOVER_FORCE", "true")]
test:
	(message "emacs %s" emacs-version)
	(let ((failures (ert-stats-completed-unexpected (ert-run-tests-batch t))))
	  (kill-emacs (if (or (not (zerop failures))
	                      (my/undercover-check-coverage 100))
					   1 0)))
