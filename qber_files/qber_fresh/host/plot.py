#!/usr/bin/env python3
"""plot.py - Graph 1, Graph 2 and the reliability table from the ZedBoard's CSV."""
import argparse
import csv
import glob
import math
import os
import sys

COLS = ("mode,preset,p_noise,f_eve,rate_div,block_size,run_s,photons_in,photons_proc,cycles,"
        "pl_dropped,sifted,sifted_errs,blocks_done,sum_n_sprt,sum_n_fix,abort_sprt,abort_fix,"
        "trunc_sprt,key_sprt,key_fix,disclosed,key_out,lat_max,stream_words_sent,"
        "stream_words_dropped,arm_photons,arm_blocks,arm_sum_n_sprt,arm_abort_sprt,arm_match").split(",")
MODES = {"single", "g1", "rel", "rate", "long"}

P0, P1, ALPHA, BETA, FIX_N = 0.03, 0.11, 0.01, 0.01, 202

C_SPRT, C_FIX, C_CURT = "#2a78d6", "#eb6834", "#1baf7a"
C_REF, C_INK, C_MUTED, C_GRID = "#6b6a63", "#22221f", "#5f5e58", "#e6e5e0"

def read_rows(paths):
    rows, seen = [], set()
    for pattern in paths:
        for path in sorted(glob.glob(pattern)) or [pattern]:
            with open(path, newline="", errors="replace") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    parts = line.split(",")
                    if parts[0] not in MODES or len(parts) != len(COLS) or line in seen:
                        continue
                    seen.add(line)
                    r = dict(zip(COLS, parts))
                    if "curtail" in r["preset"]:
                        continue
                    for k in COLS[2:]:
                        r[k] = float(r[k])
                    rows.append(r)
    return rows

def wald_asn(p, p0=P0, p1=P1, a=ALPHA, b=BETA):
    A, B = math.log((1 - b) / a), math.log(b / (1 - a))
    ze, zo = math.log(p1 / p0), math.log((1 - p1) / (1 - p0))
    mu = p * ze + (1 - p) * zo
    if p <= 0.0:
        return B / zo
    if abs(mu) < 1e-9:
        return -A * B / (p * ze * ze + (1 - p) * zo * zo)

    f = lambda h: p * math.exp(h * ze) + (1 - p) * math.exp(h * zo) - 1.0
    lo, hi = (1e-6, 60.0) if mu < 0 else (-60.0, -1e-6)
    for _ in range(200):
        mid = 0.5 * (lo + hi)
        if (f(mid) > 0) == (f(hi) > 0):
            hi = mid
        else:
            lo = mid
    h = 0.5 * (lo + hi)
    eA, eB = math.exp(h * A), math.exp(h * B)
    L = (eA - 1) / (eA - eB)
    return (L * B + (1 - L) * A) / mu

