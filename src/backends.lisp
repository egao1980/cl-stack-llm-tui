(in-package #:cl-stack-llm-tui)

(defmacro with-runtime (&body body)
  "Bind libuv + async HTTP so LM Studio generate works."
  `(progn
     (setf http-backend-async:*event-backend-maker*
           #'event-backend-libuv:make-libuv-backend)
     (let* ((eb (event-backend-libuv:make-libuv-backend))
            (el (event-protocol:make-event-loop eb)))
       (event-protocol:with-event-backend (eb)
         (event-protocol:with-event-loop-var (el)
           (let ((http-protocol:*http-backend* (http-backend-async:make-async-backend)))
             ,@body))))))

(defun %content-octets (content)
  "UTF-8 octets. http-protocol:coerce-to-octets used char-code (8212 = em dash)."
  (cond
    ((null content) nil)
    ((stringp content) (babel:string-to-octets content :encoding :utf-8))
    ((and (vectorp content) (not (stringp content))) content)
    (t (error 'tui-error
              :message (format nil "bad HTTP content ~s" (type-of content))))))

(defun %http-utf8 (method url &key headers content)
  (unless http-protocol:*http-backend*
    (error 'tui-error :message "*http-backend* is nil"))
  (let* ((octets (%content-octets content))
         (res (apply #'http:request method url
                     :headers headers
                     :timeout 180
                     (and octets (list :content octets)))))
    (values (http-protocol:response-status res)
            (let ((b (http-protocol:response-body res)))
              (cond
                ((stringp b) b)
                ((and (vectorp b) (not (stringp b)))
                 (babel:octets-to-string b :encoding :utf-8))
                (t ""))))))

(defun make-lmstudio-backend (&key base-url api-key default-model)
  (llm-protocol-openai:make-openai-compat-backend
   :base-url (or base-url (%env "OPENAI_BASE_URL") (%env "LM_STUDIO_BASE_URL"))
   :api-key (resolve-lmstudio-api-key api-key)
   :default-model (or default-model (%env "OPENAI_MODEL") (%env "LM_STUDIO_MODEL")
                      "local-model")
   :request-fn #'%http-utf8))

(defun make-scripted-backend (steps)
  "STEPS: list of tool-call parts or final strings. For tests / /backend mock."
  (let ((i 0))
    (llm-protocol:make-mock-llm-backend
     :handler
     (lambda (backend turns &key &allow-other-keys)
       (declare (ignore backend turns))
       (let ((step (nth i steps)))
         (incf i)
         (cond
           ((null step)
            (llm-protocol:make-llm-response
             :parts (list (llm-protocol:make-llm-text-part :text "(mock: no more steps)"))
             :finish-reason :stop))
           ((stringp step)
            (llm-protocol:make-llm-response
             :parts (list (llm-protocol:make-llm-text-part :text step))
             :finish-reason :stop))
           (t
            (llm-protocol:make-llm-response
             :parts (if (listp step) step (list step))
             :finish-reason :tool-use))))))))

(defun make-vllm-backend (&key model-path)
  (error "load cl-stack-llm-tui/vllm for a live vllm.cpp backend (model ~s)"
         model-path))
