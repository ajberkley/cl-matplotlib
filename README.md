# cl-matplotlib
Matlab like interactive plotting experience in Common Lisp using python+matplotlib.

With a small tweak to the read-eval loop in py4cl2 we can get nice interactive (zoomable, customizable) PyQt6 / matplotlib plots while still having a lisp repl to interact with them.  The main complexity is that we have to turn the py4cl2 dispatch loop inside out so it gets called from the Qt6 main loop.  This works well.  I'm trying to add a window docking system similar to the one in Matlab.

<img width="1841" height="1053" alt="image" src="https://github.com/user-attachments/assets/24173425-8336-49ca-bb00-b5a8c7705628" />
