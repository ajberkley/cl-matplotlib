# BUGS:
#  Clicking on an errorbar series in the legend hides it properly but does not
#  modify the visibility in the legend.  This is because the legend_handles does
#  not contain all (or even the relevant) artists in the legend.  This is a bug in
#  matplotlib where they just store artists[0] instead of creating a container for
#  them.  Override errorbar legend handler to return a container of artists instead
#  of a list of artists... hopefully picking will still work.  Urgh.

#  Trying to un-dock a window is OK for floating window managers, but not for Awesome,
#  as they are not truly top level windows.  We support floating windows on creation
#  by putting them in their own individual MainWindow.  When one clicks or drags them
#  out of that they become docked in the main window.  We do not support freeing a window
#  once it is docked yet (have to override the docking/freeing button in the title bar)
#  because a drag motion may be "re-arrange windows"
import sys
import time
import numpy as np
import PyQt6

from matplotlib.backends.backend_qtagg import FigureCanvas
from matplotlib.backends.backend_qtagg import \
    NavigationToolbar2QT as NavigationToolbar
from matplotlib.backends.qt_compat import QtWidgets
from matplotlib.figure import Figure
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas

import sys
from PyQt6.QtWidgets import QApplication, QMainWindow, QDockWidget, QLabel, QHBoxLayout, QVBoxLayout, QWidget, QRubberBand, QLayout, QPushButton, QStyle, QFrame
from PyQt6 import QtCore
from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QMouseEvent, QCloseEvent, QKeyEvent

set_active_figure = None
close_window_callback = None
legend_toggle_func = None
copy_callback = lambda trace: None
# cut_callback = lambda trace: None
paste_callback = lambda: None
undo_callback = lambda: None
redo_callback = lambda: None
delete_callback = lambda: None
new_figure_func = lambda: None
# We do not let pyplot manage figure activeness, as we need thread local
# active figures (logging can occur simultaneous to user interactive plotting,
# headless figures can be drawn at the same time, etc).
def set_callbacks (activate_figure_callback, close_window_func, legend_toggle_callback, copy_callback_in, paste_callback_in, undo_callback_in, redo_callback_in, delete_callback_in, new_figure_callback_in):
    global set_active_figure, close_window_callback, legend_toggle_func, copy_callback, paste_callback, undo_callback, redo_callback
    global delete_callback, new_figure_func
    set_active_figure = activate_figure_callback
    close_window_callback = close_window_func
    legend_toggle_func = legend_toggle_callback
    copy_callback = copy_callback_in
    paste_callback = paste_callback_in
    undo_callback = undo_callback_in
    redo_callback = redo_callback_in
    delete_callback = delete_callback_in
    new_figure_func = new_figure_callback_in

from matplotlib.backend_bases import key_press_handler
from matplotlib.backend_tools import ToolBase, ToolToggleBase

class DraggableLabel:
    def __init__(self, label):
        label.set_zorder(100) # stay on top
        self.label = label
        self.got_artist = False
        self.canvas = label.figure.canvas
        
        # Enable picking on the text artist
        self.label.set_picker(True)
        
        # Connect canvas events to our functions
        self.canvas.mpl_connect('pick_event', self.on_pick)
        self.canvas.mpl_connect('motion_notify_event', self.on_move)
        self.canvas.mpl_connect('button_release_event', self.on_release)

    def on_pick(self, event):
        # Confirm that the clicked object is our label
        if event.artist == self.label:
            self.got_artist = True

    def on_move(self, event):
        if self.got_artist:
            inv_axes_transform = self.label.axes.transAxes.inverted()
            axes_local_x, axes_local_y = inv_axes_transform.transform((event.x, event.y))
            self.label.set_in_layout(False)
            self.label.set_position((axes_local_x, axes_local_y))
            self.canvas.draw_idle()

    def on_release(self, event):
        self.got_artist = False

def enable_draggable_title(title):
    return DraggableLabel(title)

