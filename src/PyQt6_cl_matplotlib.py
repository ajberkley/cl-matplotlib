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
from PyQt6.QtWidgets import QApplication, QMainWindow, QDockWidget, QLabel, QVBoxLayout, QWidget
from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QMouseEvent, QCloseEvent

set_active_figure = None
close_window_callback = None

# We do not let pyplot manage figure activeness, as we need thread local
# active figures (logging can occur simultaneous to user interactive plotting,
# headless figures can be drawn at the same time, etc).
def set_callbacks (activate_figure_callback, close_window_func):
    global set_active_figure, close_window_callback
    set_active_figure = activate_figure_callback
    close_window_callback = close_window_func
    
class MplDockWidget(QDockWidget):
    def __init__(self, title="Plot Dock", parent=None):
        super().__init__(title, parent)
        layout = QVBoxLayout(parent)
        self.closing = False
        self.figure = Figure()
        self.figure.shutdown = self.close_window
        self.canvas = FigureCanvas(self.figure)
        self.name = title
        def update_active_figure (event):
            if not self.closing:
                set_active_figure(self.name, event.inaxes)
        self.canvas.mpl_connect('button_press_event', update_active_figure)
        self.toolbar = NavigationToolbar(self.canvas, self)
        layout.addWidget(self.toolbar)
        layout.addWidget(self.canvas)
        self.container = QWidget()
        self.container.setLayout(layout)
        self.setWidget(self.container)

    def mousePressEvent(self, event: QMouseEvent):
        # This handles mouse click events outside the active matplotlib
        # areas.
        if not self.closing:
            if event.button() == Qt.MouseButton.LeftButton:
                #local_pos = event.position()
                # Do better hear, search for which axis!
                axes = self.figure.get_axes()
                if len(axes) > 0:
                    set_active_figure(self.name, self.figure.get_axes()[0])
                else:
                    set_active_figure(self.name, None)

        super().mousePressEvent(event)

    def close_window (self):
        self.closing = True
        close_window_callback(self.name)
        self.close()
        
    def closeEvent(self, event: QCloseEvent):
        self.closing = True
        super().closeEvent(event)

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Matplotlib workbench")
        self.resize(800, 600)

main_window = None

def NewFigure (title="Hello"):
    # Return a figure
    widget = MplDockWidget(title)
    main_window.addDockWidget(Qt.DockWidgetArea.RightDockWidgetArea, widget)
    return widget.figure

def draw_lots_of_patches (xs, ys, ws, hs, ax):
    def make_rectangle(x, y, w, h):
        return matplotlib.patches.Rectangle((x, y), w, h)

    patches = matplotlib.collections.PolyCollection(list(map(make_rectangle, xs, ys, ws, hs)), match_original=True)
    ax.add_collection(patches)

counter = 1

import matplotlib

def start_app (try_process_message):
    global main_window
    print("Starting!")
    matplotlib.use("QtAgg")
    app = QtWidgets.QApplication([""])
    main_window = MainWindow()
    main_window.show()
    timer = QTimer()
    def process_messages():
        global counter
        counter = counter + 1
        try_process_message(blocking=False)
    timer.timeout.connect(process_messages);
    timer.start(100);
    print("Going into main loop, will return when all windows closed")
    app.exec()
    print("No more windows, returning to default message_dispatch_loop")
