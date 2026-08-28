;;;;   ./scripts/setup-client.sh && ros -l scripts/install.lisp
;;;;   ros -l scripts/run-tests.lisp

(load (merge-pathnames "bootstrap.lisp" *load-truename*))

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&TEST FAIL: ~A~%" c)
        (uiop:print-backtrace :condition c :stream *error-output*)
        (uiop:quit 1)))

(asdf:test-system "cl-stack-llm-tui")
(uiop:quit 0)
