(defpackage :cl-matplotlib
  (:use :common-lisp :py4cl2)
  (:export
   #:demo
   #:plot-xy-data
   #:plot-errorbar)
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

;; (defpymodule "matplotlib.widgets" nil :lisp-package "WID")
;; (defpymodule "matplotlib.pyplot" nil :lisp-package "PLT")
;; (defpymodule "matplotlib" nil :lisp-package "MPL")

(defun draw-axis (ax)
  (let* ((fig (pymethod ax "get_figure"))
	 (canvas (pyslot-value fig "canvas")))
    (pymethod canvas "draw_idle")
    (values)))

(defun new-figure (&optional (title "Default title"))
  (pycall "PyQt6_cl_matplotlib.NewFigure" title))

(defun add-rectangle (x y w h &key (ax (gca)) (color "r"))
  (assert ax nil "No current axis")
  (let ((rec (pycall "matplotlib.patches.Rectangle" (list x y) w h :color color)))
    (pymethod ax "add_patch" rec)))

(defun demo-patch (&key (ax (gca)))
  (add-rectangle 2.0 2.5 0.5 0.5 :color "b" :ax ax)  
  (draw-axis ax))

(defun lots-of-patches (&optional (N 50000))
  (let* ((fig (new-figure "Patch demo"))
         (ax (pymethod fig "add_subplot" 111)))
    (labels ((random-array (range)
               (coerce (loop repeat N collect (random range))
                       '(simple-array double-float (*)))))
      (let ((xs (random-array 1d0))
            (ys (random-array 1d0))
            (ws (random-array 0.01d0))
            (hs (random-array 0.01d0)))
        (pycall "PyQt6_cl_matplotlib.draw_lots_of_patches" xs ys ws hs ax))
    ;; (time
    ;;  (dotimes (i N)
    ;;    (add-rectangle (random 1d0) (random 1d0) (random 0.01d0) (random 0.01d0)
    ;;                   :ax ax :color (elt '("r" "b" "g" "y" "c" "m" "k")
    ;;                                      (random 7)))))
    (draw-axis ax))))

(defparameter *counter* 0)

(defun draw (ax event)
  (declare (ignorable event))
  (incf *counter*)
  (pymethod ax "plot"
            (loop repeat 3 collect (random 10))
            (loop repeat 3 collect (random 10)))
  (draw-axis ax))

(defun show-callback-demo ()
  (let* ((fig (new-figure "Callback demo"))
         (ax (pymethod fig "add_subplot" 111)))
    (pymethod ax "plot" '(1 2 3) '(3 1 2))
    (pymethod fig "subplots_adjust" :bottom 0.2)
    (let* ((button-ax (pymethod fig "add_axes" '(0.7 0.05 0.1 0.075)))
           (button (pycall "matplotlib.widgets.Button" button-ax "boo")))
      (pymethod button "on_clicked" (lambda (event)
                                      (draw ax event)))
      ;; store button to prevent it from getting gc'ed
      (setf (pyslot-value fig "button") button))))
  
(defun demo (&optional (start-loop t))
  "This code uses Common Lisp for interactivity"
  (when start-loop (when (py4cl2:python-alive-p) (pystop)) (start-loop))
  (show-callback-demo)
  (surf-random-data)
  (plot-random-points :ax nil))

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

(defun export-gaussian ()
  (py4cl2:export-function (lambda (x) (/ (exp (- (* x x)))
                                         (sqrt pi))) "lisp_gaussian"))

(defun gcf (&optional (title "Default title" title-provided-p))
  (let ((fig (pyeval "PyQt6_cl_matplotlib.active_figure")))
    (print fig)
    (if (or title-provided-p (equal fig "None") (not fig))
	(new-figure title)
	fig)))

(defun gca ()
  (let ((ax (pyeval "PyQt6_cl_matplotlib.active_axis")))
    (if (equal ax "None") nil ax)))

(defun plot-errorbar (x x+ x- y y+ y- &key (fmt "b-") (ax (gca)))
  (unless *loop-started* (start-loop))
  (let* ((fig (if ax
                  (pymethod ax "get_figure")
		  (new-figure "XY plot demo")))
         (ax (or ax (pymethod fig "add_subplot" 111))))
    (pymethod ax "errorbar" x y
              :yerr (list y- y+)
              :xerr (list x- x+)
              :fmt fmt
              :capsize 3.0)
    ax))

(defun plot-xy-data (x y &key (fmt "k.") (ax (gca)))
  (unless *loop-started* (start-loop))
  (when (and x y)
    (let* ((fig (if ax
                    (pymethod ax "get_figure")
		    (new-figure "XY plot demo")))
           (ax (or ax (pymethod fig "add_subplot" 111))))
      (pymethod ax "plot" x y fmt)
      (draw-axis ax)
      ax)))

(defun xlabel (string &key (ax (gca)))
  "Text in $ $ will be interpreted as LaTex. Don't forget \\"
  ;; (xlabel "Resistance ($\\Omega$)")
  (assert ax nil "No current axis")
  (pymethod ax "set_xlabel" string)
  (draw-axis ax))

(defun ylabel (string &key (ax (gca)))
  "Text in $ $ will be interpreted as LaTex. Don't forget \\"
  ;; (ylabel "Resistance ($\\Omega$)")
  (assert ax nil "No current axis")
  (pymethod ax "set_ylabel" string)
  (draw-axis ax))

(defun zlabel (string &key (ax (gca)))
  "Text in $ $ will be interpreted as LaTex. Don't forget \\"
  ;; (ylabel "Resistance ($\\Omega$)")
  (assert ax nil "No current axis")
  (pymethod ax "set_zlabel" string)
  (draw-axis ax))

(defun title (string &key (ax (gca)))
  "Text in $ $ will be interpreted as LaTex. Don't forget \\"
  ;; (title "My happy e$\\chi$periment")
  (assert ax nil "No current axis")
  (pymethod ax "set_title" string)
  (draw-axis ax))

(defun legend (strings &key (loc "best") (ax (gca)))
  (assert ax nil "No current axis")
  (pymethod ax "legend" strings :loc loc)
  (draw-axis ax))

(defun grid (&key (visible t) (ax (gca)))
  (assert ax nil "No current axis")
  (pymethod ax "grid" :visible visible)
  (draw-axis ax))

(defun xlim (x0 x1 &key (ax (gca)))
  (assert ax nil "No current axis")
  (pymethod ax "set_xlim" x0 x1)
  (draw-axis ax))

(defun ylim (y0 y1 &key (ax (gca)))
  (assert ax nil "No current axis")
  (pymethod ax "set_ylim" y0 y1)
  (draw-axis ax))

(defun zlim (z0 z1 &key (ax (gca)))
  (assert ax nil "No current axis")
  (pymethod ax "set_zlim" z0 z1)
  (draw-axis ax))

(defun plot-random-points (&key (N 10) (fmt "k.") (errorbars t) (ax (gca)))
  (labels ((rand (&optional (scale 10d0))
             (loop repeat N collect (- (random scale) (/ scale 2d0))))
           (prand (&optional (scale 1d0))
             (loop repeat N collect (random scale))))
    (let ((ax
            (if errorbars
                (plot-errorbar (rand) (prand) (prand)
                               (rand) (prand) (prand)
                               :fmt fmt :ax ax)
                (plot-xy-data (rand) (rand) :fmt fmt :ax ax))))
      (xlabel "position ($\\mu m$)" :ax ax)
      (ylabel "Resistance ($\\Omega$)" :ax ax)
      (title "My happy e$\\chi$periment" :ax ax)
      (grid :visible t :ax ax)
      (legend '("My data series") :ax ax)
      (draw-axis ax)
      ax)))

(defun surf-data (x y z)
  (pyexec "import matplotlib")
  (pyexec "from mpl_toolkits.mplot3d import Axes3D")
  (let* ((fig (new-figure "3D Plot Demo"))
         (ax (pymethod fig "add_subplot" 111 :projection "3d"))
         (colormap (pyeval "matplotlib.cm.coolwarm"))
         (surf (pymethod ax "plot_surface" x y z
                         :cmap colormap :linewidth 0 :antialiased nil
                         :axlim_clip t)))
    (pymethod fig "colorbar" surf :shrink 0.5 :aspect 5)
    (draw-axis ax)
    ax))

(defun sqr (x) (* x x))

(defun surf-random-data (&optional (N 1000))
  (let ((x (make-array (list N N) :element-type 'double-float))
        (y (make-array (list N N) :element-type 'double-float))
        (z (make-array (list N N) :element-type 'double-float)))
    (dotimes (i N)
      (dotimes (j N)
        (setf (aref x i j) (* i 1d0))
        (setf (aref y i j) (* j 1d0))
        (setf (aref z i j)
              (let ((p (sqrt (/ (+ (sqr (- i (/ N 2)))
                                   (sqr (- j (/ N 2))))
                                (/ N 1.5d0)))))
                (if (zerop p) 1d0 (+ (/ (sin p) p) (random 0.3d0)))))))
    (let ((ax (surf-data x y z)))
      (title "Noisy Sync" :ax ax))))

