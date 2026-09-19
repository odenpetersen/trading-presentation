import struct

HEAD = struct.Struct('>HH6s')

TAIL = {
	b'S': (('event_code',), struct.Struct('>c')),
	b'R': (('stock','mkt_category','fin_status','round_lot','round_lots_only','issue_class','issue_subtype','authenticity','short_sale_thresh','ipo_flag','luld_tier','etp_flag','etp_leverage','inverse'), struct.Struct('>8sccIcc2scccccIc')),
	b'H': (('stock','trading_state','reserved','reason'), struct.Struct('>8scc4s')),
	b'Y': (('stock','reg_sho_action'), struct.Struct('>8sc')),
	b'L': (('mpid','stock','primary_mm','mm_mode','mkt_part_state'), struct.Struct('>4s8sccc')),
	b'V': (('level1','level2','level3'), struct.Struct('>QQQ')),
	b'W': (('breached_level',), struct.Struct('>c')),
	b'K': (('stock','release_time','release_qualifier','ipo_price'), struct.Struct('>8sIcI')),
	b'J': (('stock','ref_price','upper_collar','lower_collar','extension'), struct.Struct('>8sIIII')),
	b'h': (('stock','market_code','halt_action'), struct.Struct('>8scc')),
	b'A': (('order_ref','buy_sell','shares','stock','price'), struct.Struct('>QcI8sI')),
	b'F': (('order_ref','buy_sell','shares','stock','price','attribution'), struct.Struct('>QcI8sI4s')),
	b'E': (('order_ref','executed_shares','match_num'), struct.Struct('>QIQ')),
	b'C': (('order_ref','executed_shares','match_num','printable','exec_price'), struct.Struct('>QIQcI')),
	b'X': (('order_ref','cancelled_shares'), struct.Struct('>QI')),
	b'D': (('order_ref',), struct.Struct('>Q')),
	b'U': (('orig_order_ref','new_order_ref','shares','price'), struct.Struct('>QQII')),
	b'P': (('order_ref','buy_sell','shares','stock','price','match_num'), struct.Struct('>QcI8sIQ')),
	b'Q': (('shares','stock','cross_price','match_num','cross_type'), struct.Struct('>Q8sIQc')),
	b'B': (('match_num',), struct.Struct('>Q')),
	b'I': (('paired_shares','imbalance_shares','imbalance_dir','stock','far_price','near_price','current_ref_price','cross_type','price_var_ind'), struct.Struct('>QQc8sIIIcc')),
	b'N': (('stock','interest_flag'), struct.Struct('>8sc')),
	b'O': (('stock','open_elig','min_price','max_price','near_exec_price','near_exec_time','lower_collar','upper_collar'), struct.Struct('>8scIIIQII')),
}

def decode(msg):
	t = msg[0:1]
	locate, tracking, tsb = HEAD.unpack_from(msg, 1)
	ts = int.from_bytes(tsb, 'big')
	spec = TAIL.get(t)
	if spec is None:
		return t, locate, tracking, ts, None
	names, st = spec
	return t, locate, tracking, ts, st.unpack_from(msg, 11)

def iter_mold_messages(payload):
	count = struct.unpack_from('>H', payload, 18)[0]
	off = 20
	n = len(payload)
	for _ in range(count):
		if off + 2 > n:
			break
		mlen = struct.unpack_from('>H', payload, off)[0]
		off += 2
		if off + mlen > n:
			break
		yield payload[off:off+mlen]
		off += mlen
