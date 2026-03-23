# cl-matplotlib
Matlab like interactive plotting experience in Common Lisp using python+matplotlib.

This is a very early work in progress!  If you are interested, create an issue and we can talk about it!

With a small tweak to the read-eval loop in py4cl2 we can get nice interactive (zoomable, customizable) PyQt6 / matplotlib plots while still having a lisp repl to interact with them.  The main complexity is that we have to turn the py4cl2 dispatch loop inside out so it gets called from the Qt6 main loop.  See [ajberkley/py4cl2](https://github.com/ajberkley/py4cl2/tree/ajb/non-blocking-dispatch-loop) for the modifications for just the dispatch loop.  Or the ajb/rework branch for asynchronous callback support and for supporting multiple python processes (in progress).  You will have to pull one of those branches to run the demo.

```
git clone -b ajb/rework https://github.com/ajberkley/py4cl2
```

The next step on the python side is adding a docking window for plots, similar to Matlab's.  I have some attempts in this repo, but I don't understand matplotlib enough yet.  Then a reasonable lisp side interface to plotting with state tracking so we can save and load plots and data and headless plotting, etc.

<img width="1841" height="1053" alt="image" src="https://github.com/user-attachments/assets/24173425-8336-49ca-bb00-b5a8c7705628" />
