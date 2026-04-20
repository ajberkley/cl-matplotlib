## author: fbraglia
import numpy as np
import yaml
import matplotlib
from scipy.stats import logistic
from scipy.optimize import curve_fit
from matplotlib import pyplot as plt

# config = yaml.safe_load(open('src/config.yaml', 'r'))
# turn this on for LaTeX notation (need LaTeX installed)
#plt.rcParams['text.usetex'] = True
color_wheel = plt.rcParams['axes.prop_cycle'].by_key()['color']
def sigmoid(x, l, s, a, c):
    y = (x-l)/s
    fy = a * np.exp(y)/(1.+np.exp(y)) + c
    return fy

def fit_pars(x, y, ye, fun, config):
    res = curve_fit(sigmoid, x, y,
                    sigma=ye,
                    absolute_sigma=True,
                    p0=config['fit_p0'],
                    bounds=config['fit_bounds'])
    return res[0]

def gen_pop(config):
    # generate a population of states from a logistic distribution
    # and add some noise and outliers
    px = 2.*np.random.rand(config['meas_num'])-1. + config['deg_pt']
    py = logistic.cdf(px, loc=config['deg_pt'], scale=config['deg_wdt']) \
        + np.random.randn(config['meas_num']) * config['meas_std']
    pyerr = np.abs(np.random.randn(config['meas_num']) * config['meas_std'])
    if config['outliers'] is not None:
        py[np.random.randint(0, config['meas_num']-1,
                             config['outliers'])] += \
        np.random.randn(config['outliers']) * 0.1
    return px, py, pyerr

class testPlot:
    def __init__(self):
        self.clicked_points = []
        self.stored_key = None

    def load_config(self, config_path):
        self.config = yaml.safe_load(open(config_path, 'r'))

    def generate_data(self):
        pop_x, pop_y, pop_y_e = gen_pop(self.config)
        # store data in class
        self.x = pop_x
        self.y = pop_y
        self.yerr = pop_y_e

        # also create backup of original data
        self.xo = pop_x
        self.yo = pop_y
        self.yerro = pop_y_e 

    def on_click(self, event):
        # Ignore clicks outside the axes
        if event.inaxes is None:
            return
        # also ignore if over legend
        # ugly! rewrite/refactor
        leg_box = self.legend.get_window_extent().transformed( \
                     self.ax.transData.inverted())

        if leg_box.x0 < event.xdata < leg_box.x1 \
        and leg_box.y0 < event.ydata < leg_box.y1:
            return

        # calculate distance to closest point
        # this can be generalized to any artist (2Dlines, shapes, etc)
        distances = np.hypot(self.x - event.xdata,
                            self.y - event.ydata)
        index = int(np.argmin(distances))
        if event.button == 1:  # Left click
            # shift+click to remove selection
            if self.stored_key=="shift":
                if index in self.clicked_points and distances[index]<.1:
                    self.clicked_points = [i for i in self.clicked_points
                                        if i != index]
            elif distances[index]<.1:
                if index not in self.clicked_points:
                    self.clicked_points.append(index)

        # elif event.button == 3:  # Right click
        #     # ideally right-click triggers dropdown, but this requires more work        
        self.redraw()

    def on_key_press(self, event):
        # this should be refactored into calls to single-purpose methods
        # and made into an in-class factory-like construct
        # at this stage, it's mostly a collection of examples of what can be done
        # same reasoning applies to on_click above
        # remove points on 'd', flush index cache
        if (event.key == 'd') or (event.key=='delete'):
            if self.clicked_points  != []:
                self.x = np.delete(self.x, self.clicked_points)
                self.y = np.delete(self.y, self.clicked_points)
                self.yerr = np.delete(self.yerr, self.clicked_points)
                self.clicked_points = []
        # clear all selected points
        elif event.key == 'c':
            self.clicked_points = []
        # reset graph
        elif (event.key == 'r') or (event.key=='home'):
            self.x = self.xo
            self.y = self.yo
            self.yerr = self.yerro
            self.clicked_points = []
        # refit model to data
        elif event.key == 'm':
            self.fit_pars = fit_pars(self.x, self.y, self.yerr, sigmoid, slef.config)
        # store shift (and other keys) for "key+click" behaviour
        elif event.key == "shift":
            self.stored_key = event.key
        self.redraw()
        #self.fig.canvas.draw_idle()

    def on_key_release(self, event):
        # release a stored key
        if (self.stored_key is not None) and (event.key in self.stored_key):
            self.stored_key = None

    def redraw(self):
        # store zoom state
        xlims = self.ax.get_xlim()
        ylims = self.ax.get_ylim()
        # store legend position
        # commented because of some bug
        # if hasattr(self, 'legend'):
        #     if not hasattr(self, 'legend_pos'):
        #         self.legend_pos = self.legend.get_window_extent()
        # clear and redraw canvas
        self.ax.clear()
        self.ax.set_title('Interactive plot')
        self.ax.set_xlabel('Axis 1')
        self.ax.set_ylabel('Axis 2')
        self.ax.set_xlim(xlims)
        self.ax.set_ylim(ylims)
        # plot data
        self.pdata = self.ax.errorbar(self.x, self.y,
                                        yerr=self.yerr,
                                        marker='s',
                                        color=color_wheel[0],
                                        linestyle='none',
                                        capsize=5,
                                        picker=.1,
                                        zorder=1,
                                        label='Data')

        if self.clicked_points != []:
            self.psel = self.ax.plot(self.x[self.clicked_points],
                                    self.y[self.clicked_points], 's',
                                    zorder=2,
                                    color=color_wheel[3],
                                    markerfacecolor='none',
                                    markersize=10)
        ref_x = np.linspace(self.x.min(),
                            self.x.max(),
                            1000)
        self.pfit = self.ax.plot(ref_x, sigmoid(ref_x, *self.fit_pars),
                                linestyle='--',
                                marker='none',
                                zorder=5,
                                label='Logistic',
                                color=color_wheel[1])
        legend = self.ax.legend(loc=2)
        legend.set_draggable(True)
        self.legend = InteractiveLegend(self.ax.get_legend())
        # if hasattr(self, 'legend_pos'):
        #     self.legend.set_bbox_to_anchor(self.legend_pos.transformed(
        #         self.ax.transAxes.inverted()
        #     ))
        self.ax.grid(linestyle='--')
        self.fig.canvas.draw_idle()

    def make_plot(self, block):
        # generate data points
        self.generate_data()
        # fit model to data
        self.fit_pars = fit_pars(self.x, self.y, self.yerr, sigmoid, self.config)
        fig, ax = plt.subplots(1, 1, figsize=(8, 8))
        ax.set_xlim(np.sign(self.x.min())*np.abs(self.x.min())*1.05,
                    np.sign(self.x.max())*np.abs(self.x.max())*1.05)
        ax.set_ylim(np.sign(self.y.min())*np.abs(self.y.min())*1.05,
                    np.sign(self.y.max())*np.abs(self.y.max())*1.05)
        self.fig = fig
        self.ax = ax
        self.fig.canvas.mpl_connect('button_press_event', self.on_click)
        self.fig.canvas.mpl_connect('key_press_event', self.on_key_press)
        self.fig.canvas.mpl_connect('key_release_event', self.on_key_release)
        self.redraw()
        plt.show(block=block)
        plt.pause(0.1)


