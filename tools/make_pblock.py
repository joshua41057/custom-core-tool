#!/usr/bin/env python3
"""
make_pblock.py  ROWS COLS
───────────────────────────────────────────────────────────────
Generate constraints/auto_pblock.tcl that
 - creates (if missing) a single Pblock 'pblock_1'
 - locks all custom-core blocks   (glen[*].blk_i)
 - limits the area to Slice / DSP only
  up to 120 Slice rows (two clock regions)
  selectable Slice columns (max 22 in this table)
"""

import argparse, sys, textwrap
from pathlib import Path
from math import ceil

# -------- column tables in CLOCKREGION_X1Y14 + CLOCKREGION_X1Y13 --------------------
# Columns (left → right, high col numbers are left-most)
SLICE_COLS = (  # 22 Slice columns, expand if needed
    list(range(54, 47, -1)) + list(range(46, 33, -1)) + list(range(32, 30, -1))
)
DSP_COLS_ALL = [7, 6, 5]  # 3 DSP columns aligned with the Slice range

# -------- row constants -------------------------------------------------
Y_S_HI, ROW_SLICE = 899, 60  # top CR, rows per CR
Y_D_HI, ROW_DSP = 359, 24  # DSP rows per CR
ROW_SLICE_MAX = ROW_SLICE * 2  # allow two CRs (120 rows)

# -------- other constants ----------------------------------------------
CELL_GLOB = "glen[*].blk_i"  # cells to lock
PBLOCK_ID = "pblock_1"  # single pblock name used everywhere


# -----------------------------------------------------------------------
def build(rows: int, cols: int) -> None:
    """emit auto_pblock.tcl for the requested rows × cols rectangle"""

    # ---- Slice rectangle ------------------------------------------------
    x_lo, x_hi = SLICE_COLS[cols - 1], SLICE_COLS[0]
    y_lo = Y_S_HI - rows + 1
    slice_rect = f"SLICE_X{x_lo}Y{y_lo}:SLICE_X{x_hi}Y{Y_S_HI}"

    # ---- DSP rectangle --------------------------------------------------
    dsp_rows = ceil(rows * ROW_DSP / ROW_SLICE)  # 60→24,120→48

    max_cols_per_dsp = len(SLICE_COLS) / len(DSP_COLS_ALL)
    keep_cnt = ceil(cols / max_cols_per_dsp)
    dsp_cols = DSP_COLS_ALL[-keep_cnt:]
    dx_lo, dx_hi = dsp_cols[-1], dsp_cols[0]
    y_d_lo = Y_D_HI - dsp_rows + 1
    dsp_rect = f"DSP48E2_X{dx_lo}Y{y_d_lo}:DSP48E2_X{dx_hi}Y{Y_D_HI}"
    dsp_cnt = dsp_rows * len(dsp_cols)

    # ---- TCL output -----------------------------------------------------
    auto_tcl = textwrap.dedent(
        f"""\
        # auto_pblock.tcl (generated)
        if {{![llength [get_pblocks {PBLOCK_ID}]]}} {{
            create_pblock {PBLOCK_ID}
        }}
        resize_pblock [get_pblocks {PBLOCK_ID}] -add {{{slice_rect}}}
        resize_pblock [get_pblocks {PBLOCK_ID}] -add {{{dsp_rect}}}

        set inst [get_cells -hier -filter {{NAME =~ "{CELL_GLOB}"}}]
        foreach pb [get_pblocks -of_objects $inst] {{
            remove_cells_from_pblock $pb $inst
        }}
        add_cells_to_pblock [get_pblocks {PBLOCK_ID}] $inst -clear_locs
        set_property CONTAIN_ROUTING true [get_pblocks {PBLOCK_ID}]
    """
    )

    out = Path(__file__).resolve().parents[1] / "constraints" / "auto_pblock.tcl"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(auto_tcl, "utf-8")

    # ---- console summary ------------------------------------------------
    slice_cnt = rows * cols
    print("✓ auto_pblock.tcl written")
    print(f"  Slice rect : {slice_rect}  (Slices {slice_cnt})")
    print(f"  DSP   rect : {dsp_rect}    (DSPs  {dsp_cnt})")


# -----------------------------------------------------------------------
if __name__ == "__main__":
    pa = argparse.ArgumentParser()
    pa.add_argument("rows", type=int, help="Slice rows   (1–120)")
    pa.add_argument("cols", type=int, help="Slice columns(1–22)")
    args = pa.parse_args()

    if not (1 <= args.rows <= ROW_SLICE_MAX):
        sys.exit(f"rows must be 1‥{ROW_SLICE_MAX}")
    if not (1 <= args.cols <= len(SLICE_COLS)):
        sys.exit(f"cols must be 1‥{len(SLICE_COLS)}")

    build(args.rows, args.cols)
