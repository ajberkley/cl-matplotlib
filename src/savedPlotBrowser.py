import glob
import math
import os
import sys
from collections import namedtuple

from PyQt6.QtCore import QAbstractListModel, Qt, QSize, QModelIndex
from PyQt6.QtGui import QImage
from PyQt6.QtWidgets import QApplication, QMainWindow, QListView, QStyledItemDelegate, QLabel, QPushButton, QHBoxLayout, QVBoxLayout, QWidget, QHeaderView, QFileDialog

# A simple container for our image data.
Preview = namedtuple("Preview", "id title image")

CELL_PADDING = 20  # Padding on all sides of each thumbnail.

class PreviewDelegate(QStyledItemDelegate):
    def paint(self, painter, option, index):
        # Retrieve the Preview object from the model.
        data = index.model().data(index, Qt.ItemDataRole.DisplayRole)
        if data is None:
            return

        width = option.rect.width() - CELL_PADDING * 2
        height = option.rect.height() - CELL_PADDING * 2

        # Scale the image to fit inside the cell while keeping its aspect ratio.
        scaled = data.image.scaled(
            width,
            height,
            aspectRatioMode=Qt.AspectRatioMode.KeepAspectRatio,
        )

        # Center the image within the cell.
        x = CELL_PADDING + (width - scaled.width()) / 2
        y = CELL_PADDING + (height - scaled.height()) / 2

        painter.drawImage(
            round(option.rect.x() + x),
            round(option.rect.y() + y),
            scaled,
        )

    def sizeHint(self, option, index):
        # Give every cell the same fixed size.
        return QSize(144, 144)


class PreviewModel(QAbstractListModel):
    def __init__(self):
        super().__init__()
        self.previews = []

    def data(self, index, role):
        data = self.previews[index.row()]

        if role == Qt.ItemDataRole.DisplayRole:
            return data

        if role == Qt.ItemDataRole.ToolTipRole:
            return data.title

    def rowCount(self, parent=QModelIndex()):
        return len(self.previews)

class plotBrowser(QMainWindow):
    def __init__(self, globstr, select_callback, thumb_refresh_callback):
        super().__init__()
        self.globstr = globstr
        self.setWindowTitle(f"Plot Browser: {globstr}")
        
        # Keep basic window hints, but remove the Maximize button (~)
        self.setWindowFlags(Qt.WindowType.Window) 

        self.select_callback = select_callback
        self.thumb_refresh_callback = thumb_refresh_callback
        
        self.view = QListView()
        self.view.setViewMode(QListView.ViewMode.IconMode)
        self.view.setResizeMode(QListView.ResizeMode.Adjust)
        self.view.setMovement(QListView.Movement.Static)
        self.view.setWrapping(True)             # Wrap to next
        # self.view.setStyleSheet("""
        #     QListView {
        #         background-color: #f0f0f0;
        #     }
        #     QListView::item {
        #         padding: 8px;
        #         border-bottom: 1px solid #dcdcdc;
        #     }
        #     QListView::item:selected {
        #         background-color: #3498db; /* Custom selection background color */
        #         color: #ffffff;            /* Custom selected text color */
        #     }
        # """)
        # self.view.setShowDecorationSelected(True)
        # self.view.setProperty("showDecorationSelected", True) 
        delegate = PreviewDelegate()
        self.view.setItemDelegate(delegate)

        self.model = PreviewModel()
        self.view.setModel(self.model)

        self.container = QWidget()
        self.layout = QVBoxLayout()
        # Top row, refresh button and filename and directory selector
        self.filename = QLabel("Double click to open plot, single click to see name here")
        self.close_button = QPushButton("close")
        self.refresh_button = QPushButton("refresh")
        self.chdir_button = QPushButton("chdir")
        self.toprow = QWidget()
        self.toprow.layout = QHBoxLayout()
        self.toprow.setLayout(self.toprow.layout)
        self.toprow.layout.addWidget(self.filename, stretch=1)
        self.toprow.layout.addStretch()
        self.toprow.layout.addWidget(self.close_button, stretch=0)
        self.toprow.layout.addWidget(self.chdir_button, stretch=0)
        self.toprow.layout.addWidget(self.refresh_button, stretch=0)
        self.layout.addWidget(self.toprow, stretch=0)
        self.layout.addWidget(self.view, stretch=1)
        self.container.setLayout(self.layout)
        self.setCentralWidget(self.container)
        self.refresh()
        self.chdir_button.clicked.connect(self.get_dir)
        self.refresh_button.clicked.connect(self.refresh)
        self.close_button.clicked.connect(self.close)
        self.view.doubleClicked.connect(self.on_selection)
        self.view.clicked.connect(self.on_click)

    def get_dir(self):
        dir_path = QFileDialog.getExistingDirectory(
            parent=self,
            caption="Select directory",
            directory=os.path.dirname(self.globstr),
            options=QFileDialog.Option.DontUseNativeDialog,)
        if dir_path:
            self.globstr = dir_path + "/*.thumb.png"
            self.setWindowTitle(f"Plot Browser: {self.globstr}")
            self.refresh()
        
    def refresh(self):
        self.thumb_refresh_callback(os.path.dirname(self.globstr))
        files = glob.glob(self.globstr)
        def modified_time_of_parent_file(filename):
            return os.path.getmtime(filename.removesuffix(".thumb.png"))
        
        files.sort(key=modified_time_of_parent_file, reverse=True)
        self.model.previews = []
        for n, fn in enumerate(files):
            image = QImage(fn)
            item = Preview(n, fn, image)
            self.model.previews.append(item)

        self.model.layoutChanged.emit()
        
    def on_click(self, index: QModelIndex):
        filename = self.model.data(index, Qt.ItemDataRole.ToolTipRole)
        self.filename.setText(filename)
        
    def on_selection(self, index: QModelIndex):
        filename = self.model.data(index, Qt.ItemDataRole.ToolTipRole)        
        self.on_click(index)
        self.select_callback(filename)

