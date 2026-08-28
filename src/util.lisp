(in-package #:cl-stack-llm-tui)

(defun %env (name)
  (let ((v (uiop:getenv name)))
    (and v (plusp (length v)) v)))

(defun decode-args (args)
  "Tool args as a hash-table. Agents often pass a JSON string."
  (cond
    ((hash-table-p args) args)
    ((stringp args)
     (let ((s (string-trim '(#\Space #\Tab #\Newline #\Return) args)))
       (if (zerop (length s))
           (mcp-protocol:json-object)
           (let ((obj (ignore-errors (stack-json:decode s))))
             (if (hash-table-p obj) obj (mcp-protocol:json-object))))))
    (t (mcp-protocol:json-object))))

(defun %arg (obj key &optional default)
  (or (gethash key obj)
      (gethash (substitute #\- #\_ key) obj)
      default))

(defun %stringify (x)
  (cond
    ((stringp x) x)
    ((null x) "")
    (t (princ-to-string x))))
