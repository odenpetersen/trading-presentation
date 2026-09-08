#!/usr/bin/env python3
"""Convenience launcher: spawns the dashboard + every participant in
participants.py. For the live talk you'll likely want to run each of these
in its own terminal pane instead (see README) so the audience can see them
start one at a time -- this script is for quick local iteration.
"""
import subprocess
import time

from participants import PARTICIPANTS

KIND_SCRIPT = {"dumb_trader": "dumb_trader.py", "market_maker": "market_maker.py", "taker": "taker.py"}


def to_cli(args):
    out = []
    for k, v in args.items():
        if isinstance(v, bool):
            if v:
                out.append(f"--{k}")
        else:
            out += [f"--{k}", str(v)]
    return out


procs = [subprocess.Popen(["python3", "dashboard.py"])]
time.sleep(0.5)
for p in PARTICIPANTS:
    cmd = ["python3", KIND_SCRIPT[p["kind"]], "--id", str(p["id"])] + to_cli(p["args"])
    procs.append(subprocess.Popen(cmd))

try:
    for proc in procs:
        proc.wait()
except KeyboardInterrupt:
    for proc in procs:
        proc.terminate()
