from __future__ import annotations
import argparse, csv, datetime as dt, json, re, sys
from pathlib import Path
from typing import Any, Dict, List, Tuple

# -------------------------------------------------------------------------------------------------
# collect_results.py
# -------------------------------------------------------------------------------------------------
# Parses Vivado post‑route timing, utilization **and power** reports, summarizing key metrics into
# JSON/CSV files and (optionally) Sniper/Block CSVs for simulation.
#
# **2025‑07‑11 updates**
#   • Added parsing of post_route_power.rpt – extracts:
#       ├─ total_on_chip_power_w   (float) – "Total On‑Chip Power (W)" (e.g. 5.732)
#       ├─ dynamic_power_w         (float) – "Dynamic (W)"             (e.g. 3.219)
#       └─ device_static_power_w   (float) – "Device Static (W)"       (e.g. 2.513)
#   • Previously (same date) replaced slice/DSP % fields with explicit CLB/DSP usage & totals.
# -------------------------------------------------------------------------------------------------

ap0 = argparse.ArgumentParser(add_help=False)
ap0.add_argument("-d", "--dir", default=".",
                 help="bench dir (default: cur dir)")
args0, _rest = ap0.parse_known_args()

WORKDIR    = Path(args0.dir).resolve()
RPT_DIR    = WORKDIR
LEN_PKG    = WORKDIR / "rtl" / "len_table_pkg.sv"
TIMING_RPT = WORKDIR / "post_route_timing.rpt"
POWER_RPT  = WORKDIR / "post_route_power.rpt"

CLK_TARGET_MHZ = 300.0  # target clock (MHz) – adjust if constraint changes
TARGET_T_NS    = 1000.0 / CLK_TARGET_MHZ

# ----------------------------------------------------------------------------------------------
# Utility: load text safely
# ----------------------------------------------------------------------------------------------

def text(p: Path) -> str:
    """Read *p* as text, return empty string if file missing."""
    return p.read_text(errors="ignore") if p.is_file() else ""

# ----------------------------------------------------------------------------------------------
# Timing report parsing (post_route_timing.rpt)
# ----------------------------------------------------------------------------------------------

WNS_ROW_RE = re.compile(r"Design Timing Summary.*?\n\s*([-+]?[0-9.]+)", re.S | re.I)


def parse_timing() -> tuple[float | None, float | None]:
    """Return (WNS ns, effective Fmax MHz)."""
    txt = text(TIMING_RPT)
    if not txt:
        return None, None

    m   = WNS_ROW_RE.search(txt)
    wns = float(m.group(1)) if m else None

    fmax = None
    if wns is not None:
        eff_period = TARGET_T_NS - wns  # ns
        if eff_period > 0:
            fmax = 1000.0 / eff_period  # MHz
    return wns, fmax

# ----------------------------------------------------------------------------------------------
# Utilization report parsing (utilization_pblock_*.rpt)
# ----------------------------------------------------------------------------------------------

def _parse_row_usage_available(tag: str, rpt_txt: str) -> tuple[int | None, int | None]:
    """Extract (used, available) from a utilization row whose first cell matches *tag*."""
    # Row example:
    # | DSPs | 76 | 0 | 0 | 76 | 0 | 0 | 144 | 52.78 |
    pattern = rf"^\|\s*{re.escape(tag)}\s*\|(?P<cells>[^\n]*)$"
    m = re.search(pattern, rpt_txt, flags=re.M)
    if not m:
        return None, None
    nums = [int(n.replace(",", "")) for n in re.findall(r"\d+", m.group("cells"))]
    if len(nums) < 7:
        return None, None
    used, avail = nums[3], nums[6]
    return used, avail


def parse_util(rpt: Path) -> dict[str, Any]:
    u_txt = text(rpt)
    dsp_used, dsp_tot = _parse_row_usage_available("DSPs", u_txt)
    clb_used, clb_tot = _parse_row_usage_available("CLB",  u_txt)
    return {
        "pblock_clb_total": clb_tot,
        "pblock_clb_used":  clb_used,
        "pblock_dsp_total": dsp_tot,
        "pblock_dsp_used":  dsp_used,
    }

# ----------------------------------------------------------------------------------------------
# Power report parsing (post_route_power.rpt)
# ----------------------------------------------------------------------------------------------

def _grab_power(label: str, txt: str) -> float | None:
    m = re.search(rf"{re.escape(label)}\s*\(W\)\s*\|\s*([0-9.]+)", txt)
    return float(m.group(1)) if m else None


def parse_power() -> dict[str, Any]:
    txt = text(POWER_RPT)
    if not txt:
        return {
            "total_on_chip_power_w": None,
            "dynamic_power_w":       None,
            "device_static_power_w": None,
        }
    return {
        "total_on_chip_power_w": _grab_power("Total On-Chip Power", txt),
        "dynamic_power_w":       _grab_power("Dynamic", txt),
        "device_static_power_w": _grab_power("Device Static", txt),
    }

# ----------------------------------------------------------------------------------------------
# len_table_pkg.sv helper – stage / µ‑op extraction
# ----------------------------------------------------------------------------------------------

