#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import math
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple

TARGET_CLK_MHZ = 300.0
TARGET_PERIOD_NS = 1000.0 / TARGET_CLK_MHZ  # ~= 3.333 ns


def safe_name(original: str) -> str:
    return re.sub(r"[^A-Za-z0-9_]", "_", original)


def build_safe2orig_map(bench_root: Path) -> Dict[str, str]:
    mapping: Dict[str, str] = {}
    for d in bench_root.iterdir():
        if d.is_dir():
            mapping[safe_name(d.name)] = d.name
    return mapping


def bench_has_exact_limit_file(bench_dir: Path, limit_name: str) -> bool:
    if limit_name == "full":
        cand = bench_dir / "len_table_pkg.sv"
    else:
        cand = bench_dir / f"len_table_pkg_{limit_name}.sv"
    return cand.is_file()


def parse_timing_report(timing_rpt_path: Path) -> Tuple[Optional[float], Optional[float]]:
    if not timing_rpt_path.is_file():
        return (None, None)

    txt = timing_rpt_path.read_text(errors="ignore")

    wns_val: Optional[float] = None

    table_pat = re.compile(
        r"WNS\(ns\)[^\n]*\n"       
        r"[^\n]*-+[^\n]*\n"          
        r"\s*([-\d\.]+)",           
        re.IGNORECASE | re.MULTILINE,
    )
    m = table_pat.search(txt)
    if m:
        try:
            wns_val = float(m.group(1))
        except ValueError:
            wns_val = None

    if wns_val is None:
        m = re.search(
            r"\bWNS\s*\(ns\)\s*[:=]?\s*([-+]?\d+(?:\.\d+)?)",
            txt,
            re.IGNORECASE,
        )
        if m:
            try:
                wns_val = float(m.group(1))
            except ValueError:
                wns_val = None

    if wns_val is None:
        m = re.search(
            r"Slack\s*\(WNS\)\s*[:=]?\s*([-+]?\d+(?:\.\d+)?)(?:\s*ns)?",
            txt,
            re.IGNORECASE,
        )
        if m:
            try:
                wns_val = float(m.group(1))
            except ValueError:
                wns_val = None

    if wns_val is None:
        for line in txt.splitlines():
            if re.search(r"\bWNS\b", line, re.IGNORECASE):
                nums = re.findall(r"[-+]?\d+(?:\.\d+)?", line)
                if nums:
                    try:
                        wns_val = float(nums[0])
                        break
                    except ValueError:
                        pass

    if wns_val is None:
        return (None, None)

    crit_period = TARGET_PERIOD_NS - wns_val
    if crit_period <= 0:
        fmax_mhz = None
    else:
        fmax_mhz = 1000.0 / crit_period  # MHz

    return (
        round(wns_val, 3),
        round(fmax_mhz, 3) if fmax_mhz is not None else None,
    )


def _int_from_match(m: re.Match) -> Optional[int]:
    try:
        return int(m.group(1).replace(",", ""))
    except Exception:
        return None


def estimate_clb_from_util(util_rpt_path: Path) -> Optional[int]:
    if not util_rpt_path.is_file():
        return None

    txt = util_rpt_path.read_text(errors="ignore")

    clb_used: Optional[int] = None

    for line in txt.splitlines():
        m = re.match(r"\s*\|\s*CLB\s*\|\s*([0-9,]+)", line)
        if m:
            clb_used = _int_from_match(m)
            break

    if clb_used is None or clb_used == 0:
        luts_used: Optional[int] = None
        for line in txt.splitlines():
            m = re.match(
                r"\s*\|\s*(?:Slice\s+LUTs\*?|Slice\s+LUTs|CLB\s+LUTs\*?|CLB\s+LUTs)\s*\|\s*([0-9,]+)",
                line,
                re.IGNORECASE,
            )
            if m:
                luts_used = _int_from_match(m)
                if luts_used is not None:
                    break

        if luts_used is not None:
            clb_used = math.ceil(luts_used / 8.0)

    return clb_used


def collect_for_limit(
    reports_root: Path,
    bench_root: Path,
    limit_name: str,
    safe2orig: Dict[str, str],
) -> List[Dict[str, object]]:
    synth_dir = reports_root / f"synth_{limit_name}"
    benches_dir = synth_dir / "benches"
    rows: List[Dict[str, object]] = []

    if not benches_dir.is_dir():
        return rows

    for safe_bench_dir in sorted(benches_dir.iterdir()):
        if not safe_bench_dir.is_dir():
            continue

        safe_bench_name = safe_bench_dir.name  
        orig_name = safe2orig.get(safe_bench_name)
        if orig_name is None:
            continue

        if not bench_has_exact_limit_file(bench_root / orig_name, limit_name):
            continue

        util_rpt   = safe_bench_dir / "pre_impl_util.rpt"
        timing_rpt = safe_bench_dir / "pre_impl_timing.rpt"

        clb_est = estimate_clb_from_util(util_rpt)
        (_, fmax_mhz) = parse_timing_report(timing_rpt)

        rows.append(
            {
                "limit":     limit_name,
                "bench":     orig_name,
                "CLB_Used":  clb_est,
                "Fmax_MHz":  fmax_mhz,
            }
        )

    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--bench-root",
        required=True,
        type=str,
        help=(
            "Path to the BENCH_ROOT directory, i.e. the directory that contains one "
            "subdirectory per original benchmark. Example: reports/memory_wo_simd"
        ),
    )
    parser.add_argument(
        "--reports-root",
        required=True,
        type=str,
        help=(
            "Path to the reports directory that contains synth_<limit> subdirs "
            "(e.g. synth_0p5pct, synth_1p0pct, ...). Example: reports"
        ),
    )
    parser.add_argument(
        "--out",
        required=True,
        type=str,
        help="Path to the output CSV file to write.",
    )

    args = parser.parse_args()

    bench_root   = Path(args.bench_root).resolve()
    reports_root = Path(args.reports_root).resolve()
    out_csv      = Path(args.out).resolve()

    # Map '500_perlbench_r' -> '500.perlbench_r', etc.
    safe2orig = build_safe2orig_map(bench_root)

    all_rows: List[Dict[str, object]] = []
    for synth_dir in sorted(reports_root.iterdir()):
        if not synth_dir.is_dir():
            continue
        m = re.match(r"^synth_(.+)$", synth_dir.name)
        if not m:
            continue
        limit_name = m.group(1)

        rows = collect_for_limit(
            reports_root=reports_root,
            bench_root=bench_root,
            limit_name=limit_name,
            safe2orig=safe2orig,
        )
        all_rows.extend(rows)

    fieldnames = ["limit", "bench", "CLB_Used", "Fmax_MHz"]

    with out_csv.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in all_rows:
            w.writerow(r)

    print(f"Wrote {len(all_rows)} rows -> {out_csv}")


if __name__ == "__main__":
    main()