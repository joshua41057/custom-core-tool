import pandas as pd, json, glob, pathlib, re

CPU_FREQ_GHZ = {
    "atom_d510"  : 1.67,
    "atom_c2750" : 2.40,
    "atom_e3845" : 1.91,
    "i7_4770k"   : 3.50,
    "gainestown" : 2.80,
}

CLB_BOARD = 147_780
DSP_BOARD =   6_840
CLB_DENS  =     320          # CLB/mm2 (board density)

sim_db = {}

for csv in glob.glob("sim_results_*.csv"):
    env = re.search(r"sim_results_(.+)\.csv", csv).group(1)
    cpu_f = CPU_FREQ_GHZ.get(env)
    if cpu_f is None:
        print(f"[!] CPU freq for env <{env}> unknown — skip")
        continue

    num_cols = [
        "cpu_only_cycles",
        "fpga_custom_cycles",
        "cpu_only_ipc",
        "fpga_custom_ipc",
    ]

    df = (
        pd.read_csv(csv, skip_blank_lines=True)
          .dropna(subset=["benchmark"])
    )

    if "cycle_reduction_%" in df.columns:
        cr = pd.to_numeric(df["cycle_reduction_%"], errors="coerce").fillna(0.0)
        df = df[cr.ne(0.0)]

    df[num_cols] = df[num_cols].apply(pd.to_numeric, errors="coerce")
    df = df.dropna(subset=num_cols)

    for bench in df["benchmark"].unique():
        sub = df[df["benchmark"] == bench]
        sim_db[(env, bench)] = {
            "cpu_cycles": int(sub["cpu_only_cycles"].sum()),
            "fpga_cycles": int(sub["fpga_custom_cycles"].sum()),
            "ipc_cpu": sub["cpu_only_ipc"].mean(),
            "ipc_fpga": sub["fpga_custom_ipc"].mean(),
            "cpu_freq": cpu_f * 1e9,          # Hz
        }

rows = []

for js in glob.glob("**/impl_summary_*.json", recursive=True):
    bench = pathlib.Path(js).parent.name
    with open(js) as f:
        meta = json.load(f)[0]

    depths       = list(map(int, meta["stage_count"].split('+')))
    num_blocks   = len(depths)
    avg_depth    = sum(depths) / num_blocks
    total_depth  = sum(depths)

    env_hits = [k[0] for k in sim_db if k[1] == bench]
    if not env_hits:
        print(f"[!] sim CSV, {bench} 없음 — skip")
        continue

    for env in env_hits:
        sim = sim_db[(env, bench)]

        delta_cycles = sim["cpu_cycles"] - sim["fpga_cycles"]
        delta_pct    = delta_cycles / sim["cpu_cycles"] * 100.0

        saved_cpu_ns = delta_cycles / sim["cpu_freq"] * 1e9
        fpga_hz      = meta["fmax_mhz"] * 1e6
        fpga_time_ns = delta_cycles / fpga_hz * 1e9

        area_mm2 = meta["pblock_clb_used"] / CLB_DENS

        rows.append(dict(
            env               = env,
            benchmark         = bench,
            cpu_cycles        = sim["cpu_cycles"],
            fpga_cycles       = sim["fpga_cycles"],
            delta_cycles      = delta_cycles,
            delta_cycle_pct   = round(delta_pct, 3),
            saved_cpu_ns      = round(saved_cpu_ns, 2),
            fpga_time_ns      = round(fpga_time_ns, 2),
            f_fpga_mhz        = meta["fmax_mhz"],
            num_blocks        = num_blocks,
            avg_depth         = round(avg_depth, 2),
            total_depth       = total_depth,
            clb_used          = meta["pblock_clb_used"],
            dsp_used          = meta["pblock_dsp_used"],
            clb_pct_board     = round(meta["pblock_clb_used"] / CLB_BOARD * 100, 3),
            dsp_pct_board     = round(meta["pblock_dsp_used"] / DSP_BOARD * 100, 3),
            area_mm2          = round(area_mm2, 3),
            total_W           = meta["total_on_chip_power_w"],
            dyn_W             = meta["dynamic_power_w"],
            W_per_mm2         = round(meta["total_on_chip_power_w"] / area_mm2, 3) if area_mm2 else None,
            stage_count_raw   = meta["stage_count"],
        ))

out = pd.DataFrame(rows)
out.to_csv("ppa_master.csv", index=False)
print(f"Done. ppa_master.csv ({len(out)} rows) complete.")
