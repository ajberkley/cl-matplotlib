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
from PyQt6.QtWidgets import QApplication, QMainWindow, QDockWidget, QLabel
from PyQt6.QtCore import Qt
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure

class MplDockWidget(QDockWidget):
    def __init__(self, title="Plot Dock", parent=None):
        super().__init__(title, parent)
        
        # 1. Create Matplotlib Figure & Canvas
        self.figure = Figure()
        self.canvas = FigureCanvas(self.figure)
        
        # 2. Add an axis and plot some dummy data
        self.ax = self.figure.add_subplot(111)
        self.ax.plot([0, 1, 2, 3], [10, 1, 20, 3], label="Data")
        self.ax.set_title("Docked Matplotlib Plot")
        self.ax.legend()
        
        # 3. Set the canvas as the DockWidget's main widget
        self.setWidget(self.canvas)

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("PyQt Matplotlib Docking Example")
        self.resize(800, 600)
        
        # 4. Create and add the dockable plot
        self.plot_dock = MplDockWidget("Interactive Plot")
        self.addDockWidget(Qt.DockWidgetArea.RightDockWidgetArea, self.plot_dock)
        
        # 5. Add a placeholder central widget (optional)
        self.setCentralWidget(QLabel("Main Application Area", alignment=Qt.AlignmentFlag.AlignCenter))

from PyQt6.QtCore import QTimer

def start_app (try_process_message):
        print("Starting!")
        app = QtWidgets.QApplication([""])
        main_window = MainWindow()
        main_window.show()
        timer = QTimer()
        def process_messages():
                try_process_message(blocking=False)
        timer.timeout.connect(process_messages);
        timer.start(100);
        print("Going into main loop, will return when all windows closed")
        app.exec()
        print("No more windows, returning to default message_dispatch_loop")
        
