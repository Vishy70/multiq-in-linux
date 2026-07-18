import numpy as np
import matplotlib.pyplot as plt
from matplotlib.patches import Ellipse
import seaborn as sns
import os
import pandas as pd
import re

BANDWIDTH_MIN = 0.01
LATENCY_UPPER_PCT = 95
MAHAL_TRIM_PCT = 95

CONFIDENCE_LEVEL = 0.95
SHOW_INNER_ELLIPSE = False
INNER_CONFIDENCE = 0.50

RNG_SEED = 42
EQUALIZE_SAMPLES = True

SHOW_POINTS_MODE = 'none'

LOG_X = False
LOG_Y = False
def get_unique_label(category: str) -> str:
    """Return a pretty label for group/category values.

    - fq_codel -> FQ_CoDel
    - fq-pie / fq_pie -> FQ_PIE
    Keeps other text unchanged, preserving additional tokens.
    """
    try:
        text = str(category)
        # Replace case-insensitively and tolerate "fq-codel" / "fq_codel"
        text = re.sub(r"(?i)fq[_-]?codel", "FQ_CoDel", text)
        text = re.sub(r"(?i)fq[_-]?pie", "FQ_PIE", text)
        return text
    except Exception:
        return category


def save_plot_image(image_base: str, suffix: str) -> None:
    plots_folder = os.path.join(os.path.dirname(__file__), "plots")
    png_folder = os.path.join(plots_folder, "png")
    svg_folder = os.path.join(plots_folder, "svg")
    os.makedirs(png_folder, exist_ok=True)
    os.makedirs(svg_folder, exist_ok=True)
    base_name = os.path.splitext(image_base)[0] + suffix
    png_path = os.path.join(png_folder, base_name + '.png')
    svg_path = os.path.join(svg_folder, base_name + '.svg')
    try:
        plt.savefig(png_path, bbox_inches='tight', dpi=150)
        plt.savefig(svg_path, bbox_inches='tight')
        print(f"Saved plot: {png_path}")
        print(f"Saved plot: {svg_path}")
    except Exception as e:
        print(f"Error saving plot: {e}")
    finally:
        plt.close()


def _radius_from_confidence(conf: float) -> float:
    """Mahalanobis radius for df=2 at given confidence."""
    if conf <= 0 or conf >= 1:
        conf = 0.95
    return float(np.sqrt(-2.0 * np.log(1.0 - conf)))


def plot_cov_ellipse(cov, pos, nstd=None, confidence=None, ax=None, **kwargs):
    """Plot covariance ellipse for `cov` at `pos` (use `confidence` or `nstd`)."""
    def eigsorted(cov):
        vals, vecs = np.linalg.eigh(cov)
        order = vals.argsort()[::-1]
        return vals[order], vecs[:, order]

    if ax is None:
        ax = plt.gca()

    vals, vecs = eigsorted(cov)
    theta = np.degrees(np.arctan2(*vecs[:, 0][::-1]))
    if confidence is not None:
        r = _radius_from_confidence(confidence)
    else:
        r = float(2.0 if nstd is None else nstd)
    width, height = 2 * r * np.sqrt(np.maximum(vals, 0))
    ellip = Ellipse(xy=pos, width=width, height=height, angle=theta, **kwargs)
    ax.add_artist(ellip)
    return ellip


def plot_point_cov(points, nstd=2, ax=None, **kwargs):
    """Compute mean/cov of Nx2 points and draw an `nstd` sigma ellipse."""
    pos = points.mean(axis=0)
    cov = np.cov(points, rowvar=False)
    return plot_cov_ellipse(cov, pos, nstd=nstd, ax=ax, **kwargs)


