import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import os
import pandas as pd
import re

# Configuration constants
LATENCY_UPPER_PCT = 99  # Trim top %ile of RTT values as outliers
DPI_SAVE = 150  # DPI for saved PNG images
TAIL_CDF_START_PCT = 80  # Start of tail CDF 


def get_unique_label(category: str) -> str:
    """
    Return a pretty label for group/category values.
    
    - fq_codel -> FQ_CoDel
    - fq-pie / fq_pie -> FQ_PIE
    - dualpi2 -> DualPI2
    Keeps other text unchanged, preserving additional tokens.
    
    Args:
        category (str): Input category string.
    Returns:
        str: Formatted label.
    """
    try:
        text = str(category)
        # Replace case-insensitively and tolerate "fq-codel" / "fq_codel"
        text = re.sub(r"(?i)fq[_-]?codel", "FQ_CoDel", text)
        text = re.sub(r"(?i)fq[_-]?pie", "FQ_PIE", text)
        text = re.sub(r"(?i)dualpi2", "DualPI2", text)
        text = re.sub(r"(?i)pfifo", "pFIFO", text)
        return text
    except Exception:
        return category


def save_plot_image(image_base: str, suffix: str) -> None:
    """
    Saves the current plot image to disk in both PNG and SVG formats.
    
    Args:
        image_base (str): Base name of the image file.
        suffix (str): Suffix to append to the image name.
    Returns:
        None
    """
    plots_folder = os.path.join(os.path.dirname(__file__), "plots")
    png_folder = os.path.join(plots_folder, "png")
    svg_folder = os.path.join(plots_folder, "svg")
    os.makedirs(png_folder, exist_ok=True)
    os.makedirs(svg_folder, exist_ok=True)
    
    base_name = os.path.splitext(image_base)[0] + suffix
    png_path = os.path.join(png_folder, base_name + '.png')
    svg_path = os.path.join(svg_folder, base_name + '.svg')
    
    try:
        plt.savefig(png_path, bbox_inches='tight', dpi=DPI_SAVE)
        plt.savefig(svg_path, bbox_inches='tight')
        print(f"Saved plot: {png_path}")
        print(f"Saved plot: {svg_path}")
    except Exception as e:
        print(f"Error saving plot: {e}")
    finally:
        plt.close()


def plot_cdf(df: pd.DataFrame, type: str) -> None:
    """
    Plots CDF (Cumulative Distribution Function) and tail CDF for the given DataFrame.
    
    Args:
        df (pd.DataFrame): Data to plot with value and grouping columns.
        type (str): Type of plot (RTT or Throughput).
    Returns:
        None
    """
    try:
        value_col, group_col = df.columns[0], df.columns[1]
        df = df.dropna(subset=[value_col, group_col])
        df[value_col] = pd.to_numeric(df[value_col], errors='coerce')
        
        # Convert units if needed
        if value_col == 'rtt':
            df[value_col] = df[value_col] / 1000.0
        if value_col == 'bits_per_second':
            df[value_col] = df[value_col] / 1000000.0
        
        df = df.dropna(subset=[value_col])
        if df.empty:
            print(f"No valid data to plot CDF for file: {getattr(plot_cdf, 'current_file', 'unknown')}")
            return
        
        groups = list(df[group_col].unique())
        
        # Trim top outliers for RTT (remove top 5%)
        if type == "RTT" and groups:
            trimmed_parts = []
            for g in groups:
                gdf = df[df[group_col] == g][[value_col, group_col]].dropna().copy()
                if gdf.empty:
                    continue
                try:
                    thr = np.percentile(gdf[value_col], LATENCY_UPPER_PCT)
                    gdf = gdf[gdf[value_col] <= thr]
                except Exception:
                    pass
                if not gdf.empty:
                    trimmed_parts.append(gdf)
            if trimmed_parts:
                df = pd.concat(trimmed_parts, ignore_index=True)
                groups = list(df[group_col].unique())
            else:
                return
        
        # Dynamic figure width based on number of groups
        width = max(8, min(18, 1.2 * max(3, len(groups))))
        palette = sns.color_palette(n_colors=len(groups))
        
        # Main CDF plot
        plt.figure(figsize=(width, 6))
        for i, grp in enumerate(groups):
            data = df[df[group_col] == grp][value_col].dropna().sort_values()
            if data.size == 0:
                continue
            cdf = np.arange(1, len(data) + 1) / len(data)
            plt.plot(data, cdf, label=f"{get_unique_label(grp)}", 
                    color=palette[i], linewidth=2.0, alpha=0.9)
            # Add scatter points for small datasets
            if len(data) <= 200:
                plt.scatter(data, cdf, color=palette[i], s=10, alpha=0.7)
        
        plt.grid(axis='y', alpha=0.3)
        plt.xlabel("RTT (ms)" if type == "RTT" else "Throughput (Mbps)")
        plt.ylabel("CDF")
        
        if len(groups) > 1:
            plt.legend(title="qdisc", bbox_to_anchor=(1.02, 1), loc='upper left')
        else:
            plt.legend()
        
        plt.tight_layout()
        save_plot_image(getattr(plot_cdf, 'current_file', 'plot'), f"_cdf_{type}")
        
        # Tail CDF plot (90th percentile and above)
        combined = np.concatenate([df[df[group_col] == g][value_col].dropna().values for g in groups]) if len(groups) > 0 else np.array([])
        if combined.size == 0:
            return
        
        tail_cut = np.percentile(combined, TAIL_CDF_START_PCT)
        
        plt.figure(figsize=(width, 6))
        xmin = max(np.min(combined), tail_cut)
        xmax = np.max(combined)
        x_left = xmin - 0.02 * (xmax - xmin) if xmax > xmin else xmin
        tail_min_vals = []
        
        for i, grp in enumerate(groups):
            data = df[df[group_col] == grp][value_col].dropna().sort_values()
            if data.size == 0:
                continue
            tail_data = data[data >= tail_cut]
            if tail_data.size == 0:
                continue
            cdf_full = np.arange(1, len(data) + 1) / len(data)
            idx = np.searchsorted(data, tail_cut)
            tail_cdf = cdf_full[idx:]
            plt.plot(tail_data, tail_cdf, label=f"{get_unique_label(grp)}", 
                    color=palette[i], linewidth=2.0, alpha=0.95)
            plt.scatter(tail_data, tail_cdf, color=palette[i], s=8, alpha=0.6)
            tail_min_vals.append(tail_cdf.min())
        
        plt.xlim(x_left, xmax)
        if tail_min_vals:
            y_min = max(0.0, min(tail_min_vals) - 0.02)
        else:
            y_min = 0.5
        plt.ylim(y_min, 1.0)
        plt.grid(axis='y', alpha=0.3)
        plt.xlabel("RTT (ms)" if type == "RTT" else "Throughput (Mbps)")
        plt.ylabel("CDF")
        
        if len(groups) > 1:
            plt.legend(title=f"qdisc (tail ≥ {TAIL_CDF_START_PCT}th pct)", bbox_to_anchor=(1.02, 1), loc='upper left')
        else:
            plt.legend()
        
        plt.tight_layout()
        save_plot_image(getattr(plot_cdf, 'current_file', 'plot'), f"_cdf_tail_{type}")
        
    except Exception as e:
        print(f"Error in plot_cdf: {e}")


