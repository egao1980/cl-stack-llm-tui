(in-package #:cl-stack-llm-tui)

(define-condition tui-error (error)
  ((message :initarg :message :reader tui-error-message))
  (:report (lambda (c s) (format s "~a" (tui-error-message c)))))

(define-condition sandbox-error (tui-error) ())
