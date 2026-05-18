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
from PyQt6.QtGui import QMouseEvent

# Our figures are not managed by pyplot, as written here.  We could use it
# to track active figures, etc, but it seems better if we leave control to
# ourselves.
active_figure = None
active_axis = None

def set_active_figure (figure, event):
    global active_figure, active_axis
    print(f"Switching to figure: {figure}")
    active_figure = figure
    if event:
        print(f"Switching to axis: {event.inaxes}")
        active_axis = event.inaxes
    else:
        active_axis = None
    

class MplDockWidget(QDockWidget):
    def __init__(self, title="Plot Dock", parent=None):
        super().__init__(title, parent)
        layout = QVBoxLayout(parent)
        self.figure = Figure()
        self.canvas = FigureCanvas(self.figure)
        self.canvas.mpl_connect('button_press_event', lambda event: set_active_figure(self.figure, event))
        self.toolbar = NavigationToolbar(self.canvas, self)
        layout.addWidget(self.toolbar)
        layout.addWidget(self.canvas)
        self.container = QWidget()
        self.container.setLayout(layout)
        self.setWidget(self.container)

    def mousePressEvent(self, event: QMouseEvent):
        # This handles mouse click events outside the active matplotlib
        # areas.
        if event.button() == Qt.MouseButton.LeftButton:
            #local_pos = event.position()
            set_active_figure(self.figure, None)

        super().mousePressEvent(event)

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
