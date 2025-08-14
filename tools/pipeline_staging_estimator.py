#!/usr/bin/env python3
from __future__ import annotations
import argparse, csv, json, math, re, sys, heapq
from collections import deque, defaultdict
from dataclasses import dataclass
from pathlib import Path
from statistics import pstdev
from typing import Dict, List, Optional, Tuple, Set

# ------------------------------
# 1) Opcode classification
# ------------------------------
FLAG_ONLY_OPS = {"cmp","test","ucomisd","vcomisd","vcomiss","vucomisd","vucomiss"}

INT_MUL_OPS = {"mul","imul"}
INT_SHIFT_OPS = {"shl","shlx","shr","shrx","sar","sarx","bt","bzhi","blsi","blsr","tzcnt","rorx"}
MOVE_OPS = {"mov","movsx","movzx","movsxd","lea","xchg","pop","push"}
LOGIC_OPS = {"and","andn","andpd","andps","or","xor","pxor","vpxor","vxorps","vxorpd","vandpd","vandps","vorpd","vpor","vpand","vpandn"}
ADD_OPS = {"add","sub","neg","not","dec","inc","addss","subss","vaddss","vaddsd","vsubss","vsubsd","vaddps","vaddpd","vsubps","vsubpd"}
FP_MUL_OPS = {"mulss","vmulss","vmulsd","vmulps","vmulpd","vpmulld"}
_FMA_RE = re.compile(r"v[fn]?f[mn]?(add|sub)\d*(pd|ps|sd|ss)$")

def classify(op: str) -> str:
    o = op.lower()
    if o in FLAG_ONLY_OPS:                 return "flag"
    if o in INT_MUL_OPS:                   return "imul"
    if o in INT_SHIFT_OPS:                 return "shift"
    if o in MOVE_OPS:                      return "move"
    if o in LOGIC_OPS:                     return "logic"
    if o in ADD_OPS:                       return "add"
    if o in FP_MUL_OPS:                    return "mul"
    if _FMA_RE.fullmatch(o):               return "fma"
    return "alu"

# ------------------------------
# 2) Bitwidth / memory detection
# ------------------------------
def heur_bitwidth(tokens: List[str]) -> int:
    width = 0
    for tok in tokens or []:
        t = tok.lower()
        if t.startswith("zmm"): width = max(width, 512)
        elif t.startswith("ymm"): width = max(width, 256)
        elif t.startswith("xmm"): width = max(width, 128)
        elif "[" in t: width = max(width, 64)
        elif re.match(r"r\d+d$", t) or t.endswith("d"): width = max(width, 32)
        elif re.match(r"r\d+$", t) or t in {"rax","rbx","rcx","rdx","rsi","rdi","rbp","rsp"}:
            width = max(width, 64)
    return 64 if width < 64 else width

def detect_mem_kind(u: dict) -> Optional[str]:
    mi = any("[" in t for t in u.get("in_operands", []))
    mo = any("[" in t for t in u.get("out_operands", []))
    if mi and mo: return "rwm"
    if mi: return "load"
    if mo: return "store"
    return None

def lanes_from_bw(bw: int, lane: int = 64) -> int:
    return max(1, math.ceil(bw / lane))

