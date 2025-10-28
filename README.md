# FPGA Offload for Hot x86 Blocks

Goal:  
Take the hottest compute regions from SPEC CPU2017 (already profiled on x86), map them to FPGA pipelines on an Alveo U200, floorplan/place/route them in Vivado, and report timing / area / power.

This repo is the backend (FPGA side).  
We assume you already ran the frontend CPU profiling and you have per-benchmark captured regions.

We do not rerun SPEC or pin here.


## Input we start from

You should have something like:

```

profiles_root/
500.perlbench_r/
region_000/
super_hot_regions.json
region_001/
super_hot_regions.json
...
602.gcc_s/
region_000/
super_hot_regions.json
...

````

Each `super_hot_regions.json` lists "super hot" straight-line regions (basically merged basic blocks / tight compute windows) that actually dominated runtime in that benchmark+region.

We will scan all of these and treat them as offload candidates for FPGA.

You do NOT need to manually merge them into one file. Our scripts will walk the tree, collect all candidate blocks, and then clean/schedule them.


## High level flow

1. Filter
   - keep only FPGA friendly ALU code (no branches, calls, syscalls, crazy mem modes, etc)
   - optionally drop div and wide SIMD
   - result is a clean set of offloadable basic blocks

2. Pipeline schedule
   - assign every uop in each block to pipeline stages under II=1
   - respect resource budget per stage and mem issue limits
   - compute stage_count (FPGA latency in cycles)

3. Area budget
   - choose which blocks fit about 0.5%, 1.0%, 2.0%, 3.0% of U200 CLBs
   - emit `len_table_pkg_*.sv` for each budget

4. Vivado
   - auto-generate a pblock floorplan for each benchmark subset
   - synth/place/route (Alveo U200)
   - dump timing, util, power

5. Summaries
   - write CSVs you can cite in the paper or feed to a CPU+FPGA performance model


No Makefile. You just run the python scripts and the provided tcl.


## Repo layout (only the pieces that the evaluator will touch)

### tools/

- `scan_alu_only.py`  
  Walks the profiling output tree (all benchmarks, all regions), reads every `super_hot_regions.json`, and collects the hot straight-line blocks.  
  Filters out anything that we do not offload (branches, weird control flow, etc). Also can remove div and wide SIMD for the main configs.  
  Writes cleaned aggregate json files like:
  - `alu.base.json`
  - `alu.no_div.json`
  - `alu.no_div_no_simd.json`
  plus some stats jsons.

- `pipeline_staging_estimator.py`  
  FPGA pipeline scheduler / cost model.  
  Takes the cleaned json, assigns each instruction to a pipeline stage, enforces II=1 (initiation interval 1), enforces per-stage resource and mem port budget assuming ~300 to 350 MHz on U200.  
  Writes:
  - `staged_augmented.json` (per block: stage_count, which stage each uop sits in, where flops go, mem hazard info)
  - `staged_summary.csv`
  - `staged_sniper.csv`

- `split_bench.py`  
  Split the staged result into per benchmark folders.  
  After this you get one dir per SPEC benchmark, each with `bench_blocks.json`.

- `gen_len_table_multi_limit.py`  
  For each benchmark dir:
  - estimate cost per block
  - greedily select subsets that fit about 0.5%, 1.0%, 2.0%, 3.0% of the U200 fabric
  - emit `len_table_pkg_0p5pct.sv`, `len_table_pkg_1p0pct.sv`, `len_table_pkg_2p0pct.sv`, `len_table_pkg_3p0pct.sv`

  At the root it also emits global merged CSV/json like:
  - `subset_0p5pct_sniper.csv`
  - `subset_0p5pct_augmented.json`
  (and same for 1p0pct, 2p0pct, 3p0pct)

  The `_sniper.csv` form is what we feed into the CPU+FPGA simulator. It is basically [bench, pc/src, latency_cycles]. latency_cycles here is that block's pipeline depth (stage_count).

- `gen_len_table.py`  
  Single bench single set version (no 0p5/1p0/2p0/3p0 slicing). Only needed if you want the "full" design, not the budgeted subsets.

- `clock_rate_to_fpga.py`  
  Optional. Takes something like `subset_0p5pct_sniper.csv` and rescales the reported FPGA latency to match different host CPU clocks. Good for comparing "FPGA block cycles @350 MHz" vs "cycles on Atom, Xeon, etc".

- `auto_pblock_gen.py`  
  Generate a Vivado pblock (rectangular floorplan region) for each benchmark, sized using coarse resource regions of U200. Uses `constraints/u200_cr_summary.csv` and `constraints/u200_cr_coords.csv`.

- `collect_strict_synth_summary.py`  
  Parse synth only reports (pre place/route) and dump a CSV summary with rough Fmax and CLB usage.

- `collect_results.py`  
  Parse post route reports and dump final CSV with WNS, Fmax, CLB/DSP/BRAM, dynamic power.

- `gen_multi_bench_top.py`  
  Helper to build the RTL top that instantiates all chosen blocks.

- `opcodes.py`  
  Opcode -> enum mapping used in generated packages.

### rtl/

- `top_multi_len.sv` and other RTL (`uop_pkg.sv`, etc)
- `len_table_pkg_*.sv` will be generated per benchmark budget and is not checked in

### constraints/

- `clocks.xdc`  
  Clock constraint (~300 MHz target in Vivado; internal model is ~350 MHz)
- `u200_cr_summary.csv`, `u200_cr_coords.csv`  
  Coarse region layout of the Alveo U200 (device xcu200-fsgd2104-2-e). Used to size the pblock.

### run_vivado.tcl

Batch Vivado script that:
1. reads RTL and the correct `len_table_pkg_*.sv`
2. does synth_design on top module
3. calls `auto_pblock_gen.py` to create a pblock for that benchmark
4. place_design and route_design inside that pblock
5. dumps timing/util/power reports into `reports/`

### reports/

Gets filled after you run Vivado.  
Will contain:
- per bench synth reports under `reports/<EXP>/benches/<bench_safe>/`
- per bench routed reports under `reports/<EXP>/single/<bench_safe>/`
- csv summaries like `summary_pnr_results.csv`
- also global workload csvs like `subset_0p5pct_sniper.csv`


## Step by step (what you actually run)

There is no Makefile. Just follow these steps in order.

(0) define where the profiling output lives

This is the directory that has one subdir per SPEC benchmark, and inside that, one subdir per captured hot region, each having a `super_hot_regions.json`.

Example:
```bash
export REGIONS_ROOT=/path/to/profiles_root
# profiles_root/500.perlbench_r/region_000/super_hot_regions.json
# profiles_root/500.perlbench_r/region_001/super_hot_regions.json
# profiles_root/602.gcc_s/region_000/super_hot_regions.json
# ...
````

