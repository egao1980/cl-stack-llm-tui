(defsystem "cl-stack-llm-tui"
  :version "0.1.0"
  :description "TUI agent chat over LM Studio or vllm.cpp, with tools + a stdio MCP server"
  :author "egao1980"
  :license "MIT"
  :properties (:cl-repo (:ci (:with ("dissect"))))
  :depends-on ("alexandria"
               "llm-protocol"
               "llm-protocol-openai"
               "ai-agent-protocol"
               "ai-agent-protocol/mcp"
               "mcp-protocol"
               "mcp-backend-stdio"
               "event-protocol"
               "event-backend-libuv"
               "http-protocol"
               "http-backend-async"
               "json-protocol"
               "json-backend-jzon"
               "cl-stack-pathlib")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "conditions")
               (:file "util")
               (:file "sandbox")
               (:file "tools")
               (:file "mcp-server")
               (:file "backends")
               (:file "agent")
               (:file "session")
               (:file "tui")
               (:file "main"))
  :in-order-to ((test-op (test-op "cl-stack-llm-tui/tests"))))

(defsystem "cl-stack-llm-tui/vllm"
  :version "0.1.0"
  :description "Optional vllm.cpp backend for cl-stack-llm-tui"
  :author "egao1980"
  :license "MIT"
  :depends-on ("cl-stack-llm-tui" "llm-protocol-vllm-cpp" "vllm-cpp")
  :serial t
  :pathname "src"
  :components ((:file "vllm")))

(defsystem "cl-stack-llm-tui/tests"
  :depends-on ("cl-stack-llm-tui" "rove" "dissect")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "tui-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
