;;;; Offline mock canary (no LM Studio, no libvllm).
;;;;   ./scripts/setup-client.sh && ros -l scripts/install.lisp
;;;;   ros -l scripts/run-mock.lisp

(load (merge-pathnames "bootstrap.lisp" *load-truename*))

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&MOCK FAIL: ~A~%" c)
        (uiop:print-backtrace :condition c :stream *error-output*)
        (uiop:quit 1)))

(asdf:load-system "cl-stack-llm-tui")
(cl-stack-llm-tui:run-mock)
(format t "~&MOCK OK~%")
(uiop:quit 0)
