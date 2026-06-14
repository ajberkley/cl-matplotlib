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
from PyQt6.QtWidgets import QApplication, QMainWindow, QDockWidget, QLabel, QVBoxLayout, QWidget, QRubberBand, QLayout
from PyQt6 import QtCore
from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QMouseEvent, QCloseEvent, QKeyEvent

set_active_figure = None
close_window_callback = None

# We do not let pyplot manage figure activeness, as we need thread local
# active figures (logging can occur simultaneous to user interactive plotting,
# headless figures can be drawn at the same time, etc).
def set_callbacks (activate_figure_callback, close_window_func):
    global set_active_figure, close_window_callback
    set_active_figure = activate_figure_callback
    close_window_callback = close_window_func

from matplotlib.backend_bases import key_press_handler

class MplDockWidget(QDockWidget):
    def __init__(self, title="Plot Dock", parent=None):
        super().__init__(parent)
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating, True)
        self.setAttribute(Qt.WidgetAttribute.WA_DeleteOnClose, True)
        # self.setWindowFlag(Qt.WindowType.FramelessWindowHint)
        # self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint)
        # self.setWindowFlag(Qt.WindowType.Tool)
        # still steals focus when set to floating
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
        layout.addWidget(self.toolbar)
        layout.addWidget(self.canvas)
        self.container = QWidget()
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

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating, True)
        self.setWindowTitle("Matplotlib workbench")

    def maybe_hide(self):
        child_objects = main_window.children()
        # end up with a rubberband object that we need to kill
        important_children = [c for c in child_objects if isinstance(c, MplDockWidget)]
        if len(important_children) == 0:
            self.setVisible(False)

main_window = None

def NewFigure (title="Hello", id=123, docked=True, tabbed=True):
    # Return a figure
    global main_window
    if main_window.isVisible() == False:
        main_window.setVisible(True)
    widget = MplDockWidget(title=f"{title}", parent=main_window)
    widget.unique_figure_id = id
    figure = widget.figure
    DockFigure(figure) # have to make it dockable
    if not docked and not tabbed:
        FloatFigure(figure)
    if tabbed:
        TabFigure(figure)
    #widget.resize(800, 600)
    return figure

def DockFigure (figure):
    figure.dockwidget.setFloating(False)
    main_window.addDockWidget(Qt.DockWidgetArea.TopDockWidgetArea, figure.dockwidget)

def TabFigure (figure):
    figure.dockwidget.setFloating(False)
    widget = figure.dockwidget
    dock_widgets = main_window.findChildren(QDockWidget)
    dock_widgets.remove(widget)
    # find someone who is tabified already if possible
    already_tabbed_widget = [dock_widget for dock_widget in dock_widgets if len(main_window.tabifiedDockWidgets(dock_widget))> 0]
    if already_tabbed_widget:
        main_window.tabifyDockWidget(already_tabbed_widget[0], widget)
    else:
        if len(dock_widgets) > 0:
            main_window.tabifyDockWidget(dock_widgets[0], widget)
        else:
            DockFigure(figure)

def FloatFigure (figure):
    widget = figure.dockwidget
    widget.setFloating(True)
    
def get_windows ():
    global main_window
    child_objects = main_window.children()
    # child_windows = [c for c in child_objects if c.isWindow()]
    return child_objects

from collections import Counter

def count_duplicates(items):
    counts = Counter(items)
    duplicates = {item: count for item, count in counts.items()}
    return duplicates

def get_axis_used_colors (axes):
    colors = []
    def get_colors(line):
        return [line.get_color(), line.get_markeredgecolor(), line.get_markerfacecolor()]

    colors = [get_colors(child) for child in axes.get_children() if isinstance(child,matplotlib.lines.Line2D)]
    colors_flat = [color for sublist in colors for color in sublist]
    return count_duplicates(colors_flat)

counter = 1

import matplotlib

def start_app (try_process_message):
    global main_window
    matplotlib.use("QtAgg")
    app = QtWidgets.QApplication(["MATLAB R2018b"])
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
    timer_maybe_hide.timeout.connect(lambda: main_window.maybe_hide())
    timer_maybe_hide.start(500);
    app.exec()
    print("No more windows, returning to default message_dispatch_loop")
