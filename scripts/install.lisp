;;;; Install .asd deps from ghcr.io/egao1980/cl-systems.
;;;;   ./scripts/setup-client.sh
;;;;   ros -l scripts/install.lisp
;;;;
;;;; Does not walk cl-stack-llm-tui/vllm (CUDA overlay). Optional:
;;;;   ros -l scripts/install-vllm.lisp

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&INSTALL FAIL: ~A~%" c)
        (uiop:print-backtrace :condition c :stream *error-output*)
        (uiop:quit 1)))

(load (merge-pathnames "bootstrap.lisp" *load-truename*))

(asdf:load-system "cl-repository-client")
(cl-repo:add-registry "https://ghcr.io" :namespace "egao1980/cl-systems" :priority :prepend)

(defun %install (name &key (also-tests t))
  (format t "~&; install deps for ~a~%" name)
  (cl-repo:ensure-system-dependencies name
                                      :also-tests also-tests
                                      :default-source :oci)
  (cl-repository-client/asdf-integration:configure-asdf-source-registry))

(%install "cl-stack-llm-tui" :also-tests t)
(load-tui-init-files)
(dolist (sys '("cl-stack-llm-tui" "cl-stack-llm-tui/tests"))
  (dolist (dep (asdf:system-depends-on (asdf:find-system sys)))
    (let ((n (string-downcase (if (stringp dep) dep (princ-to-string dep)))))
      (unless (asdf:find-system n nil)
        (error "after install, ASDF cannot find ~a (from ~a)" n sys)))))
(format t "~&; install done~%")
(uiop:quit 0)
