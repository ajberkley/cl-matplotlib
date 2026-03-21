import PyQt6
from PyQt6.QtWidgets import QMainWindow, QDockWidget, QApplication
from PyQt6.QtCore import QCoreApplication, QTimer

class MainWindow(QMainWindow):
        def __init__(self):
                super().__init__()
                self.setWindowTitle("MainWindow")
                self.items = []
                # self.items = QDockWidget("Dockable",self);
                # docked.setAllowedAreas(LeftDockWidgetArea | RightDockWidgetArea)

        def add_plot(self, w, figure, num):
            self.items += FigureManagerQTDock(figure, num, w);

import matplotlib                
from matplotlib.backends.backend_qt import FigureManagerQT
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg
from matplotlib.figure import Figure

class FigureManagerQTDock(FigureManagerQT):
    def __init__(self, canvas, num, w):
        self.window = QDockWidget("Dockable", w)
        self.canvas = canvas
        super().__init__(canvas, num)
        self.window.closing.connect(self._widgetclosed)

        if sys.platform != "darwin":
            image = str(cbook._get_data_path('images/matplotlib.svg'))
            icon = QtGui.QIcon(image)
            self.window.setWindowIcon(icon)

        self.window._destroying = False

        if self.toolbar:
            self.window.addToolBar(self.toolbar)
            tbs_height = self.toolbar.sizeHint().height()
        else:
            tbs_height = 0

        # resize the main window so it will display the canvas with the
        # requested size:
        cs = canvas.sizeHint()
        cs_height = cs.height()
        height = cs_height + tbs_height
        self.window.resize(cs.width(), height)

        self.window.setCentralWidget(self.canvas)

        if mpl.is_interactive():
            self.window.show()
            self.canvas.draw_idle()

        # Give the keyboard focus to the figure instead of the manager:
        # StrongFocus accepts both tab and click to focus and will enable the
        # canvas to process event without clicking.
        # https://doc.qt.io/qt-5/qt.html#FocusPolicy-enum
        self.canvas.setFocusPolicy(QtCore.Qt.FocusPolicy.StrongFocus)
        self.canvas.setFocus()

        self.window.raise_()

# This class is an entry point to the backend. It's methods are called by matplotlib if the current module is used as a backend.
class FigureCanvas(FigureCanvasQTAgg):
    required_interactive_framework = "qt6"
    FigureCanvas = FigureCanvasQTAgg
    FigureManager = FigureManagerQTDock

    def __init__(self, figure: Figure):
        super().__init__(figure)
        self.figure = figure

    @classmethod
    def new_manager(cls, figure, num):
        canvas = FigureCanvas(figure)
        manager = FigureManagerQTDock(canvas, num)
        canvas.manager = manager
        figure.canvas = canvas
        return manager
