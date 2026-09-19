import sys, os, struct, subprocess, itch
import pyarrow as pa, pyarrow.parquet as pq

FLUSH = 100_000
PKTHDR = struct.Struct('<IIII')

TYPE_NAMES = {
	b'S':'system_event', b'R':'stock_directory', b'H':'trading_action', b'Y':'reg_sho',
	b'L':'mkt_participant_position', b'V':'mwcb_decline_level', b'W':'mwcb_status',
	b'K':'ipo_quoting_period', b'J':'luld_auction_collar', b'h':'operational_halt',
	b'A':'add_order', b'F':'add_order_mpid', b'E':'order_executed', b'C':'order_executed_price',
	b'X':'order_cancel', b'D':'order_delete', b'U':'order_replace', b'P':'trade',
	b'Q':'cross_trade', b'B':'broken_trade', b'I':'noii', b'N':'rpii', b'O':'dlcr',
}

COMMON = ('pkt_idx','cap_ts_ns','mold_seq','locate','tracking','itch_ts_ns')

def eth_udp_payload(buf):
	off = 12
	while buf[off:off+2] == b'\x81\x00':
		off += 4
	if buf[off:off+2] != b'\x08\x00':
		return None
	off += 2
	ihl = (buf[off] & 0x0F) * 4
	proto = buf[off+9]
	if proto != 17:
		return None
	udp_off = off + ihl
	return buf[udp_off+8:]

class TypeBuf:
	def __init__(self, fields):
		self.fields = fields
		self.cols = {f: [] for f in fields}
		self.n = 0
	def add(self, common_vals, tail_vals):
		for f, v in zip(COMMON, common_vals):
			self.cols[f].append(v)
		for f, v in zip(self.fields[len(COMMON):], tail_vals):
			self.cols[f].append(v.decode('ascii').rstrip() if isinstance(v, bytes) else v)
		self.n += 1

def flush(writer_map, outdir, tb, type_byte, close=False):
	if tb.n == 0 and not close:
		return
	table = pa.table(tb.cols)
	name = TYPE_NAMES[type_byte]
	w = writer_map.get(type_byte)
	if w is None:
		w = pq.ParquetWriter(os.path.join(outdir, f'messages_{name}.parquet'), table.schema)
		writer_map[type_byte] = w
	if tb.n:
		w.write_table(table)
	for f in tb.cols:
		tb.cols[f] = []
	tb.n = 0
	if close:
		w.close()

def run(fn, outdir):
	os.makedirs(outdir, exist_ok=True)
	p = subprocess.Popen(['zstd', '-dc', fn], stdout=subprocess.PIPE, bufsize=1<<22)
	f = p.stdout
	gh = f.read(24)
	nsec = gh[:4] == b'\x4d\x3c\xb2\xa1'
	read = f.read
	pkt_idx = 0
	pkt_cols = {c: [] for c in ('pkt_idx','cap_ts_ns','wire_len','cap_len','mold_seq','msg_count')}
	pkt_writer = None
	typebufs = {}
	writer_map = {}
	while True:
		h = read(16)
		if len(h) < 16:
			break
		ts_sec, ts_frac, caplen, origlen = PKTHDR.unpack(h)
		buf = read(caplen)
		if len(buf) < caplen:
			break
		cap_ts_ns = ts_sec * 1_000_000_000 + (ts_frac if nsec else ts_frac * 1000)
		payload = eth_udp_payload(buf)
		mold_seq = None
		msg_count = 0
		if payload is not None and len(payload) >= 20:
			mold_seq = struct.unpack_from('>Q', payload, 10)[0]
			msg_count = struct.unpack_from('>H', payload, 18)[0]
			for msg in itch.iter_mold_messages(payload):
				t, locate, tracking, its, tail = itch.decode(msg)
				fields = TYPE_NAMES.get(t)
				if fields is None:
					continue
				tb = typebufs.get(t)
				if tb is None:
					names, _ = itch.TAIL[t]
					tb = TypeBuf(COMMON + names)
					typebufs[t] = tb
				tb.add((pkt_idx, cap_ts_ns, mold_seq, locate, tracking, its), tail or ())
				if tb.n >= FLUSH:
					flush(writer_map, outdir, tb, t)
		pkt_cols['pkt_idx'].append(pkt_idx)
		pkt_cols['cap_ts_ns'].append(cap_ts_ns)
		pkt_cols['wire_len'].append(origlen)
		pkt_cols['cap_len'].append(caplen)
		pkt_cols['mold_seq'].append(mold_seq)
		pkt_cols['msg_count'].append(msg_count)
		pkt_idx += 1
		if len(pkt_cols['pkt_idx']) >= FLUSH:
			table = pa.table(pkt_cols)
			if pkt_writer is None:
				pkt_writer = pq.ParquetWriter(os.path.join(outdir, 'packets.parquet'), table.schema)
			pkt_writer.write_table(table)
			for c in pkt_cols:
				pkt_cols[c] = []
	f.close(); p.wait()
	table = pa.table(pkt_cols)
	if pkt_writer is None:
		pkt_writer = pq.ParquetWriter(os.path.join(outdir, 'packets.parquet'), table.schema)
	if len(pkt_cols['pkt_idx']):
		pkt_writer.write_table(table)
	pkt_writer.close()
	for t, tb in typebufs.items():
		flush(writer_map, outdir, tb, t, close=True)
	open(os.path.join(outdir, '_DONE'), 'w').close()
	return pkt_idx

if __name__ == '__main__':
	fn, outdir = sys.argv[1], sys.argv[2]
	if os.path.exists(os.path.join(outdir, '_DONE')):
		print('skip (done):', fn)
		sys.exit(0)
	n = run(fn, outdir)
	print('done:', fn, n, 'packets')