def plot_ellipses(df: pd.DataFrame, kind: str) -> None:
    """Plot latency (x) vs bandwidth (y) with per-group ellipses."""
    try:
        # Expect 'AQM' (formerly 'params') as the grouping column
        if not {'latency', 'bandwidth', 'AQM'}.issubset(set(df.columns)):
            return
        df = df.dropna(subset=['latency', 'bandwidth', 'AQM'])
        df['latency'] = pd.to_numeric(df['latency'], errors='coerce')
        df['bandwidth'] = pd.to_numeric(df['bandwidth'], errors='coerce')
        if df.empty:
            return

        groups = sorted(df['AQM'].unique())
        width = max(8, min(18, 1.2 * max(3, len(groups))))
        palette = sns.color_palette('Set2', n_colors=len(groups))

        plt.figure(figsize=(width, 6))
        ax = plt.gca()

        filtered_groups = {}
        for grp in groups:
            grp_df = df[df['AQM'] == grp][['latency', 'bandwidth']].dropna()
            n_before = grp_df.shape[0]
            try:
                grp_df = grp_df[grp_df['bandwidth'] > BANDWIDTH_MIN]
            except Exception:
                pass
            n_after_bw = grp_df.shape[0]
            if n_after_bw == 0:
                continue
            try:
                lat_thresh = np.percentile(grp_df['latency'], LATENCY_UPPER_PCT)
                grp_df = grp_df[grp_df['latency'] <= lat_thresh]
            except Exception:
                lat_thresh = None
            n_after_lat = grp_df.shape[0]
            if n_after_lat == 0:
                continue
            try:
                if (n_before != n_after_bw) or (n_after_bw != n_after_lat):
                    print(f"Group '{grp}': {n_before} -> bw>{BANDWIDTH_MIN} => {n_after_bw}", end='')
                    if lat_thresh is not None:
                        print(f" -> latency<={int(LATENCY_UPPER_PCT)}% ({lat_thresh:.2f}) => {n_after_lat}")
                    else:
                        print("")
            except Exception:
                pass
            filtered_groups[grp] = grp_df

        if not filtered_groups:
            return
        group_sizes = [gdf.shape[0] for gdf in filtered_groups.values()]
        sample_size = min(group_sizes) if EQUALIZE_SAMPLES else None
        rng_seed = RNG_SEED
        try:
            if EQUALIZE_SAMPLES:
                print(f"Equalizing groups to {min(group_sizes)} points each (min group size)")
            else:
                print("Equalization disabled; using all available filtered points per group")
        except Exception:
            pass

        ellipse_info = []
        for i, grp in enumerate(groups):
            if grp not in filtered_groups:
                continue
            grp_df = filtered_groups[grp]
            pre_sample_n = grp_df.shape[0]
            try:
                if EQUALIZE_SAMPLES and sample_size is not None and pre_sample_n > sample_size:
                    grp_df = grp_df.sample(n=sample_size, random_state=rng_seed)
                    try:
                        print(f"Group '{grp}': sampled {pre_sample_n} -> {sample_size}")
                    except Exception:
                        pass
            except Exception:
                try:
                    if EQUALIZE_SAMPLES and sample_size is not None and pre_sample_n > sample_size:
                        idx = np.arange(pre_sample_n)
                        sel = np.random.RandomState(rng_seed).choice(idx, size=sample_size, replace=False)
                        grp_df = grp_df.iloc[sel]
                except Exception:
                    pass
            n_after_sample = grp_df.shape[0]
            if n_after_sample == 0:
                continue
            pts = grp_df.to_numpy()
            color = palette[i % len(palette)]
            if SHOW_POINTS_MODE == 'points':
                ax.scatter(pts[:, 0], pts[:, 1], s=14, alpha=0.35, color=color, edgecolor='none')
                med = np.median(pts, axis=0)
                ax.plot(med[0], med[1], marker='D', color=color, markersize=5, label=f"{get_unique_label(grp)} (n={len(pts)})")
            elif SHOW_POINTS_MODE == 'median':
                med = np.median(pts, axis=0)
                ax.plot(med[0], med[1], marker='D', color=color, markersize=5, label=f"{get_unique_label(grp)} (n={len(pts)})")

            try:
                from sklearn.covariance import MinCovDet
                try:
                    mcd = MinCovDet().fit(pts)
                    center = mcd.location_
                    cov = mcd.covariance_
                except Exception:
                    raise
            except Exception:
                try:
                    mean_full = pts.mean(axis=0)
                    cov_full = np.cov(pts, rowvar=False)
                    cov_inv = np.linalg.pinv(cov_full)
                    diff = pts - mean_full
                    d2 = np.sum(diff @ cov_inv * diff, axis=1)
                    thresh = np.percentile(d2, MAHAL_TRIM_PCT)
                    mask = d2 <= thresh
                    pts_trim = pts[mask]
                    if pts_trim.shape[0] >= 3:
                        center = pts_trim.mean(axis=0)
                        cov = np.cov(pts_trim, rowvar=False)
                    else:
                        center = mean_full
                        cov = cov_full
                except Exception:
                    center = pts.mean(axis=0)
                    cov = np.cov(pts, rowvar=False)

            try:
                ell = plot_cov_ellipse(cov, center, confidence=CONFIDENCE_LEVEL, ax=ax, edgecolor=color, facecolor=color, alpha=0.28, linewidth=1.5)
                if SHOW_INNER_ELLIPSE and 0 < INNER_CONFIDENCE < 1:
                    plot_cov_ellipse(cov, center, confidence=INNER_CONFIDENCE, ax=ax, edgecolor=color, facecolor='none', linewidth=1.2, alpha=0.9)
                try:
                    vals, vecs = np.linalg.eigh(cov)
                    vals = np.sort(vals)[::-1]
                    r = _radius_from_confidence(CONFIDENCE_LEVEL)
                    width = 2 * r * np.sqrt(vals[0]) if vals[0] > 0 else 0.0
                    height = 2 * r * np.sqrt(vals[1]) if vals.shape[0] > 1 and vals[1] > 0 else 0.0
                except Exception:
                    width = 0.0
                    height = 0.0
                if 'ellipse_info' not in locals():
                    ellipse_info = []
                ellipse_info.append((center, width, height, color, grp, n_after_sample))
            except Exception:
                try:
                    center_emp = pts.mean(axis=0)
                    cov_emp = np.cov(pts, rowvar=False)
                    plot_cov_ellipse(cov_emp, center_emp, confidence=CONFIDENCE_LEVEL, ax=ax,
                                     edgecolor=color, facecolor=color, alpha=0.28, linewidth=1.5)
                    try:
                        vals, vecs = np.linalg.eigh(cov_emp)
                        vals = np.sort(vals)[::-1]
                        r = _radius_from_confidence(CONFIDENCE_LEVEL)
                        width = 2 * r * np.sqrt(vals[0]) if vals[0] > 0 else 0.0
                        height = 2 * r * np.sqrt(vals[1]) if vals.shape[0] > 1 and vals[1] > 0 else 0.0
                        c_for_info = center_emp
                    except Exception:
                        width = 0.0
                        height = 0.0
                        c_for_info = center_emp
                    if 'ellipse_info' not in locals():
                        ellipse_info = []
                    ellipse_info.append((c_for_info, width, height, color, grp, n_after_sample))
                except Exception:
                    pass

        ax.set_xlabel("RTT (ms)")
        ax.set_ylabel("Throughput (Mbps)")
        ax.grid(alpha=0.25)
        try:
            ax.set_xlim(left=0)
            ax.set_ylim(bottom=0)
        except Exception:
            pass
        try:
            if SHOW_POINTS_MODE != 'points' and 'ellipse_info' in locals() and ellipse_info:
                xs = [c[0][0] for c in ellipse_info]
                ys = [c[0][1] for c in ellipse_info]
                half_ws = [max(0.0, c[1] * 0.6) for c in ellipse_info]
                half_hs = [max(0.0, c[2] * 0.6) for c in ellipse_info]
                xmin = min(x - hw for x, hw in zip(xs, half_ws))
                xmax = max(x + hw for x, hw in zip(xs, half_ws))
                ymin = min(y - hh for y, hh in zip(ys, half_hs))
                ymax = max(y + hh for y, hh in zip(ys, half_hs))
                xpad = max(1.0, 0.02 * (xmax - xmin) if xmax > xmin else 1.0)
                ypad = max(1.0, 0.02 * (ymax - ymin) if ymax > ymin else 1.0)
                ax.set_xlim(max(0, xmin - xpad), xmax + xpad)
                ax.set_ylim(max(0, ymin - ypad), ymax + ypad)
                try:
                    if LOG_X:
                        ax.set_xscale('log')
                    if LOG_Y:
                        ax.set_yscale('log')
                except Exception:
                    pass
                try:
                    from matplotlib.lines import Line2D
                    handles = [Line2D([0], [0], color=info[3], lw=3, alpha=0.9) for info in ellipse_info]
                    labels = [f"{get_unique_label(info[4])} (n={info[5]})" for info in ellipse_info]
                    ax.legend(handles, labels, bbox_to_anchor=(1.02, 1), loc='upper left', title='AQM')
                except Exception:
                    pass
            elif len(groups) > 1:
                ax.legend(bbox_to_anchor=(1.02, 1), loc='upper left', title='AQM')
        except Exception:
            try:
                if len(groups) > 1:
                    ax.legend(bbox_to_anchor=(1.02, 1), loc='upper left', title='AQM')
            except Exception:
                pass
        plt.tight_layout()
        save_plot_image((CURRENT_PLOT_FILE or 'plot'), f"_ellipse_{kind}")
    except Exception as e:
        print(f"Error in plot_ellipses: {e}")


