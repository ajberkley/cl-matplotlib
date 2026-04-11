# def start_app (try_process_message):
#         import PyQt6
#         import sys
#         import matplotlib
#         import matplotlib.pyplot as plt
#         from PyQt6.QtWidgets import QApplication
#         from PyQt6.QtCore import QTimer
#         app = QApplication(sys.argv)

#         matplotlib.use("QtAgg")

#         plot = plt.plot([1, 2, 3],[4, 5, 6])
#         plt.show(block=False)

#         timer = QTimer()
#         def process_messages():
#                 try_process_message(blocking=False)
#         timer.timeout.connect(process_messages);
#         timer.start(10);
#         print("Going into main loop, will return when all windows closed")
#         app.exec()
#         print("No more windows, returning to default messsage_dispatch_loop")



import sys
import time
import numpy as np
import PyQt6

from matplotlib.backends.backend_qtagg import FigureCanvas
from matplotlib.backends.backend_qtagg import \
    NavigationToolbar2QT as NavigationToolbar
from matplotlib.backends.qt_compat import QtWidgets
from matplotlib.figure import Figure

class ApplicationWindow(QtWidgets.QMainWindow):
    def __init__(self):
        super().__init__()
        self._main = QtWidgets.QWidget()
        self.setCentralWidget(self._main)
        layout = QtWidgets.QVBoxLayout(self._main)

        static_canvas = FigureCanvas(Figure(figsize=(5, 3)))
        # Ideally one would use self.addToolBar here, but it is slightly
        # incompatible between PyQt6 and other bindings, so we just add the
        # toolbar as a plain widget instead.
        layout.addWidget(NavigationToolbar(static_canvas, self))
        layout.addWidget(static_canvas)

        dynamic_canvas = FigureCanvas(Figure(figsize=(5, 3)))
        layout.addWidget(dynamic_canvas)
        layout.addWidget(NavigationToolbar(dynamic_canvas, self))

        self._static_ax = static_canvas.figure.subplots()
        t = np.linspace(0, 10, 501)
        self._static_ax.plot(t, np.tan(t), ".")

        self._dynamic_ax = dynamic_canvas.figure.subplots()
        # Set up a Line2D.
        self.xdata = np.linspace(0, 10, 101)
        self._update_ydata()
        self._line, = self._dynamic_ax.plot(self.xdata, self.ydata)
        # The below two timers must be attributes of self, so that the garbage
        # collector won't clean them after we finish with __init__...

        # The data retrieval may be fast as possible (Using QRunnable could be
        # even faster).
        self.data_timer = dynamic_canvas.new_timer(1)
        self.data_timer.add_callback(self._update_ydata)
        self.data_timer.start()
        # Drawing at 50Hz should be fast enough for the GUI to feel smooth, and
        # not too fast for the GUI to be overloaded with events that need to be
        # processed while the GUI element is changed.
        self.drawing_timer = dynamic_canvas.new_timer(20)
        self.drawing_timer.add_callback(self._update_canvas)
        self.drawing_timer.start()

    def _update_ydata(self):
        # Shift the sinusoid as a function of time.
        self.ydata = np.sin(self.xdata + time.time())

    def _update_canvas(self):
        self._line.set_data(self.xdata, self.ydata)
        # It should be safe to use the synchronous draw() method for most drawing
        # frequencies, but it is safer to use draw_idle().
        self._line.figure.canvas.draw_idle()


# def start_app (try_process_message):
#         import PyQt6
#         import sys
#         import matplotlib
#         import matplotlib.pyplot as plt
#         from PyQt6.QtWidgets import QApplication
#         from PyQt6.QtCore import QTimer
#         app = QApplication(sys.argv)

#         matplotlib.use("QtAgg")
#         # w = PyQt6.QMainWindow()
#         # w.show()
#         plot = plt.plot([1, 2, 3],[4, 5, 6])
#         plt.show(block=False)

#         timer = QTimer()
#         def process_messages():
#                 try_process_message(blocking=False)
#         timer.timeout.connect(process_messages);
#         timer.start(100);
#         print("Going into main loop, will return when all windows closed")
#         app.exec()
#         print("No more windows, returning to default messsage_dispatch_loop")

from PyQt6.QtCore import QTimer

def start_app (try_process_message):
        
        print("Starting!")
        qapp = QtWidgets.QApplication([""])
        app = ApplicationWindow()
        timer = QTimer()
        def process_messages():
                try_process_message(blocking=False)
        timer.timeout.connect(process_messages);
        timer.start(100);
        app.show()
        app.activateWindow()
        app.raise_()
        print("Going into main loop, will return when all windows closed")
        qapp.exec()
        print("No more windows, returning to default message_dispatch_loop")
        
