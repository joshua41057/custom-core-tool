"""
Usage:
  python tools/gen_len_table_multi_limit.py <root_or_bench_or_json>
"""

from __future__ import annotations
import argparse, csv, json, re, sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

from opcodes import OPS_MAP, op_token 

BENCH_AREA_DB: Dict[str, Dict[str, float]] = {
    "500.perlbench_r":   {"device_total_clb": 147780, "bench_total_clb": 4373,  "bench_total_pct": 2.96},
    "502.gcc_r":         {"device_total_clb": 147780, "bench_total_clb": 3024,  "bench_total_pct": 2.05},
    "503.bwaves_r":      {"device_total_clb": 147780, "bench_total_clb": 9067,  "bench_total_pct": 6.14},
    "505.mcf_r":         {"device_total_clb": 147780, "bench_total_clb": 2763,  "bench_total_pct": 1.87},
    "507.cactuBSSN_r":   {"device_total_clb": 147780, "bench_total_clb": 1145,  "bench_total_pct": 0.77},
    "508.namd_r":        {"device_total_clb": 147780, "bench_total_clb": 2468,  "bench_total_pct": 1.67},
    "510.parest_r":      {"device_total_clb": 147780, "bench_total_clb": 1348,  "bench_total_pct": 0.91},
    "511.povray_r":      {"device_total_clb": 147780, "bench_total_clb": 832,   "bench_total_pct": 0.56},
    "519.lbm_r":         {"device_total_clb": 147780, "bench_total_clb": 1786,  "bench_total_pct": 1.21},
    "520.omnetpp_r":     {"device_total_clb": 147780, "bench_total_clb": 906,   "bench_total_pct": 0.61},
    "521.wrf_r":         {"device_total_clb": 147780, "bench_total_clb": 347,   "bench_total_pct": 0.23},
    "523.xalancbmk_r":   {"device_total_clb": 147780, "bench_total_clb": 535,   "bench_total_pct": 0.36},
    "525.x264_r":        {"device_total_clb": 147780, "bench_total_clb": 7637,  "bench_total_pct": 5.17},
    "526.blender_r":     {"device_total_clb": 147780, "bench_total_clb": 639,   "bench_total_pct": 0.43},
    "527.cam4_r":        {"device_total_clb": 147780, "bench_total_clb": 450,   "bench_total_pct": 0.30},
    "531.deepsjeng_r":   {"device_total_clb": 147780, "bench_total_clb": 3015,  "bench_total_pct": 2.04},
    "538.imagick_r":     {"device_total_clb": 147780, "bench_total_clb": 917,   "bench_total_pct": 0.62},
    "541.leela_r":       {"device_total_clb": 147780, "bench_total_clb": 1209,  "bench_total_pct": 0.82},
    "544.nab_r":         {"device_total_clb": 147780, "bench_total_clb": 592,   "bench_total_pct": 0.40},
    "548.exchange2_r":   {"device_total_clb": 147780, "bench_total_clb": 3049,  "bench_total_pct": 2.06},
    "549.fotonik3d_r":   {"device_total_clb": 147780, "bench_total_clb": 11296, "bench_total_pct": 7.64},
    "554.roms_r":        {"device_total_clb": 147780, "bench_total_clb": 731,   "bench_total_pct": 0.49},
    "557.xz_r":          {"device_total_clb": 147780, "bench_total_clb": 6809,  "bench_total_pct": 4.61},
    "600.perlbench_s":   {"device_total_clb": 147780, "bench_total_clb": 4428,  "bench_total_pct": 3.00},
    "602.gcc_s":         {"device_total_clb": 147780, "bench_total_clb": 1486,  "bench_total_pct": 1.01},
    "603.bwaves_s":      {"device_total_clb": 147780, "bench_total_clb": 4498,  "bench_total_pct": 3.04},
    "605.mcf_s":         {"device_total_clb": 147780, "bench_total_clb": 2627,  "bench_total_pct": 1.78},
    "607.cactuBSSN_s":   {"device_total_clb": 147780, "bench_total_clb": 894,   "bench_total_pct": 0.60},
    "619.lbm_s":         {"device_total_clb": 147780, "bench_total_clb": 1733,  "bench_total_pct": 1.17},
    "620.omnetpp_s":     {"device_total_clb": 147780, "bench_total_clb": 928,   "bench_total_pct": 0.63},
    "621.wrf_s":         {"device_total_clb": 147780, "bench_total_clb": 355,   "bench_total_pct": 0.24},
    "623.xalancbmk_s":   {"device_total_clb": 147780, "bench_total_clb": 647,   "bench_total_pct": 0.44},
    "625.x264_s":        {"device_total_clb": 147780, "bench_total_clb": 7453,  "bench_total_pct": 5.04},
    "627.cam4_s":        {"device_total_clb": 147780, "bench_total_clb": 563,   "bench_total_pct": 0.38},
    "628.pop2_s":        {"device_total_clb": 147780, "bench_total_clb": 600,   "bench_total_pct": 0.41},
    "631.deepsjeng_s":   {"device_total_clb": 147780, "bench_total_clb": 2719,  "bench_total_pct": 1.84},
    "641.leela_s":       {"device_total_clb": 147780, "bench_total_clb": 1176,  "bench_total_pct": 0.80},
    "644.nab_s":         {"device_total_clb": 147780, "bench_total_clb": 1276,  "bench_total_pct": 0.86},
    "648.exchange2_s":   {"device_total_clb": 147780, "bench_total_clb": 2243,  "bench_total_pct": 1.52},
    "649.fotonik3d_s":   {"device_total_clb": 147780, "bench_total_clb": 9495,  "bench_total_pct": 6.43},
    "654.roms_s":        {"device_total_clb": 147780, "bench_total_clb": 449,   "bench_total_pct": 0.30},
    "657.xz_s":          {"device_total_clb": 147780, "bench_total_clb": 4608,  "bench_total_pct": 3.12},
}

