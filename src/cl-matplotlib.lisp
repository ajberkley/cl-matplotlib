(defpackage :cl-matplotlib
  (:use :common-lisp :py4cl2)
  (:export
   #:install-python-packages
   #:initialize))

(in-package :cl-matplotlib)

(defun install-python-packages ()
  (uiop:run-program '("pip" "install" "matplotlib"))
  (uiop:run-program '("pip" "install" "scipy")))

(defun initialize ()
  (py4cl2:pyexec "import sys")
  (py4cl2:pyexec "sys.path.insert(0, '.')")
  (py4cl2:pyexec "import matplotlib.pyplot as plt")
  (py4cl2:pyexec "from src import test_interactive_plot"))

(defpyfun "plot" "matplotlib.pyplot" :lisp-fun-name "PLOT")
(defpyfun "show" "matplotlib.pyplot" :lisp-fun-name "SHOW")

(defun do-something ()
  (let* ((time (loop for x from 0d0 below 1d0 by 0.1d0 collect x))
         (speed (mapcar (lambda (x) (* x x)) time)))
    (plot time speed ".-")
    (show)))

(defun try-interactive-plot ()
  (initialize)
  (py4cl2:pyexec "from src import test_interactive_plot as test")
  ;;(py4cl2:with-remote-objects
  (let ((plt (py4cl2:pyeval "test.testPlot()")))
    (py4cl2:pycall "test.testPlot.load_config" plt "src/config.yaml")
    (py4cl2:pycall "test.testPlot.generate_data" plt)
    (py4cl2:pycall "test.testPlot.make_plot" plt)))
