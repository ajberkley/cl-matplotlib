import sys
import time
import numpy as np
import PyQt6

from matplotlib.backends.backend_qtagg import FigureCanvas
from matplotlib.backends.backend_qtagg import \
    NavigationToolbar2QT as NavigationToolbar
from matplotlib.backends.qt_compat import QtWidgets
from matplotlib.figure import Figure

import sys
from PyQt6.QtWidgets import QApplication, QMainWindow, QDockWidget, QLabel, QVBoxLayout, QWidget
from PyQt6.QtCore import Qt
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure

def dummy_plot(figure):
        # 2. Add an axis and plot some dummy data
        ax = figure.add_subplot(111)
        ax.plot([0, 1, 2, 3], [10, 1, 20, 3], label="Data")
        ax.set_title("Docked Matplotlib Plot")
        ax.legend()
        return ax

class MplDockWidget(QDockWidget):
    def __init__(self, title="Plot Dock", parent=None):
        super().__init__(title, parent)
        self.layout = QVBoxLayout(self)
        self.figure = Figure()
        self.canvas = FigureCanvas(self.figure)
        self.toolbar = NavigationToolbar(self.canvas, self)
        self.layout.addWidget(self.toolbar)
        self.layout.addWidget(self.canvas)
        # Why we cannot use ourselves as a container, I do not know
        self.container = QWidget()
        self.container.setLayout(self.layout)
        self.setWidget(self.container)

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("PyQt Matplotlib Docking Example")
        self.resize(800, 600)

        # self.plot_dock = MplDockWidget("Interactive Plot")
        # self.plot_dock.ax = dummy_plot(self.plot_dock.figure)
        # self.addDockWidget(Qt.DockWidgetArea.RightDockWidgetArea, self.plot_dock)

        # self.plot_dock2 = MplDockWidget("Interactive Plot 2")
        # self.plot_dock2.ax = dummy_plot(self.plot_dock2.figure)
        # self.addDockWidget(Qt.DockWidgetArea.RightDockWidgetArea, self.plot_dock2)
        
        # self.setCentralWidget(QLabel("Main Application Area", alignment=Qt.AlignmentFlag.AlignCenter))

from PyQt6.QtCore import QTimer

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