def plot_box(df: pd.DataFrame, type: str) -> None:
    """
    Plots boxplots (with and without outlier points) for the given DataFrame.
    
    Args:
        df (pd.DataFrame): Data to plot with value and grouping columns.
        type (str): Type of plot (RTT or Throughput).
    Returns:
        None
    """
    try:
        value_col, group_col = df.columns[0], df.columns[1]
        df = df.dropna(subset=[value_col, group_col])
        df[value_col] = pd.to_numeric(df[value_col], errors='coerce')
        
        # Convert units if needed
        if value_col == 'rtt':
            df[value_col] = df[value_col] / 1000.0
        if value_col == 'bits_per_second':
            df[value_col] = df[value_col] / 1000000.0
        
        df = df.dropna(subset=[value_col])
        if df.empty:
            print(f"No valid data to plot after cleaning for file: {getattr(plot_box, 'current_file', 'unknown')}")
            return
        
        groups = sorted(df[group_col].unique())
        
        # Trim top outliers for RTT (remove top 5%)
        if type == "RTT" and groups:
            trimmed_parts = []
            for g in groups:
                gdf = df[df[group_col] == g][[value_col, group_col]].dropna().copy()
                if gdf.empty:
                    continue
                try:
                    thr = np.percentile(gdf[value_col], LATENCY_UPPER_PCT)
                    gdf = gdf[gdf[value_col] <= thr]
                except Exception:
                    pass
                if not gdf.empty:
                    trimmed_parts.append(gdf)
            if trimmed_parts:
                df = pd.concat(trimmed_parts, ignore_index=True)
                groups = sorted(df[group_col].unique())
            else:
                return
        
        # Dynamic figure width based on number of groups
        width = max(8, min(20, 1.2 * max(3, len(groups))))
        palette = sns.color_palette('Set2', n_colors=len(groups))
        
        # Box plot without overlaid points
        plt.figure(figsize=(width, 6))
        ax = sns.boxplot(
            x=group_col,
            y=value_col,
            data=df,
            order=groups,
            showfliers=False,
            notch=False,
            patch_artist=True,
            medianprops={'linewidth': 2.5, 'color': 'darkred'}
        )
        
        # Color the boxes
        try:
            for i, artist in enumerate(ax.artists):
                color = palette[i % len(palette)]
                artist.set_facecolor(color)
                artist.set_edgecolor('gray')
                artist.set_alpha(0.85)
            for line in ax.lines:
                line.set_color('gray')
                line.set_alpha(0.7)
        except Exception:
            pass
        
        plt.ylabel("RTT (ms)" if type == "RTT" else "Throughput (Mbps)")
        plt.xlabel("qdisc")
        
        # Format x-axis labels
        try:
            pretty_labels = [get_unique_label(g) for g in groups]
            ticks = np.arange(len(groups))
            ax.set_xticks(ticks)
            ax.set_xticklabels(pretty_labels, rotation=45, ha='right')
        except Exception:
            plt.xticks(rotation=45, ha='right')
        
        plt.grid(axis='y', alpha=0.25)
        plt.tight_layout()
        save_plot_image(getattr(plot_box, 'current_file', 'plot'), f"_box_no_outliers_{type}")
        
        # Box plot with overlaid points
        plt.figure(figsize=(width, 6))
        ax2 = sns.boxplot(
            x=group_col,
            y=value_col,
            data=df,
            order=groups,
            showfliers=False,
            notch=False,
            patch_artist=True,
            medianprops={'linewidth': 2.5, 'color': 'darkred'}
        )
        
        # Overlay scatter points with jitter
        for i, grp in enumerate(groups):
            grp_data = df[df[group_col] == grp][value_col].dropna().values
            if grp_data.size == 0:
                continue
            x_jitter = np.random.normal(loc=i, scale=0.08, size=len(grp_data))
            plt.scatter(x_jitter, grp_data, color=palette[i % len(palette)], s=10, alpha=0.5)
        
        # Color the boxes
        try:
            for i, artist in enumerate(ax2.artists):
                color = palette[i % len(palette)]
                artist.set_facecolor(color)
                artist.set_edgecolor('gray')
                artist.set_alpha(0.85)
            for line in ax2.lines:
                line.set_color('gray')
                line.set_alpha(0.7)
        except Exception:
            pass
        
        plt.ylabel("RTT (ms)" if type == "RTT" else "Throughput (Mbps)")
        plt.xlabel("qdisc")
        
        # Format x-axis labels
        try:
            pretty_labels = [get_unique_label(g) for g in groups]
            ticks = np.arange(len(groups))
            ax2.set_xticks(ticks)
            ax2.set_xticklabels(pretty_labels, rotation=45, ha='right')
        except Exception:
            plt.xticks(rotation=45, ha='right')
        
        plt.grid(axis='y', alpha=0.25)
        plt.tight_layout()
        save_plot_image(getattr(plot_box, 'current_file', 'plot'), f"_box_with_points_{type}")
        
    except Exception as e:
        print(f"Error in plot_box: {e}")