LIMITS_PCT = [0.5, 1.0, 2.0, 3.0]


def bits(msk: List[int], width: int) -> str:
    v = 0
    for i in msk or []:
        if 0 <= i < width:
            v |= 1 << i
    hex_w = (width + 3) // 4
    return f"{{{width}'h{v:0{hex_w}x}}}"

def hex32(tok: Any) -> str:
    try:
        v = int(tok, 0) if isinstance(tok, str) else int(tok)
    except (ValueError, TypeError):
        v = 0
    return f"32'h{v & 0xffffffff:08x}"

def load_json_list(path: Path) -> List[Dict[str, Any]]:
    obj = json.loads(path.read_text())
    return obj if isinstance(obj, list) else [obj]

def load_blocks(src: Path) -> List[Dict[str, Any]]:
    if src.is_dir():
        blk_dir = src / "blocks"
        if blk_dir.is_dir():
            files = sorted(blk_dir.glob("*.json"))
            return [json.loads(f.read_text()) for f in files]
        bj = src / "bench_blocks.json"
        if bj.is_file():
            return load_json_list(bj)
        jsons = list(src.glob("*.json"))
        if jsons:
            return load_json_list(jsons[0])
        raise SystemExit(f"[{src}] no json file")
    else:
        return load_json_list(src)

def derive_ff_boundaries(b: Dict[str, Any]) -> List[int]:
    if b.get("ff_boundaries"):
        return b["ff_boundaries"]
    if isinstance(b.get("stage_of_uop"), list):
        so = b["stage_of_uop"]
        return [i for i in range(len(so) - 1) if so[i] < so[i + 1]]
    if b.get("_ff_legacy"):
        return b["_ff_legacy"]
    return []

def get_stage_count(b: Dict[str, Any], ff: List[int], n_insn: int) -> int:
    for k in ("stage_count_fpga", "stage_count_full", "stage_count"):
        v = b.get(k)
        if isinstance(v, int) and v > 0:
            return v
    return (len(ff) + 1) if n_insn > 0 else 0

def _reorder_list_by(ord_map: List[int], arr: List[Any]) -> List[Any]:
    return [arr[i] for i in ord_map]

def reorder_block_instructions_inplace(b: Dict[str, Any]) -> None:
    instrs = b.get("instructions", []) or []
    if not instrs:
        return
    ord_map = b.get("final_order") or b.get("order_map")
    if not isinstance(ord_map, list) or len(ord_map) != len(instrs):
        return
    b["instructions"] = _reorder_list_by(ord_map, instrs)
    for k in ("stage_of_uop", "opcats"):
        if isinstance(b.get(k), list) and len(b[k]) == len(instrs):
            b[k] = _reorder_list_by(ord_map, b[k])
    if isinstance(b.get("stage_of_uop"), list) and len(b["stage_of_uop"]) == len(instrs):
        so = b["stage_of_uop"]
        b["ff_boundaries"] = [i for i in range(len(so) - 1) if so[i] < so[i + 1]]

