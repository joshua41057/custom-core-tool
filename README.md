# Custom-Core Quick Guide
Turn one **“hot-spot” JSON** into a small, variable-length ALU core,
build it in Vivado, and read timing / resource limits in a few minutes

Tested: Vivado 2020.1 ~ 2024.1, Alveo U200 (xcu200-fsgd2104-2-e)

---

## 1. One-shot run
```bash

# 1) JSON → ALU-only
python3 tools/scan_alu_only.py input_original.json [-o examples/alu_only.json] [--min-len N]

# 2) stage / FF estimate  (+ pipe_stages.tcl) -> examples/alu_only_result_*.json
python3 tools/pipeline_staging_estimator.py examples/alu_only.json --emit-tcl

# 3) explode into per-block JSON files -> examples/blocks/
python3 tools/split_block.py examples/alu_only_result_augmented.json

# 4) (optional) pick a subset of blocks  ->  examples/selected_blocks.json
python3 tools/chose_block.py examples/blocks 0 3 5 11

# 5) generate RTL lookup tables  - > rtl/len_table_pkg.sv
python3 tools/gen_len_table.py examples/selected_blocks_result_augmented.json
or
python3 tools/gen_len_table.py examples/blocks

# 6) auto pblock (rows 60, cols 20 → adjust as needed) constraints/auto_pblock.tcl
python3 tools/make_pblock.py 60 20

# 7) build
vivado -mode batch -source run_vivado.tcl | tee build.log
````

After routing:

* `reports/post_route_timing.rpt` – WNS
* `reports/post_route_util.rpt` – LUT / DSP usage
* `reports/post_route_power.rpt` – dynamic + static power

Open the DCP later:

```tcl
vivado -mode tcl
open_checkpoint reports/post_route.dcp
source constraints/speeds.tcl    ;# WNS → Fmax per pblock
source constraints/usage.tcl     ;# CLB / DSP %
quit
```

---

## 2. Repo map

```
rtl/            hand-written core (SystemVerilog)
tools/          Python generators (stdlib only)
constraints/    clocks.xdc + *.tcl  (many auto-made)
examples/       sample JSON + derived files
run_vivado.tcl  batch build
reports/        filled after a run
```

Auto-generated files

| path                          | produced by                           |
| ----------------------------- | ------------------------------------- |
| `rtl/len_table_pkg.sv`        | `tools/gen_len_table.py`              |
| `constraints/pipe_stages.tcl` | `tools/pipeline_staging_estimator.py` |
| `constraints/auto_pblock.tcl` | `tools/make_pblock.py`                |

---

## 3. Customising

* **Different board** – change `PART` in `run_vivado.tcl`
  and edit column lists in `tools/make_pblock.py`.
* **Clock period** – `constraints/clocks.xdc` (300 MHz default).
* **Pblock size** – rerun `tools/make_pblock.py rows cols`.

---