def enable_legend_interactivity(ax, leg):
    # Caller needs to store these, otherwise
    # will get gc'ed because the callback references
    # are weak!
    return InteractiveLegend(ax, leg)

import math

def close_to(x0, y0, x1, y1):
    dist = math.sqrt((x0-x1)**2 + (y0-y1)**2)
    if dist > 20:
        return False
    else:
        return True

class InteractiveLegend(object):
    def __init__(self, axes, legend):
        self.legend = legend
        self.axes = axes
        self.fig = axes.figure

        self.legend_handle_to_axes_handle = self._build_lookups(legend)
        self._setup_connections()

        self.fig.canvas.draw()

    def _setup_connections(self):
        for artist in self.legend.texts + self.legend.legend_handles:
            artist.set_picker(10) # 10 points tolerance

        self.fig.canvas.mpl_connect('pick_event', self.on_pick)
        self.fig.canvas.mpl_connect('button_press_event', self.on_click)
        self.fig.canvas.mpl_connect('button_release_event', self.on_release)
        

    def _build_lookups(self, legend):
        [handles, labels] = self.axes.get_legend_handles_labels()
        legend_handles = legend.legend_handles
        legend_handle_to_axes_handle = {}
        for (legend_handle, axes_handle) in zip(legend_handles,handles):
            legend_handle_to_axes_handle[legend_handle] = axes_handle
        
        self.pending_actions = [];

        return legend_handle_to_axes_handle

    def toggle_visible(self, legend_handle):
        if not legend_handle.get_visible() or legend_handle.get_alpha() == 0.2:
            visible = False
        else:
            visible = True
        self.set_visible(legend_handle, not visible)

    def set_all_visible(self, element, visible, alpha):
        if(isinstance(element, matplotlib.container.Container)):
            self.set_all_visible(element.get_children(), visible, alpha)
        elif(isinstance(element, tuple) or isinstance(element, list)):
            for el in element:
                self.set_all_visible(el, visible, alpha)
        else:
            element.set_visible(visible)
            if alpha:
                element.set_alpha(alpha)

    def set_visible(self, legend_handle, visible):
        if legend_handle in self.legend_handle_to_axes_handle:
            axes_handle = self.legend_handle_to_axes_handle[legend_handle]
            self.set_all_visible(legend_handle, True, 1.0 if visible else 0.2)
            self.set_all_visible(axes_handle, visible, None)
        
    def on_pick(self, event):
        # left button toggles visibility
        self.pending_actions = []
        handle = event.artist
        if handle in self.legend_handle_to_axes_handle.keys():
            def toggle (new_event):
                if close_to(event.mouseevent.x, event.mouseevent.y, new_event.x, new_event.y):
                    self.toggle_visible(handle)
                self.pending_actions = []
                self.fig.canvas.draw()
            self.pending_actions.append(toggle)

    def on_release(self, event):
        [action(event) for action in self.pending_actions]
        self.pending_actions = []
            
    def on_click(self, event):
        # Clicking right button hides all except one you are over
        # (it also triggers on_pick on release)
        # middle button makes all visible except current one
        if event.button == 3:
            visible = False
        elif event.button == 2:
            visible = True
        else:
            return
        for legend_handle in self.legend_handle_to_axes_handle.keys():
            self.set_visible(visible, legend_handle)
        self.fig.canvas.draw()

import threading

main_window = None
other_windows_lock = threading.Lock()
other_windows = []
to_be_docked = []
to_be_freed = []

