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
   #:add-subplot
   #:get-figure
   #:start-loop
   #:clear-figure-tracking
   #:*active-figures*
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
   #:mpl/xlim
   #:mpl/ylim
   #:mpl/zlim
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
   #:mpl/set-axis-label-props
   #:mpl/set-title-props
   #:mpl/error-messages
   #:mpl/get-grid-size
   #:mpl/reflow-subplots
   #:mpl/set-figure-tiled-layout-request
   #:raise-figure
   #:mpl/plot-universal-time-series
   #:mpl/bar3d
   #:mpl/set-legend-string-on-last-data-series
   #:mpl/set-legend-title
   #:mpl/set-axis-tick-label
   #:mpl/contour
   #:mpl/set-axis-tick-props
   #:mpl/set-legend-props
   #:mpl/legend-visible?
   #:mpl/legend-exists?
   #:renumber-figure
   #:close-figure
   #:mpl/draw-arrow
   #:mpl/draw-polygon
   #:mpl/set-line-prop
   #:mpl/set-all-line-props
   #:mpl/set-logscale
   #:mpl/set-linearscale
   #:mpl/set-axis-props
   #:mpl/set-error-bar-props
   #:mpl/set-axis-tick-location
   #:mpl/figure
   #:mpl/apply-colormap
   #:mpl/caxis
   #:mpl/plot-image
   #:mpl/axis-square
   #:mpl/axis-equal
   #:mpl/plot-bar
   #:mpl/suptitle
   #:mpl/scatter
   #:mpl/pcolormesh
   #:mpl/get-colorbar
   #:mpl/set-colorbar-label
   #:mpl/surf-data
   #:mpl/plot-polygon
   #:mpl/shoelace
   #:mpl/trisurf*
   #:mpl/modify-title-text
   #:mpl/link-axis
   #:mpl/next-subplot-grid
   #:mpl/tripcolor
   #:mpl/pcolor
   #:mpl/undo
   #:mpl/redo
   #:*copy-callback*
   #:*paste-callback*
   #:*undo-callback*
   #:*redo-callback*
   #:*delete-callback*
   #:mpl/paste-trace-to-active-figure
   #:mpl/delete-trace
   #:mpl/set-window-title
   #:stop-headless-matplotlib
   #:mpl/run-headless
   #:mpl/figure-is-open)
  (:documentation "Wrapper around much of matplotlib functionality focusing on its
 use in interactive plotting and data exploration.  The focus is on drawing and
 modifying a plot so follows the 'matlab' style where one has an 'active figure' and
 an 'active axes' where one plots data to or modifies the styles of.  Thus, while
 every function in this package takes an axis object, it defaults to (gca) which gets
 the current axis (or creates one).

 Figures are made active or created by: (mpl/figure figure-identifier).  They are deleted
 by (close-figure figure).  Every figure keeps a list of axes in (figure-axes figure), and the
 current axes is
 (figure-current-axis figure).
 
 If you are using Ubuntu 22, you will need to sudo apt install libxcb-cursor0 and
 export QT_QPA_PLATFORM=xcb as wayland is broken with docking windows.

 You need to use the version of py4cl2 from my repo"))

(in-package :cl-matplotlib)

;; venv support
;;(setf (py4cl2:config-var 'py4cl2:pycmd) "/home/tester/ajb/TYPHON-USER-DEV/cl-matplotlib/.venv/bin/python")
;;(setf (py4cl2:config-var 'py4cl2:numpy-pickle-lower-bound) 300)
;; (save-config)

;; You need to install all the relevant python packages
;;  matplotlib
;;  scipy
;;  PyQt6
;; Best in a virtual environment

(defparameter *loop-started* nil)

(defun import-all-code ()
  (pyexec (format nil "import sys; sys.path.insert(0, '~a')"
		  (directory-namestring
		   (asdf:component-pathname
		    (asdf:find-component :py4cl2 "python-code")))))
  (pyexec (format nil "import sys; sys.path.insert(0, '~a')"
		  (directory-namestring
		   (asdf:component-pathname
		    (asdf:find-component :cl-matplotlib "python-code"))))))

(defun start-up/internal ()
  (setf *loop-started* nil)
  (import-all-code))

;; (defpymodule "matplotlib.widgets" nil :lisp-package "WID")
;; (defpymodule "matplotlib.pyplot" nil :lisp-package "PLT")
;; (defpymodule "matplotlib" nil :lisp-package "MPL")

(defvar *suppress-redraw* nil
  "When T draw-axis and draw-figure will do nothing")

(defstruct figure
  (handle nil) ;; a python handle to the matplotlib figure object
  (dockwidget nil) ;; a python handle to the matplotlib dockwidget object
  (axes nil :type list) ;; a list of axes
  (current-axis nil) ;; current axis of the figure (nil or an `axis')
  (window-title "" :type string)
  (tiled-layout-request '(1 1)) ;; '(2 2) for example, or :flow
  (number (- (expt 2 32) 1) :type (unsigned-byte 32)) ;; unique session identifier
  (interactive-labels nil)) ;; stores interactive label handles so they don't get gc'ed

(defstruct axis
  (handle nil) ;; a python handle
  (figure (make-figure) :type figure)
  (subplot nil)
  (colorbar nil) ;; a python handle, is hard to find otherwise
  (interactive-legends nil)) ;; stores interactive-legend handles so they don't get gc'ed

(defmethod print-object ((obj axis) stream)
  (print-unreadable-object (obj stream)
    (let ((figure (axis-figure obj)))
      (format stream "AXIS ~A of #~A '~A'" (axis-subplot obj) (figure-number figure) (figure-window-title figure)))))

(defvar *current-figure* nil
  "Should be bound locally, except of interaction at the REPL which will use this
 global value. At the REPL, activating or creating a new figure will update this.
 Logged plotting will use its own locally re-bound value for this.  A goal is to
 avoid interference between logged plotting and user interactive plotting.")

(defvar *active-figures* (make-hash-table :test 'equal :synchronized t)
  "All visible figures will have an entry in this hash table from their global
 identifier to a python figure object.  Careful to keep this up-to-date to not
 leak memory on the lisp (and python) side.")

(defun draw-figure (fig)
  (unless *suppress-redraw*
    (let ((canvas (pyslot-value (figure-handle fig) "canvas")))
      (pymethod canvas "draw_idle")
      (values))))

(defun draw-axis (ax)
  (unless *suppress-redraw*
    (draw-figure (axis-figure ax))))

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

(defun find-figure (name &optional (fuzzy t))
  (if fuzzy
      (let ((found nil)
            (found-value 0.8))
        ;; warning the mk-string-metrics library will quietly
        ;; return bogus values if you pass it anything except
        ;; simple-array character
        (maphash (lambda (k v)
                   (declare (ignore k))
                   (let ((closeness
                           (mk-string-metrics:jaro-winkler
                            (coerce (figure-window-title v) '(simple-array character (*)))
                            (coerce name '(simple-array character (*))))))
                     (when (> closeness found-value)
                       (setf found v)
                       (setf found-value closeness))))
                 *active-figures*)
        found)
      (when (stringp name) (find-figure-with-window-title name))))

(defun mpl/set-figure-active (figure/figure-number)
  (let ((oldfig *current-figure*))
    (when oldfig
       ;; Sometimes this object is partially deleted
       ;; on the python side if it was closed.
       (pymethod (figure-dockwidget oldfig) "setWindowTitle"
                 (figure-window-title *current-figure*))))
  (unless figure/figure-number
    (setf *current-figure* nil)
    (return-from mpl/set-figure-active nil))
  (let ((newfig (if (typep figure/figure-number 'figure)
                    figure/figure-number
                    (get-figure figure/figure-number))))
    (assert newfig nil "Figure with name ~A does not exist" figure/figure-number)
    (setf *current-figure* newfig)
    (pymethod (figure-dockwidget newfig) "setWindowTitle"
              (concatenate 'string "*" (figure-window-title newfig) "*"))
    newfig))
  

(defun raise-figure (figure &optional (delay nil))
  "If the figure is new, we want to delay to give the gui loop a
 chance to show() it first so it can raise it"
  (let ((dockwidget (figure-dockwidget figure)))
    (if delay
        (pycall "PyQt6_cl_matplotlib.PyQt6.QtCore.QTimer.singleShot"
                50
                (lambda () (pymethod dockwidget "raise_")))
        (pymethod dockwidget "raise_"))))

(defvar *window-titles* '("cow" "eagle" "horse" "dog" "cat" "rat"))
(defvar *plot-counter* (list 0))

(defun get-window-title (figure-number)
  (format nil "~A: ~A"
          figure-number
          (elt *window-titles* (mod (sb-ext:atomic-incf (car *plot-counter*)) (length *window-titles*)))))

(defvar *figure-counter* (list 0))

(defun get-unique-figure-number ()
  (loop for fig = (sb-ext:atomic-incf (car *figure-counter*))
        for figure-exists = (gethash fig *active-figures*)
        while figure-exists
        finally (return fig)))

(defun register-new-figure (figure-number window-title figure-handle
                            &optional layout tiled-layout-request current-axis)
  (declare (ignore layout))
  (assert (not (get-figure figure-number)) nil
          "Creating a new figure with same ID as existing figure")
  (let ((fig (make-figure :handle figure-handle :axes nil :current-axis current-axis
                          :window-title window-title :number figure-number
                          :tiled-layout-request (or tiled-layout-request '(1 1))
                          :dockwidget (pyslot-value figure-handle "dockwidget"))))
    (setf (gethash figure-number *active-figures*) fig)
    fig))

(defun new-figure (&key window-title
                     figure-number (layout "tabbed")
                     (tiled-layout-request '(1 1))
                     invisible
                     (set-active (not invisible))
                     size-inches
                     dpi)
  (declare (optimize (debug 3)))
  ;; layout can be "floating" "docked" "tabbed"
  (assert (member layout '("floating" "docked" "tabbed") :test 'string=))
  (when figure-number
    (assert (not (get-figure figure-number)) nil
            "Figure with number ~A already exists" figure-number))
  (unless figure-number (setf figure-number (get-unique-figure-number)))
  (unless window-title
    (setf window-title (get-window-title figure-number)))
  ;; Callbacks may happen on this figure as soon as NewFigure is called, so
  ;; make sure we have the dock
  (let* ((figure-handle
          (apply
           #' pycall
           (if invisible
               "headless_matplotlib.NewHeadlessFigure"
               "PyQt6_cl_matplotlib.NewFigure")
           window-title figure-number
           :docked (if (or (string= layout "docked")
                           (string= layout "tabbed"))
                       t
                       nil)
           :tabbed (if (equalp layout "tabbed")
                       t
                       nil)
           (append
            (when size-inches (list :size_inches size-inches))
            (when dpi (list :dpi dpi)))))
         (fig (register-new-figure figure-number window-title figure-handle layout
                                   tiled-layout-request)))
    ;; Disabling the set-active feature isn't that useful because
    ;; there are callbacks from python that call this.
    (when set-active (mpl/set-figure-active fig))
    fig))

(defun mpl/figure (identifier &key (fuzzy-match nil) (layout "tabbed"))
  "identifier is either the window title or the identifier used in a previous
 call to figure.  Sets the *current-figure* to the new or found figure.  If
 you are identifying a figure by the window name, you can use fuzzy-match t to
 try avoid having to type the full name."
  (let ((delay-raise nil))
    (labels ((new-fig (name/number)
               (let ((fig-num (if (numberp name/number)
                                  name/number
                                  (get-unique-figure-number))))
                 (setf delay-raise t)
                 (new-figure
                  :window-title (if (stringp name/number)
                                    name/number
                                    (get-window-title fig-num))
                  :figure-number fig-num
                  :layout layout))))
      (if identifier
          (let ((figure (or (get-figure identifier)
                            (find-figure identifier fuzzy-match)
                            (new-fig identifier))))
            (mpl/set-figure-active figure)
            (raise-figure figure delay-raise)
            figure)
          (let ((figure (new-fig nil)))
            (mpl/set-figure-active figure)
            (raise-figure figure delay-raise)
            figure)))))

(defun delete-figure& (figure-number)
  "Does not close the window, that should be done by calling close-window&
 which may trigger a callback to this.  May be called with -1 if we are
 deleting a figure which we already removed from the hash table"
  (declare (type (not figure) figure-number))
  (let ((fig (gethash figure-number *active-figures*)))
    (when fig
      (remhash figure-number *active-figures*)))
  (let ((current-figure *current-figure*))
    (when (and current-figure
               (equal figure-number (figure-number current-figure)))
      (setf *current-figure* nil))))

(defun set-figure-unique-id (figure new-unique-id)
  (setf (pyslot-value (figure-dockwidget figure) "unique_figure_id") new-unique-id))

(defun mpl/set-window-title (window-title &key (figure *current-figure*))
  (pymethod (figure-dockwidget figure) "setWindowTitle" window-title)
  (setf (figure-window-title figure) window-title))

(defun close-figure (figure)
  (declare (type figure figure))
  ;; The below will trigger a callback to delete-figure&, but we
  ;; clear the current-figure anyway
  (when (eq figure *current-figure*)
    (setf *current-figure* nil))
  (pymethod (figure-dockwidget figure) "close_window"))

(defun renumber-figure (figure-num &optional new-window-title)
  (let ((fig *current-figure*))
    (assert fig)
    (let ((already-existing-figure (gethash figure-num *active-figures*)))
      (when already-existing-figure
        (restart-case
            (error "Figure ~A already exists with figure-number ~A"
                   (figure-window-title already-existing-figure)
                   (figure-number already-existing-figure))
          (OVERWRITE ()))
        (remhash figure-num *active-figures*)
        ;; We already removed this from *active-figures* and will be
        ;; replacing it with a new one, so make sure the closing callback
        ;; does not delete the wrong figure!
        (set-figure-unique-id already-existing-figure -1)
        (close-figure already-existing-figure)))
    (set-figure-unique-id fig figure-num)
    (remhash (figure-number fig) *active-figures*)
    (setf (figure-number fig) figure-num)
    (setf (gethash figure-num *active-figures*) fig)
    (when new-window-title
      (mpl/set-window-title new-window-title :figure fig))
    figure-num))

(defun register-new-axis (figure new-axis)
  (push new-axis (figure-axes figure)))

(defun mpl/figure-is-open (figure)
  (gethash (figure-number figure) *active-figures*))

(defun axis-from-axis-handle (axis-handle &optional (fig *current-figure*))
  ;; Python references are not de-duplicated on the python side, so we need
  ;; to go back and test.
  (find axis-handle (figure-axes fig) :key #'axis-handle :test
        (lambda (a b)
          (pyeval a " == " b))))

(defun set-active-axis-handle (axis-handle &optional (fig *current-figure*))
  "This is a callback from python"
  ;; UGH PYTHON REFERENCES ARE NOT DE-DUPLICATED
  ;; ON THE PYTHON SIDE, WTF?
  (unless (equal axis-handle "None")
    (when fig
      (let ((ax (axis-from-axis-handle axis-handle fig))) ;; slow!
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

(defun set-window-style/matplotlib (style &optional (Figure *current-figure*))
  (assert (member style '("tabbed" "docked" "floating") :test 'string=))
  (when figure
    (pycall
     (cond
       ((string= style "tabbed") "PyQt6_cl_matplotlib.TabFigure")
       ((string= style "floating") "PyQt6_cl_matplotlib.FloatFigure")
       (t "PyQt6_cl_matplotlib.DockFigure"))
     (figure-handle figure))))

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

(defun mpl/set-figure-tiled-layout-request (spec &optional (figure *current-figure*))
  "spec is like '(2 2) or :flow"
  (setf (figure-tiled-layout-request figure) spec))

(defun add-subplot (figure &optional (subplot-id nil) (projection "rectilinear"))
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
  (let ((tiledlayout (figure-tiled-layout-request figure)))
    (setf subplot-id (parse-subplot-id (or subplot-id
                                           (if (listp tiledlayout)
                                               (append tiledlayout '(1))
                                               '(1 1 1))))))
  (destructuring-bind (nrows ncols grid-desc) subplot-id
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

(defun mpl/subplot (subplot)
  "subplot can be '(2 2 1), or 221, or '(2 2 (1 2))"
  (add-subplot *current-figure* subplot))

(defun delete-axis (ax &optional (figure *current-figure*))
  (when figure
    (setf (figure-axes figure) (remove ax (figure-axes figure)))
    (when (eq (figure-current-axis figure) ax)
      (setf (figure-current-axis figure) nil))))

(defparameter *copied-trace* nil
  "The last trace that was copied with Ctrl-c (or ctrl-x or <delete>)")
(defparameter *undo* nil
  "Stores lists of two functions, first is an undo function, second is a redo function")
(defparameter *redo* nil
  "Stores lists of two functions, first is an undo function, second is a redo function")

(defvar *copy-callback* (lambda (trace-info) (declare (ignorable trace-info)))
  "a lambda (trace-info) to get called on ctrl-c, ctrl-x, <delete>.  trace-info will have been
 stored in *copied-trace*.  User extension point.")

(defvar *paste-callback* (lambda (copied-trace) (mpl/paste-trace-to-active-figure copied-trace))
  "A lambda (trace-info) to get called on ctrl-v.  User extension point")

(defvar *undo-callback* (lambda () (mpl/undo))
  "A lambda () that will get called on ctrl-z.  User extension point")

(defvar *redo-callback* (lambda () (mpl/redo))
  "A lambda () that will get called on ctrl-shift-z.  User extension point")

(defvar *delete-callback* (lambda (trace-id axes-id) (mpl/delete-trace trace-id axes-id))
  "A lambda (trace-id) to get called on <delete>.  trace-id is the position of the
 artist which should be deleted.  User etension point.")

(defun undisplace-array-if-possible (x)
  (if (vectorp x)
      (multiple-value-bind (displaced-to offset)
          (array-displacement x)
        (if (and (zerop offset) (= (length displaced-to) (length x)))
            displaced-to
            x))
      x))

(defun clean-up-copied-trace! (copied-trace)
  "py4cl2 sometimes generates (vector double-float) displaced to simple-array double-float (*) of the same
 size.  This is silly (and triggers a now fixed bug in cl-binary-store).  Destructively modify copied-trace
 by seeing if we can undisplace the arrays.  copied-trace is a sequence of stuff."
  (map-into copied-trace (lambda (x)
                           (if (vectorp x)
                               (undisplace-array-if-possible x)
                               x))
            copied-trace))

(defun configure-matplotlib ()
  (pyexec "import matplotlib; import matplotlib.pyplot as plt")
  (pyeval "plt.ion()")
  (pyeval "matplotlib.style.use('fast')")
  (pyexec "matplotlib.rcParams['axes.formatter.limits'] = (-2, 2)")
  (pyexec "matplotlib.rcParams['axes.formatter.use_mathtext'] = True")
  (pyexec (format nil "matplotlib.rcParams['savefig.directory'] = '~A'"
                  *default-pathname-defaults*))
  (pyexec "matplotlib.rcParams['axes.formatter.useoffset'] = False"))

(defun start-loop ()
  "Call this to start the main gui loop"
  (start-up/internal)
  (py4cl2:pyexec "import PyQt6_cl_matplotlib;")
  (py4cl2:raw-py-exec/no-return "PyQt6_cl_matplotlib.start_app(try_process_message);")
  (py4cl2:pycall "PyQt6_cl_matplotlib.set_callbacks"
                 (lambda (unique-figure-id axis)
                   (unless (eql unique-figure-id -1)
                     (ignore-errors ;; this callback may fire before figure is built, that's OK, ignore
                      (let ((fig (mpl/set-figure-active unique-figure-id)))
                        (set-active-axis-handle axis fig))))
                   (values))
                 (lambda (unique-figure-id)
                   (delete-figure& unique-figure-id)
                   (values))
                 (lambda (unique-figure-id)
                   (mpl/set-figure-active unique-figure-id)
                   (let ((ax (figure-current-axis *current-figure*)))
                     (when ax
                       (let ((l (py4cl2:pymethod (axis-handle ax) "get_legend")))
                         (if (and l (not (equal l "None")))
                             (progn
                               (pymethod l "set_visible"
                                         (if (eql (pymethod l "get_visible") t) nil t))
                               (draw-axis ax))
                             (mpl/legend))))))
                 (lambda (trace-info)
                   (setf trace-info (clean-up-copied-trace! trace-info))
                   (setf *copied-trace* trace-info)
                   (funcall *copy-callback* trace-info))
                 (lambda ()
                   (funcall *paste-callback* *copied-trace*))
                 (lambda ()
                   (funcall *undo-callback*))
                 (lambda ()
                   (funcall *redo-callback*))
                 (lambda (trace-id axis-id)
                   (funcall *delete-callback* trace-id axis-id))
                 (lambda ()
                   (mpl/figure nil)))
  ;; Verify that the system is OK.
  (assert (= (pyeval "1 + 1") 2))
  ;; The above will throw an error if the no-return statement did not succeed
  (configure-matplotlib)
  (setf *loop-started* t))

(defun export-gaussian ()
  (py4cl2:export-function (lambda (x) (/ (exp (- (* x x)))
                                         (sqrt pi))) "lisp_gaussian"))

(defun mpl/gcf (&optional window-title)
  "If title-provided, then will create a figure if one does not
 currently exist. Returns the figure struct of the currently active figure."
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

(defun get-used-colors (axis)
  "Returns a hash table of RGB triplets (lists) and counts of them"
  (declare (type axis axis))
  (pycall "PyQt6_cl_matplotlib.get_axis_used_colors" (axis-handle axis)))

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

(defvar *color-set* #((0d0 0d0 1d0) (1d0 0d0 0d0) (0d0 1d0 0d0) (0d0 0d0 0d0) (1d0 0d0 1d0) (0d0 1d0 1d0) (0d0 1d0 0d0)))

(defun find-next-color (axis)
  "Only works if user sticks with the primary colors in *color-set*."
  (let ((used-colors (make-hash-table :test 'equal)))
    (map nil (lambda (c) (setf (gethash c used-colors) 0)) *color-set*)
    (maphash (lambda (c count) (incf
                                    (gethash (maybe-matlab-color-to-rgb c) used-colors 0)
                                    count))
         (get-used-colors axis))
    (let ((best-color nil)
          (minimum-used most-positive-fixnum))
      (maphash (lambda (color count)
                 (when (< count minimum-used)
                   (setf minimum-used count)
                   (setf best-color color)))
               used-colors)
      best-color)))

(defun get-axis! (&optional (ax (gca)) figure-title)
  "May create a new figure.  Always returns an axis."
  (or ax (gca figure-title)))

(defun make-trace-name (displayname hide-in-legend)
  (cond (hide-in-legend "_")
        ((and (or (string= displayname "") (not displayname)) (not hide-in-legend))
         (let ((children (pymethod (axis-handle (gca)) "get_children")))
           (format nil "data-~A"
                   (if (typep children 'sequence)
                       (count-if (lambda (x) (or (pycall "isinstance" x '|matplotlib.lines.Line2D|))) children)
                       0))))
        (displayname displayname)))

(defun plot-errorbar (x x+ x- y y+ y- &key linestyle color (marker "o") markersize ax (label "") markerfacecolor linewidth
                                        markeredgecolor hide-in-legend (picker 5))
  "Note picker copy operation does not grab error bars yet..."
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
            :capsize 3d0
            :label (make-trace-name label hide-in-legend)
            :color color
            :markersize (or markersize "None")
            :linewidth (or linewidth 2)
            :picker picker)
  (draw-axis ax)
  ax)

(defun get-figure! (&optional figure-title)
  "May create a new figure.  Always returns a figure."
  (mpl/gcf figure-title))

(defun plot-xy-data (x y &key linestyle color (marker "o") markersize label hide-in-legend (ax (gca)) (picker 5))
  (when (and x y)
    (unless color
      (setf color (find-next-color ax)))
    (let ((artist
            (apply 'pymethod (axis-handle ax) "plot" x y
                   :linestyle (or linestyle "None")
                   :color (or color "None")
                   :marker (or marker "None")
                   :markersize (or markersize "None")
                   :label (make-trace-name label hide-in-legend)
                   (when picker (list :picker picker)))))
    (draw-axis ax)
    (values ax artist))))

(defun is-3d-axis (ax)
  (string= (pyslot-value (axis-handle ax) "name") "3d"))

(defun ensure-3d-axis (ax)
  (if (is-3d-axis ax)
      ax
      (progn
        (pymethod (axis-handle ax) "remove")
        (delete-axis ax)
        (setf (figure-current-axis (axis-figure ax))
              (add-subplot (axis-figure ax) (axis-subplot ax) "3d")))))

(defun scatter-3d (x y z &key linestyle color (marker "o") ax markersize colormap facecolor markerfacecolor displayname linewidth hide-in-legend markeredgecolor)
  (when (and x y z)
    (pyexec "import matplotlib")
    (pyexec "from mpl_toolkits.mplot3d import Axes3D")
    (let* ((ax (ensure-3d-axis (or ax (gca)))))
      (when (or (and linestyle (not (equalp linestyle "none"))) linewidth)
        (apply 'pymethod (axis-handle ax) "plot3D" x y z
               :c (or color "b")
               (append (when linestyle (list :linestyle linestyle))
                       (when linewidth (list :linewidth linewidth)))))
      (apply 'pymethod (axis-handle ax) "scatter" x y z :marker marker
             (append
              (list :c (or color "b"))
              (when facecolor (list :facecolor facecolor))
              (when markersize (list :s markersize))
              (when colormap (list :cmap colormap))
              (when markerfacecolor (list :markerfacecolor markerfacecolor))
              (when markeredgecolor (list :markeredgecolor markeredgecolor))
              (when displayname (list :label (make-trace-name displayname hide-in-legend)))))
      (draw-axis ax))))

(defun mpl/xlabel (string &key (ax (gca)) (draw t) fontsize fontweight color)
  "Text in $ $ will be interpreted as LaTex. Don't forget \\, for example
' 'Resistance ($\\Omega$)'"
  (assert ax nil "No current axis")
  (apply 'pymethod (axis-handle ax) "set_xlabel" string
         (append
          (when fontsize (list :fontsize fontsize))
          (when fontweight (list :fontweight fontweight))
          (when color (list :color color))))
  (when draw (draw-axis ax)))

(defun mpl/ylabel (string &key (ax (gca)) (draw t) fontsize fontweight color)
  "Text in $ $ will be interpreted as LaTex. Don't forget \\, for example
' 'Resistance ($\\Omega$)'"
  (assert ax nil "No current axis")
  (apply 'pymethod (axis-handle ax) "set_ylabel" string
         (append
          (when fontsize (list :fontsize fontsize))
          (when fontweight (list :fontweight fontweight))
          (when color (list :color color))))
  (when draw (draw-axis ax)))

(defun mpl/zlabel (string &key (ax (gca)) (draw t) fontsize fontweight color)
  "Text in $ $ will be interpreted as LaTex. Don't forget \\, for example
' 'Resistance ($\\Omega$)'"
  (assert ax nil "No current axis")
  (when (string= (pyslot-value (axis-handle ax) "name") "3d")
    (apply 'pymethod (axis-handle ax) "set_zlabel" string
           (append
            (when fontsize (list :fontsize fontsize))
            (when fontweight (list :fontweight fontweight))
            (when color (list :color color))))
    (when draw (draw-axis ax))))

(defun mpl/modify-title-text (string &key (action :append) (ax (gca)))
  "Appends string to title if specified with action :append or replaces it
 if :replace.  Keeps fontsize, fontweight, color.  To build a new title call
 mpl/title.  To change fonts try mpl/set-title-props."
  (let ((title (pyslot-value (axis-handle ax) "title")))
    (assert title)
    (pymethod title "set_text"
              (ecase action
                (:append (concatenate 'string (pymethod title "get_text")
                                      (format nil "~%~A" string)))
                (:replace string))))
    (draw-axis ax))

(defun mpl/title (string &key (ax (gca)) (draw t) fontsize fontweight color)
  "Text in $ $ will be interpreted as LaTex. Don't forget \\, like
 (title 'My happy e$\\chi$periment')"
  (assert ax nil "No current axis")
  (let ((title
          (apply 'pymethod (axis-handle ax) "set_title" string
                 (append
                  (when fontsize (list :fontsize fontsize))
                  (when fontweight (list :fontweight fontweight))
                  (when color (list :color color))))))
    (push (pycall "PyQt6_cl_matplotlib.enable_draggable_title" title) (figure-interactive-labels (axis-figure ax))))
  (when draw (draw-axis ax)))

(defun mpl/grid (&key (switch :on) (which :major) (ax (gca)) (draw t))
  (assert ax nil "No current axis")
  (py4cl2:pymethod (axis-handle ax) "grid"
                   (if (member switch '(:on :minor)) t nil)
                   :which (if (eq which :minor) "minor" "major"))
  (when draw (draw-axis ax)))

(defun mpl/xlim (x0 x1 &key (ax (gca)) (draw t))
  (assert ax nil "No current axis")
  (pymethod (axis-handle ax) "set_xlim" (coerce x0 'double-float) (coerce x1 'double-float))
  (when draw (draw-axis ax)))

(defun mpl/ylim (y0 y1 &key (ax (gca)) (draw t))
  (assert ax nil "No current axis")
  (pymethod (axis-handle ax) "set_ylim" (coerce y0 'double-float) (coerce y1 'double-float))
  (when draw (draw-axis ax)))

(defun mpl/zlim (z0 z1 &key (ax (gca)) (draw t))
  (assert ax nil "No current axis")
  (pymethod (axis-handle ax) "set_zlim" (coerce z0 'double-float) (coerce z1 'double-float))
  (when draw (draw-axis ax)))

(defun sampled-colormap-to-cmap (sampled-colormap)
  (pycall "matplotlib.colors.ListedColormap" sampled-colormap))

(defun maybe-sampled-colormap-to-cmap (maybe-sampled-colormap)
  "If MAYBE-SAMPLED-COLORMAP is an array of RGB / RGBA colors, make a python
 object representing it.  If it's a string representation of a colormap
 like viridis, leave it alone."
  (if (stringp maybe-sampled-colormap)
      maybe-sampled-colormap
      (sampled-colormap-to-cmap maybe-sampled-colormap)))

(defun mpl/surf-data (x y z &key cmap)
  "x, y, and z must be NxM arrays"
  (pyexec "import matplotlib")
  (pyexec "from mpl_toolkits.mplot3d import Axes3D")
  (when (and cmap (not (stringp cmap)) (arrayp cmap))
    (setf cmap (sampled-colormap-to-cmap cmap)))
  (unless cmap
    (setf cmap (pyeval "matplotlib.cm.coolwarm")))
  (let* ((ax (ensure-3d-axis (gca))))
    (maybe-remove-axis-colorbar ax)
    (let* ((surf (pymethod (axis-handle ax) "plot_surface" x y z
                           :cmap cmap :linewidth 0 :antialiased nil
                           :axlim_clip t))
           (cb (pymethod (figure-handle (axis-figure ax)) "colorbar" surf :shrink 0.5 :aspect 5)))
      (setf (axis-colorbar ax) cb))
    (draw-axis ax)
    ax))

(defun tri-surf (x y z &key cmap facealpha (edgecolor "None")
                         mesh-only facecolor linewidth
                         show-colorbar)
  "When mesh-only, cmap should be "
  (pyexec "import matplotlib")
  (pyexec "from mpl_toolkits.mplot3d import Axes3D")
  (let* ((ax (ensure-3d-axis (gca))))
    (maybe-remove-axis-colorbar ax)
    (let ((plt (apply 'pymethod (axis-handle ax) "plot_trisurf" x y z
                      :axlim_clip t
                      (append
                       (when cmap (list :cmap (sampled-colormap-to-cmap cmap)))
                       (when facealpha (list :alpha facealpha))
                       (when edgecolor (list :edgecolor edgecolor))
                       (when mesh-only (list :color '(0 0 0 0)))
                       (when facecolor (list :color facecolor))
                       (when linewidth (list :linewidth linewidth))))))
      (when show-colorbar
        (let ((cb (pymethod (figure-handle (axis-figure ax))
                            "colorbar" plt
                            :ax (axis-handle ax) :shrink 0.5 :aspect 10)))
          (setf (axis-colorbar ax) cb))))
    (draw-axis ax)))

(defun mpl/trisurf* (triangles x y z &key cmap facealpha (edgecolor "None")
                         mesh-only facecolor linewidth
                         show-colorbar)
  "triangles should be indices into the x y z arrays... we subtract one
 because they are assumed generated matlab style with 1 indexing, boo."
  (pyexec "import matplotlib")
  (pyexec "from mpl_toolkits.mplot3d import Axes3D")
  (let* ((ax (ensure-3d-axis (gca))))
    (maybe-remove-axis-colorbar ax)
    (let ((better-triangles (make-array (array-dimensions triangles)
                                        :element-type 'fixnum)))
      (dotimes (i (array-dimension triangles 0))
        (dotimes (j (array-dimension triangles 1))
          (setf (aref better-triangles i j) (aref triangles i j))))
      (setf triangles better-triangles))
    (let ((plt (apply 'pymethod (axis-handle ax) "plot_trisurf"
                      x
                      y
                      z
                      :triangles triangles
                      :axlim_clip t
                      (append
                       (when cmap (list :cmap (sampled-colormap-to-cmap cmap)))
                       (when facealpha (list :alpha facealpha))
                       (when edgecolor (list :edgecolor edgecolor))
                       (when mesh-only (list :color '(0 0 0 0)))
                       (when facecolor (list :color facecolor))
                       (when linewidth (list :linewidth linewidth))))))
      (when show-colorbar
        (let ((cb (pymethod (figure-handle (axis-figure ax))
                            "colorbar" plt
                            :ax (axis-handle ax) :shrink 0.5 :aspect 10)))
          (setf (axis-colorbar ax) cb))))
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
    (filename &key (width-pixels 2000) (height-pixels 1440) (dpi 200) eps?)
  "FILENAME is a full, absolute path to the destination file."
  ;; I think if name is specified it uses it, otherwise it
  ;; puts name-prefix figure-window-title name-suffix with some fiddling,
  ;; and tidying see build-figname
  (let* ((fig *current-figure*)
         (full-filename (if (or (search ".png" filename)
                                (search ".pdf" filename)
                                (search ".eps" filename))
                            filename
                            (format nil "~a.~a" filename
                                    (if eps? "eps" "png")))))
    (assert fig)
    (let* ((old-size (pymethod (figure-handle fig) "get_size_inches"))
           (new-width-inches (round width-pixels dpi))
           (new-height-inches (round height-pixels dpi))
           (is-same-size (and (= new-width-inches (elt old-size 0)) (= new-height-inches (elt old-size 1)))))
      (unless is-same-size
        (pymethod (figure-handle fig) "set_size_inches" new-width-inches new-height-inches))
      (pymethod (figure-handle fig) "savefig" full-filename :dpi dpi)
      (unless is-same-size
        (pymethod (figure-handle fig) "set_size_inches" old-size))
      full-filename)))

(defun clear-figure (&optional (figure *current-figure*) (relabel t))
  (declare (type (or null figure) figure))
  (when figure
    (pymethod (figure-handle figure) "clf")
    (setf (figure-current-axis figure) nil)
    (setf (figure-axes figure) nil)
    (setf (figure-tiled-layout-request figure) '(1 1))
    (setf (figure-interactive-labels figure) nil)
    ;; Rename / renumber the figure, if it was a logged plot we won't then overwrite it
    (when relabel
      (let ((figure (copy-figure figure))
            (new-fig-id (get-unique-figure-number)))
        (setf (figure-window-title figure) (get-window-title new-fig-id))
        (remhash (figure-number figure) *active-figures*)
        (setf (figure-number figure) new-fig-id)
        (setf (gethash (figure-number figure) *active-figures*) figure)
        (mpl/set-window-title (figure-window-title figure) :figure figure)
        (mpl/set-figure-active figure)
        (draw-figure figure)
        (setf *current-figure* figure)))))

(defun mpl/find-scalar-mappable (&optional (fig *current-figure*))
  (map nil (lambda (axes)
             (map nil (lambda (child)
                        (when (pycall "isinstance" child '|matplotlib.cm.ScalarMappable|)
                          (return-from mpl/find-scalar-mappable child)))
                  (pymethod axes "get_children")))
       (pymethod (figure-handle fig) "get_axes")))

(defun mpl/apply-colormap (cmap &key min max (clip t))
  "Apply a new colormap to an existing colormap image.  min/max and clip determine
 how the colormap is applied."
  (let* ((ax (gca))
         (scalable (mpl/find-scalar-mappable)))
    (when (and min max)
      (py4cl2:pymethod scalable "set_norm"
                       (py4cl2:pycall "matplotlib.colors.Normalize"
                                      :vmin min :vmax max
                                      :clip clip)))
    (py4cl2:pymethod scalable "set_cmap"
                     (cl-matplotlib:sampled-colormap-to-cmap cmap))
    (draw-axis ax)))

(defun maybe-remove-axis-colorbar (axis)
  (when (axis-colorbar axis)
    (py4cl2:pymethod (axis-colorbar axis) "remove")
    (setf (axis-colorbar axis) nil)))

(defun mpl/add-colorbar (&key (axis (gca))
                              (figure (axis-figure axis))
                       (cmap "viridis") (clip t) ticks ticklabels label interpreter
                       min max
                       apply)
  "This will add a colorbar image to the plot.  IF you want to also apply the colormap
 to the figure (replacing any one that was used during the plot call) then specify :apply t."
  (declare (ignorable interpreter))
  (when ticklabels (assert (= (length ticks) (length ticklabels))))
  ;; Need to delete an old colorbar if it is there
  (maybe-remove-axis-colorbar axis)
  (let ((norm (apply 'pycall "matplotlib.colors.Normalize"
                     (append
                      (when min (list :vmin min))
                      (when max (list :vmax max))
                      (when clip (list :clip clip))))))
    (prog1
        (let ((colorbar
                (apply 'py4cl2:pymethod
                       (figure-handle figure) "colorbar"
                       (py4cl2:pycall "matplotlib.cm.ScalarMappable"
                                      :cmap (maybe-sampled-colormap-to-cmap cmap)
                                      :norm norm)
                       :ax (axis-handle axis)
                       (when label (list :label label)))))
          (setf (axis-colorbar axis) colorbar)
          (when (or ticks ticklabels)
            (py4cl2:pymethod colorbar "set_ticks" ticks :labels (or ticklabels ticks))))
      (when apply
        (mpl/apply-colormap cmap :min min :max max :clip clip))
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
                                   (orientation "vertical")
                                   (horizontal-alignment "left")
                                   (vertical-alignment "center")
                                   (label-y-fraction 0.5))
  "orientation may be 'vertical' or 'horizontal'.  horizontal-alignment may be
 'left' 'center' 'right' , vertical-alignment may be 'center' 'top' 'bottom'"
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
                     :horizontalalignment (string-downcase horizontal-alignment)
                     :verticalalignment (string-downcase vertical-alignment)))
  (draw-axis (gca)))

(defun mpl/draw-horizontal-line (y &key (ax (gca)) (line-colour "k") (linewidth 1)
                                     label (linestyle "-") displayname
                                     (omit-from-legend (not displayname))
                                     ;; The rest of these have to do with labels
                                     (orientation "horizontal")
                                     (horizontal-alignment "center")
                                     (vertical-alignment "center")
                                     (label-x-fraction 0.5))
  "orientation may be 'vertical' or 'horizontal'.  horizontal-alignment may be
 'left' 'center' 'right' , vertical-alignment may be 'center' 'top' 'bottom'"
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
                     :horizontalalignment (string-downcase horizontal-alignment)
                     :verticalalignment (string-downcase vertical-alignment)))
  (draw-axis (gca)))

(defun mpl/ginput (n)
  "Returns an array of x y pairs:
    [[x0 y0] [x1 y1] ... ]"
  (declare (type (integer 0) n))
  (let* ((figure *current-figure*))
    (assert figure)
    (let* ((dw (figure-dockwidget figure)))
      (setf (pyslot-value dw "waiting_on_ginput") n)
      (loop until (= (pyslot-value dw "waiting_on_ginput") 0)
            do (sleep 0.1))
      (let ((result (pymethod dw "get_ginputs")))
        ;; Format is a vector of (x y) pairs.  Users expect a list of xs and ys
        (loop for pair across result
              collect (elt pair 0) into xs
              collect (elt pair 1) into ys
              finally (return (list xs ys)))))))

(defun axis-scale-method (axis)
  (ecase axis (:x "set_xscale") (:y "set_yscale") (:z "set_zscale")))

(defun mpl/set-logscale (axis &key (ax (gca)) (base 10.0) (nonpositive "clip") (subs "auto"))
  "NONPOSITIVE may be 'clip' or 'mask'.  'mask' means lines will not be draw to
 connect negative values off the edge of the plot.  'clip' will draw lines to the edge of the
 plot. SUBS is 'auto' or a sequence of integers to define where the minor ticks should live.  For
 example (2 3 4 5 6 7 8) will define 8 logarithmically space minor ticks between each major tic.
 AXIS must be :x, :y, or :z."
  (pymethod (axis-handle ax) (axis-scale-method axis) "log"
            :base base :nonpositive nonpositive :subs subs)
  (draw-axis ax))

(defun mpl/set-linearscale (axis &key (ax (gca)))
  (pymethod (axis-handle ax) (axis-scale-method axis) "linear")
  (draw-axis ax))
  
(defun mpl/set-fig-background-color (color &key (fig *current-figure*))
  (assert *current-figure*)
  (pymethod (figure-handle fig) "set_facecolor" color))

(defun mpl/set-axes-background-color (color &key (ax (gca)))
  (pymethod (axis-handle ax) "set_facecolor" color))

(defun mpl/draw-text (x y text
                      &key horizontal-alignment (fontsize 8) (color "k") vertical-alignment
                        interpreter rotation background-color normalized-x normalized-y
                        fontweight (draw-axis t) (ax (gca)))
  (let* ((axh (axis-handle ax)))
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
    (when draw-axis (draw-axis ax))))

(defun mpl/hide-legend (&key (ax (gca)))
  (let ((l (py4cl2:pymethod (axis-handle ax) "get_legend")))
    (when (and l (not (equalp l "None")))
      (py4cl2:pymethod l "set_visible" nil)
      (draw-axis ax))))


(defun mpl/legend-exists? (&key (ax (gca)))
  "Returns the legend if it exist, otherwise NIL"
  (let ((l (py4cl2:pymethod (axis-handle ax) "get_legend")))
    (if (and l (not (equalp l "None")))
        l
        nil)))

(defun mpl/legend-visible? (&key (ax (gca)))
  (let ((l (mpl/legend-exists? :ax ax)))
    (assert l nil "LEGEND has not been created")
    (pymethod l "get_visible")))

(defun mpl/show-legend (&key (ax (gca)))
  "Returns T if successfully (there was a pre-existing legend) or NIL if not"
  (let ((l (py4cl2:pymethod (axis-handle ax) "get_legend")))
    (if (and l (not (equalp l "None")))
        (progn (py4cl2:pymethod l "set_visible" t)
               (draw-axis ax)
               t)
        nil)))

(defun mpl/relabel-data-series-with-labels (data-series-labels)
  "If someone calls (legend '(label-a label-b)) we actually go and label the
 data-series with those labels."
  (let* ((ax (gca))
         (children (pymethod (axis-handle ax) "get_children")))
    (loop while data-series-labels
          for child across children
          for is-line = (pycall "isinstance" child '|matplotlib.lines.Line2D|)
          when is-line
            do (pymethod child "set_label" (pop data-series-labels)))
    (assert (null data-series-labels))))

(defun mpl/legend (&key (ax (gca)) title location fontsize facecolor framealpha
                     legend-entries ncol labelcolor bbox-to-anchor
                     fontweight title-fontsize)
  "location is 'upper left' best etc."
  (pyexec "from PyQt6_cl_matplotlib import enable_legend_interactivity")
  (when legend-entries
    (mpl/relabel-data-series-with-labels legend-entries))
  (let ((leg (apply 'py4cl2:pymethod (axis-handle ax)
                    "legend"
                    (append
                     (when title (list :title title))
                     (when title-fontsize (list :title_fontsize title-fontsize))
                     (when ncol (list :ncol ncol))
                     (when location (list :loc location))
                     (when fontsize (list :fontsize fontsize))
                     (when facecolor (list :facecolor facecolor))
                     (when framealpha (list :framealpha framealpha))
                     (when labelcolor (list :labelcolor labelcolor))
                     (when fontweight (list :fontweight fontweight))
                     (when bbox-to-anchor (list :bbox_to_anchor bbox-to-anchor))))))
    (pymethod leg "set_draggable" t)
    ;; We need to keep the interactive legend object alive, so
    ;; we stuff it into the axes object
    (push (pycall "enable_legend_interactivity" (axis-handle ax) leg)
          (axis-interactive-legends ax)))
  (draw-axis ax))

(defun mpl/set-legend-string-on-last-data-series (legend-string &key (show-legend t))
  (let* ((ax (gca))
         (children (pymethod (axis-handle ax) "get_children")))
    (loop for child across (reverse children)
          for is-line = (pycall "isinstance" child '|matplotlib.lines.Line2D|)
          until is-line
          finally
             (assert is-line nil "Could not find data series to label")
             (pymethod child "set_label" legend-string))
    (when show-legend (mpl/legend))))

(defun mpl/set-legend-title (title &key (ax (gca)) fontsize fontweight color)
  (let ((l (py4cl2:pymethod (axis-handle ax) "get_legend")))
    (unless l (setf l (mpl/legend :title title)))
    (pymethod l "set_title" title)
    (let ((title (pymethod l "get_title")))
      (when fontsize (pymethod title "set_fontsize" fontsize))
      (when fontweight (pymethod title "set_fontweight" fontweight))
      (when color (pymethod title "set_color" color)))
    (draw-axis ax)))

(defun mpl/view (azimuth elevation &optional (roll 0))
  (let ((ax (gca)))
    (pymethod (axis-handle ax) "view_init"
              :elev elevation :azim azimuth :roll roll)
    (draw-axis ax)))

(defun mpl/set-axis-tick-props
    (axis &key (offset-text t) (axis-tick-labels t) fontsize fontweight color
            width length pad)
  (declare (type (member :x :y :z) axis))
  (let ((ax (gca)))
    (when (and (eql axis :z) (not (is-3d-axis ax)))
      (return-from mpl/set-axis-tick-props))
    (when (or axis-tick-labels width length pad)
      (apply 'pymethod (axis-handle ax) "tick_params"
             :axis (ecase axis
                     (:x "x")
                     (:y "y")
                     (:z "z"))
             (append
              (when fontsize (list :labelsize fontsize))
              (when color (list :labelcolor color))
              (when width (list :width width))
              (when length (list :length length))
              (when pad (list :pad pad)))))
    (when (and offset-text (or fontsize fontweight))
      (let* ((axis-name
               (ecase axis
                 (:x "xaxis")
                 (:y "yaxis")
                 (:z "zaxis")))
             (axis-obj (pyslot-value (axis-handle ax) axis-name)))
        (when axis-obj
          (let ((offset-text (pymethod axis-obj "get_offset_text")))
            (when offset-text
              (when color (pymethod offset-text "set_color" color))
              (when fontsize (pymethod offset-text "set_fontsize" fontsize))
              (when fontweight (pymethod offset-text "set_fontweight" fontweight)))))))
    (when (and axis-tick-labels fontweight)
      (map nil (lambda (tick-label)
                 (pymethod tick-label "set_fontweight" fontweight))
                 (pymethod (axis-handle ax) (ecase axis
                                              (:x "get_xticklabels")
                                              (:y "get_yticklabels")
                                              (:z "get_zticklabels")))))
    (draw-axis ax)))

(defun mpl/set-axis-label-props (indicator &key fontsize fontweight color)
  (declare (type (member :xlabel :ylabel :zlabel indicator)))
  (let* ((ax (gca)))
    (when (and (eql indicator :zlabel) (not (is-3d-axis ax)))
      (return-from mpl/set-axis-label-props))
    (let ((axis (pyslot-value (axis-handle ax) (ecase indicator
                                                 (:xlabel "xaxis")
                                                 (:ylabel "yaxis")
                                                 (:zlabel "zaxis")))))
      (when axis
        (let ((label (pyslot-value axis "label")))
          (when label
            (when fontsize (pymethod label "set_fontsize" fontsize))
            (when fontweight (pymethod label "set_fontweight" fontweight))
            (when color (pymethod label "set_color" color))))))
    (draw-axis ax)))

(defun mpl/set-title-props (&key fontsize fontweight color)
  (let* ((ax (gca))
         (title (pyslot-value (axis-handle ax) "title")))
    (when title
      (when fontsize (pymethod title "set_size" fontsize))
      (when fontweight (pymethod title "set_fontweight" fontweight))
      (when color (pymethod title "set_color" color))
      (draw-axis ax))))

(defun mpl/set-legend-props (&key title (texts t) fontsize fontweight color)
  "Set all entries in the legend to fontsize and/or fontweight"
  (let* ((ax (gca))
         (legend (pymethod (axis-handle ax) "get_legend")))
    (when (and legend (not (stringp legend))) ;; "None"
      (labels ((update (place)
                 (when (and place (not (stringp place))) ;; "None"
                   (when fontsize (pymethod place "set_fontsize" fontsize))
                   (when fontweight (pymethod place "set_fontweight" fontweight))
                   (when color (pymethod place "set_color" color)))))
        (when title (update (pymethod legend "get_title")))
        (when texts
          (let ((texts (pymethod legend "get_texts")))
            (when (and texts (not (stringp texts))) ;; "None"
              (map nil #'update (pycall "list" texts))))))
      (draw-axis ax))))

(defun mpl/map-axes (thunk &key (figure *current-figure*))
  (dolist (axes (figure-axes figure))
    (setf (figure-current-axis figure) axes)
    (funcall thunk)))

(defun mpl/error-messages ()
  "Sometimes matplotlib will error while trying to draw"
  (prog1
      (format nil "~A" py4cl2::*spurious-info*)
    (setf (fill-pointer py4cl2::*spurious-info*) 0)))

(defun mpl/get-grid-size (&optional (figure *current-figure*))
  "Returns [nrows ncols}"
  (when figure
    (if (listp (figure-tiled-layout-request figure))
        (figure-tiled-layout-request figure)
        (loop for obj across (pyslot-value (figure-handle figure) "axes")
              for grid-spec = (pymethod obj "get_subplotspec")
              when (not (equal grid-spec "None"))
                return (coerce (subseq (pymethod grid-spec "get_geometry") 0 2) 'list)))))
  
(defun mpl/next-subplot-grid (&optional (figure *current-figure*))
  "Returns the next subplot index (zero-based), aware of spanning subplots"
  (when (null (figure-axes figure))
    (return-from mpl/next-subplot-grid 0))
  (let ((tiledlayout (figure-tiled-layout-request figure)))
    (if (equal tiledlayout "flow")
        (length (figure-axes figure))
        (loop for axis in (figure-axes figure)
              when (equal tiledlayout (subseq (axis-subplot axis) 0 2))
                maximizing
                (if (numberp (third (axis-subplot axis)))
                    (third (axis-subplot axis))
                    (apply #'max (third (axis-subplot axis))))))))

(defun mpl/reflow-subplots (nrows ncols &optional (figure *current-figure*))
  (when figure
    (let ((gs (pycall "matplotlib.gridspec.GridSpec" nrows ncols :figure (figure-handle figure))))
      (loop for obj across (pyslot-value (figure-handle figure) "axes")
            with count = 0
            when (not (equal (pymethod obj "get_subplotspec") "None"))
              do
                 (pymethod obj "set_subplotspec" (pycall "matplotlib.gridspec.SubplotSpec" gs count))
                 (incf count))
      (pymethod (figure-handle figure) "subplots_adjust")
    (draw-figure figure))))

(defun mpl/link-axis (axis-to-link list-subplot-to-link &key (fig *current-figure*))
  (assert (member axis-to-link '(:x :y)))
  (let* ((axis (format nil "share~(~A~)" axis-to-link))
         (subplot-axis (remove-if-not
                        (lambda (ax)
                          (destructuring-bind (nrows ncols grid-desc) (axis-subplot ax)
                            (declare (ignore nrows ncols))
                            (find grid-desc list-subplot-to-link :test #'equal)))
                        (figure-axes fig))))
    (assert (= (length subplot-axis)
               (length list-subplot-to-link))
            nil (format nil "did not find all axes, options are ~{~A~^,~^ ~}"
                        (mapcar (lambda (ax) (third (axis-subplot ax)))
                                (figure-axes fig))))
    (destructuring-bind (first-axis . other-axes) subplot-axis
      (map nil (lambda (ax)
                 (pymethod (axis-handle first-axis) axis (axis-handle ax)))
           other-axes)
      (pymethod (axis-handle first-axis) "autoscale")
      (draw-axis first-axis))))

(defun mpl/plot-universal-time-series (data &key color marker linewidth linestyle displayname)
  "data is a list of universal-time (seconds) and numbers."
  (let ((x (map '(simple-array (unsigned-byte 64) (*)) (lambda (x) (- ;; universal to unix time
                                                                    (round (* (first x) 1000))
                                                                    2208988800000))
                data))
        (y (map '(simple-array double-float (*)) (lambda (x) (coerce (second x) 'double-float)) data))
        (ax (gca)))
    (unless color
      (setf color (find-next-color ax)))
    ;; We cannot send numpy datetime64s back and forth because we lose the
    ;; sense of them, so we do this kludge
    (pyexec "blarg = numpy.array(" x ",dtype='datetime64[ms]')")
    (apply 'pymethod (axis-handle ax) "plot" 'blarg y
           :color color
           (append
            (when linestyle (list :linestyle linestyle))
            (when marker (list :marker marker))
            (when displayname (list :label displayname))
            (when linewidth (list :linewidth linewidth))))
    (draw-axis ax)
    ax))

(defun mpl/bar3d (x y heights dx dy &key (color/s "b"))
  (let ((ax (ensure-3d-axis (gca))))
    (pymethod (axis-handle ax)
              "bar3d" x y
              (make-array (length x) :initial-element 0 :element-type '(unsigned-byte 8))
              dx dy heights :color color/s)
    (draw-axis ax)))
           
(defun mpl/set-axis-tick-label
  (axis positions labels &key (angle 0) fontsize)
  (assert (= (length positions) (length labels)))
  (let ((ax (gca))
        (method-name (ecase axis
                       (:x "set_xticks")
                       (:y "set_yticks")
                       (:z "set_zticks"))))
    (apply 'pymethod (axis-handle ax) method-name positions
           :labels labels :rotation angle
           (when fontsize (list :fontsize fontsize)))
    (draw-axis ax)))

(defun to-sadf (seq &optional (key #'identity))
  (if (typep seq '(simple-array double-float (*)))
      seq
      (map '(simple-array double-float (*))
           (lambda (d) (coerce (funcall key d) 'double-float)) seq)))

(defun meshgrid (x y)
  "Upgrade x and y to two dimension arrays of (length x) x (length y).  Returns
 (values xmesh ymesh)."
  (let* ((x (to-sadf x))
         (y (to-sadf y))
         (dims (list (length x) (length y)))
         (xgrid (make-array dims :element-type 'double-float))
         (ygrid (make-array dims :element-type 'double-float)))
    (loop for x-val across x
          for x-idx from 0
          do (loop for y-idx below (length y)
                   do (setf (aref xgrid x-idx y-idx) x-val)))
    (loop for y-val across x
          for y-idx from 0
          do (loop for x-idx below (length x)
                   do (setf (aref ygrid x-idx y-idx) y-val)))
    (values xgrid ygrid)))

(defun mpl/contour
    (x y z &key linewidth levels show-labels cmap color linestyle (ax (gca)) filled)
  "x y z may be 1d sequences, in which case we assume they are not rectilinear data,
 or x and y are 1d and z is 2d, or x y and z are all 2d arrays.
 COLOR, LINEWIDTH, LEVEL, and LINESTYLE may all be scalars or lists"
  (when (and cmap (not (stringp cmap)))
    (setf cmap (sampled-colormap-to-cmap cmap)))
  (unless (or color cmap)
    (setf cmap "viridis"))
  (when (and color (not cmap))
    (setf cmap (map 'list #'maybe-matlab-color-to-rgb color))
    (setf color nil))
  (let* ((rectilinear (and (arrayp z) (= (array-rank z) 2)))
         (func-name (if rectilinear
                        (if filled "contourf" "contour")
                        (if filled "tricontourf" "tricontour"))))
    (if (and rectilinear
               (not (and (arrayp x) (arrayp y)
                         (= (array-rank x) 2) (= (array-rank y) 2))))
        (multiple-value-bind (xgrid ygrid)
            (meshgrid x y)
          (setf x xgrid y ygrid))
        (setf x (to-sadf x) y (to-sadf y) z (to-sadf z)))
    (let ((cs
            (apply 'pymethod (axis-handle ax) func-name
                   x y z
                   (append
                    (when linestyle (list :linestyle linestyle))
                    (when levels (list :levels levels))
                    (when linewidth (list :linewidths linewidth))
                    (when cmap (list :cmap cmap))
                    (when color (list :colors color))))))
      (when show-labels
        (if filled
            (when cmap
              (mpl/add-colorbar :cmap cmap))
            (pymethod (axis-handle ax) "clabel" cs (pyslot-value cs "levels"))))
      (draw-axis ax)
      cs)))

(defun mpl/draw-arrow (initial-pt final-pt &key arrow-type string color linestyle textcolor)
  "arrow-type: - <- -> <-> <|- -|> <|-|> ]- -[ ]-[ |-| ]-> <-[ simple fancy wedge"
  (let ((ax (gca)))
    (pymethod (axis-handle ax) "annotate" (or string "")
              :xy initial-pt
              :xycoords "data"
              :xytext final-pt
              :textcoords "data"
              :color (or textcolor "k")
              :arrowprops
              (pycall "dict" 
                      :arrowstyle
                      (if (stringp arrow-type)
                          arrow-type
                          (case arrow-type
                            (:arrow "->")
                            (:doublearrow "<->")
                            (otherwise "->")))
                      :facecolor (or color "k")
                      :linestyle (or linestyle "-")))
    (draw-axis ax)))

(defun mpl/draw-polygon (vertices &key (closed t) facecolor edgecolor linewidth alpha displayname)
  "Polygons go behind data points so facecolor will not obscure them"
  (let ((polygon
          (pycall "matplotlib.patches.Polygon"
                  vertices :closed closed :facecolor (or facecolor "w")
                           :edgecolor (or edgecolor "k") :linewidth (or linewidth 1)
                           :alpha (or alpha 1.0) :label (or displayname ""))))
    (let ((ax (gca)))
      (pymethod (axis-handle ax) "add_patch" polygon)
      (draw-axis ax))))

(defun mpl/set-line-prop (line &key linewidth color marker marker-size marker-facecolor marker-edgecolor alpha displayname visible-setting hide-in-legend)
  (declare (type (member nil :visible :hidden) visible-setting))
  (when linewidth (pymethod line "set_linewidth" linewidth))
  (when color (pymethod line "set_color" color))
  (when marker (pymethod line "set_marker" marker))
  (when marker-size (pymethod line "set_markersize" marker-size))
  (when marker-edgecolor (pymethod line "set_markeredgecolor" marker-edgecolor))
  (when marker-facecolor (pymethod line "set_markerfacecolor" marker-facecolor))
  (when alpha (pymethod line "set_alpha" alpha))
  (when displayname (pymethod line "set_label" displayname))
  (when visible-setting (pymethod line "set_visible"
                                  (case visible-setting
                                    (:visible t)
                                    (:hidden nil))))
  (when hide-in-legend (pymethod line "set_label" ""))
  )

(defun mpl/set-all-line-props (&rest rest &key linewidth color marker  marker-size marker-facecolor marker-edgecolor alpha displayname visible-setting hide-in-legend)
  (declare (ignore linewidth color marker alpha displayname visible-setting
                   marker-size marker-facecolor marker-edgecolor hide-in-legend))
  (let* ((ax (gca))
         (lines (pycall "list" (pymethod (axis-handle ax) "get_lines"))))
    (map nil (lambda (line)
               (apply 'mpl/set-line-prop line rest))
         lines)
    (draw-axis ax)))

(defun mpl/set-axis-tick-location (axis &key (location "top") (set-label t))
  "After the fact transfer your xaxis ticks and tick labels to the top.
 LOCATION is one of 'top' or 'bottom' when axis is :x or 'left' and 'right'
 for when axis is :y."
  (let* ((ax (gca))
         (axis (pyslot-value (axis-handle ax) (ecase axis (:x "xaxis") (:y "yaxis")))))
    (setf location (string-downcase (if (symbolp location) (format nil "~a" location) location)))
    (pymethod axis (format nil "tick_~a" location))
    (when set-label (pymethod axis "set_label_position" location))
    (draw-axis ax)))

(defun get-axis (ax axis-indicator)
  (pymethod (axis-handle ax)
            (ecase axis-indicator
              (:x "get_xaxis")
              (:y "get_yaxis")
              (:z "get_zaxis"))))

(defun mpl/set-axis-props (&key (ax (gca)) (box nil box-provided-p)
                             linewidth color axis (visible nil visible-provided-p))
  "If BOX is T will draw a box frame around the plot.  LINEWIDTH if provided
 sets the linewidth of that box.  If COLOR then the color of that box.  If
 VISIBLE is provided and NIL then the box, axis ticks, and axis values will
 not be drawn."
  (when box-provided-p
    (pymethod (axis-handle ax) "set_frame_on" box))
  (when visible-provided-p
    (map nil (lambda (axis-indicator)
               (pymethod (get-axis ax axis-indicator)
                         "set_visible"
                         visible))
         (if (listp axis) axis (list axis))))
  (when (or linewidth color)
    (map nil (lambda (spine)
               (when linewidth (pymethod spine "set_linewidth" linewidth))
               (when color (pymethod spine "set_color" color)))
         (pycall "list"
                 (pymethod (pyslot-value (axis-handle ax) "spines") "values"))))
  (draw-axis ax))

(defun mpl/set-error-bar-props (&key (ax (gca)) linewidth (capwidth linewidth)
                                  (caplength (when capwidth (* 4 capwidth))))
  "Modiifes the error bar LINEWIDTH.  The Caps "
  (let ((containers (pycall "list"
                            (pyslot-value (axis-handle ax) "containers"))))
    (map nil (lambda (container)
               (when (or (pycall "hasattr" container "has_xerr")
                         (pycall "hasattr" container "has_yerr"))
                 (destructuring-bind (plotline caplines errorbars)
                     (coerce (pycall "list" container) 'list)
                   (declare (ignore plotline))
                   (map nil (lambda (c)
                              (when caplength (pymethod c "set_markersize" caplength))
                              (when capwidth (pymethod c "set_markeredgewidth" capwidth)))
                        (pycall "list" caplines))
                   (map nil (lambda (c)
                              (when linewidth (pymethod c "set_linewidth" linewidth)))
                        (pycall "list" errorbars)))))
         containers)
    (draw-axis ax)))

(defun mpl/plot-image (image-data &key (x0 0) (dx 1) (y0 0) (dy 1)
                              colormap xdim ydim use-alpha alpha-stencil
                                    colorbar-label colorbar-min colorbar-max clip)
    (declare (optimize (debug 3)) (ignore colorbar-label))
  "Make color image plot for 2-dimensional image-plot. IMAGE-DATA
 should be a 2-d array.  By default, pixel locations are labelled 0
 through N-1 (where N is the length in each dimension).  X0/DX and
 Y0/DY can be provided to modify the X and Y labelling.  Returns figure
 ID and colorbar ID as multiple values.  If you want to exclude points from
 image-data, put in NaNs"
  (assert (= (array-rank image-data) 2))
  (let* ((dimensions (if (and xdim ydim) (list ydim xdim) (array-dimensions image-data)))
         (x-range (list x0 (+ x0 (* (1- (second dimensions)) dx))))
         (y-range (list y0 (+ y0 (* (1- (first dimensions)) dy))))
         (min sb-ext:double-float-positive-infinity)
         (max sb-ext:double-float-negative-infinity))
    (loop for i below (array-dimension image-data 0)
          do (loop for j below (array-dimension image-data 1)
                   for d = (aref image-data i j)
                   do
                      (when (not (float-features:float-nan-p d))
                        (when (> d max) (setf max d))
                        (when (< d min) (setf min d)))))
    (unless colormap (setf colormap "viridis"))
    (let* ((ax (gca))
           (axh (axis-handle ax))
           (cmap (maybe-sampled-colormap-to-cmap colormap)))
      ;; should create the clipped colorbar mapping here...
      (py4cl2:pymethod axh "imshow" image-data
                       :cmap cmap :alpha (or (and use-alpha alpha-stencil) "None")
                       :extent (append x-range y-range)
                       :aspect "auto" :origin "lower") ;; flip so matches matlab
      (let ((real-min (or colorbar-min min))
            (real-max (or colorbar-max max)))
        (mpl/add-colorbar :min real-min :max real-max :cmap colormap :clip clip))
      (draw-axis ax))))

(defun mpl/caxis (min max &key (clip t) (ax (gca)))
  "Change the already applied colormap to apply to values between min and max instead of
 what it was originally created with)"
    (let* ((scalable (mpl/find-scalar-mappable)))
      (py4cl2:pymethod scalable "set_norm"
                       (py4cl2:pycall "matplotlib.colors.Normalize"
                                      :vmin min :vmax max :clip clip))
      (draw-axis ax)))

(defun mpl/axis-square (&key (ax (gca)))
  (py4cl2:pymethod (axis-handle ax) "set_box_aspect" 1)
  (draw-axis ax))

(defun mpl/axis-equal (&key (ax (gca)))
  (py4cl2:pymethod (axis-handle ax) "set_aspect" "equal")
  (draw-axis ax))

(defun mpl/plot-bar (data &key facecolor (barwidth 0.9) displayname facealpha edgecolor hide-in-legend)
  "barwidth is normalized so that 1.0 means the closest two bars do not overlap."
  (let* ((xvals (remove-duplicates (sort (map 'list #'first data) #'<)))
         (min-spacing nil))
    (loop for a in xvals
          for b in (cdr xvals)
          do (when (or (not min-spacing) (< (- b a) min-spacing))
               (setf min-spacing (- b a))))
    (let ((ax (gca)))
      (apply 'py4cl2:pymethod (axis-handle ax)
             "bar"
             (map 'list #'first data) ;; can be anythings
             (map '(simple-array double-float (*))
                  (lambda (x) (coerce (second x) 'double-float))
                  data)
             :width (if barwidth
                        (* barwidth min-spacing 1.0)
                        (* 0.9d0 (/ (- (car (last xvals)) (first xvals)) (length data))))
             (append
              (when edgecolor (list :edgecolor edgecolor))
              (when facecolor (list :color facecolor))
              (when facealpha (list :alpha facealpha))
              (when displayname (list :label (make-trace-name displayname hide-in-legend)))))
      (draw-axis ax))))

(defun mpl/suptitle (suptitle &key fontsize)
  "Add a title to the top of a bunch of subplots.  If you pass a list, new-lines
 will be added between strings in the list."
    (let* ((fig (mpl/gcf))
           (obj (py4cl2:pymethod (figure-handle fig) "suptitle"
                                 (if (listp suptitle)
                                     (format nil "~{~A~^~%~}" suptitle)
                                     suptitle)
                                 :fontsize fontsize)))
      (push (pycall "PyQt6_cl_matplotlib.enable_draggable_title" obj) (figure-interactive-labels fig))
      (draw-figure fig)))

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

(defun add-rectangle (x y w h &key (ax (gca)) (color "r"))
  (assert ax nil "No current axis")
  (let ((rec (pycall "matplotlib.patches.Rectangle" (list x y) w h :color color)))
    (pymethod ax "add_patch" rec)))

(defun demo (&optional (start-loop t))
  (clear-figure-tracking)
  (when start-loop (when (py4cl2:python-alive-p)
                     (pystop)) (start-loop))
  (new-figure :window-title "Surface plot")
  (surf-random-data)
  (new-figure :window-title "Errorbar demo")
  (plot-random-points))

(defun mpl/scatter (x y z &key marker markersize/s (cmap "viridis") (ax (gca)) (show-colorbar cmap) cmin cmax)
  (when (and cmap (not (stringp cmap)))
    (setf cmap (sampled-colormap-to-cmap cmap)))
  (maybe-remove-axis-colorbar ax)
  (let ((sc (apply 'pymethod
                   (axis-handle ax) "scatter" x y
                   :c z :cmap cmap :marker (or marker "o") :s (or markersize/s 16)
                   (append
                    (when cmin (list :vmin cmin))
                    (when cmax (list :vmax cmax))))))
    (when show-colorbar
      (let ((cbar (pymethod (figure-handle (axis-figure ax))
                            "colorbar" sc :ax (axis-handle ax))))
        (setf (axis-colorbar ax) cbar))))
  (draw-axis ax))
  
(defun mpl/pcolormesh (x y z &key (ax (gca)) (cmap "viridis") (shading "gouraud") (show-colorbar t) cmin cmax)
  "z must be (length x) by (length y) 2D array"
  (when (and cmap (not (stringp cmap)))
    (setf cmap (sampled-colormap-to-cmap cmap)))
  (maybe-remove-axis-colorbar ax)
  (let ((im (apply 'pymethod
                   (axis-handle ax) "pcolormesh" x y z
                   :cmap cmap :shading shading
                   (append
                    (when cmin (list :vmin cmin))
                    (when cmax (list :vmax cmax))))))
    (when show-colorbar
      (let ((cbar (pymethod (figure-handle (axis-figure ax))
                            "colorbar" im :ax (axis-handle ax))))
        (setf (axis-colorbar ax) cbar))))
  (draw-axis ax))
            
(defun mpl/get-colorbar (ax)
  "Return a colorbar object from this axis if it exists"
  (or (axis-colorbar ax)
      (map nil (lambda (collection)
                 (let ((cb (ignore-errors (pyslot-value collection "colorbar"))))
                   (when cb
                     (return-from mpl/get-colorbar cb))))
           (pycall "list" (pyslot-value (axis-handle ax) "collections")))))

(defun mpl/set-colorbar-label (string &key (ax (gca)) (draw t) fontsize fontweight color)
  "Text in $ $ will be interpreted as LaTex. Don't forget \\, like
 (title 'My happy e$\\chi$periment')"
  (assert ax nil "No current axis")
  (let ((cb (mpl/get-colorbar ax)))
    (assert cb nil "Did not find a colorbar")
    (apply 'pymethod cb "set_label" string
           (append
            (when fontsize (list :fontsize fontsize))
            (when fontweight (list :fontweight fontweight))
            (when color (list :color color)))))
  (when draw (draw-axis ax)))

;; Matplotlib will handle filled polygons with holes well if the holes are
;; all in the opposite direction of the outer polygon.
;; TODO: if no facecolor, then don't bother with polygon manipulation (so ppl don't
;;       see the cut/bridge.
;; TODO: represent polys with holes going the other way.

(defun close-polygon (polygon)
  "2D polygon is a list of two element lists of numbers ((x0 y0) (x1 y1 )...).  Returns
 a new POLYGON which is closed (and which shares the pairs (x0 y0) ...).  If the polygon
 is already closed still returns a copy of the polygon."
  (let* ((result (list nil))
         (tail result))
    (loop for a in polygon
          for new = (cons a nil)
          do (setf (cdr tail) new) (setf tail new))
    (unless (equalp (car tail) (first polygon))
      (setf (cdr tail) (cons (first polygon) nil)))
    (cdr result)))

(defun mpl/shoelace (polygon)
  "Returns the area of a 2D polygon as a positive value if the polygon vertices are
 represented is represented clockwise, or negative if counter-clockwise.  A POLYGON
 is a list of two element lists of numbers ((x0 y0) (x1 y1) ...).  If the polygon is
 not closed, will close it during the computation."
  (let ((area 0))
    (destructuring-bind (previous-x previous-y)
        (elt polygon 0)
      (map nil (lambda (v)
                 (destructuring-bind (x y) v
                   (incf area (- (* x previous-y) (* previous-x y)))
                   (setf previous-x x previous-y y)))
           (close-polygon polygon))
      (* 0.5 area))))

(defun mpl/plot-polygon
    (exterior &key holes (ax (gca)) facecolor (edgecolor "black")
                autoscale-axis (alpha 0.3) (fill (if (equal facecolor "none") nil t)))
  "matplotlib will automatically handle filling correctly if holes go the opposite
 direction of the outside.  Have to be careful to return from the holes back to the
 last point of the polygon to avoid uncoloring other regions."
  (unless facecolor (setf facecolor (find-next-color ax)))
  (labels ((add-polygon (poly)
             (pymethod (axis-handle ax)
                       "add_patch"
                       (pycall "matplotlib.patches.Polygon"
                               poly
                               :facecolor facecolor
                               :edgecolor edgecolor
                               :alpha alpha
                               :fill fill))))
    (let ((exterior-direction (signum (mpl/shoelace exterior))))
      (setf holes
            (map 'list (lambda (hole)
                         (if (= (signum (mpl/shoelace hole)) exterior-direction)
                             (reverse hole)
                             hole))
                 holes)))
    ;; Make sure we return to the point where the hole drawing started
    ;; so we don't end up with unfilled regions by accident when we have
    ;; more than one hole.
    (let ((exit-from-hole (car (last exterior))))
      (add-polygon
       (apply 'append exterior
              (map 'list (lambda (hole)
                           (append hole (list exit-from-hole)))
                   holes))))
    (draw-axis ax)
    (when autoscale-axis
      (pymethod (axis-handle ax) "autoscale_view"))
    ax))

(defun mpl/tripcolor (triangles x y z &key (ax (gca)) (colormap "viridis") (show-colorbar t)
                                        zmin zmax)
  (maybe-remove-axis-colorbar ax)
  (let* ((sc (apply 'pymethod
                    (axis-handle ax) "tripcolor" x y z
                    :triangles triangles
                    :cmap (maybe-sampled-colormap-to-cmap colormap)
                    (append
                     (when zmin (list :vmin zmin))
                     (when zmax (list :vmax zmax))))))
      (when show-colorbar
        (let ((cbar (pymethod (figure-handle (axis-figure ax))
                              "colorbar" sc :ax (axis-handle ax))))
          (setf (axis-colorbar ax) cbar)))
    (draw-axis ax)))
  
(defun mpl/pcolor (data &key (ax (gca)) (colormap "viridis") (show-colorbar t)
                          zmin zmax)
  "Takes a sequence of '(x y z) points.  The x, y points may be non-uniformly
 distributed (not grid like).  Generates a triangulation to cover the x y points and colors the
 triangles with the scalar value in Z using the colormap specified.  colormap can be a string or an
 array of RGB or RGBA values."
  (maybe-remove-axis-colorbar ax)
  (let* ((x (to-sadf data #'first))
         (y (to-sadf data #'second))
         (z (to-sadf data #'third))
         (sc (apply 'pymethod (axis-handle ax) "tripcolor" x y z
                    :cmap (maybe-sampled-colormap-to-cmap colormap)
                    (append
                     (when zmin (list :vmin zmin))
                     (when zmax (list :vmax zmax))))))
      (when show-colorbar
        (let ((cbar (pymethod (figure-handle (axis-figure ax))
                              "colorbar" sc :ax (axis-handle ax))))
          (setf (axis-colorbar ax) cbar))))
  (draw-axis ax))

(defun mpl/undo ()
  (let ((f (pop *undo*)))
    (when f
      (push f *redo*)
      (funcall (first f)))))

(defun mpl/redo ()
  (let ((f (pop *redo*)))
    (when f
      (push f *undo*)
      (funcall (second f)))))

(defun redraw-trace (copied-trace &optional (ax (gca)))
  (destructuring-bind (x y displayname marker linestyle linecolor markercolor trace-id axes-id)
      copied-trace
    (declare (ignorable markercolor trace-id axes-id))
    (plot-xy-data x y :linestyle linestyle :color linecolor :marker marker :label displayname
                  :ax ax)))

(defun mpl/paste-trace-to-active-figure (copied-trace)
  (assert copied-trace)
  (let* ((ax (gca))
         (artist (nth-value 1 (redraw-trace copied-trace ax))))
    (push (list
           (lambda ()
             (pymethod (elt artist 0) "remove")
             (draw-axis ax))
           (lambda ()
             (setf artist (nth-value 1 (redraw-trace copied-trace ax)))))
          *undo*)))

(defun mpl/delete-trace (trace-id axis-id &optional (figure *current-figure*))
  "If the commands producing the figure are played back, trace-id should be
 reliable."
  (let* ((axis-handle (elt (pymethod (figure-handle figure) "get_axes") axis-id))
         (ax (axis-from-axis-handle axis-handle figure))
         (children (pymethod axis-handle "get_children"))
         (trace *copied-trace*)) ;; right now delete is just cut
    (pymethod (elt children trace-id) "remove")
    (draw-axis ax)
    (let ((temp-artist nil))
      (push (list (lambda ()
                    (setf temp-artist (nth-value 1 (redraw-trace trace ax))))
                  (lambda ()
                    (pymethod (elt temp-artist 0) "remove")
                    (draw-axis ax)))
          *undo*))))

(defvar *headless-lock* (sb-thread:make-mutex))

(defvar *headless-matplotlib* nil
  "A python instance running a headless matplotlib, for generating thumbnails, etc.")

(defun stop-headless-matplotlib ()
  (py4cl2:pystop *headless-matplotlib*)
  (setf *headless-matplotlib* nil))

(defun mpl/run-headless (thunk)
  (sb-thread:with-recursive-lock (*headless-lock*)
    (unless (and *headless-matplotlib* (py4cl2:python-alive-p *headless-matplotlib*))
      (setf *headless-matplotlib* (py4cl2:pystart (py4cl2:config-var 'py4cl2:pycmd) nil))
      (let ((py4cl2::*python* *headless-matplotlib*))
        (import-all-code)
        (py4cl2:pyexec "import headless_matplotlib; import matplotlib; import PyQt6_cl_matplotlib")
        (configure-matplotlib)
        (py4cl2:pyeval "matplotlib.use('Agg')")))
    (let ((py4cl2::*python* *headless-matplotlib*)
          (*current-figure* *current-figure*)
          (*active-figures* (make-hash-table :test 'equal)))
      (prog1
          (funcall thunk)
        (py4cl2:pycall "headless_matplotlib.closeallfigs")))))
