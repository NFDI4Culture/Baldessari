from pathlib import Path

import matplotlib.pyplot as plt

out = Path(__file__).parent
fig = plt.figure(figsize=(6, 9), dpi=200)
fig.patch.set_facecolor("#0047AB")
ax = fig.add_axes([0, 0, 1, 1])
ax.set_axis_off()
ax.set_xlim(0, 1)
ax.set_ylim(0, 1)
ax.text(
    0.5,
    0.60,
    "JOHN BALDESSARI",
    ha="center",
    va="center",
    color="white",
    fontsize=34,
    weight="bold",
)
ax.text(
    0.5,
    0.50,
    "A Linked Open Exhibition Guide",
    ha="center",
    va="center",
    color="white",
    fontsize=18,
)
ax.text(
    0.5,
    0.38,
    "A data-driven book sourced from OCR,",
    ha="center",
    va="center",
    color="#e8efff",
    fontsize=12,
)
ax.text(
    0.5,
    0.34,
    "CPS Wikibase, Wikidata, and the DNB",
    ha="center",
    va="center",
    color="#e8efff",
    fontsize=12,
)
ax.text(0.5, 0.09, "CPS", ha="center", color="#dbe6ff", fontsize=15)
fig.savefig(out / "cover.png", facecolor=fig.get_facecolor())