class MyNewTitleBarWidget(QWidget):
    def __init__(self, window, dock_callback):
        super().__init__()
        default_height = self.style().pixelMetric(QStyle.PixelMetric.PM_TitleBarHeight)
        # self.setFixedHeight(default_height)
        self.window = window
        self.layout = QHBoxLayout()
        self.setLayout(self.layout)
        self.closeButton = QPushButton()
        self.toggleButton = QPushButton()
        self.title_label = QLabel(self)
        self.title_label.setStyleSheet("font-size: 13px;")
        self.layout.addWidget(self.title_label)
        self.layout.addStretch()
        self.layout.addWidget(self.toggleButton)
        self.layout.addWidget(self.closeButton)

        toggle_icon = self.closeButton.style().standardIcon(QStyle.StandardPixmap.SP_TitleBarNormalButton);
        close_icon = self.closeButton.style().standardIcon(QStyle.StandardPixmap.SP_DockWidgetCloseButton);
        self.closeButton.setIcon(close_icon)
        self.toggleButton.setIcon(toggle_icon)
        default_height = round(0.6*default_height)
        self.closeButton.setFixedHeight(default_height)
        self.toggleButton.setFixedHeight(default_height)
        self.closeButton.setFixedWidth(default_height)
        self.toggleButton.setFixedWidth(default_height)
        self.closeButton.clicked.connect(self.window.close)
        self.toggleButton.clicked.connect(dock_callback)

class MegaWidget(QWidget):
    # def __init__(self):
    #     super().__init__()
        # self.setFrameShape(QFrame.Shape.Box)
        # self.setFrameShadow(QFrame.Shadow.Raised)

    def sizeHint(self):
        #print(f"MegaWidget parent is {self.parent()}")
        #self.parent().size()
        return QtCore.QSize(2000, 2000)

