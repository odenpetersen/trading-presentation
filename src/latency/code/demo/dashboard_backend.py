import asyncio, json, socket, sys, time
from collections import deque
from aiohttp import web
import protocol as p

ME_HOST = sys.argv[1] if len(sys.argv) > 1 else '127.0.0.1'
ME_MD_PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 17001
ME_CONTROL_PORT = int(sys.argv[3]) if len(sys.argv) > 3 else 17003
GW_A_CONTROL = (sys.argv[4] if len(sys.argv) > 4 else '127.0.0.1', int(sys.argv[5]) if len(sys.argv) > 5 else 18001)
GW_B_CONTROL = (sys.argv[6] if len(sys.argv) > 6 else '127.0.0.1', int(sys.argv[7]) if len(sys.argv) > 7 else 18011)
STRAT_A_CONTROL = (sys.argv[8] if len(sys.argv) > 8 else '127.0.0.1', int(sys.argv[9]) if len(sys.argv) > 9 else 19000)
STRAT_B_CONTROL = (sys.argv[10] if len(sys.argv) > 10 else '127.0.0.1', int(sys.argv[11]) if len(sys.argv) > 11 else 19010)
HTTP_PORT = int(sys.argv[12]) if len(sys.argv) > 12 else 8080

book = {p.BUY: {}, p.SELL: {}}
trades = deque(maxlen=200)
ref_prices = deque(maxlen=500)
clients = set()
stats = {}  # participant -> {taker_fills, taker_qty, maker_fills, maker_qty, cash, wins, losses, gw_a_wins, gw_b_wins}

def stat(participant):
	return stats.setdefault(participant, {'taker_fills': 0, 'taker_qty': 0, 'maker_fills': 0, 'maker_qty': 0, 'cash': 0.0, 'wins': 0, 'losses': 0, 'gw_a_wins': 0, 'gw_b_wins': 0})

batch = {'coid': None, 'count': 0, 'gap_ns': 0}

# running win-rate: markout against Binance's own price, not the demo book's
# mid - the demo maker's quotes are static (never track Binance), so the
# book's mid barely moves and a book-mid markout degenerates into "taker
# always loses the spread, maker always wins" regardless of whether the
# taker's Binance-driven bet was actually good. Binance's real price
# movement is the actual signal the taker is trading on, so it's what
# should judge whether that bet paid off. Ties are pushes, don't count.
MARKOUT_DELAY_S = 1.5
markouts = deque()  # [(eval_at, participant, is_taker, side, ref_price_at_fill), ...]
last_ref_price = None

async def markout_evaluator():
	while True:
		await asyncio.sleep(0.2)
		now = time.time()
		changed = False
		while markouts and markouts[0][0] <= now:
			_, participant, is_taker, side, ref_at_fill = markouts.popleft()
			if last_ref_price is None or last_ref_price == ref_at_fill:
				continue  # no ref feed yet, or a push - doesn't count
			moved_up = last_ref_price > ref_at_fill
			buy_side = side == p.BUY
			# taker bought/sold expecting Binance to keep moving their way;
			# maker is the opposite side of that same trade
			taker_won = moved_up == buy_side
			won = taker_won if is_taker else not taker_won
			s = stat(participant)
			s['wins' if won else 'losses'] += 1
			changed = True
		if changed:
			await broadcast({'kind': 'stats', 'stats': stats})

async def apply_trade_report(d):
	notional = d['price'] * d['qty']
	taker, maker = stat(d['taker']), stat(d['maker'])
	taker['taker_fills'] += 1; taker['taker_qty'] += d['qty']
	maker['maker_fills'] += 1; maker['maker_qty'] += d['qty']
	sign = -1 if d['side'] == p.BUY else 1  # taker buys -> pays out; taker sells -> receives
	taker['cash'] += sign * notional
	maker['cash'] -= sign * notional
	if last_ref_price is not None:
		eval_at = time.time() + MARKOUT_DELAY_S
		markouts.append((eval_at, d['taker'], True, d['side'], last_ref_price))
		markouts.append((eval_at, d['maker'], False, d['side'], last_ref_price))
	await broadcast({'kind': 'stats', 'stats': stats})

	global batch
	if d['taker_coid'] != batch['coid']:
		if batch['coid'] is not None:
			await broadcast({'kind': 'batch', 'n': batch['count'], 'gap_ns': batch['gap_ns']})
		batch = {'coid': d['taker_coid'], 'count': 1, 'gap_ns': d['publish_time'] - d['me_time']}
	else:
		batch['count'] += 1

def apply_level(d):
	side_book = book[d['side']]
	qty = side_book.get(d['price'], 0) + d['qty'] if d['added'] else side_book.get(d['price'], 0) - d['qty']
	if qty > 0: side_book[d['price']] = qty
	else: side_book.pop(d['price'], None)