REG_BITS: Dict[str, int] = {
    **{f"r{i}": 64 for i in range(16)},
    **{f"r{i}d": 32 for i in range(16)},
    **{f"r{i}w": 16 for i in range(16)},
    **{f"r{i}b":  8 for i in range(16)},
    "rax":64,"eax":32,"ax":16,"al":8,
    "rbx":64,"ebx":32,"bx":16,"bl":8,"bh":8,
    "rcx":64,"ecx":32,"cx":16,"cl":8,"ch":8,
    "rdx":64,"edx":32,"dx":16,"dl":8,"dh":8,
    "rsi":64,"esi":32,"si":16,"sil":8,
    "rdi":64,"edi":32,"di":16,"dil":8,
    "rbp":64,"ebp":32,"bp":16,"bpl":8,
    "rsp":64,"esp":32,"sp":16,"spl":8,
    **{f"xmm{i}":128 for i in range(32)},
    **{f"ymm{i}":256 for i in range(32)},
    **{f"zmm{i}":512 for i in range(32)},
    **{f"mm{i}":64 for i in range(8)},
    **{f"k{i}":64 for i in range(8)},
    "eflags":32, "rflags":64,
}
TOKEN_RE = re.compile(r"\b[a-zA-Z][a-zA-Z0-9]{0,15}\b")

def extract_regs_from_text(text: str) -> Set[str]:
    regs: Set[str] = set()
    for tok in TOKEN_RE.findall(text or ""):
        t = tok.lower()
        if t in REG_BITS:
            regs.add(t)
    return regs

def extract_regs(tokens: List[str]) -> Set[str]:
    regs: Set[str] = set()
    for t in tokens or []:
        regs |= extract_regs_from_text(str(t))
    return regs

MEM_SIZE_MAP = {
    "byte":8,"byte_ptr":8,"byteptr":8,
    "word":16,"word_ptr":16,"wordptr":16,
    "dword":32,"dword_ptr":32,"dwordptr":32,
    "qword":64,"qword_ptr":64,"qwordptr":64,
    "xmmword":128,"ymmword":256,"zmmword":512,
    "m8":8,"m16":16,"m32":32,"m64":64,"m128":128,"m256":256,"m512":512,
}
MEM_TOK_RE = re.compile("|".join(sorted(MEM_SIZE_MAP.keys(), key=len, reverse=True)), re.I)

def mem_size_hint(tokens: List[str]) -> Optional[int]:
    for t in tokens or []:
        s = str(t)
        m = MEM_TOK_RE.search(s)
        if m:
            return MEM_SIZE_MAP[m.group(0).lower()]
    return None

def has_memory_operand(tokens, opcode=None):
    if (opcode or "").strip().lower() == "lea":
        return False
    return any("[" in str(t) for t in (tokens or []))

def infer_mem_kind(ins: Dict[str, Any]) -> Optional[str]:
    op = (ins.get("opcode") or "").strip().lower()
    if op == "lea":
        return None
    ro   = ins.get("raw_operands") or []
    insi = ins.get("in_operands") or []
    out  = ins.get("out_operands") or []
    has_in  = any("[" in str(t) for t in ro+insi)
    has_out = any("[" in str(t) for t in out)
    if has_in and has_out: return "rwm"
    if has_in:  return "load"
    if has_out: return "store"
    return None

def get_mem_kind_list(b: Dict[str, Any], max_len: int) -> List[Optional[str]]:
    kinds = []
    for ins in b.get("instructions", []) or []:
        k = infer_mem_kind(ins)
        kinds.append(k)
    kinds += [None] * (max_len - len(kinds))
    return kinds

@dataclass
class OpDbInfo:
    widths: Set[int]
    occ: int = 0

SETCC_PREFIX = (
    "setb","setbe","setle","setnb","setnbe","setnl","setnle",
    "setnp","setnz","setp","setz"
)
def is_setcc(op: str) -> bool:
    return any(op.startswith(p) for p in SETCC_PREFIX)

def _is_fp_ps(op: str) -> bool:
    return bool(re.search(r"(?:^|v)(?:add|sub|mul|div|f(ma|msub|nmadd)?)\d*ps$", op))
def _is_fp_pd(op: str) -> bool:
    return bool(re.search(r"(?:^|v)(?:add|sub|mul|div|f(ma|msub|nmadd)?)\d*pd$", op))
def _is_fp_ss(op: str) -> bool:
    return bool(re.search(r"(?:^|v)(?:add|sub|mul|div|f(ma|msub|nmadd)?)\d*ss$", op))
def _is_fp_sd(op: str) -> bool:
    return bool(re.search(r"(?:^|v)(?:add|sub|mul|div|f(ma|msub|nmadd)?)\d*sd$", op))