def interactive_legend(ax=None):
    if ax is None:
        ax = plt.gca()
    if ax.legend_ is None:
        ax.legend()

    return InteractiveLegend(ax.get_legend())

class InteractiveLegend(object):
    def __init__(self, legend):
        self.legend = legend
        self.fig = legend.axes.figure

        self.lookup_artist, self.lookup_handle = self._build_lookups(legend)
        self._setup_connections()

        self.update()

    def _setup_connections(self):
        for artist in self.legend.texts + self.legend.legend_handles:
            artist.set_picker(10) # 10 points tolerance

        self.fig.canvas.mpl_connect('pick_event', self.on_pick)
        self.fig.canvas.mpl_connect('button_press_event', self.on_click)

    def _build_lookups(self, legend):
        labels = [t.get_text() for t in legend.texts]
        handles = legend.legend_handles
        label2handle = dict(zip(labels, handles))
        handle2text = dict(zip(handles, legend.texts))

        lookup_artist = {}
        lookup_handle = {}
        for artist in legend.axes.get_children():
            if artist.get_label() in labels:
                handle = label2handle[artist.get_label()]
                lookup_handle[artist] = handle
                lookup_artist[handle] = artist
                lookup_artist[handle2text[handle]] = artist

        lookup_handle.update(zip(handles, handles))
        lookup_handle.update(zip(legend.texts, handles))

        return lookup_artist, lookup_handle

    def on_pick(self, event):
        handle = event.artist
        if handle in self.lookup_artist:
            artist = self.lookup_artist[handle]
            artist.set_visible(not artist.get_visible())
            self.update()

    def on_click(self, event):
        if event.button == 3:
            visible = False
        elif event.button == 2:
            visible = True
        else:
            return

        for artist in self.lookup_artist.values():
            artist.set_visible(visible)
        self.update()

    def update(self):
        for artist in self.lookup_artist.values():
            handle = self.lookup_handle[artist]
            if artist.get_visible():
                handle.set_visible(True)
            else:
                handle.set_visible(False)
        self.fig.canvas.draw()

    def get_window_extent(self):
        return self.legend.get_window_extent()
        
    def show(self):
        plt.show()
