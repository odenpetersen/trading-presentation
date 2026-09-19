import asyncio, json, socket, sys
import websockets
import protocol as p

ME_HOST = sys.argv[1] if len(sys.argv) > 1 else '127.0.0.1'
ME_FEED_IN_PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 17002
STREAM = 'wss://stream.binance.com:9443/ws/btcusdt@trade'

async def main():
	sock = socket.create_connection((ME_HOST, ME_FEED_IN_PORT))
	sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
	async with websockets.connect(STREAM) as ws:
		async for raw in ws:
			d = json.loads(raw)
			sock.sendall(p.ref_price('BTCUSDT', float(d['p']), int(d['T']) * 1_000_000))

if __name__ == '__main__':
	asyncio.run(main())