def style(ax, xlabel, ylabel):
    ax.set_xlabel(xlabel, color=C_INK)
    ax.set_ylabel(ylabel, color=C_INK)
    ax.grid(True, color=C_GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_color(C_MUTED)
    ax.tick_params(colors=C_MUTED)

def label_end(ax, x, y, text, dy=0):
    ax.annotate(text, (x, y), xytext=(6, dy), textcoords="offset points",
                va="center", fontsize=9, color=C_INK)

def graph1(rows, out):
    import matplotlib.pyplot as plt
    pts = {}
    for r in rows:
        if r["mode"] != "g1" or r["blocks_done"] == 0 or r["sifted"] == 0:
            continue
        key = (r["preset"], r["p_noise"])
        acc = pts.setdefault(key, dict(blocks=0, sprt=0, fix=0, err=0, sif=0))
        acc["blocks"] += r["blocks_done"]; acc["sprt"] += r["sum_n_sprt"]; acc["fix"] += r["sum_n_fix"]
        acc["err"] += r["sifted_errs"]; acc["sif"] += r["sifted"]
    if not pts:
        print("graph1: no g1 rows"); return
    series = {}
    for (preset, _), a in pts.items():
        q = 100.0 * a["err"] / a["sif"]
        series.setdefault(preset, []).append((q, a["sprt"] / a["blocks"], a["fix"] / a["blocks"], a["blocks"]))
    for v in series.values():
        v.sort()

    plain = series.get("bb84") or next(v for k, v in series.items() if "curtail" not in k)
    with open(os.path.join(out, "graph1.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["true_qber_pct", "sprt_bits", "fixed_bits", "blocks", "wald_theory_bits"])
        for q, sb, fb, nb in plain:
            w.writerow([f"{q:.3f}", f"{sb:.2f}", f"{fb:.2f}", int(nb), f"{wald_asn(q / 100):.2f}"])

    fig, ax = plt.subplots(figsize=(6.4, 4.0), dpi=150)
    style(ax, "True QBER (%)", "Bits revealed per decision")
    qs = [x[0] for x in plain]
    qmax = max(qs) if qs else 25
    tq = [0.05 + i * (qmax - 0.05) / 300 for i in range(301)]
    ax.plot(tq, [wald_asn(q / 100) for q in tq], color=C_REF, linestyle=":", linewidth=1.6,
            label="SPRT, Wald's prediction", zorder=2)
    ax.plot(qs, [x[2] for x in plain], color=C_FIX, linestyle="--", linewidth=2, marker="s",
            markersize=5, label=f"Fixed sample ({FIX_N} bits)", zorder=3)
    ax.plot(qs, [x[1] for x in plain], color=C_SPRT, linewidth=2, marker="o", markersize=5,
            label="SPRT (measured on the FPGA)", zorder=4)
    ax.set_xlim(0, qmax * 1.18)
    ax.set_ylim(0, max(FIX_N, max(x[1] for x in plain)) * 1.12)
    label_end(ax, qs[-1], plain[-1][2], "Fixed")
    label_end(ax, qs[-1], plain[-1][1], "SPRT", dy=-6)
    ax.legend(frameon=False, fontsize=8.5, loc="center right", bbox_to_anchor=(1.0, 0.60))
    nb = int(min(x[3] for x in plain))
    ax.set_title(f"Bits revealed vs error rate ({nb:,} blocks per point)", fontsize=10.5, color=C_INK, loc="left")
    fig.tight_layout()
    for ext in ("pdf", "png"):
        fig.savefig(os.path.join(out, f"graph1.{ext}"), dpi=300)
    plt.close(fig)
    print("Graph 1 (bits revealed per decision)")
    print("  QBER %   SPRT    fixed   saved")
    for q, sb, fb, _ in plain:
        print(f"  {q:6.2f} {sb:7.1f} {fb:7.1f}  {100 * (1 - sb / fb):5.1f} %")

def graph2(rows, out):
    import matplotlib.pyplot as plt
    est = sorted((r for r in rows if r["mode"] == "rate" and r["preset"] == "bb84" and r["run_s"] > 0),
                 key=lambda r: r["photons_in"] / r["run_s"])
    ro = sorted((r for r in rows if r["mode"] == "rate" and r["preset"].endswith("readonly") and r["run_s"] > 0),
                key=lambda r: r["photons_in"] / r["run_s"])
    if not est:
        print("graph2: no rate rows"); return
    mps = lambda n, r: n / r["run_s"] / 1e6
    x = [mps(r["photons_in"], r) for r in est]
    fpga = [mps(r["photons_proc"], r) for r in est]
    arm = [mps(r["arm_photons"], r) for r in est]
    xr = [mps(r["photons_in"], r) for r in ro]
    armr = [mps(r["arm_photons"], r) for r in ro]
    with open(os.path.join(out, "graph2.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["rate_div", "input_mph_s", "fpga_mph_s", "pl_dropped", "arm_estimate_mph_s",
                    "arm_stream_drop_pct", "arm_matches_fpga"])
        for r, xi, fi, ai in zip(est, x, fpga, arm):
            tot = r["stream_words_sent"] + r["stream_words_dropped"]
            w.writerow([int(r["rate_div"]), f"{xi:.3f}", f"{fi:.3f}", int(r["pl_dropped"]), f"{ai:.3f}",
                        f"{100 * r['stream_words_dropped'] / tot if tot else 0:.2f}", int(r["arm_match"])])

    fig, ax = plt.subplots(figsize=(6.4, 4.0), dpi=150)
    style(ax, "Input rate (M photons/s)", "Processed rate (M photons/s)")
    top = max(x) * 1.05
    ax.plot([0, max(x)], [0, max(x)], color=C_REF, linestyle=":", linewidth=1.4, label="Ideal (nothing dropped)", zorder=2)
    if ro:
        ax.plot(xr, armr, color=C_CURT, linestyle="-.", linewidth=2, marker="^", markersize=6,
                label="ARM, reading the FIFO only", zorder=3)
    ax.plot(x, arm, color=C_FIX, linestyle="--", linewidth=2, marker="s", markersize=5,
            label="ARM, reading + estimating (C, -O2)", zorder=3)
    ax.plot(x, fpga, color=C_SPRT, linewidth=2, marker="o", markersize=5,
            label="FPGA estimator", zorder=4)
    ax.set_xlim(0, top * 1.12)
    ax.set_ylim(0, top * 1.08)
    label_end(ax, x[-1], fpga[-1], f"FPGA {fpga[-1]:.0f}")
    close = ro and abs(armr[-1] - arm[-1]) < 0.06 * top
    label_end(ax, x[-1], arm[-1], f"ARM {arm[-1]:.1f}", dy=-7 if close else 0)
    if ro:
        label_end(ax, xr[-1], armr[-1], f"ARM read only {armr[-1]:.1f}", dy=7 if close else 0)
    ax.legend(frameon=False, fontsize=8.5, loc="upper left")
    ax.set_title("Processed rate vs input rate, measured live (QBER 3 %)", fontsize=10.5, color=C_INK, loc="left")
    fig.tight_layout()
    for ext in ("pdf", "png"):
        fig.savefig(os.path.join(out, f"graph2.{ext}"), dpi=300)
    plt.close(fig)
    print("Graph 2 (M photons/s)")
    print("  input   FPGA  PL drops   ARM(est)  stream drop  ARM=FPGA")
    for r, xi, fi, ai in zip(est, x, fpga, arm):
        tot = r["stream_words_sent"] + r["stream_words_dropped"]
        print(f"  {xi:6.2f} {fi:6.2f} {int(r['pl_dropped']):8d}   {ai:7.2f}   {100 * r['stream_words_dropped'] / tot if tot else 0:6.1f} %"
              f"   {'yes' if r['arm_match'] == 1 else ('no' if r['arm_match'] == 0 else 'n/a (drops)')}")
    print(f"  FPGA / ARM at the highest input rate: {fpga[-1] / arm[-1]:.1f}x")

def reliability(rows, out):
    rel = [r for r in rows if r["mode"] == "rel" and r["blocks_done"] > 0]
    if not rel:
        print("reliability: no rel rows"); return
    lines = []
    for r in sorted(rel, key=lambda r: r["sifted_errs"] / r["sifted"]):
        q = r["sifted_errs"] / r["sifted"]
        n = r["blocks_done"]
        good = q < (P0 + P1) / 2
        def rate(aborts):
            k = aborts if good else n - aborts
            p = k / n
            return 100 * p, 100 * 1.96 * math.sqrt(max(p * (1 - p), 1e-12) / n)
        s, sci = rate(r["abort_sprt"])
        fx, fci = rate(r["abort_fix"])
        lines.append(dict(qber=100 * q, blocks=int(n), kind="wrong abort" if good else "wrong accept",
                          sprt=s, sprt_ci=sci, fixed=fx, fixed_ci=fci, target=100 * (ALPHA if good else BETA),
                          sprt_bits=r["sum_n_sprt"] / n, fixed_bits=r["sum_n_fix"] / n))
    with open(os.path.join(out, "reliability.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(lines[0].keys()))
        w.writeheader()
        for L in lines:
            w.writerow({k: (f"{v:.4f}" if isinstance(v, float) else v) for k, v in L.items()})
    with open(os.path.join(out, "reliability.tex"), "w") as f:
        f.write("\\begin{tabular}{rlrrrrr}\n\\hline\n")
        f.write("QBER (\\%) & Error type & Target (\\%) & SPRT (\\%) & Fixed (\\%) & SPRT bits & Fixed bits \\\\\n\\hline\n")
        for L in lines:
            f.write(f"{L['qber']:.2f} & {L['kind']} & {L['target']:.1f} & {L['sprt']:.2f} $\\pm$ {L['sprt_ci']:.2f} & "
                    f"{L['fixed']:.2f} $\\pm$ {L['fixed_ci']:.2f} & {L['sprt_bits']:.1f} & {L['fixed_bits']:.1f} \\\\\n")
        f.write("\\hline\n\\end{tabular}\n")
    print("Reliability (95 % intervals)")
    for L in lines:
        print(f"  QBER {L['qber']:5.2f} %  {L['kind']:12s} target {L['target']:.1f} %:  "
              f"SPRT {L['sprt']:.2f} +- {L['sprt_ci']:.2f} %   fixed {L['fixed']:.2f} +- {L['fixed_ci']:.2f} %   "
              f"(bits {L['sprt_bits']:.1f} vs {L['fixed_bits']:.1f}, {L['blocks']:,} blocks)")

def eve_sweep(rows, out):
    import matplotlib.pyplot as plt
    groups = {}
    for r in rows:
        if r["mode"] == "single" and r["blocks_done"] >= 1000 and r["sifted"] > 0:
            groups.setdefault(r["p_noise"], {})[r["f_eve"]] = r
    groups = {k: v for k, v in groups.items() if len(v) >= 3}
    if not groups:
        print("eve sweep: no demo runs with 3 or more Eve settings"); return
    p_noise, runs = max(groups.items(), key=lambda kv: len(kv[1]))
    pts = []
    for f in sorted(runs):
        r = runs[f]
        n = r["blocks_done"]
        e, p = 0.25 * f / 65536, p_noise / 65536
        pts.append(dict(eve=100 * f / 65536, qber=100 * r["sifted_errs"] / r["sifted"],
                        theory=100 * (e + p - 2 * e * p), blocks=int(n),
                        abort_sprt=100 * r["abort_sprt"] / n, abort_fix=100 * r["abort_fix"] / n,
                        sprt_bits=r["sum_n_sprt"] / n, fixed_bits=r["sum_n_fix"] / n))
    with open(os.path.join(out, "eve_sweep.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(pts[0].keys()))
        w.writeheader()
        for q in pts:
            w.writerow({k: (f"{v:.3f}" if isinstance(v, float) else v) for k, v in q.items()})
    fig, (a1, a2, a3) = plt.subplots(1, 3, figsize=(13.5, 3.8), dpi=150)
    style(a1, "Eve intercepts (% of photons)", "QBER (%)")
    style(a2, "Eve intercepts (% of photons)", "Blocks aborted (%)")
    style(a3, "Eve intercepts (% of photons)", "Bits revealed per decision")
    xe = [i for i in range(0, 101)]
    pn = p_noise / 65536
    a1.plot(xe, [100 * (0.25 * x / 100 + pn - 2 * 0.25 * x / 100 * pn) for x in xe], color=C_REF, linestyle=":",
            linewidth=1.6, label="Theory: p + f/4 - pf/2", zorder=2)
    for y, t in ((100 * P0, "safe limit p0 = 3 %"), (100 * P1, "abort limit p1 = 11 %")):
        a1.axhline(y, color=C_GRID, linewidth=1.2, zorder=1)
        a1.annotate(t, (100, y), xytext=(-2, 3), textcoords="offset points", ha="right", fontsize=8, color=C_MUTED)
    a1.plot([q["eve"] for q in pts], [q["qber"] for q in pts], color=C_SPRT, linewidth=0, marker="o",
            markersize=6, label="Measured on the FPGA", zorder=4)
    a1.set_xlim(0, 105); a1.set_ylim(0, max(30, max(q["qber"] for q in pts) * 1.1))
    a1.legend(frameon=False, fontsize=8.5, loc="upper left")
    a1.set_title(f"Error rate vs eavesdropping (noise {100 * pn:.0f} %)", fontsize=10.5, color=C_INK, loc="left")
    a2.plot([q["eve"] for q in pts], [q["abort_fix"] for q in pts], color=C_FIX, linestyle="--", linewidth=2,
            marker="s", markersize=5, label="Fixed sample (202 bits)", zorder=3)
    a2.plot([q["eve"] for q in pts], [q["abort_sprt"] for q in pts], color=C_SPRT, linewidth=2, marker="o",
            markersize=5, label="SPRT", zorder=4)
    a2.set_xlim(0, 105); a2.set_ylim(0, 108)
    a2.legend(frameon=False, fontsize=8.5, loc="center right")
    a2.set_title("Eve detected: blocks aborted", fontsize=10.5, color=C_INK, loc="left")
    a3.plot([q["eve"] for q in pts], [q["fixed_bits"] for q in pts], color=C_FIX, linestyle="--", linewidth=2,
            marker="s", markersize=5, label="Fixed sample", zorder=3)
    a3.plot([q["eve"] for q in pts], [q["sprt_bits"] for q in pts], color=C_SPRT, linewidth=2, marker="o",
            markersize=5, label="SPRT", zorder=4)
    a3.set_xlim(0, 105); a3.set_ylim(0, 230)
    a3.legend(frameon=False, fontsize=8.5, loc="lower left")
    a3.set_title("Bits revealed to decide", fontsize=10.5, color=C_INK, loc="left")
    fig.tight_layout()
    for ext in ("pdf", "png"):
        fig.savefig(os.path.join(out, f"graph3_eve.{ext}"), dpi=300)
    plt.close(fig)
    print(f"Eve sweep (noise {100 * pn:.1f} %, {pts[0]['blocks']:,} blocks per point)")
    print("  Eve %  QBER %  theory   SPRT abort  fixed abort   SPRT bits  fixed bits")
    for q in pts:
        print(f"  {q['eve']:5.0f} {q['qber']:7.2f} {q['theory']:7.2f}   {q['abort_sprt']:8.2f} %  {q['abort_fix']:8.2f} %"
              f"   {q['sprt_bits']:8.1f}  {q['fixed_bits']:8.1f}")

def sustained(rows):
    for r in rows:
        if r["mode"] == "long":
            ok = r["photons_proc"] == r["photons_in"] and r["pl_dropped"] == 0
            print(f"Sustained rate: {r['run_s']:.1f} s at {r['photons_in'] / r['run_s'] / 1e6:.2f} M photons/s, "
                  f"{r['photons_in'] / 1e9:.3f} G photons in, {r['photons_proc'] / 1e9:.3f} G processed, "
                  f"{int(r['pl_dropped'])} dropped: {'PASS' if ok else 'FAIL'}")

def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("logs", nargs="+", help="CSV/log files from the board (globs allowed)")
    ap.add_argument("--out", default=os.path.join("results", "figures"))
    a = ap.parse_args()
    rows = read_rows(a.logs)
    if not rows:
        sys.exit("no data lines found")
    os.makedirs(a.out, exist_ok=True)
    import matplotlib
    matplotlib.use("Agg")
    matplotlib.rcParams.update({"font.family": "serif", "font.size": 10, "axes.titleweight": "regular"})
    print(f"{len(rows)} runs read")
    graph1(rows, a.out)
    graph2(rows, a.out)
    reliability(rows, a.out)
    eve_sweep(rows, a.out)
    sustained(rows)
    print(f"figures and tables in {a.out}")

if __name__ == "__main__":
    main()
