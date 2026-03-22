def start_app (try_process_message):
        global w
        # Integrate ourselves into PyQt6
        import PyQt6
        import sys
        from PyQt6.QtWidgets import QApplication
        from PyQt6.QtCore import QTimer        
        app = QApplication(sys.argv)

        import PyQt6Dockable
        import matplotlib
        matplotlib.use("QtAgg")
        w = PyQt6.MainWindow()
        w.show()

        timer = QTimer()
        def process_messages():
                try_process_message(blocking=False)
        timer.timeout.connect(process_messages);
        timer.start(100);
        print("Going into main loop, will return when all windows closed")
        app.exec()
        print("No more windows, returning to blocking messsage_dispatch_loop")
        