1. Filter and schedule

1a. legality / ALU only filter

```bash
python3 tools/scan_alu_only.py $REGIONS_ROOT -o alu --reject
```

This walks all benchmarks and all regions under `$REGIONS_ROOT`, reads every `super_hot_regions.json`, throws away stuff we cannot offload (branches, calls, returns, syscalls, insane mem modes, etc), and writes:

* `alu.base.json`
* `alu.no_div.json`
* `alu.no_div_no_simd.json`
* plus some stats jsons

For the paper we mainly use `alu.no_div.json` (or for stricter config `alu.no_div_no_simd.json`).

1b. pipeline staging and timing model

```bash
python3 tools/pipeline_staging_estimator.py alu.no_div.json -o staged --trace
```

This writes:

* `staged_augmented.json`
* `staged_summary.csv`
* `staged_sniper.csv`

In `staged_augmented.json`, for each block we record:

* `stage_count` = pipeline depth in FPGA cycles at II=1
* flop cut points
* memory issue usage per stage
* dep edges we needed to respect (RAW/WAR/WAW etc)

This `stage_count` is what we treat as latency_cycles inside the simulator.

2. Split per benchmark and generate per budget RTL packages

```bash
# make per benchmark dirs
python3 tools/split_bench.py staged_augmented.json work/by_bench

# build len_table_pkg_*.sv for different FPGA area budgets
python3 tools/gen_len_table_multi_limit.py work/by_bench
```

After this:

Per benchmark (ex 500.perlbench_r, 602.gcc_s, ...):

* `len_table_pkg_0p5pct.sv`
* `len_table_pkg_1p0pct.sv`
* `len_table_pkg_2p0pct.sv`
* `len_table_pkg_3p0pct.sv`

Each of those is the subset of blocks that fits about that percent of U200 CLBs.
If the benchmark is tiny, some of those will be identical.

At the root `work/by_bench/`:

