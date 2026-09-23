#!/usr/bin/env python3
import csv
import numpy as np
import matplotlib.pyplot as plt
from collections import defaultdict

tsc_ghz = float(open("tsc_ghz.txt").read())

rows = defaultdict(list)
with open("container_latency.csv") as f:
	for row in csv.DictReader(f):
		rows[(row["container"], int(row["n"]))].append(int(row["cycles"]) / tsc_ghz)

series = {
	"vector": ("std::vector, linear scan — O(n)", "#2a78d6"),
	"unordered_set": ("std::unordered_set, hash table — O(1) avg", "#eb6834"),
	"set": ("std::set, red-black tree — O(log n)", "#1baf7a"),
	"list": ("std::list, linked-list scan — O(n)", "#eda100"),
}

fig, ax = plt.subplots(figsize=(9, 5.5))

for name, (label, color) in series.items():
	xs = sorted({n for (c, n) in rows if c == name})
	med = np.array([np.median(rows[(name, n)]) for n in xs])
	p25 = np.array([np.percentile(rows[(name, n)], 25) for n in xs])
	p75 = np.array([np.percentile(rows[(name, n)], 75) for n in xs])
	ax.fill_between(xs, p25, p75, color=color, alpha=0.15, linewidth=0)
	ax.plot(xs, med, color=color, linewidth=2)
	ax.annotate(label, xy=(xs[-1], med[-1]), xytext=(6, 0), textcoords="offset points",
		color=color, fontsize=10, va="center", fontweight="bold")

ax.set_xscale("log")
ax.set_yscale("log")
ax.set_xlabel("container size n")
ax.set_ylabel("time per contains() call, cold cache (ns)")
ax.set_title("membership-check latency vs. container size")
ax.spines[["top", "right"]].set_visible(False)
ax.grid(True, which="both", axis="both", color="#e5e5e0", linewidth=0.6, zorder=0)
ax.set_axisbelow(True)
ax.set_xlim(right=ax.get_xlim()[1] * 6)

fig.tight_layout()
fig.savefig("container_latency.png", dpi=150)