class MplDockWidget(QDockWidget):
    def __init__(self, title="Plot Dock", parent=None, floating=False, size_inches=None, dpi=None):
        super().__init__(parent)
        self.title_bar_widget = MyNewTitleBarWidget(self, self.handle_click_dock)
        self.setTitleBarWidget(self.title_bar_widget)
        self.setWindowTitle(title)        
        self.window_title = title

        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating, True)
        self.setAttribute(Qt.WidgetAttribute.WA_DeleteOnClose, True)
        self.setAllowedAreas(Qt.DockWidgetArea.AllDockWidgetAreas)
        self.setSizePolicy(QtWidgets.QSizePolicy.Policy.MinimumExpanding, QtWidgets.QSizePolicy.Policy.MinimumExpanding)
        # self.setMinimumHeight(200) # these do not seem necessary or effective
        # self.setMinimumWidth(200)

        # self.topLevelChanged.connect(self.handle_dock_change)
        self.floating = floating

        self.closed = False
        self.figure = Figure(figsize=size_inches,dpi=dpi)
        self.figure.dockwidget = self
        self.canvas = FigureCanvas(self.figure)
        self.waiting_on_ginput = 0
        self.ginputs = []
        def update_active_figure (event):
            self.clear_highlight()
            if not self.closed:
                if (self.waiting_on_ginput > 0) and event.inaxes:
                    self.ginputs.append([event.xdata, event.ydata])
                    self.waiting_on_ginput = self.waiting_on_ginput - 1
                else:
                    set_active_figure(self.unique_figure_id, event.inaxes)
        self.canvas.mpl_connect('button_press_event', update_active_figure)
        self.toolbar = NavigationToolbar(self.canvas, self)
        button = QPushButton("Legend")
        button_newfig = QPushButton("NewFig")
        self.toolbar.addWidget(button_newfig)
        self.toolbar.addWidget(button)
        global new_figure_func
        button_newfig.clicked.connect(lambda: new_figure_func())
        button.clicked.connect(lambda: legend_toggle_func(self.unique_figure_id))
        layout =QVBoxLayout()
        layout.addWidget(self.toolbar)
        layout.addWidget(self.canvas)
        self.container = MegaWidget()
        self.container.setLayout(layout)
        self.setWidget(self.container)
        self.canvas.setFocusPolicy(Qt.FocusPolicy.ClickFocus)
        self.canvas.mpl_connect('key_press_event', self.on_key_press)
        self.figure.set_layout_engine(matplotlib.layout_engine.ConstrainedLayoutEngine())
        self.visibilityChanged.connect(self.on_visibility_changed)
        self.selected_data = None
        self.highlight_artist = None
        self.highlight_time = time.time()
        self.canvas.mpl_connect('pick_event', self.on_pick)

    def setWindowTitle(self, title):
        self.title_bar_widget.title_label.setText(title)
        super().setWindowTitle(title)
        
    def on_key_press(self, event):
        # implement standard matplotlib keypress behavior
        if event.key == 'ctrl+w':
            self.close_window()
        if event.key == 'ctrl+c' or event.key == 'ctrl+x' or event.key == 'delete':
            if self.selected_data:
                global copy_callback
                copy_callback(self.selected_data)
                self.clear_highlight()
        if event.key == 'ctrl+v':
            global paste_callback
            paste_callback()  # by clicking on the right axis, liap knows which axis to paste to
        if event.key == 'ctrl+z':
            global undo_callback
            undo_callback()
        if event.key == 'ctrl+Z':
            global redo_callback
            redo_callback()
        if event.key == 'delete' or event.key == 'ctrl+x':
            global delete_callback
            self.clear_highlight()
            # trace_id and axis_id
            delete_callback(self.selected_data[-2], self.selected_data[-1])
        key_press_handler(event, self.canvas, self.toolbar)

    def make_active(self):
        set_active_figure(self.unique_figure_id, None)

    def mousePressEvent(self, event: QMouseEvent):
        self.clear_highlight()
        if not self.closed:
            if event.button() == Qt.MouseButton.LeftButton:
                self.make_active()

        super().mousePressEvent(event)

    def get_ginputs (self):
        results = self.ginputs;
        self.ginputs = [];
        return results
        
    def clean_up_details (self):
        if not self.closed:
            self.closed = True
            close_window_callback(self.unique_figure_id)
            main_window.removeDockWidget(self)
            self.deleteLater()
        
    def close_window (self):
        if not self.closed:
            self.clean_up_details()
            self.close()
        
    def closeEvent(self, event: QCloseEvent):
        if not self.closed:
            self.clean_up_details()
        super().closeEvent(event)

    def handle_click_dock(self):
        # Cannot do the work here or segfault.
        # Here we handle floating windows docking or
        # docking windows floating when the dock button is pressed
        if self.floating:
            with other_windows_lock:
                to_be_docked.append(self)
        else:
            with other_windows_lock:
                to_be_freed.append(self)

    def on_visibility_changed(self, visible: bool):
        if visible:
            # print(f"{self.unique_figure_id} is now visible")
            self.make_active()

    def highlight_data(self, artist, x, y):
        self.highlight_artist, = artist.axes.plot(x,y,linewidth=10,linestyle=":",color='#90d5ff',alpha=0.7,label="_highlight")
        self.canvas.draw_idle()

    def clear_highlight(self, force=False):
        if(force or ((time.time()-0.5) > self.highlight_time)):
            if self.highlight_artist:
                try:
                    self.highlight_artist.remove();
                    self.canvas.draw_idle()
                except Exception:
                    pass
    
    def on_pick(self, event):
        artist = event.artist
        self.clear_highlight(force=True)
        label = artist.get_label()
        x_data = artist.get_xdata()
        y_data = artist.get_ydata()
        self.highlight_data(artist, x_data, y_data)
        self.highlight_time = time.time()
        marker = artist.get_marker()
        linestyle = artist.get_linestyle()
        linecolor = artist.get_color()
        markercolor = artist.get_markerfacecolor()
        # axes_id and trace_id uniquely identify an artist
        trace_id = artist.axes.get_children().index(artist)
        axes_id = artist.figure.get_axes().index(artist.axes)
        self.selected_data = (x_data, y_data, label, marker, linestyle, linecolor, markercolor, trace_id, axes_id)

def important_children(window):
    child_objects = window.children()
    # end up with a rubberband object that we need to kill
    important_children = [c for c in child_objects if isinstance(c, MplDockWidget)]
    return len(important_children)
    