_OP_EW_8  = {"vpaddb","vpor","vpxor","vpand","vpandn","vpcmpeqb","vpsubb","vpshufb","vpsadbw","vpavgb","vpblendvb"}
_OP_EW_16 = {"vpaddw","vpsllw","vpsrlw","vpsraw","vpcmpgtw","vpsubw","vpmullw","vpackuswb"}
_OP_EW_32 = {"vpaddd","vpslld","vpsrld","vpsrad","vpcmpeqd","vpmulld","vptest","vpsubd","vpshufd","vpbroadcastd","vpmovzxbd","vpmovsxbd"}
_OP_EW_64 = {"vpaddq","vpsllq","vpsrlq","vpsubq","vpcmpeqq","vpbroadcastq"}

def dst_width_hint(ins: Dict[str, Any]) -> Optional[int]:
    outs = ins.get("out_operands") or []
    regs = extract_regs(outs)
    if regs:
        widths_le64 = [REG_BITS[r] for r in regs if REG_BITS[r] <= 64]
        if widths_le64:
            w = min(widths_le64)
            return w if w in (8,16,32,64) else None
    insrc = ins.get("in_operands") or []
    regs = extract_regs(insrc)
    if regs:
        widths_le64 = [REG_BITS[r] for r in regs if REG_BITS[r] <= 64]
        if widths_le64:
            w = min(widths_le64)
            return w if w in (8,16,32,64) else None
    return None

def src_min_width_hint(ins: Dict[str, Any]) -> Optional[int]:
    insrc = ins.get("in_operands") or []
    regs = extract_regs(insrc)
    if regs:
        widths_le64 = [REG_BITS[r] for r in regs if REG_BITS[r] <= 64]
        if widths_le64:
            w = min(widths_le64)
            return w if w in (8,16,32,64) else None
    return None

def detect_container_width(tokens: List[str]) -> int:
    regs = extract_regs(tokens)
    w = 0
    for r in regs:
        bw = REG_BITS.get(r, 0)
        if bw >= 128:
            w = max(w, bw)
    ms = mem_size_hint(tokens)
    if ms in (128,256,512):
        w = max(w, ms)
    return w

def _compute_bw_legacy(ins: Dict[str, Any]) -> int:
    ro = ins.get("raw_operands") or []
    regs = extract_regs(ro + (ins.get("in_operands") or []) + (ins.get("out_operands") or []))
    bw = 0
    for r in regs:
        bw = max(bw, REG_BITS.get(r, 0))
    ms = mem_size_hint(ro)
    if ms: bw = max(bw, ms)
    if bw in (8,16,32,64): return bw
    if bw >= 128: return 64
    return 64

def elem_width_from_op(op_in: str, ins: Dict[str, Any], dbinfo: Optional[OpDbInfo]) -> int:
    op = (op_in or "").lower()
    ro = ins.get("raw_operands") or []

    if is_setcc(op): return 8
    if op.startswith("movzx"):
        ms = mem_size_hint(ro)
        if ms in (8,16): return ms
        smin = src_min_width_hint(ins)
        if smin in (8,16): return smin
        return 8
    if op.startswith("movsx"):
        ms = mem_size_hint(ro)
        if ms in (8,16,32): return ms if ms<=32 else 32
        smin = src_min_width_hint(ins)
        if smin in (8,16,32): return smin
        return 8
    if op.startswith("movsxd"): return 32

    if _is_fp_sd(op) or op.endswith("sd") or op.endswith("comisd") or op.endswith("ucomisd"): return 64
    if _is_fp_ss(op) or op.endswith("ss") or op.endswith("comiss") or op.endswith("ucomiss"): return 32
    if _is_fp_pd(op) or op.endswith("pd") or op == "vxorpd": return 64
    if _is_fp_ps(op) or op.endswith("ps") or op == "vxorps": return 32

    if op in _OP_EW_8:  return 8
    if op in _OP_EW_16: return 16
    if op in _OP_EW_32: return 32
    if op in _OP_EW_64: return 64

    m = re.match(r"(vp\w+)([bwdq])$", op)
    if m:
        return {"b":8,"w":16,"d":32,"q":64}[m.group(2)]

    if op.startswith("vpsll") or op.startswith("vpsrl") or op.startswith("vpsra"):
        if op.endswith("w"): return 16
        if op.endswith("d"): return 32
        if op.endswith("q"): return 64

    if op.startswith("vpbroadcast"):
        if op.endswith("b"): return 8
        if op.endswith("w"): return 16
        if op.endswith("d"): return 32
        if op.endswith("q"): return 64
    if op.startswith("vbroadcast"):
        if op.endswith("ss"): return 32
        if op.endswith("sd"): return 64

    ms = mem_size_hint(ro)
    if ms in (8,16,32,64): return ms

    dw = dst_width_hint(ins)
    if dw in (8,16,32,64): return dw

    smin = src_min_width_hint(ins)
    if smin in (8,16,32,64): return smin

    if dbinfo and dbinfo.widths:
        cands = sorted(w for w in dbinfo.widths if w <= 64)
        if cands:
            return cands[0]

    return _compute_bw_legacy(ins)

