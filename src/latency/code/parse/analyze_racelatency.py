import glob, os, sys
import numpy as np, pandas as pd
import pyarrow.parquet as pq

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(ROOT, '..', '..', 'pcaps_parsed'))
LATENCIES_NS = [0, 1_000, 10_000, 50_000, 100_000, 500_000, 1_000_000, 5_000_000, 10_000_000, 50_000_000, 100_000_000, 500_000_000, 1_000_000_000]

def load_triggers():
	t = pq.read_table(os.path.join(OUT, '_triggers.parquet')).to_pandas()
	t['price'] = t['price'] / 1e4
	t['spread'] = t['spread'] / 1e4
	t['direction'] = np.where(t['side'] == 1, -1, 1)
	t['time_budget'] = (t['disappear_time'] - t['trigger_time']).astype('Float64')
	t['ratio'] = t['remaining_after'] / t['exec_shares']
	t['spread_bps'] = t['spread'] / t['price'] * 1e4
	t['back_ratio'] = t['back_depth'] / t['exec_shares']
	return t

def load_trade_tape():
	files = sorted(glob.glob(os.path.join(OUT, '*', 'messages_trade.parquet')))
	dfs = [pq.read_table(f, columns=['locate', 'itch_ts_ns', 'price']).to_pandas() for f in files]
	df = pd.concat(dfs, ignore_index=True)
	df['price'] = df['price'] / 1e4
	return df.sort_values('itch_ts_ns').reset_index(drop=True)

def evaluate(trig, tape_arrays, hold_ns, min_ratio=1.0, max_spread_bps=20.0, max_back_ratio=0.5,
			 large_pctl=0.95, min_total_triggers=0, max_ratio=1e18, latencies_ns=LATENCIES_NS, verbose=True):
	t = trig
	if min_total_triggers > 0:
		vol = t.groupby('locate')['exec_shares'].sum()
		t = t[t['locate'].isin(vol[vol >= min_total_triggers].index)]
	thresh = t.groupby('locate')['exec_shares'].quantile(large_pctl)
	t = t.assign(thresh=t['locate'].map(thresh))
	large = t[
		(t['exec_shares'] >= t['thresh']) &
		(t['ratio'] >= min_ratio) & (t['ratio'] <= max_ratio) &
		(t['spread_bps'] <= max_spread_bps) &
		(t['back_ratio'] <= max_back_ratio)
	].reset_index(drop=True)
	if verbose:
		print(f'hold={hold_ns/1e6:.0f}ms min_ratio={min_ratio} max_ratio={max_ratio} max_spread_bps={max_spread_bps} '
			f'max_back_ratio={max_back_ratio} large_pctl={large_pctl} min_total={min_total_triggers}: '
			f'{len(large)} calibrated triggers, {large.locate.nunique()} stocks', file=sys.stderr)
	tb = large['time_budget'].to_numpy()
	tt = large['trigger_time'].to_numpy()
	px = large['price'].to_numpy()
	dr = large['direction'].to_numpy()
	loc = large['locate'].to_numpy()

	results = []
	for lat in latencies_ns:
		caught = np.isnan(tb) | (tb >= lat)
		pnl = 0.0
		n_caught = 0
		for i in np.nonzero(caught)[0]:
			arrs = tape_arrays.get(loc[i])
			if arrs is None:
				continue
			ts_arr, px_arr = arrs
			k = np.searchsorted(ts_arr, tt[i] + lat + hold_ns, side='right') - 1
			if k < 0:
				continue
			pnl += dr[i] * (px_arr[k] - px[i])
			n_caught += 1
		results.append({
			'latency_ns': lat, 'catch_rate': caught.mean(), 'n_caught': n_caught,
			'pnl': pnl, 'avg_pnl_all': pnl / len(large) if len(large) else np.nan,
			'avg_pnl_caught': pnl / n_caught if n_caught else np.nan,
		})
	return pd.DataFrame(results), large

def main():
	hold_ns = int(sys.argv[1]) if len(sys.argv) > 1 else 200_000_000
	min_ratio = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0
	max_spread_bps = float(sys.argv[3]) if len(sys.argv) > 3 else 20.0
	max_back_ratio = float(sys.argv[4]) if len(sys.argv) > 4 else 0.5
	large_pctl = float(sys.argv[5]) if len(sys.argv) > 5 else 0.95
	min_total_triggers = int(sys.argv[6]) if len(sys.argv) > 6 else 0
	max_ratio = float(sys.argv[7]) if len(sys.argv) > 7 else 1e18

	trig = load_triggers()
	tape = load_trade_tape()
	tape_arrays = {locate: (g['itch_ts_ns'].to_numpy(), g['price'].to_numpy()) for locate, g in tape.groupby('locate')}
	res, large = evaluate(trig, tape_arrays, hold_ns, min_ratio, max_spread_bps, max_back_ratio, large_pctl, min_total_triggers, max_ratio)
	res.to_parquet(os.path.join(OUT, '_racelatency.parquet'))
	print(res)
	surv = pd.DataFrame({'time_budget_ns': large['time_budget'].dropna().to_numpy()})
	surv.to_parquet(os.path.join(OUT, '_time_budget_dist.parquet'))

if __name__ == '__main__':
	main()
