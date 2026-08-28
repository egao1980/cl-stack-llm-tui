(in-package #:cl-stack-llm-tui)

(defparameter +esc+ #\Esc)

(defun %csi (code)
  (format nil "~c[~a" +esc+ code))

(defun %wrap-width (text width)
  (let ((w (max 20 width))
        (out '()))
    (dolist (para (uiop:split-string (or text "") :separator '(#\Newline)))
      (if (<= (length para) w)
          (push para out)
          (loop for i from 0 below (length para) by w
                do (push (subseq para i (min (length para) (+ i w))) out))))
    (nreverse out)))

(defun render-screen (session &key (width 80) (height 24))
  "Return a string: header + transcript + status. No raw tty required."
  (let* ((w width)
         (header (format nil " llm-tui  backend=~a  model=~a  root=~a"
                         (chat-session-backend-kind session)
                         (chat-session-model session)
                         (stack-pathlib:as-posix (workspace-root))))
         (status (format nil " ~a~@[  tools:~{~a~^,~}~]"
                         (chat-session-status session)
                         (chat-session-last-tools session)))
         (body-h (max 3 (- height 5)))
         (lines '()))
    (dolist (turn (chat-session-turns session))
      (let ((role (first turn))
            (text (second turn)))
        (dolist (ln (%wrap-width
                     (format nil "~a ~a"
                             (ecase role
                               (:user "you>")
                               (:assistant "desk>"))
                             text)
                     (- w 1)))
          (push ln lines))))
    (let* ((all (nreverse lines))
           (shown (if (> (length all) body-h)
                      (nthcdr (- (length all) body-h) all)
                      all))
           (pad (make-list (max 0 (- body-h (length shown))) :initial-element "")))
      (with-output-to-string (s)
        (format s "~a~%~a~%" header (make-string (min w (max 8 (length header)))
                                                 :initial-element #\-))
        (dolist (ln (append shown pad))
          (format s "~a~%" ln))
        (format s "~a~%~a~%" (make-string (min w 40) :initial-element #\-) status)))))

(defun %tty-p ()
  (and (interactive-stream-p *query-io*)
       (interactive-stream-p *standard-output*)))

(defun %paint (session)
  (when (%tty-p)
    (write-string (%csi "?1049h") *standard-output*)
    (write-string (%csi "H") *standard-output*)
    (write-string (%csi "2J") *standard-output*))
  (write-string (render-screen session) *standard-output*)
  (force-output *standard-output*))

(defun %restore-tty ()
  (when (%tty-p)
    (write-string (%csi "?1049l") *standard-output*)
    (force-output *standard-output*)))

(defun run-tui (&key (backend :lmstudio) session)
  (find-and-apply-dotenv)
  (with-auto-load-env
    (let ((sess (or session (make-chat-session :backend-kind backend))))
      (unwind-protect
           (with-runtime
             (loop
               (%paint sess)
               (format *query-io* "~&you> ")
               (force-output *query-io*)
               (let ((line (read-line *query-io* nil :eof)))
                 (when (or (eq line :eof) (null line))
                   (return))
                 (multiple-value-bind (handled msg)
                     (apply-slash-command sess line)
                   (cond
                     ((eq handled :quit)
                      (return))
                     (handled
                      (setf (chat-session-turns sess)
                            (append (chat-session-turns sess)
                                    (list (list :assistant msg)))))
                     ((plusp (length (string-trim '(#\Space #\Tab) line)))
                      (handler-case
                          (with-auto-load-env
                            (chat-turn sess line))
                        (error (e)
                          (setf (chat-session-turns sess)
                                (append (chat-session-turns sess)
                                        (list (list :assistant
                                                    (format nil "error: ~a" e)))))))))))))
        (%restore-tty))
      sess)))

(defun run-line-chat (&key (backend :mock) session)
  "No alt-screen — good for logs / tests / pipes."
  (find-and-apply-dotenv)
  (with-auto-load-env
    (let ((sess (or session (make-chat-session :backend-kind backend))))
      (with-runtime
        (format t "~&cl-stack-llm-tui  backend=~a  /help to list commands~%"
                (chat-session-backend-kind sess))
        (loop
          (format *query-io* "~&you> ")
          (force-output *query-io*)
          (let ((line (read-line *query-io* nil :eof)))
            (when (or (eq line :eof) (null line))
              (return))
            (multiple-value-bind (handled msg)
                (apply-slash-command sess line)
              (cond
                ((eq handled :quit) (return))
                (handled (format t "~&desk> ~a~%" msg))
                ((plusp (length (string-trim '(#\Space #\Tab) line)))
                 (handler-case
                     (let ((run (with-auto-load-env (chat-turn sess line))))
                       (format t "~&desk> ~a~%"
                               (or (ai-agent-protocol:agent-run-text run) "")))
                   (error (e)
                     (format t "~&desk> error: ~a~%" e))))))))
      sess)))
