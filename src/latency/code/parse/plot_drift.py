import os, sys
import pandas as pd, matplotlib.pyplot as plt
import matplotlib.dates as mdates
from datetime import datetime, timedelta

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(ROOT, '..', '..', 'pcaps_parsed'))
ASSETS = os.path.abspath(os.path.join(ROOT, '..', '..', 'assets'))
TYPE = sys.argv[1] if len(sys.argv) > 1 else 'add_order'

df = pd.read_parquet(os.path.join(OUT, f'_drift_{TYPE}.parquet'))
base = datetime(2023, 8, 22)
df.index = [base + timedelta(seconds=s) for s in df.index]

fig, ax = plt.subplots(figsize=(9, 4.5))
ax.fill_between(df.index, df['p1'] / 1e3, df['p99'] / 1e3, color='#4472c4', alpha=0.2, label='1st-99th pctile')
ax.plot(df.index, df['median'] / 1e3, color='#4472c4', lw=1, label='median')
ax.set_yscale('log')
ax.set_ylabel('apparent latency, rx - match (µs, log scale)')
ax.set_xlabel('time of day (Eastern)')
ax.xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))
ax.legend(loc='upper right')
ax.set_title('Capture-to-match latency over the trading day')
fig.tight_layout()
fig.savefig(os.path.join(ASSETS, f'drift_{TYPE}.png'), dpi=150)
print('wrote', os.path.join(ASSETS, f'drift_{TYPE}.png'))
