(in-package #:cl-stack-llm-tui)

(defun %raw-env (name)
  (let ((v (uiop:getenv name)))
    (and v (plusp (length v)) v)))

(defun %env (name)
  (%raw-env name))

(defun %nonempty-key (value)
  (and value (plusp (length value)) value))

(defun %dummy-lmstudio-token-p (value)
  (and value
       (member (string-trim '(#\Space #\Tab) value)
               '("lm-studio" "lmstudio")
               :test #'string-equal)))

(defun %lmstudio-api-key (&optional api-key)
  "Real token only. Dummy `lm-studio` is treated as unset (LM Studio 0.4+ rejects it)."
  (dolist (k (list (%nonempty-key api-key)
                   (%raw-env "OPENAI_API_KEY")
                   (%raw-env "LM_API_TOKEN")))
    (when (and k (not (%dummy-lmstudio-token-p k)))
      (return k))))

(defun %apply-lmstudio-token (key)
  (when (and *lmstudio-backend*
             (typep *lmstudio-backend* 'llm-protocol-openai:openai-compat-backend))
    (setf (llm-protocol-openai:openai-api-key *lmstudio-backend*) key))
  (cond
    (key
     (setf (uiop:getenv "LM_API_TOKEN") key)
     (when (%dummy-lmstudio-token-p (%raw-env "OPENAI_API_KEY"))
       (setf (uiop:getenv "OPENAI_API_KEY") "")))
    (t
     (when (%dummy-lmstudio-token-p (%raw-env "OPENAI_API_KEY"))
       (setf (uiop:getenv "OPENAI_API_KEY") ""))
     (when (%dummy-lmstudio-token-p (%raw-env "LM_API_TOKEN"))
       (setf (uiop:getenv "LM_API_TOKEN") ""))))
  key)

(defun resolve-lmstudio-api-key (&optional api-key)
  (let ((key (%lmstudio-api-key api-key))
        (raw (or (%nonempty-key api-key)
                 (%raw-env "OPENAI_API_KEY")
                 (%raw-env "LM_API_TOKEN"))))
    (cond
      (key key)
      ((%dummy-lmstudio-token-p raw)
       (%restart-lmstudio-auth
        :token raw
        :message (format nil "Malformed LM Studio API token: ~a" raw)))
      (t nil))))

(defun %unquote-dotenv (s)
  (let ((n (length s)))
    (if (and (>= n 2)
             (or (and (char= (char s 0) #\") (char= (char s (1- n)) #\"))
                 (and (char= (char s 0) #\') (char= (char s (1- n)) #\'))))
        (subseq s 1 (1- n))
        s)))

(defun parse-dotenv (text)
  "Return an alist of (NAME . VALUE) from dotenv text."
  (let ((out '()))
    (dolist (raw (uiop:split-string (or text "") :separator '(#\Newline #\Return)))
      (let ((line (string-trim '(#\Space #\Tab) raw)))
        (when (and (plusp (length line)) (char/= (char line 0) #\#))
          (when (eql (search "export " line) 0)
            (setf line (string-trim '(#\Space #\Tab) (subseq line 7))))
          (let ((eqpos (position #\= line)))
            (when eqpos
              (let ((k (string-trim '(#\Space #\Tab) (subseq line 0 eqpos)))
                    (v (%unquote-dotenv
                        (string-trim '(#\Space #\Tab) (subseq line (1+ eqpos))))))
                (when (plusp (length k))
                  (push (cons k v) out))))))))
    (nreverse out)))

(defun apply-dotenv (path)
  "Set env from PATH. Does not override a non-dummy existing value."
  (dolist (pair (parse-dotenv (uiop:read-file-string path)))
    (destructuring-bind (k . v) pair
      (let ((cur (%raw-env k)))
        (when (or (null cur) (%dummy-lmstudio-token-p cur))
          (setf (uiop:getenv k) v)))))
  path)

(defun dotenv-candidates ()
  (let* ((explicit (%raw-env "LLM_TUI_ENV"))
         (root (%raw-env "LLM_TUI_ROOT"))
         (sys (ignore-errors
                (uiop:ensure-directory-pathname
                 (asdf:system-source-directory "cl-stack-llm-tui"))))
         (cwd (uiop:getcwd)))
    (remove nil
            (list (and explicit (pathname explicit))
                  (merge-pathnames ".env" cwd)
                  (and root (merge-pathnames ".env"
                                             (uiop:ensure-directory-pathname root)))
                  (and sys (merge-pathnames ".env" sys))
                  (and sys (merge-pathnames ".env"
                                            (uiop:pathname-parent-directory-pathname sys)))))))

(defun find-dotenv ()
  (dolist (p (dotenv-candidates))
    (let ((found (probe-file p)))
      (when (and found (not (uiop:directory-pathname-p found)))
        (return found)))))

(defun find-and-apply-dotenv ()
  (let ((p (find-dotenv)))
    (when p (apply-dotenv p))))

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
