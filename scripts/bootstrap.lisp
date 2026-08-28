;;;; This checkout + ./.cl-repository. No siblings.

(defparameter *tui-root*
  (uiop:pathname-parent-directory-pathname
   (uiop:pathname-directory-pathname
    (or *load-truename* *compile-file-truename* (uiop:getcwd)))))

(defun %env-dir (name)
  (let ((v (uiop:getenv name)))
    (when (and v (plusp (length v)))
      (let ((p (probe-file v)))
        (and p (uiop:ensure-directory-pathname p))))))

(defun %client-dest ()
  (or (%env-dir "CL_REPOSITORY_DEST")
      (uiop:ensure-directory-pathname
       (merge-pathnames ".cl-repository/" *tui-root*))))

(defun %client-asd ()
  (or (directory (merge-pathnames "**/cl-repository-client.asd" (%client-dest)))
      (let ((d (%env-dir "CL_REPOSITORY_CLIENT_DIR")))
        (when d (directory (merge-pathnames "**/cl-repository-client.asd" d))))))

(defun %bind-tui-asdf ()
  (let ((dest (%client-dest)))
    (unless (%client-asd)
      (error "cl-repository-client not found — run ./scripts/setup-client.sh"))
    (asdf:initialize-source-registry
     `(:source-registry
       (:directory ,*tui-root*)
       (:tree ,dest)
       :ignore-inherited-configuration))
    (format t "~&; tui: root=~a~%;      dest=~a~%" *tui-root* dest)))

(setf asdf:*compile-file-failure-behaviour* :warn)
(%bind-tui-asdf)
(asdf:load-asd (merge-pathnames "cl-stack-llm-tui.asd" *tui-root*))
#+sbcl
(handler-bind ((sb-ext:defconstant-uneql #'continue))
  (asdf:load-system "cl-repository-client" :verbose nil))
#-sbcl
(asdf:load-system "cl-repository-client" :verbose nil)
(cl-repository-client/asdf-integration:configure-asdf-source-registry)

(defun load-tui-init-files (&key live)
  "Load cl-repo-init.lisp. Skip vllm-cpp unless LIVE (preload can SIGKILL)."
  (let ((root (cl-repository-client/installer:systems-root)))
    (when (probe-file root)
      (dolist (system-dir (uiop:subdirectories root))
        (let ((name (car (last (pathname-directory system-dir)))))
          (unless (and (not live) (string-equal name "vllm-cpp"))
            (dolist (version-dir (uiop:subdirectories system-dir))
              (let ((init (merge-pathnames "cl-repo-init.lisp" version-dir)))
                (when (probe-file init)
                  (load init))))))))))

(load-tui-init-files)
