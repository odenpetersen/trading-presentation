import glob, os, sys, heapq
import pyarrow as pa, pyarrow.parquet as pq
from sortedcontainers import SortedDict

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(ROOT, '..', '..', 'pcaps_parsed'))
FLUSH = 200_000

def file_dirs():
	return sorted(d for d in glob.glob(os.path.join(OUT, '*')) if os.path.isdir(d))

def rd(d, name, cols):
	fn = os.path.join(d, f'messages_{name}.parquet')
	if not os.path.exists(fn):
		return None
	t = pq.read_table(fn, columns=cols)
	return {c: t.column(c).to_numpy(zero_copy_only=False) for c in cols}

SIDE = {'B': 1, 'S': -1}

def load_sources(d):
	srcs = []
	for name, cols, kind in [
		('add_order', ['itch_ts_ns','locate','order_ref','buy_sell','shares','price'], 'ADD'),
		('add_order_mpid', ['itch_ts_ns','locate','order_ref','buy_sell','shares','price'], 'ADD'),
		('order_executed', ['itch_ts_ns','locate','order_ref','executed_shares'], 'EXEC'),
		('order_executed_price', ['itch_ts_ns','locate','order_ref','executed_shares','printable'], 'EXECP'),
		('order_cancel', ['itch_ts_ns','locate','order_ref','cancelled_shares'], 'CANCEL'),
		('order_delete', ['itch_ts_ns','locate','order_ref'], 'DELETE'),
		('order_replace', ['itch_ts_ns','locate','orig_order_ref','new_order_ref','shares','price'], 'REPLACE'),
	]:
		c = rd(d, name, cols)
		if c is not None and len(c['itch_ts_ns']):
			srcs.append((kind, c))
	return srcs

def merged_events(srcs):
	heap = []
	for i, (kind, c) in enumerate(srcs):
		heap.append((c['itch_ts_ns'][0], i, 0))
	heapq.heapify(heap)
	while heap:
		ts, i, j = heapq.heappop(heap)
		kind, c = srcs[i]
		yield kind, c, j
		j2 = j + 1
		ts_arr = c['itch_ts_ns']
		if j2 < len(ts_arr):
			heapq.heappush(heap, (ts_arr[j2], i, j2))

