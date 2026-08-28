(defpackage #:cl-stack-llm-tui
  (:use #:cl)
  (:nicknames #:stack-llm-tui)
  (:export
   #:tui-error
   #:tui-error-message
   #:sandbox-error
   #:lmstudio-auth-error
   #:lmstudio-auth-error-token
   #:lmstudio-auth-error-cause
   #:with-lmstudio-restarts
   #:with-auto-load-env
   #:auto-load-env
   #:invoke-retry
   #:invoke-load-env
   #:load-env
   #:resolve-lmstudio-api-key
   #:parse-dotenv
   #:apply-dotenv
   #:find-dotenv
   #:find-and-apply-dotenv
   #:*workspace-root*
   #:workspace-root
   #:resolve-in-workspace

   #:decode-args
   #:now-iso
   #:eval-calc
   #:tool-now
   #:tool-calc
   #:tool-list-dir
   #:tool-read-file
   #:tool-write-note
   #:tool-search-files

   #:make-workspace-mcp-server
   #:serve-workspace-mcp
   #:make-host-client

   #:make-lmstudio-backend
   #:make-scripted-backend
   #:make-vllm-backend
   #:with-runtime

   #:make-chat-agent
   #:*chat-instructions*

   #:chat-session
   #:make-chat-session
   #:chat-session-backend-kind
   #:chat-session-backend
   #:chat-session-agent
   #:chat-session-mcp-server
   #:chat-session-model
   #:chat-session-turns
   #:chat-session-last-tools
   #:chat-session-status
   #:chat-turn
   #:apply-slash-command

   #:render-screen
   #:run-tui
   #:run-line-chat
   #:run-mock
   #:main))

(in-package #:cl-stack-llm-tui)
