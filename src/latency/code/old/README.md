# Live matching-engine demo

A tiny C++ matching engine (`engine/`, extending `spec.md`) plus a handful of
short Python strategies and a live terminal dashboard (`python/`), all
talking to a single TCP port on localhost. Built to demonstrate, live:

1. **Cache warming** -- a participant that keeps touching the same price
   levels stays fast; one that scatters across many ticks evicts everyone.
2. **Private feed advantage** -- every participant gets its own fill/ack
   directly on its own connection; the public feed (which is how everyone
   reconstructs the book, including your own resting-order state) is a
   broadcast to every connection and is strictly slower to update for you
   than your own private ack was.
3. **Self-match prevention** -- `--smp` on vs off changes whether a
   participant's own resting orders can trade against its own new orders.
4. **Cache vs. disk for validation** -- "does this sender exist" is checked
   against a tiny in-memory cache backed by ground truth on disk; a cache
   hit avoids a syscall entirely, a miss pays a real `stat()`.

## Build & run

```sh
cd engine && make
./engine 4 roster.txt            # SMP off
./engine 4 roster.txt --smp      # SMP on
```

`roster.txt` is the human-editable list of sender ids allowed to trade. At
startup the engine materializes it into `engine/users/<id>` -- one empty
file per known sender -- which is the actual ground truth a validation
cache miss reads (see the cache-vs-disk demo below). It must match the ids
used in `python/participants.py`.

Then, from `python/`, in separate terminals (or via `python3 launch_all.py`
for quick iteration -- see its docstring):

```sh
python3 dashboard.py
python3 dumb_trader.py --id 1
python3 market_maker.py --id 2 --width 0.02 --levels_from_touch 0 --cancel_before_requote
python3 market_maker.py --id 3 --width 0.10 --levels_from_touch 1 --interval 1.2
python3 taker.py --id 4
```

(`participants.py` is the single source of truth for these four -- edit it
and restart to reconfigure a segment.)

## Demo segments

**Self-match prevention.** Run with SMP off. `market_maker.py --id 3` never
cancels its old quote before sending a new one (`--cancel_before_requote` is
absent), so its own stale resting orders eventually get crossed by its own
fresh ones -- watch its "Wash qty" column climb. `--id 2` passes
`--cancel_before_requote`, cancels both old sides before sending either new
one, and stays at zero. The dumb trader also washes itself (it manages
nothing) -- that's expected and reinforces why real exchanges don't rely on
participants self-policing. Restart the engine with `--smp` and rerun: wash
qty stays at zero for everyone, including the dumb trader -- the engine
skips matching against a participant's own resting orders instead of
crossing them.

**Adverse selection.** Every strategy reads the same synthetic "true value"
curve (`common.true_value`, a fixed sum of sines -- everyone computes it
locally, no signal server) plus its own noise (`--signal_noise`; lower =
better-informed) as its private read of fair value, and trades on the
disagreement. Watch the dashboard's "Adverse selection" column: the tight,
always-at-the-touch `MM-top` should run consistently negative (it's the one
getting picked off), while `Taker` (the best-informed, lowest
`--signal_noise`) should run consistently positive.

**Cache warming / private feed advantage.** The order book stores price
levels in a flat array indexed by price tick (`engine/order_book.hpp`), and
every level touch is timed with `RDTSC` (real CPU cycles, not a simulated
delay). A narrow, top-of-book quoter re-touches a handful of ticks
constantly; the dumb trader's wide, scattered resting inserts pollute many
distinct ticks. Watch "Avg access (cyc)" on the dashboard for the gap.

This one needs tuning to your actual demo machine:
- Run `lscpu` and note your L2 size. `engine/order_book.hpp` sizes each
  `Level` (`LEVEL_LINES`, currently 16 cache lines) and prints the total
  book footprint at startup (`NUM_TICKS * sizeof(Level)`); the dumb
  trader's *distinct resting ticks touched* need to exceed your L2 for the
  gap to show up. Fewer/bigger `Level`s means fewer distinct ticks needed.
- `dumb_trader.py --price_range` (ticks either side of mid; default 8000)
  controls how wide a range it scatters across -- it needs to be wide
  enough, and `--interval` fast enough, to rack up thousands of distinct
  ticks within your demo window.
- Close other CPU-hungry apps before the live demo -- scheduler contention
  from unrelated processes adds noise on the same order of magnitude as the
  effect you're measuring. The dashboard reports the *median*, not the
  mean, specifically to be more robust to occasional scheduler stalls.

**Cache vs. disk for validation.** `engine/user_store.hpp`: each validation
worker owns a tiny LRU cache (`--cache N`, default 1) in front of
`engine/users/<id>` on disk. A sender's messages always hash to the same
worker (that's the existing ordering guarantee paying off again here), so
its cache stays warm there specifically -- until another sender sharing
that worker evicts it. Run with `--verbose` and fewer workers than active
senders so a worker actually sees more than `--cache` distinct senders,
e.g. `./engine 2 roster.txt --cache 1 --verbose` with the usual 4
participants (senders hash 1,3 -> worker 1 and 2,4 -> worker 0, so each
worker alternates between two senders against a 1-entry cache). Watch the
engine's own terminal: hits and misses are printed with their real cost in
CPU cycles. Measured live in this environment, hits ran ~3-9k cycles
(no syscall), misses ~90-360k cycles (a real `stat()`) -- a 30-100x gap,
comfortably larger than scheduler noise, unlike the order-book cache demo
above which needs machine-specific tuning to show cleanly.

## Wire protocol

Newline-delimited, space-separated, one connection = one participant (or,
for the dashboard, a silent subscriber). See `engine/protocol.hpp` for the
exact `GFD`/`FAK`/`CANCEL` / `ACK`/`FILL` / `SEQ ... ADD`/`CANCEL`/`TRADE`
formats -- deliberately plain text, no serialisation library, so it's easy
to read on a slide and to reimplement from scratch in Python.
