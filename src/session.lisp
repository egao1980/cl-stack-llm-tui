(in-package #:cl-stack-llm-tui)

(defstruct (chat-session (:constructor %make-chat-session))
  backend-kind
  backend
  agent
  mcp-server
  model
  turns
  last-tools
  status)

(defun make-chat-session (&key (backend-kind :mock) backend model)
  (let* ((kind (intern (string-upcase (string backend-kind)) :keyword))
         (b (or backend
                (ecase kind
                  (:mock (make-scripted-backend
                          (list (list (llm-protocol:make-llm-tool-call-part
                                       :id "t1" :name "now" :arguments "{}"))
                                "It's a mock clock. Ask me something real with /backend lmstudio.")))
                  (:lmstudio (make-lmstudio-backend :default-model model))
                  (:vllm (make-vllm-backend)))))
         (server (make-workspace-mcp-server))
         (agent (make-chat-agent :backend b :mcp-server server)))
    (%make-chat-session
     :backend-kind kind
     :backend b
     :agent agent
     :mcp-server server
     :model (or model
                (ignore-errors (llm-protocol:backend-model b))
                (string-downcase (string kind)))
     :turns '()
     :last-tools '()
     :status "ready")))

(defun %on-event (session kind payload)
  (case kind
    (:started
     (setf (chat-session-status session) "thinking"))
    (:response
     (setf (chat-session-last-tools session)
           (mapcar #'llm-protocol:llm-tool-call-part-name
                   (llm-protocol:llm-response-tool-calls payload)))
     (when (chat-session-last-tools session)
       (setf (chat-session-status session)
             (format nil "tool ~{~a~^, ~}" (chat-session-last-tools session)))))
    (:finished
     (setf (chat-session-status session) "ready"))
    (t nil)))

(defun chat-turn (session text &key (max-steps 8) (max-tokens 256))
  (setf (chat-session-turns session)
        (append (chat-session-turns session)
                (list (list :user text))))
  (setf (chat-session-status session) "thinking")
  (let ((run (ai-agent-protocol:run-ai-agent
              (chat-session-agent session) text
              :settings (ai-agent-protocol:make-agent-settings
                         :llm (llm-protocol:make-llm-settings
                               :temperature 0.2 :max-tokens max-tokens)
                         :max-steps max-steps)
              :on-event (lambda (kind payload)
                          (%on-event session kind payload)))))
    (let ((reply (or (ai-agent-protocol:agent-run-text run) "")))
      (setf (chat-session-last-tools session)
            (mapcar #'ai-agent-protocol:agent-invocation-name
                    (ai-agent-protocol:agent-run-invocations run)))
      (setf (chat-session-turns session)
            (append (chat-session-turns session)
                    (list (list :assistant reply
                                :tools (chat-session-last-tools session)
                                :finish (ai-agent-protocol:agent-run-finish-reason run)))))
      (setf (chat-session-status session) "ready")
      run)))

(defun apply-slash-command (session line)
  "Returns (values handled-p message). handled-p T means do not send to the LLM."
  (let* ((s (string-trim '(#\Space #\Tab) line))
         (parts (uiop:split-string s :separator " "))
         (cmd (string-downcase (first parts)))
         (arg (second parts)))
    (cond
      ((member cmd '("/quit" "/exit" "/q") :test #'string=)
       (values :quit "bye"))
      ((member cmd '("/help" "/?") :test #'string=)
       (values t (format nil "commands: /help /clear /backend mock|lmstudio|vllm /quit")))
      ((string= cmd "/clear")
       (setf (chat-session-turns session) '())
       (values t "cleared"))
      ((string= cmd "/backend")
       (unless arg
         (return-from apply-slash-command
           (values t (format nil "backend is ~a" (chat-session-backend-kind session)))))
       (handler-case
           (let ((next (make-chat-session :backend-kind arg)))
             (setf (chat-session-backend-kind session) (chat-session-backend-kind next)
                   (chat-session-backend session) (chat-session-backend next)
                   (chat-session-agent session) (chat-session-agent next)
                   (chat-session-mcp-server session) (chat-session-mcp-server next)
                   (chat-session-model session) (chat-session-model next)
                   (chat-session-last-tools session) '())
             (values t (format nil "backend → ~a (~a)"
                               (chat-session-backend-kind session)
                               (chat-session-model session))))
         (error (e)
           (values t (format nil "cannot switch backend: ~a" e)))))
      (t (values nil nil)))))
