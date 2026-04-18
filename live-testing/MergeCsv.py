import os
import glob
import pandas as pd
import re


def merge_csvs_by_all_parents(base_dir: str) -> dict:
    """
    Merge CSV files from all parent directories grouped by subfolder and filename.
    Args:
        base_dir (str): Base directory containing parent folders.
    Returns:
        dict: Nested dictionary {subfolder: {csv_name: DataFrame}}
    """
    try:
        parent_dirs = [os.path.join(base_dir, d) for d in os.listdir(
            base_dir) if os.path.isdir(os.path.join(base_dir, d))]
    except Exception as e:
        print(f"Error reading base_dir '{base_dir}': {e}")
        return {}
    parent_groups = {}
    for parent in parent_dirs:
        m = re.match(r"(.+)-\d+$", os.path.basename(parent))
        if m:
            k = m.group(1)
            parent_groups.setdefault(k, []).append(parent)
    merged = {}
    if not parent_groups:
        print("No parent groups found.")
        return {}
    first_group = next(iter(parent_groups.values()))
    first_parent = first_group[0]
    try:
        subfolders = [entry for entry in os.listdir(
            first_parent) if os.path.isdir(os.path.join(first_parent, entry))]
    except Exception as e:
        print(f"Error reading subfolders in '{first_parent}': {e}")
        return {}
    for subfolder in subfolders:
        csv_names = set()
        for parents in parent_groups.values():
            for parent in parents:
                folder_path = os.path.join(parent, subfolder)
                if os.path.isdir(folder_path):
                    for csv_file in glob.glob(os.path.join(folder_path, '*.csv')):
                        csv_names.add(os.path.basename(csv_file))
        for csv_name in csv_names:
            dfs = []
            for k, parents in parent_groups.items():
                for parent in parents:
                    csv_path = os.path.join(parent, subfolder, csv_name)
                    if os.path.isfile(csv_path):
                        try:
                            df = pd.read_csv(csv_path)
                            df['source_parent'] = k
                            dfs.append(df)
                        except Exception as e:
                            print(f"Error reading {csv_path}: {e}")
            if dfs:
                try:
                    merged.setdefault(subfolder, {})[csv_name] = pd.concat(
                        dfs, ignore_index=True)
                except Exception as e:
                    print(
                        f"Error concatenating DataFrames for {csv_name} in {subfolder}: {e}")
    return merged


def get_tests_csv_dir() -> str:
    """
    Get the absolute path to the tests-csv directory.
    Returns:
        str: Path to tests-csv directory.
    """
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(script_dir, 'tests-csv')


merged = merge_csvs_by_all_parents(get_tests_csv_dir())
output_dir = os.path.join(os.path.dirname(
    os.path.abspath(__file__)), 'merged-csv')
os.makedirs(output_dir, exist_ok=True)
for subfolder, csvs in merged.items():
    for csv_name, df in csvs.items():
        filename = f"{subfolder}_{csv_name}"
        filepath = os.path.join(output_dir, filename)
        try:
            df.to_csv(filepath, index=False)
            print(f"Saved: {filepath}")
        except Exception as e:
            print(f"Error saving {filepath}: {e}")