def book_snapshot():
	return {'kind': 'book', 'bids': sorted(book[p.BUY].items(), reverse=True)[:10], 'asks': sorted(book[p.SELL].items())[:10]}

async def broadcast(msg):
	dead = set()
	for ws in clients:
		try: await ws.send_json(msg)
		except Exception: dead.add(ws)
	clients.difference_update(dead)

async def md_reader():
	while True:
		try:
			reader, _ = await asyncio.open_connection(ME_HOST, ME_MD_PORT)
			while True:
				buf = await reader.readexactly(p.MSG_SIZE)
				d = p.decode(buf)
				if d['type'] == p.LEVEL_UPDATE:
					apply_level(d)
					await broadcast(book_snapshot())
				elif d['type'] == p.TRADE:
					t = {'kind': 'trade', 'side': d['side'], 'price': d['price'], 'qty': d['qty'], 't': time.time()}
					trades.append(t)
					await broadcast(t)
				elif d['type'] == p.REF_PRICE:
					global last_ref_price
					last_ref_price = d['price']
					r = {'kind': 'ref_price', 'price': d['price'], 't': time.time()}
					ref_prices.append(r)
					await broadcast(r)
				elif d['type'] == p.TRADE_REPORT:
					await apply_trade_report(d)
				elif d['type'] == p.RACE_RESULT:
					s = stat(d['participant'])
					s['gw_a_wins' if d['winner_gw'] == 0 else 'gw_b_wins'] += 1
					await broadcast({'kind': 'stats', 'stats': stats})
		except Exception as e:
			print('md_reader error', repr(e))
			await asyncio.sleep(1)

def send_control(addr, buf):
	try:
		s = socket.create_connection(addr, timeout=2)
		s.sendall(buf)
		s.close()
	except Exception as e:
		print('control send failed', addr, e)

def handle_command(cmd):
	a = cmd['action']
	if a == 'smp':
		v = int(cmd['value'])
		send_control((ME_HOST, ME_CONTROL_PORT), p.set_config(p.SELF_MATCH_PREVENTION, 0, v))
		send_control(STRAT_A_CONTROL, p.set_config(p.SELF_MATCH_PREVENTION, 0, v))
		send_control(STRAT_B_CONTROL, p.set_config(p.SELF_MATCH_PREVENTION, 0, v))
	elif a == 'auth': send_control((ME_HOST, ME_CONTROL_PORT), p.set_config(p.PARTICIPANT_AUTHORISED, int(cmd['participant']), int(cmd['value'])))
	elif a == 'ttl':
		send_control(GW_A_CONTROL, p.set_config(p.AUTH_CACHE_TTL_MS, 0, int(cmd['value'])))
		send_control(GW_B_CONTROL, p.set_config(p.AUTH_CACHE_TTL_MS, 0, int(cmd['value'])))
	elif a == 'gwmode':
		# broadcast to both strategy instances; each ignores it unless the
		# target_participant is one of its own (taker or maker) participant ids
		participant = int(cmd['participant'])
		v = int(cmd['value'])
		send_control(STRAT_A_CONTROL, p.set_config(p.GATEWAY_SELECTION_MODE, participant, v))
		send_control(STRAT_B_CONTROL, p.set_config(p.GATEWAY_SELECTION_MODE, participant, v))
	elif a == 'quote_refresh':
		send_control(STRAT_A_CONTROL, p.set_config(p.QUOTE_REFRESH_MS, 0, int(cmd['value'])))
		send_control(STRAT_B_CONTROL, p.set_config(p.QUOTE_REFRESH_MS, 0, int(cmd['value'])))

async def ws_handler(request):
	ws = web.WebSocketResponse()
	await ws.prepare(request)
	clients.add(ws)
	await ws.send_json(book_snapshot())
	await ws.send_json({'kind': 'stats', 'stats': stats})
	async for msg in ws:
		if msg.type == web.WSMsgType.TEXT:
			handle_command(json.loads(msg.data))
	clients.discard(ws)
	return ws

async def index(request):
	return web.FileResponse('dashboard.html')

app = web.Application()
app.router.add_get('/', index)
app.router.add_get('/ws', ws_handler)

async def main():
	global md_reader_task, markout_task
	md_reader_task = asyncio.ensure_future(md_reader())  # kept referenced - GC'd tasks silently stop
	markout_task = asyncio.ensure_future(markout_evaluator())
	runner = web.AppRunner(app)
	await runner.setup()
	site = web.TCPSite(runner, '0.0.0.0', HTTP_PORT)
	await site.start()
	print(f'dashboard on http://localhost:{HTTP_PORT}')
	await asyncio.Event().wait()

if __name__ == '__main__':
	asyncio.run(main())
