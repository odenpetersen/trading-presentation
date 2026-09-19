import os
import numpy as np, pandas as pd, matplotlib.pyplot as plt

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(ROOT, '..', '..', 'pcaps_parsed'))
ASSETS = os.path.abspath(os.path.join(ROOT, '..', '..', 'assets'))

res = pd.read_parquet(os.path.join(OUT, '_racelatency.parquet'))
res['latency_ms'] = (res['latency_ns'] / 1e6).clip(lower=0.0001)

fig, ax = plt.subplots(figsize=(9, 4.5))
ax.plot(res['latency_ms'], res['avg_pnl_all'] * 100, color='#c0504d', marker='o', label='avg P&L (all signals)')
ax.axhline(0, color='gray', lw=0.8)
ax.set_xscale('log')
ax.set_xlabel('round-trip reaction latency (ms)')
ax.set_ylabel('avg P&L per signal (cents/share)')
ax.set_title('Level-sniping copy trade: expected edge vs round-trip latency')
fig.tight_layout()
fig.savefig(os.path.join(ASSETS, 'race_pnl.png'), dpi=150)

fig2, ax2 = plt.subplots(figsize=(9, 4.5))
ax2.plot(res['latency_ms'], res['catch_rate'] * 100, color='#4472c4', marker='o')
ax2.set_xscale('log')
ax2.set_xlabel('round-trip reaction latency (ms)')
ax2.set_ylabel('fills caught (%)')
ax2.set_title('Probability of catching the level before it disappears')
fig2.tight_layout()
fig2.savefig(os.path.join(ASSETS, 'race_catchrate.png'), dpi=150)

dist = pd.read_parquet(os.path.join(OUT, '_time_budget_dist.parquet'))
tb = np.sort(dist['time_budget_ns'].to_numpy()) / 1e3
surv = 1 - np.arange(1, len(tb) + 1) / len(tb)
fig3, ax3 = plt.subplots(figsize=(9, 4.5))
ax3.plot(tb, surv * 100, color='#4472c4')
ax3.set_xscale('log')
ax3.set_xlabel('time until level fully depleted (µs)')
ax3.set_ylabel('% of levels still alive')
ax3.set_title('How long a depleted order-book level survives after the triggering execution')
fig3.tight_layout()
fig3.savefig(os.path.join(ASSETS, 'level_survival.png'), dpi=150)

print('wrote race_pnl.png, race_catchrate.png, level_survival.png')
