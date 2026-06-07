(defpackage :cl-matplotlib
  (:use :common-lisp :py4cl2)
  (:export
   #:demo
   #:plot-xy-data
   #:plot-errorbar
   #:gca
   #:mpl/xlabel
   #:mpl/ylabel
   #:mpl/title
   #:mpl/grid
   #:draw-axis
   #:mpl/zlabel
   #:tri-surf
   #:new-figure
   #:figure-window-title
   #:figure-number
   #:figure-is-open
   #:add-subplot
   #:get-figure
   #:start-loop
   #:clear-figure-tracking
   #:*active-figures*
   #:delete-figure
   #:*current-figure*
   #:set-window-style/matplotlib
   #:scatter-3d
   #:save-preferred-size-figure/matplotlib
   #:find-next-color
   #:get-used-colors
   #:clear-figure
   #:find-figure-with-window-title
   #:get-unique-figure-number
   #:*suppress-redraw*
   #:draw-figure
   #:mpl/get-colormap-samples
   #:mpl/get-colormap
   #:mpl/add-colorbar
   #:mpl/set-figure-active
   #:mpl/cla
   #:mpl/subplot
   #:mpl/gcf
   #:mpl/legend
   #:sampled-colormap-to-cmap
   #:mpl/draw-vertical-line
   #:mpl/draw-horizontal-line
   #:mpl/ginput
   #:mpl/set-xscale
   #:mpl/set-yscale
   #:mpl/xlim
   #:mpl/ylim
   #:mpl/zlim
   #:get-unused-window-title
   #:mpl/set-fig-background-color
   #:mpl/set-axes-background-color
   #:mpl/find-scalar-mappable
   #:mpl/draw-text
   #:mpl/hide-legend
   #:mpl/show-legend
   #:mpl/view
   #:mpl/subplot-exists
   #:mpl/set-tick-fontsize
   #:mpl/map-axes
   #:mpl/set-axis-label-fontsize
   #:mpl/set-title-fontsize
   #:mpl/set-legend-fontsize)
  (:documentation "
 If you are using Ubuntu 22, you will need to sudo apt install libxcb-cursor0 and
 export QT_QPA_PLATFORM=xcb as wayland is broken with docking windows.

 You need to use the version of py4cl2 from my repo"))

(in-package :cl-matplotlib)

;; venv support
;;(setf (py4cl2:config-var 'py4cl2:pycmd) "/home/tester/ajb/TYPHON-USER-DEV/cl-matplotlib/.venv/bin/python")
(setf (py4cl2:config-var 'py4cl2:numpy-pickle-lower-bound) 300)
(save-config)

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

(defvar *suppress-redraw* nil
  "When T draw-axis and draw-figure will do nothing")

(defun draw-axis (ax)
  (unless *suppress-redraw*
    (draw-figure (axis-figure ax))))

(defun draw-figure (fig)
  (unless *suppress-redraw*
    (let ((canvas (pyslot-value (figure-handle fig) "canvas")))
      (pymethod canvas "draw_idle")
      (values))))

(defstruct axis
  (handle nil) ;; a python handle
  (figure (make-figure) :type figure)
  (subplot nil)
  (colorbar nil)) ;; a python handle, is hard to find otherwise

(defmethod print-object ((obj axis) stream)
  (print-unreadable-object (obj stream)
    (let ((figure (axis-figure obj)))
      (format stream "AXIS of #~A '~A'" (figure-number figure) (figure-window-title figure)))))

(defstruct figure
  (handle nil) ;; a python handle
  (axes nil :type list) ;; a list of axes
  (current-axis nil :type (or null axis)) ;; current axis of the figure
  (layout-info nil) ;; for automatic tiled layout and stuff
  (window-title "" :type string)
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

(defun get-figure (figure-number)
  (gethash figure-number *active-figures*))

(defun find-figure-with-window-title (window-title)
  (maphash (lambda (figure-number figure)
             (declare (ignore figure-number))
             (when (string= (figure-window-title figure) window-title)
               (return-from find-figure-with-window-title figure)))
  *active-figures*)
  nil)

(defun delete-figure (figure-number)
  (let ((fig (gethash figure-number *active-figures*)))
    (when fig
      (remhash figure-number *active-figures*)
      (ignore-errors (close-figure& fig))))
  (let ((current-figure *current-figure*))
    (when (and current-figure
               (equal figure-number (figure-number current-figure)))
      (setf *current-figure* nil))))

(defun register-new-figure (figure-number window-title figure-handle
                            &optional layout current-axis)
  (assert (not (get-figure figure-number)) nil
          "Creating a new figure with same ID as existing figure")
  (let ((fig (make-figure :handle figure-handle :axes nil :current-axis current-axis
                          :layout-info layout :window-title window-title :number figure-number)))
    (setf (gethash figure-number *active-figures*) fig)
    fig))

(defun register-new-axis (figure new-axis)
  (push new-axis (figure-axes figure)))

(defun figure-is-open (figure-number)
  (gethash figure-number *active-figures*))

(defun set-active-axis-handle (axis-handle)
  "This is a callback from python"
  ;; UGH PYTHON REFERENCES ARE NOT DE-DUPLICATED
  ;; ON THE PYTHON SIDE, WTF?
  (let* ((fig *current-figure*))
    (when fig
      (let ((ax (find axis-handle (figure-axes fig) :key #'axis-handle :test
                      (lambda (a b)
                        (pyeval a " == " b))))) ;; slow!
        ;; There may not be an axis if we have never created a plot on it,
        ;; like a button, for example...?
        (when ax
          (setf (figure-current-axis fig) ax))))
    (values)))

(defun set-new-active-axis (ax)
  (let ((fig (axis-figure ax)))
    (setf *current-figure* fig)
    (pushnew ax (figure-axes fig))
    (setf (figure-current-axis fig) ax)))

(defvar *figure-counter* (list 0))

(defun get-unique-figure-number ()
  (sb-ext:atomic-incf (car *figure-counter*)))

(defvar *window-titles* '("eagle" "cow" "horse" "dog" "cat"))

(defun make-random-window-title ()
  (format nil "~a-~a"
          (elt *window-titles* (random (length *window-titles*)))
          (random 10)))

(defun get-unused-window-title ()
  (loop
    for retries below 100
    for window-title = (make-random-window-title)
    until (not (cl-matplotlib:find-figure-with-window-title window-title))
    finally (return (or window-title "ran out of title names"))))

(defun new-figure (&key window-title
                     figure-number (layout "normal"))
  (when figure-number
    (assert (not (get-figure figure-number)) nil
            "Figure with number ~A already exists" figure-number))
  (unless window-title
    (setf window-title (or figure-number (get-unused-window-title))))
  (unless figure-number (setf figure-number (get-unique-figure-number)))
  (let ((figure-handle (pycall "PyQt6_cl_matplotlib.NewFigure" window-title figure-number
                               (if (string= layout "docked") t nil))))
    (setf *current-figure* (register-new-figure figure-number window-title figure-handle layout))))

(defun mpl/set-figure-active (figure/figure-number)
  (if (typep figure/figure-number 'figure)
      (setf *current-figure* figure/figure-number)
      (let ((figure (get-figure figure/figure-number)))
        (assert figure nil "Figure with name ~A does not exist" figure/figure-number)
        (setf *current-figure* figure))))

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

(defun mpl/subplot (subplot)
  "subplot can be '(2 2 1), or 221, or '(2 2 (1 2))"
  (add-subplot *current-figure* subplot))

(defun parse-subplot-id (subplot-id)
  (if (numberp subplot-id)
      (let* ((hundreds (floor subplot-id 100))
             (tens (progn (decf subplot-id (* 100 hundreds))
                          (floor subplot-id 10)))
             (ones (decf subplot-id (* 10 tens))))
        (list hundreds tens ones))
      subplot-id))

(defun matlab-gridspec-to-matplotlib-gridspec (nrows ncols matlab-spec fig_gridspec)
  (declare (ignorable nrows))
  (let ((row-start nil)
        (col-start nil)
        (row-end nil)
        (col-end))
    (setf matlab-spec (map 'list (lambda (x) (- x 1)) matlab-spec)) ;; zero based
    (setf col-start (apply #'min (map 'list (lambda (x) (mod x ncols)) matlab-spec)))
    (setf col-end (apply #'max (map 'list (lambda (x) (mod x ncols)) matlab-spec)))
    (setf row-start (apply #'min (map 'list (lambda (x) (floor x ncols)) matlab-spec)))
    (setf row-end (apply #'max (map 'list (lambda (x) (floor x ncols)) matlab-spec)))
    ;; array indexing is exclusive of the second bound in python, not so in matlab
    (py4cl2:pyeval fig_gridspec (format nil "[~A:~A, ~A:~A]" row-start (1+ row-end) col-start (1+ col-end)))))

(defun mpl/subplot-exists (figure subplot-id)
  (and figure (find (parse-subplot-id subplot-id) (figure-axes figure) :key #'axis-subplot :test 'equal)))

(defun add-subplot (figure &optional (subplot-id 111) (projection "rectilinear"))
  "Returns an `AXIS' object.  subplot-id can be a number, from 111 to 999.  For, example, 122
 is equivalent to (subplot '(1 2 2)).  To specify, matlab style, a figure which spans many
 subplots you do: (subplot '(2 2 (3 4))) which means in a 2x2 grid, create a plot which
 spans the subplots designated by (subplot '(2 2 3)) and (subplot '(2 2 4)).  You can draw
 arbitrary boxes for subplots that way within a grid like: (subplot '(4 4 '(6 7 9 10))) is
 a large central subplot with potentially 12 small figures around it.  Counting is left to
 right and then top to bottom starting at 1.  Returns two values, the axis and T if the axis
 was pre-existing, NIL if not"
  (declare (optimize (debug 3)))
  (unless figure
    (setf figure (new-figure)))
  (setf *current-figure* figure)
  (setf subplot-id (parse-subplot-id subplot-id))
  (destructuring-bind (nrows ncols grid-desc) (or subplot-id '(1 1 1))
    (let ((ax (find subplot-id (figure-axes figure) :key #'axis-subplot :test 'equal)))
      (if ax
        (values (setf (figure-current-axis figure) ax) t)
        (if (numberp (third subplot-id)) ;; simple (subplot '( 2 3 4))
            (let* ((new-ax-handle (pymethod (figure-handle figure) "add_subplot"
                                            (nth 0 subplot-id) (nth 1 subplot-id) (nth 2 subplot-id)
                                            :projection projection))
                   (ax (make-axis :handle new-ax-handle :figure figure :subplot subplot-id)))
              (set-new-active-axis ax)
              (draw-axis ax)
              ax)
            (let ((fig-gridspec
                    (when (figure-current-axis figure)
                      (pymethod (axis-handle (figure-current-axis figure)) "get_gridspec"))))
              (when (or (not fig-gridspec)
                        (and fig-gridspec (not (and (= (pyslot-value fig-gridspec "nrows") nrows)
                                                    (= (pyslot-value fig-gridspec "ncols") ncols)))))
                (setf fig-gridspec
                      (pymethod (figure-handle figure) "add_gridspec" :nrows nrows :ncols ncols)))
              (let* ((ax (pymethod (figure-handle figure) "add_subplot"
                                   (matlab-gridspec-to-matplotlib-gridspec nrows ncols grid-desc fig-gridspec)
                                   :projection projection))
                     (new-axis (make-axis :handle ax :figure figure :subplot subplot-id)))
                (set-new-active-axis new-axis)
                (draw-axis new-axis)
                new-axis)))))))

(defparameter *counter* 0)

(defun draw (ax event)
  (declare (ignorable event))
  (incf *counter*)
  (pymethod (axis-handle ax) "plot"
            (loop repeat 3 collect (random 10))
            (loop repeat 3 collect (random 10)))
  (draw-axis ax))

(defun show-callback-demo (&optional (window-title "Callback demo"))
  (let* ((fig (or (find-figure-with-window-title window-title)
                  (new-figure :window-title window-title)))
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
  (new-figure :window-title "Errorbar demo")
  (plot-random-points :ax nil))

(defun start-loop ()
  "Call this to start the main gui loop"
  (start-up/internal)
  (py4cl2::raw-py-exec/no-return "import PyQt6_cl_matplotlib; PyQt6_cl_matplotlib.start_app(try_process_message);")
  (py4cl2:pycall "PyQt6_cl_matplotlib.set_callbacks"
                 (lambda (unique-figure-id axis)
                   (mpl/set-figure-active unique-figure-id)
                   (set-active-axis-handle axis)
                   (values))
                 (lambda (unique-figure-id)
                   (delete-figure unique-figure-id)
                   (values)))
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

(defun mpl/gcf (&optional window-title)
  "If title-provided, then will create a figure if one does not
 currently exist."
  (or *current-figure*
      (setf *current-figure* (new-figure :window-title window-title))))

(defun gca (&optional window-title-if-new)
  "Return last used axis.  If no figure exists, create a new one and a new axis"
  (let ((fig *current-figure*))
    (when (not fig)
      (setf fig (new-figure :window-title window-title-if-new)))
    (or (figure-current-axis fig) (add-subplot fig))))

(defun mpl/cla (&key (figure *current-figure*))
  (let ((ax (and figure (figure-current-axis figure))))
    (when ax
      (pymethod (axis-handle ax) "cla")
      (draw-axis ax))))
        
(defun plot-errorbar (x x+ x- y y+ y- &key linestyle color (marker "o") ax (label "") markerfacecolor
                                        markeredgecolor)
  (unless *loop-started* (start-loop))
  (setf ax (get-axis! ax))
  (unless color
    (setf color (find-next-color ax)))
  (pymethod (axis-handle ax) "errorbar" x y
            :yerr (list y- y+)
            :xerr (list x- x+)
            :linestyle (or linestyle "None")
            :markeredgecolor (or markeredgecolor color "None")
            :markerfacecolor (or markerfacecolor color "None")
            :marker (or marker "None")
            :capsize 3.0
            :label label
            :color color)
  (draw-axis ax)
  ax)

(defun get-figure! (&optional figure-title)
  "May create a new figure.  Always returns a figure."
  (mpl/gcf figure-title))

(defun get-axis! (&optional (ax (gca)) figure-title)
  "May create a new figure.  Always returns an axis."
  (or ax (gca figure-title)))

(defun plot-xy-data (x y &key linestyle color (marker "o") ax label)
  (unless *loop-started* (start-loop))
  (when (and x y)
    (setf ax (get-axis! ax))
    (unless color
      (setf color (find-next-color ax)))
    (pymethod (axis-handle ax) "plot" x y
              :linestyle (or linestyle "None")
              :color (or color "None")
              :marker (or marker "None")
              :label (or label ""))
    (draw-axis ax)
    ax))

(defun scatter-3d (x y z &key linestyle color (marker "o") ax markersize)
  (unless *loop-started* (start-loop))
  (when (and x y z)
    (pyexec "import matplotlib")
    (pyexec "from mpl_toolkits.mplot3d import Axes3D")
    (let* ((fig (unless ax (or *current-figure* (new-figure))))
           (ax (or ax (setf ax (add-subplot fig 111 "3d")))))
      (when (and linestyle (not (equalp linestyle "none")))
        (pymethod (axis-handle ax) "plot3D" x y z :c (or color "b") :linestyle linestyle))
      (apply 'pymethod (axis-handle ax) "scatter" x y z :c (or color "b") :marker marker
             (append 
              (when markersize (list :s markersize))))
      (draw-axis ax))))

(defun mpl/xlabel (string &key (ax (gca)) (draw t) fontsize)
  "Text in $ $ will be interpreted as LaTex. Don't forget \\"
  ;; (xlabel "Resistance ($\\Omega$)")
  (assert ax nil "No current axis")
  (apply 'pymethod (axis-handle ax) "set_xlabel" string
         (when fontsize (list :fontsize fontsize)))
  (when draw (draw-axis ax)))

(defun mpl/ylabel (string &key (ax (gca)) (draw t) fontsize)
  "Text in $ $ will be interpreted as LaTex. Don't forget \\"
  ;; (ylabel "Resistance ($\\Omega$)")
  (assert ax nil "No current axis")
  (apply 'pymethod (axis-handle ax) "set_ylabel" string
         (when fontsize (list :fontsize fontsize)))
  (when draw (draw-axis ax)))

(defun mpl/zlabel (string &key (ax (gca)) (draw t) fontsize)
  "Text in $ $ will be interpreted as LaTex. Don't forget \\"
  ;; (ylabel "Resistance ($\\Omega$)")
  (assert ax nil "No current axis")
  (apply 'pymethod (axis-handle ax) "set_zlabel" string
        (when fontsize (list :fontsize fontsize)))
  (when draw (draw-axis ax)))

(defun mpl/title (string &key (ax (gca)) (draw t) fontsize)
  "Text in $ $ will be interpreted as LaTex. Don't forget \\"
  ;; (title "My happy e$\\chi$periment")
  (assert ax nil "No current axis")
  (apply 'pymethod (axis-handle ax) "set_title" string
         (when fontsize (list :fontsize fontsize)))
  (when draw (draw-axis ax)))

(defun mpl/grid (&key (switch :on) (which :major) (ax (gca)) (draw t))
  (assert ax nil "No current axis")
  (py4cl2:pymethod (axis-handle ax) "grid"
                   (if (member switch '(:on :minor)) t nil)
                   :which (if (eq which :minor) "minor" "major"))
  (when draw (draw-axis ax)))

(defun mpl/xlim (x0 x1 &key (ax (gca)) (draw t))
  (assert ax nil "No current axis")
  (pymethod (axis-handle ax) "set_xlim" x0 x1)
  (when draw (draw-axis ax)))

(defun mpl/ylim (y0 y1 &key (ax (gca)) (draw t))
  (assert ax nil "No current axis")
  (pymethod (axis-handle ax) "set_ylim" y0 y1)
  (when draw (draw-axis ax)))

(defun mpl/zlim (z0 z1 &key (ax (gca)) (draw t))
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
      (mpl/xlabel "position ($\\mu m$)" :ax ax)
      (mpl/ylabel "Resistance ($\\Omega$)" :ax ax)
      (mpl/title "My happy e$\\chi$periment" :ax ax)
      (mpl/legend :legend-entries '("My data series") :ax ax)
      (draw-axis ax)
      ax)))

(defun sampled-colormap-to-cmap (sampled-colormap)
  (assert (typep sampled-colormap 'array))
  (py4cl2:pycall "matplotlib.colors.ListedColormap" sampled-colormap))

(defun mpl/surf-data (x y z &key cmap)
  (pyexec "import matplotlib")
  (pyexec "from mpl_toolkits.mplot3d import Axes3D")
  (unless cmap
    (setf cmap (pyeval "matplotlib.cm.coolwarm")))
  (let* ((fig (new-figure :window-title "3D Plot Demo"))
         (ax (add-subplot fig 111 "3d"))
         (surf (pymethod (axis-handle ax) "plot_surface" x y z
                         :cmap cmap :linewidth 0 :antialiased nil
                         :axlim_clip t)))
    (pymethod (figure-handle fig) "colorbar" surf :shrink 0.5 :aspect 5)
    (draw-axis ax)
    ax))

(defun tri-surf (x y z &key fig cmap)
  (pyexec "import matplotlib")
  (pyexec "from mpl_toolkits.mplot3d import Axes3D")
  (unless cmap
    (setf cmap (pyeval "matplotlib.cm.coolwarm")))
  (let* ((fig (or fig (new-figure :window-title "3D Plot Demo")))
         (ax (figure-current-axis fig)))
    (when ax (pymethod ax "remove")) ;; in case it isn't 3D
    (setf ax (add-subplot fig 111 "3d"))
    (pymethod (axis-handle ax) "plot_trisurf" x y z :cmap cmap :axlim_clip t)
    (draw-axis ax)))

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
    (let ((ax (mpl/surf-data x y z)))
      (mpl/title "Noisy Sync" :ax ax))))

(defun save-preferred-size-figure/matplotlib
    (filename &key (width-pixels 2000) (height-pixels 1440) (dpi 200) eps?
                name-prefix name-suffix fig-handle sub-dir)
  ;; I think if name is specified it uses it, otherwise it
  ;; puts name-prefix figure-window-title name-suffix with some fiddling,
  ;; and tidying see build-figname
  (assert filename)
  (assert (not name-prefix))
  (assert (not name-suffix))
  (assert (not fig-handle))
  (assert (not sub-dir))
  (let ((fig *current-figure*)
        (full-filename (if (search ".png" filename)
                           filename
                           (format nil "~a.~a" filename
                                   (if eps? "eps" "png")))))
    (assert fig)
    (let ((old-size (pymethod (figure-handle fig) "get_size_inches")))
      (pymethod (figure-handle fig) "set_size_inches" (round width-pixels dpi) (round height-pixels dpi))
      (pymethod (figure-handle fig) "savefig" full-filename
                :dpi dpi)
      (pymethod (figure-handle fig) "set_size_inches" old-size)
      full-filename)))

(defun get-used-colors (axis)
  (declare (type axis axis))
  (let ((children (pymethod (axis-handle axis) "get_children"))
        (colors))
    (map nil (lambda (child)
               (when (pycall "isinstance" child '|matplotlib.lines.Line2D|)
                 (push (pymethod child "get_color") colors)
                 (push (pymethod child "get_markeredgecolor") colors)
                 (push (pymethod child "get_markerfacecolor") colors)))
         children)
    colors))

(defun maybe-matlab-color-to-rgb (color)
  "color can be a matlab color, a string '#1f77b4' or a list of numbers from 0.0 to 1.0, an rgb triplet"
  (when (not (stringp color))
    (return-from maybe-matlab-color-to-rgb color))
  (when (eql (aref color 0) #\#)
    (return-from maybe-matlab-color-to-rgb
      (loop for entry below 3
            collect (/ (parse-integer color :radix 16 :start (+ 1 (* 2 entry)) :end (+ 3 (* 2 entry)))
                       255.0))))
  (macrolet ((is (&rest colors)
               `(member color ',colors :test 'equalp)))
    (cond
      ((is "r" "red") '(1.0 0.0 0.0))
      ((is "g" "green") '(0.0 1.0 0.0))
      ((is "b" "blue") '(0.0 0.0 1.0))
      ((is "c" "cyan") '(0.0 1.0 1.0))
      ((is "m" "magenta") '(1.0 0.0 1.0))
      ((is "y" "yellow") '(1.0 1.0 0.0))
      ((is "k" "black") '(0.0 0.0 0.0))
      ((is "w" "white") '(1.0 1.0 1.0))
      (t (error "Unknown color ~A" color)))))

(defvar *color-set* #((0.0 0.0 1.0) (1.0 0.0 0.0) (0.0 1.0 0.0) (0.0 0.0 0.0) (1.0 0.0 1.0) (0.0 1.0 1.0) (1.0 1.0 0.0)))

(defun find-next-color (axis)
  "Only works if user sticks with the primary colors in *color-set*."
  (let ((used-colors (make-hash-table :test 'equal)))
    (map nil (lambda (c) (setf (gethash c used-colors) 0)) *color-set*)
    (map nil (lambda (c) (incf (gethash (maybe-matlab-color-to-rgb c) used-colors 0))) (get-used-colors axis))
    (let ((best-color nil)
          (minimum-used most-positive-fixnum))
      (maphash (lambda (color count)
                 (when (< count minimum-used)
                   (setf minimum-used count)
                   (setf best-color color)))
               used-colors)
      best-color)))

(defun clear-figure (&optional (figure *current-figure*))
  (declare (type (or null figure) figure))
  (when figure
    (pymethod (figure-handle figure) "clf")
    (setf (figure-current-axis figure) nil)
    (setf (figure-axes figure) nil)
    (draw-figure figure)))

(defun mpl/add-colorbar (colormap-min colormap-max
                     &key (figure *current-figure*) (axis (figure-current-axis figure))
                       (cmap "viridis") (clip t) ticks ticklabels label interpreter)
  "Do this is you have not created your axis/plot with the :cmap key, that is
 draw a fake colormap not connected to your data (if, for example, you did coloring
 by hand).  Since this is a fake colormap CLIP is not important."
  (declare (ignorable interpreter))
  (when ticklabels (assert (= (length ticks) (length ticklabels))))
  ;; Need to delete an old colorbar if it is there
  (when (axis-colorbar axis)
    (py4cl2:pymethod (axis-colorbar axis) "remove")
    (setf (axis-colorbar axis) nil))
  (let ((norm (pycall "matplotlib.colors.Normalize"
                      :vmin colormap-min :vmax colormap-max :clip clip)))
    (prog1
        (let ((colorbar
                (apply 'py4cl2:pymethod
                       (figure-handle figure) "colorbar"
                       (py4cl2:pycall "matplotlib.cm.ScalarMappable"
                                      :cmap
                                      (if (stringp cmap)
                                          cmap
                                          (sampled-colormap-to-cmap cmap))
                                      :norm norm)
                       :ax (axis-handle axis)
                       (when label (list :label label)))))
          (setf (axis-colorbar axis) colorbar)
          (when (or ticks ticklabels)
            (py4cl2:pymethod colorbar "set_ticks" ticks :labels (or ticklabels ticks))))
      (draw-axis axis))))

(defun mpl/get-colormap (name)
  "Returns a python-object"
  (py4cl2:pyeval (format nil "matplotlib.colormaps['~A']" name)))

(defun mpl/get-colormap-samples (colormap &key (num-pts 256))
  "Takes a python-object COLORMAP, from say calling GET-COLORMAP.  Returns
 a NUM-COLORMAP-PTS x 4 array of double-floats representing RGBA"
  (pycall colormap (loop for i below num-pts collect i)))

(defun mpl/draw-vertical-line (x &key (ax (gca)) (line-colour "k") (linewidth 1)
                                   label (linestyle "-") displayname
                                   (omit-from-legend (not displayname))
                                   ;; The rest of these have to do with labels
                                   (orientation (or "vertical" "horizontal"))
                                   (horizontal-alignment (or "left" "center" "right"))
                                   (vertical-alignment (or "center" "top" "bottom"))
                                   (label-y-fraction 0.5))
  (py4cl2:pymethod (axis-handle ax) "axvline" x :color line-colour :linewidth linewidth
                                                :linestyle linestyle
                                                :label (if (or (not displayname) omit-from-legend)
                                                           "_"
                                                           displayname))
  (when label
    (py4cl2:pymethod (axis-handle ax) "text"
                     :x x
                     :y label-y-fraction
                     :transform (pymethod (axis-handle ax) "get_xaxis_transform")
                     :s label
                     :rotation orientation
                     :horizontalalignment horizontal-alignment
                     :verticalalignment vertical-alignment))
  (draw-axis (gca)))

(defun mpl/draw-horizontal-line (y &key (ax (gca)) (line-colour "k") (linewidth 1)
                                     label (linestyle "-") displayname
                                     (omit-from-legend (not displayname))
                                     ;; The rest of these have to do with labels
                                     (orientation (or "horizontal" "vertical"))
                                     (horizontal-alignment (or "center" "right" "left"))
                                     (vertical-alignment (or "center" "top" "bottom"))
                                     (label-x-fraction 0.5))
  (py4cl2:pymethod (axis-handle ax) "axhline" y
                   :color line-colour :linewidth linewidth
                   :linestyle linestyle
                   :label (if (or (not displayname) omit-from-legend) "_" displayname))
  (when label
    (py4cl2:pymethod (axis-handle ax) "text"
                     :y y
                     :x label-x-fraction
                     :transform (pymethod (axis-handle ax) "get_yaxis_transform")
                     :s label
                     :rotation orientation
                     :horizontalalignment horizontal-alignment
                     :verticalalignment vertical-alignment))
  (draw-axis (gca)))

(defun mpl/ginput (n)
  "Returns an array of x y pairs:
    [[x0 y0] [x1 y1] ... ]"
  (declare (type (integer 0) n))
  (let* ((figure *current-figure*))
    (assert figure)
    (let* ((fh (figure-handle figure))
           (dw (pyslot-value fh "dockwidget")))
      (setf (pyslot-value dw "waiting_on_ginput") n)
      (loop until (= (pyslot-value dw "waiting_on_ginput") 0)
            do (sleep 0.1))
      (let ((result (pymethod dw "get_ginputs")))
        ;; Format is a vector of (x y) pairs.  Users expect a list of xs and ys
        (loop for pair across result
              collect (elt pair 0) into xs
              collect (elt pair 1) into ys
              finally (return (list xs ys)))))))
      
(defun mpl/set-xscale (log/linear &optional (ax (gca)))
  "Use string 'log' or 'linear'"
  (pymethod (axis-handle ax) "set_xscale" log/linear)
  (draw-axis ax))

(defun mpl/set-yscale (log/linear &optional (ax (gca)))
  "Use string 'log' or 'linear'"
  (pymethod (axis-handle ax) "set_yscale" log/linear)
  (draw-axis ax))

(defun mpl/set-fig-background-color (color &key (fig *current-figure*))
  (assert *current-figure*)
  (pymethod (figure-handle fig) "set_facecolor" color))

(defun mpl/set-axes-background-color (color &key (ax (gca)))
  (pymethod (axis-handle ax) "set_facecolor" color))

(defun mpl/find-scalar-mappable (&optional (fig *current-figure*))
  (map nil (lambda (axes)
             (map nil (lambda (child)
                        (when (pycall "isinstance" child '|matplotlib.cm.ScalarMappable|)
                          (return-from mpl/find-scalar-mappable child)))
                  (pymethod axes "get_children")))
       (pymethod (figure-handle fig) "get_axes")))

(defun mpl/draw-text (x y text
                      &key horizontal-alignment (fontsize 8) (color "k") vertical-alignment
                        interpreter rotation background-color normalized-x normalized-y
                        fontweight)
  (let* ((ax (gca))
         (axh (axis-handle ax)))
    (apply 'py4cl2:pymethod axh "text" x y text
           (append
            (when interpreter (list :interpreter interpreter))
            (when rotation (list :rotation rotation))
            (when background-color (list :backgroundcolor background-color))
            (when color (list :color color))
            (when fontsize (list :fontsize fontsize))
            (when vertical-alignment (list :verticalalignment vertical-alignment))
            (when horizontal-alignment (list :horizontalalignment horizontal-alignment))
            (when fontweight (list :fontweight fontweight))
            (cond
              ((and normalized-x normalized-y)
               (list :transform (py4cl2:pyslot-value axh "transAxes")))
              (normalized-x
               (list :transform (py4cl2:pycall "matplotlib.transforms.blended_transform_factory"
                                               (py4cl2:pyslot-value axh "transAxes")
                                               (py4cl2:pyslot-value axh "transData"))))
              (normalized-y
               (list :transform
                     (py4cl2:pycall "matplotlib.transforms.blended_transform_factory"
                                    (py4cl2:pyslot-value axh "transData")
                                    (py4cl2:pyslot-value axh "transAxes")))))))
    (draw-axis ax)))

(defun mpl/hide-legend (&key (ax (gca)))
  (let ((l (py4cl2:pymethod (axis-handle ax) "get_legend")))
    (when (and l (not (equalp l "None")))
      (py4cl2:pymethod l "set_visible" nil)
      (draw-axis ax))))

(defun mpl/show-legend (&key (ax (gca)))
  "Returns T if successfully (there was a pre-existing legend) or NIL if not"
  (let ((l (py4cl2:pymethod (axis-handle ax) "get_legend")))
    (if (and l (not (equalp l "None")))
        (progn (py4cl2:pymethod l "set_visible" t)
               (draw-axis ax)
               t)
        nil)))

(defun mpl/legend (&key (ax (gca)) title location fontsize facecolor (framealpha 1.0)
                          legend-entries (ncol 1) labelcolor)
  "location is 'upper left' best etc"
  (when (member location '(:southeast "southeast") :test 'equalp)
    (setf location "lower right"))
  (when (member location '(:southwest "southwest") :test 'equalp)
    (setf location "lower left"))
  (when (member location '(:northwest "northwest") :test 'equalp)
    (setf location "upper left"))
  (when (member location '(:northeast "northeast") :test 'equalp)
    (setf location "upper right"))
  (apply 'py4cl2:pymethod (axis-handle ax) "legend"
         (append
          (when legend-entries (list legend-entries))
          (when title (list :title title))
          (when ncol (list :ncol ncol))
          (when location (list :loc location))
          (when fontsize (list :fontsize fontsize))
          (when facecolor (list :facecolor facecolor))
          (when framealpha (list :framealpha framealpha))
          (when labelcolor (list :labelcolor labelcolor))))
  (draw-axis ax))

(defun mpl/view (azimuth elevation &optional (roll 0))
  (let ((ax (gca)))
    (pymethod (axis-handle ax) "view_init"
              :elev elevation :azim azimuth :roll roll)
    (draw-axis ax)))

(defun mpl/set-tick-fontsize (fontsize)
  (let ((ax (gca)))
    (pymethod (axis-handle ax) "tick_params" :axis "both"
              :labelsize fontsize)
    (dolist (axis (map 'list (lambda (ax-name)
                               (pyslot-value (axis-handle ax) ax-name))
                       '("xaxis" "yaxis"
                         ;; "zaxis" ;; need to check and see if it exists
                         )))
      (when axis
        (let ((offset-text (pymethod axis "get_offset_text")))
          (when offset-text
            (pymethod offset-text "set_fontsize" fontsize)))))
    (draw-axis ax)))

(defun mpl/set-axis-label-fontsize (fontsize)
  (let ((ax (gca)))
    (dolist (axis (map 'list (lambda (ax-name)
                               (pyslot-value (axis-handle ax) ax-name))
                       '("xaxis" "yaxis")))
      (when axis
        (let ((label (pyslot-value axis  "label")))
          (when label
            (pymethod label "set_fontsize" fontsize)))))
    (draw-axis ax)))

(defun mpl/set-title-fontsize (fontsize)
  (let* ((ax (gca))
         (title (pyslot-value (axis-handle ax) "title")))
    (when title
      (pymethod title "set_size" fontsize)
      (draw-axis ax))))

(defun mpl/set-legend-fontsize (fontsize)
  (let* ((ax (gca))
         (legend (pymethod (axis-handle ax) "get_legend")))
    (when (and legend (not (stringp legend))) ;; "None"
      (let ((texts (pymethod legend "get_texts")))
        (when (not (stringp texts)) ;; "None"
          (map nil (lambda (label)
                     (pymethod label "set_fontsize" fontsize))
               (pycall "list" texts))))
      (draw-axis ax))))

(defun mpl/map-axes (thunk &key (figure *current-figure*))
  (dolist (axes (figure-axes figure))
    (setf (figure-current-axis figure) axes)
    (funcall thunk)))
