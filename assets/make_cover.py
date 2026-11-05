from pathlib import Path

import matplotlib.pyplot as plt

out = Path(__file__).parent
fig = plt.figure(figsize=(6, 9), dpi=200)
fig.patch.set_facecolor("#1f3a68")
ax = fig.add_axes([0, 0, 1, 1])
ax.set_axis_off()
ax.set_xlim(0, 1)
ax.set_ylim(0, 1)
for x, y, c in [(0.28, 0.62, "#e04545"), (0.5, 0.55, "#f5a623"), (0.72, 0.62, "#2e8b57")]:
    ax.add_patch(plt.Circle((x, y), 0.11, color=c, lw=0))
ax.text(0.5, 0.34, "John Baldessari", ha="center", color="white", fontsize=30, weight="bold")
ax.text(0.5, 0.28, "in Linked Open Data", ha="center", color="white", fontsize=18)
ax.text(0.5, 0.08, "NFDI4Culture", ha="center", color="#cfd8ea", fontsize=12)
fig.savefig(out / "cover.png", facecolor=fig.get_facecolor())