CURRENT_PLOT_FILE = None


def plot_cdf(df: pd.DataFrame, kind: str) -> None:
    try:
        value_col, group_col = df.columns[0], df.columns[1]
        df = df.dropna(subset=[value_col, group_col])
        df[value_col] = pd.to_numeric(df[value_col], errors='coerce')
        if df.empty:
            return
        groups = list(df[group_col].unique())
        width = max(8, min(18, 1.2 * max(3, len(groups))))
        palette = sns.color_palette(n_colors=len(groups))

        plt.figure(figsize=(width, 6))
        for i, grp in enumerate(groups):
            data = df[df[group_col] == grp][value_col].dropna().sort_values()
            if data.size == 0:
                continue
            cdf = np.arange(1, len(data) + 1) / len(data)
            plt.plot(data, cdf, label=f"{get_unique_label(grp)} (n={len(data)})", color=palette[i], linewidth=2.0, alpha=0.9)
            if len(data) <= 200:
                plt.scatter(data, cdf, color=palette[i], s=10, alpha=0.7)
        plt.grid(axis='y', alpha=0.3)
        plt.xlabel("RTT (ms)" if kind == "RTT" else "Throughput (Mbps)")
        plt.ylabel("CDF")
        if len(groups) > 1:
            plt.legend(title=group_col, bbox_to_anchor=(1.02, 1), loc='upper left')
        else:
            plt.legend()
        plt.tight_layout()
        save_plot_image((CURRENT_PLOT_FILE or 'plot'), f"_cdf_{kind}")

        combined = np.concatenate([df[df[group_col] == g][value_col].dropna().values for g in groups]) if len(groups) > 0 else np.array([])
        if combined.size == 0:
            return

        tail_cut = np.percentile(combined, 90)

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
            plt.plot(tail_data, tail_cdf, label=f"{get_unique_label(grp)} (n={len(data)})", color=palette[i], linewidth=2.0, alpha=0.95)
            plt.scatter(tail_data, tail_cdf, color=palette[i], s=8, alpha=0.6)
            tail_min_vals.append(tail_cdf.min())
        plt.xlim(x_left, xmax)
        if tail_min_vals:
            y_min = max(0.0, min(tail_min_vals) - 0.02)
        else:
            y_min = 0.5
        plt.ylim(y_min, 1.0)
        plt.grid(axis='y', alpha=0.3)
        plt.xlabel("RTT (ms)" if kind == "RTT" else "Throughput (Mbps)")
        plt.ylabel("CDF")
        if len(groups) > 1:
            plt.legend(title=f"{group_col} (tail >= {int(100*(1-0.10))}th pct)", bbox_to_anchor=(1.02, 1), loc='upper left')
        else:
            plt.legend()
        plt.tight_layout()
        save_plot_image((CURRENT_PLOT_FILE or 'plot'), f"_cdf_tail_{kind}")

        plt.figure(figsize=(width, 6))
        for i, grp in enumerate(groups):
            data = df[df[group_col] == grp][value_col].dropna().sort_values()
            if data.size == 0:
                continue
            ccdf = 1.0 - (np.arange(1, len(data) + 1) / len(data)) + (1.0 / len(data))
            plt.step(data, ccdf, where='post', label=f"{get_unique_label(grp)} (n={len(data)})", color=palette[i], linewidth=2.0, alpha=0.9)
        plt.yscale('log')
        plt.ylim(1e-4, 1.2)
        plt.grid(which='both', axis='y', linestyle='--', alpha=0.3)
        plt.xlabel("RTT (ms)" if kind == "RTT" else "Throughput (Mbps)")
        plt.ylabel("CCDF = 1 - CDF (log scale)")
        if len(groups) > 1:
            plt.legend(title=group_col, bbox_to_anchor=(1.02, 1), loc='upper left')
        else:
            plt.legend()
        plt.tight_layout()
        save_plot_image((CURRENT_PLOT_FILE or 'plot'), f"_ccdf_log_{kind}")
    except Exception as e:
        print(f"Error in plot_cdf: {e}")


