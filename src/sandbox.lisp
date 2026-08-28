(in-package #:cl-stack-llm-tui)

(defvar *workspace-root* nil
  "Directory MCP file tools may touch. Defaults to cwd / LLM_TUI_ROOT.")

(defun workspace-root ()
  "Truename the sandbox dir so Windows 8.3 (`RUNNER~1`) matches iterdir/walk."
  (let* ((raw (uiop:ensure-directory-pathname
               (or *workspace-root*
                   (%env "LLM_TUI_ROOT")
                   (uiop:getcwd))))
         (true (uiop:probe-file* raw :truename t)))
    (uiop:ensure-directory-pathname (or true raw))))

(defun workspace-root-path ()
  (stack-pathlib:ensure-directory (workspace-root)))

(defun %relposix (path)
  (handler-case
      (stack-pathlib:as-posix (stack-pathlib:relative-to path (workspace-root-path)))
    (stack-pathlib:not-relative-error ()
      (stack-pathlib:name path))))

(defun resolve-in-workspace (rel &key (must-exist nil))
  "Resolve REL under the workspace. Signals SANDBOX-ERROR on `..` escape."
  (when (or (null rel) (zerop (length (string-trim '(#\Space) (%stringify rel)))))
    (error 'sandbox-error :message "empty path"))
  (let* ((root (workspace-root-path))
         (joined (stack-pathlib:normpath (stack-pathlib:join root rel))))
    (unless (stack-pathlib:relative-to-p joined root)
      (error 'sandbox-error
             :message (format nil "path ~s escapes workspace ~a" rel
                              (stack-pathlib:as-posix root))))
    (when (and must-exist (not (stack-pathlib:exists-p joined)))
      (error 'sandbox-error
             :message (format nil "not found: ~a" (stack-pathlib:as-posix joined))))
    joined))
