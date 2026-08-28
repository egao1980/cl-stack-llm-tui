;;;; Stdio MCP server (llm-tui-workspace): list_dir / read_file / write_note / search_files.
;;;;   LLM_TUI_ROOT=/path/to/sandbox ros -l scripts/mcp-server.lisp
;;;;
;;;; Cursor / Claude Desktop: command ros, args ["-l", "<checkout>/scripts/mcp-server.lisp"]

(load (merge-pathnames "bootstrap.lisp" *load-truename*))

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&MCP FAIL: ~A~%" c)
        (uiop:print-backtrace :condition c :stream *error-output*)
        (uiop:quit 1)))

(asdf:load-system "cl-stack-llm-tui")
(cl-stack-llm-tui:serve-workspace-mcp)
(uiop:quit 0)
