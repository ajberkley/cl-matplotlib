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

class MplDockWidget(QDockWidget):
    def __init__(self, title="Plot Dock", parent=None):
        super().__init__(title, parent)
        layout = QVBoxLayout(parent)
        self.figure = Figure()
        self.canvas = FigureCanvas(self.figure)
        self.toolbar = NavigationToolbar(self.canvas, self)
        layout.addWidget(self.toolbar)
        layout.addWidget(self.canvas)
        self.container = QWidget()
        self.container.setLayout(layout)
        self.setWidget(self.container)

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("PyQt Matplotlib Docking Example")
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
