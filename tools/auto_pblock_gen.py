import argparse
import math
import re
import csv
from pathlib import Path
from dataclasses import dataclass
from typing import Dict, Tuple, List, Optional, Set


def _toi(x):
    try:
        return int(str(x).replace(',', '').strip())
    except Exception:
        return 0


def sanitize(s: str) -> str:
    import re
    return re.sub(r'[^A-Za-z0-9_]+', '_', s)


HDR = {
    "inst": ["Instance", "Hierarchical Cell", "Cell"],
    "lut_total": ["Total LUTs", "LUT", "CLB LUTs", "CLB LUTs*"],
    "lut_logic": ["Logic LUTs", "LUT as Logic"],
    "lut_mem": ["LUT as Memory", "LUTRAM", "LUTRAMs"],
    "lut_srl": ["SRL", "SRLs", "LUT as Shift Register"],
    "ff": ["FF", "FFs", "Registers", "CLB Registers"],
    "bram18": ["BRAM_18K", "RAMB18", "RAMB18E1", "RAMB18E2", "BRAM18/FIFO", "RAMB18/FIFO"],
    "bram36": ["RAMB36", "RAMB36E1", "RAMB36E2", "RAMB36/FIFO", "RAMB36/FIFO*"],
    "uram": ["URAM", "URAM288", "URAM288E2", "UltraRAM"],
    "dsp": ["DSP Blocks", "DSP", "DSPs", "DSP48", "DSP48E1", "DSP48E2"],
    "carry": ["CARRY8", "CARRY4"]
}


def _split(line):
    return [t.strip() for t in line.strip().split('|') if t.strip()]


def _find(h, k):
    for ali in HDR[k]:
        for i, t in enumerate(h):
            if t == ali or ali in t:
                return i
    return -1


@dataclass
class Util:
    inst: str
    lut: int
    ff: int
    carry: int
    dsp: int
    b18: int
    b36: int
    uram: int
    lut_mem: int = 0
    lut_srl: int = 0


def parse_util_hier_ascii(text: str) -> Util:
    lines = text.splitlines()
    hi = -1
    hdr = None
    for i, ln in enumerate(lines):
        if '|' not in ln:
            continue
        toks = _split(ln)
        if toks and any('Instance' in t for t in toks):
            hi = i
            hdr = toks
            break
    if hi < 0:
        raise SystemExit("util header not found")

    idx = {k: _find(hdr, k) for k in ["inst", "lut_total", "lut_logic", "lut_mem",
                                       "lut_srl", "ff", "bram18", "bram36", "uram", "dsp", "carry"]}

    def _get_num(tk, i):
        return _toi(tk[i]) if (0 <= i < len(tk)) else 0

    best = None
    top = None
    for ln in lines[hi + 1:]:
        if '|' not in ln:
            continue
        tk = _split(ln)
        if not tk:
            continue
        name = tk[idx["inst"]] if (0 <= idx["inst"] < len(tk)) else ""
        if any(x in name for x in ("Instance", "Total", "Totals", "----", "====", "+")):
            continue

        if 0 <= idx["lut_total"] < len(tk):
            lut = _get_num(tk, idx["lut_total"])
        else:
            lut = _get_num(tk, idx["lut_logic"]) + _get_num(tk, idx["lut_mem"]) + _get_num(tk, idx["lut_srl"])

        rec = Util(
            inst=name,
            lut=lut,
            ff=_get_num(tk, idx["ff"]),
            carry=_get_num(tk, idx["carry"]),
            dsp=_get_num(tk, idx["dsp"]),
            b18=_get_num(tk, idx["bram18"]),
            b36=_get_num(tk, idx["bram36"]),
            uram=_get_num(tk, idx["uram"]),
            lut_mem=_get_num(tk, idx["lut_mem"]),
            lut_srl=_get_num(tk, idx["lut_srl"]),
        )
        if rec.inst == "top_multi_len":
            top = rec
        score = rec.lut + rec.ff / 2 + 2000 * rec.dsp + 1500 * (rec.b36 + rec.b18) + 3000 * rec.uram
        if (best is None) or (score > best[0]):
            best = (score, rec)

    if top:
        return top
    if best:
        return best[1]
    raise SystemExit("no data row found under header")


@dataclass
class CR:
    x: int
    y: int
    slice: int
    dsp: int
    ramb18: int
    ramb36: int


def parse_cr_summary_csv(path: Path) -> Tuple[Dict[Tuple[int, int], CR], int, int]:
    crs: Dict[Tuple[int, int], CR] = {}
    xmax = -1
    ymax = -1
    with path.open(newline='', encoding='utf-8', errors='ignore') as f:
        r = csv.DictReader(f)
        for row in r:
            name = row.get('clock_region') or row.get('CLOCK_REGION') or row.get('cr') or ''
            m = re.match(r'X(\d+)Y(\d+)', name.strip(), re.I)
            if not m:
                continue
            x, y = int(m.group(1)), int(m.group(2))
            crs[(x, y)] = CR(
                x, y,
                _toi(row.get('SLICE', 0)),
                _toi(row.get('DSP', 0)),
                _toi(row.get('RAMB18', 0)),
                _toi(row.get('RAMB36', 0))
            )
            xmax = max(xmax, x)
            ymax = max(ymax, y)
    if not crs:
        raise SystemExit(f"no rows parsed from {path}")
    return crs, xmax, ymax


