#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
auto_pblock_gen.py
- Read post-synth hierarchical utilization (ASCII)
- Read device grid ranges (constraints/grid_ranges.txt)
- Compute vertical band pblocks sized for ~TARGET_FILL using actual usage
- Greedily assign top-level child instances into pblocks to balance resource use
- Emit a Tcl file that creates pblocks, resizes, and add_cells_to_pblock

Usage:
  python3 tools/auto_pblock_gen.py --util post_synth_util_hier.rpt \
      --grid constraints/grid_ranges.txt --npblocks 8 --target-fill 0.8 \
      --bench 527.cam4_r --out reports/527.cam4_r/auto_pblock.tcl
"""
import re, sys, json, argparse, math
from pathlib import Path
from collections import defaultdict, namedtuple

RES_KEYS = ["LUT", "FF", "DSP", "BRAM18", "BRAM36", "URAM"]

def parse_grid_ranges(txt: str):
    """
    Accepts a file that contains a line starting with 'GRID_RANGES' followed by
    comma-separated ranges like 'SLICE_X0Y1:SLICE_X7Y898' etc.
    Returns a dict with per-type sorted unique X columns.
    """
    type_xs = {"SLICE": set(), "DSP48E2": set(), "RAMB18": set(), "RAMB36": set(), "URAM288": set()}
    lines = [l.strip() for l in txt.splitlines() if l.strip()]
    grid_line = None
    for l in lines:
        if l.startswith("GRID_RANGES"):
            grid_line = l.split("GRID_RANGES",1)[1].strip()
            break
        if l.startswith("DERIVED_RANGES"):
            grid_line = l.split("DERIVED_RANGES",1)[1].strip()
            # still acceptable if only DERIVED_RANGES present
    if not grid_line:
        raise ValueError("No GRID_RANGES/DERIVED_RANGES line found in grid file")

    # Split ranges by comma
    parts = [p.strip() for p in grid_line.split(",")]
    rng_re = re.compile(r'(?P<typ>SLICE|DSP48E2|RAMB18|RAMB36|URAM288)_X(?P<x0>\d+)Y(?P<y0>-?\d+):\w+_X(?P<x1>\d+)Y(?P<y1>-?\d+)')
    for p in parts:
        m = rng_re.search(p)
        if not m: 
            continue
        typ = m.group("typ")
        x0, x1 = int(m.group("x0")), int(m.group("x1"))
        for x in range(min(x0,x1), max(x0,x1)+1):
            type_xs[typ].add(x)
    # Sort
    type_xs = {k: sorted(v) for k,v in type_xs.items()}
    return type_xs

def parse_util_hier_ascii(rpt_text: str):
    """
    Very tolerant parser for Vivado 'report_utilization -hierarchical' ASCII.
    Returns totals and a list of top-level children with resource counts.
    """
    lines = rpt_text.splitlines()
    # Identify header line to detect column indices
    hdr_idx = None
    for i,l in enumerate(lines):
        if re.search(r'\bLUT\b', l) and re.search(r'\bFF\b', l) and re.search(r'\bDSP\b', l):
            hdr_idx = i
            break
    if hdr_idx is None:
        raise ValueError("Cannot find header with LUT/FF/DSP in utilization report")
    header = lines[hdr_idx]
    # Determine columns by searching for numbers below headers -> we will just split by '|' and strip
    Entry = namedtuple("Entry", "name depth LUT FF DSP BRAM18 BRAM36 URAM")
    entries = []
    totals = dict((k,0) for k in RES_KEYS)

    # heuristic: lines with '|' separators and numeric fields will be parsed
    for l in lines[hdr_idx+1:]:
        if '|' not in l: 
            continue
        cols = [c.strip() for c in l.split('|')]
        if len(cols) < 3:
            continue
        name_field = cols[0]
        # try to parse resource numbers from last columns (they are often at the end)
        nums = [c for c in cols[1:] if re.search(r'\d', c)]
        if len(nums) < 3:
            continue
        # Extract name and depth by counting leading spaces
        raw = name_field
        # remove draw characters
        cname = raw.replace('+', '').replace('-', '').replace('─','').replace('└','').replace('├','').replace('│','').strip()
        depth = len(raw) - len(raw.lstrip())
        # Now scan for resource values in the entire line using regex keys
        def find_num(key):
            # search like 'LUT' then the number after in the table; fallback: any number token with key nearby
            m = re.search(rf'{key}\s*\:\s*([0-9]+)', l)  # not common
            if m:
                return int(m.group(1))
            # fallback: try to map by typical column ordering (LUT, LUTRAM, FF, BRAM_18K, URAM, DSP...)
            return None

        # Robust tokenization: grab all integers in the line
        ints = [int(x) for x in re.findall(r'\b\d+\b', l)]
        # Try to map: take last 6 ints as (maybe) [LUT, FF, BRAM18, BRAM36, URAM, DSP] in some order
        LUT=FF=DSP=BRAM18=BRAM36=URAM=0
        if len(ints)>=6:
            # Guess: Vivado usually has "... LUT as Logic | LUT as Memory | Reg | BRAM_18K | URAM | DSP"
            # We'll approximate LUT by the max of first two LUT fields if present. Hard to robustly do without JSON.
            # Strategy: use the largest among early integers as LUT-ish, the next as FF-ish etc. It's a heuristic.
            # To be safer, we also search for tokens with clues.
            # Basic fallback:
            LUT = ints[-6]
            FF  = ints[-5]
            BRAM18 = ints[-4]
            URAM = ints[-3]
            DSP = ints[-1]
            # BRAM36 is often not a separate column; approximate from BRAM18//2
            BRAM36 = BRAM18//2
        # Accumulate totals only for the grand total row (depth small)
        entries.append(Entry(cname, depth, LUT, FF, DSP, BRAM18, BRAM36, URAM))

    # Summarize by top-level children (depth minimal but not zero)
    # Find top name (first non-empty)
    top = None
    for e in entries:
        if e.depth == 0 and e.name:
            top = e.name
            break
    top_children = []
    for e in entries:
        if e.depth == 2:  # heuristic: table draws add 2 spaces for first level
            top_children.append(e)

    # If no children detected, fallback to grouping by the biggest few entries
    if not top_children:
        # choose first 50 entries as potential groups
        top_children = [e for e in entries[:50] if e.name]
    # Compute totals across entries (rough, used only for scaling wide devices)
    tot = dict((k,0) for k in RES_KEYS)
    for e in top_children:
        tot["LUT"] += e.LUT
        tot["FF"]  += e.FF
        tot["DSP"] += e.DSP
        tot["BRAM18"] += e.BRAM18
        tot["BRAM36"] += e.BRAM36
        tot["URAM"] += e.URAM

    return tot, top_children

def split_columns(xs, k, weights):
    """
    Split sorted column indices xs into k contiguous bands, proportionally to 'weights' (sum to 1).
    Returns list of (x_lo, x_hi).
    """
    n = len(xs)
    if n == 0:
        return [(0, -1)] * k
    target = [w * n for w in weights]
    bands = []
    start = 0
    acc = 0.0
    for i, t in enumerate(target):
        width = int(round(t))
        if i == k-1:
            end = n
        else:
            end = min(n, start + width)
        if end <= start and i < k-1:
            end = start + 1
        bands.append( (xs[start], xs[end-1]) )
        start = end
    # Fix any gaps/overlaps due to rounding
    if bands and bands[-1][1] != xs[-1]:
        bands[-1] = (bands[-1][0], xs[-1])
    return bands

def greedy_pack(children, capacities, k):
    """
    Greedy bin pack top-level children into k bins to match capacities.
    capacities: dict with keys in RES_KEYS mapping to list of per-bin capacities (relative units)
    Returns list of lists of child names per bin.
    """
    bins = [dict((rk,0) for rk in RES_KEYS) for _ in range(k)]
    groups = [[] for _ in range(k)]
    # weight vector for demand: emphasize LUT/FF + DSP + memories
    def score(e):
        return e.LUT + e.FF/2 + 200*e.DSP + 20*(e.BRAM18 + 2*e.BRAM36) + 300*e.URAM
    order = sorted(children, key=score, reverse=True)

    # "distance" of bin load to capacity (sum normalized squares)
    def dist(bin_load, i):
        d = 0.0
        for rk in RES_KEYS:
            cap = capacities[rk][i] if i < len(capacities[rk]) else 0.0
            cap = max(cap, 1e-6)
            d += (bin_load[rk]/cap)**2
        return d

    for e in order:
        # try all bins and pick the one that minimizes distance
        best_i, best_val = 0, float('inf')
        for i in range(k):
            tmp = bins[i].copy()
            tmp["LUT"] += e.LUT
            tmp["FF"]  += e.FF
            tmp["DSP"] += e.DSP
            tmp["BRAM18"] += e.BRAM18
            tmp["BRAM36"] += e.BRAM36
            tmp["URAM"] += e.URAM
            val = dist(tmp, i)
            if val < best_val:
                best_val, best_i = val, i
        # assign
        bins[best_i]["LUT"] += e.LUT
        bins[best_i]["FF"]  += e.FF
        bins[best_i]["DSP"] += e.DSP
        bins[best_i]["BRAM18"] += e.BRAM18
        bins[best_i]["BRAM36"] += e.BRAM36
        bins[best_i]["URAM"] += e.URAM
        groups[best_i].append(e.name)
    return groups

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--util", required=True)
    ap.add_argument("--grid", required=True)
    ap.add_argument("--npblocks", type=int, default=8)
    ap.add_argument("--target-fill", type=float, default=0.80)
    ap.add_argument("--bench", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    grid_txt = Path(args.grid).read_text(encoding="utf-8", errors="ignore")
    type_xs = parse_grid_ranges(grid_txt)

    rpt_txt  = Path(args.util).read_text(encoding="utf-8", errors="ignore")
    totals, children = parse_util_hier_ascii(rpt_txt)

    # Device column counts
    n_slice = len(type_xs["SLICE"])
    n_dsp   = len(type_xs["DSP48E2"])
    n_b18   = len(type_xs["RAMB18"])
    n_b36   = len(type_xs["RAMB36"])
    n_uram  = len(type_xs["URAM288"])

    k = max(1, int(args.npblocks))

    # Capacity per column is assumed uniform along Y; normalize to columns.
    # Compute desired total width W such that total design uses ~target_fill of W (not of whole device).
    # For columns, we can't shrink device; instead we partition whole device but size bands per expected load fraction.
    # We compute weights per band = capacity share; here we just split *equally* across bands by capacity, but
    # we will later *assign* modules to match resource capacities.
    weights = [1.0/k for _ in range(k)]

    # Split columns into k bands
    slice_bands = split_columns(type_xs["SLICE"], k, weights)
    # For hard resources, we keep the same X bands (vertical alignment). This is important for routability.
    # Compute per-band capacities (relative units = column count within the band)
    def band_capacity(xs, bands):
        cap = []
        for lo,hi in bands:
            cnt = len([x for x in xs if lo <= x <= hi])
            cap.append(float(cnt))
        return cap

    caps = {
        "LUT": band_capacity(type_xs["SLICE"], slice_bands),
        "FF":  band_capacity(type_xs["SLICE"], slice_bands),
        "DSP": band_capacity(type_xs["DSP48E2"], slice_bands),
        "BRAM18": band_capacity(type_xs["RAMB18"], slice_bands),
        "BRAM36": band_capacity(type_xs["RAMB36"], slice_bands),
        "URAM": band_capacity(type_xs["URAM288"], slice_bands),
    }

    # Greedy pack top-level children into bands according to capacities
    groups = greedy_pack(children, caps, k)

    # Emit Tcl
    out = []
    out.append(f"# Auto-generated pblocks for bench {args.bench}")
    out.append("set_param place.enableMBBB true")
    out.append("set_param place.enableClockRegionRepacking true")
    out.append("")
    for i, (xlo,xhi) in enumerate(slice_bands):
        pb = f"pblock_{args.bench}_{i}"
        out.append(f"if {{[llength [get_pblocks {pb}]]}} {{ delete_pblocks [get_pblocks {pb}] }}")
        out.append(f"create_pblock {pb}")
        # Collect resources inside this X band across full height
        # We define RANGE strings per type.
        # SLICE range
        out.append(f"resize_pblock [get_pblocks {pb}] -add {{SLICE_X{xlo}Y0:SLICE_X{xhi}Y9999}}")
        # Add matching DSP/BRAM/URAM columns (full height)
        if n_dsp>0:
            # approximate: include any DSP columns whose X falls within band
            out.append(f"resize_pblock [get_pblocks {pb}] -add {{DSP48E2_X{xlo}Y0:DSP48E2_X{xhi}Y9999}}")
        if n_b18>0:
            out.append(f"resize_pblock [get_pblocks {pb}] -add {{RAMB18_X{xlo}Y0:RAMB18_X{xhi}Y9999}}")
        if n_b36>0:
            out.append(f"resize_pblock [get_pblocks {pb}] -add {{RAMB36_X{xlo}Y0:RAMB36_X{xhi}Y9999}}")
        if n_uram>0:
            out.append(f"resize_pblock [get_pblocks {pb}] -add {{URAM288_X{xlo}Y0:URAM288_X{xhi}Y9999}}")
        out.append(f"set_property SNAPPING_MODE ON [get_pblocks {pb}]")
        out.append(f"set_property EXCLUDE_PLACEMENT false [get_pblocks {pb}]")
        out.append(f"set_property EXCLUDE_ROUTING   false [get_pblocks {pb}]")
        # Assign cells (hierarchical groups greedily packed)
        names = groups[i]
        if names:
            # Convert to Tcl list of hierarchical cell patterns under the current top
            # We assume top is 'top_multi_len'
            # If exact names don't match, users may adjust later. We use wildcards to be tolerant.
            toks = " ".join([f"*{n}*" for n in names])
            out.append(f"set sel_cells [get_cells -hier -quiet -filter {{NAME =~ {toks}}}]")
            out.append(f"if {{[llength $sel_cells]}} {{ add_cells_to_pblock [get_pblocks {pb}] $sel_cells }}")
        out.append("")
    # Write out
    Path(args.out).write_text("\n".join(out), encoding="utf-8")
    print(f"Wrote {args.out}")

if __name__ == "__main__":
    main()
