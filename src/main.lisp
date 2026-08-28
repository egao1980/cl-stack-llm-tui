(in-package #:cl-stack-llm-tui)

(defun %backend-from-env ()
  (intern (string-upcase (or (%env "LLM_TUI_BACKEND") "lmstudio")) :keyword))

(defun run-mock ()
  "One scripted agent turn (now → reply). Offline canary."
  (with-runtime
    (let* ((s (make-chat-session :backend-kind :mock))
           (run (chat-turn s "what time is it?" :max-steps 4 :max-tokens 64)))
      (format t "~&desk> ~a~%" (or (ai-agent-protocol:agent-run-text run) ""))
      (format t "~&tools: ~{~a~^, ~}~%" (or (chat-session-last-tools s) '()))
      run)))

(defun main (&key backend line-mode)
  (let ((kind (or backend (%backend-from-env))))
    (if (or line-mode (not (%tty-p)) (%env "LLM_TUI_LINE"))
        (run-line-chat :backend kind)
        (run-tui :backend kind))))
