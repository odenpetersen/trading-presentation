import struct

MSG_SIZE = 45

NEW_ORDER, CANCEL, ACK, FILL, REJECT, LEVEL_UPDATE, TRADE, REF_PRICE, AUTH_CHECK_REQUEST, AUTH_CHECK_RESPONSE, SET_CONFIG, TRADE_REPORT, RACE_RESULT = range(13)

BUY, SELL = 0, 1

SELF_MATCH_PREVENTION, GATEWAY_SELECTION_MODE, PARTICIPANT_AUTHORISED, AUTH_CACHE_TTL_MS, QUOTE_REFRESH_MS = range(5)

REF_PRICE_SCALE = 100_000_000

FORMATS = {
	NEW_ORDER: '<QIBII', CANCEL: '<QII', ACK: '<IQQQQ', FILL: '<IQIIQQQ', REJECT: '<QB',
	LEVEL_UPDATE: '<BII?', TRADE: '<BII', REF_PRICE: '<8sqQ', AUTH_CHECK_REQUEST: '<I',
	AUTH_CHECK_RESPONSE: '<I?Q', SET_CONFIG: '<BIq', TRADE_REPORT: '<QIIBIIQQ', RACE_RESULT: '<IB',
}

FIELDS = {
	NEW_ORDER: ('coid', 'participant', 'side', 'price', 'qty'),
	CANCEL: ('coid', 'participant', 'id'),
	ACK: ('id', 'coid', 'me_time', 'gateway_time', 'publish_time'),
	FILL: ('id', 'coid', 'price', 'qty', 'me_time', 'gateway_time', 'publish_time'),
	REJECT: ('coid', 'reason'),
	LEVEL_UPDATE: ('side', 'price', 'qty', 'added'),
	TRADE: ('side', 'price', 'qty'),
	REF_PRICE: ('symbol', 'price', 'exch_time'),
	AUTH_CHECK_REQUEST: ('participant',),
	AUTH_CHECK_RESPONSE: ('participant', 'authorised', 'checked_at'),
	SET_CONFIG: ('param', 'target_participant', 'value'),
	TRADE_REPORT: ('taker_coid', 'taker', 'maker', 'side', 'price', 'qty', 'me_time', 'publish_time'),
	RACE_RESULT: ('participant', 'winner_gw'),
}

def encode(msg_type, *args):
	payload = struct.pack(FORMATS[msg_type], *args)
	return bytes([msg_type]) + payload + b'\0' * (MSG_SIZE - 1 - len(payload))

def decode(buf):
	msg_type = buf[0]
	if msg_type not in FORMATS:
		return {'type': msg_type}
	fmt = FORMATS[msg_type]
	size = struct.calcsize(fmt)
	values = struct.unpack(fmt, buf[1:1 + size])
	d = dict(zip(FIELDS[msg_type], values))
	d['type'] = msg_type
	if msg_type == REF_PRICE:
		d['symbol'] = d['symbol'].rstrip(b'\0').decode()
		d['price'] = d['price'] / REF_PRICE_SCALE
	return d

def ref_price(symbol, price_float, exch_time_ns):
	sym = symbol.encode()[:8].ljust(8, b'\0')
	return encode(REF_PRICE, sym, round(price_float * REF_PRICE_SCALE), exch_time_ns)

def set_config(param, target_participant, value):
	return encode(SET_CONFIG, param, target_participant, value)
