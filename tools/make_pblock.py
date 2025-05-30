#!/usr/bin/env python3

import argparse, sys, textwrap
from pathlib import Path
from math import ceil

# CLOCKREGION_X1Y14
SLICE_COLS = (
    list(range(54, 47, -1)) +
    list(range(46, 33, -1)) +
    list(range(32, 30, -1))
)                               # 22 cols
DSP_COLS_ALL = [7, 6, 5]        # 3 cols

Y_S_HI, ROW_SLICE = 899, 60
Y_D_HI, ROW_DSP   = 359, 24
CELL_NAME = "glen[0].blk_i"
PBLOCK_ID = "pblock_1"

def build(rows:int, cols:int):
    x_lo, x_hi = SLICE_COLS[cols-1], SLICE_COLS[0]
    y_lo       = Y_S_HI - rows + 1
    slice_rect = f"SLICE_X{x_lo}Y{y_lo}:SLICE_X{x_hi}Y{Y_S_HI}"

    slice_cnt  = rows * cols
    dsp_need   = ceil(slice_cnt / 120)
    dsp_rows   = ceil(rows * ROW_DSP / ROW_SLICE)
    dsp_cols   = DSP_COLS_ALL[:ceil(dsp_need / dsp_rows)]
    dx_lo, dx_hi = dsp_cols[-1], dsp_cols[0]
    y_d_lo     = Y_D_HI - dsp_rows + 1
    dsp_rect   = f"DSP48E2_X{dx_lo}Y{y_d_lo}:DSP48E2_X{dx_hi}Y{Y_D_HI}"

    auto_tcl = textwrap.dedent(f"""\
        # auto_pblock.tcl (generated)
        resize_pblock [get_pblocks {PBLOCK_ID}] -add {{{slice_rect}}}
        resize_pblock [get_pblocks {PBLOCK_ID}] -add {{{dsp_rect}}}

        set inst [get_cells -hier {{{CELL_NAME}}}]
        foreach pb [get_pblocks -of_objects $inst] {{ remove_cells_from_pblock $pb $inst }}
        add_cells_to_pblock [get_pblocks {PBLOCK_ID}] $inst -clear_locs
    """)
    Path("auto_pblock.tcl").write_text(auto_tcl, "utf-8")

    dsp_cnt = dsp_rows * len(dsp_cols)
    print("✓ auto_pblock.tcl")
    print(f"  Slice rect : {slice_rect} (Slice {slice_cnt})")
    print(f"  DSP   rect : {dsp_rect} (DSP {dsp_cnt})")


if __name__ == "__main__":
    pa = argparse.ArgumentParser()
    pa.add_argument("rows", type=int)
    pa.add_argument("cols", type=int)
    args = pa.parse_args()

    if not (1 <= args.rows <= ROW_SLICE):
        sys.exit(f"rows must be 1‥{ROW_SLICE}")
    if not (1 <= args.cols <= len(SLICE_COLS)):
        sys.exit(f"cols must be 1‥{len(SLICE_COLS)}")

    build(args.rows, args.cols)