def parse_len_pkg() -> tuple[str, str]:
    src = text(LEN_PKG)
    stages = re.findall(r"STAGE_LUT\s*\[N_CASE\].+?\{\s*([^}]+)\}", src, re.S)
    if stages:
        nums = [int(x) for x in stages[0].replace("\n", " ").split(",") if x.strip()]
        stage_expr = "+".join(str(n) for n in nums)
    else:
        stage_expr = "?"

    muops_match = re.search(r"OPS_LUT.+?=\s*'\{(.+?)\};", src, re.S)
    rows = re.findall(r"\{\s*([^}]+)\}", muops_match.group(1)) if muops_match else []
    muops = ", ".join(
        "-".join(tok.strip().replace("OP_", "") for tok in row.split(",") if tok.strip() != "OP_NOP")
        for row in rows
    )
    return stage_expr, muops

# ----------------------------------------------------------------------------------------------
# Main collection pipeline
# ----------------------------------------------------------------------------------------------

def collect(tag: str) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]], List[Dict[str, Any]]]:
    wns, fmax            = parse_timing()
    stage_expr, muops    = parse_len_pkg()
    power_dict           = parse_power()

    impl_rows:   List[Dict[str, Any]] = []
    block_rows:  List[Dict[str, Any]] = []
    sniper_rows: List[Dict[str, Any]] = []

    pcs_all:  list[str] = []
    lats_all: list[str] = []

    # Block‑level JSONs ( *_alu_result_augmented.json or blocks/blk*.json )
    blk_groups: List[dict] = []
    for fp in WORKDIR.glob("*_alu_result_augmented.json"):
        blk_groups = json.loads(fp.read_text())
        break
    if not blk_groups:
        blk_groups = [json.loads(p.read_text()) for p in (WORKDIR / "blocks").glob("blk*.json")]

    for g in blk_groups:
        bench = g.get("bench", "?")
        src   = g.get("src",   "?")
        pcs   = [ins["address"] for ins in g.get("instructions", [])]
        if not pcs:
            continue

        first_lat = str(g.get("latency_cycles", g.get("stage_count", 1)))
        sniper_rows.append({"bench": bench, "src": src, "pc": pcs[0], "latency": first_lat})
        sniper_rows.extend({"bench": bench, "src": src, "pc": p, "latency": "0"} for p in pcs[1:])

        lat_list = [first_lat] + ["0"] * (len(pcs) - 1)
        pcs_all.extend(pcs)
        lats_all.extend(lat_list)

        block_rows.append({
            "bench":       bench,
            "src":         src,
            "pcs":         ",".join(pcs),
            "latencies":   ",".join(lat_list),
            "stage_count": g.get("stage_count", 1),
            "muops":       "-".join(op["opcode"].upper() for op in g["instructions"]),
        })

    # Utilization per pblock
    for util_rpt in sorted(RPT_DIR.glob("utilization_pblock_*.rpt")):
        pb_name = util_rpt.stem.replace("utilization_", "")
        util    = parse_util(util_rpt)

        impl_rows.append({
            "run_tag":        tag,
            "timestamp_utc":  dt.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
            "pblock":         pb_name,
            **util,
            **power_dict,
            "fmax_mhz":       round(fmax, 3) if fmax else None,
            "wns_ns":         round(wns, 3) if wns else None,
            "stage_count":    stage_expr,
            "muops":          muops,
            "pcs":            ",".join(pcs_all),
            "latencies":      ",".join(lats_all),
        })

    return impl_rows, block_rows, sniper_rows

# ----------------------------------------------------------------------------------------------
# Dump helpers
# ----------------------------------------------------------------------------------------------

def dump(rows, block_rows, sniper_rows, tag):
    base = WORKDIR / f"impl_summary_{tag}"

    # Main summary JSON/CSV
    base.with_suffix(".json").write_text(json.dumps(rows, indent=2))
    with base.with_suffix(".csv").open("w", newline="") as f:
        w = csv.DictWriter(f, rows[0].keys())
        w.writeheader()
        w.writerows(rows)
    print(f"Done, {base.name}.json / .csv written")

    # Sniper CSV
    if sniper_rows:
        seen, uniq = set(), []
        for r in sniper_rows:
            key = (r["bench"], r["src"], r["pc"])
            if key not in seen:
                seen.add(key)
                uniq.append(r)
        sfile = RPT_DIR / f"sniper_{tag}.csv"
        with sfile.open("w", newline="") as f:
            w = csv.DictWriter(f, ["bench", "src", "pc", "latency"])
            w.writeheader()
            w.writerows(uniq)
        print(f"Done, {sfile.name} (for Sniper cfg)")

    # Block summary JSON/CSV
    if block_rows:
        bfile = RPT_DIR / f"block_summary_{tag}.json"
        bfile.write_text(json.dumps(block_rows, indent=2))
        with bfile.with_suffix(".csv").open("w", newline="") as f:
            w = csv.DictWriter(f, block_rows[0].keys())
            w.writeheader()
            w.writerows(block_rows)
        print(f"Done, {bfile.name} / .csv written")

# ----------------------------------------------------------------------------------------------
# CLI
# ----------------------------------------------------------------------------------------------

if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Parse Vivado reports and summarise implementation results.")
    ap.add_argument("run_tag", help="Unique tag identifying this synthesis run (e.g. 527.cam4_s)")
    args = ap.parse_args()

    if not TIMING_RPT.exists():
        sys.exit("ERROR: post_route_timing.rpt missing")

    rows, block_rows, sniper_rows = collect(args.run_tag)
    if not rows:
        sys.exit("ERROR: no utilization_pblock_*.rpt found")

    dump(rows, block_rows, sniper_rows, args.run_tag)