def slices_needed(lut: int, ff: int, carry: int, slice_lut: int = 4, slice_ff: int = 8) -> int:
    return max(1, math.ceil(lut / float(slice_lut)), math.ceil(ff / float(slice_ff)), carry)


@dataclass
class Box:
    x0: int
    y0: int
    x1: int
    y1: int
    sum_slice: int
    sum_slicem: int


def choose_cr_box_from_origin(
    crs: Dict[Tuple[int, int], CR],
    xmax: int,
    ymax: int,
    need_slices: int,
    need_slicem: int = 0,
    origin_x: int = 0,
    origin_y: int = 0,
    target_aspect: float = 0.90,
    aspect_tol: float = 0.25
) -> Box:
    def box_sum(x1, y1):
        s = 0
        m = 0
        for x in range(origin_x, x1 + 1):
            for y in range(origin_y, y1 + 1):
                c = crs.get((x, y))
                if c:
                    s += c.slice
                    m += int(round(c.slice * 0.5))
        return s, m

    best: Optional[Tuple[int, int, int, float, int, int]] = None
    best_box: Optional[Box] = None

    for y1 in range(origin_y, ymax + 1):
        for x1 in range(origin_x, xmax + 1):
            w = (x1 - origin_x + 1)
            h = (y1 - origin_y + 1)
            aspect = w / float(h)
            if abs(aspect - target_aspect) > aspect_tol:
                continue
            s, m = box_sum(x1, y1)
            if s < need_slices:
                continue
            if need_slicem and m < need_slicem:
                continue
            area = w * h
            over = s - need_slices
            key = (area, over, abs(aspect - target_aspect), x1, y1)
            if (best is None) or (key < best):
                best = key
                best_box = Box(origin_x, origin_y, x1, y1, s, m)

    if not best_box:
        for y1 in range(origin_y, ymax + 1):
            for x1 in range(origin_x, xmax + 1):
                s, m = box_sum(x1, y1)
                if s >= need_slices and (not need_slicem or m >= need_slicem):
                    return Box(origin_x, origin_y, x1, y1, s, m)
        raise SystemExit("cannot find any CR rectangle to satisfy slice/SLICEM requirement")
    return best_box


def emit_pblock_tcl(pbname: str, inst: str, box: Box) -> List[str]:
    tcl = []
    tcl.append(
        f"# pblock for {inst}  CR: X{box.x0}Y{box.y0} .. X{box.x1}Y{box.y1}  "
        f"(sumSLICE={box.sum_slice}, sumSLICEM~{box.sum_slicem})"
    )
    tcl.append(f'if {{[llength [get_pblocks -quiet {{{pbname}}}]]}} {{ delete_pblocks [get_pblocks -quiet {{{pbname}}}] }}')
    tcl.append(f"create_pblock {pbname}")
    tcl.append(f"set pblk [get_pblocks -quiet {{{pbname}}}]")
    tcl.append("set_property SNAPPING_MODE ON $pblk")
    tcl.append("set_property IS_SOFT false $pblk")
    tcl.append("set_property EXCLUDE_PLACEMENT false $pblk")
    tcl.append("set_property CONTAIN_ROUTING   false $pblk")

    cr_list_pref = []
    cr_list_nop  = []
    for x in range(box.x0, box.x1 + 1):
        for y in range(box.y0, box.y1 + 1):
            cr_list_pref.append(f"CLOCKREGION_X{x}Y{y}")
            cr_list_nop.append(f"X{x}Y{y}")
    crs_pref = " ".join(cr_list_pref)
    crs_nop  = " ".join(cr_list_nop)

    tcl += [
        f"set _cr_list {{{crs_nop}}}",  
        "set _cr [get_clock_regions -quiet $_cr_list]",
        "if {![llength $_cr]} { puts \"ERROR: No matching CLOCK_REGION objects for requested CR box.\"; exit 1 }",
        "set _sites [get_sites -quiet -of_objects $_cr "
        "  -filter { SITE_TYPE =~ SLIC* || SITE_TYPE =~ DSP* || NAME =~ RAMB18_* || NAME =~ RAMB36_* || SITE_TYPE =~ URAM* }]",
        "resize_pblock $pblk -add $_sites",
    ]

    tcl += [
        f'set inst_path {{{inst}}}',
        'set tgt {}',
        'set pats [list "$inst_path/*" "$inst_path"]',
        'foreach pat $pats {',
        '  set c [get_cells -quiet -hier * -filter "NAME =~ $pat"]',
        '  if {[llength $c]} { set tgt $c; break }',
        '}',
        'if {![llength $tgt]} {',
        '  set top [get_cells -quiet top_multi_len]',
        '  if {[llength $top]} { set tgt $top }',
        '}',
        'set hc {}',
        'if {[llength $tgt]} {',
        '  set hc [get_cells -quiet -hier -of_objects $tgt -filter { IS_PRIMITIVE == 1 && PRIMITIVE_GROUP != "IO" && PRIMITIVE_GROUP != "CLOCK" }]',
        '}',
        'if {![llength $hc]} {',
        '  puts "WARN: pattern $inst_path matched no cells. Falling back to whole design primitives."',
        '  set hc [get_cells -quiet -hier * -filter { IS_PRIMITIVE == 1 && PRIMITIVE_GROUP != "IO" && PRIMITIVE_GROUP != "CLOCK" }]',
        '}',
        'puts "INFO: add [llength $hc] cells to $pblk"',
        'if {[llength $hc] == 0} { puts "ERROR: No cells found to add into pblock"; exit 1 }',
        'add_cells_to_pblock $pblk $hc -clear_locs',
        'set NS  [llength [get_sites -quiet -of_objects $pblk -filter {SITE_TYPE =~ SLIC*}]]',
        'set ND  [llength [get_sites -quiet -of_objects $pblk -filter {SITE_TYPE =~ DSP*}]]',
        'set NB36 [llength [get_sites -quiet -of_objects $pblk -filter {NAME =~ RAMB36_*}]]',
        'set NB18 [llength [get_sites -quiet -of_objects $pblk -filter {NAME =~ RAMB18_*}]]',
        'set NU  [llength [get_sites -quiet -of_objects $pblk -filter {SITE_TYPE =~ URAM*}]]',
        'puts "INFO: pblock coverage SLICE=$NS DSP=$ND RAMB36=$NB36 RAMB18=$NB18 URAM=$NU"',
        ''
    ]
    return tcl


