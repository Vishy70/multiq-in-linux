import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import os
import pandas as pd


def get_unique_label(category: str) -> str:
    """
    Extracts the unique label from a category string.
    Args:
        category (str): Input category string.
    Returns:
        str: Unique label.
    """
    return category.split('-')[-1] if '-' in category else category


def save_plot_image(image_base: str, suffix: str) -> None:
    """
    Saves the current plot image to disk.
    Args:
        image_base (str): Base name of the image file.
        suffix (str): Suffix to append to the image name.
    Returns:
        None
    """
    plots_folder = os.path.join(os.path.dirname(__file__), "plots")
    os.makedirs(plots_folder, exist_ok=True)
    image_name = os.path.splitext(image_base)[0] + suffix
    image_path = os.path.join(plots_folder, image_name)
    try:
        plt.savefig(image_path, bbox_inches='tight')
        print(f"Saved plot: {image_path}")
    except Exception as e:
        print(f"Error saving plot: {e}")
    finally:
        plt.close()


def plot_cdf(df: pd.DataFrame, type: str) -> None:
    """
    Plots the CDF for the given DataFrame.
    Args:
        df (pd.DataFrame): Data to plot.
        type (str): Type of plot (RTT or Throughput).
    Returns:
        None
    """
    try:
        col1, col2 = df.columns[0], df.columns[1]
        df = df.dropna(subset=[col1, col2])
        df[col1] = pd.to_numeric(df[col1], errors='coerce')
        if col1 == 'rtt':
            df[col1] = df[col1] / 1000.0
        if col1 == 'bits_per_second':
            df[col1] = df[col1] / 1000000.0
        df[col2] = df[col2].astype(str)
        df = df.dropna(subset=[col1])
        if df.empty:
            print(
                f"No valid data to plot CDF after cleaning for file: {getattr(plot_cdf, 'current_file', 'unknown')}")
            return
        plt.figure()
        for group in df[col2].unique():
            group_data = df[df[col2] == group][col1].sort_values()
            if group_data.empty:
                continue
            cdf = np.arange(1, len(group_data)+1) / len(group_data)
            plt.plot(group_data, cdf, label=get_unique_label(group))
        plt.xlabel("RTT (ms)" if type == "RTT" else "Throughput (Mbps)")
        plt.ylabel("CDF")
        plt.legend()
        save_plot_image(getattr(plot_cdf, 'current_file',
                        'plot'), f"_cdf_{type}.png")
    except Exception as e:
        print(f"Error in plot_cdf: {e}")


def plot_box(df: pd.DataFrame, type: str) -> None:
    """
    Plots a boxplot for the given DataFrame.
    Args:
        df (pd.DataFrame): Data to plot.
        type (str): Type of plot (RTT or Throughput).
    Returns:
        None
    """
    try:
        col1, col2 = df.columns[0], df.columns[1]
        df = df.dropna(subset=[col1, col2])
        df[col1] = pd.to_numeric(df[col1], errors='coerce')
        if col1 == 'rtt':
            df[col1] = df[col1] / 1000.0
        if col1 == 'bits_per_second':
            df[col1] = df[col1] / 1000000.0
        df[col2] = df[col2].astype(str)
        df = df.dropna(subset=[col1])
        if df.empty:
            print(
                f"No valid data to plot after cleaning for file: {getattr(plot_box, 'current_file', 'unknown')}")
            return
        ax = sns.boxplot(x=col2, y=col1, data=df)
        plt.ylabel("RTT (ms)" if type == "RTT" else "Throughput (Mbps)")
        xticks = ax.get_xticks()
        xticklabels = [get_unique_label(t.get_text())
                       for t in ax.get_xticklabels()]
        ax.set_xticks(xticks)
        ax.set_xticklabels(xticklabels, rotation=45)
        save_plot_image(getattr(plot_box, 'current_file',
                        'plot'), f"_box_{type}.png")
    except Exception as e:
        print(f"Error in plot_box: {e}")


csv_folder = os.path.join(os.path.dirname(__file__), "merged-csv")
try:
    csv_files = [f for f in os.listdir(csv_folder) if f.endswith('.csv')]
except Exception as e:
    print(f"Error reading CSV folder: {e}")
    csv_files = []

if csv_files:
    for csv_file in csv_files:
        plot_box.current_file = plot_cdf.current_file = csv_file
        csv_path = os.path.join(csv_folder, csv_file)
        try:
            df = pd.read_csv(csv_path)
        except Exception as e:
            print(f"Error reading {csv_file}: {e}")
            continue
        rtt_col = next((c for c in ['rtt', 'rtt_ms'] if c in df.columns), None)
        throughput_col = next(
            (c for c in ['bits_per_second', 'Mbps'] if c in df.columns), None)
        if rtt_col and 'source_parent' in df.columns:
            plot_box(df[[rtt_col, 'source_parent']], 'RTT')
            plot_cdf(df[[rtt_col, 'source_parent']], 'RTT')
        else:
            print(
                f"RTT columns ('rtt' or 'rtt_ms') and/or 'source_parent' not found in {csv_file}.")
        if throughput_col and 'source_parent' in df.columns:
            plot_box.current_file = plot_cdf.current_file = csv_file
            plot_box(df[[throughput_col, 'source_parent']], 'Throughput')
            plot_cdf(df[[throughput_col, 'source_parent']], 'Throughput')
        else:
            print(
                f"Throughput columns ('bits_per_second' or 'Mbps') and/or 'source_parent' not found in {csv_file}.")
else:
    print("No CSV files found in the folder.")
