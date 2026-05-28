(defpackage :cl-matplotlib
  (:use :common-lisp :py4cl2)
  (:export
   #:demo
   #:plot-xy-data
   #:plot-errorbar
   #:gca
   #:xlabel
   #:ylabel
   #:title
   #:legend
   #:grid
   #:draw-axis
   #:zlabel
   #:tri-surf
   #:new-figure
   #:set-figure-active
   #:figure-is-open
   #:add-subplot
   #:get-figure
   #:start-loop
   #:defun
   #:cla
   #:clear-figure-tracking
   #:*active-figures*
   #:set-active-figure
   #:delete-figure
   #:*current-figure*
   #:set-window-style/matplotlib)
  (:documentation "
 If you are using Ubuntu 22, you will need to sudo apt install libxcb-cursor0 and
 export QT_QPA_PLATFORM=xcb as wayland is broken with docking windows.

 You need to use the version of py4cl2 from my repo"))


(in-package :cl-matplotlib)

;; venv support
;;(setf (py4cl2:config-var 'py4cl2:pycmd) "/home/tester/ajb/TYPHON-USER-DEV/cl-matplotlib/.venv/bin/python")
(setf (py4cl2:config-var 'py4cl2:numpy-pickle-lower-bound) 300)

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
  (let* ((fig (axis-figure ax))
	 (canvas (pyslot-value (figure-handle fig) "canvas")))
    (pymethod canvas "draw_idle")
    (values)))

(defstruct axis
  (handle nil) ;; a python handle
  (figure (make-figure) :type figure)
  (subplot nil))

(defmethod print-object ((obj axis) stream)
  (print-unreadable-object (obj stream)
    (format stream "AXIS of ~A" (figure-name (axis-figure obj)))))

(defstruct figure
  (handle nil) ;; a python handle
  (axes nil :type list) ;; a list of axes
  (current-axis nil :type (or null axis)) ;; current axis of the figure
  (layout-info nil) ;; for automatic tiled layout and stuff
  (name nil) ;; This is the window title
  (number (- (expt 2 32) 1) :type (unsigned-byte 32))) ;; unique session identifier

(defvar *current-figure* nil
  "Should be bound locally, except of interaction at the REPL which will use this
 global value. At the REPL, activating or creating a new figure will update this.
 Logged plotting will use its own locally re-bound value for this.  A goal is to
 avoid interference between logged plotting and user interactive plotting.")

(defvar *active-figures* (make-hash-table :test 'equal)
  "All visible figures will have an entry in this hash table from their global
 identifier to a python figure object.  Careful to keep this up-to-date to not
 leak memory on the lisp (and python) side.")

(defun clear-figure-tracking ()
  (setf *current-figure* nil)
  (clrhash *active-figures*))

(defun get-figure (figure-name)
  (gethash figure-name *active-figures*))

(defun delete-figure (figure-name)
  ;;(cl-user::log-for cl-user::info "Deleting figure ~A" figure-name)
  (let ((fig (gethash figure-name *active-figures*)))
    (when fig
      (remhash figure-name *active-figures*)
      (ignore-errors (close-figure& fig))))
  (let ((current-figure *current-figure*))
    (when (and current-figure
               (equal figure-name (figure-name current-figure)))
      (setf *current-figure* nil))))

(defun register-new-figure (figure-name figure-handle &optional current-axis layout)
  (assert (not (get-figure figure-name)) nil "Creating a new figure with same name as existing figure")
  (let ((fig (make-figure :handle figure-handle :axes nil :current-axis current-axis
                          :layout-info layout :name figure-name)))
    (setf (gethash figure-name *active-figures*) fig)
    fig))

(defun register-new-axis (figure new-axis)
  (push new-axis (figure-axes figure)))

(defun set-active-figure (figure)
  ;;(cl-user::log-for cl-user::info "Setting ~A as current figure" figure)
  (setf *current-figure* figure))

(defun figure-is-open (figure-name)
  (gethash figure-name *active-figures*))

(defun set-active-axis-handle (axis-handle)
  "This is a callback from python"
  ;; UGH PYTHON REFERENCES ARE NOT DE-DUPLICATED
  ;; ON THE PYTHON SIDE, WTF?
  (let* ((fig *current-figure*))
    ;;(cl-user::log-for cl-user::info "Searching for ~A in ~A~%" axis-handle (figure-axes fig))
    (let ((ax (find axis-handle (figure-axes fig) :key #'axis-handle :test
                    (lambda (a b) (pyeval a "==" b))))) ;; slow!
      ;; There may not be an axis if we have never created a plot on it,
      ;; like a button, for example...?
      (when ax
        (setf (figure-current-axis fig) ax)))
    (values)))

(defun set-active-axis (ax)
  ;;(cl-user::log-for cl-user::info "Setting ~A as current axis" ax)
  (let ((fig (axis-figure ax)))
    (setf *current-figure* fig)
    (pushnew ax (figure-axes fig))
    (setf (figure-current-axis fig) ax)))

(defun new-figure (&optional (figure-name "default-figure") (layout "normal"))
  (assert (not (get-figure figure-name)) nil
          "Figure with name ~A already exists" figure-name)
  (let ((figure-handle (pycall "PyQt6_cl_matplotlib.NewFigure" figure-name)))
    (setf *current-figure* (register-new-figure figure-name figure-handle nil layout))))

(defun set-figure-active (figure-name)
  (let ((figure (get-figure figure-name)))
    (assert figure nil "Figure with name ~A does not exist" figure-name)
    (setf *current-figure* figure)))

(defun set-window-style/matplotlib (style)
  ;; BUGS:
  ;;  when setting NORMAL it steals mouse focus
  ;;  if has never been docked in main window will not redock
  (assert (member style '("docked" "normal") :test 'string=))
  (let ((figure *current-figure*))
    (when figure
      (let ((widget (pyslot-value (figure-handle *current-figure*) "dockwidget")))
        (pymethod widget "setFloating" (if (string= style "normal") t nil))))))

(defun close-figure& (figure)
  "Do not call me, call delete-figure"
  (declare (type figure figure))
  (pymethod (pyslot-value (pyslot-value (figure-handle figure) "figure") "dockwidget") "close_window"))

(defun add-rectangle (x y w h &key (ax (gca)) (color "r"))
  (assert ax nil "No current axis")
  (let ((rec (pycall "matplotlib.patches.Rectangle" (list x y) w h :color color)))
    (pymethod ax "add_patch" rec)))

(defun demo-patch (&key (ax (gca)))
  (add-rectangle 2.0 2.5 0.5 0.5 :color "b" :ax ax)  
  (draw-axis ax))

(defun add-subplot (figure &optional (subplot-id 111) (projection "rectilinear"))
  "Returns an `AXIS' object"
  ;; TODO check and see if a subplot already exists in the figure-axes?
  (let ((ax (pymethod (figure-handle figure) "add_subplot" subplot-id
                      :projection projection)))
    (set-active-axis (make-axis :handle ax :figure figure :subplot subplot-id))))

(defun lots-of-patches (&optional (N 50000))
  (let* ((fig (new-figure "Patch demo"))
         (ax (add-subplot fig)))
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
  (pymethod (axis-handle ax) "plot"
            (loop repeat 3 collect (random 10))
            (loop repeat 3 collect (random 10)))
  (draw-axis ax))

(defun show-callback-demo (&optional (figure-name "Callback demo"))
  (let* ((fig (or (get-figure figure-name) (new-figure figure-name)))
         (ax (add-subplot fig)))
    (pymethod (axis-handle ax) "plot" '(1 2 3) '(3 1 2))
    (pymethod (figure-handle fig) "subplots_adjust" :bottom 0.2)
    (let* ((button-ax (pymethod (figure-handle fig) "add_axes" '(0.7 0.05 0.1 0.075)))
           (button (pycall "matplotlib.widgets.Button" button-ax "boo")))
      (pymethod button "on_clicked" (lambda (event)
                                      (draw ax event)))
      ;; store button to prevent it from getting gc'ed
      (setf (pyslot-value (figure-handle fig) "button") button))))

(defun demo (&optional (start-loop t))
  "This code uses Common Lisp for interactivity"
  (clear-figure-tracking)
  (when start-loop (when (py4cl2:python-alive-p)
                     (pystop)) (start-loop))
  (show-callback-demo)
  (surf-random-data)
  (new-figure "Errorbar demo")
  (plot-random-points :ax nil))

(defun start-loop ()
  "Call this to start the main gui loop"
  (start-up/internal)
  (py4cl2::raw-py-exec/no-return "import PyQt6_cl_matplotlib; PyQt6_cl_matplotlib.start_app(try_process_message);")
  (py4cl2:pycall "PyQt6_cl_matplotlib.set_callbacks"
                 (lambda (fig-name axis)
                   (set-active-figure (get-figure fig-name))
                   (set-active-axis-handle axis))
                 (lambda (fig-name)
                   (delete-figure fig-name)))
  ;; Verify that the system is OK.
  (assert (= (pyeval "1 + 1") 2))
  ;; The above will throw an error if the no-return statement did not succeed
  (pyexec "import matplotlib; import matplotlib.pyplot as plt")
  (pyeval "plt.ion()")  ;; this is critical otherwise redrawing doesn't happen without a plt:pause call
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

(defun gcf (&optional (title "default-figure"))
  "If title-provided, then will create a figure if one does not
 currently exist."
  (or *current-figure*
      (new-figure title)))

(defun gca (&optional (figure-title-if-new "Default figure title"))
  "Return last used axis.  If no figure exists, create a new one and a new axis"
  (let ((fig *current-figure*))
    (when (not fig)
      (setf fig (new-figure figure-title-if-new)))
    (let ((ax (figure-current-axis fig)))
      (or ax (setf ax (add-subplot fig))))))

(defun cla (&key (figure *current-figure*) (subplot-id 111))
  (when figure
    (let ((ax (find-if (lambda (ax) (eql (axis-subplot ax) subplot-id))
                       (figure-axes figure))))
      (when ax
        ;;(format t "Deleting figure ~A axis ~A~%" figure ax)
        (setf (figure-axes figure) (delete ax (figure-axes figure)))
        (pymethod (figure-handle figure) "delaxes" (axis-handle ax))))))
        
(defun plot-errorbar (x x+ x- y y+ y- &key linestyle color (marker "o") ax)
  (unless *loop-started* (start-loop))
  (setf ax (get-axis! ax "Errorbar plot demo"))
  (pymethod (axis-handle ax) "errorbar" x y
            :yerr (list y- y+)
            :xerr (list x- x+)
            :linestyle linestyle
            :markeredgecolor color
            :marker marker
            :capsize 3.0)
  (draw-axis ax)
  ax)

(defun get-figure! (&optional (figure-title "Default figure title"))
  "May create a new figure.  Always returns a figure."
  (gcf figure-title))

(defun get-axis! (&optional (ax (gca)) (figure-title "Default figure title"))
  "May create a new figure.  Always returns an axis."
  (or ax (gca figure-title)))

(defun plot-xy-data (x y &key linestyle color (marker "o") ax)
  (unless *loop-started* (start-loop))
  (when (and x y)
    (setf ax (get-axis! ax "XY plot demo"))
    (pymethod (axis-handle ax) "plot" x y
              :linestyle linestyle
              :color color
              :marker marker)
    (draw-axis ax)
    ax))

(defun xlabel (string &key (ax (gca)) (draw t))
  "Text in $ $ will be interpreted as LaTex. Don't forget \\"
  ;; (xlabel "Resistance ($\\Omega$)")
  (assert ax nil "No current axis")
  (pymethod (axis-handle ax) "set_xlabel" string)
  (when draw (draw-axis ax)))

(defun ylabel (string &key (ax (gca)) (draw t))
  "Text in $ $ will be interpreted as LaTex. Don't forget \\"
  ;; (ylabel "Resistance ($\\Omega$)")
  (assert ax nil "No current axis")
  (pymethod (axis-handle ax) "set_ylabel" string)
  (when draw (draw-axis ax)))

(defun zlabel (string &key (ax (gca)) (draw t))
  "Text in $ $ will be interpreted as LaTex. Don't forget \\"
  ;; (ylabel "Resistance ($\\Omega$)")
  (assert ax nil "No current axis")
  (pymethod (axis-handle ax) "set_zlabel" string)
  (when draw (draw-axis ax)))

(defun title (string &key (ax (gca)) (draw t))
  "Text in $ $ will be interpreted as LaTex. Don't forget \\"
  ;; (title "My happy e$\\chi$periment")
  (assert ax nil "No current axis")
  (pymethod (axis-handle ax) "set_title" string)
  (when draw (draw-axis ax)))

(defun legend (strings &key (loc "best") (ax (gca)) (draw t))
  (assert ax nil "No current axis")
  (pymethod (axis-handle ax) "legend" strings :loc loc)
  (when draw (draw-axis ax)))

(defun grid (&key (visible t) (ax (gca)) (draw t))
  (assert ax nil "No current axis")
  (pymethod (axis-handle ax) "grid" :visible visible)
  (when draw (draw-axis ax)))

(defun xlim (x0 x1 &key (ax (gca)) (draw t))
  (assert ax nil "No current axis")
  (pymethod (axis-handle ax) "set_xlim" x0 x1)
  (when draw (draw-axis ax)))

(defun ylim (y0 y1 &key (ax (gca)) (draw t))
  (assert ax nil "No current axis")
  (pymethod (axis-handle ax) "set_ylim" y0 y1)
  (when draw (draw-axis ax)))

(defun zlim (z0 z1 &key (ax (gca)) (draw t))
  (assert ax nil "No current axis")
  (pymethod (axis-handle ax) "set_zlim" z0 z1)
  (when draw (draw-axis ax)))

(defun plot-random-points (&key (N 10) (marker ".") (linestyle "-") (color "k") (errorbars t) (ax (gca)))
  (labels ((rand (&optional (scale 10d0))
             (loop repeat N collect (- (random scale) (/ scale 2d0))))
           (prand (&optional (scale 1d0))
             (loop repeat N collect (random scale))))
    (let ((ax
            (if errorbars
                (plot-errorbar (rand) (prand) (prand)
                               (rand) (prand) (prand)
                               :marker marker :linestyle linestyle :color color
                               :ax ax)
                (plot-xy-data (rand) (rand) :marker marker :linestyle linestyle
                                            :color color :ax ax))))
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
         (ax (add-subplot fig 111 "3d"))
         (colormap (pyeval "matplotlib.cm.coolwarm"))
         (surf (pymethod (axis-handle ax) "plot_surface" x y z
                         :cmap colormap :linewidth 0 :antialiased nil
                         :axlim_clip t)))
    (pymethod (figure-handle fig) "colorbar" surf :shrink 0.5 :aspect 5)
    (draw-axis ax)
    ax))

(defun tri-surf (x y z &key fig)
  (pyexec "import matplotlib")
  (pyexec "from mpl_toolkits.mplot3d import Axes3D")
  (let* ((fig (or fig (new-figure "3D Plot Demo")))
         (ax (figure-current-axis fig)))
    ;; TODO FIXME
    (when ax (pymethod ax "remove")) ;; in case it isn't 3D
    (setf ax (add-subplot 111 :projection "3D"))
    (let ((colormap (pyeval "matplotlib.cm.coolwarm")))
      (pymethod ax "plot_trisurf" x y z :cmap colormap :axlim_clip t)
      (draw-axis ax))))

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

(defun save-preferred-size-figure
    (filename &key (width-pixels 2000) (height-pixels 1440) (dpi 200) eps?
                name-prefix name-suffix fig-handle)
  ;; I think if name is specified it uses it, otherwise it
  ;; puts name-prefix figure-name name-suffix with some fiddling,
  ;; and tidying see build-figname
  (assert filename)
  (assert (not name-prefix))
  (assert (not name-suffix))
  (assert (not fig-handle))
  (let ((fig *current-figure*))
    (assert fig)
    (let ((old-size (pymethod (figure-handle fig) "get_size_inches")))
      (pymethod (figure-handle fig) "set_size_inches" (round width-pixels dpi) (round height-pixels dpi))
      (pymethod (figure-handle fig) "savefig" (if (search ".png" filename)
                                                  filename
                                                  (format nil "~a.~a" filename
                                                          (if eps? "eps" "png")))
                :dpi dpi)
      (pymethod (figure-handle fig) "set_size_inches" old-size))))

