(defpackage :cl-matplotlib
  (:use :common-lisp :py4cl2)
  (:import-from :lparallel)
  (:export
   #:install-python-packages
   #:initialize))

(in-package :cl-matplotlib)

;; You need to install all the relevant python packages
;;  matplotlib
;;  scipy
;;  PyQt6

(defun start-loop ()
  "Call this to start the main gui loop, then try calilng try-interactive-plot"
  (start-up/internal)
  (let ((stream (uiop:process-info-input py4cl2::*python*)))
    (bt:with-recursive-lock-held (py4cl2::*python-lock*) ; wait for previous processing to be done
      (py4cl2::write-char #\s stream)
      (force-output stream))))

(defun start-up/internal ()
  (pystop)
  ;; Our bespoke dispatch loop and inverted dispatch loop called from a
  ;; Qt6 timer.
  (setf py4cl2::*python-code*
	(alexandria:read-file-into-string
	 (asdf:component-pathname
          (asdf:find-component :cl-matplotlib "python-code"))))  
  (pystart)
  (py4cl2:pyexec "import sys")
  (py4cl2:pyexec "import matplotlib; matplotlib.use('module://mpldock.backend');")
  (py4cl2:pyexec (format nil "sys.path.insert(0, '~a')"
			 (directory-namestring
			  (asdf:component-pathname
			   (asdf:find-component :cl-matplotlib "python-code"))))))

(defpyfun "plot" "matplotlib.pyplot" :lisp-fun-name "PLOT")
(defpyfun "show" "matplotlib.pyplot" :lisp-fun-name "SHOW&")
(defpyfun "figure" "matplotlib.pyplot" :lisp-fun-name "FIGURE")

(defun show ()
  "Non-blocking show"
  (show& :block nil))

(defun do-something ()
  ;; call me after calling (start-loop)
  (let* ((time (loop for x from 0d0 below 1d0 by 0.1d0 collect x))
         (speed (mapcar (lambda (x) (* x x)) time)))
    (plot time speed ".-")
    (show)))

(defun try-interactive-plot ()
  ;; call me after calling (start-loop)
  (py4cl2:pyexec "import test_interactive_plot as test")
  (let ((plt (py4cl2:pyeval "test.testPlot()")))
    (py4cl2:pycall "test.testPlot.load_config" plt "src/config.yaml")
    (py4cl2:pycall "test.testPlot.generate_data" plt)
    (values plt (py4cl2:pycall "test.testPlot.make_plot" plt nil))))

;; Callbacks, only called at the right point in the loop
;; (defun blarg (x) (print x))
;; (defparameter *myblarg* (py4cl2::pythonize #'blarg))
;; (pyeval (format nil "~A(17 + 32)" *myblarg*))
