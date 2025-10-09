#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import argparse, os, re, subprocess, sys
from pathlib import Path

TEMPLATE_BENCH_CORE = r"""
(* keep_hierarchy = "yes" *)
module bench_core__{SAFE} #(
  parameter integer W = 64
)(
  input  logic                 clk,
  input  logic [W-1:0]         src_val,
  input  logic [$clog2(W)-1:0] shamt,
  output logic [W-1:0]         result
);
  import len_table_pkg__{SAFE}::*;

  function automatic logic [W-1:0] rotl(input logic [W-1:0] x, input int s_in);
    int s; logic [W-1:0] r;
    begin s = (W==0)?0:(s_in % W); r = (s==0)? x : ((x<<s)|(x>>(W-s))); return r; end
  endfunction
  function automatic logic [W-1:0] salt(input int idx);
    logic [W-1:0] r; logic [7:0] base; int bytes;
    begin
      base  = 8'hA5 ^ (8'(idx) * 8'h1D);
      r     = '0; bytes=(W+7)/8;
      for (int k=0;k<bytes;k++) r[k*8 +: 8] = base ^ 8'(k);
      return r;
    end
  endfunction

  localparam int SHW = (W>1)?$clog2(W):1;
  wire [SHW-1:0] shamt_harden = shamt ^ src_val[SHW-1:0] ^ {{(SHW-1){1'b0}},1'b1};

  logic [W-1:0] y [N_CASE];
  logic [W-1:0] y_mixed [N_CASE];

  generate
    for (genvar i = 0; i < N_CASE; i++) begin : glen
      localparam int THIS_LEN = LEN_LUT[i];
      localparam bit [THIS_LEN-1:0] THIS_MASK = FF_MASK_LUT[i][THIS_LEN-1:0];
      wire [W-1:0] c_per_case = rotl(src_val, i+1) ^ salt(i);

      localparam bit HAS_MEM_OP_ANY = (MEM_KIND_LUT[i] != '{default: 2'd0});
      localparam bit FORCE_BRAM = (HAS_MEM_OP_ANY && THIS_LEN >= 5);
      wire [W-1:0] rdata_from_bram;

      (* keep_hierarchy = "yes" *)
      uop_block_wrap #(
        .LEN       (THIS_LEN),
        .W         (W),
        .FF_MASK   (THIS_MASK),
        .OPS       (OPS_LUT    [i][0:THIS_LEN-1]),
        .IMM       (IMM_LUT    [i][0:THIS_LEN-1]),
        .USE_IMM   (USE_IMM_LUT[i][0:THIS_LEN-1]),
        .BW_ARR    (BW_LUT     [i][0:THIS_LEN-1]),
        .CONT_ARR  (CONT_W_LUT [i][0:THIS_LEN-1]),
        .HAS_MEM   (HAS_MEM_OP_ANY),
        .MEM_KIND  (MEM_KIND_LUT[i])
      ) core_i (
        .clk    (clk),
        .src_i  (src_val),
        .shamt_i(shamt_harden),
        .c_i    (c_per_case),
        .dst_o  (y[i]),
        .mem_rdata_o(rdata_from_bram)
      );

      logic [W-1:0] y_final;
      if (FORCE_BRAM) begin
        assign y_final = y[i] ^ rdata_from_bram;
      end else begin
        assign y_final = y[i];
      end

      localparam int MIX_SH = (i+1) % W;
      if (MIX_SH == 0) begin
        assign y_mixed[i] = y_final;
      end else begin
        assign y_mixed[i] = (y_final << MIX_SH) | (y_final >> (W - MIX_SH));
      end
    end
  endgenerate

  always_comb begin
    result = '0;
    for (int i=0; i<N_CASE; i++) result ^= y_mixed[i];
  end
endmodule
"""

TEMPLATE_TOP_MULTI = r"""
module top_multi_bench__W{WVAL} #(
  parameter integer W = {WVAL}
)(
  input  logic                 clk,
  input  logic [W-1:0]         src_val,
  input  logic [$clog2(W)-1:0] shamt,
  output logic [W-1:0]         result
);
  {WIRES}

  {INSTANTS}

  always_comb begin
    result = '0;
    {REDUCTION}
  end
endmodule
"""

