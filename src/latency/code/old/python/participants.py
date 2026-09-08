"""Single source of truth for who's trading. One participant per role asked
for in the demo -- kept deliberately minimal. Ids must match
engine/roster.txt. Edit this file (and restart) to reconfigure a segment.
"""

PARTICIPANTS = [
    {
        "id": 1,
        "kind": "dumb_trader",
        "label": "DumbTrader",
        "args": {"qty": 50, "price_range": 8000},
    },
    {
        "id": 2,
        "kind": "market_maker",
        "label": "MM-top (w=0.02)",
        "args": {"width": 0.02, "levels_from_touch": 0, "cancel_before_requote": True, "signal_noise": 0.3},
    },
    {
        "id": 3,
        "kind": "market_maker",
        "label": "MM-behind (w=0.10, sloppy)",
        "args": {
            "width": 0.10,
            "levels_from_touch": 1,
            "cancel_before_requote": False,
            "signal_noise": 0.4,
            "interval": 1.2,  # slow requoting: lets its own stale quotes drift into a self-cross
        },
    },
    {
        "id": 4,
        "kind": "taker",
        "label": "Taker",
        "args": {"signal_noise": 0.1, "threshold": 0.1},
    },
]
