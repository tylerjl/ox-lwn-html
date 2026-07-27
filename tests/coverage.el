(defun coverage-render-summary (covered total minimum)
  "Return a GitHub-flavored Markdown coverage summary."
  (let* ((percent (/ (* 100.0 covered) total))
         (passed (>= (* 100 covered) (* minimum total))))
    (format
     (concat
      "## Test Coverage\n\n"
      "| Result | Coverage | Lines covered | Required |\n"
      "|:------:|---------:|--------------:|---------:|\n"
      "| %s | %.2f%% | %d / %d | %.2f%% |\n\n")
     (if passed "✅ Pass" "❌ Fail")
     percent covered total minimum)))

(defun coverage-write-summary (markdown)
  "Append MARKDOWN to the GitHub Actions job summary, when available."
  (when-let ((path (getenv "GITHUB_STEP_SUMMARY")))
    (write-region markdown nil path 'append 'silent)))

(defun my/undercover-check-coverage (minimum)
  "Fail when aggregate line coverage is below MINIMUM percent."
  (undercover--collect-files-coverage undercover--files)

  (let ((covered 0)
        (total 0))
    (maphash
     (lambda (_file statistics)
       (maphash
        (lambda (_line count)
          (cl-incf total)
          (unless (zerop count)
            (cl-incf covered)))
        statistics))
     undercover--files-coverage-statistics)

    (when (zerop total)
      (error "Undercover collected no coverage data"))

    (let ((percent (/ (* 100.0 covered) total)))
      (message "Line coverage: %.2f%% (%d/%d); required: %.2f%%"
               percent covered total minimum)

      (coverage-write-summary (coverage-render-summary covered total minimum))

      (when (< (* 100 covered) (* minimum total))
        (error "Coverage %.2f%% is below required %.2f%%"
               percent minimum)))))

(provide 'coverage)