def plot_box(df: pd.DataFrame, kind: str) -> None:
    try:
        value_col, group_col = df.columns[0], df.columns[1]
        df = df.dropna(subset=[value_col, group_col])
        df[value_col] = pd.to_numeric(df[value_col], errors='coerce')
        if df.empty:
            return
        groups = sorted(df[group_col].unique())
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
            medianprops={'linewidth': 2.5}
        )
        try:
            for i, artist in enumerate(ax.artists):
                color = palette[i % len(palette)]
                artist.set_facecolor(color)
                artist.set_edgecolor('gray')
                artist.set_alpha(0.9)
            for line in ax.lines:
                line.set_color('gray')
                line.set_alpha(0.7)
        except Exception:
            pass
        plt.ylabel("RTT (ms)" if kind == "RTT" else "Throughput (Mbps)")
        try:
            pretty_labels = [get_unique_label(g) for g in groups]
            ticks = np.arange(len(groups))
            ax.set_xticks(ticks)
            ax.set_xticklabels(pretty_labels, rotation=45, ha='right')
        except Exception:
            plt.xticks(rotation=45, ha='right')
        plt.grid(axis='y', alpha=0.25)
        plt.tight_layout()
        save_plot_image((CURRENT_PLOT_FILE or 'plot'), f"_box_no_outliers_{kind}")

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
            medianprops={'linewidth': 2.5}
        )
        for i, grp in enumerate(groups):
            grp_data = df[df[group_col] == grp][value_col].dropna().values
            if grp_data.size == 0:
                continue
            x_jitter = np.random.normal(loc=i, scale=0.08, size=len(grp_data))
            plt.scatter(x_jitter, grp_data, color=palette[i % len(palette)], s=10, alpha=0.6)
        try:
            for i, artist in enumerate(ax2.artists):
                color = palette[i % len(palette)]
                artist.set_facecolor(color)
                artist.set_edgecolor('gray')
                artist.set_alpha(0.9)
            for line in ax2.lines:
                line.set_color('gray')
                line.set_alpha(0.7)
        except Exception:
            pass
        plt.ylabel("RTT (ms)" if kind == "RTT" else "Throughput (Mbps)")
        try:
            pretty_labels = [get_unique_label(g) for g in groups]
            ticks = np.arange(len(groups))
            ax2.set_xticks(ticks)
            ax2.set_xticklabels(pretty_labels, rotation=45, ha='right')
        except Exception:
            plt.xticks(rotation=45, ha='right')
        plt.grid(axis='y', alpha=0.25)
        plt.tight_layout()
        save_plot_image((CURRENT_PLOT_FILE or 'plot'), f"_box_with_outliers_{kind}")
    except Exception as e:
        print(f"Error in plot_box: {e}")


