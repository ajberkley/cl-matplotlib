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
  (pyexec (format nil "import sys; sys.path.insert(0, '~a')"
		  (directory-namestring
		   (asdf:component-pathname
		    (asdf:find-component :py4cl2 "python-code")))))
  (pyexec (format nil "import sys; sys.path.insert(0, '~a')"
		  (directory-namestring
		   (asdf:component-pathname
		    (asdf:find-component :cl-matplotlib "python-code"))))))

(defpymodule "matplotlib.widgets" nil :lisp-package "WID")
(defpymodule "matplotlib.pyplot" nil :lisp-package "PLT")
(defpymodule "matplotlib" nil :lisp-package "MPL")

(defun draw (ax event)
  (format t "Got event ~A~%" event)
  (pymethod ax "plot"
            (loop repeat 3 collect (random 10))
            (loop repeat 3 collect (random 10))))

(defun try-callbacks (&optional (start-loop t))
  (when start-loop (start-loop))
  (pyexec "import matplotlib; import matplotlib.pyplot as plt")
  (plt:ion) ;; this is critical otherwise redrawing doesn't happen without a plt:pause call
  (destructuring-bind (fig ax)
      (plt:subplots)
    (pymethod ax "plot" '(1 2 3) '(3 1 2))
    (pymethod fig "subplots_adjust" :bottom 0.2)
    (let* ((button-ax (pymethod fig "add_axes" '(0.7 0.05 0.1 0.075)))
           (button (pycall "matplotlib.widgets.Button" button-ax "boo")))
      (pymethod button "on_clicked" (alexandria:curry 'draw ax)))
    (plt:pause :interval 0.001)
    (plt:show :block nil)))

(defun start-loop ()
  "Call this to start the main gui loop"
  (start-up/internal)
  (py4cl2::raw-py-exec/no-return "import PyQt6_cl_matplotlib; PyQt6_cl_matplotlib.start_app(try_process_message);")

  ;; Verify that the system is OK.
  (assert (= (pyeval "1 + 1") 2))
  ;; The above will throw an error if the no-return statement did not succeed
  (setf *loop-started* t))

(defun try-interactive-plot ()
  "Call me!"
  (unless *loop-started* (start-loop))
  (pyexec "import matplotlib")
  (pyexec "import test_interactive_plot as test")
  (let ((plt (pyeval "test.testPlot()")))
    (pycall "test.testPlot.load_config" plt "src/config.yaml")
    (pycall "test.testPlot.generate_data" plt)
    (values plt (pycall "test.testPlot.make_plot" plt nil))))

;; venv support
;;(setf (py4cl2:config-var 'py4cl2:pycmd) "/path/to/python/of/your/venv")

