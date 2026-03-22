(defpackage :cl-matplotlib
  (:use :common-lisp :py4cl2)
  (:export
   #:try-interactive-plot))

(in-package :py4cl2)
(defun raw-py-exec/no-return (&rest strings)
  "Execute strings without expecting any return, used to pass
control permanently to, say, a GUI main loop in the python process.
Passes strings as they are, without any 'pythonize'ation."
  (python-start-if-not-alive)
  (let ((stream (uiop:process-info-input *python*))
        (str (apply #'concatenate 'string strings)))
    (bt:with-recursive-lock-held (*python-lock*) ; wait for previous processing to be done
      (write-char #\x stream)
      (stream-write-string str stream)
      (force-output stream))))

(in-package :cl-matplotlib)

;; You need to install all the relevant python packages
;;  matplotlib
;;  scipy
;;  PyQt6
;; Best in a virtual environment

(defparameter *loop-started* nil)

(defun start-up/internal ()
  (setf *loop-started* nil)
  (pystop)
  ;; Changes to py4cl2 to support inverted control loop
  (setf py4cl2::*python-code*
	(alexandria:read-file-into-string
	 (asdf:component-pathname
          (asdf:find-component :cl-matplotlib "python-code"))))
  (pystart)
  (py4cl2:pyexec (format nil "import sys; sys.path.insert(0, '~a')"
			 (directory-namestring
			  (asdf:component-pathname
			   (asdf:find-component :py4cl2 "python-code")))))
  (py4cl2:pyexec (format nil "import sys; sys.path.insert(0, '~a')"
			 (directory-namestring
			  (asdf:component-pathname
			   (asdf:find-component :cl-matplotlib "python-code"))))))

(defun start-loop ()
  "Call this to start the main gui loop"
  (start-up/internal)
  (py4cl2::raw-py-exec/no-return "import PyQt6_example; PyQt6_example.start_app(try_process_message);")
  (setf *loop-started* t))

(defun try-interactive-plot ()
  "Call me!"
  (unless *loop-started* (start-loop))
  (py4cl2:pyexec "import matplotlib")
  (py4cl2:pyexec "import test_interactive_plot as test")
  (let ((plt (py4cl2:pyeval "test.testPlot()")))
    (py4cl2:pycall "test.testPlot.load_config" plt "src/config.yaml")
    (py4cl2:pycall "test.testPlot.generate_data" plt)
    (values plt (py4cl2:pycall "test.testPlot.make_plot" plt nil))))
