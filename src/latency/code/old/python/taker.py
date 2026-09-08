#!/usr/bin/env python3
"""No resting orders at all -- only ever crosses the spread when its private
signal diverges from the book by more than `threshold`. This is the cleanest
adverse-selection demo: its fills should show a consistently positive edge
against true_value, at the market makers' expense.
"""
import argparse
import random
import time

from common import BookView, Client, true_value

a = argparse.ArgumentParser()
a.add_argument("--id", type=int, required=True)
a.add_argument("--signal_noise", type=float, default=0.15, help="lower = better-informed")
a.add_argument("--threshold", type=float, default=0.15)
a.add_argument("--qty", type=int, default=3)
a.add_argument("--interval", type=float, default=0.2)
args = a.parse_args()

book = BookView()
client = Client(args.id, book.feed)
t0 = time.time()

while True:
    t = time.time() - t0
    signal = true_value(t) + random.gauss(0, args.signal_noise)
    if book.best_ask and signal > book.best_ask + args.threshold:
        client.fak("BUY", book.best_ask, args.qty)
    elif book.best_bid and signal < book.best_bid - args.threshold:
        client.fak("SELL", book.best_bid, args.qty)
    time.sleep(args.interval)