class MainWindow(QMainWindow):
    def __init__(self, title="Matplotlib workbench"):
        super().__init__()
        self.setDockNestingEnabled(True)
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating, True)
        self.setWindowTitle(title)
        self.setMinimumSize(400,400)
        # Need a central widget otherwise cannot access all four dock areas
        # But it also sometimes is the cause of the TopDockWidgetArea getting
        # small.  When no one is docked, maybe I have to re-add a Central Widget?
        self.centralWidget = QWidget(self);
        self.centralWidget.resize(0, 0)
        self.centralWidget.setMaximumSize(0,0)
        self.setCentralWidget(self.centralWidget);

    def maybe_hide(self):
        if important_children(self) == 0:
            self.setVisible(False)

    def maybe_close(self):
        if important_children(self) == 0:
            self.close();
            return True
        else:
            return False

def NewFigure (title="Hello", id=123, docked=True, tabbed=True, size_inches=None, dpi=None):
    # Return a figure
    floating = (not docked) and (not tabbed)
    global main_window
    if main_window.isVisible() == False:
        main_window.setVisible(True)

    if floating:
        global other_windows
        parent = MainWindow(title)
        parent.setVisible(True)
        with other_windows_lock:
            other_windows.append(parent)
        widget = MplDockWidget(title=f"{title}", parent=parent, floating=floating, size_inches=size_inches, dpi=dpi)
        widget.unique_figure_id = id
        figure = widget.figure
        widget.setFloating(False)
        parent.addDockWidget(Qt.DockWidgetArea.TopDockWidgetArea, widget)
        widget.setFeatures(QDockWidget.DockWidgetFeature.NoDockWidgetFeatures)
    else:
        widget = MplDockWidget(title=f"{title}", parent=None, floating=floating)
        widget.unique_figure_id = id
        figure = widget.figure
        if tabbed:
            TabFigure(figure)
        else:
            DockFigure(figure, main_window)
    return figure

# Change figure status after the fact
def FloatFigure (figure, parent=None):
    if FigureWindowStatus(figure) == "floating":
        return True
    global to_be_freed
    to_be_freed.append(figure.dockwidget)

def DockFigure (figure, parent=None): # this could be untabify
    if FigureWindowStatus(figure) == "docked":
        return True
    global main_window
    if parent == None:
        parent = main_window

    DockWindow(figure.dockwidget, main_window)

    if parent.isVisible() == False:
        parent.setVisible(True)

def FigureWindowStatus (figure):
    "Returns 'docked' 'floating' or 'tabbed'"
    global main_window
    widget = figure.dockwidget
    if widget.parent() == main_window:
        if main_window.tabifiedDockWidgets(widget):
            return "tabbed"
        elif widget in main_window.findChildren(QDockWidget):
            return "docked"
        else:
            return "being constructed"
    else:
        return "floating"
    
def TabFigure (figure):
    if not FigureWindowStatus(figure) == "tabbed":
        figure.dockwidget.setFloating(False)
        figure.dockwidget.setFeatures(QDockWidget.DockWidgetFeature.DockWidgetMovable|QDockWidget.DockWidgetFeature.DockWidgetClosable)
        widget = figure.dockwidget
        dock_widgets = main_window.findChildren(QDockWidget)
        if widget in dock_widgets: dock_widgets.remove(widget)
        # find someone who is tabified already if possible
        already_tabbed_widget = [dock_widget for dock_widget in dock_widgets if main_window.tabifiedDockWidgets(dock_widget)]
        if already_tabbed_widget:
            main_window.tabifyDockWidget(already_tabbed_widget[0], widget)
        else:
            if len(dock_widgets) > 0:
                main_window.tabifyDockWidget(dock_widgets[0], widget)
            else:
                if not FigureWindowStatus(figure) == "docked":
                    DockFigure(figure, main_window)

from collections import Counter

def count_duplicates(items):
    counts = Counter(items)
    duplicates = {item: count for item, count in counts.items()}
    return duplicates

