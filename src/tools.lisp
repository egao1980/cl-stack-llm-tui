(in-package #:cl-stack-llm-tui)

(defun now-iso (&optional (universal (get-universal-time)))
  (multiple-value-bind (sec min hour date month year)
      (decode-universal-time universal)
    (format nil "~4,'0d-~2,'0d-~2,'0dT~2,'0d:~2,'0d:~2,'0d"
            year month date hour min sec)))

(defun tool-now (args)
  (declare (ignore args))
  (stack-json:encode
   (mcp-protocol:json-object
    "iso" (now-iso)
    "universal" (get-universal-time)
    "timezone" "local")))

(defun %num (x)
  (etypecase x
    (number x)
    (string (let ((n (ignore-errors (read-from-string x))))
              (unless (numberp n)
                (error 'tui-error :message (format nil "not a number: ~s" x)))
              n))))

(defun eval-calc (op a b)
  (let ((oa (%stringify op))
        (x (%num a))
        (y (%num b)))
    (cond
      ((member oa '("+" "add") :test #'string=) (+ x y))
      ((member oa '("-" "sub") :test #'string=) (- x y))
      ((member oa '("*" "mul") :test #'string=) (* x y))
      ((member oa '("/" "div") :test #'string=)
       (when (zerop y)
         (error 'tui-error :message "division by zero"))
       (/ x y))
      (t (error 'tui-error :message (format nil "unknown op ~s (use + - * /)" oa))))))

(defun tool-calc (args)
  (let* ((obj (decode-args args))
         (result (eval-calc (%arg obj "op") (%arg obj "a") (%arg obj "b"))))
    (stack-json:encode
     (mcp-protocol:json-object
      "result" (if (and (numberp result) (not (integerp result)))
                   (float result 1.0d0)
                   result)))))
