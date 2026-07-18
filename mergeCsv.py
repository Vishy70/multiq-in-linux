from pathlib import Path
import csv
import sys


def collect_tests(output_dir: Path):
	tests = {}
	for aqm in sorted(output_dir.iterdir()):
		if not aqm.is_dir():
			continue
		for test in sorted(aqm.iterdir()):
			if not test.is_dir():
				continue
			params = f"{aqm.name}"
			for f in sorted(test.iterdir()):
				if f.suffix.lower() != '.csv' or not f.is_file():
					continue
				tests.setdefault(test.name, []).append((f, params))
	return tests


def merge_tests(tests, out_dir: Path):
	out_dir.mkdir(exist_ok=True)
	for test, files in sorted(tests.items()):
		fields = []
		rows = []
		for f, params in files:
			with f.open('r', encoding='utf-8', newline='') as fh:
				r = csv.DictReader(fh)
				if not r.fieldnames:
					continue
				for c in r.fieldnames:
					if c not in fields:
						fields.append(c)
				for row in r:
					rows.append((row, params))
		if not rows:
			continue
		if 'params' not in fields:
			fields.append('params')
		out = out_dir / f"{test}.csv"
		with out.open('w', encoding='utf-8', newline='') as fh:
			w = csv.DictWriter(fh, fieldnames=fields, extrasaction='ignore')
			w.writeheader()
			for row, params in rows:
				out_row = {k: row.get(k, '') for k in fields if k != 'params'}
				out_row['params'] = params
				w.writerow(out_row)


def main():
	base = Path(__file__).resolve().parent
	print(base)
	src = base / 'results'
	if not src.exists():
		src = base / 'tests-csv'
	if not src.exists():
		print('results or output directory not found')
		sys.exit(1)
	merged = base / 'merged'
	tests = collect_tests(src)
	merge_tests(tests, merged)
	print('merged csvs in', merged)


if __name__ == '__main__':
	main()