# ------------------------------
# 3) Delay & resource models (ns)
#    Conservative, FPGA-oriented
# ------------------------------
@dataclass
class DelayModel:
    # LUT-ish operations per 32-bit slice (ns)
    ns_logic32: float = 0.35        # and/xor/move/minor ops
    ns_add32:   float = 0.80        # add/sub/barrel approx per 32b
    ns_shift32: float = 0.85
    # DSP path (registered)
    ns_mul_dsp: float = 1.20
    ns_fma_dsp: float = 1.60
    # Address gen before BRAM/URAM reg (1-cycle memory read assumption)
    ns_addrgen: float = 0.60

    def dsp_for(self, cat: str) -> int:
        return {"imul":1, "mul":1, "fma":2}.get(cat, 0)  # rough

    def bram_ports(self, mem_kind: Optional[str]) -> int:
        if mem_kind is None: return 0
        return {"load":1, "store":1, "rwm":2}[mem_kind]

    def delay_ns(self, op: str, cat: str, bw: int, mem_kind: Optional[str], use_dsp: bool=True) -> float:
        if mem_kind is not None:
            # Address generation in this stage; data appears next stage
            return self.ns_addrgen
        slices = max(1, (bw + 31)//32)
        if cat in ("logic","move","alu","flag"): return self.ns_logic32 * slices
        if cat == "add":                          return self.ns_add32   * slices
        if cat == "shift":                        return self.ns_shift32 * slices
        if cat in ("imul","mul"):                 return self.ns_mul_dsp if use_dsp else self.ns_add32 * slices
        if cat == "fma":                          return self.ns_fma_dsp
        return self.ns_logic32 * slices

# ------------------------------
# 4) Node & DAG builder (RAW/WAW + WAR)
# ------------------------------
@dataclass
class Node:
    idx: int
    op: str
    cat: str
    bw: int
    delay_ns: float
    dsp: int
    lut_units: int
    bram_ports: int
    mem_kind: Optional[str] = None
    succ: int = 0
    needs_micro_pipe: bool = False
    substages: int = 1

def add_edge(edges: Set[Tuple[int,int]], a: int, b: int) -> None:
    if a != b: edges.add((a,b))

def build_dag(
    uops: List[dict],
    dmodel: DelayModel,
    use_dsp: bool = True,
    serial_mem: bool = False,
) -> Tuple[List[Node], Set[Tuple[int,int]]]:

    edges: Set[Tuple[int,int]] = set()
    last_write: Dict[str,int] = {}
    last_read:  Dict[str,List[int]] = defaultdict(list)  # for WAR
    nodes: List[Node] = []

    mem_nodes_order: List[int] = []

    # Create nodes
    for i, u in enumerate(uops):
        op_lc = u["opcode"].lower()
        mk    = detect_mem_kind(u)
        cat   = classify(op_lc)
        bw    = heur_bitwidth(u.get("raw_operands", []))
        delay = dmodel.delay_ns(op_lc, cat, bw, mk, use_dsp=use_dsp)
        dsp   = dmodel.dsp_for(cat) * lanes_from_bw(bw)
        lut   = max(1, (bw + 31)//32)
        ports = dmodel.bram_ports(mk)
        nodes.append(Node(i, op_lc, cat, bw, delay, dsp, lut, ports, mk))
        if mk is not None:
            mem_nodes_order.append(i)

    # Build deps: RAW / WAW / WAR
    for i, u in enumerate(uops):
        src = list(u.get("in_operands", []))
        dst = list(u.get("out_operands", []))

        # RAW
        for r in src:
            if r in last_write: add_edge(edges, last_write[r], i)
            last_read[r].append(i)

        # WAW + WAR
        for w in dst:
            # WAR: all previous readers of w must precede this write
            for r_i in last_read.get(w, []):
                add_edge(edges, r_i, i)
            last_read[w].clear()
            # WAW
            if w in last_write: add_edge(edges, last_write[w], i)
            last_write[w] = i

    # Conservative memory serialization (optional)
    if serial_mem and mem_nodes_order:
        prev = mem_nodes_order[0]
        for cur in mem_nodes_order[1:]:
            add_edge(edges, prev, cur)
            prev = cur

    # succ counts
    for a,b in edges:
        nodes[a].succ += 1

    return nodes, edges

def topo_sort(n: int, edges: Set[Tuple[int,int]]):
    succ = [[] for _ in range(n)]
    indeg = [0]*n
    for a,b in edges:
        succ[a].append(b)
        indeg[b] += 1
    q = deque(i for i,d in enumerate(indeg) if d == 0)
    order: List[int] = []
    while q:
        u = q.popleft()
        order.append(u)
        for v in succ[u]:
            indeg[v] -= 1
            if indeg[v] == 0: q.append(v)
    if len(order) != n:
        raise RuntimeError("cycle detected")
    return order, succ

# ------------------------------
# 5) Criticality & list scheduler
#     - memory barrier (load/store -> consumer next stage)
#     - oversize op (delay > stage_ns_limit) tracking
# ------------------------------
def compute_criticality(nodes: List[Node], edges: Set[Tuple[int,int]]) -> Tuple[List[int], List[List[int]], List[float]]:
    n = len(nodes)
    order, succ = topo_sort(n, edges)
    crit = [0.0]*n
    for u in reversed(order):
        crit[u] = nodes[u].delay_ns + max((crit[v] for v in succ[u]), default=0.0)
    return order, succ, crit

@dataclass
class StageInfo:
    nodes: List[int]
    max_delay_ns: float
    used_dsp: int
    used_bram_ports: int
    used_lut_units: int
    ii: int

def schedule_list_crit(
    nodes: List[Node],
    edges: Set[Tuple[int,int]],
    target_ns: float,        # Tclk (ns)
    logic_frac: float,       # portion for logic (routing slack)
    dsp_budget: int, bram_ports_budget: int, lut_budget: int,
    allow_ii: bool = False,
    trace: bool = False,
) -> Tuple[List[int], List[StageInfo]]:

    n = len(nodes)
    order, succ, crit = compute_criticality(nodes, edges)
    preds = [[] for _ in range(n)]
    for a,b in edges:
        preds[b].append(a)

    stage_ns_limit = target_ns * logic_frac

    # ready queue by -criticality (max-first)
    indeg = [0]*n
    for a,b in edges: indeg[b]+=1
    ready: List[Tuple[float,int]] = []
    for u in range(n):
        if indeg[u]==0:
            heapq.heappush(ready, (-crit[u], u))

    stages: List[StageInfo] = []
    cur: List[int] = []
    stage_longest: Dict[int,float] = {}
    used_dsp = used_bram = used_lut = 0

    def has_mem_barrier_pred_in_cur(u: int) -> bool:
        # If any predecessor placed in the *current* stage is a memory op,
        # consumer must be in the next stage (1-cycle read)
        for p in preds[u]:
            if p in cur and nodes[p].mem_kind is not None:
                return True
        return False

    def can_place(u: int) -> bool:
        nonlocal used_dsp, used_bram, used_lut
        # memory barrier: forbid placing u if any mem predecessor is in this stage
        if has_mem_barrier_pred_in_cur(u):
            return False

        # oversize path check
        L = max((stage_longest.get(p,0.0) for p in preds[u] if p in cur), default=0.0) + nodes[u].delay_ns
        if L > stage_ns_limit:
            return False

        ndsp  = used_dsp  + nodes[u].dsp
        nbram = used_bram + nodes[u].bram_ports
        nlut  = used_lut  + nodes[u].lut_units

        if allow_ii:
            return True
        if dsp_budget  >= 0 and ndsp  > dsp_budget:  return False
        if bram_ports_budget >=0 and nbram > bram_ports_budget: return False
        if lut_budget  >= 0 and nlut  > lut_budget:  return False
        return True

    def place(u: int):
        nonlocal used_dsp, used_bram, used_lut
        # micro-pipeline mark (oversize op)
        if nodes[u].delay_ns > stage_ns_limit:
            nodes[u].needs_micro_pipe = True
            nodes[u].substages = max(1, math.ceil(nodes[u].delay_ns / stage_ns_limit))
        L = max((stage_longest.get(p,0.0) for p in preds[u] if p in cur), default=0.0) + nodes[u].delay_ns
        stage_longest[u] = L
        cur.append(u)
        used_dsp  += nodes[u].dsp
        used_bram += nodes[u].bram_ports
        used_lut  += nodes[u].lut_units

    def commit():
        nonlocal cur, stage_longest, used_dsp, used_bram, used_lut
        if not cur:
            return
        max_delay = max((stage_longest[u] for u in cur), default=0.0)
        if allow_ii:
            ii_candidates = [1]
            if dsp_budget  > 0: ii_candidates.append(math.ceil(used_dsp / dsp_budget))
            if bram_ports_budget > 0: ii_candidates.append(math.ceil(used_bram / bram_ports_budget))
            if lut_budget  > 0: ii_candidates.append(math.ceil(used_lut / lut_budget))
            ii_val = max(ii_candidates)
        else:
            ii_val = 1

        stages.append(StageInfo(
            nodes=cur[:],
            max_delay_ns=max_delay,
            used_dsp=used_dsp,
            used_bram_ports=used_bram,
            used_lut_units=used_lut,
            ii=ii_val,
        ))
        cur = []
        stage_longest = {}
        used_dsp = used_bram = used_lut = 0

    placed_order: List[int] = []

    while ready:
        _, u = heapq.heappop(ready)
        if not can_place(u):
            # 스테이지를 닫고 새 스테이지를 연 뒤,
            # 단일 연산이 자원 한도를 스스로 초과하는지 검사(II=1일 때는 금지)
            commit()
            if not allow_ii:
                if (dsp_budget  >= 0 and nodes[u].dsp        > dsp_budget) or \
                   (bram_ports_budget >= 0 and nodes[u].bram_ports > bram_ports_budget) or \
                   (lut_budget  >= 0 and nodes[u].lut_units  > lut_budget):
                    raise ValueError(
                        f"Single op exceeds per-stage resource budget: op={nodes[u].op}, "
                        f"DSP={nodes[u].dsp}, BRAMports={nodes[u].bram_ports}, LUTs={nodes[u].lut_units}. "
                        f"Increase budgets or use --allow-ii."
                    )
        # 빈 스테이지에 단독 배치는 허용(경로 초과는 마이크로 파이프라인으로 표기)
        place(u)
        placed_order.append(u)
        for v in succ[u]:
            indeg[v]-=1
            if indeg[v]==0:
                heapq.heappush(ready, (-crit[v], v))

    commit()
    if trace:
        print("Stage | max_delay(ns) | DSP | BRAMports | LUTs | II | #ops")
        for i, st in enumerate(stages):
            print(f"{i:3d}   {st.max_delay_ns:7.3f}       {st.used_dsp:4d}   {st.used_bram_ports:5d}     {st.used_lut_units:5d}  {st.ii:2d}  {len(st.nodes):3d}")
    return placed_order, stages

# ------------------------------
# 6) Group analysis
# ------------------------------
def analyse_group(
    group: dict,
    target_mhz: float,
    logic_frac: float,
    dsp_budget: int,
    bram_ports_budget: int,
    lut_budget: int,
    allow_ii: bool,
    use_dsp: bool,
    serial_mem: bool,
    trace: bool,
):
    dmodel = DelayModel()

    # === 변경 1: 입력에 메모리 uop이 1개라도 있으면 자동 직렬화 ===
    has_mem = any(detect_mem_kind(u) is not None for u in group["instructions"])
    serial_eff = serial_mem or has_mem

    nodes, edges = build_dag(group["instructions"], dmodel, use_dsp=use_dsp, serial_mem=serial_eff)
    Tclk_ns = 1000.0 / max(1.0, target_mhz)

    final_order, stages = schedule_list_crit(
        nodes, edges,
        target_ns=Tclk_ns, logic_frac=logic_frac,
        dsp_budget=dsp_budget, bram_ports_budget=bram_ports_budget, lut_budget=lut_budget,
        allow_ii=allow_ii, trace=trace
    )

    # stage-of mapping & FF boundaries
    stage_of = [-1]*len(nodes)
    for s, st in enumerate(stages):
        for idx in st.nodes:
            stage_of[idx] = s
    ff_boundaries = []
    for i in range(len(final_order)-1):
        a, b = final_order[i], final_order[i+1]
        if stage_of[a] < stage_of[b]:
            ff_boundaries.append(a)

    stage_count_full = len(stages)
    latency_cycles = stage_count_full
    initiation_interval = max((st.ii for st in stages), default=1)

    # Fmax 추정(보수적)
    worst_stage_delay = max((st.max_delay_ns for st in stages), default=0.0)
    worst_op_delay    = max((n.delay_ns for n in nodes), default=0.0)
    est_Tclk_ns = 0.0
    if worst_stage_delay > 0:
        est_Tclk_ns = max(est_Tclk_ns, worst_stage_delay / max(1e-9, logic_frac))
    if worst_op_delay > 0:
        est_Tclk_ns = max(est_Tclk_ns, worst_op_delay  / max(1e-9, logic_frac))
    est_fmax_mhz = 1000.0 / est_Tclk_ns if est_Tclk_ns > 0 else 0.0

    sigma = pstdev([st.max_delay_ns for st in stages]) if len(stages) > 1 else 0.0

    # annotate group
    group["order_map"]           = final_order
    group["ff_boundaries"]       = ff_boundaries
    group["stage_of_uop"]        = stage_of
    group["stage_count_full"]    = stage_count_full
    group["stage_count_fpga"]    = stage_count_full
    group["latency_cycles"]      = latency_cycles
    group["initiation_interval"] = initiation_interval
    group["est_fmax_mhz"]        = est_fmax_mhz
    group["stage_max_delay_ns"]  = [round(st.max_delay_ns,4) for st in stages]
    group["crit_path_sigma"]     = sigma
    group["serial_mem_effective"]= serial_eff  # 리포트에 기록

    # Op info
    group["pcs"]            = [ins.get("address","") for ins in group["instructions"]]
    group["opcats"]         = [nodes[i].cat for i in range(len(nodes))]
    group["op_mem_kind"]    = [nodes[i].mem_kind for i in range(len(nodes))]
    group["op_delay_ns"]    = [round(nodes[i].delay_ns,4) for i in range(len(nodes))]
    group["op_dsp"]         = [nodes[i].dsp for i in range(len(nodes))]
    group["op_lut_slices"]  = [nodes[i].lut_units for i in range(len(nodes))]
    group["op_need_mpipe"]  = [nodes[i].needs_micro_pipe for i in range(len(nodes))]
    group["op_substages"]   = [nodes[i].substages for i in range(len(nodes))]

# ------------------------------
# 7) CLI & main
# ------------------------------
def cli() -> argparse.Namespace:
    ap = argparse.ArgumentParser("fpga_pipeline_stager_200mhz")
    ap.add_argument("input_json", help="block_scanner output JSON (ALU-only preferred)")
    ap.add_argument("-o","--out", help="output base (no extension)")
    ap.add_argument("--target-mhz", type=float, default=200.0, help="target Fmax in MHz (default: 200)")
    ap.add_argument("--logic-frac", type=float, default=0.70, help="portion of Tclk usable for logic (routing slack), default 0.70")
    ap.add_argument("--dsp-budget", type=int, default=64, help="max DSPs per stage if II=1; -1 = unbounded")
    ap.add_argument("--bram-ports-budget", type=int, default=8, help="max BRAM ports per stage if II=1; -1 = unbounded")
    ap.add_argument("--lut-budget", type=int, default=4096, help="max LUT 'units' per stage if II=1; -1 = unbounded")
    ap.add_argument("--allow-ii", action="store_true", help="allow per-stage oversubscription and compute II>1 instead of splitting")
    ap.add_argument("--no-dsp", action="store_true", help="do not use DSP in delay model (pessimistic LUT implementation)")
    ap.add_argument("--serial-mem", action="store_true", help="conservatively serialize all memory operations in program order")
    ap.add_argument("--emit-sniper", type=Path, help="emit Sniper depth CSV")
    ap.add_argument("--trace", action="store_true")
    return ap.parse_args()

def main() -> None:
    args = cli()
    groups = json.loads(Path(args.input_json).read_text())
    groups.sort(key=lambda g: g.get("rank", 0))

    for i, g in enumerate(groups):
        analyse_group(
            g,
            target_mhz=args.target_mhz,
            logic_frac=args.logic_frac,
            dsp_budget=args.dsp_budget,
            bram_ports_budget=args.bram_ports_budget,
            lut_budget=args.lut_budget,
            allow_ii=args.allow_ii,
            use_dsp=(not args.no_dsp),
            serial_mem=args.serial_mem,
            trace=args.trace,
        )
        print(f"[{i:05d}] stages={g['stage_count_fpga']:3d} II={g['initiation_interval']}"
              f" Fmax≈{g['est_fmax_mhz']:6.1f} MHz  σ={g['crit_path_sigma']:.2f}"
              f"  serial_mem={g['serial_mem_effective']}")

    outb = Path(args.out) if args.out else Path(args.input_json).with_suffix("")
    outb.parent.mkdir(parents=True, exist_ok=True)
    (outb.parent / f"{outb.name}_augmented.json").write_text(json.dumps(groups, indent=2))

    # Summary CSV
    summary_csv = outb.parent / f"{outb.name}_summary.csv"
    with summary_csv.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(("idx","stages","II","est_fmax_mhz","latency","rank","exec_cnt","serial_mem"))
        for i, g in enumerate(groups):
            w.writerow((
                i, g["stage_count_fpga"], g["initiation_interval"],
                f"{g['est_fmax_mhz']:.1f}",
                g["latency_cycles"], g.get("rank",""), g.get("execution_count",""),
                g.get("serial_mem_effective", False),
            ))
    print(f"summary CSV -> {summary_csv}")

    # Sniper CSV (depth only)
    if args.emit_sniper:
        snf = Path(args.emit_sniper)
        with snf.open("w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["bench", "src", "pc", "latency"])
            for g in groups:
                bench = g.get("bench", "")
                src   = g.get("src", "")
                depth = g.get("stage_count_full", 0)
                for idx, pc in enumerate(g.get("pcs", [])):
                    lat = depth if idx == 0 else 0
                    writer.writerow([bench, src, pc, lat])
                writer.writerow([])
        print(f"Sniper CSV -> {snf}")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        sys.exit(f"error: {e}")