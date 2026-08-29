(in-package #:cl-stack-llm-tui)

(defun make-vllm-backend (&key model-path (max-model-len 2048) device)
  (let ((path (or model-path (%env "VLLM_MODEL_PATH"))))
    (unless path
      (error 'tui-error :message "set VLLM_MODEL_PATH to a GGUF"))
    (let ((engine (vllm-cpp:load-engine
                   :model-path path
                   :device (or device (vllm-cpp:default-device))
                   :max-model-len max-model-len)))
      (llm-backend-vllm-cpp:make-vllm-cpp-backend)
       :model-path path
       :device (vllm-cpp:engine-device engine)
       :engine engine))))
