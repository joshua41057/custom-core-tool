"""
python3 tools/collect_results.py <run-tag>
"""

from __future__ import annotations
import argparse, csv, datetime as dt, json, re, sys
from pathlib import Path
from typing import Any, Dict, List

ROOT = Path(__file__).resolve().parents[1]
RPT_DIR = ROOT / "reports"
LEN_PKG = ROOT / "rtl" / "len_table_pkg.sv"
TIMING_RPT = RPT_DIR / "post_route_timing.rpt"

TIMING_RPT_RE = re.compile(r"Worst Negative Slack *: *([\-0-9.]+) ns")
FMAX_RE = re.compile(r"Maximum Frequency *: *([0-9.]+) *MHz")
PERIOD_RE = re.compile(r"Minimum period *: *([0-9.]+) ns")

CLB_RE = re.compile(r"\| CLB LUTs.*?\|\s*([\d.]+)\s*\|\s*([\d.]+)\s*\|")
DSP_RE = re.compile(r"\| DSPs\s*\|\s*([\d.]+)\s*\|\s*([\d.]+)\s*\|")
TIMING_RE = re.compile(
    r"Design Timing Summary[^\n]*\n(?:.*\n){4}.*?^\s*([-0-9.]+)\s+", re.M
)
UTIL_RE = r"\|\s*{tag}\s*\|[^\n]+\|\s*([0-9.]+)\s*\|"


def text(p: Path) -> str:
    return p.read_text(errors="ignore") if p.is_file() else ""


def grab(regex: str, src: str, idx: int = 1, cast=float, default=None):
    m = re.search(regex, src, flags=re.M)
    return cast(m.group(idx)) if m else default


# ─────────────────────────── timing report ────────────────────────────────
def _first_float(line: str) -> float | None:
    m = re.search(r"[-+]?\d+\.\d+", line)
    return float(m.group()) if m else None


def parse_timing() -> tuple[float | None, float | None]:
    txt = text(TIMING_RPT)
    if not txt:
        return None, None

    wns = None
    fmax = None
    period = None

    grab_wns = False
    for ln in txt.splitlines():
        if "Design Timing Summary" in ln:
            grab_wns = True
            continue
        if grab_wns:
            cand = _first_float(ln.strip())
            if cand is not None:
                wns = cand
                grab_wns = False
        if ln.startswith("host_clk"):
            cols = ln.split()
            if cols[-1].replace(".", "").isdigit():
                fmax = float(cols[-1])
            if cols[-2].replace(".", "").isdigit():
                period = float(cols[-2])

    if fmax is None and period:
        fmax = 1000.0 / period  # MHz

    return wns, fmax


# ─────────────────────────── util report ──────────────────────────────────
RE_ROW = r"\|\s*{tag}\s*\|[^|]*\|\s*[^|]*\|\s*[^|]*\|\s*([^|]+)\|\s*[^|]*\|\s*([^|]+)\|"


def parse_util(rpt: Path) -> dict[str, Any]:
    u = text(rpt)
    clb = grab(RE_ROW.format(tag="CLB "), u, 2)
    dsp = grab(RE_ROW.format(tag="DSPs"), u, 2)
    slice_pct = grab(UTIL_RE.format(tag="CLB "), u)
    dsp_pct = grab(UTIL_RE.format(tag="DSPs"), u)
    return {
        "pblock_slice%": float(slice_pct) if slice_pct else None,
        "pblock_dsp%": float(dsp_pct) if dsp_pct else None,
        "slice_total": int(clb) if clb else None,
        "dsp_total": int(dsp) if dsp else None,
    }


# ─────────────────────────── stage / μ-op info ────────────────────────────
def parse_len_pkg() -> tuple[str, str]:
    src = text(LEN_PKG)

    stages = re.findall(r"STAGE_LUT\s*\[N_CASE\].+?\{\s*([^}]+)\}", src, re.S)
    if stages:
        nums = [int(x) for x in stages[0].replace("\n", " ").split(",") if x.strip()]
        stage_expr = "+".join(str(n) for n in nums)
    else:
        stage_expr = "?"

    ops_rows = re.findall(
        r"\{\s*([^}]+)\}", re.search(r"OPS_LUT.+?=\s*'\{(.+?)\};", src, re.S).group(1)
    )
    muops = ", ".join(
        "-".join(
            tok.strip().replace("OP_", "")
            for tok in row.split(",")
            if tok.strip() != "OP_NOP"
        )
        for row in ops_rows
    )
    return stage_expr, muops


# ─────────────────────────── collect all data ─────────────────────────────
def collect(tag: str) -> List[Dict[str, Any]]:
    wns, fmax = parse_timing()
    stage_expr, muops = parse_len_pkg()

    rows: List[Dict[str, Any]] = []
    for util_rpt in sorted(RPT_DIR.glob("utilization_pblock_*.rpt")):
        pb_name = util_rpt.stem.replace("utilization_", "")
        util = parse_util(util_rpt)
        rows.append(
            {
                "run_tag": tag,
                "timestamp_utc": dt.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
                "pblock": pb_name,
                **util,
                "fmax_mhz": round(fmax, 3) if fmax else None,
                "wns_ns": round(wns, 3) if wns else None,
                "stage_count": stage_expr,
                "muops": muops,
            }
        )
    return rows


def dump(rows: List[Dict[str, Any]], tag: str) -> None:
    base = RPT_DIR / f"impl_summary_{tag}"
    base.with_suffix(".json").write_text(json.dumps(rows, indent=2))
    with base.with_suffix(".csv").open("w", newline="") as f:
        w = csv.DictWriter(f, rows[0].keys())
        w.writeheader()
        w.writerows(rows)

    master = RPT_DIR / "all_runs.csv"
    new_hdr = not master.exists()
    with master.open("a", newline="") as f:
        w = csv.DictWriter(f, rows[0].keys())
        if new_hdr:
            w.writeheader()
        w.writerows(rows)

    print(f"✔  {base.name}.json / .csv written")
    print(f"✔  all_runs.csv updated")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("run_tag")
    args = ap.parse_args()

    if not TIMING_RPT.exists():
        sys.exit("ERROR: post_route_timing.rpt missing")

    rows = collect(args.run_tag)
    if not rows:
        sys.exit("ERROR: no utilization_pblock_*.rpt found")
    dump(rows, args.run_tag)