# Set seaborn theme for publication-quality plots
sns.set_theme(style='whitegrid', palette='Set2', rc={'figure.dpi': 100, 'savefig.dpi': DPI_SAVE})

csv_folder = os.path.join(os.path.dirname(__file__), "merged-csv")
try:
    csv_files = [f for f in os.listdir(csv_folder) if f.endswith('.csv')]
except Exception as e:
    print(f"Error reading CSV folder: {e}")
    csv_files = []

if csv_files:
    for csv_file in sorted(csv_files):
        plot_box.current_file = plot_cdf.current_file = csv_file
        csv_path = os.path.join(csv_folder, csv_file)
        try:
            df = pd.read_csv(csv_path)
        except Exception as e:
            print(f"Error reading {csv_file}: {e}")
            continue
        
        print(f"\n{'='*60}")
        print(f"Processing: {csv_file}")
        print(f"{'='*60}")
        
        rtt_col = next((c for c in ['rtt', 'rtt_ms'] if c in df.columns), None)
        throughput_col = next(
            (c for c in ['bits_per_second', 'Mbps'] if c in df.columns), None)
        
        if rtt_col and 'source_parent' in df.columns:
            print(f"  → Plotting RTT metrics...")
            plot_box(df[[rtt_col, 'source_parent']], 'RTT')
            plot_cdf(df[[rtt_col, 'source_parent']], 'RTT')
        else:
            print(
                f"  ⚠ RTT columns ('rtt' or 'rtt_ms') and/or 'source_parent' not found in {csv_file}.")
        
        # Skip throughput plots for client1 files
        if throughput_col and 'source_parent' in df.columns and 'client1' not in csv_file.lower():
            print(f"  → Plotting Throughput metrics...")
            plot_box(df[[throughput_col, 'source_parent']], 'Throughput')
        elif 'client1' in csv_file.lower() and throughput_col:
            print(f"  ℹ Skipping Throughput plots for client1 file")
        else:
            print(
                f"  ⚠ Throughput columns ('bits_per_second' or 'Mbps') and/or 'source_parent' not found in {csv_file}.")
else:
    print("No CSV files found in the folder.")
