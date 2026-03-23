(defpackage :cl-matplotlib
  (:use :common-lisp :py4cl2)
  (:export
   #:try-interactive-plot))

;; you need to use the verison of py4cl2 from my repo

(in-package :cl-matplotlib)

;; You need to install all the relevant python packages
;;  matplotlib
;;  scipy
;;  PyQt6
;; Best in a virtual environment

(defparameter *loop-started* nil)

(defun start-up/internal ()
  (setf *loop-started* nil)
  (py4cl2:pyexec (format nil "import sys; sys.path.insert(0, '~a')"
			 (directory-namestring
			  (asdf:component-pathname
			   (asdf:find-component :py4cl2 "python-code")))))
  (py4cl2:pyexec (format nil "import sys; sys.path.insert(0, '~a')"
			 (directory-namestring
			  (asdf:component-pathname
			   (asdf:find-component :cl-matplotlib "python-code"))))))

(py4cl2:defpymodule "matplotlib.widgets" nil :lisp-package "WID")
;; (py4cl2:defpymodule "matplotlib.pyplot" nil :lisp-package "PLT") ;; too slow!
(py4cl2:defpymodule "matplotlib" nil :lisp-package "MPL")

(defun draw (&rest rest)
  (print rest))
  ;; (py4cl2:pymethod ax "plot"
  ;; 		   (loop repeat 3 collect (random 10))
  ;; 		   (loop repeat 3 collect (random 10)))


(defun try-callbacks ()
  (pyexec "import matplotlib.pyplot as plt")
  (destructuring-bind (fig ax)
      (pycall "plt.subplots")
    (declare (ignorable fig))
    (py4cl2:pymethod ax "plot" '(1 2 3) '(3 2 1))
    (let ((button (pycall "matplotlib.widgets.Button" ax "boo")))
      (py4cl2:pymethod button "on_clicked" (alexandria:curry 'draw ax)))
    (pycall "plt.show" :block nil)))

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

;; venv support
;;(setf (py4cl2:config-var 'py4cl2:pycmd) "/path/to/python/of/your/venv")

