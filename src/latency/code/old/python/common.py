"""Tiny shared TCP client + book reconstruction, used by every strategy and
the dashboard. Everything talks to the engine's single port; there is no
separate market-data port -- every connection gets both the public feed and
(if it's trading) its own private ACK/FILL lines on the same socket.
"""
import math
import socket
import threading

HOST, PORT = "127.0.0.1", 7000
TICK_SIZE = 0.01  # must match engine/order_book.hpp


def true_value(t):
    """Synthetic 'fair value' curve. Every participant computes this locally
    from wall-clock time -- no signal server needed -- then adds its own
    noise (see strategies' --signal_noise) to get an imperfect private read
    of it. That noise is what produces adverse selection."""
    return 100.0 + 3 * math.sin(t / 17.0) + 1.5 * math.sin(t / 5.3 + 1) + 0.7 * math.sin(t / 1.9 + 2)


class Client:
    """One TCP connection. `sender=None` means subscribe-only (dashboard)."""

    def __init__(self, sender, on_line=None):
        self.sender = sender
        self.sock = socket.create_connection((HOST, PORT))
        self.on_line = on_line
        self._buf = b""
        threading.Thread(target=self._read_loop, daemon=True).start()

    def send(self, line):
        self.sock.sendall((line + "\n").encode())

    def gfd(self, side, price, qty):
        self.send(f"GFD {side} {self.sender} {price:.2f} {qty}")

    def fak(self, side, price, qty):
        self.send(f"FAK {side} {self.sender} {price:.2f} {qty}")

    def cancel(self, order_id):
        self.send(f"CANCEL {self.sender} {order_id}")

    def _read_loop(self):
        while True:
            chunk = self.sock.recv(4096)
            if not chunk:
                break
            self._buf += chunk
            while b"\n" in self._buf:
                line, self._buf = self._buf.split(b"\n", 1)
                if self.on_line:
                    self.on_line(line.decode())


class BookView:
    """Reconstructs book state (and each participant's own resting order
    ids) purely from the public SEQ feed -- the same information everyone,
    including the dashboard, can see."""

    def __init__(self):
        self.bids, self.asks = {}, {}          # price -> total qty
        self.order_price = {}                  # order_id -> (side, price, qty)
        self.last_trade = None

    def feed(self, line):
        p = line.split()
        if p[0] != "SEQ":
            return None
        kind = p[2]
        if kind == "ADD":
            oid, sender, side, price, qty, ns = p[3], int(p[4]), p[5], float(p[6]), int(p[7]), int(p[8])
            book = self.bids if side == "BUY" else self.asks
            book[price] = book.get(price, 0) + qty
            self.order_price[oid] = (side, price, qty)
            return ("ADD", oid, sender, side, price, qty, ns)

        if kind == "CANCEL":
            oid = p[3]
            if oid in self.order_price:
                side, price, qty = self.order_price.pop(oid)
                book = self.bids if side == "BUY" else self.asks
                book[price] = book.get(price, 0) - qty
                if book[price] <= 0:
                    book.pop(price, None)
            return ("CANCEL", oid)

        if kind == "TRADE":
            aid, asnd, rid, rsnd = p[3], int(p[4]), p[5], int(p[6])
            price, qty, wash, ns = float(p[7]), int(p[8]), p[9] == "1", int(p[10])
            rest_side = None
            if rid in self.order_price:
                rest_side, rp, rq = self.order_price[rid]
                book = self.bids if rest_side == "BUY" else self.asks
                book[rp] = book.get(rp, 0) - qty
                if book[rp] <= 0:
                    book.pop(rp, None)
                rq -= qty
                if rq <= 0:
                    self.order_price.pop(rid, None)
                else:
                    self.order_price[rid] = (rest_side, rp, rq)
            self.last_trade = price
            return ("TRADE", aid, asnd, rid, rsnd, rest_side, price, qty, wash, ns)
        return None

    @property
    def best_bid(self):
        return max(self.bids) if self.bids else None

    @property
    def best_ask(self):
        return min(self.asks) if self.asks else None
