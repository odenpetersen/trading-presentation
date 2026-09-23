import os, re
import matplotlib.pyplot as plt
import numpy as np

ROOT = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.abspath(os.path.join(ROOT, '..', '..', 'assets'))

SERIES = [
    ('kernel', 'kernel stack', 'rtt_a_kernel.txt', '#2a78d6'),
    ('dpdk', 'AF_XDP kernel bypass', 'rtt_b_xdp.txt', '#eb6834'),
    ('fpga', 'FPGA', 'rtt_c_fpga.txt', '#1baf7a'),
]
DATA_DIR = os.environ.get('PING_RTT_DIR', ROOT)

def load(path):
    vals = []
    with open(path) as f:
        for line in f:
            m = re.search(r'rtt=([\d.]+)us', line)
            if m: vals.append(float(m.group(1)))
    return np.sort(vals)

fig, ax = plt.subplots(figsize=(7, 4.5))
for key, label, fname, color in SERIES:
    path = os.path.join(DATA_DIR, fname)
    if not os.path.exists(path): continue
    vals = load(path)
    if len(vals) == 0: continue
    frac = np.arange(1, len(vals) + 1) / len(vals)
    ax.plot(vals, frac, color=color, lw=2, label=f'{label} (n={len(vals)})')

ax.set_xscale('log')
ax.set_xlabel('round-trip latency (µs, log scale)')
ax.set_ylabel('cumulative fraction')
ax.set_ylim(0, 1)
ax.legend(loc='lower right')
ax.set_title('Ping round-trip latency: kernel stack vs DPDK vs FPGA')
fig.tight_layout()
out_path = os.path.join(ASSETS, 'ping_latency_cdf.png')
fig.savefig(out_path, dpi=150)
print('wrote', out_path)
