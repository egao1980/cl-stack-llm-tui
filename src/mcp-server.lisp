(in-package #:cl-stack-llm-tui)

(defparameter +max-read-bytes+ 32768)

(defun tool-list-dir (args)
  (let* ((obj (decode-args args))
         (rel (or (%arg obj "path") "."))
         (dir (resolve-in-workspace rel)))
    (unless (stack-pathlib:directory-p dir)
      (error 'sandbox-error :message (format nil "not a directory: ~a"
                                             (stack-pathlib:as-posix dir))))
    (stack-json:encode
     (mapcar (lambda (p)
               (mcp-protocol:json-object
                "name" (stack-pathlib:name p)
                "path" (stack-pathlib:as-posix (stack-pathlib:relative-to p (workspace-root)))
                "dir" (and (stack-pathlib:directory-p p) t)))
             (stack-pathlib:iterdir dir)))))

(defun tool-read-file (args)
  (let* ((obj (decode-args args))
         (path (resolve-in-workspace (%arg obj "path") :must-exist t)))
    (unless (stack-pathlib:file-p path)
      (error 'sandbox-error :message "not a file"))
    (let ((size (or (stack-pathlib:file-size path) 0)))
      (when (> size +max-read-bytes+)
        (error 'tui-error
               :message (format nil "file too large (~a bytes, max ~a)"
                                size +max-read-bytes+)))
      (stack-json:encode
       (mcp-protocol:json-object
        "path" (stack-pathlib:as-posix (stack-pathlib:relative-to path (workspace-root)))
        "text" (stack-pathlib:read-text path))))))

(defun tool-write-note (args)
  (let* ((obj (decode-args args))
         (text (%stringify (%arg obj "text")))
         (rel (or (%arg obj "path") "notes.md"))
         (path (resolve-in-workspace rel))
         (prev (if (stack-pathlib:file-p path)
                   (stack-pathlib:read-text path)
                   "")))
    (when (zerop (length (string-trim '(#\Space #\Tab #\Newline) text)))
      (error 'tui-error :message "empty note"))
    (stack-pathlib:with-auto-create-parents
      (stack-pathlib:write-text path
                                (format nil "~a~a~a~%"
                                        prev
                                        (if (and (plusp (length prev))
                                                 (not (eql (char prev (1- (length prev))) #\Newline)))
                                            (string #\Newline)
                                            "")
                                        text)))
    (stack-json:encode
     (mcp-protocol:json-object
      "path" (stack-pathlib:as-posix (stack-pathlib:relative-to path (workspace-root)))
      "bytes" (length text)))))

(defun tool-search-files (args)
  (let* ((obj (decode-args args))
         (pattern (or (%arg obj "pattern") "*"))
         (root (resolve-in-workspace (or (%arg obj "path") ".")))
         (hits '()))
    (cond
      ((stack-pathlib:directory-p root)
       (dolist (triple (or (stack-pathlib:walk root) '()))
         (destructuring-bind (dir files dirs) triple
           (declare (ignore dir dirs))
           (dolist (f files)
             (when (stack-pathlib:match-p f pattern)
               (push f hits))))))
      ((stack-pathlib:match-p root pattern)
       (push root hits)))
    (let ((hits (nreverse hits)))
      (stack-json:encode
       (mapcar (lambda (p)
                 (stack-pathlib:as-posix (stack-pathlib:relative-to p (workspace-root))))
               (subseq hits 0 (min 50 (length hits))))))))

(defun %mcp-handler (fn)
  (lambda (args)
    (handler-case (funcall fn args)
      (tui-error (c)
        (stack-json:encode (mcp-protocol:json-object "error" (tui-error-message c)))))))

(defun make-workspace-mcp-server ()
  "File tools sandboxed to WORKSPACE-ROOT. Same object for in-process + stdio."
  (let ((server (make-instance 'mcp-protocol:mcp-server
                               :name "llm-tui-workspace"
                               :version "0.1.0"
                               :instructions
                               "Workspace file tools. Paths are relative to the TUI workspace root.")))
    (mcp-protocol:register-tool
     server
     (mcp-protocol:make-mcp-tool
      "list_dir"
      :description "List files in a workspace subdirectory."
      :input-schema
      (mcp-protocol:json-object
       "type" "object"
       "properties"
       (mcp-protocol:json-object
        "path" (mcp-protocol:json-object "type" "string"
                                         "description" "Relative directory, default .")))
      :handler (%mcp-handler #'tool-list-dir)))
    (mcp-protocol:register-tool
     server
     (mcp-protocol:make-mcp-tool
      "read_file"
      :description "Read a small text file from the workspace (32KiB cap)."
      :input-schema
      (mcp-protocol:json-object
       "type" "object"
       "properties"
       (mcp-protocol:json-object
        "path" (mcp-protocol:json-object "type" "string"))
       "required" (vector "path"))
      :handler (%mcp-handler #'tool-read-file)))
    (mcp-protocol:register-tool
     server
     (mcp-protocol:make-mcp-tool
      "write_note"
      :description "Append a line to a notes file (default notes.md)."
      :input-schema
      (mcp-protocol:json-object
       "type" "object"
       "properties"
       (mcp-protocol:json-object
        "text" (mcp-protocol:json-object "type" "string")
        "path" (mcp-protocol:json-object "type" "string"))
       "required" (vector "text"))
      :handler (%mcp-handler #'tool-write-note)))
    (mcp-protocol:register-tool
     server
     (mcp-protocol:make-mcp-tool
      "search_files"
      :description "Glob filenames under a workspace directory (max 50)."
      :input-schema
      (mcp-protocol:json-object
       "type" "object"
       "properties"
       (mcp-protocol:json-object
        "pattern" (mcp-protocol:json-object "type" "string" "description" "e.g. *.lisp")
        "path" (mcp-protocol:json-object "type" "string")))
      :handler (%mcp-handler #'tool-search-files)))
    server))

(defun serve-workspace-mcp (&key (input *standard-input*) (output *standard-output*))
  (mcp-backend-stdio:use-stdio-mcp-backend)
  (mcp-protocol:backend-mcp-serve
   mcp-protocol:*mcp-backend*
   (make-workspace-mcp-server)
   :input input :output output))

(defun make-host-client (&key backend)
  (make-instance 'mcp-protocol:mcp-client
                 :sampling-handler
                 (ai-agent-protocol/mcp:make-mcp-sampling-handler :backend backend)))