TEMPLATE_TOP_SINGLE = r"""
module top_bench__{SAFE}__W{WVAL} #(
  parameter integer W = {WVAL}
)(
  input  logic                 clk,
  input  logic [W-1:0]         src_val,
  input  logic [$clog2(W)-1:0] shamt,
  output logic [W-1:0]         result
);
  bench_core__{SAFE} #(.W({WVAL})) u_{SAFE} (.clk(clk), .src_val(src_val), .shamt(shamt), .result(result));
endmodule
"""

def safe_name(s: str) -> str:
  return re.sub(r'[^A-Za-z0-9_]', '_', s)

def rename_package(src: Path, dst: Path, new_pkg: str):
  txt = src.read_text(encoding='utf-8', errors='ignore')
  txt2, n1 = re.subn(r'\bpackage\s+(?:automatic\s+)?len_table_pkg\b', f'package {new_pkg}', txt)
  txt2, n2 = re.subn(r'\bimport\s+len_table_pkg(?:::\*)?\s*;', f'import {new_pkg}::*;', txt2)
  if n1 == 0:
    raise RuntimeError(f"{src} : package len_table_pkg not found")
  dst.write_text(txt2, encoding='utf-8', newline='\n')

def resolve_repo_root() -> Path:
  return Path(__file__).resolve().parents[1]

def resolve_bench_root(args) -> Path:
  if getattr(args, "bench_root", None):
    return Path(args.bench_root).resolve()
  env = os.environ.get("BENCH_ROOT")
  if env:
    return Path(env).resolve()
  return Path(args.ex_dir).resolve()

def find_bench_dir(root: Path, bench: str) -> Path:
  cand = root / bench
  if cand.is_dir(): return cand
  s = safe_name(bench)
  cand = root / s
  if cand.is_dir(): return cand
  cand = root / s.replace('_','.')
  if cand.is_dir(): return cand
  raise FileNotFoundError(f"bench dir not found under {root}: {bench}")

def ensure_len_pkg(bench_dir: Path, tools_dir: Path) -> Path:
  pkg = bench_dir / "len_table_pkg.sv"
  if pkg.exists():
    return pkg
  have_json = (bench_dir / "bench_blocks.json").exists()
  have_blocks = (bench_dir / "blocks").is_dir()
  gen_py = tools_dir / "gen_len_table.py"
  if (have_json or have_blocks) and gen_py.exists():
    cmd = [sys.executable or "python3", str(gen_py), str(bench_dir)]
    subprocess.check_call(cmd, cwd=tools_dir.parent)
    if pkg.exists():
      return pkg
  raise FileNotFoundError(f"{pkg} not found (and cannot generate)")

def list_rtl_files(rtl_root: Path):
  pats = ("*.sv", "*.v", "*.vh", "*.svh")
  files = []
  for p in pats:
    files += [str(x.resolve()) for x in rtl_root.rglob(p)]
  return sorted(set(files))

