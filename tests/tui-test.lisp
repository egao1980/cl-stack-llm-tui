(in-package #:cl-stack-llm-tui/tests)

(defmacro with-tmp-workspace (&body body)
  `(let* ((dir (uiop:ensure-directory-pathname
                (merge-pathnames
                 (format nil "llm-tui-test-~a-~a/"
                         (get-universal-time)
                         (random 100000000))
                 (uiop:temporary-directory))))
          (*workspace-root* dir))
     (ensure-directories-exist dir)
     (unwind-protect (progn ,@body)
       (uiop:delete-directory-tree dir :validate t :if-does-not-exist :ignore))))

(deftest utf8-content-octets
  (ok (equalp (babel:string-to-octets (string (code-char 8212)) :encoding :utf-8)
              (cl-stack-llm-tui::%content-octets (string (code-char 8212))))))

(deftest calc-ops
  (ok (= 5 (eval-calc "+" 2 3)))
  (ok (= 6 (eval-calc "*" "2" 3)))
  (ok (= 2 (eval-calc "/" 10 5)))
  (ok (signals (eval-calc "/" 1 0) 'tui-error))
  (ok (signals (eval-calc "pow" 2 3) 'tui-error)))

(deftest now-iso-shape
  (let ((s (now-iso)))
    (ok (>= (length s) 19))
    (ok (char= #\- (char s 4)))
    (ok (char= #\T (char s 10))))
  (let ((js (stack-json:decode (tool-now nil))))
    (ok (gethash "iso" js))))

(deftest sandbox-blocks-escape
  (with-tmp-workspace
    (ok (signals (resolve-in-workspace "../etc/passwd") 'sandbox-error))
    (ok (signals (resolve-in-workspace "/etc/passwd") 'sandbox-error))
    (ok (stack-pathlib:relative-to-p (resolve-in-workspace "notes.md")
                                     (workspace-root)))))

(deftest mcp-file-tools
  (with-tmp-workspace
    (let ((note (tool-write-note (mcp-protocol:json-object "text" "hello desk"))))
      (ok (search "notes.md" note)))
    (let ((read (stack-json:decode (tool-read-file (mcp-protocol:json-object "path" "notes.md")))))
      (ok (search "hello desk" (gethash "text" read))))
    (let ((listing (stack-json:decode (tool-list-dir (mcp-protocol:json-object "path" ".")))))
      (ok (find "notes.md" listing :test #'string=
                :key (lambda (row) (gethash "name" row)))))
    (let ((hits (stack-json:decode
                 (tool-search-files (mcp-protocol:json-object "pattern" "*.md")))))
      (ok (find "notes.md" hits :test #'string=)))))

(defun %mcp-text (result)
  (cond
    ((stringp result) result)
    ((hash-table-p result)
     (let ((content (gethash "content" result)))
       (if (and content (plusp (length content)))
           (or (gethash "text" (elt (coerce content 'vector) 0)) "")
           "")))
    (t "")))

(deftest mcp-server-call-tool
  (with-tmp-workspace
    (tool-write-note (mcp-protocol:json-object "text" "via mcp"))
    (let* ((server (make-workspace-mcp-server))
           (names (mapcar #'mcp-protocol:mcp-tool-name (mcp-protocol:list-tools server)))
           (out (mcp-protocol:call-tool
                 server "list_dir" (mcp-protocol:json-object "path" "."))))
      (ok (find "list_dir" names :test #'string=))
      (ok (find "read_file" names :test #'string=))
      (ok (search "notes.md" (%mcp-text out))))))

(deftest slash-commands
  (let ((s (make-chat-session :backend-kind :mock)))
    (multiple-value-bind (h msg) (apply-slash-command s "/help")
      (ok (eq h t))
      (ok (search "/backend" msg)))
    (multiple-value-bind (h) (apply-slash-command s "/quit")
      (ok (eq h :quit)))
    (setf (chat-session-turns s) '((:user "x")))
    (apply-slash-command s "/clear")
    (ok (null (chat-session-turns s)))
    (multiple-value-bind (h msg) (apply-slash-command s "/backend vllm")
      (ok (eq h t))
      (ok (search "cannot switch" msg)))))

(deftest mock-agent-calls-now
  (with-runtime
    (let* ((s (make-chat-session :backend-kind :mock))
           (run (chat-turn s "what time is it?" :max-steps 4 :max-tokens 64)))
      (ok (eq :stop (ai-agent-protocol:agent-run-finish-reason run)))
      (ok (find "now" (ai-agent-protocol:agent-run-invocations run)
                :key #'ai-agent-protocol:agent-invocation-name
                :test #'equal))
      (ok (search "desk>" (render-screen s :width 60 :height 16))))))

(deftest mock-agent-calls-list-dir
  (with-tmp-workspace
    (tool-write-note (mcp-protocol:json-object "text" "listed"))
    (with-runtime
      (let* ((b (make-scripted-backend
                 (list (list (llm-protocol:make-llm-tool-call-part
                              :id "t1" :name "list_dir" :arguments "{\"path\":\".\"}"))
                       "workspace has notes.md")))
             (s (make-chat-session :backend-kind :mock :backend b))
             (run (chat-turn s "what files are here?" :max-steps 4 :max-tokens 64)))
        (ok (eq :stop (ai-agent-protocol:agent-run-finish-reason run)))
        (ok (find "list_dir" (ai-agent-protocol:agent-run-invocations run)
                  :key #'ai-agent-protocol:agent-invocation-name
                  :test #'equal))
        (ok (search "notes.md" (or (ai-agent-protocol:agent-run-text run) "")))))))
