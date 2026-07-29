# cl-matplotlib
Matlab like interactive plotting experience in Common Lisp using python+matplotlib using https://github.com/ajberkley/py4cl2 (forked from https://github.com/digikar99/py4cl2 currently, will try and merge changes).

This is a work in progress, but is being used pretty extensively in house.  If you are interested, create an issue and we can talk about it!

With a small tweak to the read-eval loop in py4cl2 we can get nice interactive (zoomable, customizable) PyQt6 / matplotlib plots while still having a lisp repl to interact with them.  The main complexity is that we have to turn the py4cl2 dispatch loop inside out so it gets called from the Qt6 main loop.  See [ajberkley/py4cl2](https://github.com/ajberkley/py4cl2) for a fork of py4cl2 that supports the inside out dispatch loop, asynchronous callback support, and multiple python processes.

```
cd ~/quicklisp/local-projects
git clone https://github.com/ajberkley/py4cl2
git clone https://github.com/ajberkley/cl-matplotlib
```
You will need to pip install PyQt6, matplotlib, numpy at least.  Start a virtual env if they aren't globally installed, then start up emacs / slime and (quicklisp:quickload :cl-matplotlib) and then (in-package:cl-matplotlib) then (start-loop) and then (plot-random-points) (mpl/figure 3) (plot-random-points)... or run (demo).  You can drag/drop plots to dock/undock them etc, click the float/unfloat button, etc.

Note that if you are using Ubuntu22 please read the package doc-string for some kludge workarounds for Qt6 dockable windows and wayland issues
<img width="1851" height="1055" alt="image" src="https://github.com/user-attachments/assets/4ec76dbc-f8a3-41ef-a9ab-4220caad2d34" />
