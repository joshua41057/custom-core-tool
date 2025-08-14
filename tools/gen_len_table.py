#!/usr/bin/env python3
"""
python tools/gen_len_table.py  examples/blocks/.json  --out rtl/len_table_pkg.sv
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

from opcodes import OPS_MAP, op_token

def bits(msk: List[int], width: int) -> str:
    v = 0
    for i in msk:
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

def infer_mem_kind(ins):
    ro   = ins.get("raw_operands") or []
    insi = ins.get("in_operands") or []
    out  = ins.get("out_operands") or []
    has_in  = any("[" in str(t) for t in ro+insi)
    has_out = any("[" in str(t) for t in out)
    if has_in and has_out: return "rwm"
    if has_in:  return "load"
    if has_out: return "store"
    return None

def get_mem_kind_list(b, max_len):
    kinds = []
    for ins in b.get("instructions", []):
        k = ins.get("mem_kind")
        if k is None:
            k = infer_mem_kind(ins)
        kinds.append(k)
    kinds += [None] * (max_len - len(kinds))
    return kinds



# Register DB 

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
    **{f"k{i}":64 for i in range(8)},
    "eflags":32, "rflags":64,
}
TOKEN_RE = re.compile(r"\b[a-zA-Z][a-zA-Z0-9]{0,9}\b")

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

# Memory size tokens 

MEM_SIZE_MAP = {
    "byte": 8, "byte_ptr": 8, "byteptr": 8,
    "word": 16, "word_ptr":16, "wordptr":16,
    "dword": 32, "dword_ptr":32, "dwordptr":32,
    "qword": 64, "qword_ptr":64, "qwordptr":64,
    "xmmword":128, "ymmword":256, "zmmword":512,
}
MEM_TOK_RE = re.compile("|".join(sorted(MEM_SIZE_MAP.keys(), key=len, reverse=True)), re.IGNORECASE)
BRACKET_RE = re.compile(r"\[")

def mem_size_hint(tokens: List[str]) -> Optional[int]:
    for t in tokens or []:
        s = str(t)
        m = MEM_TOK_RE.search(s)
        if m:
            return MEM_SIZE_MAP[m.group(0).lower()]
    return None

def has_memory_operand(tokens: List[str]) -> bool:
    for t in tokens or []:
        if BRACKET_RE.search(str(t)):
            return True
    return False

# Heuristics kept for fallback 

_RE32 = re.compile(r"r\d+d$")
def _heur_bitwidth(tokens: List[str]) -> int:
    width = 0
    for tok in tokens or []:
        t = str(tok).lower()
        if   t.startswith("zmm"): width = max(width, 512)
        elif t.startswith("ymm"): width = max(width, 256)
        elif t.startswith("xmm"): width = max(width, 128)
        elif "[" in t:            width = max(width, 64)
        elif _RE32.search(t) or t.endswith("d"): width = max(width, 32)
        elif re.match(r"r\d+$", t) or t in {"rax","rbx","rcx","rdx","rsi","rdi","rbp","rsp"}:
            width = max(width, 64)
    return 64 if width < 64 else width

def _compute_bw_legacy(ins: Dict[str, Any]) -> int:
    try:
        return int(ins.get("bit_width"))
    except Exception:
        pass
    ro = ins.get("raw_operands") or []
    toks = ro
    if not toks:
        toks = (ins.get("in_operands") or []) + (ins.get("out_operands") or [])
    return _heur_bitwidth(toks)

# Opcode DB

@dataclass
class OpDbInfo:
    widths: Set[int]
    occ: int = 0

def load_opcode_db(csv_path: Optional[Path]) -> Dict[str, OpDbInfo]:
    if not csv_path or not csv_path.is_file():
        return {}
    db: Dict[str, OpDbInfo] = {}
    with csv_path.open(newline="") as f:
        rdr = csv.DictReader(f)
        for row in rdr:
            op = (row.get("Opcode") or "").strip().lower()
            if not op:
                continue
            wset: Set[int] = set()
            field = (row.get("RegWidths") or "").strip()
            for tok in re.split(r"[,\s]+", field):
                if not tok: continue
                try:
                    wset.add(int(tok))
                except ValueError:
                    pass
            occ = int(row.get("Occurrences") or 0)
            db[op] = OpDbInfo(wset, occ)
    return db

# Classifiers

SETCC_PREFIX = (
    "setb","setbe","setle","setnb","setnbe","setnl","setnle",
    "setnp","setnz","setp","setz"
)
def is_setcc(op: str) -> bool:
    return any(op.startswith(p) for p in SETCC_PREFIX)

_OP_EW_8  = {
    "vpaddb","vpor","vpxor","vpand","vpandn","vpcmpeqb","vpsubb",
    "vpshufb","vpsadbw","vpavgb","vavgb","vpblendvb",
}
_OP_EW_16 = {
    "vpaddw","vpsllw","vpsrlw","vpsraw","vpcmpgtw","vpsubw","vpmullw","vpackuswb",
}
_OP_EW_32 = {
    "vpaddd","vpslld","vpsrld","vpsrad","vpcmpeqd","vpmulld","vptest","vpsubd",
    "vpshufd","vpbroadcastd","vpmovzxbd","vpmovsxbd",
}
_OP_EW_64 = {
    "vpaddq","vpsllq","vpsrlq","vpsubq","vpcmpeqq","vpbroadcastq",
}

def _is_fp_ps(op: str) -> bool:
    return bool(re.search(r"(?:^|v)(?:add|sub|mul|div|f(ma|msub|nmadd)?)\d*ps$", op))
def _is_fp_pd(op: str) -> bool:
    return bool(re.search(r"(?:^|v)(?:add|sub|mul|div|f(ma|msub|nmadd)?)\d*pd$", op))
def _is_fp_ss(op: str) -> bool:
    return bool(re.search(r"(?:^|v)(?:add|sub|mul|div|f(ma|msub|nmadd)?)\d*ss$", op))
def _is_fp_sd(op: str) -> bool:
    return bool(re.search(r"(?:^|v)(?:add|sub|mul|div|f(ma|msub|nmadd)?)\d*sd$", op))

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
    # memory annotation like xmmword/ymmword/zmmword
    ms = mem_size_hint(tokens)
    if ms in (128,256,512):
        w = max(w, ms)
    return w

def elem_width_from_op(op_in: str, ins: Dict[str, Any],
                       dbinfo: Optional[OpDbInfo]) -> int:
    op = (op_in or "").lower()
    ro = ins.get("raw_operands") or []
    bw = _compute_bw_legacy(ins)

    if is_setcc(op):
        return 8

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
    if op.startswith("movsxd"):
        return 32

    if _is_fp_sd(op) or op.endswith("sd") or op.endswith("comisd") or op.endswith("ucomisd"):
        return 64
    if _is_fp_ss(op) or op.endswith("ss") or op.endswith("comiss") or op.endswith("ucomiss"):
        return 32
    if _is_fp_pd(op) or op.endswith("pd") or op == "vxorpd":
        return 64
    if _is_fp_ps(op) or op.endswith("ps") or op == "vxorps":
        return 32

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

    if op == "vpshufd": return 32

    if op == "vmovd": return 32
    if op == "vmovq": return 64
    if op == "vmovss": return 32
    if op == "vmovsd": return 64
    if op.startswith("vmovdq"): return 32
    if op in ("vmovaps","vmovups"): return 32
    if op in ("vmovapd","vmovupd"): return 64

    ms = mem_size_hint(ro)
    if ms in (8,16,32,64):
        return ms

    dw = dst_width_hint(ins)
    if dw in (8,16,32,64):
        return dw

    smin = src_min_width_hint(ins)
    if smin in (8,16,32,64):
        return smin

    if dbinfo and dbinfo.widths:
        cands = sorted(w for w in dbinfo.widths if w <= 64)
        if cands:
            return cands[0]

    if bw in (8,16,32,64):
        return bw

    return 64

def compute_role_widths(op_in: str, ins: Dict[str, Any], dbinfo: Optional[OpDbInfo]) -> Tuple[int,int,int,int]:
    op = (op_in or "").lower()
    ro = ins.get("raw_operands") or []
    elem_w = elem_width_from_op(op, ins, dbinfo)

    cont_w = detect_container_width(ro)

    addr_w = 64 if has_memory_operand(ro) else 0

    if _is_fp_sd(op) or op.endswith("sd") or op.endswith("comisd") or op.endswith("ucomisd"):
        return elem_w, 64, 128 if cont_w>=128 else 128, addr_w
    if _is_fp_ss(op) or op.endswith("ss") or op.endswith("comiss") or op.endswith("ucomiss"):
        return elem_w, 32, 128 if cont_w>=128 else 128, addr_w

    if op.startswith(("movzx","movsx")):
        dstw = dst_width_hint(ins) or 64
        dstw = dstw if dstw in (8,16,32,64) else 64
        return elem_w, dstw, 0, addr_w
    if op.startswith("movsxd"):
        return 32, 64, 0, addr_w
    if is_setcc(op):
        return 8, 8, 0, addr_w

    if op == "vmovq":
        return 64, 64, 128, addr_w
    if op == "vmovd":
        return 32, 32, 128, addr_w

    if op.startswith("vinsertf128"):
        cw = cont_w if cont_w >= 256 else 256
        return 32, 128, cw, addr_w
    if op.startswith("vextractf128"):
        cw = cont_w if cont_w >= 256 else 256
        return 32, 128, cw, addr_w

    if _is_fp_pd(op) or _is_fp_ps(op) or op.startswith("vp") or op in (
        "vmovapd","vmovupd","vmovaps","vmovups","vmovdqu","vmovdqa","vmovntdq",
        "vpxor","vpor","vpand","vpandn","vptest","vxorps","vxorpd","vorpd","vandpd","vandps",
        "vcmppd","vmaskmovpd","vmovups","vmovups","vpshufd","vpsrldq","vpsllq","vpsrlq",
        "vbroadcastss","vbroadcastsd","vmovddup","vmovhpd","vmovlpd","vinserti128","vextracti128",
        "vpsadbw","vpsubd","vpsubw","vpsubb","vpmulld","vpmullw","vpslld","vpsllw","vpsrlw","vpsrld",
        "vpsrad","vpblendvb","vpmaxsd","vpmovsxwd","vpmovzxbw","vpmovzxwd","vpackusdw","vpackuswb",
        "vbroadcastf128","vbroadcasti128"
    ):
        cw = cont_w if cont_w in (128,256,512) else 128
        return elem_w, cw, cw, addr_w

    dstw = dst_width_hint(ins)
    if dstw in (8,16,32,64):
        return elem_w, dstw, 0, addr_w
    smin = src_min_width_hint(ins)
    if smin in (8,16,32,64):
        return elem_w, smin, 0, addr_w

    bw = _compute_bw_legacy(ins)
    data_w = bw if bw in (8,16,32,64) else 64
    return elem_w, data_w, cont_w if cont_w>=128 else 0, addr_w


# Immediate handling
def get_imm_and_use(ins: Dict[str, Any]) -> Tuple[str, str]:
    op = ins.get("opcode", "").lower()
    ro = ins.get("raw_operands", [])
    if op == "test" and isinstance(ro, list) and len(ro) == 2:
        imm_hex = hex32(ro[1])
        use = "1'b1" if imm_hex != "32'h00000000" else "1'b0"
        return imm_hex, use
    return "32'h00000000", "1'b0"

def normalize_ff_to_stage(ff_idx: List[int], stage: int, n_insn: int,
                          opcats: Optional[List[str]] = None) -> List[int]:
    need = max(0, min(n_insn - 1, stage - 1))
    ff = sorted(i for i in set(ff_idx) if 0 <= i < n_insn - 1)

    if len(ff) == need:
        return ff

    def pri(i: int) -> Tuple[int, int]:
        if opcats:
            here_ctrl = 1 if (0 <= i < len(opcats) and opcats[i] == "ctrl") else 0
            next_ctrl = 1 if (0 <= i+1 < len(opcats) and opcats[i+1] == "ctrl") else 0
            is_ctrl_boundary = 1 if (here_ctrl or next_ctrl) else 0
        else:
            is_ctrl_boundary = 0
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
        if not cand:
            break
        j = min(range(len(cand)), key=lambda j: abs(cand[j] - t))
        add.append(cand.pop(j))
        if len(add) == missing:
            break
    add += cand[:(missing - len(add))]
    return sorted(ff + add[:missing])


# Emit package
def make_len_pkg(blocks: List[Dict[str, Any]], op_db: Dict[str, OpDbInfo],
                 debug_rows: Optional[List[List[Any]]] = None) -> str:
    n = len(blocks)
    max_len = max((len(b["instructions"]) for b in blocks), default=0)
    kind_code = {"load": "2'd1", "store": "2'd2", "rwm": "2'd3", None: "2'd0"}

    out: List[str] = []
    o = out.append

    stages: List[int] = []
    ff_lists: List[List[int]] = []
    for b in blocks:
        ff = derive_ff_boundaries(b)
        st = get_stage_count(b, ff, len(b['instructions']))
        stages.append(st)
        ff_lists.append(ff)

    norm_ff_lists: List[List[int]] = []
    for b, st, ff in zip(blocks, stages, ff_lists):
        n_insn = len(b["instructions"])
        opcats = b.get("opcats")
        ff_norm = normalize_ff_to_stage(ff, st, n_insn, opcats)
        assert len(ff_norm) == max(0, st-1), \
            f"ff normalization mismatch: need {st-1}, got {len(ff_norm)}"
        norm_ff_lists.append(ff_norm)

    o("package len_table_pkg;")
    o("  import uop_pkg::*;")
    o(f"  localparam int N_CASE = {n};")
    o(f"  localparam int MAX_LEN = {max_len};")

    # LEN
    o("  localparam int LEN_LUT [N_CASE] = '{")
    o(",\n".join(f"    {len(b['instructions'])}" for b in blocks))
    o("  };")

    # STAGE
    o("  localparam int STAGE_LUT [N_CASE] = '{")
    o(",\n".join(f"    {s}" for s in stages))
    o("  };")

    # FF MASK
    o("  /* FF boundaries bitmask per block */")
    o("  localparam logic [MAX_LEN-1:0] FF_MASK_LUT [N_CASE] = '{")
    ff_masks = [bits(ff_norm, len(b["instructions"])) for b, ff_norm in zip(blocks, norm_ff_lists)]
    o(",\n".join(f"    {m}" for m in ff_masks))
    o("  };")

    # OPS
    o("  localparam op_t OPS_LUT [N_CASE][MAX_LEN] = '{")
    for idx, b in enumerate(blocks):
        ops = [op_token(i["opcode"]) for i in b["instructions"]]
        ops += ["OP_NOP"] * (max_len - len(ops))
        o("    '{ " + ", ".join(ops) + " }" + ("," if idx < n - 1 else ""))
    o("  };")

    # MEM_KIND
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
    cont_max_lines: List[str] = []

    for bi, b in enumerate(blocks):
        ews: List[int] = []
        dws: List[int] = []
        cws: List[int] = []
        aws: List[int] = []
        data_max = 0
        cont_max = 0

        for ui, ins in enumerate(b.get("instructions", [])):
            op = str(ins.get("opcode", ""))
            dbi = op_db.get(op.lower())
            elem_w, data_w, cont_w, addr_w = compute_role_widths(op, ins, dbi)

            # sanitize
            if elem_w not in (8,16,32,64): elem_w = 64
            if data_w not in (8,16,32,64,128,256,512): data_w = 64
            if cont_w not in (0,128,256,512): cont_w = 0
            if addr_w not in (0,64): addr_w = 0

            ews.append(elem_w)
            dws.append(data_w)
            cws.append(cont_w)
            aws.append(addr_w)

            data_max = max(data_max, data_w)
            cont_max = max(cont_max, cont_w)

            if debug_rows is not None:
                ro = " ".join(map(str, ins.get("raw_operands") or []))
                bw_legacy = _compute_bw_legacy(ins)
                debug_rows.append([bi, ui, op, elem_w, data_w, cont_w, addr_w, bw_legacy, ro])

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
        cont_max_lines.append(f"    {cont_max}")

    # ELEM_W_LUT
    o("  /* Element width per uop (8/16/32/64) */")
    o("  localparam int ELEM_W_LUT [N_CASE][MAX_LEN] = '{")
    o(",\n".join(ew_rows))
    o("  };")

    # BW_LUT 
    o("  /* Data width per uop: integer/scalar FP => 8~64, vector => 128/256/512 */")
    o("  localparam int BW_LUT [N_CASE][MAX_LEN] = '{")
    o(",\n".join(data_rows))
    o("  };")

    # BW_MAX_LUT 
    o("  localparam int BW_MAX_LUT [N_CASE] = '{")
    o(",\n".join(data_max_lines))
    o("  };")

    o("  /* Vector container width (XMM=128/YMM=256/ZMM=512), scalar=0 or 128 for sd/ss context */")
    o("  localparam int CONT_W_LUT [N_CASE][MAX_LEN] = '{")
    o(",\n".join(cont_rows))
    o("  };")

    o("  /* Address path width: 64 when memory operand exists, else 0 */")
    o("  localparam int ADDR_W_LUT [N_CASE][MAX_LEN] = '{")
    o(",\n".join(addr_rows))
    o("  };")

    # IMM / USE_IMM
    imm_rows: List[str] = []
    use_rows: List[str] = []
    for b in blocks:
        imms: List[str] = []
        uses: List[str] = []
        for ins in b["instructions"]:
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

    for i, (b, st, ff_norm) in enumerate(zip(blocks, stages, norm_ff_lists)):
        need = max(0, st - 1)
        if len(ff_norm) != need:
            print(f"[WARN] case {i}: stage={st}, ff={len(ff_norm)} (len={len(b['instructions'])})")

    return "\n".join(out) + "\n"


# Tcl
def make_pipe_tcl(blocks: List[Dict[str, Any]]) -> str:
    tmpl = 'set_property PIPE_STAGES {ST} [get_cells -hier -filter {NAME =~ "*glen[{IDX}].blk_i"}]\n'
    lines: List[str] = []
    for i, b in enumerate(blocks):
        ff = derive_ff_boundaries(b)
        st = get_stage_count(b, ff, len(b["instructions"]))
        lines.append(tmpl.replace("{ST}", str(st)).replace("{IDX}", str(i)))
    return "".join(lines)

def is_bench_dir(p: Path) -> bool:
    return (p / "blocks").is_dir() or (p / "bench_blocks.json").is_file()


# Driver
def run_one_bench(bench_dir: Path,
                  sv_out: Optional[Path],
                  tcl_out: Optional[Path],
                  op_db: Dict[str, OpDbInfo],
                  debug_path: Optional[Path]) -> None:
    blocks = load_blocks(bench_dir)
    if not blocks:
        print(f"[WARN] {bench_dir}: no blocks")
        return

    if sv_out is None:
        sv_out = bench_dir / "len_table_pkg.sv"
    if tcl_out is None:
        tcl_out = bench_dir / "pipe_stages.tcl"

    debug_rows_list: Optional[List[List[Any]]] = [] if debug_path else None
    pkg_txt = make_len_pkg(blocks, op_db, debug_rows_list)
    tcl_txt = make_pipe_tcl(blocks)

    sv_out.parent.mkdir(parents=True, exist_ok=True)
    tcl_out.parent.mkdir(parents=True, exist_ok=True)

    sv_out.write_text(pkg_txt, encoding="utf-8", newline="\n")
    tcl_out.write_text(tcl_txt, encoding="utf-8", newline="\n")

    if debug_rows_list is not None:
        with open(debug_path, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["block_idx","uop_idx","opcode",
                        "elem_w","data_w","cont_w","addr_w","bw_legacy","raw_operands"])
            w.writerows(debug_rows_list)

    print(f"[OK] {bench_dir.name}: N_BLOCKS={len(blocks)} -> {sv_out.name}, {tcl_out.name}")

def main():
    ap = argparse.ArgumentParser(description="Generate len_table_pkg.sv & pipe_stages.tcl")
    ap.add_argument("src", help="bench dir, root dir, or json file")
    ap.add_argument("--sv-out", default=None, help="override path for single bench (sv)")
    ap.add_argument("--tcl-out", default=None, help="override path for single bench (tcl)")
    ap.add_argument("--opcode-db", type=Path, default=None, help="opcode_details.csv path (optional)")
    ap.add_argument("--debug-ew", type=Path, default=None, help="dump per-uop width decision CSV")
    args = ap.parse_args()

    src = Path(args.src).resolve()
    op_db = load_opcode_db(args.opcode_db)

    if src.is_dir() and not is_bench_dir(src):
        benches = [p for p in sorted(src.iterdir()) if p.is_dir() and is_bench_dir(p)]
        if not benches:
            sys.exit(f"No bench dirs under {src}")
        for b in benches:
            run_one_bench(b, None, None, op_db, args.debug_ew)
    else:
        if src.is_file():
            bench_dir = src.parent
            run_one_bench(bench_dir,
                          Path(args.sv_out) if args.sv_out else None,
                          Path(args.tcl_out) if args.tcl_out else None,
                          op_db,
                          args.debug_ew)
        else:
            run_one_bench(src,
                          Path(args.sv_out) if args.sv_out else None,
                          Path(args.tcl_out) if args.tcl_out else None,
                          op_db,
                          args.debug_ew)

if __name__ == "__main__":
    main()