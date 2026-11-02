(defpackage :cl-matplotlib
  (:use :common-lisp :py4cl2)
  (:import-from #:alexandria #:define-constant #:copy-array)
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
   #:mpl/figure-is-open
   #:mpl/get-xlim
   #:mpl/get-ylim
   #:mpl/get-zlim
   #:*invisible-figure*
   #:mpl/toggle-title-visibility
   #:mpl/show-marker-types
   #:mpl/show-linestyle-types
   #:mpl/get-artist
   #:set-tooltips
   #:clear-cl-matplotlib-lisp-state)
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
  (annotations nil :type list)
  (artists nil :type list)
  (subplot nil)
  (colorbar nil) ;; a python handle, is hard to find otherwise
  (interactive-legends nil)  ;; stores interactive-legend handles so they don't get gc'ed

  ;; Set to TRUE (by Python) when the axis is changed in someway, via the function axis-notice-change
  ;; which is installed as a callback. Unfortunately it's not responsive
  ;; to all kinds of changes, like xlims and stuff, so you still have to use axis-properties-hash
  ;; afterwards to be sure.
  (changed-p t :type boolean))

(defmethod print-object ((obj axis) stream)
  (print-unreadable-object (obj stream)
    (let ((figure (axis-figure obj)))
      (format stream "AXIS ~A of #~A '~A'" (axis-subplot obj) (figure-number figure) (figure-window-title figure)))))

(defstruct artist
  (handle nil)
  (axis nil :type axis)
  (annotations nil :type list)
  (highlighted-p nil :type boolean))

(defun artist-highlight (artist)
  "Apply a highlight to the given artist. Used by the interation loop to show which lines are selected."
  (declare (type artist artist))
  ;; (format t "~%ADDING ARTIST HIGHLIGHT to ~s" artist)
  (setf (artist-highlighted-p artist) t)
  (pyexec (artist-handle artist)
          ".set_path_effects([matplotlib.patheffects.Stroke(linewidth=5, foreground='yellow'),
                              matplotlib.patheffects.Normal()])"))

(defun artist-unhighlight (artist)
  "Apply a highlight to the given artist. Used by the interation loop to show which lines are selected."
  (declare (type artist artist))
  ;; (format t "~%REMOVING ARTIST HIGHLIGHT from ~s" artist)
  (setf (artist-highlighted-p artist) nil)
  (pyexec (artist-handle artist)
          ".set_path_effects([matplotlib.patheffects.Normal()])"))

(defmethod print-object ((obj artist) stream)
  (print-unreadable-object (obj stream)
    (format stream "ARTIST on ~A" (artist-axis obj))))

(defun artist-from-handle (axis python-object)
  "Returns the artist object corresponding to the python handle on axis.

   Note that artists can contain other artists. This routine is more about preventing duplicate
   artist structures from pointing to the same thing.  If you say some bogus python-object is an
   artist on axis, we're going to believe you and track it. That could be good or bad, depending
   on what you're trying to do."
  (declare (type axis axis))
  (declare (type python-object python-object))
  (loop :for artist :in (axis-artists axis)
        :when (pyeval (artist-handle artist) " == " python-object)
          :do (return-from artist-from-handle artist))

  ;; Couldn't find it, so create it if it's a real child.
  (let ((new-artist (make-artist :handle python-object :axis axis)))
    (push new-artist (axis-artists axis))
    new-artist))

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

(defun axis-properties-hash (axis)
  "Computes a unique number based on the Axis properties to detect changes. First we check axis-changed-p, because
   that's a fast check... and if that doesn't think there is a change, then we look for changes this
   way.  It's all about knowing when we need to redraw the plot."
  (let ((handle (axis-handle axis)))
    (pyexec "legend_coordinates = None")
    (ignore-errors (pyexec "legend_coordinates = " handle".get_legend()"))
    (pyexec "legend_coordinates = legend_coordinates.get_tightbbox().bounds if legend_coordinates is not None else (0,0,0,0)")
    (pyeval "int(("
            "( 23 * legend_coordinates[0]) + "
            "( 27 * legend_coordinates[1]) + "
            "( 19 * legend_coordinates[2]) + "
            "( 17 * legend_coordinates[3]) + "
            "( 53 * " handle".get_ylim()[1]) + "
            "( 7 * " handle".get_ylim()[0]) + "
            "( 53 * " handle".get_ylim()[1]) + "
            "( 13 * " handle".get_xlim()[0]) + "
            "( 3 * " handle".get_xlim()[1]) + "
            "( 11 * " handle ".get_xmargin()) +"
            "( 19 * " handle ".get_ymargin())) * 1000000)")))

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
       (ignore-errors
        (pymethod (figure-dockwidget oldfig) "setWindowTitle"
                 (figure-window-title *current-figure*)))))
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

(defvar *invisible-figure* nil)

