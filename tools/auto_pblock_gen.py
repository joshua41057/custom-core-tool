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
    type_xs = {"SLICE": set(), "DSP48E2": set(), "RAMB18": set(), "RAMB36": set(), "URAM288": set()}
    type_ymin = {"SLICE":  1<<30, "DSP48E2": 1<<30, "RAMB18": 1<<30, "RAMB36": 1<<30, "URAM288": 1<<30}
    type_ymax = {"SLICE": -(1<<30), "DSP48E2": -(1<<30), "RAMB18": -(1<<30), "RAMB36": -(1<<30), "URAM288": -(1<<30)}
    lines = [l.strip() for l in txt.splitlines() if l.strip()]
    grid_line = None
    for l in lines:
        if l.startswith("GRID_RANGES"):
            grid_line = l.split("GRID_RANGES",1)[1].strip()
            break
        if l.startswith("DERIVED_RANGES"):
            grid_line = l.split("DERIVED_RANGES",1)[1].strip()
    if not grid_line:
        raise ValueError("No GRID_RANGES/DERIVED_RANGES line found in grid file")

    parts = [p.strip() for p in grid_line.split(",")]
    rng_re = re.compile(r'(?P<typ>SLICE|DSP48E2|RAMB18|RAMB36|URAM288)_X(?P<x0>\d+)Y(?P<y0>-?\d+):\w+_X(?P<x1>\d+)Y(?P<y1>-?\d+)')
    for p in parts:
        m = rng_re.search(p)
        if not m: 
            continue
        typ = m.group("typ")
        x0, x1 = int(m.group("x0")), int(m.group("x1"))
        y0, y1 = int(m.group("y0")), int(m.group("y1"))
        for x in range(min(x0,x1), max(x0,x1)+1):
            type_xs[typ].add(x)
        lo_y, hi_y = (y0, y1) if y0 <= y1 else (y1, y0)
        type_ymin[typ] = min(type_ymin[typ], lo_y)
        type_ymax[typ] = max(type_ymax[typ], hi_y)
    # Sort
    type_xs = {k: sorted(v) for k,v in type_xs.items()}
    for k in list(type_ymin.keys()):
        if type_ymin[k] > type_ymax[k]:
            type_ymin[k], type_ymax[k] = 0, -1
    return type_xs, (type_ymin, type_ymax)

def parse_util_hier_ascii(rpt_text: str):
    lines = rpt_text.splitlines()
    hdr_idx = None
    for i,l in enumerate(lines):
        if re.search(r'\bLUT\b', l) and re.search(r'\bFF\b', l) and re.search(r'\bDSP\b', l):
            hdr_idx = i
            break
    if hdr_idx is None:
        raise ValueError("Cannot find header with LUT/FF/DSP in utilization report")
    header = lines[hdr_idx]
    Entry = namedtuple("Entry", "name depth LUT FF DSP BRAM18 BRAM36 URAM")
    entries = []
    totals = dict((k,0) for k in RES_KEYS)

    for l in lines[hdr_idx+1:]:
        if '|' not in l: 
            continue
        cols = [c.strip() for c in l.split('|')]
        if len(cols) < 3:
            continue
        name_field = cols[0]
        nums = [c for c in cols[1:] if re.search(r'\d', c)]
        if len(nums) < 3:
            continue
        raw = name_field
        cname = raw.replace('+', '').replace('-', '').replace('─','').replace('└','').replace('├','').replace('│','').strip()
        depth = len(raw) - len(raw.lstrip())
        def find_num(key):
            m = re.search(rf'{key}\s*\:\s*([0-9]+)', l) 
            if m:
                return int(m.group(1))
            return None

        ints = [int(x) for x in re.findall(r'\b\d+\b', l)]
        LUT=FF=DSP=BRAM18=BRAM36=URAM=0
        if len(ints)>=6:
            LUT = ints[-6]
            FF  = ints[-5]
            BRAM18 = ints[-4]
            URAM = ints[-3]
            DSP = ints[-1]
            BRAM36 = BRAM18//2
        entries.append(Entry(cname, depth, LUT, FF, DSP, BRAM18, BRAM36, URAM))

    top = None
    for e in entries:
        if e.depth == 0 and e.name:
            top = e.name
            break
    top_children = []
    for e in entries:
        if e.depth == 2:  
            top_children.append(e)

    if not top_children:
        top_children = [e for e in entries[:50] if e.name]
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
    if bands and bands[-1][1] != xs[-1]:
        bands[-1] = (bands[-1][0], xs[-1])
    return bands

