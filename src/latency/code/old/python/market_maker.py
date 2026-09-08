#!/usr/bin/env python3
"""Quotes both sides at `width` ticks beyond `levels_from_touch` from the
touch, and separately takes when its private signal disagrees with its own
quotes (this is where it, like everyone but the dumb trader, makes most of
its money). A narrow, levels_from_touch=0 maker sits at the touch and stays
cache-warm + gets its own private fills before anyone sees the public feed.

--cancel_before_requote is the one lever for the SMP demo: without it, old
resting quotes are never cancelled before a fresh pair is sent, so they pile
up and eventually a new quote crosses one of the old ones -- a wash trade
whenever SMP is off. (Quoting and taking alternate ticks rather than sharing
one, so a take decision never races its own just-sent, not-yet-acknowledged
quote -- otherwise it could mistake its own resting order for an opportunity
and wash-trade itself regardless of --cancel_before_requote.)
"""
import argparse
import random
import time

from common import BookView, Client, true_value

a = argparse.ArgumentParser()
a.add_argument("--id", type=int, required=True)
a.add_argument("--width", type=float, default=0.02, help="ticks from touch to quote")
a.add_argument("--levels_from_touch", type=int, default=0, help="0 = top of book, 1 = level behind, ...")
a.add_argument("--cancel_before_requote", action="store_true")
a.add_argument("--signal_noise", type=float, default=0.3)
a.add_argument("--qty", type=int, default=5)
a.add_argument("--interval", type=float, default=0.3)
args = a.parse_args()

book = BookView()
resting = {"BUY": None, "SELL": None}  # side -> (order_id, price)


def on_line(line):
    ev = book.feed(line)
    if not ev:
        return
    if ev[0] == "ADD":
        _, oid, sender, side, price, qty, ns = ev
        if sender == args.id:
            resting[side] = (oid, price)
    elif ev[0] == "CANCEL":
        _, oid = ev
        for side, r in resting.items():
            if r and r[0] == oid:
                resting[side] = None
    elif ev[0] == "TRADE":
        _, aid, asnd, rid, rsnd, rest_side, price, qty, wash, ns = ev
        for side, r in resting.items():
            if r and r[0] == rid and rid not in book.order_price:
                resting[side] = None


client = Client(args.id, on_line)
t0 = time.time()
tick = 0

while True:
    t = time.time() - t0
    mid = ((book.best_bid or 100.0) + (book.best_ask or 100.0)) / 2
    step = args.width * (args.levels_from_touch + 1)
    quote = {"BUY": round(mid - step, 2), "SELL": round(mid + step, 2)}

    if tick % 2 == 0:
        # Cancel *both* old sides before sending *either* new one: with a
        # single sender funnelled through one worker thread and one
        # matching thread, messages are processed strictly in the order we
        # send them, so this guarantees neither new quote can ever cross
        # our own still-resting one.
        if args.cancel_before_requote:
            for side in quote:
                if resting[side]:
                    client.cancel(resting[side][0])
        for side, price in quote.items():
            client.gfd(side, price, args.qty)
    else:
        # A full tick has passed since we last quoted, so `resting` has
        # caught up with our own orders -- safe to compare against it.
        my_bid = resting["BUY"][1] if resting["BUY"] else None
        my_ask = resting["SELL"][1] if resting["SELL"] else None
        signal = true_value(t) + random.gauss(0, args.signal_noise)
        if book.best_ask and book.best_ask != my_ask and signal > quote["SELL"]:
            client.fak("BUY", book.best_ask, args.qty)
        elif book.best_bid and book.best_bid != my_bid and signal < quote["BUY"]:
            client.fak("SELL", book.best_bid, args.qty)

    tick += 1
    time.sleep(args.interval)