def compute_role_widths(op_in: str, ins: Dict[str, Any], dbinfo: Optional[OpDbInfo]) -> Tuple[int,int,int,int]:
    op = (op_in or "").strip().lower()
    ro = ins.get("raw_operands") or []
    elem_w = elem_width_from_op(op, ins, dbinfo)

    cont_w = detect_container_width(ro)
    addr_w = 64 if has_memory_operand(ro, opcode=op) else 0

    if _is_fp_sd(op) or op.endswith("sd") or op.endswith("comisd") or op.endswith("ucomisd"):
        return elem_w, 64, 128 if cont_w>=128 else 128, addr_w
    if _is_fp_ss(op) or op.endswith("ss") or op.endswith("comiss") or op.endswith("ucomiss"):
        return elem_w, 32, 128 if cont_w>=128 else 128, addr_w

    if op.startswith("movzx"):
        dstw = dst_width_hint(ins) or 64
        dstw = dstw if dstw in (8,16,32,64) else 64
        return elem_w, dstw, 0, addr_w
    if op.startswith("movsx"):
        dstw = dst_width_hint(ins) or 64
        dstw = dstw if dstw in (8,16,32,64) else 64
        return elem_w, dstw, 0, addr_w
    if op.startswith("movsxd"):
        return 32, 64, 0, addr_w
    if is_setcc(op):
        return 8, 8, 0, addr_w

    if cont_w in (128,256,512):
        if op == "vmovq": return 64, 64, 128, addr_w
        if op == "vmovd": return 32, 32, 128, addr_w
        return elem_w, cont_w, cont_w, addr_w

    data_w = elem_w if elem_w in (8,16,32,64) else 64
    return elem_w, data_w, 0, addr_w

def get_imm_and_use(ins):
    op = (ins.get("opcode") or "").lower()
    ro = ins.get("raw_operands") or []
    if not isinstance(ro, list):
        return "32'h00000000", "1'b0"

    if op in {"add","sub","and","or","xor","cmp","test","shl","shr","sar"} and len(ro) >= 2:
        imm = hex32(ro[1])
        use = "1'b1" if imm != "32'h00000000" else "1'b0"
        return imm, use

    return "32'h00000000", "1'b0"

def normalize_ff_to_stage(ff_idx: List[int], stage: int, n_insn: int,
                          opcats: Optional[List[str]] = None) -> List[int]:
    need = max(0, min(n_insn - 1, stage - 1))
    ff = sorted(i for i in set(ff_idx or []) if 0 <= i < n_insn - 1)
    if len(ff) == need:
        return ff

    def pri(i: int) -> Tuple[int, int]:
        is_ctrl_boundary = 0
        if opcats:
            here_ctrl = 1 if (0 <= i < len(opcats) and opcats[i] == "ctrl") else 0
            next_ctrl = 1 if (0 <= i+1 < len(opcats) and opcats[i+1] == "ctrl") else 0
            is_ctrl_boundary = 1 if (here_ctrl or next_ctrl) else 0
        return (0 if is_ctrl_boundary else 1, -i)

    if len(ff) > need:
        k = len(ff) - need
        rm_order = sorted(ff, key=pri)
        to_remove = set(rm_order[:k])
        return [i for i in ff if i not in to_remove]

    missing = need - len(ff)
    used = set(ff)
    cand = [i for i in range(n_insn - 1) if i not in used]
    targets = []
    if need > 0:
        step = n_insn / (need + 1)
        targets = [max(0, min(n_insn - 2, int(round(step * (t + 1)) - 1)))
                   for t in range(need)]
    add: List[int] = []
    for t in targets:
        if not cand: break
        j = min(range(len(cand)), key=lambda j: abs(cand[j] - t))
        add.append(cand.pop(j))
        if len(add) == missing: break
    add += cand[:(missing - len(add))]
    return sorted(ff + add[:missing])

