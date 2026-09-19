import glob, os, sys
from datetime import datetime
from zoneinfo import ZoneInfo
import pyarrow.parquet as pq
import numpy as np, pandas as pd

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(ROOT, '..', '..', 'pcaps_parsed'))
DATE = datetime(2023, 8, 22, tzinfo=ZoneInfo('America/New_York'))
MIDNIGHT_NS = int(DATE.timestamp()) * 1_000_000_000
TYPE = sys.argv[1] if len(sys.argv) > 1 else 'add_order'

def buckets_for_file(fn):
	rows = []
	pf = pq.ParquetFile(fn)
	for batch in pf.iter_batches(columns=['cap_ts_ns', 'itch_ts_ns'], batch_size=200_000):
		cap = batch.column('cap_ts_ns').to_numpy()
		itch = batch.column('itch_ts_ns').to_numpy()
		lat = cap - (MIDNIGHT_NS + itch)
		sec = itch // 1_000_000_000
		df = pd.DataFrame({'sec': sec, 'lat': lat})
		g = df.groupby('sec')['lat'].agg(['mean', 'median', lambda s: np.percentile(s, 1), lambda s: np.percentile(s, 99), 'count'])
		g.columns = ['mean', 'median', 'p1', 'p99', 'count']
		rows.append(g)
	return rows

def main():
	files = sorted(glob.glob(os.path.join(OUT, '*', f'messages_{TYPE}.parquet')))
	print(f'{len(files)} files for type {TYPE}', file=sys.stderr)
	parts = []
	for i, fn in enumerate(files):
		parts.extend(buckets_for_file(fn))
		print(f'[{i+1}/{len(files)}] {fn}', file=sys.stderr)
	all_g = pd.concat(parts)
	combined = all_g.groupby(level=0).apply(
		lambda d: pd.Series({
			'mean': np.average(d['mean'], weights=d['count']),
			'median': np.average(d['median'], weights=d['count']),
			'p1': d['p1'].min(),
			'p99': d['p99'].max(),
			'count': d['count'].sum(),
		})
	)
	combined = combined.sort_index()
	combined.to_parquet(os.path.join(OUT, f'_drift_{TYPE}.parquet'))
	print(combined)

if __name__ == '__main__':
	main()
