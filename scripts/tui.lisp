;;;; Interactive TUI (or line-mode if not a tty / LLM_TUI_LINE=1).
;;;;   ./scripts/setup-client.sh && ros -l scripts/install.lisp
;;;;   LLM_TUI_BACKEND=lmstudio ros -l scripts/tui.lisp
;;;;   LLM_TUI_BACKEND=mock LLM_TUI_LINE=1 ros -l scripts/tui.lisp
;;;;
;;;; vllm.cpp: ros -l scripts/install-vllm.lisp first, then
;;;;   VLLM_MODEL_PATH=… LLM_TUI_BACKEND=vllm ros -l scripts/tui.lisp

(load (merge-pathnames "bootstrap.lisp" *load-truename*))

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&TUI FAIL: ~A~%" c)
        (uiop:print-backtrace :condition c :stream *error-output*)
        (uiop:quit 1)))

(let ((backend (string-downcase (or (uiop:getenv "LLM_TUI_BACKEND") "lmstudio"))))
  (when (string= backend "vllm")
    (load-tui-init-files :live t)
    (asdf:load-system "cl-stack-llm-tui/vllm"))
  (asdf:load-system "cl-stack-llm-tui"))

(cl-stack-llm-tui:main)
(uiop:quit 0)
