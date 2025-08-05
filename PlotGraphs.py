import os
import pandas as pd
import numpy as np
from scipy.stats import cumfreq
import datetime
import matplotlib.pyplot as plt


def plot_boxplot(values, filename, plots_dir):
    plt.figure(figsize=(10, 6))
    plt.boxplot(values, showfliers=True, patch_artist=True, boxprops=dict(facecolor='#0571b0', color='#92c5de'), medianprops=dict(
        color='#92c5de'), whiskerprops=dict(color='#0571b0'), capprops=dict(color='#0571b0'), flierprops=dict(markerfacecolor='#0571b0', markeredgecolor='#92c5de', marker='x'))
    plt.savefig(os.path.join(plots_dir,
                'boxplot_' + filename + '.png'))
    plt.close()


def plot_cdf(sorted_values, filename, plots_dir):
    plt.figure(figsize=(10, 6))
    values = np.array(sorted_values)
    res = cumfreq(values, numbins=100)
    x = np.linspace(values.min(), values.max(), num=100)
    cdf = res.cumcount / res.cumcount[-1]
    plt.plot(x, cdf, color='#0571b0')
    plt.xlabel('Bits per Second')
    plt.ylabel('Cumulative Distribution Function')
    plt.title('CDF of Bits per Second for ' + filename)
    plt.grid(True)
    plt.savefig(os.path.join(plots_dir, 'cdf_' + filename + '.png'))
    plt.close()


def plot_graphs(filename, plots_dir):
    df = pd.read_csv(os.path.join('tests-csv', filename))
    plot_boxplot(df["bits_per_second"], filename, plots_dir)
    plot_cdf(df["bits_per_second"].sort_values(), filename, plots_dir)


def main():
    filenames = [f for f in os.listdir('tests-csv') if 'quic' not in f]
    timestamp = datetime.datetime.now().strftime("%Y_%m_%d_%H_%M_%S")
    plots_dir = f'tests-plots_{timestamp}'
    os.makedirs(plots_dir)
    for fname in filenames:
        plot_graphs(fname, plots_dir)


if __name__ == "__main__":
    main()
