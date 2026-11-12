#!/usr/bin/env python3
"""Render a clean static waveform chart for the OE teaching demo."""
from pathlib import Path
import matplotlib.pyplot as plt

OUT = Path(__file__).with_name("oe_demo_waveforms.png")

# Each item is (signal label, values at 0,10,20,...,70 ns).
# Z and X are intentionally shown as labeled discrete states.
rows = [
    ("OE",                 [0, 1, 1, 1, 1, 0, 0]),
    ("FPGA1 data_ready",   [1, 1, 1, 1, 1, 1, 1]),
    ("FPGA2 data_ready",   [1, 1, 1, 1, 1, 1, 1]),
    ("FPGA1 tx_enable",    [1, 1, 0, 1, 1, 1, 0]),
    ("FPGA2 tx_enable",    [1, 0, 1, 1, 1, 1, 0]),
    ("FPGA1 data",         [1, 1, 1, 1, 1, 1, 1]),
    ("FPGA2 data",         [0, 0, 0, 1, 0, 0, 0]),
    ("side A bus",         [1, 1, 0, 1, "X", 1, "Z"]),
    ("side B bus",         [0, 1, 0, 1, "X", 0, "Z"]),
    ("both driving",       [1, 0, 0, 1, 1, 1, 0]),
    ("opposite-drive flag",[0, 0, 0, 0, 1, 0, 0]),
]

# Values describe the stable interval starting at the listed edge.
# The seventh state (60-70 ns) is represented by the sample at 60 ns.
fig, ax = plt.subplots(figsize=(14, 8.2), dpi=160)
fig.patch.set_facecolor("#0b1020")
ax.set_facecolor("#111a2e")

n = len(rows)
low, high = 0.18, 0.78
for i, (label, vals) in enumerate(rows):
    y = n - 1 - i
    ax.text(-2.2, y + 0.48, label, ha="right", va="center", color="#e6edf7", fontsize=9.5)
    if label in ("side A bus", "side B bus"):
        for j, v in enumerate(vals):
            x0, x1 = j * 10, (j + 1) * 10
            if isinstance(v, int):
                yy = y + (high if v else low)
                ax.plot([x0, x1], [yy, yy], color="#4bd5c5", linewidth=2.0)
                if j < len(vals) - 1 and vals[j + 1] != v:
                    next_v = vals[j + 1]
                    if isinstance(next_v, int):
                        ax.plot([x1, x1], [yy, y + (high if next_v else low)], color="#4bd5c5", linewidth=1.5)
                ax.text((x0 + x1) / 2, yy + 0.08, str(v), ha="center", color="#8bf0e2", fontsize=8)
            else:
                ax.plot([x0 + 1, x1 - 1], [y + 0.48, y + 0.48], color="#ffb454" if v == "X" else "#a9b7cb", linewidth=2.0, linestyle="--")
                ax.text((x0 + x1) / 2, y + 0.50, v, ha="center", va="center", color="#ffca83" if v == "X" else "#cbd5e1", fontsize=10, weight="bold")
    else:
        for j, v in enumerate(vals):
            yy = y + (high if v else low)
            x0, x1 = j * 10, (j + 1) * 10
            ax.plot([x0, x1], [yy, yy], color="#68a7ff" if label != "OE" else "#f472b6", linewidth=1.9)
            if j < len(vals) - 1 and vals[j + 1] != v:
                next_y = y + (high if vals[j + 1] else low)
                ax.plot([x1, x1], [yy, next_y], color="#68a7ff" if label != "OE" else "#f472b6", linewidth=1.5)
            ax.text((x0 + x1) / 2, yy + 0.08, str(v), ha="center", color="#b8d5ff" if label != "OE" else "#ffaad3", fontsize=8)

# Timing divisions and phase captions.
for x in range(0, 71, 10):
    ax.axvline(x, color="#42506a", linewidth=0.7, alpha=0.65)
ax.set_xlim(-23, 70)
ax.set_ylim(-0.2, n + 0.1)
ax.set_xticks(range(0, 71, 10), [f"{x} ns" for x in range(0, 71, 10)], color="#cbd5e1")
ax.set_yticks([])
ax.tick_params(axis="x", colors="#cbd5e1", labelsize=9)
for spine in ax.spines.values():
    spine.set_color("#55627a")
ax.set_title("TXS0101: OE abre el paso, no arbitra transmisores", color="white", fontsize=15, pad=16, weight="bold")
ax.set_xlabel("Tiempo de simulación (fase final comienza en 60 ns)", color="#cbd5e1", labelpad=10)

phase_text = [
    (5, "OE=0\naislados"),
    (15, "solo FPGA1\ntransmite"),
    (25, "solo FPGA2\ntransmite"),
    (35, "ambos=1\nno aparece X"),
    (45, "ambos opuestos\nconflicto X"),
    (55, "OE=0\nseparados"),
    (65, "ambos en Z"),
]
for x, text in phase_text:
    ax.text(x, -0.03, text, ha="center", va="top", color="#d6deeb", fontsize=7.4, clip_on=False)

fig.text(0.5, 0.012,
         "Modelo lógico idealizado. En Game Boy, SO y SI son líneas separadas: pueden transmitir simultáneamente sin compartir el mismo conductor.",
         ha="center", color="#a9b7cb", fontsize=8.3)
plt.subplots_adjust(left=0.22, right=0.985, top=0.91, bottom=0.18)
fig.savefig(OUT, facecolor=fig.get_facecolor(), bbox_inches="tight")
print(OUT)
