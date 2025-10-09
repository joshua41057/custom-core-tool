#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

CLK_TARGET_MHZ = 300.0
TARGET_T_NS = 1000.0 / CLK_TARGET_MHZ

def text(p: Path) -> str:
    return p.read_text(errors="ignore") if p.is_file() else ""

def parse_timing(timing_rpt_path: Path) -> Tuple[Optional[float], Optional[float]]:
    content = text(timing_rpt_path)
    if not content:
        return None, None

    m = re.search(r"WNS\(ns\)\s+.*\n\s*-+\s+.*\n\s*([\d.-]+)", content, re.M | re.I)
    wns = float(m.group(1)) if m else None

    fmax = None
    if wns is not None:
        effective_period = TARGET_T_NS - wns
        if effective_period > 0:
            fmax = round(1000.0 / effective_period, 3)

    return (round(wns, 3) if wns is not None else None), fmax

def parse_util(util_rpt_path: Path) -> Dict[str, Optional[Any]]:
    content = text(util_rpt_path)

    def get_resource_stats(tag: str) -> Optional[int]:
        pattern = re.compile(
            rf"^\s*\|\s*{re.escape(tag)}\s*\|"
            r"\s*[\d,]+\s*\|"  # Parent
            r"\s*[\d,]+\s*\|"  # Child
            r"\s*[\d,]+\s*\|"  # Non-Assigned
            r"\s*([\d,]+)\s*\|"  # Used (group 1)
            r"\s*[\d,]+\s*\|"  # Fixed
            r"\s*[\d,]+\s*\|"  # Available
            r"\s*[^|]+\s*\|",  # Util% (ignored)
            re.M | re.I
        )
        match = pattern.search(content)
        if match:
            used_str = match.group(1)
            return int(used_str.replace(",", "")) if used_str else 0
        return 0  # Default if no match

    clb_used = get_resource_stats("CLB")
    dsp_used = get_resource_stats("DSPs")
    bram_used = get_resource_stats("Block RAM Tile")

    return {
        "CLB_Used": clb_used,
        "DSP_Used": dsp_used,
        "BRAM_Used": bram_used,
    }

def parse_power(power_rpt_path: Path) -> Dict[str, Optional[float]]:
    content = text(power_rpt_path)
    m = re.search(r"^\s*\|\s*Dynamic\s*\(W\)\s*\|\s*(\d+\.\d+)", content, re.M | re.I)
    dynamic_w = float(m.group(1)) if m else None

    return {"Dynamic_Power_W": (round(dynamic_w, 4) if dynamic_w is not None else None)}

def main(work_dir: Path):
    all_results: List[Dict[str, Any]] = []
    
    case_paths = []
    if (work_dir / "single").is_dir():
        case_paths = [work_dir]
    else:
        case_paths = [p for p in work_dir.iterdir() if (p / "single").is_dir()]

    if not case_paths:
        print(f"Error: No subdirectories containing a 'single' folder found in {work_dir}", file=sys.stderr)
        return

    for case_path in case_paths:
        single_path = case_path / "single"
        case_name = case_path.name
        
        for bench_path in sorted(single_path.iterdir()):
            if not bench_path.is_dir():
                continue

            bench_name = bench_path.name
            
            timing_rpt = bench_path / "post_route_timing.rpt"
            util_rpt = bench_path / "pblock_util.rpt"
            power_rpt = bench_path / "post_route_power.rpt"

            if not (timing_rpt.is_file() and util_rpt.is_file() and power_rpt.is_file()):
                continue

            wns, fmax = parse_timing(timing_rpt)
            util_data = parse_util(util_rpt)
            power_data = parse_power(power_rpt)

            result_row = {
                "Case": case_name,
                "Benchmark": bench_name,
                "WNS_ns": wns,
                "Fmax_MHz": fmax,
                "Dynamic_Power_W": power_data["Dynamic_Power_W"],
                **util_data,
            }
            all_results.append(result_row)

    if not all_results:
        print("No results found. Check report files inside 'single' subdirectories.", file=sys.stderr)
        return

    output_csv_path = work_dir / "summary_pnr_results.csv"
    try:
        with open(output_csv_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=all_results[0].keys())
            writer.writeheader()
            writer.writerows(all_results)
        print(f"Analysis complete. Results saved to: {output_csv_path}")
    except (IOError, IndexError) as e:
        print(f"Error writing to file: {e}", file=sys.stderr)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Parse Vivado post-P&R results from 'single' directories."
    )
    parser.add_argument(
        "-d", "--dir", type=str, default=".",
        help="Root directory. Can be a single case folder (e.g., 'alubase') or a parent folder containing multiple cases."
    )
    args = parser.parse_args()
    main(Path(args.dir).resolve())