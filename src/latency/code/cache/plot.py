#!/usr/bin/env python3
import csv
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap

darkred_orange = LinearSegmentedColormap.from_list("darkred_orange", ["#8B0000", "#FFA500"])

rows = []
with open("cache_latency.csv") as f:
	for row in csv.DictReader(f):
		rows.append((int(row["reuse_distance"]), float(row["nanoseconds"])))

reuse = np.array([r[0] for r in rows])
ns = np.array([r[1] for r in rows])
order = np.argsort(ns)
ns, reuse = ns[order], reuse[order]
pct = 100 * np.arange(1, len(ns) + 1) / len(ns)
reuse_rank = 100 * reuse.argsort().argsort() / (len(reuse) - 1)

fig, ax = plt.subplots(figsize=(8, 5))
sc = ax.scatter(ns, pct, c=reuse_rank, cmap=darkred_orange, vmin=0, vmax=100, s=4, alpha=0.5, linewidths=0)

ax.set_xlim(ns.min(), np.percentile(ns, 99.9))
ax.set_xlabel("nanoseconds")
ax.set_ylabel("cumulative %")
ax.set_title("access latency CDF, coloured by reuse distance")
ax.spines[["top", "right"]].set_visible(False)

forward = lambda y: -np.log10(np.clip(100 - y, 1e-9, None))
inverse = lambda y: 100 - 10.0 ** (-y)
ax.set_yscale("function", functions=(forward, inverse))
yticks = [0, 50, 90, 99, 99.9, 99.99]
ax.set_yticks(yticks)
ax.set_yticklabels([str(t) for t in yticks])
ax.set_ylim(0, 99.99)

cb = fig.colorbar(sc, ax=ax)
cb.set_label("reuse distance percentile rank")

fig.tight_layout()
fig.savefig("cdf.png", dpi=150)
