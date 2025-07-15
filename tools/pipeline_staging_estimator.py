#!/usr/bin/env python3
"""
python tools/pipeline_staging_estimator.py examples/alu_only.json \
    -o examples/result --emit_tcl --tcl-dir constraints
"""

from __future__ import annotations
import argparse, csv, json, re, sys
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from collections import deque
from dataclasses import dataclass
from statistics import pstdev

class LatencyDB:
    WIDTH = 64
    BASE: Dict[str,int] = {
        "NOP":1, 
        "ADD":1,"ADC":1,"SUB":1,"SBB":1, "INC":1,"DEC":1,
        "CMP":1,"NEG":1,
        "AND":1,"OR":1,"XOR":1,"NOT":1,"TEST":1,

        "SHL":1, "SAL":1, "SHR":1, "SAR":1,
        "ROL":1, "ROR":1, "RCL":1, "RCR":1,
        "RORX":1, "SHRX":1,
        "SHLD":1, "SHRD":1,

        "MUL":18,  "IMUL":18, "DIV":68, "IDIV":68,

        "MOV":1, "MOVSX":1, "MOVSXD":1, "MOVZX":1,

        "FADD":15, "FSUB":15,
        "FMUL":13,
        "FMA":27,
        "FCMP":3,
        "ICONV":5,

        "SUBSS":15, "VADDSD":15, "VSUBSD":15,
        "VMULSD":13,
        "VFMADD132SD":27, "VFNMADD132SD":27,
        "VCOMISD":3, "VCVTSI2SD":4, "VDIVSD":58,
        "VMAXSD":3, "VMINSD":3,        

        "VMOVD":1,"VMOVQ":1,"VMOVSD":1,"VMOVSLDUP":1,           

        "VPBROADCASTB":1,  "VPBROADCASTW":1,
        "VPBROADCASTB256":1, "VPBROADCASTW256":1,
        "VPSHUFD":2,
        "VXORPD":1,
        "VADDSD256":15, "VSUBSD256":15,
    }
    FANOUT_THRESH = 5
    FLAG_OPS = {
        "ADD","SUB","SBB","ADC","INC","DEC","CMP","NEG",
        "AND","OR","XOR","TEST",
        "SHL","SAR","SHR","SAL","SHRX","RORX",
        "IMUL","MUL","VCOMISD","FCMP",
    }

    @classmethod
    def bitwidth(cls, tokens: List[str] = []) -> int:
        width = 0
        for tok in tokens:
            if not isinstance(tok, str):
                continue
            t = tok.lower()
            if t.startswith("zmm"):
                width = max(width, 512)
            elif t.startswith("ymm"):
                width = max(width, 256)
            elif t.startswith("xmm"):
                width = max(width, 128)
            elif re.match(r"r\d+d$", t) or t.endswith("d"):
                width = max(width, 32)
            elif re.match(r"r\d+$", t) or t in {
                "rax","rbx","rcx","rdx","rsi","rdi","rbp","rsp"}:
                width = max(width, 64)

        return 64 if width < 64 else width

    @classmethod
    def latency(cls, op: str, bw: int) -> int:
        return cls.BASE.get(op.upper(), 1)

    @classmethod
    def dsp_need(cls, op: str, bw: int) -> int:
        opu = op.upper()
        if opu in {"MUL", "IMUL"}:                   
            return 1
        if opu in {"DIV", "IDIV"}:                   
            return 0
        if opu in {"FADD","FSUB","SUBSS","VADDSD","VSUBSD",
                "VADDSD256","VSUBSD256"}:
            return 3                                 
        if opu in {"FMUL","VMULSD"}:
            return 6                                 
        if opu in {"FMA","VFMADD132SD","VFNMADD132SD"}:
            return 10                                
        return 0

    @staticmethod
    def lut_need(bw: int) -> int:
        return (bw+31)//32

@dataclass
class Uop:
    idx:    int
    op:     str
    bw:     int
    lat:    int
    dsp:    int
    lut:    int
    succ:   int = 0

def _add_edge(edges:set[tuple[int,int]], a:int, b:int):
    edges.add((a,b))

def build_dag(uops:List[dict]) -> Tuple[List[Uop], set[tuple[int,int]]]:
    edges = set()
    last_write: Dict[str,int] = {}
    live_out:   Dict[str,int] = {}

    nodes: List[Uop] = []
    for i,u in enumerate(uops):
        bw  = LatencyDB.bitwidth(u.get("raw_operands",[]))
        lat = LatencyDB.latency(u["opcode"], bw)
        dsp = LatencyDB.dsp_need(u["opcode"], bw)
        lut = LatencyDB.lut_need(bw)
        nodes.append(Uop(i,u["opcode"],bw,lat,dsp,lut))

    for i,u in enumerate(uops):
        src = set(u.get("in_operands",[]))
        dst = set(u.get("out_operands",[]))
        for r in src:
            if r in last_write:
                _add_edge(edges, last_write[r], i)
        for w in dst:
            if w in last_write:
                _add_edge(edges, last_write[w], i)
            last_write[w] = i
        for v in src|dst:
            live_out[v] = i

    flag_src: Optional[int] = None
    for i,u in enumerate(uops):
        opc = u["opcode"].upper()
        if opc in LatencyDB.FLAG_OPS:
            flag_src = i
        if opc in LatencyDB.FLAG_OPS and flag_src is not None and flag_src!=i:
            _add_edge(edges, flag_src, i)

    for a,b in edges:
        nodes[a].succ += 1
    for reg,wr in last_write.items():
        if live_out.get(reg)==wr:
            nodes[wr].dsp = nodes[wr].lut = 0

    for n in nodes:
        if n.succ>LatencyDB.FANOUT_THRESH:
            n.lat += 1

    return nodes, edges

