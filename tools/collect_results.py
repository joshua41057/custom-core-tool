"""
python3 tools/collect_results.py <run-tag>
"""

from __future__ import annotations
import argparse, csv, datetime as dt, json, re, sys
from pathlib import Path
from typing import Any, Dict, List, Tuple
import glob, re

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


# timing report 
def _first_float(line: str) -> float | None:
    m = re.search(r"[-+]?\d+\.\d+", line)
    return float(m.group()) if m else None


CLK_TARGET_MHZ = 300.0
TARGET_T_NS = 1000.0 / CLK_TARGET_MHZ

WNS_ROW_RE = re.compile(r"Design Timing Summary.*?\n\s*([-+]?\d+\.\d+)", re.S | re.I)


def parse_timing() -> tuple[float | None, float | None]:
    txt = text(TIMING_RPT)
    if not txt:
        return None, None

    m = WNS_ROW_RE.search(txt)
    wns = float(m.group(1)) if m else None

    # Fmax = 1 / (목표 period - WNS)
    fmax = None
    if wns is not None:
        eff_period = TARGET_T_NS - wns           # ns
        if eff_period > 0:
            fmax = 1000.0 / eff_period          # MHz
    return wns, fmax


#  util report 
RE_ROW = r"\|\s*{tag}\s*\|[^|]*\|\s*[^|]*\|\s*[^|]*\|\s*([^|]+)\|\s*[^|]*\|\s*([^|]+)\|"

def _first_number(line: str) -> int | None:
    m = re.search(r"[-+]?\d[\d,]*", line)
    return int(m.group().replace(",", "")) if m else None

def parse_util(rpt: Path) -> dict[str, Any]:
    u = text(rpt)
    clb = _first_number(re.search(r"\|\s*CLB LUTs[^\n]*", u).group()) if "CLB LUTs" in u else None
    dsp = _first_number(re.search(r"\|\s*DSPs[^\n]*",     u).group()) if "DSPs"    in u else None
    slice_pct = grab(UTIL_RE.format(tag="CLB "), u)
    dsp_pct = grab(UTIL_RE.format(tag="DSPs"), u)
    return {
        "pblock_slice%": float(slice_pct) if slice_pct else None,
        "pblock_dsp%": float(dsp_pct) if dsp_pct else None,
        "slice_total": clb,
        "dsp_total": dsp,
    }


#  stage / u-op info
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


#  collect all data
def collect(tag: str) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    wns, fmax = parse_timing()
    stage_expr, muops = parse_len_pkg()
    sniper_rows : List[Dict[str, Any]] = []
    pcs_all     : list[str] = []
    lats_all    : list[str] = []

    CANDIDATE_JSON = [
        ROOT / "examples/selected_blocks_result_augmented.json",
        ROOT / "examples/alu_only_result_augmented.json",
    ]
    blk_groups: List[dict] = []
    for fp in CANDIDATE_JSON:
        if fp.is_file():
            blk_groups = json.loads(fp.read_text())
            break
    if not blk_groups:           
        blk_groups = [
            json.loads(p.read_text())
            for p in (ROOT / "examples/blocks").glob("blk*.json")
        ]

    for g in blk_groups:
        pc  = g.get("pc", "0x0")
        path_ns   = TARGET_T_NS - (wns or 0.0)
        lat_cycle = str(int((path_ns + TARGET_T_NS - 1e-3) // TARGET_T_NS)) 
        lat = lat_cycle
        
        sniper_rows.append({"pc": pc, "latency": lat})
        pcs_all.append(pc)
        lats_all.append(lat)

    rows: List[Dict[str, Any]] = []

    for util_rpt in sorted(RPT_DIR.glob("utilization_pblock_*.rpt")):
        pb_name  = util_rpt.stem.replace("utilization_", "")
        util     = parse_util(util_rpt)
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
                "pcs":       ",".join(pcs_all),
                "latencies": ",".join(lats_all),
            }
        )
        
    return rows, sniper_rows


def dump(rows: List[Dict[str, Any]], sniper_rows: List[Dict[str, Any]], tag: str) -> None:
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

    print(f"Done,  {base.name}.json / .csv written")
    print(f"Done,  all_runs.csv updated")

    if sniper_rows:
        sfile = RPT_DIR / f"sniper_{tag}.csv"
        with sfile.open("w", newline="") as f:
            w = csv.DictWriter(f, ["pc", "latency"])
            w.writeheader()
            w.writerows(sniper_rows)
        print(f"Done,  {sfile.name}  (for Sniper cfg)")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("run_tag")
    args = ap.parse_args()

    if not TIMING_RPT.exists():
        sys.exit("ERROR: post_route_timing.rpt missing")

    rows, sniper_rows = collect(args.run_tag)
    if not rows:
        sys.exit("ERROR: no utilization_pblock_*.rpt found")
    dump(rows, sniper_rows, args.run_tag)
