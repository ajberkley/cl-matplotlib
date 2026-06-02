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
   #:mpl/add-color-to-colormap
   #:mpl/get-colormap
   #:mpl/add-colorbar
   #:mpl/set-figure-active
   #:cla/mpl
   #:mpl/subplot)
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
  (subplot nil))

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
  
(defun new-figure (&key (window-title "default-figure")
                     (figure-number (get-unique-figure-number)) (layout "normal"))
  (assert (not (get-figure figure-number)) nil
          "Figure with number ~A already exists" figure-number)
  (let ((figure-handle (pycall "PyQt6_cl_matplotlib.NewFigure" window-title figure-number
                               (if (string= layout "docked") t nil))))
    (setf *current-figure* (register-new-figure figure-number window-title figure-handle layout))))

(defun mpl/set-figure-active (figure-number)
  (let ((figure (get-figure figure-number)))
    (assert figure nil "Figure with name ~A does not exist" figure-number)
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

(defun mpl/subplot (subplot)
  "subplot can be '(2 2 1), or 221, or '(2 2 (1 2))"
  (add-subplot *current-figure* subplot))

(defun add-subplot (figure &optional (subplot-id 111) (projection "rectilinear"))
  "Returns an `AXIS' object"
  ;; TODO check and see if a subplot already exists in the figure-axes?
  (unless figure
    (setf figure (new-figure)))
  (let ((maybe-ax (find subplot-id (figure-axes figure) :key #'axis-subplot :test 'equal)))
    (if maybe-ax
        (setf (figure-current-axis figure) maybe-ax)
        (let* ((ax (if (typep subplot-id 'sequence)
                       (progn
                         (assert (= (length subplot-id) 3))
                         (pymethod (figure-handle figure) "add_subplot"
                                   (elt subplot-id 0) (elt subplot-id 1) (elt subplot-id 2)
                                   :projection projection))
                       (pymethod (figure-handle figure) "add_subplot" subplot-id
                                 :projection projection)))
               (new-axis (make-axis :handle ax :figure figure :subplot subplot-id)))
          (set-new-active-axis new-axis)
          (draw-axis new-axis)))))

(defun lots-of-patches (&optional (N 50000))
  (let* ((fig (new-figure :window-title "Patch demo"))
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
                   (set-active-axis-handle axis))
                 (lambda (unique-figure-id)
                   (delete-figure unique-figure-id)))
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

(defun gcf (&optional (window-title "default-figure"))
  "If title-provided, then will create a figure if one does not
 currently exist."
  (or *current-figure*
      (new-figure :window-title window-title)))

(defun gca (&optional (window-title-if-new "Default figure title"))
  "Return last used axis.  If no figure exists, create a new one and a new axis"
  (let ((fig *current-figure*))
    (when (not fig)
      (setf fig (new-figure :window-title window-title-if-new)))
    (let ((ax (figure-current-axis fig)))
      (or ax (setf ax (add-subplot fig))))))

(defun cla/mpl (&key (figure *current-figure*))
  (let ((ax (and figure (figure-current-axis figure))))
    (when ax
      (pymethod (axis-handle ax) "cla")
      (draw-axis ax))))
        
(defun plot-errorbar (x x+ x- y y+ y- &key linestyle color (marker "o") ax)
  (unless *loop-started* (start-loop))
  (setf ax (get-axis! ax "Errorbar plot demo"))
  (unless color
    (setf color (find-next-color ax)))
  (pymethod (axis-handle ax) "errorbar" x y
            :yerr (list y- y+)
            :xerr (list x- x+)
            :linestyle (or linestyle "None")
            :markeredgecolor (or color "None")
            :marker (or marker "None")
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
    (unless color
      (setf color (find-next-color ax)))
    (pymethod (axis-handle ax) "plot" x y
              :linestyle (or linestyle "None")
              :color (or color "None")
              :marker (or marker "None"))
    (draw-axis ax)
    ax))

(defun scatter-3d (x y z &key linestyle color (marker "o") ax)
  (unless *loop-started* (start-loop))
  (when (and x y z)
    (pyexec "import matplotlib")
    (pyexec "from mpl_toolkits.mplot3d import Axes3D")
    (let* ((fig (unless ax (or *current-figure* (new-figure :window-title "Scatter 3D"))))
           (ax (or ax (add-subplot fig 111 "3d"))))
    (pymethod (axis-handle ax) "scatter" x y z :c (or color "b") :linestyle linestyle :marker marker))))

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
  (let* ((fig (new-figure :window-title "3D Plot Demo"))
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
  (let* ((fig (or fig (new-figure :window-title "3D Plot Demo")))
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

(defun get-used-colors (axis)
  (declare (type axis axis))
  (let ((children (pymethod (axis-handle axis) "get_children"))
        (colors))
    (map nil (lambda (child)
               (when (pycall "isinstance" child '|matplotlib.lines.Line2D|)
                 (pushnew (pymethod child "get_color") colors :test 'equal)
                 (pushnew (pymethod child "get_markeredgecolor") colors :test 'equal)
                 (pushnew (pymethod child "get_markerfacecolor") colors :test 'equal)))
         children)
    colors))

(defvar *color-set* '("b" "r" "g" "k" "m" "c" "y"))
(defun find-next-color (axis)
  (let ((colors *color-set*)) ;; switch to *category20*
    (map nil (lambda (color)
               (setf colors (remove color colors :test 'equal))
               (unless colors
                 (setf colors *color-set*)))
         (get-used-colors axis))
    (first colors)))

(defun clear-figure (&optional (figure *current-figure*))
  (declare (type (or null figure) figure))
  (when figure
    (pymethod (figure-handle figure) "clf")
    (setf (figure-current-axis figure) nil)
    (setf (figure-axes figure) nil)
    (draw-figure figure)))

(defun mpl/add-colorbar (colormap-min colormap-max
                     &key (figure *current-figure*) (axis (figure-current-axis figure))
                       (cmap "viridis") (clip t))
  "Do this is you have not created your axis/plot with the :cmap key, that is
 draw a fake colormap not connected to your data (if, for example, you did coloring
 by hand).  Since this is a fake colormap CLIP is not important."
  (let ((norm (pycall "matplotlib.colors.Normalize"
                      :vmin colormap-min :vmax colormap-max :clip clip)))
    (prog1
        (py4cl2:pymethod (figure-handle figure) "colorbar"
                         (py4cl2:pycall "matplotlib.cm.ScalarMappable"
                                        :cmap
                                        (if (stringp cmap)
                                            cmap
                                            (py4cl2:pycall "matplotlib.colors.ListedColormap" cmap))
                                        :norm norm)
                         :ax (axis-handle axis))
      (draw-axis axis))))

(defun mpl/get-colormap (name)
  "Returns a python-object"
  (py4cl2:pyeval (format nil "matplotlib.colormaps['~A']" name)))

(defun mpl/add-color-to-colormap
    (colormap new-color &key (resample-pts 256) (method :append))
  "Create a new colormap from python-object COLORMAP with new-color :append'ed or :prepend'ed to it.
 NEW-COLOR should be a sequence of length 3 of RGB or 4 of numbers RGBA (A is alpha)"
  (let ((original-colors (if (arrayp colormap) colormap (mpl/get-colormap-samples colormap :num-pts resample-pts))))
    (when (= (length new-color) 3) ;; upgrade to RGBA
      (setf new-color (list (elt new-color 0) (elt new-color 1)
                            (elt new-color 2) 1.0)))
    (pycall "matplotlib.colors.ListedColormap"
            (ecase method
              (:append (pycall "numpy.vstack" (list original-colors new-color)))
              (:prepend (pycall "numpy.vstack" (list new-color original-colors)))))))

(defun mpl/get-colormap-samples (colormap &key (num-pts 256))
  "Takes a python-object COLORMAP, from say calling GET-COLORMAP.  Returns
 a NUM-COLORMAP-PTS x 4 array of double-floats representing RGBA"
  (pycall colormap (loop for i below num-pts collect i)))