def make_len_pkg(blocks: List[Dict[str, Any]],
                 op_db: Dict[str, OpDbInfo],
                 debug_rows: Optional[List[List[Any]]] = None) -> str:
    n = len(blocks)
    max_len = max((len(b.get("instructions", []) or []) for b in blocks), default=0)
    kind_code = {"load": "2'd1", "store": "2'd2", "rwm": "2'd3", None: "2'd0"}

    out: List[str] = []
    o = out.append

    stages: List[int] = []
    ff_lists: List[List[int]] = []
    for b in blocks:
        insn = b.get("instructions", []) or []
        ff = derive_ff_boundaries(b)
        st = get_stage_count(b, ff, len(insn))
        stages.append(st)
        ff_lists.append(ff)

    norm_ff_lists: List[List[int]] = []
    for b, st, ff in zip(blocks, stages, ff_lists):
        n_insn = len(b.get("instructions", []) or [])
        opcats = b.get("opcats")
        ff_norm = normalize_ff_to_stage(ff, st, n_insn, opcats)
        assert len(ff_norm) == max(0, st-1), \
            f"ff normalization mismatch: need {st-1}, got {len(ff_norm)}"
        norm_ff_lists.append(ff_norm)

    o("package len_table_pkg;")
    o("  import uop_pkg::*;")
    o(f"  localparam int N_CASE = {n};")
    o(f"  localparam int MAX_LEN = {max_len};")

    o("  localparam int LEN_LUT [N_CASE] = '{")
    o(",\n".join(f"    {len(b.get('instructions', []) or [])}" for b in blocks))
    o("  };")

    o("  localparam int STAGE_LUT [N_CASE] = '{")
    o(",\n".join(f"    {s}" for s in stages))
    o("  };")

    o("  /* FF boundaries bitmask per block */")
    o("  localparam logic [MAX_LEN-1:0] FF_MASK_LUT [N_CASE] = '{")
    ff_masks = [bits(ff_norm, len(b.get("instructions", []) or [])) for b, ff_norm in zip(blocks, norm_ff_lists)]
    o(",\n".join(f"    {m}" for m in ff_masks))
    o("  };")

    o("  localparam op_t OPS_LUT [N_CASE][MAX_LEN] = '{")
    for idx, b in enumerate(blocks):
        ops = [op_token(i.get("opcode","")) for i in (b.get("instructions", []) or [])]
        ops += ["OP_NOP"] * (max_len - len(ops))
        o("    '{ " + ", ".join(ops) + " }" + ("," if idx < n - 1 else ""))
    o("  };")

    o("  localparam logic [1:0] MEM_KIND_LUT [N_CASE][MAX_LEN] = '{")
    for idx, b in enumerate(blocks):
        kinds = [kind_code[k] for k in get_mem_kind_list(b, max_len)]
        o(f"    '{{ {', '.join(kinds)} }}{',' if idx < n-1 else ''}")
    o("  };")

    ew_rows: List[str] = []
    data_rows: List[str] = []
    cont_rows: List[str] = []
    addr_rows: List[str] = []
    data_max_lines: List[str] = []

    for bi, b in enumerate(blocks):
        ews: List[int] = []
        dws: List[int] = []
        cws: List[int] = []
        aws: List[int] = []
        data_max = 0

        for ui, ins in enumerate(b.get("instructions", []) or []):
            op = str(ins.get("opcode", ""))
            elem_w, data_w, cont_w, addr_w = compute_role_widths(op, ins, None)

            if elem_w not in (8,16,32,64): elem_w = 64
            if data_w not in (8,16,32,64,128,256,512): data_w = 64
            if cont_w not in (0,128,256,512): cont_w = 0
            if addr_w not in (0,64): addr_w = 0

            ews.append(elem_w)
            dws.append(data_w)
            cws.append(cont_w)
            aws.append(addr_w)

            data_max = max(data_max, data_w)

            if debug_rows is not None:
                ro = " ".join(map(str, ins.get("raw_operands") or []))
                debug_rows.append([bi, ui, op, elem_w, data_w, cont_w, addr_w, ro])

        pad_n = max_len - len(ews)
        ews += [64] * pad_n
        dws += [64] * pad_n
        cws += [0]  * pad_n
        aws += [0]  * pad_n

        ew_rows.append("    '{ " + ", ".join(map(str, ews)) + " }")
        data_rows.append("    '{ " + ", ".join(map(str, dws)) + " }")
        cont_rows.append("    '{ " + ", ".join(map(str, cws)) + " }")
        addr_rows.append("    '{ " + ", ".join(map(str, aws)) + " }")
        if data_max == 0: data_max = 64
        data_max_lines.append(f"    {data_max}")

    o("  /* Element width per uop (8/16/32/64) */")
    o("  localparam int ELEM_W_LUT [N_CASE][MAX_LEN] = '{")
    o(",\n".join(ew_rows))
    o("  };")

    o("  /* Data width per uop: scalar 8~64, vector 128/256/512 */")
    o("  localparam int BW_LUT [N_CASE][MAX_LEN] = '{")
    o(",\n".join(data_rows))
    o("  };")

    o("  localparam int BW_MAX_LUT [N_CASE] = '{")
    o(",\n".join(data_max_lines))
    o("  };")

    o("  /* Vector container width (XMM=128/YMM=256/ZMM=512), scalar=0 or 128 for ss/sd */")
    o("  localparam int CONT_W_LUT [N_CASE][MAX_LEN] = '{")
    o(",\n".join(cont_rows))
    o("  };")

    o("  /* Address path width: 64 when memory operand exists, else 0 */")
    o("  localparam int ADDR_W_LUT [N_CASE][MAX_LEN] = '{")
    o(",\n".join(addr_rows))
    o("  };")

    imm_rows: List[str] = []
    use_rows: List[str] = []
    for b in blocks:
        imms: List[str] = []
        uses: List[str] = []
        for ins in b.get("instructions", []) or []:
            imm, use = get_imm_and_use(ins)
            imms.append(imm)
            uses.append(use)
        pad = max_len - len(imms)
        imms += ["32'h00000000"] * pad
        uses += ["1'b0"] * pad
        imm_rows.append("    '{ " + ", ".join(imms) + " }")
        use_rows.append("    '{ " + ", ".join(uses) + " }")

    o("  localparam logic [31:0] IMM_LUT [N_CASE][MAX_LEN] = '{")
    o(",\n".join(imm_rows))
    o("  };")

    o("  localparam logic USE_IMM_LUT [N_CASE][MAX_LEN] = '{")
    o(",\n".join(use_rows))
    o("  };")

    o("endpackage")

    return "\n".join(out) + "\n"