def topo_sort(n:int, edges:set[tuple[int,int]]):
    succ = [[] for _ in range(n)]
    indeg= [0]*n
    for a,b in edges:
        succ[a].append(b)
        indeg[b]+=1
    q = deque(i for i,d in enumerate(indeg) if d==0)
    order=[]
    while q:
        u = q.popleft()
        order.append(u)
        for v in succ[u]:
            indeg[v]-=1
            if indeg[v]==0:
                q.append(v)
    if len(order)!=n:
        raise RuntimeError("Cycle detected in DAG")
    return order, succ

MAX_COMB = 2
MAX_DSP  = 12

def schedule_group(uops:List[dict], trace:bool=False):
    nodes, edges = build_dag(uops)
    N = len(nodes)
    order0, succ = topo_sort(N, edges)

    indeg = [0]*N
    for _,b in edges: indeg[b]+=1
    ready = [i for i in order0 if indeg[i]==0]

    final_order=[]
    stage_ff=[]
    metrics=[]

    while ready:
        ready.sort(key=lambda i:(nodes[i].lat, nodes[i].dsp, nodes[i].succ), reverse=True)
        used_c=used_d=used_l=net= 0
        this_stage=[]
        i=0
        while i<len(ready):
            uidx = ready[i]
            u = nodes[uidx]
            if used_c+u.lat<=MAX_COMB and used_d+u.dsp<=MAX_DSP:
                this_stage.append(uidx)
                used_c+=u.lat; used_d+=u.dsp; used_l+=u.lut; net+=u.succ*u.lat
                ready.pop(i)
            else:
                i+=1
        if not this_stage:
            this_stage.append(ready.pop(0))
        final_order.extend(this_stage)
        metrics.append((used_c,used_d,used_l,net))
        if ready:
            stage_ff.append(this_stage[-1])
        for uidx in this_stage:
            for v in succ[uidx]:
                indeg[v]-=1
                if indeg[v]==0:
                    ready.append(v)

    cp = [m[0] for m in metrics]
    sigma = pstdev(cp) if len(cp)>1 else 0.0
    if trace:
        print(f"\nStage | Comb DSP LUT Cong  - critσ={sigma:.2f}")
        for s,(c,d,l,g) in enumerate(metrics):
            print(f"{s:2d} | {c:3d} {d:2d} {l:3d} {g:4d}")

    return final_order, stage_ff, sigma

def analyse(group:dict, trace:bool):
    order, ff, sigma = schedule_group(group["instructions"], trace)
    group["order_map"]       = order
    group["ff_boundaries"]   = ff
    group["stage_count"]     = len(ff)+1
    group["latency_cycles"]  = len(ff)+1
    group["crit_path_sigma"] = sigma

    pcs = []
    lats = []
    for u in group["instructions"]:
        pcs.append(u.get("address", ""))
        bw = LatencyDB.bitwidth(u.get("raw_operands", []))
        lats.append(LatencyDB.latency(u["opcode"], bw))
    group["pcs"]       = pcs
    group["latencies"] = lats

def main():
    p = argparse.ArgumentParser()
    p.add_argument("input_json", help="input JSON")
    p.add_argument("-o","--out",    help="output base name")
    p.add_argument("--emit_tcl",    action="store_true", help="TCL emit")
    p.add_argument("--tcl_dir", default="constraints",    help="TCL dir")
    p.add_argument("--trace",       action="store_true", help="stage info")
    args = p.parse_args()

    groups = json.loads(Path(args.input_json).read_text())
    groups.sort(key=lambda g:g.get("rank",0))

    for i,g in enumerate(groups):
        analyse(g, args.trace)
        print(f"[{i:02d}] stages={g['stage_count']} critσ={g['crit_path_sigma']:.2f}")

    if args.out:
        outb = Path(args.out)
    else:
        inp = Path(args.input_json)
        outb = inp.parent / f"{inp.stem}_result"
    outb.parent.mkdir(parents=True, exist_ok=True)

    # augmented JSON
    aug = outb.parent / f"{outb.name}_augmented.json"
    aug.write_text(json.dumps(groups, indent=2))

    # summary CSV
    csvf = outb.parent / f"{outb.name}_summary.csv"
    with csvf.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(("idx","stages","latency","critσ"))
        for i,g in enumerate(groups):
            w.writerow((i, g["stage_count"], g["latency_cycles"], g["crit_path_sigma"]))

    # emit TCL
    if args.emit_tcl:
        td = Path(args.tcl_dir)
        td.mkdir(parents=True, exist_ok=True)
        tclf = td/"pipe_stages.tcl"
        with tclf.open("w") as f:
            for i,g in enumerate(groups):
                f.write(
                  f"set_property PIPE_STAGES {g['stage_count']} "
                  f"[get_cells -hier -filter {{NAME =~ \"*glen[{i}].blk_i\"}}]\n"
                )
        print(f"TCL -> {tclf}")

if __name__=="__main__":
    try:
        main()
    except Exception as e:
        sys.exit(f"Error: {e}")
