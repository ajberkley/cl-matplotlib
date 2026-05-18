(defpackage :cl-matplotlib
  (:use :common-lisp :py4cl2)
  (:export
   #:demo)
  (:documentation "Make sure to call (py4cl2:initialize) first and
 I suggest using 100 as the lower limit for numpy array transferring.

 If you are using Ubuntu 22, you will need to sudo apt install libxcb-cursor0 and
 export QT_QPA_PLATFORM=xcb as wayland is broken with docking windows.

 You need to use the version of py4cl2 from my repo
"))


(in-package :cl-matplotlib)

;; venv support
;;(setf (py4cl2:config-var 'py4cl2:pycmd) "/home/tester/ajb/TYPHON-USER-DEV/cl-matplotlib/.venv/bin/python")

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

(defun draw-axis (ax)
  (let* ((fig (pymethod ax "get_figure"))
	 (canvas (pyslot-value fig "canvas")))
    (pymethod canvas "draw_idle")
    (values)))

(defparameter *counter* 0)

(defun draw (ax event)
  (declare (ignorable event))
  (incf *counter*)
  (pymethod ax "plot"
            (loop repeat 3 collect (random 10))
            (loop repeat 3 collect (random 10)))
  (draw-axis ax))

(defparameter *button* nil)

(defun show-callback-demo ()
  (let* ((fig (pycall "PyQt6_cl_matplotlib.NewFigure" "Callback demo"))
         (ax (pymethod fig "add_subplot" 111)))
    (pymethod ax "plot" '(1 2 3) '(3 1 2))
    (pymethod fig "subplots_adjust" :bottom 0.2)
    (let* ((button-ax (pymethod fig "add_axes" '(0.7 0.05 0.1 0.075)))
           (button (pycall "matplotlib.widgets.Button" button-ax "boo")))
      (pymethod button "on_clicked" (lambda (event)
                                      (draw ax event)))
      (setf *button* button))))
  
(defun demo (&optional (start-loop t))
  "This code uses Common Lisp for interactivity"
  (when start-loop (when (py4cl2:python-alive-p) (pystop)) (start-loop))
  (show-callback-demo)
  (surf-random-data)
  (plot-random-points))

(defun start-loop ()
  "Call this to start the main gui loop"
  (start-up/internal)
  (py4cl2::raw-py-exec/no-return "import PyQt6_cl_matplotlib; PyQt6_cl_matplotlib.start_app(try_process_message);")
  ;; Verify that the system is OK.
  (assert (= (pyeval "1 + 1") 2))
  ;; The above will throw an error if the no-return statement did not succeed
  (pyexec "import matplotlib; import matplotlib.pyplot as plt")
  (plt:ion)  ;; this is critical otherwise redrawing doesn't happen without a plt:pause call
  (pyeval "matplotlib.style.use('fast')")
  (setf *loop-started* t))

(defun try-interactive-plot ()
  "This code uses python for interactivity"
  (unless *loop-started* (start-loop))
  (pyexec "import matplotlib")
  (pyexec "import test_interactive_plot as test")
  (let ((plt (pyeval "test.testPlot()")))
    (pycall "test.testPlot.load_config" plt "/opt/sbcl/quicklisp/local-projects/cl-matplotlib/src/config.yaml")
    (pycall "test.testPlot.generate_data" plt)
    (values plt (pycall "test.testPlot.make_plot" plt nil))))

(defstruct uncertain-number
  (x 0d0 :type double-float)
  (s+ 0d0 :type double-float)
  (s- 0d0 :type double-float))

(defun maybe-uncertain-number-x (maybe-uncertain-number)
  (if (uncertain-number-p maybe-uncertain-number)
      (uncertain-number-x maybe-uncertain-number)
      maybe-uncertain-number))

(defun export-gaussian ()
  (py4cl2:export-function (lambda (x) (/ (exp (- (* x x)))
                                         (sqrt pi))) "lisp_gaussian"))

(deftype sadf () '(simple-array double-float (*)))

(defun plot-xy-data (x y &key (fmt "k."))
  (unless *loop-started* (start-loop))
  (when (and x y)
    (let* ((fig (pycall "PyQt6_cl_matplotlib.NewFigure" "XY plot demo"))
           (ax (pymethod fig "add_subplot" 111)))
      (if (or (uncertain-number-p (elt x 0))
              (uncertain-number-p (elt y 0)))
          (pymethod ax "errorbar"
                    (map 'sadf #'maybe-uncertain-number-x x)
                    (map 'sadf #'maybe-uncertain-number-x y)
                    :yerr (if (uncertain-number-p (elt y 0))
                              (list
                               (map 'sadf #'uncertain-number-s- x)
                               (map 'sadf #'uncertain-number-s+ x))
                              nil)
                    :xerr (if (uncertain-number-p (elt x 0))
                              (list
                               (map 'sadf #'uncertain-number-s- y)
                               (map 'sadf #'uncertain-number-s+ y))
                              nil)
                    :fmt fmt
                    :capsize 3.0)
          (pymethod ax "plot" x y fmt))
      (plt:show :block nil)
      ax)))

(defun xlabel (ax string)
  "Text in $ $ will be interpreted as LaTex. Don't forget \\"
  ;; (xlabel "Resistance ($\\Omega$)")
  (pymethod ax "set_xlabel" string))

(defun ylabel (ax string)
  "Text in $ $ will be interpreted as LaTex. Don't forget \\"
  ;; (ylabel "Resistance ($\\Omega$)")
  (pymethod ax "set_ylabel" string))

(defun title (ax string)
  "Text in $ $ will be interpreted as LaTex. Don't forget \\"
  ;; (title "My happy e$\\chi$periment")
  (pymethod ax "set_title" string))

(defun legend (ax strings &key (loc "best"))
  (pymethod ax "legend" strings :loc loc))

(defun grid (ax &optional (visible t))
  (pymethod ax "grid" :visible visible))

(defun plot-random-points (&key (N 10) (fmt "k.") (errorbars t))
  (labels ((random-point ()
             (if errorbars
                 (make-uncertain-number :x (- (random 10d0) 5d0)
                                        :s- (+ 0.5d0 (random 0.5d0))
                                        :s+ (+ 0.5d0 (random 0.5d0)))
                 (- (random 10d0) 5d0))))
    (let ((ax
            (plot-xy-data
             (loop
               repeat N
               collect (random-point))
             (loop
               repeat N
               collect (random-point))
             :fmt fmt)))
      (xlabel ax "position ($\\mu m$)")
      (ylabel ax "Resistance ($\\Omega$)")
      (title ax "My happy e$\\chi$periment")
      (grid ax t)
      (legend ax '("My data series"))
      (draw-axis ax)
      ax)))

(defun surf-data (x y z)
  (pyexec "import matplotlib")
  (pyexec "from mpl_toolkits.mplot3d import Axes3D")
  (let* ((fig (pycall "PyQt6_cl_matplotlib.NewFigure" "3D Plot Demo"))
         (ax (pymethod fig "add_subplot" 111 :projection "3d"))
         (colormap (pyeval "matplotlib.cm.coolwarm"))
         (surf (pymethod ax "plot_surface" x y z
                         :cmap colormap :linewidth 0 :antialiased nil)))
    (pymethod fig "colorbar" surf :shrink 0.5 :aspect 5)
    (draw-axis ax))

(defun surf-random-data (&optional (N 1000))
  (let ((x (make-array (list N N) :element-type 'double-float))
        (y (make-array (list N N) :element-type 'double-float))
        (z (make-array (list N N) :element-type 'double-float)))
    (dotimes (i N)
      (dotimes (j N)
        (setf (aref x i j) (* i 1d0))
        (setf (aref y i j) (* j 1d0))
        (setf (aref z i j) (random 1d0))))
    (surf-data x y z)))
  
              
  