class Replay:
	def __init__(self):
		self.orders = {}
		self.book = {}
		self.pending = {}
		self.cols = {k: [] for k in ('locate','price','side','trigger_time','exec_shares','remaining_after','spread','back_depth','disappear_time')}
		self.writer = None
		self.n = 0

	def bd(self, locate, side):
		return self.book.setdefault((locate, side), SortedDict())

	def add_level(self, locate, side, price, shares):
		d = self.bd(locate, side)
		d[price] = d.get(price, 0) + shares

	def sub_level(self, locate, side, price, shares, ts):
		d = self.bd(locate, side)
		new = d.get(price, 0) - shares
		if new > 0:
			d[price] = new
		elif price in d:
			del d[price]
		key = (locate, price, side)
		if new <= 0 and key in self.pending:
			for rec in self.pending.pop(key):
				self.emit(key, rec, ts)
		return max(new, 0)

	def best(self, locate, side):
		d = self.book.get((locate, side))
		if not d:
			return None
		return d.peekitem(-1 if side == 1 else 0)[0]

	def back_depth(self, locate, side, price):
		d = self.book.get((locate, side))
		if not d:
			return 0
		if side == -1:
			idx = d.bisect_right(price)
		else:
			idx = d.bisect_left(price) - 1
		if 0 <= idx < len(d):
			return d.peekitem(idx)[1]
		return 0

	def add_trigger(self, key, ts, shares, remaining_after, spread, back_depth):
		self.pending.setdefault(key, []).append((ts, shares, remaining_after, spread, back_depth))

	def emit(self, key, rec, disappear_time):
		locate, price, side = key
		trigger_time, exec_shares, remaining_after, spread, back_depth = rec
		self.cols['locate'].append(locate)
		self.cols['price'].append(price)
		self.cols['side'].append(side)
		self.cols['trigger_time'].append(trigger_time)
		self.cols['exec_shares'].append(exec_shares)
		self.cols['remaining_after'].append(remaining_after)
		self.cols['spread'].append(spread)
		self.cols['back_depth'].append(back_depth)
		self.cols['disappear_time'].append(disappear_time)
		self.n += 1
		if self.n >= FLUSH:
			self.flush()

	def flush(self):
		if self.n == 0:
			return
		table = pa.table(self.cols)
		if self.writer is None:
			self.writer = pq.ParquetWriter(os.path.join(OUT, '_triggers.parquet'), table.schema)
		self.writer.write_table(table)
		for c in self.cols:
			self.cols[c] = []
		self.n = 0

	def process(self, kind, c, j):
		locate = c['locate'][j]
		ts = c['itch_ts_ns'][j]
		if kind == 'ADD':
			ref = c['order_ref'][j]
			side = SIDE.get(c['buy_sell'][j], 0)
			price = c['price'][j]
			shares = c['shares'][j]
			self.orders[ref] = (locate, side, price, shares)
			self.add_level(locate, side, price, shares)
		elif kind in ('EXEC', 'EXECP'):
			ref = c['order_ref'][j]
			o = self.orders.get(ref)
			if o is None:
				return
			locate, side, price, remaining = o
			shares = c['executed_shares'][j]
			is_signal = kind == 'EXEC' or c['printable'][j] == 'Y'
			new_depth = self.sub_level(locate, side, price, shares, ts)
			remaining -= shares
			if remaining > 0:
				self.orders[ref] = (locate, side, price, remaining)
			else:
				self.orders.pop(ref, None)
			if is_signal:
				opp = -side
				best_own = price if new_depth > 0 else self.best(locate, side)
				best_opp = self.best(locate, opp)
				spread = None
				if best_own is not None and best_opp is not None:
					spread = (best_opp - best_own) if side == 1 else (best_own - best_opp)
				back = self.back_depth(locate, side, price)
				key = (locate, price, side)
				if new_depth <= 0:
					self.emit(key, (ts, shares, new_depth, spread, back), ts)
				else:
					self.add_trigger(key, ts, shares, new_depth, spread, back)
		elif kind == 'CANCEL':
			ref = c['order_ref'][j]
			o = self.orders.get(ref)
			if o is None:
				return
			locate, side, price, remaining = o
			shares = c['cancelled_shares'][j]
			remaining -= shares
			if remaining > 0:
				self.orders[ref] = (locate, side, price, remaining)
			else:
				self.orders.pop(ref, None)
			self.sub_level(locate, side, price, shares, ts)
		elif kind == 'DELETE':
			ref = c['order_ref'][j]
			o = self.orders.pop(ref, None)
			if o is None:
				return
			locate, side, price, remaining = o
			self.sub_level(locate, side, price, remaining, ts)
		elif kind == 'REPLACE':
			ref = c['orig_order_ref'][j]
			o = self.orders.pop(ref, None)
			if o is None:
				return
			locate, side, price, remaining = o
			self.sub_level(locate, side, price, remaining, ts)
			new_ref = c['new_order_ref'][j]
			new_price = c['price'][j]
			new_shares = c['shares'][j]
			self.orders[new_ref] = (locate, side, new_price, new_shares)
			self.add_level(locate, side, new_price, new_shares)

	def finish(self):
		for key, lst in self.pending.items():
			for rec in lst:
				self.emit(key, rec, None)
		self.flush()
		if self.writer is not None:
			self.writer.close()

def main():
	dirs = file_dirs()
	if len(sys.argv) > 1:
		dirs = dirs[:int(sys.argv[1])]
	r = Replay()
	for i, d in enumerate(dirs):
		srcs = load_sources(d)
		n = 0
		for kind, c, j in merged_events(srcs):
			r.process(kind, c, j)
			n += 1
		print(f'[{i+1}/{len(dirs)}] {os.path.basename(d)} {n} events, live orders {len(r.orders)}, pending {sum(len(v) for v in r.pending.values())}', file=sys.stderr, flush=True)
	r.finish()
	print('triggers written:', os.path.join(OUT, '_triggers.parquet'), file=sys.stderr)

if __name__ == '__main__':
	main()