def main():
  ap = argparse.ArgumentParser("gen_multi_bench_top")
  ap.add_argument("--bench-root", default=None)
  ap.add_argument("--ex-dir", default="example")
  ap.add_argument("--rtl-dir", default="rtl")
  ap.add_argument("--out-dir", default="build/multi_gen")
  ap.add_argument("--widths", nargs='+', type=int, default=[128,256], help="e.g. --widths 128 256")
  ap.add_argument("--benches", nargs='+', required=True)
  args = ap.parse_args()

  repo = resolve_repo_root()
  tools_dir = repo / "tools"
  bench_root = resolve_bench_root(args)
  outdir = (repo / args.out_dir).resolve()
  outdir.mkdir(parents=True, exist_ok=True)

  rtl_dir = (repo / args.rtl_dir).resolve()
  rtl_files = list_rtl_files(rtl_dir)

  safes = [safe_name(b) for b in args.benches]

  for b, s in zip(args.benches, safes):
    bdir = find_bench_dir(bench_root, b)
    src_pkg = ensure_len_pkg(bdir, tools_dir)

    gen_pkg = outdir / f"len_table_pkg__{s}.sv"
    rename_package(src_pkg, gen_pkg, f"len_table_pkg__{s}")

    bench_core = outdir / f"bench_core__{s}.sv"
    bench_core.write_text(TEMPLATE_BENCH_CORE.replace("{SAFE}", s), encoding='utf-8', newline='\n')

  manifests = []
  for W in args.widths:
    wdir = outdir / f"W{W}"
    wdir.mkdir(parents=True, exist_ok=True)

    gen_files = []
    for f in outdir.glob("len_table_pkg__*.sv"): gen_files.append(str(f.resolve()))
    for f in outdir.glob("bench_core__*.sv"):    gen_files.append(str(f.resolve()))

    for s in safes:
      top_single = wdir / f"top_bench__{s}__W{W}.sv"
      top_single.write_text(
        TEMPLATE_TOP_SINGLE.replace("{SAFE}", s).replace("{WVAL}", str(W)),
        encoding='utf-8', newline='\n')
      gen_files.append(str(top_single.resolve()))

    wires = [f"logic [W-1:0] res__{s};" for s in safes]
    insts = [f"bench_core__{s} #(.W({W})) u_{s} (.clk(clk), .src_val(src_val), .shamt(shamt), .result(res__{s}));" for s in safes]
    reds  = [f"result ^= res__{s};" for s in safes]
    top_multi = wdir / f"top_multi_bench__W{W}.sv"
    top_src = (TEMPLATE_TOP_MULTI
               .replace("{WVAL}", str(W))
               .replace("{WIRES}", "\n  ".join(wires))
               .replace("{INSTANTS}", "\n\n  ".join(insts))
               .replace("{REDUCTION}", "\n    ".join(reds)))
    top_multi.write_text(top_src, encoding='utf-8', newline='\n')
    gen_files.append(str(top_multi.resolve()))

    inst_paths = [f"top_multi_bench__W{W}/u_{s}" for s in safes]
    bench_list_path = (wdir / f"bench_instances__W{W}.txt").resolve()
    bench_list_path.write_text("\n".join(inst_paths) + ("\n" if inst_paths else ""), encoding='utf-8', newline='\n')

    mani = wdir / f"manifest__W{W}.tcl"
    mani.write_text(
      "set GEN_FILES {\n" + "\n".join(f"  {p}" for p in gen_files) + "\n}\n" +
      "set RTL_FILES {\n" + "\n".join(f"  {p}" for p in rtl_files) + "\n}\n" +
      ("set BENCH_INSTS {\n" + "\n".join(f"  {p}" for p in inst_paths) + "\n}\n") +
      f"set BENCH_LIST_FILE {bench_list_path}\n" +
      f"set TOP_NAME top_multi_bench__W{W}\n" +
      f"set TOP_WIDTH {W}\n",
      encoding='utf-8', newline='\n'
    )
    manifests.append(str(mani.resolve()))

  runner = outdir / "synth_multi_widths.tcl"
  runner.write_text(f"""# Auto-generated
if {{![info exists ::env(PART)]}} {{
  puts "ERROR: set PART env var, e.g., export PART=xcvu9p-flga2104-2-i"; exit 1
}}
set part $::env(PART)

proc do_synth {{manifest}} {{
  source $manifest
  create_project -in_memory -part $::part
  catch {{read_ip [glob -nocomplain ip/*.xci]}}
  foreach f $RTL_FILES {{ read_verilog -sv $f }}
  foreach f $GEN_FILES {{ read_verilog -sv $f }}
  set_param general.maxThreads 8
  synth_design -top $TOP_NAME -flatten_hierarchy none
  opt_design

  file mkdir reports
  set repdir [file join reports $TOP_NAME]
  file mkdir $repdir
  report_utilization            -file [file join $repdir util.rpt]
  report_utilization -hierarchical -file [file join $repdir util_hier.rpt]
  report_timing_summary         -file [file join $repdir timing.rpt]
  write_checkpoint -force       [file join $repdir post_synth.dcp]
  close_project
}}

foreach m {{"{'" "'.join(manifests)}"}} {{
  puts "==> Synth: $m"
  do_synth $m
}}
puts "Done."
""", encoding='utf-8', newline='\n')

  print("Wrote:")
  for m in manifests: print("  ", m)
  print("Runner   :", runner)

if __name__ == "__main__":
  main()
