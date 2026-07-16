# Feed recipe texts directly into emacs
set script-interpreter := [
	"emacs",
	"--batch",
	"-L", ".", "-L", "tests",
	"-l", "all.el", "-l"
]

[script]
test:
	(message "emacs %s" emacs-version)
	(ert-run-tests-batch-and-exit)
