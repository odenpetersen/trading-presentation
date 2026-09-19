#!/usr/bin/env python3
"""Big, price-insensitive GFD flow whose direction is autocorrelated (a
Markov chain: same side as last time with probability p_persist). This is
the noise trader everyone else picks off, and --price_range controls how
many distinct ticks it roams across -- widen it to blow past your machine's
L2 and make cache evictions actually happen (see README).
"""
import argparse
import random
import time

from common import TICK_SIZE, BookView, Client

a = argparse.ArgumentParser()
a.add_argument("--id", type=int, required=True)
a.add_argument("--qty", type=int, default=50)
a.add_argument("--p_persist", type=float, default=0.7)
a.add_argument("--price_range", type=float, default=8000.0, help="+/- ticks around mid; drives cache eviction")
a.add_argument("--interval", type=float, default=0.05, help="fast by design: needs volume to pollute the cache")
args = a.parse_args()

book = BookView()
client = Client(args.id, book.feed)
side = random.choice(["BUY", "SELL"])

while True:
    side = side if random.random() < args.p_persist else ("SELL" if side == "BUY" else "BUY")
    mid = ((book.best_bid or 100.0) + (book.best_ask or 100.0)) / 2
    price = round(mid + random.uniform(-args.price_range, args.price_range) * TICK_SIZE, 2)
    client.gfd(side, price, args.qty)
    time.sleep(args.interval)