def opcode_cost(opname: str) -> float:
    op = (opname or "").lower()

    heavy_patterns = ["mul", "mac", "mad", "mulh", "div", "rem", "sqrt", "fma", "fmul", "fdiv"]
    if any(p in op for p in heavy_patterns):
        return 10.0

    mem_patterns = ["ld", "st", "load", "store", "lw", "lh", "lb", "sw", "sh", "sb"]
    if any(p in op for p in mem_patterns):
        return 4.0

    shift_logic_patterns = ["sh", "rot", "and", "or", "xor"]
    if any(p in op for p in shift_logic_patterns):
        return 2.0

    branch_patterns = ["br", "jmp", "call", "ret", "branch"]
    if any(p in op for p in branch_patterns):
        return 1.0

    alu_patterns = ["add", "sub", "cmp", "sel", "mov", "lea", "fadd", "fsub"]
    if any(p in op for p in alu_patterns):
        return 1.5

    return 2.0

def estimate_block_area_raw(block_obj: Dict[str, Any]) -> float:
    inst_list = block_obj.get("instructions", []) or []
    cost_sum = 0.0
    for inst in inst_list:
        if isinstance(inst, dict):
            op_name = (
                inst.get("opcode") or
                inst.get("mnemonic") or
                inst.get("op") or
                inst.get("name") or
                inst.get("inst") or
                ""
            )
        else:
            op_name = str(inst)
        cost_sum += opcode_cost(op_name)

    if cost_sum <= 0.0:
        cost_sum = 1.0
    return cost_sum

def normalize_block_areas(raw_areas: List[float], real_total: float) -> List[float]:
    s = sum(raw_areas)
    if s <= 0.0:
        n = len(raw_areas)
        if n == 0:
            return []
        avg = real_total / float(n)
        return [avg for _ in raw_areas]
    scale = real_total / s
    return [x * scale for x in raw_areas]

def greedy_pick_blocks_for_budget(block_abs_areas: List[float],
                                  budget_abs: float) -> List[int]:
    picked: List[int] = []
    acc = 0.0
    for i, area_i in enumerate(block_abs_areas):
        if acc + area_i > budget_abs:
            break
        picked.append(i)
        acc += area_i
    return picked

def _strip_debug_keys(g: dict) -> dict:
    return {k: v for (k,v) in g.items() if not k.startswith("_")}

def emit_sniper_csv(groups: List[dict], out_csv: Path, add_blank_lines: bool=True):
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    with out_csv.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["bench","src","pc","latency"])
        for g in groups:
            instrs = g.get("instructions", [])
            if not instrs:
                continue
            bench = g.get("bench","")
            src   = g.get("src","")
            pcs = [ins.get("address") or ins.get("pc") or "" for ins in instrs]
            D = int(g.get("stage_count", 1))
            for j, pc in enumerate(pcs):
                w.writerow([bench, src, pc, D if j==0 else 0])
            if add_blank_lines:
                w.writerow([])


def is_bench_dir(p: Path) -> bool:
    return (p / "blocks").is_dir() or (p / "bench_blocks.json").is_file()