def main():
    ap = argparse.ArgumentParser(
        description="Generate pblocks by CLOCK_REGION rectangles, growing from X0Y0 like dragging."
    )
    ap.add_argument("--bench-list", required=True, help="list of hierarchical paths (one per line)")
    ap.add_argument("--bench-rpt-root", required=True, help="dir containing util_hier reports per bench")
    ap.add_argument("--cr-summary", required=True, help="CSV with per-CR counts (clock_region,SLICE,DSP,RAMB18,RAMB36)")
    ap.add_argument("--out", required=True, help="output Tcl file")
    ap.add_argument("--target-fill", type=float, default=0.65, help="slice fill target inside pblock")
    ap.add_argument("--min-slices", type=int, default=1200)
    ap.add_argument("--origin-crx", type=int, default=0)
    ap.add_argument("--origin-cry", type=int, default=0)
    ap.add_argument("--target-aspect", type=float, default=0.90, help="W/H aimed aspect")
    ap.add_argument("--aspect-tol", type=float, default=0.25, help="acceptable |W/H - target|")
    args = ap.parse_args()

    benches = [
        ln.strip()
        for ln in Path(args.bench_list).read_text(encoding="utf-8", errors="ignore").splitlines()
        if ln.strip()
    ]
    crs, xmax, ymax = parse_cr_summary_csv(Path(args.cr_summary))

    tcl_all: List[str] = []
    for inst in benches:
        safe = sanitize(inst.split('/')[-1] if '/' in inst else inst)
        cand_reports = [
            Path(args.bench_rpt_root) / safe / "pre_impl_util_hier.rpt",
            Path(args.bench_rpt_root) / safe / f"{safe}_util_hier.rpt",
        ]
        rpt = next((p for p in cand_reports if p.exists()), None)
        if rpt is None:
            raise SystemExit(f"util report missing under {Path(args.bench_rpt_root) / safe}")

        ut = parse_util_hier_ascii(rpt.read_text(encoding="utf-8", errors="ignore"))

        sneed_raw = slices_needed(ut.lut, ut.ff, ut.carry, slice_lut=4, slice_ff=8)
        sneed = max(args.min_slices, math.ceil(sneed_raw / max(1e-6, args.target_fill)))

        mem_like = ut.lut_mem + ut.lut_srl
        need_slicem = 0 if mem_like == 0 else math.ceil((mem_like / 4.0) / max(1e-6, args.target_fill))

        box = choose_cr_box_from_origin(
            crs=crs,
            xmax=xmax,
            ymax=ymax,
            need_slices=sneed,
            need_slicem=need_slicem,
            origin_x=args.origin_crx,
            origin_y=args.origin_cry,
            target_aspect=args.target_aspect,
            aspect_tol=args.aspect_tol
        )

        pbname = f"pblock_{safe}"
        tcl_all += emit_pblock_tcl(pbname, inst, box)

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text("\n".join(tcl_all), encoding="utf-8")
    print(f"Wrote {args.out}")


if __name__ == "__main__":
    main()
