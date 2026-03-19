(defpackage :cl-matplotlib
  (:use :common-lisp :py4cl2)
  (:export
   #:install-python-packages
   #:initialize))

(in-package :cl-matplotlib)

(defun install-python-packages ()
  (uiop:run-program '("pip" "install" "matplotlib")))

(defun initialize ()
  (py4cl2:pyexec "import matplotlib.pyplot as plt"))

(defpyfun "plot" "matplotlib.pyplot" :lisp-fun-name "PLOT")
(defpyfun "show" "matplotlib.pyplot" :lisp-fun-name "SHOW")

(defun do-something ()
  (let* ((time (loop for x from 0d0 below 1d0 by 0.1d0 collect x))
         (speed (mapcar (lambda (x) (* x x)) time)))
    (plot time speed ".-")
    (show)))
