;;;; Optional: walk cl-stack-llm-tui/vllm (pulls vllm-cpp native overlay).
;;;;   ros -l scripts/install.lisp
;;;;   ros -l scripts/install-vllm.lisp

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&INSTALL-VLLM FAIL: ~A~%" c)
        (uiop:print-backtrace :condition c :stream *error-output*)
        (uiop:quit 1)))

(load (merge-pathnames "bootstrap.lisp" *load-truename*))

(asdf:load-system "cl-repository-client")
(cl-repo:add-registry "https://ghcr.io" :namespace "egao1980/cl-systems" :priority :prepend)

(format t "~&; install deps for cl-stack-llm-tui/vllm~%")
(cl-repo:ensure-system-dependencies "cl-stack-llm-tui/vllm"
                                    :also-tests nil
                                    :default-source :oci)
(cl-repository-client/asdf-integration:configure-asdf-source-registry)
(load-tui-init-files :live t)
(format t "~&; install-vllm done~%")
(uiop:quit 0)