* `subset_0p5pct_sniper.csv`
* `subset_0p5pct_augmented.json`
  (and same for 1p0pct / 2p0pct / 3p0pct)

`subset_0p5pct_sniper.csv` is the workload CSV we hand to the CPU+FPGA simulator. Each row is basically [bench, src/pc, latency_cycles] where latency_cycles = stage_count for that block (first row per block stores it).

Optional: frequency scaling

```bash
python3 tools/clock_rate_to_fpga.py work/by_bench/subset_0p5pct_sniper.csv
```

This will write `subset_0p5pct_sniper_scaled_<CPU>.csv` etc.
Only the latency column changes. It scales 350 MHz FPGA cycles into cycles at some specific CPU clock.

3. Vivado (PnR on Alveo U200)

We now actually synth/place/route the subsets on a real U200 floorplan.

Assume:

* FPGA device is `xcu200-fsgd2104-2-e` (Alveo U200)
* `vivado` is on PATH
* clocks.xdc targets about 300 MHz
* each benchmark gets a pblock (auto sized rectangle on the device)

```bash
export BENCH_ROOT=work/by_bench   # the dirs created by split_bench.py
vivado -mode batch -source run_vivado.tcl -- \
    -exp synth_0p5pct \
    -limit 0p5pct \
    -stage all
```

Explanation:

* `-limit 0p5pct` selects `len_table_pkg_0p5pct.sv` in each benchmark dir
  You can also pass `1p0pct`, `2p0pct`, `3p0pct`.
  If you used the single bench path and `gen_len_table.py`, you can also say `full` to just use `len_table_pkg.sv`.
* `-exp synth_0p5pct` means reports will go under `reports/synth_0p5pct/`
* `-stage all` means do synth then impl (place/route). You can also do `-stage synth` or `-stage impl`.

What run_vivado.tcl will do per benchmark:

1. read RTL/ and the chosen `len_table_pkg_*.sv`
2. apply `constraints/clocks.xdc`
3. synth_design top module (`top_multi_len`)

   * dumps `pre_impl_util.rpt`, `pre_impl_timing.rpt`
   * writes a synth checkpoint
4. call `auto_pblock_gen.py` to pick a coarse rectangular region on U200 using `u200_cr_summary.csv` and `u200_cr_coords.csv`
5. place_design and route_design inside that pblock

   * dumps `post_route_timing.rpt`, `pblock_util.rpt`, `post_route_power.rpt`

Output will look like:

* `reports/synth_0p5pct/benches/<bench_safe>/pre_impl_*.rpt`
* `reports/synth_0p5pct/single/<bench_safe>/post_route_*.rpt`

4. Collect final CSV summaries

Synth only summary (pre place/route sanity):

```bash
python3 tools/collect_strict_synth_summary.py \
  --bench-root work/by_bench \
  --reports-root reports \
  --out reports/synth_0p5pct_synth_summary.csv
```

This scans `reports/synth_0p5pct/benches/*/pre_impl_*.rpt` and writes one row per benchmark with:

* benchmark name
* CLB_Used estimate from synth
* Fmax_MHz estimate from pre_impl_timing.rpt (rough)

Post route summary (this is the final table we actually cite):

```bash
python3 tools/collect_results.py \
  --dir reports/synth_0p5pct
```

This scans `reports/synth_0p5pct/single/*/` and writes `summary_pnr_results.csv` with:

* Benchmark
* WNS_ns
* Fmax_MHz (derived from WNS and target period)
* CLB_Used / DSP_Used / BRAM_Used (from pblock_util.rpt)
* Dynamic_Power_W (from post_route_power.rpt)

These CSVs are the artifact deliverables.

## What numbers matter

* `stage_count` in `staged_augmented.json`
  pipeline depth (latency in FPGA cycles) for that offloaded block, assuming II=1

* `subset_0p5pct_sniper.csv` (and 1p0pct / 2p0pct / 3p0pct)
  which blocks we actually keep for that FPGA budget and what latency_cycles they have.
  This is what we plug into the CPU+FPGA simulator

* `synth_0p5pct_synth_summary.csv`
  quick sanity after synth (can we theoretically get ~300 MHz, how many CLBs, before route)

* `summary_pnr_results.csv`
  final post-route timing (Fmax via WNS), resource usage (CLB / DSP / BRAM), and dynamic power in Watts.
  This is the real hardware cost and speed number

