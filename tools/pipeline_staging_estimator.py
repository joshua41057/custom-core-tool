#!/usr/bin/env python3
"""
python tools/pipeline_staging_estimator.py examples/alu_only.json -o examples/result --emit_tcl --tcl-dir constraints
"""

from __future__ import annotations
import argparse, csv, json, re, sys
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from collections import deque
from dataclasses import dataclass
from statistics import pstdev


# base latency table
class LatencyDB:
    BASE: Dict[str, int] = {
        "ADD": 1,
        "SUB": 1,
        "SBB": 2,
        "ADC": 1,
        "INC": 1,
        "DEC": 1,
        "CMP": 1,
        "NEG": 1,
        "AND": 1,
        "OR": 1,
        "XOR": 1,
        "NOT": 1,
        "TEST": 1,
        "SHL": 2,
        "SAL": 2,
        "SHR": 2,
        "SAR": 2,
        "ROL": 2,
        "ROR": 2,
        "RCL": 2,
        "RCR": 2,
        "SHLD": 3,
        "SHRD": 3,
        "MUL": 2,
        "IMUL": 2,
        "DIV": 4,
        "IDIV": 4,
    }
    DSP_ALU_W = 48
    DSP_MUL_W = 18
    CARRY8_PER_LUT = 12  # UltraScale+ –2
    FANOUT_THRESH = 5

    FLAG_WR = {
        "ADD",
        "SUB",
        "SBB",
        "ADC",
        "INC",
        "DEC",
        "CMP",
        "NEG",
        "AND",
        "OR",
        "XOR",
        "TEST",
        "SHL",
        "SAL",
        "SHR",
        "SAR",
        "ROL",
        "ROR",
        "RCL",
        "RCR",
        "SHLD",
        "SHRD",
    }
    FLAG_RD = FLAG_WR | {"SBB", "ADC", "RCL", "RCR"}

    @staticmethod
    def bitwidth(tokens: List[str]) -> int:
        bw = 32
        for t in tokens:
            if m := re.search(r"(\d+)", t):
                bw = max(bw, int(m.group(1)))
            elif t.lower().startswith(("xmm", "ymm", "zmm")):
                bw = max(bw, 128)
            elif "qword" in t.lower():
                bw = max(bw, 64)
        return bw

    @classmethod
    def latency(cls, op: str, bw: int) -> int:
        opu = op.upper()
        lat = cls.BASE.get(opu, 1)
        if opu in {"ADD", "SUB", "AND", "OR", "XOR"} and bw > 64:
            lat += 1
        if opu in {"MUL", "IMUL"} and bw > 32:
            lat += 1
        if opu in {"DIV", "IDIV"} and bw > 32:
            lat += 2
        return lat

    @classmethod
    def carry_penalty(cls, op: str, bw: int) -> int:
        return (
            0
            if op.upper() not in {"ADD", "SUB", "ADC", "SBB"}
            else max(0, (bw // 8 - 1) // cls.CARRY8_PER_LUT)
        )

    @classmethod
    def dsp_need(cls, op: str, bw: int) -> int:
        opu = op.upper()
        if opu in {"MUL", "IMUL"} and bw > cls.DSP_MUL_W:
            return 1
        if opu in {"ADD", "SUB"} and bw > cls.DSP_ALU_W:
            return 1
        return 0

    @staticmethod
    def lut_need(bw: int) -> int:
        return (bw + 31) // 32


@dataclass
class Uop:
    idx: int
    op: str
    bw: int
    lat: int
    dsp: int
    lut: int
    succ: int = 0  # will fill later


#  dependency graph builder
def _add_edge(edges: set[tuple[int, int]], a: int, b: int):
    edges.add((a, b))


def build_dag(uops: List[dict]) -> Tuple[List[Uop], set[tuple[int, int]]]:
    edges: set[tuple[int, int]] = set()
    last_write: Dict[str, int] = {}
    live_out: Dict[str, int] = {}

    # Pass 1: latency & resource table
    node: List[Uop] = []
    for i, u in enumerate(uops):
        bw = LatencyDB.bitwidth(u.get("raw_operands", []))
        base = LatencyDB.latency(u["opcode"], bw)
        extra = LatencyDB.carry_penalty(u["opcode"], bw)
        node.append(
            Uop(
                i,
                u["opcode"],
                bw,
                base + extra,
                LatencyDB.dsp_need(u["opcode"], bw),
                LatencyDB.lut_need(bw),
            )
        )

    # Pass 2: RAW/WAR/WAW edges
    for i, u in enumerate(uops):
        dst = set(u.get("out_operands", []))
        src = set(u.get("in_operands", []))
        for o in src:
            if o in last_write:
                _add_edge(edges, last_write[o], i)
        for o in dst:
            if o in last_write:
                _add_edge(edges, last_write[o], i)  # WAW/WAR
            last_write[o] = i
        for o in src | dst:
            live_out[o] = i

    # Pass 3: flag chain
    flag_src = None

    for i, u in enumerate(uops):
        opc = u["opcode"].upper()
        if opc in LatencyDB.FLAG_WR:
            flag_src = i
        if opc in LatencyDB.FLAG_RD and flag_src is not None and flag_src != i:
            _add_edge(edges, flag_src, i)

    # Pass 4: succ count & dead-write prune
    for a, b in edges:
        node[a].succ += 1

    for reg, wr in last_write.items():
        if live_out[reg] == wr:
            node[wr].dsp = node[wr].lut = 0

    for n in node:
        if n.succ > LatencyDB.FANOUT_THRESH:
            n.lat += 1

    return node, edges


def topo_sort(n: int, edges: set[tuple[int, int]]) -> Tuple[List[int], List[List[int]]]:
    succ = [[] for _ in range(n)]
    indeg = [0] * n
    for a, b in edges:
        succ[a].append(b)
        indeg[b] += 1
    q = deque(i for i, d in enumerate(indeg) if d == 0)
    order = []
    while q:
        i = q.popleft()
        order.append(i)
        for j in succ[i]:
            indeg[j] -= 1
            if indeg[j] == 0:
                q.append(j)
    if len(order) != n:
        raise RuntimeError("cycle detected")
    return order, succ


# main analysis 
def schedule_group(
    group: dict, max_comb: int, max_dsp: int, trace: bool = False
) -> Tuple[List[int], List[int], dict]:
    """return (order, ff_list, stats)"""
    node, edges = build_dag(group["instructions"])
    N = len(node)
    order0, succ = topo_sort(N, edges)
    indeg = [0] * N
    for _, b in edges:
        indeg[b] += 1

    ready = [i for i in order0 if indeg[i] == 0]
    order: List[int] = []
    stage_ff: List[int] = []
    stage_metrics = []
    stage_idx = 0

    while ready:
        ready.sort(key=lambda i: (node[i].lat, node[i].dsp, node[i].succ), reverse=True)
        used_comb = used_dsp = used_lut = net_cong = 0
        MAX_DSP_STAGE = max_dsp
        this_stage = []
        i = 0
        while i < len(ready):
            u = node[ready[i]]
            if used_comb + u.lat <= max_comb and used_dsp + u.dsp <= MAX_DSP_STAGE:
                this_stage.append(ready.pop(i))
                used_comb += u.lat
                used_dsp += u.dsp
                used_lut += u.lut
                net_cong += u.succ * u.lat
            else:
                i += 1
        if not this_stage:
            this_stage.append(ready.pop(0))
        order.extend(this_stage)
        stage_metrics.append((used_comb, used_dsp, used_lut, net_cong))
        if ready:
            stage_ff.append(this_stage[-1])
        for u in this_stage:
            for v in succ[u]:
                indeg[v] -= 1
                if indeg[v] == 0:
                    ready.append(v)
        stage_idx += 1

    cp_list = [m[0] for m in stage_metrics]
    stats = {
        "stage_metrics": stage_metrics,
        "crit_path_std": pstdev(cp_list) if len(cp_list) > 1 else 0.0,
    }

    # optional trace
    if trace:
        print(
            "\nStage | Comb DSP LUT Cong  -- critσ={:.2f}".format(
                stats["crit_path_std"]
            )
        )
        for s, (c, d, l, cong) in enumerate(stage_metrics):
            warn = "warning" if l > max_comb * 4 else ""
            print(f"{s:5d} | {c:4d} {d:3d} {l:3d} {cong:4d} {warn}")

    return order, stage_ff, stats, sum(n.lat for n in node)


def analyse(
    group: dict,
    max_comb: int,
    max_dsp: int,
    trace: bool,
    stats_out: Optional[List[dict]] = None,
) -> None:
    order, ff, stats, depth = schedule_group(group, max_comb, max_dsp, trace)
    g = group
    g["instructions"] = [g["instructions"][i] for i in order]
    g.update(
        {
            "order_map": order,
            "ff_boundaries": ff,
            "stage_count": len(ff) + 1,
            "latency_cycles": depth,
            "ff_mask": sum(1 << p for p in ff) & ((1 << len(order)) - 1),
            "crit_path_sigma": stats["crit_path_std"],
        }
    )
    if stats_out is not None:
        stats_out.append(
            {
                "idx": g.get("rank", 0),
                "stage_metrics": stats["stage_metrics"],
                "crit_sigma": stats["crit_path_std"],
            }
        )


# 5 │ CLI
def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("input_json")
    ap.add_argument("-o", "--out", default=None)
    ap.add_argument("--max-comb", type=int, default=2)
    ap.add_argument("--max-dsp", type=int, default=2)
    ap.add_argument("--tcl-dir", default="constraints")
    ap.add_argument("--emit-tcl", action="store_true")
    ap.add_argument("--trace", action="store_true")
    ap.add_argument("--json-stats", type=Path, help="dump per-stage metrics JSON")
    args = ap.parse_args()

    groups = json.loads(Path(args.input_json).read_text())
    groups = sorted(groups, key=lambda g: g.get("rank", 0))

    stats_list: list[dict] = []
    for idx, g in enumerate(groups):
        analyse(g, args.max_comb, args.max_dsp, args.trace, stats_list)
        print(
            f"[{idx:02d}] stage={g['stage_count']} " f"critσ={g['crit_path_sigma']:.2f}"
        )

    if args.out:
        out_base = Path(args.out)
        if out_base.is_dir():
            out_base = out_base / (Path(args.input_json).stem + "_result")
    else:
        in_p = Path(args.input_json).resolve()
        out_base = in_p.with_name(in_p.stem + "_result")

    out_base.parent.mkdir(parents=True, exist_ok=True)

    aug_json = out_base.parent / f"{out_base.name}_augmented.json"
    csv_out = out_base.parent / f"{out_base.name}_summary.csv"

    aug_json.write_text(json.dumps(groups, indent=2))
    with csv_out.open("w", newline="") as f:
        csv.writer(f).writerows(
            [("idx", "stage", "lat", "critσ")]
            + [
                (i, g["stage_count"], g["latency_cycles"], g["crit_path_sigma"])
                for i, g in enumerate(groups)
            ]
        )

    if args.emit_tcl:
        tcl = Path(args.tcl_dir) / "pipe_stages.tcl"
        tcl.parent.mkdir(parents=True, exist_ok=True)
        with tcl.open("w") as f:
            for idx, g in enumerate(groups):
                f.write(
                    f'set_property PIPE_STAGES {g["stage_count"]} '
                    f'[get_cells -hier -filter {{NAME =~ "*glen[{idx}].blk_i"}}]\n'
                )
        print(f"Done, {tcl}")

    if args.json_stats:
        args.json_stats.write_text(json.dumps(stats_list, indent=2))
        print(f"stats → {args.json_stats}")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        sys.exit(f"Error: {e}")
