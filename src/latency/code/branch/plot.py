#!/usr/bin/env python3
import csv
import numpy as np
import matplotlib.pyplot as plt
from collections import defaultdict

tsc_ghz = float(open("tsc_ghz.txt").read())

rows = defaultdict(list)
with open("branch_latency.csv") as f:
	for row in csv.DictReader(f):
		if row["variant"] == "random": rows[float(row["x"])].append(float(row["cycles_per_iter"]) / tsc_ghz)

xs = sorted(rows)

fig, ax = plt.subplots(figsize=(9, 5.5))
ax.plot(xs, [np.median(rows[x]) for x in xs], color="#eb6834", linewidth=2)
ax.set_ylim(bottom=0)
ax.set_xlim(0, 100)
ax.set_xlabel("branch taken x% of the time")
ax.set_ylabel("time per loop iteration (ns)")
ax.set_title("cost of a data-dependent branch vs. how often it is taken")
ax.spines[["top", "right"]].set_visible(False)
ax.grid(True, color="#e5e5e0", linewidth=0.6, zorder=0)
ax.set_axisbelow(True)

fig.tight_layout()
fig.savefig("branch_latency.png", dpi=150)
