#!/usr/bin/env python3
"""Live terminal dashboard, subscribed to the engine like any other
connection (sender=None -- it never sends an order). Everything shown here
is derived purely from the public SEQ feed.
"""
import statistics
import time
from collections import defaultdict

from rich.columns import Columns
from rich.live import Live
from rich.table import Table

from common import BookView, Client, true_value
from participants import PARTICIPANTS

labels = {p["id"]: p["label"] for p in PARTICIPANTS}
book = BookView()
fills = defaultdict(int)
wash = defaultdict(int)
access_cyc = defaultdict(list)
markout = defaultdict(list)  # adverse selection: this participant's edge vs true_value at fill time

t0 = time.time()


def on_line(line):
    ev = book.feed(line)
    if not ev:
        return
    # Every resting insert also touches (and times) a price level -- this is
    # where the dumb trader's wide, scattered quotes show up as cold misses;
    # a TRADE's touch is always at the current best price, so on its own it
    # can't tell a narrow quoter's warm re-touches from a wide roamer's.
    if ev[0] == "ADD":
        _, oid, sender, side, price, qty, ns = ev
        access_cyc[sender].append(ns)
        return
    if ev[0] != "TRADE" or ev[5] is None:
        return
    _, aid, asnd, rid, rsnd, rest_side, price, qty, was, ns = ev
    fills[asnd] += qty
    fills[rsnd] += qty
    if was:
        wash[rsnd] += qty
    access_cyc[asnd].append(ns)
    access_cyc[rsnd].append(ns)

    tv = true_value(time.time() - t0)
    aggr_side = "SELL" if rest_side == "BUY" else "BUY"
    edge = (tv - price) if aggr_side == "BUY" else (price - tv)
    markout[asnd].append(edge)   # aggressor's edge
    markout[rsnd].append(-edge)  # resting side's edge (adverse selection when consistently negative)


Client(None, on_line)


def book_table():
    t = Table(title="Order book (top 5)")
    t.add_column("Bid"); t.add_column("Ask")
    bids = sorted(book.bids, reverse=True)[:5]
    asks = sorted(book.asks)[:5]
    for i in range(max(len(bids), len(asks))):
        b = f"{bids[i]:.2f} x{book.bids[bids[i]]}" if i < len(bids) else ""
        a = f"{asks[i]:.2f} x{book.asks[asks[i]]}" if i < len(asks) else ""
        t.add_row(b, a)
    return t


def participant_table():
    t = Table(title="Participants")
    for col in ("Participant", "Fill qty", "Wash qty", "Avg access (cyc)", "Adverse selection"):
        t.add_column(col)
    for sid, label in labels.items():
        ns, mo = access_cyc[sid], markout[sid]
        t.add_row(
            label,
            str(fills[sid]),
            str(wash[sid]),
            f"{statistics.median(ns):.0f}" if ns else "-",  # median: robust to rare scheduler-jitter outliers
            f"{statistics.mean(mo):+.3f}" if mo else "-",
        )
    return t


with Live(refresh_per_second=4) as live:
    while True:
        live.update(Columns([book_table(), participant_table()]))
        time.sleep(0.25)