def greedy_pack(children, capacities, k):
    bins = [dict((rk,0) for rk in RES_KEYS) for _ in range(k)]
    groups = [[] for _ in range(k)]
    def score(e):
        return e.LUT + e.FF/2 + 200*e.DSP + 20*(e.BRAM18 + 2*e.BRAM36) + 300*e.URAM
    order = sorted(children, key=score, reverse=True)

    def dist(bin_load, i):
        d = 0.0
        for rk in RES_KEYS:
            cap = capacities[rk][i] if i < len(capacities[rk]) else 0.0
            cap = max(cap, 1e-6)
            d += (bin_load[rk]/cap)**2
        return d

    for e in order:
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
    
    safe_bench = re.sub(r'[^A-Za-z0-9_]', '_', args.bench)

    grid_txt = Path(args.grid).read_text(encoding="utf-8", errors="ignore")
    type_xs, (type_ymin, type_ymax) = parse_grid_ranges(grid_txt)

    rpt_txt  = Path(args.util).read_text(encoding="utf-8", errors="ignore")
    totals, children = parse_util_hier_ascii(rpt_txt)

    # Device column counts
    n_slice = len(type_xs["SLICE"])
    n_dsp   = len(type_xs["DSP48E2"])
    n_b18   = len(type_xs["RAMB18"])
    n_b36   = len(type_xs["RAMB36"])
    n_uram  = len(type_xs["URAM288"])

    k = max(1, int(args.npblocks))

    weights = [1.0/k for _ in range(k)]

    slice_xs   = type_xs["SLICE"]
    slice_bands = split_columns(slice_xs, k, weights)
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

    groups = greedy_pack(children, caps, k)

    def map_band_to_res(xs_res, band):
        if not xs_res:
            return None
        xlo, xhi = band
        # positions in SLICE ordered list
        try:
            pos_lo = slice_xs.index(xlo)
            pos_hi = slice_xs.index(xhi)
        except ValueError:
            return None
        if pos_lo > pos_hi:
            pos_lo, pos_hi = pos_hi, pos_lo
        nS = max(1, len(slice_xs) - 1)
        nR = max(1, len(xs_res)  - 1)
        r_lo = int(round((pos_lo / nS) * nR))
        r_hi = int(round((pos_hi / nS) * nR))
        if r_hi < r_lo:
            r_hi = r_lo
        return xs_res[r_lo], xs_res[r_hi]
    # Emit Tcl
    out = []
    out.append(f"# Auto-generated pblocks for bench {args.bench}")
    out.append("set_param place.enableMBBB true")
    out.append("set_param place.enableClockRegionRepacking true")
    out.append("")
    for i, (xlo,xhi) in enumerate(slice_bands):
        pb = f"pblock_{safe_bench}_{i}"
        out.append(f"if {{[llength [get_pblocks {pb}]]}} {{ delete_pblocks [get_pblocks {pb}] }}")
        out.append(f"create_pblock {pb}")
        set_ylo = type_ymin["SLICE"]; set_yhi = type_ymax["SLICE"]
        out.append(f"resize_pblock [get_pblocks {pb}] -add {{SLICE_X{xlo}Y{set_ylo}:SLICE_X{xhi}Y{set_yhi}}}")
        

        dsp_band = map_band_to_res(type_xs["DSP48E2"], (xlo,xhi))
        if dsp_band and n_dsp>0:
            dx0, dx1 = dsp_band
            out.append(f"resize_pblock [get_pblocks {pb}] -add {{DSP48E2_X{dx0}Y{type_ymin['DSP48E2']}:DSP48E2_X{dx1}Y{type_ymax['DSP48E2']}}}")
        b18_band = map_band_to_res(type_xs["RAMB18"], (xlo,xhi))
        if b18_band and n_b18>0:
            bx0, bx1 = b18_band
            out.append(f"resize_pblock [get_pblocks {pb}] -add {{RAMB18_X{bx0}Y{type_ymin['RAMB18']}:RAMB18_X{bx1}Y{type_ymax['RAMB18']}}}")
        b36_band = map_band_to_res(type_xs["RAMB36"], (xlo,xhi))
        if b36_band and n_b36>0:
            cx0, cx1 = b36_band
            out.append(f"resize_pblock [get_pblocks {pb}] -add {{RAMB36_X{cx0}Y{type_ymin['RAMB36']}:RAMB36_X{cx1}Y{type_ymax['RAMB36']}}}")
        ur_band = map_band_to_res(type_xs["URAM288"], (xlo,xhi))
        if ur_band and n_uram>0:
            ux0, ux1 = ur_band
            out.append(f"resize_pblock [get_pblocks {pb}] -add {{URAM288_X{ux0}Y{type_ymin['URAM288']}:URAM288_X{ux1}Y{type_ymax['URAM288']}}}")

        out.append(f"set_property SNAPPING_MODE ON [get_pblocks {pb}]")
        out.append(f"set_property EXCLUDE_PLACEMENT false [get_pblocks {pb}]")
        out.append(f"set_property EXCLUDE_ROUTING   false [get_pblocks {pb}]")
        # Assign cells (hierarchical groups greedily packed)

        names = groups[i]
        if names:
            out.append("set sel_cells {}")
            pats = " ".join([f"*{n}*" for n in names])
            out.append(f"set _patterns {{{pats}}}")
            out.append("foreach p $_patterns {")
            out.append("  set c [get_cells -hier -quiet -filter \"NAME =~ $p\"]")
            out.append("  if {[llength $c]} { lappend sel_cells $c }")
            out.append("}")
            out.append(f"if {{[llength $sel_cells]}} {{ add_cells_to_pblock [get_pblocks {pb}] $sel_cells }}")
        out.append("")
    # Write out
    Path(args.out).write_text("\n".join(out), encoding="utf-8")
    print(f"Wrote {args.out}")

if __name__ == "__main__":
    main()