def run_one_bench_multi_limit(
    bench_dir: Path,
    op_db: Dict[str, OpDbInfo],
    global_picksets: Dict[float, List[Dict[str,Any]]]
) -> None:
    blocks = load_blocks(bench_dir)
    if not blocks:
        print(f"[WARN] {bench_dir}: no blocks")
        return

    for b in blocks:
        reorder_block_instructions_inplace(b)

    bench_name = bench_dir.name
    if bench_name not in BENCH_AREA_DB:
        print(f"[WARN] {bench_name}: no BENCH_AREA_DB entry. skipping bench.")
        return

    area_info = BENCH_AREA_DB[bench_name]
    device_total_clb = area_info["device_total_clb"]
    bench_total_clb  = area_info["bench_total_clb"]
    bench_total_pct  = area_info["bench_total_pct"]

    raw_areas: List[float] = [estimate_block_area_raw(b) for b in blocks]
    block_area_abs = normalize_block_areas(raw_areas, bench_total_clb)

    bench_full_pct: Optional[float] = None
    full_indices_cached: Optional[List[int]] = None

    for pct in LIMITS_PCT:
        if bench_full_pct is not None:
            sel_indices = list(full_indices_cached or [])
        else:
            budget_abs_clb = device_total_clb * (pct / 100.0)

            if bench_total_pct <= pct + 1e-9:
                sel_indices = list(range(len(blocks)))
                bench_full_pct = pct
                full_indices_cached = list(sel_indices)
            else:
                sel_indices = greedy_pick_blocks_for_budget(block_area_abs, budget_abs_clb)
                if not sel_indices:
                    sel_indices = [0]

        subset_blocks = [blocks[i] for i in sel_indices]

        global_picksets[pct].extend(subset_blocks)

        emit_sv = (bench_full_pct is None) or (pct <= bench_full_pct + 1e-9)
        if emit_sv:
            pct_tag = f"{pct:.1f}".replace('.', 'p') + "pct"
            sv_out = bench_dir / f"len_table_pkg_{pct_tag}.sv"
            pkg_txt = make_len_pkg(subset_blocks, op_db, None)
            sv_out.write_text(pkg_txt, encoding="utf-8", newline="\n")
            print(f"[OK] {bench_name} {pct:.1f}%: "
                  f"N_BLOCKS={len(subset_blocks)} (/{len(blocks)}) "
                  f"-> {sv_out.name}")
        else:
            print(f"[SKIP] {bench_name} {pct:.1f}%: "
                  f"same as {bench_full_pct:.1f}%, no new SV")


def emit_global_artifacts(root_dir: Path,
                          global_picksets: Dict[float, List[Dict[str,Any]]]) -> None:
    for pct in LIMITS_PCT:
        all_blocks = global_picksets[pct]

        all_blocks_sorted = sorted(
            all_blocks,
            key=lambda g: (g.get("bench",""), g.get("src",""), g.get("rank",0))
        )

        pct_tag = f"{pct:.1f}".replace('.', 'p') + "pct"
        base = root_dir / f"subset_{pct_tag}"

        json_path = root_dir / f"subset_{pct_tag}_augmented.json"
        serializable_groups = [_strip_debug_keys(g) for g in all_blocks_sorted]
        json_path.write_text(json.dumps(serializable_groups, indent=2))

        sniper_csv_path = root_dir / f"subset_{pct_tag}_sniper.csv"
        emit_sniper_csv(all_blocks_sorted, sniper_csv_path, add_blank_lines=True)

        print(f"[GLOBAL {pct:.1f}%] "
              f"{len(all_blocks_sorted)} blocks -> "
              f"{json_path.name}, {sniper_csv_path.name}")


def main():
    ap = argparse.ArgumentParser(
        description="Generate per-budget len_table_pkg_<limit>.sv for each bench "
                    "and also global subset_<limit>_(augmented.json|sniper.csv)"
    )
    ap.add_argument("src", help="bench dir, root dir, or json file (same semantics as old gen_len_table.py)")
    args = ap.parse_args()

    src = Path(args.src).resolve()
    op_db: Dict[str, OpDbInfo] = {}

    global_picksets: Dict[float, List[Dict[str,Any]]] = {pct: [] for pct in LIMITS_PCT}

    if src.is_dir():
        if is_bench_dir(src):
            benches = [src]
            root_dir = src.parent
        else:
            benches = [p for p in sorted(src.iterdir()) if p.is_dir() and is_bench_dir(p)]
            if not benches:
                sys.exit(f"No bench dirs under {src}")
            root_dir = src
    else:
        bench_dir = src.parent
        benches = [bench_dir]
        root_dir = bench_dir.parent if is_bench_dir(bench_dir) else bench_dir

    for b in benches:
        run_one_bench_multi_limit(b, op_db, global_picksets)

    emit_global_artifacts(root_dir, global_picksets)

if __name__ == "__main__":
    main()
