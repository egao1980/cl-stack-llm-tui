(in-package #:cl-stack-llm-tui)

(define-condition tui-error (error)
  ((message :initarg :message :reader tui-error-message :initform nil))
  (:report (lambda (c s)
             (format s "~a" (or (tui-error-message c)
                                (string-downcase (symbol-name (class-name (class-of c)))))))))

(define-condition sandbox-error (tui-error) ())

(define-condition lmstudio-auth-error (tui-error)
  ((token :initarg :token :reader lmstudio-auth-error-token :initform nil)
   (cause :initarg :cause :reader lmstudio-auth-error-cause :initform nil))
  (:report (lambda (c s)
             (format s "LM Studio API token rejected~@[ (~a)~]. ~
USE-VALUE a token (sk-lm-…), CONTINUE without Authorization, or LOAD-ENV from a .env."
                     (or (tui-error-message c)
                         (lmstudio-auth-error-token c))))))

;;; Restarts: RETRY at the op; USE-VALUE / CONTINUE / LOAD-ENV mutate then RETRY.

(defvar *lmstudio-backend* nil)

(defun call-with-lmstudio-restarts (thunk)
  (tagbody
   :retry
     (return-from call-with-lmstudio-restarts
       (restart-case (funcall thunk)
         (retry ()
           :report "Retry after changing the LM Studio token"
           (go :retry))))))

(defmacro with-lmstudio-restarts (&body body)
  `(call-with-lmstudio-restarts (lambda () ,@body)))

(defun %invoke-retry ()
  (let ((r (find-restart 'retry)))
    (if r
        (invoke-restart r)
        (error "RETRY restart not active; wrap the call in WITH-LMSTUDIO-RESTARTS"))))

(defun invoke-retry (&optional condition)
  (let ((r (find-restart 'retry condition)))
    (when r (invoke-restart r))))

(defun invoke-load-env (&optional path condition)
  (let ((r (find-restart 'load-env condition)))
    (when r
      (if path
          (invoke-restart r path)
          (invoke-restart r)))))

(defun %restart-lmstudio-auth (&key token cause message)
  (flet ((finish (key)
           (%apply-lmstudio-token key)
           (if (find-restart 'retry)
               (%invoke-retry)
               key)))
    (restart-case
        (error 'lmstudio-auth-error
               :token token
               :cause cause
               :message message)
      (use-value (value)
        :report "Use a supplied LM Studio API token"
        :interactive (lambda ()
                       (format *query-io* "LM_API_TOKEN: ")
                       (force-output *query-io*)
                       (list (read-line *query-io*)))
        (finish (%nonempty-key (string-trim '(#\Space #\Tab #\Newline #\Return)
                                           (string value)))))
      (continue ()
        :report "Continue with no Authorization header"
        (finish nil))
      (load-env (&optional path)
        :report "Load KEY=VALUE from a .env (LM_API_TOKEN) and retry"
        :interactive (lambda ()
                       (format *query-io* ".env path [empty = search]: ")
                       (force-output *query-io*)
                       (let ((line (string-trim '(#\Space #\Tab) (read-line *query-io*))))
                         (list (when (plusp (length line)) line))))
        (let ((p (or (and path (probe-file path)) (find-dotenv))))
          (unless p
            (error 'lmstudio-auth-error
                   :token token
                   :cause cause
                   :message "no .env found — copy .env.example or pass a path to LOAD-ENV"))
          (apply-dotenv p)
          (finish (%lmstudio-api-key)))))))

(defvar *auto-load-env-once* nil)

(defun auto-load-env (condition)
  "HANDLER-BIND: LOAD-ENV when a .env is visible. One shot so a bad file cannot loop."
  (when (and (not *auto-load-env-once*)
             (typep condition 'lmstudio-auth-error)
             (find-restart 'load-env condition))
    (let ((p (find-dotenv)))
      (when p
        (setf *auto-load-env-once* t)
        (invoke-restart 'load-env p)))))

(defmacro with-auto-load-env (&body body)
  `(let ((*auto-load-env-once* nil))
     (handler-bind ((lmstudio-auth-error #'auto-load-env))
       (with-lmstudio-restarts ,@body))))
