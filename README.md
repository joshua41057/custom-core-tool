# Custom-Core Quick Guide

Turn one **“hot-spot” JSON** into a small, variable-length ALU core,
build it in Vivado, and read timing / resource limits in a few minutes

Tested: Vivado 2020.1 \~ 2024.1, Alveo U200 (xcu200-fsgd2104-2-e)

---

## 1. One-shot run

```bash
# 1) JSON -> ALU-only
python3 tools/scan_alu_only.py input_original.json -o examples/alu_only.json --min-len 2

# 2) stage / FF estimate (+ per-group timing meta) -> examples/alu_only_result_*.json
python3 tools/pipeline_staging_estimator.py examples/alu_only.json --emit-tcl

# 3) split by benchmark  ->  example/<bench>/bench_blocks.json
python3 tools/split_bench.py examples/alu_only_result_augmented.json example

# 4) (optional) explode into per-block JSON files  ->  example/<bench>/blocks/*.json
python3 tools/split_block.py example

# 5) generate per-benchmark RTL lookup tables (+ pipe_stages.tcl)
#    all benches under example/
python3 tools/gen_len_table.py example
#    or a single bench
# python3 tools/gen_len_table.py example/527.cam4_r

# 6) build (multi-benchmark, auto pblock *after synthesis*)
#    a) run all benches found under example/
vivado -mode batch -source run_vivado_batch.tcl
#    b) or pick specific benches (8~10 recommended)
vivado -mode batch -source run_vivado_batch.tcl -tclargs 527.cam4_r 525.x264_r 521.wrf_r 523.xalancbmk_r

#    knobs (env):
#      NPBLOCKS     - number of pblocks per compile (default 8)
#      TARGET_FILL  - target fill inside each pblock (default 0.80)
#      PART         - FPGA part (default xcu200-fsgd2104-2-e)
#    example:
# NPBLOCKS=10 TARGET_FILL=0.75 PART=xcu200-fsgd2104-2-e vivado -mode batch -source run_vivado_batch.tcl -tclargs 527.cam4_r

# 7) summary -> reports/all_runs.csv (appended per bench)
```

After routing:

* `reports/<bench>/post_route_timing.rpt` – WNS
* `reports/<bench>/post_route_util.rpt` – LUT / DSP usage
* `reports/<bench>/post_route_power.rpt` – dynamic + static power
* `reports/<bench>/utilization_pblock_*.rpt` – per-pblock CLB/DSP usage
* `reports/<bench>/auto_pblock.tcl` – pblocks generated from post-synth utilization
* `reports/all_runs.csv` – bench, WNS, TNS, Fmax, Dynamic\_W

Open the DCP later:

```tcl
vivado -mode tcl
open_checkpoint reports/<bench>/post_route.dcp
source constraints/speeds.tcl    ;# WNS -> Fmax per pblock
source constraints/usage.tcl     ;# CLB / DSP %
quit
```

---

## 2. Repo map

```
rtl/            hand-written core (SystemVerilog)
tools/          Python generators (stdlib only)
constraints/    clocks.xdc, grid_ranges.txt, helper *.tcl
example/<bench>/  bench input + per-bench SV/TCL
run_vivado_batch.tcl  multi-benchmark batch build (auto pblock)
run_vivado.tcl        legacy single-run flow
reports/        per-bench outputs + all_runs.csv
```

Auto-generated files

| path                                       | produced by                                                   |
| ------------------------------------------ | ------------------------------------------------------------- |
| `example/<bench>/len_table_pkg.sv`         | `tools/gen_len_table.py`                                      |
| `example/<bench>/pipe_stages.tcl`          | `tools/gen_len_table.py`                                      |
| `reports/<bench>/post_synth_util_hier.rpt` | Vivado `report_utilization -hierarchical`                     |
| `reports/<bench>/auto_pblock.tcl`          | `tools/auto_pblock_gen.py` (called by `run_vivado_batch.tcl`) |

---

## 3. Customising

* **Different board** – set env `PART` or edit it in `run_vivado_batch.tcl`.
  Provide correct device ranges in `constraints/grid_ranges.txt`.
* **Clock period** – `constraints/clocks.xdc` (300 MHz default).
* **Pblock policy** – set env `NPBLOCKS` (e.g. 8–10) and `TARGET_FILL` (e.g. 0.75–0.85).
  Pblocks are created **after synthesis** from actual utilization; no need to pre-size.
* **Legacy single run** – if you prefer the old single-bench flow, keep `run_vivado.tcl`.
  (The new flow supersedes `make_pblock.py` for most cases.)

---