def get_axis_used_colors (axes):
    colors = []

    def get_colors(obj):
        if isinstance(obj, matplotlib.lines.Line2D):
            return [obj.get_color(), obj.get_markeredgecolor(), obj.get_markerfacecolor()]
        elif isinstance(obj, matplotlib.patches.Patch):
            return [obj.get_facecolor()[0:3]]  # maybe has alpha
        else:
            return []
    
    def get_line_colors(line):
        return [line.get_color(), line.get_markeredgecolor(), line.get_markerfacecolor()]

    def get_patch_facecolor(patch):
        return [patch.get_facecolor()]
    
    colors = [get_colors(child) for child in axes.get_children()]
    colors_flat = [color for sublist in colors for color in sublist]
    return count_duplicates(colors_flat)

def DockWindow (dockwidget, window):
    "Dock DOCKWIDGET into MainWindow WINDOW by maybe splitting existing dockwidgets"
    dockwidget.setFeatures(QDockWidget.DockWidgetFeature.DockWidgetMovable|QDockWidget.DockWidgetFeature.DockWidgetClosable)
    visible_children = [d for d in window.findChildren(QDockWidget) if d.isVisible() and not window.tabifiedDockWidgets(d)] # this way we only see one top level window, not the tabbed ones
    if visible_children:
        widest_window = max(visible_children, key = lambda c: c.width())
        tallest_window = max(visible_children, key = lambda c: c.height())
        # print(f"widest_window {widest_window} tallest_window {tallest_window}")
        if widest_window.width() > tallest_window.height():
            window.splitDockWidget(widest_window, dockwidget, Qt.Orientation.Horizontal)
        else:
            window.splitDockWidget(tallest_window, dockwidget, Qt.Orientation.Vertical)
    else:
        window.addDockWidget(Qt.DockWidgetArea.TopDockWidgetArea, dockwidget)


counter = 1

import matplotlib

def start_app (try_process_message):
    global main_window
    matplotlib.use("QtAgg")
    app = QtWidgets.QApplication(["MATLAB R2018b"])
    app.setQuitOnLastWindowClosed(False)
    # parameter to QApplication sets WM_CLASS, here I am matching a local
    # override to prevent focus stealing
    main_window = MainWindow()
    timer = QTimer()
    def process_messages():
        global counter
        counter = counter + 1
        try_process_message(blocking=False)
    timer.timeout.connect(process_messages);
    timer.start(1);
    timer_maybe_hide = QTimer()
    def maybe_hide_windows ():
        global other_windows, main_window
        main_window.maybe_hide()
        dead_windows = [other_window for other_window in other_windows if other_window.maybe_close()]
        with other_windows_lock:
            for dead_window in dead_windows:
                other_windows.remove(dead_window);
                
            global to_be_docked, to_be_freed
            
            for win in to_be_docked:
                parent = win.parent()
                parent.removeDockWidget(win);
                win.setParent(main_window);
                DockWindow(win, main_window)
                win.floating = False
                win.is_floating = False
                TabFigure(win.figure)
                win.show()
                
            if to_be_docked:
                if main_window.isVisible() == False:
                    main_window.setVisible(True)

            to_be_docked = []

            for win in to_be_freed:
                old_parent = win.parent()
                old_parent.removeDockWidget(win);
                new_parent = MainWindow(win.windowTitle())
                new_parent.setVisible(True)
                new_parent.show()
                new_parent.addDockWidget(Qt.DockWidgetArea.TopDockWidgetArea, win)
                win.setFeatures(QDockWidget.DockWidgetFeature.NoDockWidgetFeatures)
                other_windows.append(new_parent)
                win.floating = True
                win.is_floating = True
                win.show()

            to_be_freed = []

    timer_maybe_hide.timeout.connect(maybe_hide_windows);
    timer_maybe_hide.start(500);
    app.exec()
    print("No more windows, returning to default message_dispatch_loop")
