#!/usr/bin/env python3
"""
pipeline_staging_estimator.py  fully_alu.json [-o result] [--max-comb 4] [--emit_tcl]
"""
from __future__ import annotations
import argparse, csv, json, re
from math import ceil
from pathlib import Path
from typing import Dict, List, Tuple

# ─────────────── base latency table  ───────────────
BASE_LAT: Dict[str, int] = {
    "ADD": 1, "SUB": 1, "SBB": 2, "INC": 1, "DEC": 1, "CMP": 1, "NEG": 1,
    "AND": 1, "OR": 1, "XOR": 1, "NOT": 1, "TEST": 1,
    "SHL": 2, "SAL": 2, "SHR": 2, "SAR": 2, "ROL": 2, "ROR": 2,
    "RCL": 2, "RCR": 2, "SHLD": 3, "SHRD": 3,
    "MUL": 2, "IMUL": 2, "DIV": 4, "IDIV": 4,
}

# ─────────────── flag read/write sets ───────────────
FLAG_WR = {"ADD", "SUB", "SBB", "INC", "DEC", "CMP", "NEG",
           "AND", "OR", "XOR", "TEST",
           "SHL", "SAL", "SHR", "SAR", "ROL", "ROR", "RCL", "RCR", "SHLD", "SHRD"}
FLAG_RD = FLAG_WR | {"SBB", "ADC", "RCL", "RCR"}

# ────────────────── helper functions ──────────────────
def bitwidth(tokens: list[str]) -> int:
    """extract widest bit-width from operand tokens; default 32"""
    bw = 32
    for t in tokens:
        m = re.search(r'(\d+)', t)
        if m:
            bw = max(bw, int(m.group(1)))
        elif t.lower().startswith(("xmm", "ymm", "zmm")):
            bw = max(bw, 128)             # SSE/AVX
    return bw

def latency(op: str, bw: int) -> int:
    """width-aware latency"""
    opu = op.upper()
    base = BASE_LAT.get(opu, 1)
    if opu in {"ADD", "SUB", "AND", "OR", "XOR"} and bw > 64:
        base += 1                         # extra LUT delay
    if opu in {"MUL", "IMUL"} and bw > 32:
        base += 1                         # wider DSP cascade
    if opu in {"DIV", "IDIV"} and bw > 32:
        base += 2
    return base

def dsp_need(op: str, bw: int) -> int:
    """rough DSP usage estimation"""
    opu = op.upper()
    if opu in {"MUL", "IMUL"} and bw > 18:
        return 1
    if opu in {"ADD", "SUB"} and bw > 48:
        return 1
    return 0

def writes_flag(op: str) -> bool: return op.upper() in FLAG_WR
def reads_flag(op: str)  -> bool: return op.upper() in FLAG_RD

# ─────────────── dependency graph builder ───────────────
def build_edges(uops: list[dict]) -> list[dict]:
    """construct full RAW/WAR/WAW + flag dependencies"""
    edges: list[dict] = []
    last_writer: dict[str, int] = {}
    for i, u in enumerate(uops):
        dsts = set(u.get("out_operands", []))
        srcs = set(u.get("in_operands",  []))

        # RAW
        for op in srcs:
            if op in last_writer:
                edges.append({"from": {"instr_index": last_writer[op]},
                              "to":   {"instr_index": i}})
        # WAW / WAR
        for op in dsts:
            if op in last_writer:
                edges.append({"from": {"instr_index": last_writer[op]},
                              "to":   {"instr_index": i}, "output": True})
            last_writer[op] = i

    # flag chain
    flag_src = None
    for i, u in enumerate(uops):
        if writes_flag(u["opcode"]):
            flag_src = i
        if reads_flag(u["opcode"]) and flag_src is not None and flag_src != i:
            edges.append({"from": {"instr_index": flag_src},
                          "to":   {"instr_index": i}, "flag": True})
    return edges

# ─────────────── main analysis ───────────────
def analyse(g: dict, max_comb: int = 4
            ) -> tuple[int, int, list[int], int]:
    uops = g["instructions"]
    edges = g.get("merge_edges", []) + build_edges(uops)
    N = len(uops)

    # per-uop latency / dsp / width
    bw   = [bitwidth(u.get("raw_operands", []))       for u in uops]
    lats = [latency(u["opcode"], w)                   for u, w in zip(uops, bw)]
    dsp  = [dsp_need(u["opcode"], w)                  for u, w in zip(uops, bw)]

    # quick adjacency list
    preds: list[list[int]] = [[] for _ in range(N)]
    for e in edges:
        preds[e["to"]["instr_index"]].append(e["from"]["instr_index"])

    stage_end: List[int] = []
    ff_pos:     List[int] = []
    cur_cycle = 0
    comb_depth = 0

    for i in range(N):
        # ---- dependency stall ----
        stall = 0
        for p in preds[i]:
            gap = i - p
            need = lats[p]
            if gap < need:
                stall = max(stall, need - gap)
        if stall:
            cur_cycle += stall
            ff_pos.append(i - 1)
            stage_end.append(cur_cycle)
            comb_depth = 0                    # new stage

        # ---- comb-depth limit ----
        if comb_depth and comb_depth + lats[i] > max_comb:
            ff_pos.append(i - 1)
            stage_end.append(cur_cycle)
            comb_depth = 0

        # ---- advance cycle ----
        cur_cycle += lats[i]
        comb_depth += lats[i]

    stage_end.append(cur_cycle)               # last stage
    depth  = cur_cycle
    stages = len(stage_end)
    dsp_sum = sum(dsp)
    return depth, stages, ff_pos, dsp_sum

# ─────────────── entry point ───────────────
def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("input_json")
    ap.add_argument("-o", "--out", default="result")
    ap.add_argument("--max-comb", type=int, default=4)
    ap.add_argument("--emit_tcl", action="store_true")
    args = ap.parse_args()

    groups = json.loads(Path(args.input_json).read_text())
    rows: List[Tuple] = []

    for g in groups:
        depth, stg, ffs, dsp_cnt = analyse(g, args.max_comb)
        g.update({"latency_cycles": depth,
                  "stage_count":    stg,
                  "ff_boundaries":  ffs,
                  "dsp_usage":      dsp_cnt})
        rows.append((g.get("rank", -1), g.get("execution_count", 0),
                     depth, stg, len(ffs), dsp_cnt))
        print(f"[rank={g['rank']}] Lat={depth} cyc  stage={stg}  FFs={ffs}")

    # augmented JSON / summary CSV
    Path(f"{args.out}_augmented.json").write_text(json.dumps(groups, indent=2))
    with Path(f"{args.out}_summary.csv").open("w", newline="") as f:
        csv.writer(f).writerows(
            [("rank", "exec_cnt", "lat", "stages", "n_ff", "DSP")] + rows)

    # optional Vivado TCL
    if args.emit_tcl:
        with Path(f"{args.out}_vivado.tcl").open("w") as t:
            for r in rows:
                rank, _, _, stg, _, _ = r
                t.write(
                    f"set_property PIPE_STAGES {stg} "
                    f"[get_cells glen[{rank-1}].blk_i]\n")

if __name__ == "__main__":
    main()
