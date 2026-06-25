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
from PyQt6.QtWidgets import QApplication, QMainWindow, QDockWidget, QLabel, QVBoxLayout, QWidget, QRubberBand, QLayout, QPushButton
from PyQt6 import QtCore
from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QMouseEvent, QCloseEvent, QKeyEvent

set_active_figure = None
close_window_callback = None
legend_toggle_func = None

# We do not let pyplot manage figure activeness, as we need thread local
# active figures (logging can occur simultaneous to user interactive plotting,
# headless figures can be drawn at the same time, etc).
def set_callbacks (activate_figure_callback, close_window_func, legend_toggle_callback):
    global set_active_figure, close_window_callback, legend_toggle_func
    set_active_figure = activate_figure_callback
    close_window_callback = close_window_func
    legend_toggle_func = legend_toggle_callback

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

class MegaWidget(QWidget):
    def sizeHint(self):
        #print(f"MegaWidget parent is {self.parent()}")
        #self.parent().size()
        return QtCore.QSize(2000, 2000)

class MplDockWidget(QDockWidget):
    def __init__(self, title="Plot Dock", parent=None, floating=False):
        super().__init__(parent)
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating, True)
        self.setAttribute(Qt.WidgetAttribute.WA_DeleteOnClose, True)
        self.setAllowedAreas(Qt.DockWidgetArea.AllDockWidgetAreas)
        self.setSizePolicy(QtWidgets.QSizePolicy.Policy.MinimumExpanding, QtWidgets.QSizePolicy.Policy.MinimumExpanding)
        # self.setMinimumHeight(200) # these do not seem necessary or effective
        # self.setMinimumWidth(200)
        self.topLevelChanged.connect(self.handle_dock_change)
        self.floating = floating
        # if floating:
        #     self.setFeatures(self.features() & ~QDockWidget.DockWidgetFeature.DockWidgetFloatable)
        self.setWindowTitle(title)
        layout = QVBoxLayout()
        self.closed = False
        self.figure = Figure()
        self.figure.dockwidget = self
        self.canvas = FigureCanvas(self.figure)
        self.window_title = title
        self.waiting_on_ginput = 0
        self.ginputs = []
        def update_active_figure (event):
            if not self.closed:
                if (self.waiting_on_ginput > 0) and event.inaxes:
                    self.ginputs.append([event.xdata, event.ydata])
                    self.waiting_on_ginput = self.waiting_on_ginput - 1
                else:
                    set_active_figure(self.unique_figure_id, event.inaxes)
        self.canvas.mpl_connect('button_press_event', update_active_figure)
        self.toolbar = NavigationToolbar(self.canvas, self)
        button = QPushButton("Legend")
        self.toolbar.addWidget(button)
        button.clicked.connect(lambda: legend_toggle_func(self.unique_figure_id))
        layout.addWidget(self.toolbar)
        layout.addWidget(self.canvas)
        self.container = MegaWidget()
        self.container.setLayout(layout)
        self.setWidget(self.container)
        self.canvas.setFocusPolicy(Qt.FocusPolicy.ClickFocus)
        self.canvas.mpl_connect('key_press_event', self.on_key_press)
        self.figure.set_layout_engine(matplotlib.layout_engine.ConstrainedLayoutEngine())
        #self.canvas.setFocus()
        
    def on_key_press(self, event):
        # implement standard matplotlib keypress behavior
        if event.key == 'ctrl+w':
            self.close_window()
        key_press_handler(event, self.canvas, self.toolbar)

    def mousePressEvent(self, event: QMouseEvent):
        if not self.closed:
            if event.button() == Qt.MouseButton.LeftButton:
                axes = self.figure.get_axes()
                if len(axes) > 0:
                    set_active_figure(self.unique_figure_id, self.figure.get_axes()[0])
                else:
                    set_active_figure(self.unique_figure_id, None)

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

    def handle_dock_change(self, is_floating):
        # Floating window in a MainWindow container wants
        # to dock to the main_window.  Cannot do the work
        # here or segfault.
        if is_floating:
            with other_windows_lock:
                if self.floating:
                    to_be_docked.append(self)

def important_children(window):
    child_objects = window.children()
    # end up with a rubberband object that we need to kill
    important_children = [c for c in child_objects if isinstance(c, MplDockWidget)]
    return len(important_children)
    
class MainWindow(QMainWindow):
    def __init__(self, title="Matplotlib workbench"):
        super().__init__()
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating, True)
        self.setWindowTitle(title)
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

def NewFigure (title="Hello", id=123, docked=True, tabbed=True):
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
        widget = MplDockWidget(title=f"{title}", parent=parent, floating=floating)
        widget.unique_figure_id = id
        figure = widget.figure
        DockFigure(figure, parent)
    else:
        widget = MplDockWidget(title=f"{title}", parent=main_window, floating=floating)
        widget.unique_figure_id = id
        figure = widget.figure
        DockFigure(figure, main_window)
        if tabbed:
            TabFigure(figure)

            
    return figure

def DockFigure (figure, parent):
    figure.dockwidget.setFloating(False)
    parent.addDockWidget(Qt.DockWidgetArea.TopDockWidgetArea, figure.dockwidget)

def TabFigure (figure):
    figure.dockwidget.setFloating(False)
    widget = figure.dockwidget
    dock_widgets = main_window.findChildren(QDockWidget)
    if widget in dock_widgets: dock_widgets.remove(widget)
    # find someone who is tabified already if possible
    already_tabbed_widget = [dock_widget for dock_widget in dock_widgets if len(main_window.tabifiedDockWidgets(dock_widget))> 0]
    if already_tabbed_widget:
        main_window.tabifyDockWidget(already_tabbed_widget[0], widget)
    else:
        if len(dock_widgets) > 0:
            main_window.tabifyDockWidget(dock_widgets[0], widget)
        else:
            DockFigure(figure, main_window)

def FloatFigure (figure):
    widget = figure.dockwidget
    widget.setFloating(True)
    
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
                main_window.addDockWidget(Qt.DockWidgetArea.TopDockWidgetArea, win);
                win.floating = False
                TabFigure(win.figure)
                win.show()

            to_be_docked = []

            for win in to_be_freed:
                old_parent = win.parent()
                old_parent.removeDockWidget(win);
                new_parent = MainWindow(old_parent.windowTitle())
                new_parent.setVisible(True)
                new_parent.show()
                # May squishify
                DockFigure(win.figure, new_parent) # have to make it dockable
                other_windows.append(new_parent)
                win.show()

            to_be_freed = []

    timer_maybe_hide.timeout.connect(maybe_hide_windows);
    timer_maybe_hide.start(500);
    app.exec()
    print("No more windows, returning to default message_dispatch_loop")
