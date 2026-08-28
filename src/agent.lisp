(in-package #:cl-stack-llm-tui)

(defparameter *chat-instructions*
  "You are a local desk agent in a terminal. Be terse.
Use tools when they help: now, calc, list_dir, read_file, write_note, search_files.
Paths are relative to the workspace root. Do not invent file contents — read them.
After tools, answer the user in a few sentences.")

(defclass json-mcp-source (ai-agent-protocol/mcp:mcp-tool-source) ())

(defmethod ai-agent-protocol:invoke-tool-async
    ((source json-mcp-source) name arguments &key context callback error-callback)
  (call-next-method source name (decode-args arguments)
                    :context context :callback callback
                    :error-callback error-callback))

(defun make-chat-agent (&key backend (mcp-server (make-workspace-mcp-server)))
  (let ((agent (ai-agent-protocol:make-ai-agent
                :name "desk"
                :backend backend
                :instructions *chat-instructions*)))
    (ai-agent-protocol:define-agent-tool
        agent "now"
        (:description "Current local time as ISO-8601."
         :parameters (mcp-protocol:json-object
                      "type" "object"
                      "properties" (mcp-protocol:json-object)))
        (args)
      (tool-now args))
    (ai-agent-protocol:define-agent-tool
        agent "calc"
        (:description "Arithmetic: op is + - * / plus numbers a and b."
         :parameters (mcp-protocol:json-object
                      "type" "object"
                      "properties"
                      (mcp-protocol:json-object
                       "op" (mcp-protocol:json-object "type" "string")
                       "a" (mcp-protocol:json-object "description" "left operand")
                       "b" (mcp-protocol:json-object "description" "right operand"))
                      "required" (vector "op" "a" "b")))
        (args)
      (tool-calc args))
    (when mcp-server
      (ai-agent-protocol:register-agent-tool
       agent (make-instance 'json-mcp-source :peer mcp-server)))
    agent))