csv_folder = os.path.join(os.path.dirname(__file__), "merged")
try:
    csv_files = [f for f in os.listdir(csv_folder) if f.endswith('.csv')]
except Exception as e:
    print(f"Error reading CSV folder: {e}")
    csv_files = []

sns.set_theme(style='whitegrid', palette='Set2', rc={'figure.dpi': 100, 'savefig.dpi': 150})

if csv_files:
    for csv_file in sorted(csv_files):
        csv_path = os.path.join(csv_folder, csv_file)
        try:
            df = pd.read_csv(csv_path)
        except Exception as e:
            print(f"Error reading {csv_file}: {e}")
            continue

        test_name = os.path.splitext(csv_file)[0].lower()

        if 'rrul' in test_name:
            latency_col = 'Ping (ms) avg'
            throughput_col = 'TCP download avg'
        elif test_name.startswith('tcp'):
            latency_col = 'Ping (ms) ICMP'
            throughput_col = 'TCP download sum'
        else:
            print(f"Unknown test type for file {csv_file}, skipping")
            continue

        # Ensure grouping column is 'AQM' (backward compatible with older 'params')
        if 'AQM' not in df.columns:
            if 'params' in df.columns:
                print(f"Renaming 'params' to 'AQM' in {csv_file} (backward compatibility)")
                df = df.rename(columns={'params': 'AQM'})
            else:
                print(f"'AQM' column not found in {csv_file}, skipping")
                continue

        if latency_col in df.columns:
            lat_df = df[[latency_col, 'AQM']].dropna()
            if not lat_df.empty:
                lat_df = lat_df.rename(columns={latency_col: 'value', 'AQM': 'AQM'})
                try:
                    CURRENT_PLOT_FILE = test_name + '_latency'
                    plot_box(lat_df[['value', 'AQM']], 'RTT')
                    plot_cdf(lat_df[['value', 'AQM']], 'RTT')
                except Exception as e:
                    print(f"Error plotting latency for {csv_file}: {e}")
        else:
            print(f"Latency column '{latency_col}' not found in {csv_file}")

        if throughput_col in df.columns:
            tp_df = df[[throughput_col, 'AQM']].dropna()
            if not tp_df.empty:
                tp_df = tp_df.rename(columns={throughput_col: 'value', 'AQM': 'AQM'})
                try:
                    CURRENT_PLOT_FILE = test_name + '_throughput'
                    plot_box(tp_df[['value', 'AQM']], 'Throughput')
                except Exception as e:
                    print(f"Error plotting throughput for {csv_file}: {e}")
        else:
            print(f"Throughput column '{throughput_col}' not found in {csv_file}")

        # If both latency and throughput are available, create ellipse plot (latency x, bandwidth y)
        if (latency_col in df.columns) and (throughput_col in df.columns):
            ell_df = df[[latency_col, throughput_col, 'AQM']].dropna()
            if not ell_df.empty:
                ell_df = ell_df.rename(columns={latency_col: 'latency', throughput_col: 'bandwidth', 'AQM': 'AQM'})
                try:
                    CURRENT_PLOT_FILE = test_name + '_lat_bw'
                    plot_ellipses(ell_df[['latency', 'bandwidth', 'AQM']], 'RTT_vs_Throughput')
                except Exception as e:
                    print(f"Error plotting ellipse for {csv_file}: {e}")
else:
    print("No CSV files found in the folder.")