(defvar *new-figure-callbacks* '(install-interactivity)
  "A list of callback functions called when a new
   figure is created.  The callback is called with the figure structure.")

(defun new-figure (&key window-title
                     figure-number (layout "tabbed")
                     (tiled-layout-request '(1 1))
                     (invisible *invisible-figure*)
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
           #'pycall
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

    (loop :for callback :in *new-figure-callbacks*
          :do (funcall callback fig))

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

(defun axis-notice-change (axis-handle)
  "This is installed as a callback. This way when python thinks the axis has changed it
   can just directly let us know."
  (let ((axis (axis-from-axis-handle axis-handle)))
    (when axis
      (setf (axis-changed-p axis) t))))

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

(alexandria:define-constant +single-character-markers+
  #(#\. #\, #\o #\v #\^ #\< #\> #\1 #\2 #\3 #\4 #\8 #\s #\p #\P #\* #\h #\H
    #\+ #\x #\X #\D #\d #\| #\_ #\Space) :test 'equalp)

(defun validate-marker (marker)
  "marker is valid or raises an error"
  (etypecase marker
    ((string 0))
    ((string 1) (assert (find (aref marker 0) +single-character-markers+)))
    ((integer 0 11))
    (string
     (assert (or (equal marker "none")
                 (equal marker "None")
                 (and (> (length marker) 1)
                      (eq #\$ (elt marker 0))
                      (eq #\$ (elt marker (- (length marker) 1)))))))
    (list (assert (or
                   (and (= (length marker) 3)
                        (integerp (elt marker 0))
                        (<= 0 (elt marker 1) 2)
                        (numberp (elt marker 2)))
                   (every (lambda (x) (and (typep x 'sequence) (every #'numberp x))) marker)))))) ;; list of verts

(defun matlab-marker-to-matplotlib-marker (marker)
  "convert some special matlab marker strings to appropriate matplotlib and validate the marker input"
  (when marker
    (cond
      ((equalp marker "diamond") "D") ;; regular diamond, "d" is thin diamond
      ((equalp marker "square") "s")
      ((equalp marker "hexagram") "h")
      ((equalp marker "pentagram") "p")
      (t (validate-marker marker) marker))))

(defun mpl/show-marker-types ()
  (mpl/figure "marker")
  (clear-figure)
  (let* ((counter 50)
         (N 6)
         (x (loop for i from 0 below N collect i)))
    (labels ((pl (mark-string &optional (label (format nil "~S" mark-string)))
               (plot-xy-data x (make-list N :initial-element counter)
                             :marker mark-string :label label :linestyle "")
               (decf counter)))
      (loop for marker across +single-character-markers+
            for mark-string = (make-string 1 :initial-element marker)
            do (pl mark-string))
      (loop for mark-string from 0 below 12
            do (pl mark-string))
      (pl "none")
      (pl "$a$" "\"\\$a\\$\"")
      (pl "$b$" "\"\\$b\\$\"")
      (pl "None")
      (pl '(4 0 45) "(4 0 45)")
      (pl '(4 0 0) "(4 0 0)")
      (pl '(4 1 0) "(4 1 0)")
      (pl '(4 2 0) "(4 2 0)")
      (pl '(3 0 0) "(3 0 0)")
      (pl "")
      (pl '((0 0) (1 1) (1 0)) "((0 0) (1 1) (1 0))")
      (mpl/xlim -0.5 (+ N 2))
      (mpl/legend :ncol 2 :location "upper right"))))

(defun mpl/show-linestyle-types ()
  (mpl/figure "linestyles")
  (clear-figure)
  (let* ((counter 50)
         (N 6)
         (x (loop for i from 0 below N collect i)))
    (labels ((pl (linestyle &optional gapcolor)
               (plot-xy-data x (make-list N :initial-element counter)
                             :label (format nil ":linestyle ~S~@[ :gapcolor ~S~]" linestyle gapcolor)
                             :linestyle linestyle
                             :gapcolor gapcolor)
               (decf counter)))
      (pl "-")
      (pl "--")
      (pl "-.")
      (pl ":")
      (pl "none")
      (pl '(0 (2 1)))
      (pl '(0 (2 1)) "green")
      (pl '(0 (10 5 1 5)))
      (pl '(0 (10 5 1 5)) "blue")
      (mpl/xlim -0.5 8.75)
      (mpl/legend))))

(defun validate-linestyle (linestyle)
  (when linestyle
    (etypecase linestyle
      (string (assert (member linestyle '("-" "--" "-." ":" "none" "") :test 'equal)))
      (list (assert (and (= (length linestyle) 2) (numberp (first linestyle))
                         (typep (second linestyle) 'sequence)
                         (every #'numberp (second linestyle))))))
    linestyle))

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
              (pymethod new-ax-handle "add_callback" #'axis-notice-change)
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
                (pymethod ax "add_callback" #'axis-notice-change)
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

(defparameter *copied-traces* nil
  "The last trace(s) that were copied with Ctrl-c (or ctrl-x)")

(defparameter *undo* nil
  "Stores lists of two functions, first is an undo function, second is a redo function")
(defparameter *redo* nil
  "Stores lists of two functions, first is an undo function, second is a redo function")

(defvar *copy-callback* (lambda (line-copies)
                          (setf *copied-traces* line-copies))
  "a lambda (line-copies) to get called on ctrl-c, ctrl-x.  trace-info will have been stored in *copied-traces*.  User extension point.")

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

(defun configure-matplotlib ()
  (pyexec "import matplotlib; import matplotlib.pyplot as plt; import mpl_toolkits")
  (pyeval "plt.ion()")
  (pyeval "matplotlib.style.use('fast')")
  (pyexec "matplotlib.rcParams['axes.formatter.limits'] = (-4, 4)")
  (pyexec "matplotlib.rcParams['axes.formatter.use_mathtext'] = True")
  (pyexec (format nil "matplotlib.rcParams['savefig.directory'] = '~A'"
                  *default-pathname-defaults*))
  (pyexec "matplotlib.rcParams['axes.formatter.useoffset'] = False"))

(defvar *legend-clicked-force-redraw-p* nil
  "This variable exists because when the legend is clicked we want to know it happened so we can
   redraw. We can pass the axis handle back and convert it to an axis object, but in testing
   it was more reliable to just set this flag and let the interactivity handler assume the clicked
   axis is the currently active one.")

(defun start-loop ()
  "Call this to start the main gui loop"
  (start-up/internal)
  ;; Force reload, works around file date issues on my FS
  (py4cl2:pyexec "if 'PyQt6_cl_matplotlib' in sys.modules: del sys.modules['my_module']")
  (py4cl2:pyexec "import PyQt6_cl_matplotlib;")
  (py4cl2:raw-py-exec/no-return "PyQt6_cl_matplotlib.start_app(try_process_message);")
  (py4cl2:pycall "PyQt6_cl_matplotlib.set_callbacks"
                 ;; Set-active-figure
                 (lambda (unique-figure-id axis)
                   (unless (eql unique-figure-id -1)
                     (ignore-errors ;; this callback may fire before figure is built, that's OK, ignore
                      (let ((fig (mpl/set-figure-active unique-figure-id)))
                        (set-active-axis-handle axis fig))))
                   (values))

                 ;; Close-window
                 (lambda (unique-figure-id)
                   (delete-figure& unique-figure-id)
                   (values))

                 ;; Legend toggle
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

                 ;; New figure
                 (lambda ()
                   (mpl/figure nil))

                 ;; Title visibility
                 (lambda ()
                   (mpl/toggle-title-visibility))

                 ;; Force redraw
                 (lambda ()
                   ;; While we can have Python tell us the changed
                   ;; axis, that proved less reliable than just telling
                   ;; the interactivy loop that something has changed
                   ;; and it assuming it was the current axis.
                   (setf *legend-clicked-force-redraw-p* t)))

  ;; Verify that the system is OK.
  (assert (= (pyeval "1 + 1") 2))
  ;; The above will throw an error if the no-return statement did not succeed
  (configure-matplotlib)
  ;; Start bash script to monitor the status of the lisp process,
  ;; and kill the python process if lisp has exited.
  (uiop:launch-program
   (list "./lib/cl-matplotlib/src/monitor-lisp-process.sh"
         (write-to-string (sb-posix:getpid))
         (write-to-string (uiop:process-info-pid (py4cl2::python-subprocess py4cl2::*python*)))))
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
      ((is "y" "yellow") '(1.0d0 0.72d0 0.035d0)) ;; amber
      ((is "k" "black") '(0.0 0.0 0.0))
      ((is "w" "white") '(1.0 1.0 1.0))
      ((is "gr" "gray") '(0.7 0.7 0.7))
      (t (error "Unknown color ~A" color)))))

;; Default color order is blue, red, green, black, pink, cyan, amber (yellow).  We don't use exactly black because
;; our way of counting colors includes the figure lines which count as strictly black
(defvar *color-set* #((0d0 0d0 1d0) (1d0 0d0 0d0) (0d0 1d0 0d0) (0.001d0 0.001d0 0.001d0) (1d0 0d0 1d0) (0d0 1d0 1d0) (1.0d0 0.72d0 0.035d0)))

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
      (map nil (lambda (color)
                 (let ((count (gethash color used-colors)))
                   (when (< count minimum-used)
                     (setf minimum-used count)
                     (setf best-color color))))
           *color-set*)
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
                                        markeredgecolor hide-in-legend (picker 5) ecolor gapcolor)
  "Note picker copy operation does not grab error bars yet..."
  (validate-linestyle linestyle)
  (setf ax (get-axis! ax))
  (unless color
    (setf color (find-next-color ax)))
  (let ((errorbarcontainer
          (pymethod (axis-handle ax) "errorbar" x y
                    :yerr (list y- y+)
                    :xerr (list x- x+)
                    :linestyle (or linestyle "None")
                    :markeredgecolor (or markeredgecolor color "None")
                    :markerfacecolor (or markerfacecolor color "None")
                    :marker (or (matlab-marker-to-matplotlib-marker marker) "None")
                    :capsize 3d0
                    :label (make-trace-name label hide-in-legend)
                    :color color
                    :markersize (or markersize "None")
                    :linewidth (or linewidth 2)
                    :picker picker
                    :ecolor (or ecolor color)
                    :gapcolor (or gapcolor "None"))))
    (draw-axis ax)
    (values ax errorbarcontainer)))

(defun get-figure! (&optional figure-title)
  "May create a new figure.  Always returns a figure."
  (mpl/gcf figure-title))

(defun plot-xy-data (x y &key linestyle color (marker "o") markersize label hide-in-legend (ax (gca)) (picker 5)
                           markerfacecolor markeredgecolor linewidth gapcolor)
  (when (and x y)
    (validate-linestyle linestyle)
    (unless color
      (setf color (find-next-color ax)))
    (let* ((artist-handles
             (apply 'pymethod (axis-handle ax) "plot" x y
                    :linestyle (or linestyle "None")
                    :color (or color "None")
                    :marker (or (matlab-marker-to-matplotlib-marker marker) "None")
                    :markersize (or markersize "None")
                    :label (make-trace-name label hide-in-legend)
                    (append
                     (when gapcolor (list :gapcolor gapcolor))
                     (when picker (list :picker picker))
                     (when linewidth (list :linewidth linewidth))
                     (when markerfacecolor (list :markerfacecolor markerfacecolor))
                     (when markeredgecolor (list :markeredgecolor markeredgecolor)))))
           ;; Plot returns a list of lines, there should be exactly 1.
           (artist (make-artist :handle (elt artist-handles 0) :axis ax)))
      (push artist (axis-artists ax))
      (draw-axis ax)
      (values ax (list artist)))))

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
    (validate-linestyle linestyle)
    (pyexec "import matplotlib")
    (pyexec "from mpl_toolkits.mplot3d import Axes3D")
    (let* ((ax (ensure-3d-axis (or ax (gca)))))
      (when (or (and linestyle (not (equalp linestyle "none"))) linewidth)
        (apply 'pymethod (axis-handle ax) "plot3D" x y z
               :c (or color "b")
               (append (when linestyle (list :linestyle linestyle))
                       (when linewidth (list :linewidth linewidth)))))
      (apply 'pymethod (axis-handle ax) "scatter" x y z :marker (matlab-marker-to-matplotlib-marker marker)
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

(defun mpl/toggle-title-visibility (&key (ax (gca)))
  "Appends string to title if specified with action :append or replaces it
 if :replace.  Keeps fontsize, fontweight, color.  To build a new title call
 mpl/title.  To change fonts try mpl/set-title-props."
  (let ((title (pyslot-value (axis-handle ax) "title")))
    (when (and title (not (equal title "None")))
      (pymethod title "set_visible" (not (pymethod title "get_visible")))
      (draw-axis ax))))

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
  (check-type switch (member :on :off))
  (check-type which (member :major :minor))
  (when (and (eq which :minor) (eq switch :on))
    ;; Need to make sure minor ticks are on
    (pymethod (axis-handle ax) "minorticks_on"))
  (py4cl2:pymethod (axis-handle ax) "grid"
                   (if (eq switch :on) t nil)
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

(defun mpl/get-xlim (&key (ax (gca)))
  "Return a list (min max) for the visible range of the x-axis"
  (pymethod (axis-handle ax) "get_xlim"))

(defun mpl/get-ylim (&key (ax (gca)))
  "Return a list (min max) for the visible range of the y-axis"
  (pymethod (axis-handle ax) "get_ylim"))

(defun mpl/get-zlim (&key (ax (gca)))
  "Return a list (min max) for the visible range of the z-axis"
  (pymethod (axis-handle ax) "get_zlim"))

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
    (filename &key (width-pixels 2000) (height-pixels 1440) (dpi 200))
  "FILENAME is a full, absolute path to the destination file."
  ;; I think if name is specified it uses it, otherwise it
  ;; puts name-prefix figure-window-title name-suffix with some fiddling,
  ;; and tidying see build-figname
  (let* ((fig *current-figure*)
         (full-filename (if (or (search ".png" filename)
                                (search ".pdf" filename)
                                (search ".eps" filename))
                            filename
                            (format nil "~a.~a" filename "png"))))
    (assert fig)
    ;; We quantize the size for comparing to see if we can avoid re-drawing.
    (let* ((old-size (pymethod (figure-handle fig) "get_size_inches"))
           (new-width-inches (* 1000.0 (round width-pixels (/ dpi 1000.0))))
           (new-height-inches (* 1000.0 (round height-pixels (/ dpi 1000.0))))
           (is-same-size (and (= new-width-inches (round (* 1000 (elt old-size 0))))
                              (= new-height-inches (round (* 1000 (elt old-size 1)))))))
      (unless is-same-size
        (pymethod (figure-handle fig) "set_size_inches" (/ width-pixels dpi 1.0) (/ height-pixels dpi 1.0)))
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
        (setf (pyslot-value (figure-dockwidget figure) "unique_figure_id") new-fig-id)
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

(defun validate-horizontal-alignment (horizontal-alignment)
  (setf horizontal-alignment (string-downcase horizontal-alignment))
  (assert (member horizontal-alignment '("left" "center" "right") :test 'string=))
  horizontal-alignment)

(defun validate-vertical-alignment (vertical-alignment)
  (setf vertical-alignment (string-downcase vertical-alignment))
  (member vertical-alignment '("center" "top" "bottom") :test 'string=)
  vertical-alignment)

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
                                                :linestyle (validate-linestyle linestyle)
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
                     :horizontalalignment (validate-horizontal-alignment horizontal-alignment)
                     :verticalalignment (validate-vertical-alignment vertical-alignment)))
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
                   :linestyle (validate-linestyle linestyle)
                   :label (if (or (not displayname) omit-from-legend) "_" displayname))
  (when label
    (py4cl2:pymethod (axis-handle ax) "text"
                     :y y
                     :x label-x-fraction
                     :transform (pymethod (axis-handle ax) "get_yaxis_transform")
                     :s label
                     :rotation orientation
                     :horizontalalignment (validate-horizontal-alignment horizontal-alignment)
                     :verticalalignment (validate-vertical-alignment vertical-alignment)))
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

(defun validate-rotation (rotation)
  (assert (numberp rotation))
  rotation)

(defun mpl/draw-text (x y text
                      &key horizontal-alignment (fontsize 8) (color "k") vertical-alignment
                        interpreter rotation background-color normalized-x normalized-y
                        fontweight (draw-axis t) (ax (gca)))
  (declare (ignorable interpreter))
  (let* ((axh (axis-handle ax)))
    (apply 'py4cl2:pymethod axh "text" x y text
           (append
            ;;(when interpreter (list :interpreter interpreter))
            (when rotation (list :rotation (validate-rotation rotation)))
            (when background-color (list :backgroundcolor background-color))
            (when color (list :color color))
            (when fontsize (list :fontsize fontsize))
            (when vertical-alignment
              (list :verticalalignment (validate-vertical-alignment vertical-alignment)))
            (when horizontal-alignment
              (list :horizontalalignment (validate-horizontal-alignment horizontal-alignment)))
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
  (assert ax)
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
    (cond
      ((equal leg "None") ;; not sure why this happens, but it does sometimes!
       (warn "legend call returned None"))
      (t
       (pymethod leg "set_draggable" t)
       ;; We need to keep the interactive legend object alive, so
       ;; we stuff it into the axes object
       (push (pycall "enable_legend_interactivity" (axis-handle ax) leg)
             (axis-interactive-legends ax)))))
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
                 (incf count)
                 ;; Update our understanding of them so user can go back to the axis with nexttile :tilenum
                 ;; or subplot
                 (let ((ax (find obj (figure-axes figure) :test (lambda (a b) (pyeval a "==" (axis-handle b))))))
                   (assert ax)
                   (setf (axis-subplot ax) (list nrows ncols count))))
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
  (validate-linestyle linestyle)
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
            (when marker (list :marker (matlab-marker-to-matplotlib-marker marker)))
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
    (setf x (to-sadf x) y (to-sadf y))
    (unless (arrayp z)
      (setf z (to-sadf z)))
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

(defun mpl/draw-arrow (initial-pt final-pt &key arrow-type string color linestyle textcolor textrotation (draggable t))
  "arrow-type: - <- -> <-> <|- -|> <|-|> ]- -[ ]-[ |-| ]-> <-[ simple fancy wedge"
  (validate-linestyle linestyle)
  (let* ((ax (gca))
         (arrow
           (pymethod (axis-handle ax) "annotate" (or string "")
                     :xy initial-pt
                     :xycoords "data"
                     :xytext final-pt
                     :textcoords "data"
                     :color (or textcolor "k")
                     :rotation (or textrotation 0)
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
                             :linestyle (or linestyle "-")))))
    (when draggable (pymethod arrow "draggable"))
    (draw-axis ax)
    (values ax arrow)))

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

(defun to-simple-array-double-float (input &optional (nil-value 0d0) (nan-value 0d0))
  (if (typep input 'sequence)
      (to-sadf input)
      (if (typep input '(simple-array double-float *))
          input
          (let* ((dims (array-dimensions input))
                 (new-array (make-array dims :element-type 'double-float)))
            (dotimes (i (array-total-size input))
              (let ((d (row-major-aref input i)))
                (setf (row-major-aref new-array i)
                      (if (null d)
                          nil-value
                          (if (and (typep d 'float) (float-features:float-nan-p d))
                              nan-value
                              (coerce d 'double-float))))))
            new-array))))

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
         (max sb-ext:double-float-negative-infinity)
         (alpha-stencil (if (and use-alpha alpha-stencil)
                            (to-simple-array-double-float alpha-stencil)
                            (make-array dimensions :element-type 'double-float :initial-element 1d0))))
    ;; image-data may have NIL or NaNs in it.  Take those out and put them in ALPHA-STENCIL
    (dotimes (i (array-total-size image-data))
      (let ((d (row-major-aref image-data i)))
        (if (or (not d) (and (typep d 'float) (float-features:float-nan-p d)))
            (setf (row-major-aref alpha-stencil i) 0d0)
            (progn
              (when (> d max) (setf max d))
              (when (< d min) (setf min d))))))
    (setf image-data (to-simple-array-double-float image-data 0d0 0d0))
    (let* ((ax (gca))
           (axh (axis-handle ax))
           (cmap (when colormap (maybe-sampled-colormap-to-cmap colormap)))
           (real-min (or colorbar-min min))
           (real-max (or colorbar-max max)))
      ;; should create the clipped colorbar mapping here...
      (apply 'py4cl2:pymethod
             axh "imshow" image-data
             :alpha alpha-stencil
             :extent (append x-range y-range)
             :aspect "auto" :origin "lower"  ;; flip so matches matlab
             (when cmap
               (list :norm (apply 'py4cl2:pycall "matplotlib.colors.Normalize"
                                  :vmin real-min :vmax real-max
                                  (when clip (list :clip t)))
                     :cmap cmap)))
      (mpl/add-colorbar :min real-min :max real-max :cmap colormap :clip clip :apply nil)
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
      (setf data (remove-if (lambda (x) (zerop (second x))) data))
      (apply 'py4cl2:pymethod (axis-handle ax)
             "bar"
             (to-sadf data #'first)
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
                   :c z :cmap cmap :marker (or (matlab-marker-to-matplotlib-marker marker) "o")
                   :s (or markersize/s 16)
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
 direction of the outside.

 (loop for n in (reverse '(4 5 6 7 8 9 10 300 3000))
                 do
                    (mpl/plot-polygon (loop for angle in (linspace 0.0 nil (* 2 pi) :n n)
                                            collect (list (sin angle) (cos angle)))
                                  :holes '(((0.0 0.25) (-0.25 -0.25) (0.25 -0.25))))))"
  (unless facecolor (setf facecolor (find-next-color ax)))
  (let ((exterior-direction (signum (mpl/shoelace exterior))))
    (setf holes
          (map 'list (lambda (hole)
                       ;; Reverse direction if needed and add dummy vertex for CLOSEPOLY
                       (if (= (signum (mpl/shoelace hole)) exterior-direction)
                           (append (reverse hole) '((0.0 0.0)))
                           (append hole '((0.0 0.0)))))
               holes)))
  ;; Add dummy vertex for CLOSEPOLY
  (setf exterior (append exterior '((0.0 0.0))))
  (let ((moveto (pyeval "matplotlib.path.Path.MOVETO"))
        (lineto (pyeval "matplotlib.path.Path.LINETO"))
        (closepoly (pyeval "matplotlib.path.Path.CLOSEPOLY")))
    (labels ((make-path (verts)
               (let* ((num-verts (length verts))
                      (a (make-array num-verts :element-type '(unsigned-byte 8) :initial-element lineto)))
                 (setf (aref a 0) moveto)
                 (setf (aref a (- num-verts 1)) closepoly)
                 a)))
      (let* ((polygon-path (make-path exterior))
             (hole-paths (map 'list #'make-path holes))
             (all-paths
               (apply 'concatenate '(simple-array (unsigned-byte 8) (*)) polygon-path hole-paths))
             (poly-points (apply 'append exterior holes)))
        (when (> (length poly-points) 100)
          ;; convert to an array for transmission to python
          (setf poly-points
                (make-array (list (length poly-points) 2) :element-type 'double-float :initial-contents
                            (map 'list (lambda (x) (list (float (elt x 0) 0d0)
                                                         (float (elt x 1) 0d0))) poly-points))))
        (let* ((path (pycall "matplotlib.path.Path" poly-points all-paths))
               (patch (pycall "matplotlib.patches.PathPatch" path :facecolor facecolor :edgecolor edgecolor :alpha alpha :fill fill)))
          (pymethod (axis-handle ax) "add_patch" patch)))))
  (draw-axis ax)
  (when autoscale-axis
    (pymethod (axis-handle ax) "autoscale_view"))
  ax)

(defun mpl/tripcolor (triangles x y z &key (ax (gca)) (colormap "viridis") (show-colorbar t)
                                        zmin zmax edgecolor)
  (maybe-remove-axis-colorbar ax)
  (unless (typep triangles '(simple-array (unsigned-byte 32) (* 3)))
    (setf triangles (alexandria:copy-array triangles :element-type '(unsigned-byte 32))))
  (let* ((sc (apply 'pymethod
                    (axis-handle ax) "tripcolor" x y z
                    :triangles triangles
                    :cmap (maybe-sampled-colormap-to-cmap colormap)
                    (append
                     (when edgecolor (list :edgecolor edgecolor))
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reapers and Moribund objects
;;
;; When you return an object from Python, py4cl2 actually stores in on the python side and passes
;; you back a numeric reference wrapped in an object.  This lisp side object has a finalizer that
;; will free the python side reference when the lisp side object goes away. But this isn't quite
;; enough; we want two more features:
;;
;;   1. The ability to do extra work in that finalizer (For example, to automatically remove a plot
;;      annotation when lisp no longer has a reference to it), and
;;   2. The ability to trigger that extra work immediately, to remove an annotation, regardless of
;;      who is referencing it, and without needing to run `sb-ext:gc` to trigger finalizers.
;;
;; Reapers provide this: They contain the extra-cleanup function and a boolean flag to prevent
;; double-execution. If your lisp object holds py4cl2 handle(s), you can instantiate a reaper with
;; the necessary cleanup instructions and install it as a finalizer on that lisp object.
;; 
;; **The reaper should not have a reference to the lisp object (that would prevent GC) but the
;; reaper can have references to the py4cl2 objects.**
;;
;; A moribund structure is a structure that sees death coming for it (it has a handle to it's own
;; reaper)!  You can hook up your structures close and closed-p methods to the reaper. This gives
;; you a structure that is closable, closes on GC, and closes only once.

(defstruct (reaper (:conc-name "") (:constructor make-reaper (reap-fn)))
  "A reaper is the bookkeeping for the dead.  It stores a reaping function and ensures it's only
   executed once. It's useful for making finalizers and close-this-thing functions work together
   nicely."
  (reaped-p nil :type boolean :read-only nil)
  (reap-fn #'(lambda () nil) :type function :read-only t))

(defun reap (reaper)
  "Unless already reaped, run the reaping function (and claim soul, most likely)."
  (declare (type reaper reaper))
  (when (eq nil (sb-ext:compare-and-swap (reaped-p reaper) nil t))
    (funcall (reap-fn reaper))))

(defstruct moribund
  "A moribund object is one that knows death awaits it. It holds a handle to it's own reaper
   and can ask it if it's dead already.  Usually the reaper will also be installed as a finalizer
   to reap objects we don't have handles too."
  (reaper nil :type reaper :read-only t))

(defun dont-fear-the-reaper (moribund &aux (reaper (moribund-reaper moribund)))
  "Registers the reaper stored on the moribund as the finalizer of the moribund. The name of
   this function is awesome."
  (sb-ext:finalize moribund #'(lambda () (reap reaper))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MPL Callback
;;
;; Matplotlib supports adding events and callbacks. This structure allows registering
;; lisp callbacks for matplotlib events.
;;
;; Example use:
;;
;; (defvar *output* *standard-output*)
;; (register *current-figure*
;;           :button-press-event
;;           #'(lambda (&rest args)
;;               (format *output* "~%BUTTON PRESS: ~s" args)))
;; (register *current-figure*
;;           :pick-event
;;           #'(lambda (&rest args)
;;               (format *output* "~%PICK: ~s" args)))

(deftype mpl-event ()
  '(member
    :pick-event
    :button-press-event
    :button-release-event
    :motion-notify-event
    :key-press-event
    :key-release-event
    :axes-enter-event))

(defstruct (mpl-callback (:include moribund))
  (cid nil :type fixnum :read-only t)
  (event nil :type mpl-event :read-only t)
  (lisp-callback nil :type function :read-only t)
  (python-callback0 nil :type python-object :read-only t)
  (python-callback1 nil :type python-object :read-only t))

(defun unregister-callback (mpl-callback)
  (reap (mpl-callback-reaper mpl-callback)))

(defun callback-active-p (mpl-callback)
  (not (reaped-p (mpl-callback-reaper mpl-callback))))

(defun register-callback (figure event callback-function)
  "Register an mpl-callback on a figure. Note that it actually is registered
   on the canvas that backs the figure, but we don't keep references to canvas...
   just figures."
  (declare (type figure figure))
  (declare (type mpl-event event))
  (declare (type function callback-function))
  (let* ((canvas (pyslot-value (figure-handle figure) "canvas"))
         ;; Do this so we keep a reference to this handle so it doesn't GC.
         (python-callback0 (pyeval callback-function))
         ;; Then wrap that in a lambda and keep a reference to that so it doesn't GC.
         (python-callback1 (pyeval "lambda ev: " python-callback0 "(PyQt6_cl_matplotlib.time.time(), ev)"))
         (cid (pymethod canvas "mpl_connect"
                        (ecase event
                          (:pick-event "pick_event")
                          (:button-press-event "button_press_event")
                          (:button-release-event "button_release_event")
                          (:motion-notify-event "motion_notify_event")
                          (:key-press-event "key_press_event")
                          (:key-release-event "key_release_event")
                          (:axes-enter-event "axes_enter_event"))
                        ;; Inside the Python environment, Attach the current time to the event.
                        ;; If we get the time on the Lisp side our resolution is limited to
                        ;; polling rate our python<->lisp communication loop
                        ;; communicates.  This helps, but it isn't PERFECT, and QT doesn't
                        ;; give us anything better, so we're hosed.
                        ;;
                        ;; Basically, when there is lots to draw, the timing becomes so inaccurate
                        ;; when drawing that we can't tell short clicks from long clicks. Double
                        ;; clicks still seem to be reliably distinguished.
                        ;;
                        ;; In practice that means that if your screen is BUSY all short clicks will
                        ;; become long clicks. So you should probably set up your actions so that
                        ;; long clicks on objects can make the screen less busy.
                        python-callback1))
         (reaper (make-reaper #'(lambda ()
                                  (ignore-errors
                                   (pymethod canvas "mpl_disconnect" cid)))))
         (callback (make-mpl-callback
                    :event event
                    :reaper reaper
                    :cid cid
                    :lisp-callback callback-function
                    :python-callback0 python-callback0
                    :python-callback1 python-callback1)))
    (dont-fear-the-reaper callback)
    callback))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Annotations
;;
;; An annotation is a moribund structure. It lets you draw arbitrarily on the plot.  One use of
;; this is implementing callout annotations that are used for tooltips.

(defstruct (annotation (:include moribund))
  "An annotation is a handle to a matplotlib annotation object and an optional interaction-update-fn
   which can be used to update the annotation depending on the user interaction state.  If supplied
   the interaction object will call it with both the annotation and an interaction-state structure."
  (handle nil :type python-object :read-only t)
  (axis nil :type axis :read-only t)
  ;; Some annotations are tooltips which conceptually belong to an artist. We can fill this out
  ;; to provide more information on the Lisp side.
  ;; When an annotation has an artist, it's added to both the axis-annotations AND artist-annotations.
  (artist nil :type (or null artist) :read-only t)
  (interaction-update-fn nil :type (or null symbol function) :read-only t))

(defmethod print-object ((obj annotation) stream)
  (print-unreadable-object (obj stream)
    (format stream "ANNOTATION on ~A" (annotation-axis obj))))

(defun annotation-screen-coords (annotation)
  "Returns the screen coordinates of the annotation. (xmin xmax ymin ymax). If the annotation
   is closed returns (60000 60001 60000 60001), which should be way off screen."
  (cond ((annotation-closed-p annotation)
         '(60000 60000 60001 60001))
        (t
         (pyexec "ann_xy_cmp_temp = None")
         (ignore-errors (pyexec "ann_xy_cmp_temp = " (annotation-handle annotation) ".get_bbox_patch().get_extents()"))
         (prog1 (pyeval "(60000, 60000, 60001, 60001) if ann_xy_cmp_temp is None else (ann_xy_cmp_temp.xmin, ann_xy_cmp_temp.xmax, ann_xy_cmp_temp.ymin, ann_xy_cmp_temp.ymax)")
           (pyexec "ann_xy_cmp_temp = None")))))

(defvar *remove-annotation-callback* nil
  "This callback is setup when the interactivity thread is setup.  When it's in place
   we remove annotations with this and it will animate them out.  If it's not
   in place, the annotate will just be removed.")

(defun remove-annotation (annotation
                          &aux
                            (axis (annotation-axis annotation))
                            (artist (annotation-artist annotation)))
  (flet ((detach-and-trash-annotation ()
           (when axis
             (setf (axis-annotations axis)
                   (remove annotation (axis-annotations axis))))
           (when artist
             (setf (artist-annotations artist)
                   (remove annotation (artist-annotations artist))))
           (reap (annotation-reaper annotation))))
    (if (and *remove-annotation-callback*
             (not (annotation-closed-p annotation)))
        (funcall *remove-annotation-callback* annotation
                 #'detach-and-trash-annotation)
        (detach-and-trash-annotation))))

(defun annotation-closed-p (annotation)
  (reaped-p (annotation-reaper annotation)))

(defvar *register-annotation-callback* nil
  "This callback is setup when the interactivity thread is setup.  When it's in place
   we register annotations with it and it will animate them open..  If it's not
   in place, the annotate function will just draw itself.")

(defun annotate (axis text xy
                 &key artist
                   xytext
                   horizontal-alignment
                   vertical-alignment
                   xycoords
                   textcoords
                   z-order
                   b-box
                   arrow-properties
                   interaction-update-fn)
  "Place an annotation on an axis. Returns an annotation structure. The annotation will be shown when the axis is redrawn."
  (declare (type string text))
  (declare (type cons xy))
  (declare (type axis axis))
  (declare (type (or null artist) artist))
  (declare (type (or null function symbol) interaction-update-fn))
  (assert (or (typep (car xy) 'py4cl2::python-object) ;; a number, or a datetime object
              (numberp (car xy))))
  (assert (numberp (cadr xy)))
  (when artist
    (assert (eq axis (artist-axis artist))))
  (let* ((handle (apply #'pymethod (axis-handle axis)
                        "annotate"
                        text
                        :xy xy
                        (append
                         (and xytext `(:xytext ,xytext))
                         (and horizontal-alignment `(:horizontalalignment ,horizontal-alignment))
                         (and vertical-alignment `(:verticalalignment ,vertical-alignment))
                         (and textcoords `(:textcoords ,textcoords))
                         (and xycoords `(:xycoords ,(if (axis-p xycoords)
                                                        (pyslot-value (axis-handle xycoords) ".transAxes")
                                                        xycoords)))
                         (and z-order `(:zorder ,z-order))
                         (and b-box `(:bbox ,b-box))
                         (and arrow-properties `(:arrowprops ,arrow-properties)))))
         (reaper (make-reaper
                  #'(lambda ()
                      (ignore-errors
                       (pymethod handle "remove")
                       ;; We don't want to automatically trigger a redraw.
                       ;; That should be a decision of higher level code.
                       ;; (draw-axis axis)
                       ))))
         (annotation (make-annotation :handle handle :axis axis :artist artist :reaper reaper :interaction-update-fn interaction-update-fn)))
    (dont-fear-the-reaper annotation)
    (when artist
      (push annotation (artist-annotations artist)))
    (push annotation (axis-annotations axis))

    ;; If we have an interaction handler, by registering with it
    ;; we should get drawn.  If we don't, just draw ourselves.
    (if *register-annotation-callback*
        (funcall *register-annotation-callback* annotation nil)
        (pyexec (annotation-handle annotation) ".draw("
                (figure-handle (axis-figure (annotation-axis annotation)))
                ".canvas.get_renderer())"))

    annotation))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Tooltip
;;
;; Tooltips are user specified callouts associated with the points of a line. This subsystem tracks
;; the set of tooltips for an artist. They're in a weakly keyed hash table on the artist object of
;; an axis.
;;
;; Example usage:
;;
;;  (plot-random-points)
;;
;;  ;; Update text and show:
;;  (setf (tooltip (gca) 3) "Here is a point!")
;;  ;; Hide it
;;  (hide-tooltip (gca) 3)
;;  ;; Show it again
;;  (tooltip (gca) 3)

(defvar *tooltips* (make-hash-table :weakness :key)
  "A weakly keyed hashtable of axis / artist -> tooltips structure.")
(defstruct tooltips
  "This is a state tracking object. They're weakly keyed on an artist
   via the *tooltips* variable.

   Strings is a vector of string or nil.  NIL if no tooltip was defined."
  (strings #() :type simple-vector :read-only nil)
  (callouts #() :type simple-vector :read-only nil))

(defun artist-num-points (artist)
  (pyeval "len(" (artist-handle artist) ".get_xdata()) if isinstance(" (artist-handle artist) ", matplotlib.lines.Line2D) "
          "else ("(artist-handle artist)".get_size()[0] * " (artist-handle artist) ".get_size()[1] if isinstance(" (artist-handle artist) ", matplotlib.image.AxesImage) "
          "else 0)"))

(flet ((resize-vector (vector num-points initial-element)
         (let ((new (make-array num-points :initial-element initial-element)))
           (replace new vector)
           new)))
  (defun resize-tooltips (tooltips num-points)
    (declare (type tooltips tooltips))
    (with-slots (strings callouts) tooltips
      (when (< (length strings) num-points)
        (setf strings (resize-vector strings num-points nil))
        (loop :for i :from num-points :below (length callouts)
              :when (aref callouts i)
                :do (remove-annotation (aref callouts i)))
        (setf callouts (resize-vector callouts num-points nil))))
    tooltips))

(defun tooltips (artist)
  "Internal use mainly, returns the tooltips structure after resizing it to
   match the data points."
  (let ((tooltips (or (gethash artist *tooltips*)
                      (setf (gethash artist *tooltips*) (make-tooltips)))))
    (resize-tooltips tooltips (artist-num-points artist))
    tooltips))

(defun nice-tooltip-location (artist point-index)
  "Utility function, Looks at the tooltip data and decides were to place it.
   Returns (values (x1 y1) (x2 y2) horizontal-alignment vertical-alignment)
   Assumes that we're using :textcoords \"offset points\" in the callout style
   so that the text location is screen-points relative to where (x1 y1) are.

   (x1 y1) are the place the tooltip points (e.g. the data point)
   and (x2 y2) are the location of the callout center where the text is. The
   text will flow from that point base on the alignment."
  (declare (type artist artist)
           (type (or (double-float 0d0) (unsigned-byte 32)) point-index))
  (let ((x 0.0d0)
        (y 0.0d0)
        (num-points (artist-num-points artist)))
    (when (< -1 point-index num-points)
      (let ((type (python-object-type (artist-handle artist))))
        (cond ((string-equal type "<class 'matplotlib.lines.Line2D'>")
               (etypecase point-index
                 (double-float
                  (multiple-value-bind (int fractal) (truncate point-index)
                    (cond ((zerop fractal) ;; This path taken by date-time axis.
                           (setf x (pyeval (artist-handle artist) ".get_xdata()[" int "]"))
                           (setf y (pyeval (artist-handle artist) ".get_ydata()[" int "]")))
                          (t ;; This path taken by numeric axis.
                           (setf x (pyeval "(" (artist-handle artist) ".get_xdata()[" int "] * (1.0 - " fractal ")) + (" (artist-handle artist) ".get_xdata()[" (+ int 1) "] * " fractal ")"))
                           (setf y (pyeval "(" (artist-handle artist) ".get_ydata()[" int "] * (1.0 - " fractal ")) + (" (artist-handle artist) ".get_ydata()[" (+ int 1) "] * " fractal ")"))))))
                 (integer
                  (setf x (pyeval (artist-handle artist) ".get_xdata()[" point-index "]"))
                  (setf y (pyeval (artist-handle artist) ".get_ydata()[" point-index "]"))))
               (values
                (list x y)
                (list 12 12) ;; Offset in points.
                "left"
                "bottom"))
              ((string-equal type "<class 'matplotlib.image.AxesImage'>")
               (let* ((extent (pymethod (artist-handle artist) "get_extent"))
                      (xmin (aref extent 0))
                      (xmax (aref extent 1))
                      (ymin (aref extent 2))
                      (ymax (aref extent 3))
                      (array (with-remote-objects (pymethod (artist-handle artist) "get_array")))
                      (array-dim-1 (pyeval array ".shape[1]")))
                 (when (string-equal "upper" (pyslot-value (artist-handle artist) "origin"))
                   (let ((temp ymin))
                     (setf ymin ymax)
                     (setf ymax temp)))
                 (multiple-value-bind (y x) (truncate (truncate point-index) array-dim-1)
                   (values
                    (list (+ (/ 1
                                (+ 1 (- xmax xmin)))
                             (* (/ x (+ 1 (- xmax xmin))) (- xmax xmin)) xmin)
                          (+ (/ 1
                                (+ 1 (- ymax ymin)))
                             (* (/ y (+ 1 (- ymax ymin))) (- ymax ymin)) ymin))
                    (list 12 12)
                    "left"
                    "bottom"))))
              (t (values (list 0d0 0d0)
                         (list 12 12)
                         "left"
                         "bottom")))))))

(defun tooltip-visible-p (artist point-index)
  "Returns T if the tooltip is visible, nil otherwise."
  (let ((tooltips (tooltips artist)))
    (when (<= 0 point-index (- (length (tooltips-strings tooltips)) 1))
      (let ((existing (aref (tooltips-callouts tooltips) point-index)))
        (and existing
             (not (annotation-closed-p existing)))))))

(defun tooltip-defined-p (artist point-index)
  "Returns T if the tooltip is defined (it's string is not nil)."
  (let ((tooltips (tooltips artist)))
    (when (<= 0 point-index (- (length (tooltips-strings tooltips)) 1))
      (not (null (aref (tooltips-strings tooltips) point-index))))))

(defun show-tooltip (artist point-index)
  "Shows (if necessary) and returns the tooltip for the specified point-index."
  (declare (type artist artist)
           (type (unsigned-byte 32) point-index))
  (let ((tooltips (tooltips artist)))
    ;; Cap the users point to the acceptable range.
    (assert (<= 0 point-index (- (length (tooltips-strings tooltips)) 1))
            nil "Tooltip index out of range. You gave ~d, but the range is ~d to ~d (inclusive)."
            point-index
            0 (- (length (tooltips-strings tooltips)) 1))

    (let ((existing (aref (tooltips-callouts tooltips) point-index)))
      (when (or (null existing)
                (annotation-closed-p existing))
          (let ((string (aref (tooltips-strings tooltips) point-index)))
            (when string
              (assert (stringp string))
              (multiple-value-bind (xy xytext horizontal-alignment vertical-alignment)
                  (nice-tooltip-location artist point-index)
                (when (zerop (length string))
                  ;; At least one space. An empty string doesn't render
                  ;; and is very confusing.
                  (setf string " "))
                (setf existing
                      (callout (artist-axis artist) string
                               xy :artist artist :xytext xytext
                               :horizontal-alignment horizontal-alignment
                               :vertical-alignment vertical-alignment))))))
      (setf (aref (tooltips-callouts tooltips) point-index) existing)
      existing)))

(defun set-tooltip-text (artist point-index text)
  "Set a tooltips text, then redraws the tooltip. Supports setf."
  (declare (type string text))
  (declare (type artist artist))
  (declare (type (unsigned-byte 32) point-index))
  (let ((tooltips (tooltips artist)))
    (assert (<= 0 point-index (- (length (tooltips-strings tooltips)) 1))
            nil "Tooltip index out of range. You gave ~d, but the range is ~d to ~d (inclusive)."
            point-index
            0 (- (length (tooltips-strings tooltips)) 1))
    (setf (aref (tooltips-strings tooltips) point-index) text)
    (let ((existing (aref (tooltips-callouts tooltips) point-index)))
      (when existing
        (remove-annotation existing)))
    (show-tooltip artist point-index)))

(defun hide-tooltip (artist point-index)
  "Hide a specific tooltip by point-index."
  (declare (type artist artist)
           (type (unsigned-byte 32) point-index))
  (let ((tooltips (tooltips artist)))
    (when (<= 0 point-index (- (length (tooltips-callouts tooltips)) 1))
      (let ((existing (aref (tooltips-callouts tooltips) point-index)))
        (when existing
          (setf (aref (tooltips-callouts tooltips) point-index) nil)
          (remove-annotation existing))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Line Copying
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(deftype rgb-triplet () 'list)
(defstruct line-copy
  "Represents a lisp side copy of a line from matplotlib. It's used to store the line
   temporarily, for cut/copy/paste, for undo/redo, and for logged plots."
  (x-data nil :type vector :read-only t)
  (y-data nil :type vector :read-only t)
  (label nil :type string :read-only t)
  (marker nil :type string :read-only t)
  (linestyle nil :type string :read-only t)
  (linecolor nil :type (or rgb-triplet string) :read-only t)
  (linewidth nil :type double-float :read-only t)
  (markerfacecolor nil :type (or rgb-triplet string) :read-only t)
  (markeredgecolor nil :type (or rgb-triplet string) :read-only t)
  (errorbar-info nil :type list :read-only t)
  (trace-id nil :type (unsigned-byte 32) :read-only t)
  (axis-id nil :type (unsigned-byte 32) :read-only t)
  ;; Tooltips is a list of strings. It should be either empty or
  ;; have 1 string element per data point.
  (tooltips nil :type list :read-only t))

(defun make-line-copy-from-artist (artist)
  (declare (type artist artist))
  (destructuring-bind (trace-id axis-id label x-data y-data marker linestyle linewidth linecolor markerfacecolor markeredgecolor)
      (let ((handle (artist-handle artist)))
        (pyeval "("
                handle".axes.get_children().index("handle"),"
                handle".figure.get_axes().index("handle".axes),"
                handle".get_label(),"
                handle".get_xdata(),"
                handle".get_ydata(),"
                handle".get_marker(),"
                handle".get_linestyle(),"
                handle".get_linewidth(),"
                handle".get_color(),"
                handle".get_markerfacecolor(),"
                handle".get_markeredgecolor()"
                ")"))
    (let ((tooltips (coerce (tooltips-strings (tooltips artist)) 'list)))
      (make-line-copy
       :axis-id axis-id
       :trace-id trace-id
       :label label
       :x-data (undisplace-array-if-possible x-data)
       :y-data (undisplace-array-if-possible y-data)
       :marker marker
       :linestyle linestyle
       :linewidth linewidth
       :linecolor linecolor
       :markerfacecolor markerfacecolor
       :markeredgecolor markeredgecolor
       :tooltips tooltips))))

(defun redraw-trace (copied-trace &optional (ax (gca)))
  (declare (type line-copy copied-trace))
  (with-accessors ((x line-copy-x-data)
                   (y line-copy-y-data)
                   (displayname line-copy-label)
                   (marker line-copy-marker)
                   (linestyle line-copy-linestyle)
                   (linecolor line-copy-linecolor)
                   (linewidth line-copy-linewidth)
                   (markerfacecolor line-copy-markerfacecolor)
                   (markeredgecolor line-copy-markeredgecolor)
                   (errorbar-info line-copy-errorbar-info)
                   (tooltip-strings line-copy-tooltips)) copied-trace
    (if errorbar-info
        (plot-errorbar
         x (elt errorbar-info 0) (elt errorbar-info 1)
         y (elt errorbar-info 2) (elt errorbar-info 3)
         :linestyle linestyle :color linecolor :marker marker :label displayname :ax ax
         :linewidth linewidth :markerfacecolor markerfacecolor :markeredgecolor markeredgecolor)
        (multiple-value-bind (axis artists)
            (plot-xy-data
             x y :linestyle linestyle :color linecolor :marker marker :label displayname :ax ax
             :linewidth linewidth :markerfacecolor markerfacecolor :markeredgecolor markeredgecolor)
          (replace (tooltips-strings (tooltips (first artists))) tooltip-strings)
          (values axis artists)))))

(defun mpl/paste-trace-to-active-figure (copied-trace)
  (declare (type line-copy copied-trace))
  (let* ((ax (gca))
         (artist (nth-value 1 (redraw-trace copied-trace ax))))
    (push (list
           (lambda ()
             (if (pycall "isinstance" artist '|matplotlib.container.ErrorbarContainer|)
                 (pycall "PyQt6_cl_matplotlib.delete_errorbar" artist)
                 (pymethod (artist-handle (elt artist 0)) "remove"))
             (draw-axis ax))
           (lambda ()
             (setf artist (nth-value 1 (redraw-trace copied-trace ax)))))
          *undo*)))

(defun delete-artist (artist)
  "Delete a trace (e.g. an artist, a line). Supports undo and redo."
  (declare (type artist artist))
  (let* ((ax (artist-axis artist))
         (copy (make-line-copy-from-artist artist)))
    (loop :for annotation :in (artist-annotations artist)
          :do (remove-annotation annotation))
    (pymethod (artist-handle artist) "remove")
    (setf (axis-changed-p ax) t)
    (let ((temp-artist nil))
      (push (list (lambda ()
                    (setf temp-artist (nth-value 1 (redraw-trace copy ax))))
                  (lambda ()
                    (pymethod (artist-handle (elt temp-artist 0)) "remove")
                    (setf (axis-changed-p ax) t)))
          *undo*))))

(defun trace-id-artist-id-to-artist (trace-id axis-id &optional (figure *current-figure*))
  (let* ((axis-handle (elt (pymethod (figure-handle figure) "get_axes") axis-id))
         (axis (axis-from-axis-handle axis-handle figure))
         (artist-handle (pyeval axis-handle "get_children[" trace-id "]")))
    (artist-from-handle axis artist-handle)))

(defun mpl/delete-trace (trace-id axis-id &optional (figure *current-figure*))
  (delete-artist
   (trace-id-artist-id-to-artist trace-id axis-id figure)))

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
          (let ((*invisible-figure* t))
            (funcall thunk))
        (py4cl2:pycall "headless_matplotlib.closeallfigs")))))

(defun mpl/get-artist (&key (ax (gca)) (types '(|matplotlib.lines.Line2D|)))
  "Returns the latest artist of TYPE drawn on axis"
  (let ((children (pymethod (axis-handle ax) "get_children")))
    (loop for child across (reverse children)
          for matched-type = (find-if #'(lambda (type)
                                          (pycall "isinstance" child type)) types)
          until matched-type
          finally
             (assert matched-type nil "Could not find data series to label")
             (return (values (artist-from-handle ax child)
                             matched-type)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Picking points
;;
;; This code was adapted from mplcursors library; Routines to find the nearest point or line to
;; given screen coordinates (e.g. mouse location where you clicked). These routines are later used
;; to place callouts on the clicked points and lines.
;;
;; The two 'interface' functions you want are:
;;   1. compute-nearest-point (artist, screenx, screeny) => selection or nil
;;   2. compute-nearest-line (artist, screenx, screeny) => selection or nil

(defstruct selection
  "Return value of compute-nearest-line and compute-nearest-point. It holds the artist,
   the screen-x and screen-y of the selected point (or point on the line), the index of the point in
   the artist (which will lie between integers in the case of selections on line segments), the domain
   coordinates (which may have more than two dimensions) and the distance (in screen screenspace)
   from the screen-x and screen-y here and the search point."
  (artist nil :type artist :read-only t)
  ;; X, Y of where the search was triggered from
  (click-screen-x nil :type double-float :read-only t)
  (click-screen-y nil :type double-float :read-only t)

  ;; X, Y of the selected point or point on the line.
  (point-screen-x nil :type double-float :read-only t)
  (point-screen-y nil :type double-float :read-only t)

  ;; Point index number in the artist, which will be a double float if the selection is a line
  ;; projection.
  (point-index nil :type (or (and fixnum (integer 0)) double-float) :read-only t)

  ;; Coordinates of the point (or projection on the line) in the data domain.
  (domain-coordinates nil :type vector :read-only t)

  ;; Distance (in screen space) between the click and the selection point.
  (distance nil :type double-float :read-only t))

(defun points-visible-p (artist)
  "Returns T if the artist is drawing visible points"
  (not (member (ignore-errors (pymethod artist "get_marker")) '("None" "none" " " "" nil) :test #'equalp)))

(defun lines-visible-p (artist)
  "Returns T if the artist is drawing visible lines."
  (not (member (ignore-errors (pymethod artist "get_linestyle")) '("None" "none" " " "" nil) :test #'equalp)))

(defun image-visible-p (artist)
  "Returns T if the artist is drawing visible images."
  (declare (ignore artist))
  t)

(defun untransform (orig-xy screen-xy axis)
  "Return data coordinates to place an annotation at screen coordinates
   *screen_xy* in axes *ax*.

   orig_xy are the original coordinates as stored by the artist; they are
   transformed to screen_xy by whatever transform the artist uses.

   If the artist uses ``ax.transData``, just return orig_xy, otherwise apply
   ``ax.transData.inverse()`` to *screen_xy*.  (The first case is more
   accurate than always applying ``ax.transData.inverse()``."
  (with-remote-objects*
    (let* ((tr-xy (pymethod axis "transData.transform" orig-xy))
           (invalid-p (pyeval "((" tr-xy " == " screen-xy ") | numpy.isnan(" tr-xy ") & numpy.isnan(" screen-xy ")).all()")))
      (if invalid-p
          orig-xy
          (pymethod axis "transData.inverted().transform" screen-xy)))))

(defun compute-nearest-point/line2D (axis artist screen-x screen-y)
  (let* ((xy (with-remote-objects (pyeval screen-x ", " screen-y)))
         (data-xy (with-remote-objects (pymethod artist "get_xydata")))
         (data-screen-xy (with-remote-objects (pymethod artist "get_transform().transform" data-xy))))
    (let* ((ds (with-remote-objects (pyeval "numpy.hypot(*(" xy " - " data-screen-xy ").T)")))
           (min (pyeval "numpy.nanargmin( " ds ")"))
           (domain-coordinates
             (untransform (pyeval data-xy "[" min "]")
                          (pyeval data-screen-xy "[" min "]")
                          (pyslot-value artist "axes"))))
      (make-selection
       :artist (artist-from-handle axis artist)
       :click-screen-x screen-x
       :click-screen-y screen-y
       :point-screen-x (pyeval data-screen-xy "[ "min" ][0]")
       :point-screen-y (pyeval data-screen-xy "[ "min" ][1]")
       :point-index min
       :domain-coordinates domain-coordinates
       :distance (pyeval ds "[" min "]")))))

(defun compute-nearest-point (axis artist screen-x screen-y)
  "Returns a selection object, nearest point to x y screen coordinates. Note
   that this routine doesn't care about point visibility.  If you don't want to be able to click
   on invisible points, guard this with points-visible-p."
  (declare (type python-object artist)
           (type double-float screen-x screen-y))
  (let ((type (python-object-type artist)))
    (cond ((string-equal type "<class 'matplotlib.lines.Line2D'>")
           (compute-nearest-point/line2D axis artist screen-x screen-y))
          ((string-equal type "<class 'matplotlib.image.AxesImage'>")
           ;; AxesImage doesn't have points.
           nil)
          (t (warn "compute-nearest-point not implemented for ~s" type)
             nil))))

(defun compute-projection-pick (axis artist path screen-x screen-y)
  "Project screen-x and screen-y onto path to obtain a selection for the artist.

   Path is first transformed to screet coordinates using the artist
   transform, and the target of the returned `Selection` is transformed
   back to data coordinates using the artist *axes* inverse transform.  The
   `Selection` `index` is returned as a float.  This function returns ``None``
   for degenerate inputs.

   The caller is responsible for converting the index to the proper class if
   needed."
  (declare (optimize debug))
  (let* ((xy (with-remote-objects (pyeval "[" screen-x ", " screen-y "]")))
         (transform (with-remote-objects (pymethod artist "get_transform().frozen")))
         (tpath ;; cleaned only handles affine transformations.
           (with-remote-objects
             (pyeval "(" path ".cleaned(" transform ") if " transform ".is_affine else " transform ".transform_path(" path ").cleaned())")))
         ;;  `cleaned` should return a path where the first element is `MOVETO`, the
         ;;  following are `LINETO` or `CLOSEPOLY`, and the last one is `STOP`, i.e.
         ;;      codes = path.codes
         ;;      assert (codes[0], codes[-1]) == (path.MOVETO, path.STOP)
         ;;      assert numpy.isin(codes[1:-1], [path.LINETO, path.CLOSEPOLY]).all()
         (vertices (with-remote-objects (pyeval tpath ".vertices[:-1]")))
         (codes (with-remote-objects (pyeval tpath ".codes[:-1]")))
         (mt_idxs (with-remote-objects (pyeval "(" codes " == " tpath ".MOVETO).nonzero()[0]")))
         (cp_idxs (with-remote-objects (pyeval "(" codes " == " tpath ".CLOSEPOLY).nonzero()[0]"))))

    ;; For a close poly command, update the vertices to be the prior vertex?
    (pyexec vertices "[ " cp_idxs "] = " vertices "[ " mt_idxs "[ " mt_idxs ".searchsorted("cp_idxs") - 1]]")

    (let* (;; Unit vectors for each segment.
           (us (with-remote-objects (pyeval vertices "[1:] - "vertices "[:-1]")))
           (ls (with-remote-objects (pyeval "numpy.hypot(*" us ".T)"))))
      ;; Results in 0/0 for repeated consecutive points.
      (pyexec (format nil "with numpy.errstate(invalid=\"ignore\"):~%   ")
              us "/= " ls "[:, None]")

      ;; Vectors from each vertex to the event
      (let (;; Vectors from each vertex to the event.
            (vs (with-remote-objects (pyeval xy " - " vertices "[:-1]")))
            (dot (with-remote-objects (pyeval 0))))

        ;; Clipped dot products -- `einsum` cannot be done in place, `clip` can.
        ;; `clip` can trigger invalid comparisons if there are nan points.
        (pyexec (format nil "with numpy.errstate(invalid=\"ignore\"):~%   ")
                dot " = numpy.clip(numpy.einsum(\"ij,ij->i\", " vs ", " us "), 0, " ls ")")

        (let* (;; Projections.
               (projs (with-remote-objects (pyeval vertices "[:-1] + " dot "[:, None] * " us)))
               (ds (with-remote-objects (pyeval "numpy.hypot(*( " xy " - " projs ").T)"))))
          (pyexec ds "["mt_idxs"[1:] - 1] = numpy.nan")

          (let* ((argmin (pyeval "numpy.nanargmin(" ds ")"))
                 ;; Python error: Input values must have shape (N, 2) or (2,)
                 (domain-coordinates (pyeval artist ".axes.transData.inverted().transform(" projs "[" argmin "])"))
                 (index (pyeval "((" argmin " + " dot "[" argmin "] / " ls "[" argmin "]) / (" path "._interpolation_steps / " tpath "._interpolation_steps))")))
            (make-selection
             :artist (artist-from-handle axis artist)
             :click-screen-x screen-x
             :click-screen-y screen-y
             :point-screen-x (pyeval projs "[ "argmin" ][0]")
             :point-screen-y (pyeval projs "[ "argmin" ][1]")
             :point-index index
             :domain-coordinates domain-coordinates
             :distance (pyeval ds "[" argmin "]"))))))))

(defun compute-nearest-line (axis artist x-screen y-screen)
  "Returns a selection object (or nil). The selection is the projection onto the nearest line to x y
   screen coordinates. Note that this routine doesn't care about line visibility.  If you don't want
   to be able to click on invisible lines, guard this with lines-visible-p."
  (declare (type python-object artist)
           (type double-float x-screen y-screen))
  (let ((type (python-object-type artist)))
    (cond ((string-equal type "<class 'matplotlib.lines.Line2D'>")
           (compute-projection-pick axis artist (with-remote-objects (pymethod artist "get_path")) x-screen y-screen))
          ((string-equal type "<class 'matplotlib.image.AxesImage'>")
           ;; AxesImage doesn't have any lines.
           nil)
          (t (warn "compute-nearest-line not implemented for ~s" type)
             nil))))

(defun compute-pixel-pick (axis artist screen-x screen-y)
  "Project screen-x and screen-y onto the artist (which should be an AxesImage)
   to obtain a selection for the artist.

   The `Selection` `index` is returned as a integer."
  (declare (optimize debug))

  (let* ((extent (pymethod artist "get_extent"))
         (xmin (aref extent 0))
         (xmax (aref extent 1))
         (ymin (aref extent 2))
         (ymax (aref extent 3)))
    (when (string-equal "upper" (pyslot-value artist "origin"))
      (let ((temp ymin))
        (setf ymin ymax)
        (setf ymax temp)))

    (let* ((array (with-remote-objects (pymethod artist "get_array")))
           (array-dim-0 (pyeval array ".shape[0]"))
           (array-dim-1 (pyeval array ".shape[1]"))
           (data-extent (with-remote-objects (pyeval "matplotlib.transforms.Bbox([[" xmin ", " ymin "], [" xmax ", " ymax "]])")))
           (array-extent (with-remote-objects (pyeval "matplotlib.transforms.Bbox([[ 0, 0], [" array-dim-1", " array-dim-0 "]])")))
           (trans (with-remote-objects (pyeval artist ".get_transform().inverted()")))
           (trans (with-remote-objects (pyeval trans " + matplotlib.transforms.BboxTransform(boxin=" data-extent ", boxout=" array-extent")")))
           (point (pymethod trans "transform" (list screen-x screen-y)))
           (i (aref point 0))
           (j (aref point 1))
           (valid-p (and (not (null i))
                         (< -1 i array-dim-1)
                         (not (null j))
                         (< -1 j array-dim-0))))
      (when valid-p
        (setf i (truncate i))
        (setf j (truncate j))
        (when (< i 0)
          (setf i 0))
        (when (>= i array-dim-1)
          (setf i (- array-dim-1 1)))
        (when (< j 0)
          (setf j 0))
        (when (>= j array-dim-0)
          (setf j (- array-dim-0 1)))
        (let* ((value (pyeval array "[" j ", " i "]"))
               (trans (with-remote-objects (pyeval trans ".inverted()")))
               ;; The added 0.5 make it so you click the CENTER of the colors.
               (point-screen (pymethod trans "transform" (list (+ i 0.5) (+ j 0.5))))
               (point-screen-x (aref point-screen 0))
               (point-screen-y (aref point-screen 1))
               (distance (let ((delta-x (- screen-x point-screen-x))
                               (delta-y (- screen-y point-screen-y)))
                           (sqrt (+ (* delta-x delta-x) (* delta-y delta-y))))))
          (make-selection
           :artist (artist-from-handle axis artist)
           :click-screen-x screen-x
           :click-screen-y screen-y
           :point-screen-x point-screen-x
           :point-screen-y point-screen-y
           :point-index (+ i (* array-dim-1 j))
           :domain-coordinates (vector (+ i xmin) (+ j ymin) value)
           :distance distance))))))

(defun compute-nearest-pixel (axis artist x-screen y-screen)
  "Returns a selection object (or nil). The selection is the projection onto the nearest image to x y
   screen coordinates. Note that this routine doesn't care about image visibility.  If you don't want
   to be able to click on invisible images, guard this with image-visible-p."
  (declare (type python-object artist)
           (type double-float x-screen y-screen))
  (let ((type (python-object-type artist)))
    (cond ((string-equal type "<class 'matplotlib.image.AxesImage'>")
           (compute-pixel-pick axis artist x-screen y-screen))
          ((string-equal type "<class 'matplotlib.lines.Line2D'>")
           ;; Line2D doesn't have images.
           nil)
          (t (warn "compute-nearest-pixel not implemented for ~s" type)
             nil))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Data Cursors
;;
;; Data cursors are callouts associated with a line, but they're not user specified like tooltips.
;; They're dynamically created and point to a position on the line (and not necessarily a point on
;; the line). They're used to get the exact coordinates from a plot.
;;
;; Because they're not limited to points, their their point-indexes are not whole numbers like they
;; are for tooltips; The point-index 0.5 is exactly halfway between the first and second point on
;; the line.  1.5 is halfway between the second and third point on the line, and so on.

(defvar *data-cursors* (make-hash-table :weakness :key)
  "A weakly keyed hashtable of artist -> list of (cons point-index annotation), kept sorted by point index.")

(defun data-cursor-near (artist point-index &key (tol 0.1d0))
  "Find a data cursor within tol of the specified point-index."
  (loop :with best-data-cursor = nil
        :with smallest-distance = 1d20
        :for prior-distance = 1d20 :then dist
        :for ((idx . data-cursor) . rest) :on (gethash artist *data-cursors*)
        :for dist = (abs (- idx point-index))
        :do (when (and (< dist smallest-distance)
                       (not (annotation-closed-p data-cursor)))
              (setf smallest-distance dist)
              (setf best-data-cursor data-cursor))
        ;; Since the data is sorted, once distances start becoming greater we can stop.
        :until (and (> dist prior-distance)
                    (not (annotation-closed-p data-cursor)))
        :finally (when (< smallest-distance tol)
                   (return-from data-cursor-near best-data-cursor))))


(defun coordinates-from-point-index (artist point-index)
  (declare (type (or fixnum double-float) point-index)
           (type artist artist))
  (let ((num-points (artist-num-points artist)))
    (when (< -1 point-index num-points)
      (let ((x 0d0)
            (y 0d0)
            (type (python-object-type (artist-handle artist))))
        (cond ((string-equal type "<class 'matplotlib.lines.Line2D'>")
               (multiple-value-bind (int fractal) (truncate point-index)
                 (cond ((zerop fractal) ;; This path taken by date-time axis.
                        (setf x (pyeval "(" (artist-handle artist) ".get_xdata()[" int "])"))
                        (setf y (pyeval "(" (artist-handle artist) ".get_ydata()[" int "])")))
                       (t ;; This path taken by numeric axis.
                        (setf x (pyeval "(" (artist-handle artist) ".get_xdata()[" int "] * (1.0 - " fractal ")) + (" (artist-handle artist) ".get_xdata()[" (+ int 1) "] * " fractal ")"))
                        (setf y (pyeval "(" (artist-handle artist) ".get_ydata()[" int "] * (1.0 - " fractal ")) + (" (artist-handle artist) ".get_ydata()[" (+ int 1) "] * " fractal ")")))))
               (list x y))
              ((string-equal type "<class 'matplotlib.image.AxesImage'>")
               (let* ((data (pyeval "numpy.asarray("(artist-handle artist)".get_array())"))
                      (extent (pymethod (artist-handle artist) "get_extent"))
                      (xmin (aref extent 0))
                      ;;(xmax (aref extent 1))
                      (ymin (aref extent 2))
                      ;;(ymax (aref extent 3))
                      (array-dim-1 (array-dimension data 1)))
                 (multiple-value-bind (y x) (truncate (truncate point-index) array-dim-1)
                   (list (+ x xmin) (+ y ymin) (aref data y x)))))
              (t nil))))))

(defun place-data-cursor (artist point-index &optional text)
  "Put a data-cursor on the artist at the given point-index with the provided text."
  (declare (type (or null string) text))
  (declare (type artist artist))
  (declare (type double-float point-index))

  (when (null text)
    ;; Compute a selection so that we can build the data-cursor value.
    (let ((coords (coordinates-from-point-index artist point-index)))
      (cond (coords
             (ecase (length coords)
               (3 (setf text (format nil "X: ~f~%Y: ~f~%Z: ~f" (first coords) (second coords) (third coords))))
               (2 (setf text (format nil "X: ~f~%Y: ~f" (first coords) (second coords))))))
            (t
             (setf text "Couldn't compute coords?")))))

  (when (and (stringp text) (zerop (length text)))
    ;; Ensure text isn't totally empty. An empty string doesn't render and is very confusing.
    (setf text " "))

  (multiple-value-bind (xy xytext horizontal-alignment vertical-alignment)
      (nice-tooltip-location artist point-index)
    (setf (gethash artist *data-cursors*)
          (sort
           (acons point-index
                  (callout (artist-axis artist) text
                           xy :artist artist :xytext xytext
                           :horizontal-alignment horizontal-alignment
                           :vertical-alignment vertical-alignment)
                  (remove-if #'annotation-closed-p
                             (gethash artist *data-cursors*)
                             :key #'cdr))
           #'< :key #'car))))

(defun hide-data-cursor (artist data-cursor)
  (setf (gethash artist *data-cursors*)
        (sort
         (remove data-cursor (gethash artist *data-cursors*) :key #'cdr)
         #'< :key #'car))
  (remove-annotation data-cursor))

(defun hide-data-cursors (artist &optional (after-index-inclusive 0) before-index-exclusive)
  "Hide a specific tooltip by point-index."
  (declare (type artist artist)
           (type (or (unsigned-byte 32) double-float) after-index-inclusive)
           (type (or (unsigned-byte 32) double-float null) before-index-exclusive))
  (loop :for item :in (gethash artist *data-cursors*)
        :for (point-index . data-cursor) = item
        :if (or (and (>= point-index after-index-inclusive)
                     (or (null before-index-exclusive)
                         (< point-index before-index-exclusive)))
                (annotation-closed-p data-cursor))
          :do (remove-annotation data-cursor)
        :else
          :collect item :into remaining-items
        :finally (setf (gethash artist *data-cursors*) remaining-items)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Interactivity Handling
;;
;; We want users to be able to open and close, move and resize, legends and tooltips, etc.  To build
;; this out, Matplotlib gives us events. We have mouse events, keyboard events, etc.  You can
;; register handlers for these events on individual elements.
;;
;; But that's weak sauce. For example, if you only used those handlers you'd "click through"
;; everything.  Second, when you click and drag, your starting click will trigger on-click logic
;; that you don't want.  Third, there is no central state tracking, so every element is repeating
;; similar logic and there is no hope of resolving conflicts (did you mean to select the tooltip, or
;; click the close button of the legend just above it?). Finally, to show the modified item in it's
;; new location you'd need to call redraw and that usually takes > 1 second.
;;
;; So, we build something more suitable here to support richer interactivity. Interaction both
;; interprets the low level events which are injected into the queue by python callbacks, and also
;; provide useful visual feedback at a high frame rate.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defstruct interaction-event
  "Interaction events are lisp equivalents of python events. Note that the time is
   as-recorded-by-python and is not the same as get-internal-real-time, even though
   they're all mapped to INTERNAL-TIME-UNITS. So don't compare python times to lisp
   times.

   Why do we use the python times? We want to get as close to the actual event time as possible.  So
   having python attach a timestamp when it sees the event is the most accurate we can be, and
   noticably more accurate than waiting for the lisp interaction loop (which runs at 20hz) to handle
   the event and attach a timestamp."
  (time (error "This time should be provided by Python") :type fixnum :read-only t)
  (screen-x nil :type double-float :read-only t)
  (screen-y nil :type double-float :read-only t))

(defstruct (motion (:include interaction-event))
  "Records a mouse position.")

(defstruct (axis-enter (:include interaction-event))
  (axis nil :type axis :read-only t))

(defconstant +shift-modifier+ 0)
(defconstant +ctrl-modifier+ 1)
(defconstant +alt-modifier+ 2)
(defconstant +number-of-modifiers+ 3)
(deftype modifiers () `(simple-array bit (,+number-of-modifiers+)))
(defun make-modifiers () (make-array +number-of-modifiers+ :element-type 'bit :initial-element 0))

(defstruct (mbutton (:include motion))
  (axis nil :type axis :read-only t)
  (button :left :type (member :left :middle :right) :read-only t)
  (modifiers (make-modifiers) :type modifiers :read-only t))

(defstruct (click (:include mbutton))
  "Records a single mouse click. When, where and what modifiers.")

(defstruct (release (:include mbutton))
  "Records a single mouse release. When, where and what modifiers.")

(deftype key () '(member :delete :backspace :escape :left :right :up :down
                  :home :pageup :pagedown :end :insert :enter
                  :control :alt :shift
                  :tab :pause
                  :f1 :f2 :f3 :f4 :f5 :f6 :f7 :f8 :f9 :f10 :f11 :f12
                  :a :b :c :d :e :f :g :h :i :j :k :l :m
                  :n :o :p :q :r :s :t :u :v :w :x :y :z
                  :/
                  :*
                  :-
                  :+
                  :. :0 :1 :2 :3 :4 :5 :6 :7 :8 :9
                  :|\\| :$ :@ :/))
(defstruct (key-event (:include interaction-event))
  "Records a key press or release. We don't care about X/Y locations for these."
  (key nil :type key :read-only t)
  (modifiers (make-modifiers) :type modifiers :read-only t))

(defstruct (key-press (:include key-event))
  "A key is pressed.")

(defstruct (key-release (:include key-event))
  "A key is released.")

(defconstant +interaction-idle-event-period-internal-units+
  (truncate (* (/ 1.0 20.0) #| seconds |# INTERNAL-TIME-UNITS-PER-SECOND ))
  "How long between handling idle interaction logic. We want to process this at
   a high rate so that we can animate the user interface, but over VNC we're probably
   not going to get more than 20 fps anyway.")

(defstruct interaction
  "Interaction is the top-level object for plotting.  It handles queues of events, storing animation
   states, selected objects etc.

   Another important thing it does is the book keeping for UI interactivity; things like determining
   the users intent (is it a click? a click and drag? Are they trying to pan the screen or move an
   annotation?). Once the activity is decided, it must be animated to provide visual feedback to the
   user.

   The basic flow is:

     Python Input Events --->  Lisp Callbacks -+                   Python events trigger lisp callbacks
                                               |                   that turn the python events into
               +-------------------+           | (atomic push)     click, release, etc structures
               |   *interation*    |           |                   and atomically push them onto
               +-------------------+           |                   the event queue.
    +--------- | 1. event-quueue   | <---------+
    |          |                   |
  - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                  *INTERACTION THREAD*                             Meanwhile, the ever looping interaction
  - - - - - - - - - - - - - - - - - - - - - - - - - - - - -        thread takes that queue and maintains
    |          |                   |                               summary variables.
    +---+----> | 2. input summary  | ---+
        |      |    prior-click    |    |
        +--->  |    click          | ---+
        |      |    release        |    |
        +--->  |    screen x y     | ---+------+
               |                   |           |
               |                   |       (@30 hz)                        Less frequently (15hz), the
               |                   |           |                           interaction loop deduces from the
               |                   |      Interpret input                  summary variables clicks, dblclicks,
               |                   |       summary                         drags, etc, and acts on them by
               |                   |           |                           updating itself.
               |                   |      Dispatch -----> double-click
               |                   |           |          or long click
               |                   |           |          or single click
               |                   |           |          or drag start
               |                   |           |          or drag end
               | 3. state variable |           |                |
               |                   | <----->+<-|----read/write->+
               |                   |        |  |      state
               |                   | <----->+  |
               |                   |        |  +---> +----------------+    Finally, and also at 15hz, the
               |                   | <----->+------> |    Animate     |    interaction thread draws to the
               |                   |                 +----------------+    screen to communicate what is
               +-------------------+                                       occurring."
  ;; 0. This structure has a thread which handles the processing of it.
  (done-p nil :type boolean :read-only nil)
  (thread nil :type (or null sb-thread:thread) :read-only nil) ;; runs interaction-loop til done-p = true.
  (image-cache (make-hash-table :weakness :key :synchronized t) :type hash-table :read-only t) ;; this slot, multithread read/write safe.

  ;; 1. Python callbacks put events (motion, click and release) onto this queue
  (event-queue nil :type list :read-only nil)
  (stay-awake-end-time 0 :type fixnum :read-only nil) ;; The system will busy-wait rather than block up to this time. Each event/animation pushes this time later.

  ;; This mutex and waitqueue implement a sort of "side channel" for sleeping the system until an
  ;; event comes.  It's not a rigorous thread safe thing; events are NOT protected in a manner that
  ;; guarentees no losses or anything like that.  But it works well in practice because events are
  ;; "spammy" when the come.  see comments on interaction-blocking-wait-for-events
  (event-queue-mutex (sb-thread:make-mutex :name "interaction mutex") :type sb-thread:mutex :read-only t)
  (event-queue-waitqueue (sb-thread:make-waitqueue :name "interaction waitqueue") :type sb-thread:waitqueue :read-only t)  

  ;; 2. Those queued events are summarized in these slots. We record the last two clicks
  ;; and the last release event in order to distinguish double-clicks and single clicks.
  ;; We also know the last mouse location and if we seem to be dragging and dropping.
  (prior-click nil :type (or null click) :read-only nil)
  (click nil :type (or null click) :read-only nil)
  (click-lisp-time 0 :type fixnum :read-only nil) ;; the time we saw the click, Lisp side. We can't directly compare python and lisp timestamps, so we need this extra one.
  (release nil :type (or null release) :read-only nil)
  (dragging-p nil :type boolean :read-only nil)
  (screen-x 0d0 :type double-float :read-only nil) ;; last known screenx and screeny
  (screen-y 0d0 :type double-float :read-only nil)
  (released-keys nil :type list :read-only nil)

  ;; 3. Knowing the last time we processed allows us to cap drawing and event firing logic to 30
  ;; times per second.  The slots of step 2 are interpreted to distinguish and dispatch
  ;; double-click, click, long click, start-of-drag, completion-of-drag.
  (last-idle-process-time 0 :type fixnum :read-only nil)
  (animation-queue nil :type list :read-only nil)

  ;; The marked object is set when the mouse clicks. Stored so that the mouse action
  ;; callbacks can make use of this information
  (mark-screen-x 0d0 :type double-float :read-only nil)
  (mark-screen-y 0d0 :type double-float :read-only nil)
  (mark-item nil :type t :read-only nil)

  (selected-annotations nil :type list :read-only nil)
  (selected-lines nil :type list :read-only nil)
  (hover-axis nil :type (or null axis) :read-only nil)
  (current-hover nil :type t :read-only nil)
  (previous-hover nil :type t :read-only nil)

  (mode-change-start-screen-x 0d0 :type double-float :read-only nil)
  (mode-change-start-screen-y 0d0 :type double-float :read-only nil)
  (mode :normal :read-only nil
   :type (member :normal :drag-and-drop :selection-rectangle :pan :zoom-to-rectangle)))

(defconstant +double-click-time-internal-time-units+
  (truncate (* 0.22d0 #| seconds |# INTERNAL-TIME-UNITS-PER-SECOND ))
  "The maximum amount of time, in INTERNAL-TIME-UNITS, between first clicks and final release for a
   double click.")

(defconstant +long-click-time-internal-time-units+
  (truncate (* 0.85d0 #| seconds |# INTERNAL-TIME-UNITS-PER-SECOND ))
  "The amount of time, in INTERNAL-TIME-UNITS, between click and release for a long click.")

(defconstant +click-maximum-screen-pixel-distance-squared+
  (coerce (+ (* 4 4) (* 4 4)) 'double-float)
  "The amount of distance the mouse can travel between click and release and still
   be treated as a click or double click (and not a click and drag).  Most people can double click
   without the mouse moving at all.")

(defun interaction/stay-awake (interaction minimum-time)
  (tagbody :retry
     (let* ((time (interaction-stay-awake-end-time interaction))
            (nv (max time minimum-time)))
       (unless (eq time (sb-ext:compare-and-swap (interaction-stay-awake-end-time interaction) time nv))
         (go :retry)))))

(defun interaction/queue-event (interaction event)
  "Thread-safely notify the interaction structure about the event, waking it if necessary."
  (declare (type interaction-event event)
           (type interaction interaction))
  (let ((now (get-internal-real-time)))
    ;; Note: that events are atomically pushed to the queue, NOT USING the
    ;; mutex/waitqueue at all. This is by design. See note on interaction-blocking-wait-for-events
    (sb-ext:atomic-push event (interaction-event-queue interaction))
    (interaction/stay-awake interaction (+ now INTERNAL-TIME-UNITS-PER-SECOND))

    ;; If the system seemed to be asleep, send a wake up message. But see
    ;; comment on interaction-blocking-wait-for-events
    (when (< now (interaction-stay-awake-end-time interaction))
      (sb-thread:with-mutex ((interaction-event-queue-mutex interaction))
        (sb-thread:condition-notify (interaction-event-queue-waitqueue interaction))))
    event))

(defun interaction-blocking-wait-for-events (interaction)
  "Block until something calls interaction/queue-event.

   This IS NOT protecting the event queue slot and is just a side mechanism for sleeping the
   interaction loop and re-awakening it when events start coming again.  No guarentees about events
   delivery, events not being missed, or the wake up signal coming exactly when you'd expect. But
   since events tend to be spammy (every mouse movement is an event) it so far works well in
   practice.

   Conversely, using the waitqueue/mutex properly (e.g. to protect the event queue) seemed to really
   delay the system. I suspect because python callbacks would end up waiting for Lisp threads, and
   the system chugged (e.g. mouse events wouldn't register immediately, they'd come in a burst after
   about 5 seconds, followed by another 5 second wait)."
  (declare (type interaction interaction))
  (let ((mutex (interaction-event-queue-mutex interaction))
        (waitqueue (interaction-event-queue-waitqueue interaction)))
    (sb-thread:with-mutex (mutex)
      (sb-thread:condition-wait waitqueue mutex))))

(deftype animate-goal ()
  "The set of ends that an animation can push an interactable element towards."
  '(member :closed :opened
    :unselected :selected
    :unhovered :hovered
    :unraised :raised))

(defconstant +animation-time-internal-time-units+
  (truncate (* 0.250d0 #| seconds |# INTERNAL-TIME-UNITS-PER-SECOND ))
  "The maximum amount of time over which a state change animation occurs (e.g. goes from 0.0 to
   1.0). We use a fairly slow rate because our FPS over VNC isn't that high.")

(defstruct (animate (:constructor ANIMATE))
  "Animates are stored in the interaction-animation-queue. They're just a record of
   what thing is animating towards what state.  The callback is invoked when the animation
   is finished. These callbacks are called by the interaction loop thread, so it's safe for
   them to modify any interaction state variables."
  (started (get-internal-real-time) :type fixnum :read-only t)
  (towards :open :type animate-goal :read-only t)
  (annotation-weak-pointer nil :type sb-ext:weak-pointer :read-only t)
  ;; The callback is called when the animation finishes.
  (callback nil :type (or null function) :read-only t))

(defun interaction/queue-animation (interaction animation)
  "Thread-safely notify the interaction structure about the animation, waking it if necessary."
  (declare (type animate animation)
           (type interaction interaction))
  ;; Push the stay-awake time safely out past the animation run time.
  (interaction/stay-awake interaction (+ (animate-started animation)
                                         +animation-time-internal-time-units+
                                         +animation-time-internal-time-units+))
  (sb-ext:atomic-push animation (interaction-animation-queue interaction)))

(declaim (type interaction *interaction*))
(defparameter *interaction* (make-interaction)
  "Current user interaction state. Global singleton, updated in place by callbacks (installed
   on matplotlib) triggering state-machine transitions on this structure..")

(defun stop-interaction-thread (&optional (interaction *interaction*))
  "Stop the interactivity thread on the interaction object."
  (setf (interaction-done-p interaction) t))

(defun start-interaction-thread (&optional (interaction *interaction*))
  "Start the interactivity thread on the interaction object."
  (setf (interaction-done-p interaction) nil)
  (when (or (not (interaction-thread interaction))
            (not (sb-thread:thread-alive-p (interaction-thread interaction))))
    ;; Reset the interaction object before starting work upon it.
    (setf (interaction-event-queue interaction) nil)
    (setf (interaction-last-idle-process-time interaction) 0)
    (setf (interaction-prior-click interaction) nil)
    (setf (interaction-click interaction) nil)
    (setf (interaction-click-lisp-time interaction) 0)
    (setf (interaction-thread interaction)
          (sb-thread:make-thread
           'interaction-loop
           :name "cl-matplotlib interaction"
           :arguments (list interaction *standard-output*))))
  interaction)

;; Below here are interaction callbacks that are called by matplotlib and modify the global
;; *interaction* object.  This same set of callbacks is registered on every figure, and they all
;; modify the same global *interaction* object (but only it's event-queue slot and in a thread safe
;; way!).  Using the same set of callbacks everywhere is fine, since you only have one mouse cursor
;; anyway so you can only interact with one figure at a time.

(defun pyevent-axes (location-event)
  "When a matplotlib python event derives from LocationEvent (and most do), they contain the relevant
   axes that generated the event. This routine finds the association lisp axes object for the event,
   or nil if it couldn't be determined."
  (let* ((figure-number (ignore-errors (pyeval location-event ".inaxes.figure.dockwidget.unique_figure_id")))
         (figure (and figure-number (get-figure figure-number)))
         (axis (and figure (axis-from-axis-handle (pyslot-value location-event "inaxes") figure))))
    axis))

(defun pyevent-mouse-button (py-mouse-event)
  "Returns nil (if not determinable), :left, :middle, or :right."
  (let ((string (ignore-errors (pyslot-value py-mouse-event "button.name"))))
    (cond ((null string) nil)
          ((string-equal string "LEFT") :left)
          ((string-equal string "MIDDLE") :middle)
          ((string-equal string "RIGHT") :right))))

(defun pyevent-modifiers (py-event)
  (let ((provided-modifiers (pyeval "['shift' in " py-event ".modifiers, 'ctrl' in " py-event ".modifiers, 'alt' in " py-event ".modifiers]"))
        (modifiers (make-modifiers)))
    (setf (sbit modifiers +shift-modifier+) (if (elt provided-modifiers 0) 1 0))
    (setf (sbit modifiers +ctrl-modifier+) (if (elt provided-modifiers 1) 1 0))
    (setf (sbit modifiers +alt-modifier+) (if (elt provided-modifiers 2) 1 0))
    modifiers))

(defun pyevent-key (py-event)
  (let ((key (pyslot-value py-event "key"))
        (modifiers (make-modifiers))
        (len nil)
        (offset 0))
    (unless (stringp key)
      (return-from pyevent-key (values nil modifiers)))

    (setf len (length key))
    (when (string= key "ctrl+" :start1 offset :end1 (min len (+ offset 5)))
      (setf (sbit modifiers +ctrl-modifier+) 1)
      (incf offset 5))
    (when (string= key "alt+" :start1 offset :end1 (min len (+ offset 4)))
      (setf (sbit modifiers +alt-modifier+) 1)
      (incf offset 4))
    (when (string= key "shift+" :start1 offset :end1 (min len (+ offset 6)))
      (setf (sbit modifiers +shift-modifier+) 1)
      (incf offset 6))

    ;; Now map the key string to a symbol. We're probably missing many
    ;; entries here.
    (macrolet ((is (s) `(string= key ,s :start1 offset))
               (shift () '(setf (sbit modifiers +shift-modifier+) 1)))
      (values
       ;; Order these clauses by likelyhood of occurring.
       (cond
         ((is "backspace") :backspace)
         ((is "delete") :delete)
         ((is "enter") :enter)
         ((is "escape") :escape)
         ((is "home") :home)     ((is "end") :end)
         ((is "pageup") :pageup) ((is "pagedown") :pagedown)

         ((is "control") :control)
         ((is "alt") :alt)
         ((is "shift") :shift)

         ((is "up") :up) ((is "down") :down)
         ((is "left") :left) ((is "right") :right)

         ((is "f1")       :f1) ((is "f2")       :f2) ((is "f3")       :f3)
         ((is "f4")       :f4) ((is "f5")       :f5) ((is "f6")       :f6)
         ((is "f7")       :f7) ((is "f8")       :f8) ((is "f9")       :f9)
         ((is "f10")     :f10) ((is "f11")     :f11) ((is "f12")     :f12)

         ((is "1")         :1) ((is "2")         :2) ((is "3")         :3)
         ((is "4")         :4) ((is "5")         :5) ((is "6")         :6)
         ((is "7")         :7) ((is "8")         :8) ((is "9")         :9)

         ((is "A") (shift) :a) ((is "B") (shift) :b) ((is "C") (shift) :c)
         ((is "a")         :a) ((is "b")         :b) ((is "c")         :c)
         ((is "D") (shift) :d) ((is "E") (shift) :e) ((is "F") (shift) :f)
         ((is "d")         :d) ((is "e")         :e) ((is "f")         :f)
         ((is "G") (shift) :g) ((is "H") (shift) :h) ((is "I") (shift) :i)
         ((is "g")         :g) ((is "h")         :h) ((is "i")         :i)
         ((is "J") (shift) :j) ((is "K") (shift) :k) ((is "L") (shift) :l)
         ((is "j")         :j) ((is "k")         :k) ((is "l")         :l)
         ((is "M") (shift) :m) ((is "N") (shift) :n) ((is "O") (shift) :o)
         ((is "m")         :m) ((is "n")         :n) ((is "o")         :o)
         ((is "P") (shift) :p) ((is "Q") (shift) :q) ((is "R") (shift) :r)
         ((is "p")         :p) ((is "q")         :q) ((is "r")         :r)
         ((is "S") (shift) :s) ((is "T") (shift) :t) ((is "U") (shift) :u)
         ((is "s")         :s) ((is "t")         :t) ((is "u")         :u)
         ((is "V") (shift) :v) ((is "W") (shift) :w) ((is "X") (shift) :x)
         ((is "v")         :v) ((is "w")         :w) ((is "x")         :x)
         ((is "Y") (shift) :y) ((is "Z") (shift) :z)
         ((is "y")         :y) ((is "z")         :z)

         ;; Otherwise...
         (t nil))
       modifiers))))

(defun interact/button-press (time py-event)
  "Interaction handler for mouse button presses. Callback called by matplotlib"
  (when (not (interaction-done-p *interaction*))
    (let ((axis (pyevent-axes py-event)))
      (when axis
        (let ((x (pyslot-value py-event "x"))
              (y (pyslot-value py-event "y"))
              (button (or (pyevent-mouse-button py-event)
                          :left)))
          ;; We prefer not to lose release events, because things will feel
          ;; non-responsive if we do. Therefore if we can't interpret the X/Y
          ;; coordinates on the event, substitute the previous X and Y
          ;; so we can still have a release event.
          (unless (numberp x)
            (setf x (interaction-screen-x *interaction*)))
          (unless (numberp y)
            (setf y (interaction-screen-y *interaction*)))
          (interaction/queue-event
           *interaction*
           (make-click
            :axis axis
            :button button
            :time (truncate (* time INTERNAL-TIME-UNITS-PER-SECOND))
            :modifiers (pyevent-modifiers py-event)
            :screen-x (coerce (pyslot-value py-event "x") 'double-float)
            :screen-y (coerce (pyslot-value py-event "y") 'double-float))))))))

(defun interact/button-release (time py-event)
  "Interaction handler for mouse button releases. Callback called by matplotlib"
  (when (not (interaction-done-p *interaction*))
    (let ((axis (pyevent-axes py-event)))
      (when axis
        (let ((x (pyslot-value py-event "x"))
              (y (pyslot-value py-event "y"))
              (button (or (pyevent-mouse-button py-event)
                          :left)))
          ;; We prefer not to lose release events, because things will feel
          ;; non-responsive if we do. Therefore if we can't interpret the X/Y
          ;; coordinates on the event, substitute the previous X and Y
          ;; so we can still have a release event.
          (unless (numberp x)
            (setf x (interaction-screen-x *interaction*)))
          (unless (numberp y)
            (setf y (interaction-screen-y *interaction*)))
          (interaction/queue-event
           *interaction*
           (make-release
            :axis axis
            :button button
            :time (truncate (* time INTERNAL-TIME-UNITS-PER-SECOND))
            :modifiers (pyevent-modifiers py-event)
            :screen-x (coerce (pyslot-value py-event "x") 'double-float)
            :screen-y (coerce (pyslot-value py-event "y") 'double-float))))))))

(defun interact/motion (time py-event)
  "Interaction handler for mouse motion. Callback called by matplotlib"
  (when (not (interaction-done-p *interaction*))
    (let ((x (pyslot-value py-event "x"))
          (y (pyslot-value py-event "y")))
      (when (and (numberp x) (numberp y))
        (interaction/queue-event
         *interaction*
         (make-motion
          :time (truncate (* time INTERNAL-TIME-UNITS-PER-SECOND))
          :screen-x (coerce x 'double-float)
          :screen-y (coerce y 'double-float)))))))

(defun interact/key (constructor time py-event)
  (when (not (interaction-done-p *interaction*))
    (multiple-value-bind (key modifiers) (pyevent-key py-event)
      (when key
        (let ((x (pyslot-value py-event "x"))
              (y (pyslot-value py-event "y")))
          (interaction/queue-event
           *interaction*
           (funcall constructor
                    :time (truncate (* time INTERNAL-TIME-UNITS-PER-SECOND))
                    :key key
                    :modifiers modifiers
                    :screen-x (coerce x 'double-float)
                    :screen-y (coerce y 'double-float))))))))

(defun interact/key-down (time py-event)
  (interact/key #'make-key-press time py-event))

(defun interact/key-up (time py-event)
  (interact/key #'make-key-release time py-event))

(defun interact/enter-axes (time py-event)
  (when (not (interaction-done-p *interaction*))
    (let ((axis (pyevent-axes py-event)))
        (when axis
          (let ((x (pyslot-value py-event "x"))
                (y (pyslot-value py-event "y")))
      (when (and (numberp x) (numberp y))
        ;; (format *out* "~%Entered axes...")
        (interaction/queue-event
         *interaction*
         (make-axis-enter
          :time (truncate (* time INTERNAL-TIME-UNITS-PER-SECOND))
          :axis axis
          :screen-x (coerce x 'double-float)
          :screen-y (coerce y 'double-float)))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Interaction high level acts!

(defparameter *actions*
  '(((:mouse :double :left-click  :line       :shift) #|does|# act!/toggle-line-in-selection)
    ((:mouse :double :left-click  :line             ) #|does|# act!/deselect act!/select-line)
    ((:mouse :long   :left-click  :line             ) #|does|# act!/deselect act!/show-data-at-cursor)
    ((:mouse :single :left-click  :point            ) #|does|# act!/deselect act!/toggle-tooltip)
    ((:mouse :long   :left-click  :point            ) #|does|# act!/deselect act!/toggle-tooltip)
    ((:mouse :single :left-click  :image            ) #|does|# act!/deselect act!/toggle-tooltip)
    ((:mouse :long   :left-click  :image            ) #|does|# act!/deselect act!/toggle-tooltip)
    ((:mouse :single :left-click  :annotation :shift) #|does|# act!/toggle-annotation-in-selection)
    ((:mouse :single :left-click  :annotation       ) #|does|# act!/select-annotation)
    ((:mouse :single :left-click  :emptyspace :shift) #|does|# )
    ((:mouse :single :left-click  :emptyspace       ) #|does|# act!/deselect)
    ((:mouse :hover               :annotation       ) #|does|# act!/trigger-hover)
    ((:mouse :start  :left-drag   :annotation :shift) #|does|# act!/add-annotation-to-selection act!/raise-for-drag-and-drop act!/begin-drag-and-drop)
    ((:mouse :start  :left-drag   :annotation       ) #|does|# act!/select-annotation act!/raise-for-drag-and-drop act!/begin-drag-and-drop)
    ((:mouse :start  :left-drag   :emptyspace       ) #|does|# act!/start-select-rectangle)
    ((:mouse :start  :middle-drag :emptyspace       ) #|does|# act!/start-pan-rectangle)
    ((:mouse :start  :right-drag  :emptyspace       ) #|does|# act!/start-zoom-rectangle)
    ((:mouse :end                                   ) #|does|# act!/end-drag-and-drop act!/end-select-rectangle act!/end-pan-rectangle act!/end-zoom-rectangle)
    ;; ((:mouse :up :scroll                            ) #|does|# act!/zoom-in)
    ;; ((:mouse :down :scroll                          ) #|does|# act!/zoom-out)
    ((:keyboard :escape            ) #|does|# act!/cancel-drag-and-drops)
    ((:keyboard :delete            ) #|does|# act!/delete-selection)
    ;; ((:keyboard :up                ) #|does|# move-selection-up)
    ;; ((:keyboard :down              ) #|does|# move-selection-down)
    ;; ((:keyboard :left        :shift) #|does|# add-to-selection-left)
    ;; ((:keyboard :right       :shift) #|does|# add-to-selection-right)
    ;; ((:keyboard :left  :alt        ) #|does|# move-data-cursors-left)
    ;; ((:keyboard :right :alt        ) #|does|# move-data-cursors-right)
    ;; ((:keyboard :left              ) #|does|# move-selection-left)
    ;; ((:keyboard :right             ) #|does|# move-selection-right)
    ((:keyboard :w     :ctrl       ) #|does|# act!/close-window)
    ((:keyboard :z     :ctrl :shift) #|does|# act!/redo)
    ((:keyboard :z     :ctrl       ) #|does|# act!/undo)
    ((:keyboard :c     :ctrl       ) #|does|# act!/copy)
    ((:keyboard :x     :ctrl       ) #|does|# act!/cut)
    ((:keyboard :v     :ctrl       ) #|does|# act!/paste))
  "The different actions that can be performed by the interaction loop.
   A list of (action-requirements . functions-to-call) where action-requirements is a list
   like (:mouse :double :left-click :line).")

(defun actions-match (inputs action-requirements)
  "Test if the given inputs [a list like (:mouse :double :left-click :line))] matches the
   action-requirements, which probably came from the *actions* variable."
  (loop :while (and inputs action-requirements)
        :when (equalp (pop inputs) (car action-requirements))
          :do (pop action-requirements))

  ;; Match if action-requirements are all satisified
  (null action-requirements))

(defun act!/toggle-tooltip (interaction)
  (declare (type interaction interaction))
  ;; (format t "~%INTERACTION SHOULD HIDE/SHOW THE TOOLTIP AT ~s" (interaction-mark-item interaction))
  (let ((mark (interaction-mark-item interaction)))
    (when mark
      (let* ((point (selection-point-index mark))
             (artist (selection-artist mark))
             (tooltip-p (tooltip-defined-p artist point))
             (visible-p (and tooltip-p (tooltip-visible-p artist point)))
             (existing-data-cursor (unless tooltip-p
                                     (setf point (coerce point 'double-float))
                                     (data-cursor-near artist point))))
        (cond ((and tooltip-p visible-p)
               (hide-tooltip artist point))
              (tooltip-p
               (show-tooltip artist point))
              (existing-data-cursor
               (hide-data-cursor artist existing-data-cursor))
              (t (place-data-cursor artist point)))))))

(defun act!/deselect (interaction)
  "Animate the deselection of interaction-selected and set it to nil."
  (declare (type interaction interaction))
  (loop :for thing :in (interaction-selected-annotations interaction)
        :do (interaction/queue-animation
             interaction
             (animate
              :towards :unselected
              :annotation-weak-pointer (sb-ext:make-weak-pointer thing))))
  (setf (interaction-selected-annotations interaction) nil)
  (setf (interaction-selected-lines interaction) nil))

(defun act!/select-annotation (interaction)
  (declare (type interaction interaction))
  ;; (format t "~%INTERACTION SHOULD SELECT ANNOTATION ~a...." (interaction-mark-item interaction))
  (setf (interaction-selected-lines interaction) nil)
  (let* ((prior-selection (interaction-selected-annotations interaction))
         (annotation (interaction-mark-item interaction))
         (already-selected (member annotation prior-selection)))
    (flet ((animate-prior-selection-deselecting ()
             "Animate the deselection of the prior-selection list. Doesn't update the selections though."
             (loop :for thing :in prior-selection
                   :do (interaction/queue-animation
                        interaction
                        (animate
                         :towards :unselected
                         :annotation-weak-pointer (sb-ext:make-weak-pointer thing))))))
    (cond (already-selected
           (setf prior-selection (delete annotation prior-selection))
           (animate-prior-selection-deselecting)
           (setf (interaction-selected-annotations interaction) (list (interaction-mark-item interaction))))
          (t
           (animate-prior-selection-deselecting)
           (setf (interaction-selected-annotations interaction) (list (interaction-mark-item interaction)))
           (interaction/queue-animation
            interaction
            (animate
             :towards :selected
             :annotation-weak-pointer (sb-ext:make-weak-pointer annotation))))))))

(defun act!/toggle-annotation-in-selection (interaction)
  (declare (type interaction interaction))
  ;; (format t "~%INTERACTION SHOULD ADD ANNOTATION ~a to selection...." (interaction-mark-item interaction))
  (let* ((prior-selection (interaction-selected-annotations interaction))
         (annotation (interaction-mark-item interaction))
         (already-selected (member annotation prior-selection)))
    (cond (already-selected
           (setf (interaction-selected-annotations interaction) (remove annotation (interaction-selected-annotations interaction)))
           (interaction/queue-animation
            interaction
            (animate
             :towards :unselected
             :annotation-weak-pointer (sb-ext:make-weak-pointer annotation))))
          (t
           (push annotation (interaction-selected-annotations interaction))
           (interaction/queue-animation
            interaction
            (animate
             :towards :selected
             :annotation-weak-pointer (sb-ext:make-weak-pointer annotation)))))))

(defun act!/add-annotation-to-selection (interaction)
  (declare (type interaction interaction))
  ;; (format t "~%INTERACTION SHOULD ADD ANNOTATION ~a to selection...." (interaction-mark-item interaction))
  (let* ((prior-selection (interaction-selected-annotations interaction))
         (annotation (interaction-mark-item interaction))
         (already-selected (member annotation prior-selection)))
    (unless already-selected
      (push annotation (interaction-selected-annotations interaction))
      (interaction/queue-animation
       interaction
       (animate
        :towards :selected
        :annotation-weak-pointer (sb-ext:make-weak-pointer annotation))))))

(defun  act!/begin-drag-and-drop (interaction)
  (declare (type interaction interaction))
  (setf (interaction-mode-change-start-screen-x interaction) (interaction-screen-x interaction))
  (setf (interaction-mode-change-start-screen-y interaction) (interaction-screen-y interaction))
  (setf (interaction-mode interaction) :drag-and-drop))

(defun act!/raise-for-drag-and-drop (interaction)
  (declare (type interaction interaction))
  (loop :for thing :in (interaction-selected-annotations interaction)
        :do (typecase thing
              (annotation
               (interaction/queue-animation
                interaction
                (animate
                 :towards :raised
                 :annotation-weak-pointer (sb-ext:make-weak-pointer thing)))))))

(defun act!/show-data-at-cursor (interaction)
  (declare (type interaction interaction))
  (let ((selection (interaction-mark-item interaction)))
    (assert (selection-p selection))
    (let ((existing (data-cursor-near (selection-artist selection)
                                      (selection-point-index selection))))
      (cond (existing
              (hide-data-cursor (selection-artist selection) existing))
            (t (place-data-cursor
                (selection-artist selection)
                (selection-point-index selection)))))))

(defun act!/select-line (interaction)
  (declare (type interaction interaction))
  ;; Need to mark this line too.
  ;; (format t "~%INTERACTION SHOULD ADD LINE ~a to selection...." (interaction-mark-item interaction))

  ;; Deselect all annotations
  (loop :for annotation :in (interaction-selected-annotations interaction)
        :do (interaction/queue-animation
             interaction
             (animate
              :towards :unselected
              :annotation-weak-pointer (sb-ext:make-weak-pointer annotation))))
  (setf (interaction-selected-annotations interaction) nil)

  ;; Select this line.
  (setf (interaction-selected-lines interaction) (list (selection-artist (interaction-mark-item interaction)))))

(defun act!/toggle-line-in-selection (interaction)
  (declare (type interaction interaction))
  ;; (format t "~%INTERACTION SHOULD TOGGLE LINE ~a to selection...." (interaction-mark-item interaction))
  (let* ((prior-selection (interaction-selected-lines interaction))
         (line (selection-artist (interaction-mark-item interaction)))
         (already-selected (member line prior-selection)))
    (cond (already-selected
           ;; (format t "~%It's already selected...")
           (setf (interaction-selected-lines interaction) (remove line (interaction-selected-lines interaction))))
          (t
           ;; (format t "~%Should be selected now!")
           (push line (interaction-selected-lines interaction))))))

;; (defun act!/hide-other-lines (interaction)
;;   (declare (type interaction interaction))
;;   (format t "~%INTERACTION SHOULD ALL LINES EXCEPT AT ~s" (interaction-mark-item interaction)))

(defun act!/start-select-rectangle (interaction)
  (declare (type interaction interaction))
  ;; (format t "~%INTERACTION SHOULD START SELECTION RECTANGLE at ~d,~d"
  ;;         (interaction-mark-screen-x interaction)
  ;;         (interaction-mark-screen-y interaction))
  (setf (interaction-mode-change-start-screen-x interaction) (interaction-screen-x interaction))
  (setf (interaction-mode-change-start-screen-y interaction) (interaction-screen-y interaction))
  (setf (interaction-mode interaction) :selection-rectangle))

(defun act!/start-pan-rectangle (interaction)
  (declare (type interaction interaction))
  ;; (format t "~%INTERACTION SHOULD START PAN RECTANGLE at ~d,~d"
  ;;         (interaction-mark-screen-x interaction)
  ;;         (interaction-mark-screen-y interaction))
  (setf (interaction-mode-change-start-screen-x interaction) (interaction-screen-x interaction))
  (setf (interaction-mode-change-start-screen-y interaction) (interaction-screen-y interaction))
  (setf (interaction-mode interaction) :pan))

(defun act!/start-zoom-rectangle (interaction)
  (declare (type interaction interaction))
  ;; (format t "~%INTERACTION SHOULD START ZOOM RECTANGLE at ~d,~d"
  ;;         (interaction-mark-screen-x interaction)
  ;;         (interaction-mark-screen-y interaction))
  (setf (interaction-mode-change-start-screen-x interaction) (interaction-screen-x interaction))
  (setf (interaction-mode-change-start-screen-y interaction) (interaction-screen-y interaction))
  (setf (interaction-mode interaction) :zoom-to-rectangle))

(defun act!/cancel-drag-and-drops (interaction)
  (declare (type interaction interaction))
  ;; (format t "~%INTERACTION SHOULD CANCEL ALL DRAG AND DROPS.")
  (setf (interaction-click interaction) nil)
  (setf (interaction-mode-change-start-screen-x interaction) (interaction-screen-x interaction))
  (setf (interaction-mode-change-start-screen-y interaction) (interaction-screen-y interaction))
  (setf (interaction-dragging-p interaction) nil)
  (setf (interaction-mode interaction) :normal)
  (when (interaction-hover-axis interaction)
    (setf (axis-changed-p (interaction-hover-axis interaction)) t)))

(defvar *drag-and-drop-offset-fudge-factor* 0.71d0
  "Not sure why this fudge factor is needed. But it scales the mouse screen offsets in such a way
   that adding it to the annotation x/y makes them track correctly.   It could be total nonsense
   and be invalidated when I change the scale of the plot axis.")

(defun act!/end-drag-and-drop (interaction)
  (declare (type interaction interaction))
  (when (eq (interaction-mode interaction) :drag-and-drop)
    ;; (format t "~%INTERACTION SHOULD END DRAG AND DROP at ~d,~d"
    ;;         (interaction-mark-screen-x interaction)
    ;;         (interaction-mark-screen-y interaction))
    (let ((offset-x (* *drag-and-drop-offset-fudge-factor* (- (interaction-screen-x interaction)
                              (interaction-mode-change-start-screen-x interaction))))
          (offset-y (* *drag-and-drop-offset-fudge-factor* (- (interaction-screen-y interaction)
                              (interaction-mode-change-start-screen-y interaction)))))
      (setf (interaction-mode interaction) :normal)
      (setf (interaction-mode-change-start-screen-x interaction) (interaction-screen-x interaction))
      (setf (interaction-mode-change-start-screen-y interaction) (interaction-screen-y interaction))

      (let* ((axis (interaction-hover-axis interaction))
             (old-positions
               (loop :for thing :in (interaction-selected-annotations interaction)
                     :collect (typecase thing
                                (annotation
                                 (cons thing (pymethod (annotation-handle thing) "get_position"))))))
             (new-positions
               (loop :for (thing . position) :in old-positions
                     :collect (typecase thing
                                (annotation
                                 (cons thing (list (+ (first position) offset-x)
                                                   (+ (second position) offset-y))))))))

        ;; (format t "~%old: ~s" old-positions)
        ;; (format t "~%new: ~s" new-positions)

        (flet ((apply-drag-and-drop ()
                 ;;(format t "~%APPLY DRAG AND DROP.")
                 (loop :for (thing . position) :in new-positions
                       :do (typecase thing
                             (annotation
                              (pyexec (annotation-handle thing) ".set_position(" position ")")))))
               (revert-drag-and-drop ()
                 ;; (format t "~%REVERT DRAG AND DROP.")
                 (loop :for (thing . position) :in old-positions
                       :do (typecase thing
                             (annotation
                              (pyexec (annotation-handle thing) ".set_position(" position ")"))))))
          (apply-drag-and-drop)
          (loop :for (thing . position) :in new-positions
                :do (interaction/queue-animation
                     interaction
                     (animate
                      :towards :unraised
                      :annotation-weak-pointer (sb-ext:make-weak-pointer thing))))
          (push (list #'(lambda ()
                          (revert-drag-and-drop)
                          (setf (axis-changed-p axis) t))
                      #'(lambda ()
                          (apply-drag-and-drop)
                          (setf (axis-changed-p axis) t)))
                *undo*))))))

(defun act!/end-select-rectangle (interaction)
  (when (eq (interaction-mode interaction) :selection-rectangle)
    (setf (interaction-mode interaction) :normal)
    (setf (interaction-mode-change-start-screen-x interaction) (interaction-screen-x interaction))
    (setf (interaction-mode-change-start-screen-y interaction) (interaction-screen-y interaction))
    ;; (format t "~%INTERACTION SHOULD END SELECTION RECTANGLE at ~d,~d"
    ;;         (interaction-mark-screen-x interaction)
    ;;         (interaction-mark-screen-y interaction))
    ))

(defun act!/end-pan-rectangle (interaction)
  (declare (type interaction interaction))
  (when (eq (interaction-mode interaction) :pan)
    (setf (interaction-mode interaction) :normal)
    (setf (interaction-mode-change-start-screen-x interaction) (interaction-screen-x interaction))
    (setf (interaction-mode-change-start-screen-y interaction) (interaction-screen-y interaction))
    ;; (format t "~%INTERACTION SHOULD END PAN RECTANGLE at ~d,~d"
    ;;         (interaction-mark-screen-x interaction)
    ;;         (interaction-mark-screen-y interaction))
    ))

(defun act!/end-zoom-rectangle (interaction)
  (declare (type interaction interaction))
  (when (eq (interaction-mode interaction) :zoom-to-rectangle)
    (setf (interaction-mode interaction) :normal)
    (setf (interaction-mode-change-start-screen-x interaction) (interaction-screen-x interaction))
    (setf (interaction-mode-change-start-screen-y interaction) (interaction-screen-y interaction))
    ;; (format t "~%INTERACTION SHOULD END ZOOM RECTANGLE at ~d,~d"
    ;;         (interaction-mark-screen-x interaction)
    ;;         (interaction-mark-screen-y interaction))
    ))

(defun act!/delete-selection (interaction)
  "Animate the deselection of interaction-selected-annotations and set it to nil."
  (map nil 'remove-annotation (interaction-selected-annotations interaction))
  (setf (interaction-selected-annotations interaction) nil)
  (map nil 'delete-artist (interaction-selected-lines interaction))
  (setf (interaction-selected-lines interaction) nil))

(defun act!/trigger-hover (interaction)
  "Animate the deselection of interaction-selected-annotations and set it to nil."
  (let ((prior (interaction-previous-hover interaction))
        (current (interaction-current-hover interaction)))
    (typecase prior
      (annotation
       (unless (annotation-closed-p prior)
         (interaction/queue-animation
          interaction
          (animate
           :towards :unhovered
           :annotation-weak-pointer (sb-ext:make-weak-pointer prior))))))
    (typecase current
      (annotation
       (unless (annotation-closed-p current)
         (interaction/queue-animation
          interaction
          (animate
           :towards :hovered
           :annotation-weak-pointer (sb-ext:make-weak-pointer current))))))))

(defun act!/close-window (interaction)
  ;; (format t "~%Closing window: ~s" (axis-figure (interaction-hover-axis interaction)))
  (when (interaction-hover-axis interaction)
    (close-figure (axis-figure (interaction-hover-axis interaction)))))

(defun act!/undo (interaction)
  (declare (ignore interaction))
  (funcall *undo-callback*))

(defun act!/redo (interaction)
  (declare (ignore interaction))
  (funcall *redo-callback*))

(defun act!/copy (interaction)
  (declare (type interaction interaction)
           (optimize debug))
  (let ((axis (interaction-hover-axis interaction)))
    (funcall *copy-callback*
             (loop :for artist :in (interaction-selected-lines interaction)
                   :when (eq (artist-axis artist) axis)
                     :collect (make-line-copy-from-artist artist))))
  (format t "~%Copied ~d lines" (length *copied-traces*)))

(defun act!/cut (interaction)
  (declare (type interaction interaction)
           (optimize debug))
  (let ((axis (interaction-hover-axis interaction)))
    (funcall *copy-callback*
             (loop :for artist :in (interaction-selected-lines interaction)
                   :when (eq (artist-axis artist) axis)
                     :collect (make-line-copy-from-artist artist)))
    (loop :for artist :in (interaction-selected-lines interaction)
          :when (eq (artist-axis artist) axis)
            :collect (delete-artist artist)))
  (format t "~%Cut ~d lines" (length *copied-traces*)))

(defun act!/paste (interaction)
  (declare (type interaction interaction)
           (optimize debug))
  (declare (ignore interaction))
  (loop :for line :in *copied-traces*
        :do (funcall *paste-callback* line))
  (format t "~%Pasted ~d lines" (length *copied-traces*)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Interaction High Level Utilities

(defun interaction-loop/handle-inputs (interaction inputs)
  (loop :for (action-requirements . functions) :in *actions*
        ;; Only one action can match.
        :when (actions-match inputs action-requirements)
          :do (progn
                (loop :for fn :in functions
                      :do (funcall fn interaction))
                (return-from interaction-loop/handle-inputs))))

(defun interaction-loop/mark-annotation-under-mouse-pointer (interaction axis screen-x screen-y)
  "If a point is on top of an annotation returns :annotation and also
   updates the interaction structure's mark slots (x, y, item) to the found item. Otherwise
   returns nil and resets the interaction structure's mark slots."
  (declare (type interaction interaction)
           (type axis axis)
           (type double-float screen-x screen-y))
  (let ((match (find-if #'(lambda (annotation)
                            (and (not (annotation-closed-p annotation))
                                 (destructuring-bind (xmin xmax ymin ymax) (annotation-screen-coords annotation)
                                   ;; (format t "~%CHECK (~a, ~a) to (~a, ~a) vs (~a, ~a)"
                                   ;;         xmin ymin xmax ymax
                                   ;;         screen-x screen-y)
                                   (and (<= xmin screen-x xmax)
                                        (<= ymin screen-y ymax)))))
                        (axis-annotations axis))))
    (cond (match
            (setf (interaction-mark-screen-x interaction) screen-x)
            (setf (interaction-mark-screen-y interaction) screen-y)
            (setf (interaction-hover-axis interaction) axis)
            (setf (interaction-mark-item interaction) match)
            :annotation)
          (t
           (setf (interaction-mark-screen-x interaction) 0d0)
           (setf (interaction-mark-screen-y interaction) 0d0)
           (setf (interaction-mark-item interaction) nil)
           nil))))

(defun interaction-loop/mark-line-point-under-mouse-pointer (interaction axis screen-x screen-y)
  "If a point is find near the screen-x screen-y coordinates, returns :point and also
   updates the interaction structure's mark slots (x, y, item) to the found item. Otherwise
   returns nil and resets the interaction structure's mark slots."
  (declare (type interaction interaction)
           (type axis axis)
           (type double-float screen-x screen-y))
  (loop :with closest = nil
        ;; For the data browser, and generally, the users are far more interested in
        ;; being able to easily click points. So we make these large.
        :with closest-distance-pixels = 45
        :for artist :across (pymethod (axis-handle axis) "get_children")
        :for selection = (and (points-visible-p artist)
                              (compute-nearest-point axis artist screen-x screen-y))
        :when (and selection (< (selection-distance selection) closest-distance-pixels))
          :do (setf closest selection
                    closest-distance-pixels (selection-distance selection))
        :finally (cond (closest
                        (setf (interaction-mark-screen-x interaction) (selection-point-screen-x closest))
                        (setf (interaction-mark-screen-y interaction) (selection-point-screen-y closest))
                        (setf (interaction-hover-axis interaction) axis)
                        (setf (interaction-mark-item interaction) closest)
                        (return-from interaction-loop/mark-line-point-under-mouse-pointer :point))
                       (t (setf (interaction-mark-screen-x interaction) 0d0)
                          (setf (interaction-mark-screen-y interaction) 0d0)
                          (setf (interaction-mark-item interaction) nil)
                          (return-from interaction-loop/mark-line-point-under-mouse-pointer nil)))))

(defun interaction-loop/mark-line-under-mouse-pointer (interaction axis screen-x screen-y)
  "If a line is find near the screen-x screen-y coordinates, returns :line and also
   updates the interaction structure's mark slots (x, y, item) to the found item. Otherwise
   returns nil and resets the interaction structure's mark slots."
  (declare (type interaction interaction)
           (type axis axis)
           (type double-float screen-x screen-y))
  (loop :with closest = nil
        :with closest-distance-pixels = 5 ;; must be within 5px to hit anything.
        :for artist :across (pymethod (axis-handle axis) "get_children")
        :for projection = (and (lines-visible-p artist)
                               (compute-nearest-line axis artist screen-x screen-y))
        :when (and projection (< (selection-distance projection) closest-distance-pixels))
          :do (setf closest projection
                    closest-distance-pixels (selection-distance projection))
        :finally (cond (closest
                        (setf (interaction-mark-screen-x interaction) (selection-point-screen-x closest))
                        (setf (interaction-mark-screen-y interaction) (selection-point-screen-y closest))
                        (setf (interaction-mark-item interaction) closest)
                        (setf (interaction-hover-axis interaction) axis)
                        (return-from interaction-loop/mark-line-under-mouse-pointer :line))
                       (t (setf (interaction-mark-screen-x interaction) 0d0)
                          (setf (interaction-mark-screen-y interaction) 0d0)
                          (setf (interaction-mark-item interaction) nil)
                          (return-from interaction-loop/mark-line-under-mouse-pointer nil)))))

(defun interaction-loop/mark-image-under-mouse-pointer (interaction axis screen-x screen-y)
  "If an image is near the screen-x screen-y coordinates, returns :image and also
   updates the interaction structure's mark slots (x, y, item) to the found item. Otherwise
   returns nil and resets the interaction structure's mark slots."
  (declare (type interaction interaction)
           (type axis axis)
           (type double-float screen-x screen-y))
  (loop :with closest = nil
        :with closest-distance-pixels = 50
        :for artist :across (pymethod (axis-handle axis) "get_children")
        :for projection = (and (image-visible-p artist)
                               (compute-nearest-pixel axis artist screen-x screen-y))
        :when (and projection (< (selection-distance projection) closest-distance-pixels))
          :do (setf closest projection
                    closest-distance-pixels (selection-distance projection))
        :finally (cond (closest
                        (setf (interaction-mark-screen-x interaction) (selection-point-screen-x closest))
                        (setf (interaction-mark-screen-y interaction) (selection-point-screen-y closest))
                        (setf (interaction-mark-item interaction) closest)
                        (setf (interaction-hover-axis interaction) axis)
                        (return-from interaction-loop/mark-image-under-mouse-pointer :image))
                       (t (setf (interaction-mark-screen-x interaction) 0d0)
                          (setf (interaction-mark-screen-y interaction) 0d0)
                          (setf (interaction-mark-item interaction) nil)
                          (return-from interaction-loop/mark-image-under-mouse-pointer nil)))))

(defun interaction-loop/mark-thing-under-mouse-pointer (interaction axis screen-x screen-y)
  (or
   (interaction-loop/mark-annotation-under-mouse-pointer
    interaction
    axis
    screen-x
    screen-y)
   (interaction-loop/mark-line-point-under-mouse-pointer
    interaction
    axis
    screen-x
    screen-y)
   (interaction-loop/mark-line-under-mouse-pointer
    interaction
    axis
    screen-x
    screen-y)
   (interaction-loop/mark-image-under-mouse-pointer
    interaction
    axis
    screen-x
    screen-y)
   :emptyspace))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Interaction State
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defstruct animation-state
  "A on screen manipulative (e.g. a tooltip) that can be interacted with has only a limited set of 'states'
   that it can animate between. So we can encode it as a few floats.

    Close -> Open factor (0.0 = fully closed, 1.0 = fully open)
    Unselected -> Selected factor (0.0 = fully deselected, 1.0 = fully selected)
    Unraised -> Raised factor (0.0 = fully unraised, 1.0 = fully raise)
    hover -> unhovered factor (0.0 = fully unhovered, 1.0 = fully hovered).

   Items should fade in as they're opened.
   Items borders should brighten as they're selected.
   Items should raise as they're picked up (e.g. drag and drop)
    - By scaling up slightly
    - By gaining a drop shadow
   Items should brighet as they're hovered."
  (open 0d0 :type double-float :read-only nil)
  (select 0d0 :type double-float :read-only nil)
  (raise 0d0 :type double-float :read-only nil)
  (hover 0d0 :type double-float :read-only nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Interaction loop.
;;
;; We have to take the low level events (clicks, releases) and turn them into higher level
;; constructs (click-and-drags, double clicks, long clicks, short clicks).  These higher level
;; events will trigger longer running activities, such as maintaining a list of selected objects,
;; selecting a bunch of objects by region, moving your selections, etc.  And these long running
;; activities must be animated.
;;
;;  1. A newly selected object should glow.
;;  2. Objects being dragged should be a bit larger, have drop shadows, and follow the mouse cursor.
;;  3. A collapsing tooltip should animate open and closed
;;
;; The interaction loop takes care of all of that.

(defun interaction-loop/handle-double-click (interaction release)
  "A left button double click on a line hides that line (and all associated annotations). If shift
   is held it hides all other lines."
  (declare (type interaction interaction)
           (type release release))
  ;; (format t "~%DOUBLE-CLICK @ ~d,~d" (release-screen-x release) (release-screen-y release))
  (let ((thing (interaction-loop/mark-thing-under-mouse-pointer
                interaction
                (release-axis release)
                (release-screen-x release)
                (release-screen-y release)))
        (shift-modifier (= 1 (sbit (release-modifiers release) +shift-modifier+))))
    (interaction-loop/handle-inputs
     interaction
     `(:mouse :double ,(ecase (release-button release)
                         (:left :left-click)
                         (:middle :middle-click)
                         (:right :right-click))
              ,thing ,@(and shift-modifier '(:shift))))))

(defun interaction-loop/handle-short-click (interaction release)
  "A left button short click selects the annotation under the cursor. All others are deselected (unless
   shift is held)."
  (declare (type interaction interaction)
           (type release release))
  ;; (format t "~%SHORT-CLICK @ ~d,~d" (release-screen-x release) (release-screen-y release))
  (let ((thing (interaction-loop/mark-thing-under-mouse-pointer
                interaction
                (release-axis release)
                (release-screen-x release)
                (release-screen-y release)))
        (shift-modifier (= 1 (sbit (release-modifiers release) +shift-modifier+))))
    (interaction-loop/handle-inputs
     interaction
     `(:mouse :single ,(ecase (release-button release)
                         (:left :left-click)
                         (:middle :middle-click)
                         (:right :right-click))
              ,thing ,@(and shift-modifier '(:shift))))))

(defun interaction-loop/handle-long-click (interaction release)
  "A left button long click opens a data-cursor on the nearest visible line."
  (declare (type interaction interaction)
           (type release release))
  ;; (format t "~%LONG-CLICK @ ~d,~d" (release-screen-x release) (release-screen-y release))
  (let ((thing (interaction-loop/mark-thing-under-mouse-pointer
                interaction
                (release-axis release)
                (release-screen-x release)
                (release-screen-y release)))
        (shift-modifier (= 1 (sbit (release-modifiers release) +shift-modifier+))))
    (interaction-loop/handle-inputs
     interaction
     `(:mouse :long ,(ecase (release-button release)
                       (:left :left-click)
                       (:middle :middle-click)
                       (:right :right-click))
              ,thing ,@(and shift-modifier '(:shift))))))

(defun interaction-loop/start-drag (interaction click)
  "A left button drag started from an annotation selects it (acting like a left click) and moves the annotations.
   If there is no annotation it creates a selection rectangle.  If the rectangle is going to the right, it
   selects anything it touches.  If it's going left, it selects only things fully included.  Shift controls
   if it adds to the current selection.

   A middle button drag will pan the plot.

   A right button drag will create a zoom rectangle. On release the plot will zoom to the selected region.

   In any case, ESCAPE should cancel the action."
  (declare (type interaction interaction)
           (type click click))
  ;; (format t "~%START-DRAG @ ~d,~d" (click-screen-x click) (click-screen-y click))
  (let ((thing (interaction-loop/mark-thing-under-mouse-pointer
                interaction
                (click-axis click)
                (click-screen-x click)
                (click-screen-y click)))
        (shift-modifier (= 1 (sbit (click-modifiers click) +shift-modifier+))))
    (interaction-loop/handle-inputs
     interaction
     `(:mouse :start ,(ecase (click-button click)
                        (:left :left-drag)
                        (:middle :middle-drag)
                        (:right :right-drag))
              ,thing ,@(and shift-modifier '(:shift))))))

(defun interaction-loop/conclude-drag (interaction release)
  "What to do when we've resolved low level click releases into a click drag release. The click
   and release structures have useful metadata -- like axis and location."
  (declare (type interaction interaction)
           (type release release))
  ;; (format t "~%CONCLUDE-DRAG @ ~d,~d -> ~d,~d"
  ;;         (click-screen-x click)
  ;;         (click-screen-y click)
  ;;         (release-screen-x release)
  ;;         (release-screen-y release))
  (let (;; None of the handlers for concluding a drag depend on the thing
        ;; so save some work by not computing it.
        ;; (thing (interaction-loop/mark-thing-under-mouse-pointer
        ;;         interaction
        ;;         (click-axis click)
        ;;         (click-screen-x click)
        ;;         (click-screen-y click)))
        (shift-modifier (= 1 (sbit (release-modifiers release) +shift-modifier+))))
    (interaction-loop/handle-inputs
     interaction
     `(:mouse :end ,(ecase (release-button release)
                      (:left :left-drag)
                      (:middle :middle-drag)
                      (:right :right-drag))
              ;; ,thing
              ,@(and shift-modifier '(:shift))))))

(defun interaction-loop/handle-key (interaction key)
  "A left button double click on a line hides that line (and all associated annotations). If shift
   is held it hides all other lines."
  (declare (type interaction interaction)
           (type key-release key))
  ;; (format t "~%KEY ~s" key)
  (let ((shift-modifier (= 1 (sbit (key-release-modifiers key) +shift-modifier+)))
        (ctrl-modifier (= 1 (sbit (key-release-modifiers key) +ctrl-modifier+)))
        (alt-modifier (= 1 (sbit (key-release-modifiers key) +alt-modifier+))))
    (interaction-loop/handle-inputs
     interaction
     `(:keyboard ,(key-release-key key)
                 ,@(and ctrl-modifier '(:ctrl))
                 ,@(and alt-modifier '(:alt))
                 ,@(and shift-modifier '(:shift))))))

(defun interaction-loop/hover (interaction)
  (declare (type interaction interaction))
  ;; Only annotations can be hovered right now.
  (when (interaction-hover-axis interaction)
    (let* ((screen-x (interaction-screen-x interaction))
           (screen-y (interaction-screen-y interaction))
           (axis (interaction-hover-axis interaction))
           ;; It would be better to do this with a single python call...
           (hovered (find-if #'(lambda (annotation)
                                 (and (not (annotation-closed-p annotation))
                                      (destructuring-bind (xmin xmax ymin ymax) (annotation-screen-coords annotation)
                                        ;; (format t "~%CHECK (~a, ~a) to (~a, ~a) vs (~a, ~a)"
                                        ;;         xmin ymin xmax ymax
                                        ;;         screen-x screen-y)
                                        (and (<= xmin screen-x xmax)
                                             (<= ymin screen-y ymax)))))
                             (axis-annotations axis))))
      (unless (eq (interaction-current-hover interaction) hovered)
        (setf (interaction-previous-hover interaction) (interaction-current-hover interaction))
        (setf (interaction-current-hover interaction) hovered)
        (interaction-loop/handle-inputs
         interaction
         `(:mouse :hover :annotation))))))

(defun interaction-loop/decode-and-trigger-input (interaction now)
  (let ((prior (interaction-prior-click interaction))
        (click (interaction-click interaction))
        (click-lisp-time (interaction-click-lisp-time interaction))
        (release (interaction-release interaction)))

    (cond (;; Test for a double click
           (and release prior click
                ;; Same button
                (eq (release-button release) (click-button click))
                (eq (release-button release) (click-button prior))
                ;; Time constaint
                (< (- (release-time release) (click-time prior))
                   +double-click-time-internal-time-units+)
                (let ((dx (- (release-screen-x release)
                             (click-screen-x prior)))
                      (dy (- (release-screen-y release)
                             (click-screen-y prior))))
                  ;; Pixel movement constraint.
                  (< (+ (* dx dx) (* dy dy)) +click-maximum-screen-pixel-distance-squared+)))

           (setf (interaction-hover-axis interaction) (release-axis release))
           (setf (interaction-click interaction) nil)
           (setf (interaction-click-lisp-time interaction) 0)
           (setf (interaction-prior-click interaction) nil)
           (setf (interaction-release interaction) nil)
           (interaction-loop/handle-double-click
            interaction release))
          (;; Test for a single-click (long or short)
           (and release click
                ;; Same button
                (eq (release-button release) (click-button click))
                (let ((dx (- (release-screen-x release)
                             (click-screen-x click)))
                      (dy (- (release-screen-y release)
                             (click-screen-y click))))
                  ;; Pixel movement constraint.
                  (< (+ (* dx dx) (* dy dy)) +click-maximum-screen-pixel-distance-squared+))
                ;; Too long for a double click.
                (> (- now click-lisp-time)
                   +double-click-time-internal-time-units+))
           (setf (interaction-hover-axis interaction) (release-axis release))
           (setf (interaction-click interaction) nil)
           (setf (interaction-click-lisp-time interaction) 0)
           (setf (interaction-prior-click interaction) nil)
           (setf (interaction-release interaction) nil)
           (if (< (- (release-time release) (click-time click))
                  +long-click-time-internal-time-units+)
               (interaction-loop/handle-short-click
                interaction release)
               (interaction-loop/handle-long-click
                interaction release)))
          (;; Test for starting a click and drag
           (and (not release)
                click
                (not (interaction-dragging-p interaction))
                (let ((dx (- (interaction-screen-x interaction)
                             (click-screen-x click)))
                      (dy (- (interaction-screen-y interaction)
                             (click-screen-y click))))
                  (> (+ (* dx dx) (* dy dy)) +click-maximum-screen-pixel-distance-squared+)))
           (setf (interaction-hover-axis interaction) (click-axis click))
           (setf (interaction-dragging-p interaction) t)
           (interaction-loop/start-drag
            interaction click))
          )

    ;; Test for completing a click and drag
    (when (and release (interaction-dragging-p interaction))
      (setf (interaction-hover-axis interaction) (release-axis release))
      (setf (interaction-click interaction) nil)
      (setf (interaction-click-lisp-time interaction) 0)
      (setf (interaction-prior-click interaction) nil)
      (setf (interaction-release interaction) nil)
      (setf (interaction-dragging-p interaction) nil)
      (interaction-loop/conclude-drag
       interaction ;; click
       release))

    ;; Handle hovering
    (interaction-loop/hover interaction)

    ;; Handle key releases
    (loop :for release :in (interaction-released-keys interaction)
          :do (interaction-loop/handle-key interaction release))
    (setf (interaction-released-keys interaction) nil)))

(defun interaction-loop/handle-event-queue-item (interaction event)
  (etypecase event
    (click
     ;; Currently stored click moves to prior click if it's very recent.
     (setf (interaction-prior-click interaction)
           (when (and (interaction-click interaction)
                      ;; only left double clicks.
                      (eq :left (click-button event))
                      (eq :left (click-button (interaction-click interaction)))

                      ;; Occured within double-click time limit.
                      (< (- (click-time event) (click-time (interaction-click interaction)))
                         +double-click-time-internal-time-units+))
             (interaction-click interaction)))

     ;; This new click becomes the stored click.
     (setf (interaction-release interaction) nil)
     (setf (interaction-screen-x interaction) (click-screen-x event))
     (setf (interaction-screen-y interaction) (click-screen-y event))
     (setf (interaction-click interaction) event)
     (setf (interaction-click-lisp-time interaction) (get-internal-real-time)))
    (release
     (setf (interaction-release interaction) event)
     (setf (interaction-screen-x interaction) (release-screen-x event))
     (setf (interaction-screen-y interaction) (release-screen-y event)))
    (key-press
     ;; We generally don't do anything on the key-press, but on the key-release instead.
     ;; (format t "~%Ignoring ~s" event)
     (setf (interaction-screen-x interaction) (key-press-screen-x event))
     (setf (interaction-screen-y interaction) (key-press-screen-y event)))
    (key-release
     (push event (interaction-released-keys interaction))
     (setf (interaction-screen-x interaction) (key-release-screen-x event))
     (setf (interaction-screen-y interaction) (key-release-screen-y event)))
    (motion
     (setf (interaction-screen-x interaction) (motion-screen-x event))
     (setf (interaction-screen-y interaction) (motion-screen-y event)))
    (axis-enter
     (setf (interaction-hover-axis interaction) (axis-enter-axis event))
     (setf (interaction-screen-x interaction) (axis-enter-screen-x event))
     (setf (interaction-screen-y interaction) (axis-enter-screen-y event)))
     ))

(defvar *debug-interaction-loop* nil
  "Defaults to nil: suppress python errors that occur during the interaction loop.

   If set to T and the interaction loop will halt on python-errors. Otherwise it'll suppress them.

   Suppressing errors is usually appreciated.. The errors tend to be things like use-after-free of a
   plot that was closed but Lisp still having some reference to it (e.g. in animations, in
   selections).

   We could harden it up, but I (Warren) suspect that's not better than ignoring the occasional
   problem, and a lot more work.")

(defun interaction-loop/process-queue (interaction now queue)
  "This is the main queue processing body of the interaction loop. I pulled it out of interaction-loop
   to allow easier development (e.g. you can just re-evaluate it and see your changes.)"
  ;; Always, process all the queued up events from python. These will modify state on the
  ;; interaction object so that interaction-loop/handle-event-state can function.
  (loop :for event :in queue
        :do (interaction-loop/handle-event-queue-item interaction event))

  ;; The python events modified slots on the interaction object. Now
  ;; we can look at those modifications and determine / trigger higher order
  ;; interactions (e.g. double click events, click and drag events, in the context
  ;; of what's on the screen to interact with.
  (interaction-loop/decode-and-trigger-input interaction now)

  ;; Process active animations to produce a set of animation states
  ;; that can be applied to the annotation.
  (let* ((animation-states nil)
         (animations (interaction-animation-queue interaction))
         (done-animations
           (loop :for animation :in animations
                 :for annotation = (sb-ext:weak-pointer-value (animate-annotation-weak-pointer animation))
                 :for factor = (max 0d0 (min 1d0 (coerce (/ (- now (animate-started animation)) +animation-time-internal-time-units+) 'double-float)))
                 :when annotation
                   :do (let ((state (cdr (find annotation animation-states :key #'car))))
                         (unless state
                           ;; Build the new initial state for the animation.  Basically a
                           ;; heuristic based on the goal... assume we started from the opposite
                           ;; place.
                           (setf state (make-animation-state :open 1d0)) ;; assume open.
                           (when (member annotation (interaction-selected-annotations interaction))
                             (setf (animation-state-select state) 1d0))
                           (when (eq annotation (interaction-current-hover interaction))
                             (setf (animation-state-hover state) 1d0))
                           (case (animate-towards animation)
                             (:opened (setf (animation-state-open state) 0d0))
                             (:unselected (setf (animation-state-select state) 1d0))
                             (:unhovered (setf (animation-state-hover state) 1d0))
                             (:unraise (setf (animation-state-raise state) 1d0)))
                           (push (cons annotation state) animation-states))

                         ;; Update the animation state with the progress of this animation. Most
                         ;; recent animation wins (Animations are stored oldest to newest).
                         (ecase (animate-towards animation)
                           (:opened (setf (animation-state-open state) factor))
                           (:closed (setf (animation-state-open state) (- 1d0 factor)))
                           (:selected (setf (animation-state-select state) factor))
                           (:unselected (setf (animation-state-select state) (- 1d0 factor)))
                           (:hovered (setf (animation-state-hover state) factor))
                           (:unhovered (setf (animation-state-hover state) (- 1d0 factor)))
                           (:raised (setf (animation-state-raise state) factor))
                           (:unraised (setf (animation-state-raise state) (- 1d0 factor)))))
                 :when (or (null annotation) (>= factor 1.0d0))
                   :collect animation)))
    ;; Thread-safely update the animation queue to remove finished animations.
    (loop :for animation-queue = (interaction-animation-queue interaction)
          :for new-animation-queue = (sort (set-difference animation-queue done-animations) #'< :key #'animate-started)
          :until (eq animation-queue (sb-ext:compare-and-swap (interaction-animation-queue interaction) animation-queue new-animation-queue)))

    ;; Apply the animation states to the annotations they belong too.
    (loop :for (annotation . interaction-state) :in animation-states
          :for update-fn = (and (annotation-p annotation) (annotation-interaction-update-fn annotation))
          :when update-fn
            :do (funcall update-fn annotation interaction-state))

    ;; Handle closed things by calling their callbacks.
    (loop :for animation :in done-animations
          :when (animate-callback animation)
            :do (funcall (animate-callback animation)))

    ;; Redraw any animated Axis using fast blitting.
    ;; https://matplotlib.org/stable/users/explain/animations/blitting.html
    (let ((animated-axis nil)
          (must-redraw-axis nil))
      (loop :for animation :in animations
            :for annotation = (sb-ext:weak-pointer-value (animate-annotation-weak-pointer animation))
            :when annotation
              :do (pushnew (annotation-axis annotation) animated-axis))

      ;; Or if we're dragging and dropping, we must draw.
      (when (eq (interaction-mode interaction) :drag-and-drop)
        (loop :for selected :in (interaction-selected-annotations interaction)
              :when (annotation-p selected)
                :do (pushnew (annotation-axis selected) animated-axis)))

      ;; The the legend was clicked, treat that as the axis has been changed.
      (when (and *legend-clicked-force-redraw-p* (interaction-hover-axis interaction))
        (setf (axis-changed-p (interaction-hover-axis interaction)) t)
        (setf *legend-clicked-force-redraw-p* nil))

      ;; If the annotation seems to need a redraw, we must draw.
      (when (and (interaction-hover-axis interaction)
                 (let ((axis (interaction-hover-axis interaction))
                       (cached nil))
                   (or (axis-changed-p axis)
                       (null (setf cached (gethash axis (interaction-image-cache interaction))))
                       (not (eq (car cached) (axis-properties-hash axis))))))
        (pushnew (interaction-hover-axis interaction) animated-axis))

      ;; If the axis has artists, check the selection state matches the artist
      ;; highlight state.  If they don't match, fix it, and force a redraw.
      (when (interaction-hover-axis interaction)
        (let ((needs-highlight-added
                (remove-if #'artist-highlighted-p
                           (interaction-selected-lines interaction)))
              (needs-highlight-removed
                (remove-if #'(lambda (artist)
                               (or (not (artist-highlighted-p artist))
                                   (member artist (interaction-selected-lines interaction))))
                           (axis-artists (interaction-hover-axis interaction)))))
          (assert (null (intersection needs-highlight-added needs-highlight-removed)))
          (map nil #'artist-highlight needs-highlight-added)
          (map nil #'artist-unhighlight needs-highlight-removed)
          (when (or needs-highlight-added needs-highlight-removed)
            (pushnew (interaction-hover-axis interaction) animated-axis)
            (pushnew (interaction-hover-axis interaction) must-redraw-axis))))

      (loop :for axis :in animated-axis
            :for axis-handle = (axis-handle axis)
            :for figure-handle = (figure-handle (axis-figure axis))
            ;; Redraw the plot from cache, caching if needed.
            :do (tagbody
                   (handler-bind ((PY4CL2:PYERROR
                                    #'(lambda (python-error)
                                        (declare (ignore python-error))
                                        ;; For most users, popping a debugger on a cryptic python error is
                                        ;; not appreciated during plotting. Better to suppress them.
                                        ;;
                                        ;; If you're trying to debug something,
                                        ;;   (setf *debug-interaction-loop* t)
                                        (when (null *debug-interaction-loop*)
                                          (go :next-axis)))))
                     (let ((cached nil)
                           (hash nil))
                       (cond ((or ;; Python says the axis has changed.
                               (member axis must-redraw-axis)
                               (axis-changed-p axis)
                               ;; We don't have a saved value.
                               (null (setf cached (gethash axis (interaction-image-cache interaction))))
                               ;; Signature change, the car of the saved value is the old hash.
                               (not (eq (car cached) (setf hash (axis-properties-hash axis)))))

                              ;; When we are drawing for the background cached image, we need to take
                              ;; full control and prevent others from redrawing during this time.
                              ;; To do that we *suppress-redraw*, hide all the annotations, immediately
                              ;; trigger a draw, then save the draw.
                              ;;
                              ;; The unwind protect here ensures that we turn off *suppress-redraw* and
                              ;; reshow the annotations.
                              (setf *suppress-redraw* t)
                              (unwind-protect
                                   (progn
                                     ;; Disable all the annotations.
                                     (dolist (annotation (axis-annotations axis))
                                       (pymethod (annotation-handle annotation) "set_visible" nil))
                                     (setf (axis-changed-p axis) nil)

                                     ;; FORCE the redraw, bypassing *suppress-redraw*
                                     (pyeval (figure-handle (axis-figure axis)) ".canvas.draw()")

                                     (setf (gethash axis (interaction-image-cache interaction))
                                           (cons hash
                                                 (pymethod figure-handle "canvas.copy_from_bbox"
                                                           (pyslot-value axis-handle "bbox")))))
                                ;; Reenable all the annotations and then allow drawing again.
                                (dolist (annotation (axis-annotations axis))
                                  (pymethod (annotation-handle annotation) "set_visible" t))
                                (setf *suppress-redraw* nil)))
                             (t (pyexec figure-handle ".canvas.restore_region(" (cdr cached) ")"))))

                     ;; Draw the annotations.
                     ;; Note: the drawing order is in order of position in axis-annotations.
                     (dolist (annotation (axis-annotations axis))
                       (unless (annotation-closed-p annotation)
                         ;; Set the location if it's drag and drop...
                         ;;(when (eq (interaction-mode interaction) :drag-and-drop)
                         (let ((offset-x 0)
                               (offset-y 0))
                           (case (interaction-mode interaction)
                             (:drag-and-drop
                              (when (member annotation (interaction-selected-annotations interaction))
                                ;; The -5 and +5 here offset the drop box to account for the drop
                                ;; shadow.  When you release the drag and drop, the box falls exactly
                                ;; where the shadow lay.
                                ;;
                                ;; The multiply by .71 is a fudge factor. Not sure why it's needed.
                                (setf offset-x (+ -5 (* *drag-and-drop-offset-fudge-factor* (- (interaction-screen-x interaction)
                                                                                               (interaction-mode-change-start-screen-x interaction)))))
                                (setf offset-y (+ 5 (* *drag-and-drop-offset-fudge-factor* (- (interaction-screen-y interaction)
                                                                                              (interaction-mode-change-start-screen-y interaction))))))))
                           (pyexec (annotation-handle annotation) ".set_position("
                                   (annotation-handle annotation) ".get_position() + numpy.asarray((" offset-x ", " offset-y ")))")
                           (ignore-errors (pyexec axis-handle ".draw_artist(" (annotation-handle annotation) ")"))
                           (pyexec (annotation-handle annotation) ".set_position("
                                   (annotation-handle annotation) ".get_position() - numpy.asarray((" offset-x ", " offset-y ")))")
                           )))

                     ;; Blit it to the screen.
                     (pyexec figure-handle ".canvas.blit(" figure-handle ".bbox)"))
                   :next-axis)))))

(defun interaction-loop (&optional (interaction *interaction*) (output *standard-output*))
  "This is the main loop run by the interaction thread. It handles the event queue (e.g. user input like mouse movement, clicks and keyboard) and animations."
  (declare (type interaction interaction))
  (let ((*standard-output* output))
    (loop :until (interaction-done-p interaction)
          :for now = (get-internal-real-time)
          :for delta = (- now (interaction-last-idle-process-time *interaction*))
          :if (< delta +interaction-idle-event-period-internal-units+)
            :do (sleep (/ delta INTERNAL-TIME-UNITS-PER-SECOND))
          :else
            :do (let ((queue (interaction-event-queue interaction)))
                  (when (eq queue (sb-ext:compare-and-swap (interaction-event-queue interaction) queue nil))
                    ;; As we enter here, we've atomically emptied the event-queue and must
                    ;; now process the events therein:
                    (interaction-loop/process-queue
                     interaction
                     (get-internal-real-time)
                     (nreverse queue)))

                  ;; Set the last processed time so we don't draw again until the appropriate time.
                  (setf (interaction-last-idle-process-time *interaction*)
                        (get-internal-real-time)))
          :do (when (> now (interaction-stay-awake-end-time interaction))
                ;; (format t "~%matplotlib interaction thread sleeping...")
                ;; This will cause us to sleep until new events come in.  It's not rigorously thread safe
                ;; but seems to work well in practice. See the notes on interaction-blocking-wait-for-events
                (interaction-blocking-wait-for-events interaction)
                ;; (format t "~%matplotlib interaction thread waking...")
                ))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Interactivity Rendering
;;
;; Because we're going to be drawing, moving, manipulating a variety of annotations, and we want
;; that to be fast, what we do is cache the plot after it's drawn and then just draw the annotations
;; on top. The annotations can be quickly drawn and erased this way, which makes the
;; whole thing feel responsive.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun interaction-cache-axis-image (axis &key force (interaction *interaction*))
  ;; Cache the figure... No annotations nor the legend should be visible.
  ;; If force is true it'll hide and redraw so that it can be cached.
  (declare (type axis axis)
           (type boolean force)
           (type interaction interaction))
  (let ((figure (axis-figure axis))
        (annotations (axis-annotations axis)))

    (when (and force annotations)
      ;; (hide-tooltips axis) ;; TODO this is assuredly wrong right now, but harmless.
      (setf annotations nil))

    (when (null annotations)
      (setf (gethash axis (interaction-image-cache interaction))
            (pymethod (figure-handle figure) "canvas.copy_from_bbox" (pyslot-value (axis-handle axis) "bbox")))
      t)))

(defun interaction/open-annotation (annotation &key (interaction *interaction*) (callback nil))
  (interaction/queue-animation
   interaction
   (animate
    ;; Openining an annotation seems to cause a lot of work, so delay the start time
    ;; a bit so it fades better.
    :started (+ (get-internal-real-time) (/ INTERNAL-TIME-UNITS-PER-SECOND 2))
    :towards :opened
    :annotation-weak-pointer (sb-ext:make-weak-pointer annotation)
    :callback callback)))

(defun interaction/close-annotation (annotation &key (interaction *interaction*) (callback nil))
  (interaction/queue-animation
   interaction
   (animate
    :towards :closed
    :annotation-weak-pointer (sb-ext:make-weak-pointer annotation)
    :callback callback)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Enable and Disable interactivity:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar *interactivity-callbacks* (make-hash-table :weakness :key)
  "References from figure -> interactivity callbacks.")

(defun disable-interactivity (&optional (figure *current-figure*))
  "Disable tooltips on a figure. The callback and all the tooltips are removed."
  (declare (type figure figure))
  (stop-interaction-thread)
  (warn "This should disable interactivity EVERYWHERE on EVERYTHING.")
  (let ((callbacks (gethash figure *interactivity-callbacks*)))
    (loop :for (event callback . _) :on callbacks :by #'cddr
          :do (unregister-callback callback))
    (remhash figure *interactivity-callbacks*)))

;; These trampoline functions exists because we can ONLY send a function to python as a callback and
;; not a quoted symbol.  So we send these really simply functions that just call the real
;; function. This avoids a requirement to re-register callbacks everytime we hotfix them.
(defun interact/button-press/trampoline (time py-event) (interact/button-press time py-event))
(defun interact/button-release/trampoline (time py-event) (interact/button-release time py-event))
(defun interact/motion/trampoline (time py-event) (interact/motion time py-event))
(defun interact/key-down/trampoline (time py-event) (interact/key-down time py-event))
(defun interact/key-up/trampoline (time py-event) (interact/key-up time py-event))
(defun interact/enter-axes/trampoline (time py-event) (interact/enter-axes time py-event))
(defun install-interactivity (&optional (figure *current-figure*))
  "Install interactivity callbacks on a figure, disabling/resetting them if already present"
  (declare (type figure figure))
  (start-interaction-thread)
  (setf *register-annotation-callback* #'(lambda (annotation callback)
                                           (interaction/open-annotation annotation :callback callback)))
  (setf *remove-annotation-callback* #'(lambda (annotation callback)
                                         (interaction/close-annotation annotation :callback callback)))
  (unless (gethash figure *interactivity-callbacks*)
    (setf (gethash figure *interactivity-callbacks*)
          (macrolet ((event-callback-plist ()
                       `(list
                         ,@(loop :for (event . callback)
                                   :in '((:button-press-event . #'interact/button-press/trampoline)
                                         (:button-release-event . #'interact/button-release/trampoline)
                                         (:motion-notify-event . #'interact/motion/trampoline)
                                         (:key-press-event . #'interact/key-down/trampoline)
                                         (:key-release-event . #'interact/key-up/trampoline)
                                         (:axes-enter-event . #'interact/enter-axes/trampoline))
                                 :collect event
                                 :collect `(register-callback
                                            figure
                                            ,event
                                            ,callback)))))
            (event-callback-plist)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Callouts
;;
;; A callout is a big yellow box annotation. It has text and points at something.
;;
;; Example:
;;
;;    (callout (gca) "Hello!" '(0 0) :xytext '(1 1))
;;    (remove-annotation *) ;; this removes it.

(defparameter *callout-style*
  `(:horizontal-alignment "left"
    :vertical-alignment "top"
    :z-order ,SB-EXT:SINGLE-FLOAT-POSITIVE-INFINITY
    :b-box ,(let ((ht (make-hash-table)))
              (setf (gethash "boxstyle" ht) "round,pad=.5")
              (setf (gethash "fc" ht) "yellow")
              (setf (gethash "alpha" ht) 0.5d0)
              (setf (gethash "ec" ht) "k")
              ht)
    :textcoords "offset points"
    :arrow-properties ,(let ((ht (make-hash-table)))
                         (setf (gethash "arrowstyle" ht) "->")
                         (setf (gethash "connectionstyle" ht) "arc3")
                         (setf (gethash "ec" ht) "k")
                         ht)))

(declaim (inline ease-in-quad))
(defun ease-in-quad (x)
  "Quadratic Ease-in function"
  (declare (type double-float x))
  (* x x))

(declaim (inline ease-out-quad))
(defun ease-out-quad (x)
  "Quadratic Ease-out function"
  (declare (type double-float x))
  (- 1d0 (* (- 1d0 x) (- 1d0 x))))

(defun callout-animation (annotation animation-state)
  (let* ((open-factor
           ;; Don't let the transparency be less than 0.9. If you do, the callout will
           ;; appear to fade in / fade out.  Which looks cool, but doesn't feel 'snappy'
           ;; to the user.  Capping it at 0.9 or more makes the callouts 'pop' in a nice
           ;; way.
           (max 0.9d0 (animation-state-open animation-state)))
         (text-factor (ease-out-quad open-factor))
         (raised (animation-state-raise animation-state))
         (select-factor (if (> raised 0d0) 1d0 (animation-state-select animation-state)))
         (hover-factor (animation-state-hover animation-state))
         (lightness (min 1.0 (+ (* 1.0 select-factor)
                                (* 0.8 hover-factor))))
         (bgcolor (list 1.0 1.0 (* 0.8 lightness)))
         (border-color (list (* 0.8 select-factor)
                             (* 0.8 select-factor)
                             (* 0.5 select-factor))))
    (pyexec (annotation-handle annotation) ".get_bbox_patch().set_color(" border-color ")")
    (pyexec (annotation-handle annotation) ".set_backgroundcolor(" bgcolor ")")
    (pyexec (annotation-handle annotation) ".set_alpha(" text-factor ")")
    (cond ((zerop raised)
           (pyexec
            (annotation-handle annotation) ".get_bbox_patch().set_path_effects([matplotlib.patheffects.Normal()])"))
          (t
           (pyexec
            (annotation-handle annotation) ".get_bbox_patch().set_path_effects([matplotlib.patheffects.SimplePatchShadow(offset=(" (* 5.0 raised) ", " (* -5.0 raised) ")), matplotlib.patheffects.Normal()])")))
    (pyexec (annotation-handle annotation) ".get_bbox_patch().set_alpha(" open-factor ")")))

(defun reparent-annotation-from-axis-to-figure (annotation)
  "This idea was taken from mplcursors.

   Move the Annotation's ownership from the Axes to the Figure, so that
   it gets drawn even above twinned axes.  But ann.axes must stay set,
   so that e.g. unit converters get correctly applied."
  (unless (annotation-closed-p annotation)
    (pymethod (annotation-handle annotation) "remove")
    (pyexec (annotation-handle annotation) ".axes = " (axis-handle (annotation-axis annotation)))
    (pyexec (figure-handle (axis-figure (annotation-axis annotation))) ".add_artist(" (annotation-handle annotation) ")")
    (setf (axis-changed-p (annotation-axis annotation)) t)))

(defun callout (axis text xy &rest args
                &key artist xytext
                  horizontal-alignment
                  vertical-alignment
                  z-order
                  xycoords
                  textcoords
                  b-box
                  arrow-properties)
  "A callout is a big yellow box annotation with text and an arrow pointing at something. Tooltips
   are rendered with callouts.  This callout style mimics the mpl_cursors package for visual
   consistency. Returns an annotation structure.

   Example:
     (callout (gca) (format nil \"Two lines~%of text!\") '(0 0) :xytext '(2 -2))"
  (declare (type string text))
  (declare (ignore artist xytext
                   horizontal-alignment
                   vertical-alignment
                   z-order
                   xycoords
                   textcoords
                   b-box
                   arrow-properties))
  (let ((annotation (apply #'annotate axis text xy
                           :interaction-update-fn 'callout-animation
                           (append args *callout-style*))))
    (reparent-annotation-from-axis-to-figure annotation)
    annotation))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Tooltip Builder
;;
;; From matlab we've inherited the idea that your tooltip is comprised of a number
;; of metadata columns that get joined together to build your tooltip.  Our tooltip
;; basis above is more general (any string); this compatibility layer provides
;; the metadata columns and builds the strings for you.
;;
;; (set-tooltips 2 :label "Hello" :data '(2.0 6.0 55))
;; (set-tooltips 1 :label "Blah" :data '("hello" "there" "bob"))
;; (tooltip (gca) 0) ;; show a couple points.
;; (tooltip (gca) 1)
;; (reset-tooltips) ;; Remove the customizations.

(defvar *tooltips-builders* (make-hash-table :weakness :key)
  "A weakly keyed hashtable of axis -> tooltips-builder structure.")
(defstruct tooltips-builder
  "This is a state tracking object, used to build tooltip strings for points.
   These builders are weakly keyed on axis objects via *tooltips-builders*"
  ;; Count is how many columns of metadata, not how many points.
  ;; Columns 0 is X location, column 1 is Y location.
  (count 0 :type (unsigned-byte 4) :read-only nil)

  ;; The labels for each column of metadata.
  (labels (make-array 4 :fill-pointer 0 :adjustable t :initial-element "") :type array :read-only t)

  ;; The data for that column (should match the number of points in the plot, but it's not enforced).
  ;; Each element of data is a simple-vector
  (data (make-array 4 :fill-pointer 0 :adjustable t :initial-element #()) :type array :read-only t)

  ;; Whether this column of metadata will show up or not.
  ;; It's set to T when you populate the column. It's mostly just incase the
  ;; user sets, say, column 15 of metadata without any of columns 3-14. Those
  ;; gap columns would default to not enabled and would not show up.
  (enabled (make-array 4 :fill-pointer 0 :adjustable t :initial-element nil) :type array :read-only t))

(defun rebuild-tooltips (axis)
  "Using the tooltips builder, recompute and redisplay all open tooltips for the axis."
  (declare (type axis axis))
  (let ((builder (gethash axis *tooltips-builders*)))
    (when builder
      (when (axis-p axis)
        (let* ((artist (mpl/get-artist :ax axis :types '(cl-matplotlib::|matplotlib.lines.Line2D|
                                                         cl-matplotlib::|matplotlib.image.AxesImage|)))
               (tooltips (tooltips artist))
               (strings (tooltips-strings tooltips))
               (callouts (tooltips-callouts tooltips)))
          (loop :for i :below (length strings)
                :for callout = (aref callouts i)
                :for new-string-parts
                  = (loop :with labels = (tooltips-builder-labels builder)
                          :with enabled = (tooltips-builder-enabled builder)
                          :with data = (tooltips-builder-data builder)
                          :for j :below (tooltips-builder-count builder)
                          :when (aref enabled j)
                            :collect (list (aref labels j)
                                           (let ((dsv (aref data j)))
                                             (if (< i (length dsv))
                                                 (elt dsv i)
                                                 ""))))
                ;; Colors not working yet. Fix later.
                ;; :for new-string = (print (format nil "~{~{\bf{~a} \textcolor{blue}{~a}~}~^~%~}"
                ;;                                  new-string-parts))
                :for new-string = (format nil "~{~{~a ~a~}~^~%~}" new-string-parts)
                :do (setf (aref strings i) new-string)
                :when (and callout (not (annotation-closed-p callout)))
                  :do (ignore-errors (pymethod (annotation-handle callout) "set_text" new-string)))
          (draw-axis axis))))))

(defun tooltips-builder (axis)
  "Internal use mainly, returns the tooltips-builder structure after resizing"
  (let ((existing (gethash axis *tooltips-builders*)))
    (when existing
      (return-from tooltips-builder (values existing t))))

  (let ((builder (make-tooltips-builder)))
    (multiple-value-bind (artist type)
        (mpl/get-artist :ax axis :types '(cl-matplotlib::|matplotlib.lines.Line2D|
                                          cl-matplotlib::|mpl_toolkits.mplot3d.art3d.Line3D|
                                          cl-matplotlib::|matplotlib.image.AxesImage|))
      (cond ((null artist)
             (format t "~%No line in tooltip builder."))
            ((eq type 'cl-matplotlib::|mpl_toolkits.mplot3d.art3d.Line3D|)
             ;; Populate the X, Y and Z coordinates at this time.
             (setf (tooltips-builder-count builder) 3)
             (adjust-array (tooltips-builder-labels builder) 3 :fill-pointer 2 :initial-contents '("X" "Y" "Z"))
             (adjust-array (tooltips-builder-data builder) 3 :fill-pointer 2)
             (adjust-array (tooltips-builder-enabled builder) 3 :fill-pointer 2)
             (setf (aref (tooltips-builder-enabled builder) 0) t)
             (setf (aref (tooltips-builder-enabled builder) 1) t)
             (setf (aref (tooltips-builder-enabled builder) 2) t)
             (let* ((data (pyeval (artist-handle artist)".get_data_3d()"))
                    (x (elt data 0))
                    (y (elt data 1))
                    (z (elt data 2)))
               (setf (aref (tooltips-builder-data builder) 0) (coerce (undisplace-array-if-possible x) 'vector))
               (setf (aref (tooltips-builder-data builder) 1) (coerce (undisplace-array-if-possible y) 'vector))
               (setf (aref (tooltips-builder-data builder) 2) (coerce (undisplace-array-if-possible z) 'vector))
               (format t "~%X and Y and Z:~%~s~% ~s~%~s" x y z)))
            ((eq type 'cl-matplotlib::|matplotlib.lines.Line2D|)
             ;; Populate the X and Y coordinates at this time.
             (setf (tooltips-builder-count builder) 2)
             (adjust-array (tooltips-builder-labels builder) 2 :fill-pointer 2 :initial-contents '("X" "Y"))
             (adjust-array (tooltips-builder-data builder) 2 :fill-pointer 2)
             (adjust-array (tooltips-builder-enabled builder) 2 :fill-pointer 2)
             (setf (aref (tooltips-builder-enabled builder) 0) t)
             (setf (aref (tooltips-builder-enabled builder) 1) t)
             (let* ((x (pyeval "numpy.array("(artist-handle artist)".get_xdata())"))
                    (y (pyeval "numpy.array("(artist-handle artist)".get_ydata())")))
               (setf (aref (tooltips-builder-data builder) 0) (coerce (undisplace-array-if-possible x) 'vector))
               (setf (aref (tooltips-builder-data builder) 1) (coerce (undisplace-array-if-possible y) 'vector))
               ;; (format t "~%X and Y and Z:~%~s~% ~s" x y)
               ))
            ((eq type 'cl-matplotlib::|matplotlib.image.AxesImage|)
             ;; Populate the X, Y, Z coordinates at this time.
             (setf (tooltips-builder-count builder) 3)
             (adjust-array (tooltips-builder-labels builder) 3 :fill-pointer 3 :initial-contents '("X" "Y" "Z"))
             (adjust-array (tooltips-builder-data builder) 3 :fill-pointer 3)
             (adjust-array (tooltips-builder-enabled builder) 3 :fill-pointer 3)
             (setf (aref (tooltips-builder-enabled builder) 0) t)
             (setf (aref (tooltips-builder-enabled builder) 1) t)
             (setf (aref (tooltips-builder-enabled builder) 2) t)
             (let* ((data (pyeval "numpy.asarray("(artist-handle artist)".get_array())"))
                    (xs nil)
                    (ys nil)
                    (zs nil)
                    (extent (pymethod (artist-handle artist) "get_extent"))
                    (xmin (aref extent 0))
                    ;;(xmax (aref extent 1))
                    (ymin (aref extent 2))
                    ;;(ymax (aref extent 3))
                    )
               (loop :for x :below (array-dimension data 0)
                     :do (loop :for y :below (array-dimension data 1)
                               :for z = (aref data x y)
                               ;; NOTE the x/y transpose in below is intentional.
                               :do (push (+ y ymin) xs)
                               :do (push (+ x xmin) ys)
                               :do (push z zs)))
               (setf (aref (tooltips-builder-data builder) 0) (coerce (nreverse xs) 'vector))
               (setf (aref (tooltips-builder-data builder) 1) (coerce (nreverse ys) 'vector))
               (setf (aref (tooltips-builder-data builder) 2) (coerce (nreverse zs) 'vector))))
            (t
             (format t "~%Unknown line type in tooltip builder.")))
      (setf (gethash axis *tooltips-builders*) builder)
      (values builder nil))))

(defun reset-tooltips (&optional (axis (gca)))
  (remhash axis *tooltips-builders*)
  (tooltips-builder axis)
  (rebuild-tooltips axis))

(defun set-tooltips (number &key (label nil label-provided-p) (data nil data-provided-p) (axis (gca)))
  "Provide a metadata series by number full of information to the
   tooltip-builder, then redraw the tooltips."
  (declare (type (or (eql :add) (unsigned-byte 32)) number))
  (when (or label-provided-p data-provided-p)
    (let ((builder (tooltips-builder axis)))
      (when (eq number :add)
        (setf number (tooltips-builder-count builder)))
      (when (>= number (tooltips-builder-count builder))
        (setf (tooltips-builder-count builder) (+ 1 number))
        (adjust-array (tooltips-builder-labels builder) (+ 1 number) :fill-pointer (+ 1 number) :initial-element "")
        (adjust-array (tooltips-builder-data builder) (+ 1 number) :fill-pointer (+ 1 number):initial-element nil)
        (adjust-array (tooltips-builder-enabled builder) (+ 1 number) :fill-pointer (+ 1 number) :initial-element nil))
      (setf (aref (tooltips-builder-enabled builder) number) t)
      (when label-provided-p
        (setf (aref (tooltips-builder-labels builder) number) label))
      (when data-provided-p
        (let ((data (etypecase data
                      (null nil)
                      (list (coerce data 'vector))
                      (vector data)
                      (array
                       (let ((vector (make-array (array-total-size data))))
                         (replace vector (make-array (array-total-size data) :displaced-to data))
                         vector)))))
          (setf (aref (tooltips-builder-enabled builder) number) (not (null data)))
          (setf (aref (tooltips-builder-data builder) number) data)))
      (rebuild-tooltips axis))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun clear-cl-matplotlib-lisp-state ()
  "Entirely reset Lisp's knowledge of matplotlib. Used for getting a clean state after a reset."
  (stop-interaction-thread)
  (clrhash *interactivity-callbacks*)
  (clrhash *tooltips-builders*)
  (clrhash *tooltips*)
  (clrhash *data-cursors*)
  (setf *interaction* (make-interaction))
  (clear-figure-tracking))
