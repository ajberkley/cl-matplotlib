# cl-matplotlib
Matlab like interactive plotting experience in Common Lisp using python+matplotlib.

This is a very early work in progress!  If you are interested, create an issue and we can talk about it!

With a small tweak to the read-eval loop in py4cl2 we can get nice interactive (zoomable, customizable) PyQt6 / matplotlib plots while still having a lisp repl to interact with them.  The main complexity is that we have to turn the py4cl2 dispatch loop inside out so it gets called from the Qt6 main loop.  See [ajberkley/py4cl2](https://github.com/ajberkley/py4cl2) for a fork of py4cl2 that supports the inside out dispatch loop, asynchronous callback support, and multiple python processes.

```
cd ~/quicklisp/local-projects
git clone https://github.com/ajberkley/py4cl2
git clone https://github.com/ajberkley/cl-matplotlib
```
You will need to pip install PyQt6, matplotlib, numpy, scipy at least.  Start a virtual env if they aren't globally installed, then start up emacs / slime and (in-package:cl-matplotlib) then (try-callbacks) and click the Boo button to see callbacks into lisp, then (plot-random-points)...

<img width="2560" height="1600" alt="image" src="https://github.com/user-attachments/assets/fc189288-08cf-4316-9e22-ec6198c1f03a" />
