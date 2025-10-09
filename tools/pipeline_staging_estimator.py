from __future__ import annotations
import argparse, csv, json, re, sys
from collections import deque, defaultdict
from dataclasses import dataclass, asdict
from pathlib import Path
from statistics import pstdev
from typing import Dict, List, Optional, Set, Tuple

_CMOV_RE  = re.compile(r"^cmov([a-z]+)$", re.I)
_SETCC_RE = re.compile(r"^set([a-z]+)$", re.I)
_JCC_RE   = re.compile(r"^j([a-z]+)$", re.I)

FLAGS = {"CF","ZF","SF","OF","PF","AF"}

_CC_NEEDS: Dict[str, Set[str]] = {
    "z": {"ZF"}, "nz": {"ZF"},
    "c": {"CF"}, "nc": {"CF"}, "b": {"CF"}, "nb": {"CF"}, "nae": {"CF"}, "ae": {"CF"},
    "o": {"OF"}, "no": {"OF"},
    "s": {"SF"}, "ns": {"SF"},
    "p": {"PF"}, "pe": {"PF"}, "np": {"PF"}, "po": {"PF"},
    "be": {"CF","ZF"}, "na": {"CF","ZF"},
    "a": {"CF","ZF"}, "nbe": {"CF","ZF"},
    "l": {"SF","OF"}, "nge": {"SF","OF"},
    "ge": {"SF","OF"}, "nl": {"SF","OF"},
    "le": {"SF","OF","ZF"}, "ng": {"SF","OF","ZF"},
    "g": {"SF","OF","ZF"}, "nle": {"SF","OF","ZF"},
}

_ARITH_RW = {"CF","ZF","SF","OF","PF","AF"}
_INCDEC_RW = {"ZF","SF","OF","PF","AF"}
_LOGIC_RW = {"CF","ZF","SF","OF","PF"}
_SHFT_RW  = {"CF","ZF","SF","OF","PF"}

_FLAG_READS: Dict[str, Set[str]] = defaultdict(set)
_FLAG_WRITES: Dict[str, Set[str]] = defaultdict(set)

for op in ("add","sub","cmp","neg"): _FLAG_WRITES[op] = set(_ARITH_RW)
for op in ("and","or","xor","test","andn"): _FLAG_WRITES[op] = set(_LOGIC_RW)
for op in ("shl","sal","shr","sar","rol","ror","shld","shrd","shlx","shrx","sarx"): _FLAG_WRITES[op] = set(_SHFT_RW)
for op in ("inc","dec"): _FLAG_WRITES[op] = set(_INCDEC_RW)
_FLAG_READS["adc"] = {"CF"}; _FLAG_WRITES["adc"] = set(_ARITH_RW)
_FLAG_READS["sbb"] = {"CF"}; _FLAG_WRITES["sbb"] = set(_ARITH_RW)
_FLAG_WRITES["cmp"]  = set(_ARITH_RW)
_FLAG_WRITES["test"] = set(_LOGIC_RW)
for op in ("bt","bts","btr","btc"): _FLAG_WRITES[op] = {"CF","ZF"}
for op in ("mul","imul","div","idiv"): _FLAG_WRITES[op] = {"CF","OF"}
for op in ("comisd","ucomisd","comiss","ucomiss"): _FLAG_WRITES[op] = {"ZF","CF","PF","OF","SF"}

_rx_rxx   = re.compile(r"r(1[0-5]|[8-9])([bdw])?$", re.I)
_rx_gpr64 = {"RAX","RBX","RCX","RDX","RSI","RDI","RBP","RSP"}
_map_legacy = {
    "EAX":"RAX","AX":"RAX","AH":"RAX","AL":"RAX",
    "EBX":"RBX","BX":"RBX","BH":"RBX","BL":"RBX",
    "ECX":"RCX","CX":"RCX","CH":"RCX","CL":"RCX",
    "EDX":"RDX","DX":"RDX","DH":"RDX","DL":"RDX",
    "ESI":"RSI","SI":"RSI","SIL":"RSI",
    "EDI":"RDI","DI":"RDI","DIL":"RDI",
    "EBP":"RBP","BP":"RBP","BPL":"RBP",
    "ESP":"RSP","SP":"RSP","SPL":"RSP",
}
_rx_vec = re.compile(r"(zmm|ymm|xmm)(\d+)$", re.I)
_rx_mmx = re.compile(r"mm(\d+)$", re.I)
_rx_k   = re.compile(r"k(\d+)$", re.I)

def is_flag(tok: str) -> bool:
    return isinstance(tok, str) and tok.lower() == "flag"

def _has_mem_brackets(s: str) -> bool:
    try:
        s = (s or "").lower()
        return "[" in s and "]" in s
    except Exception:
        return False

def canon_reg(tok: str) -> Optional[str]:
    if not isinstance(tok, str): return None
    t = tok.strip().upper()
    if is_flag(t) or _has_mem_brackets(t): return None
    if t in _map_legacy: return _map_legacy[t]
    if t in _rx_gpr64: return t
    if _rx_rxx.fullmatch(t):
        b = t[:t.find("D")] if "D" in t else t
        b = b[:t.find("W")] if "W" in b else b
        b = b[:t.find("B")] if "B" in b else b
        return b.upper()
    m = _rx_vec.fullmatch(t)
    if m: return f"ZMM{m.group(2)}"
    m = _rx_mmx.fullmatch(t)
    if m: return f"MM{m.group(1)}"
    m = _rx_k.fullmatch(t)
    if m: return f"K{m.group(1)}"
    if re.fullmatch(r"(CS|DS|ES|FS|GS|SS)", t): return t
    return None

_REG_W = {
    "al":8,"ah":8,"ax":16,"eax":32,"rax":64,
    "bl":8,"bh":8,"bx":16,"ebx":32,"rbx":64,
    "cl":8,"ch":8,"cx":16,"ecx":32,"rcx":64,
    "dl":8,"dh":8,"dx":16,"edx":32,"rdx":64,
    "sil":8,"si":16,"esi":32,"rsi":64,
    "dil":8,"di":16,"edi":32,"rdi":64,
    "spl":8,"sp":16,"esp":32,"rsp":64,
    "bpl":8,"bp":16,"ebp":32,"rbp":64,
}
_R_RE = re.compile(r"r(1[0-5]|[8-9])(b|w|d)?$", re.I)

def _gpr_width(tok: str) -> int:
    t = (tok or "").lower()
    if t in _REG_W: return _REG_W[t]
    m = _R_RE.fullmatch(t)
    if m:
        suf = (m.group(2) or "").lower()
        return 8 if suf=="b" else 16 if suf=="w" else 32 if suf=="d" else 64
    if t in {"rax","rbx","rcx","rdx","rsi","rdi","rbp","rsp"}: return 64
    return 0

def tight_data_width(u: dict) -> int:
    op = (u.get("opcode") or "").lower()
    ro = (u.get("raw_operands") or [])
    ins= (u.get("in_operands") or [])
    outs=(u.get("out_operands") or [])
    if op.startswith("set"):            return 8
    if op.startswith("movsxd"):         return 64
    if op == "cdqe":                    return 64
    if op == "cdq":                     return 64
    if op.startswith("movsx"):
        cands = [_gpr_width(x) for x in (ro or ins)]
        smin  = min([w for w in cands if w in (8,16,32)], default=8)
        dstw  = max(_gpr_width(x) for x in outs) or 64
        return max(smin, dstw) if dstw<=64 else 64
    if op.startswith("movzx"):
        cands = [_gpr_width(x) for x in (ro or ins)]
        smin  = min([w for w in cands if w in (8,16)], default=8)
        dstw  = max(_gpr_width(x) for x in outs) or 64
        return max(smin, dstw) if dstw<=64 else 64
    dstw = max((_gpr_width(x) for x in outs), default=0)
    if dstw in (8,16,32,64): return dstw
    srcw = max((_gpr_width(x) for x in (ins + ro)), default=0)
    if srcw in (8,16,32,64): return srcw
    return 64

_READONLY_MEM_FIRST = {"cmp","test","vcomisd","ucomisd","comisd","comiss","ucomiss"}
_RMW_MEM_FIRST = {
    "add","sub","and","or","xor","adc","sbb",
    "inc","dec","neg","not",
    "bt","bts","btr","btc",
    "shl","shr","sar","rol","ror",
    "xchg","xadd","cmpxchg",
}
_ATOMIC_OPS = {"xchg","xadd","cmpxchg"}
_MEMW_RE = re.compile(r"(?i)\b(byte|word|dword|qword|oword|dqword|tword|xmmword|ymmword|zmmword)\s+ptr")

def is_mem_src(u: dict) -> bool:
    op  = (u.get("opcode") or "").lower()
    if op == "lea": return False
    ops = u.get("raw_operands") or []
    if any("[" in str(x) and "]" in str(x) for x in ops[1:]):
        return True
    if ops and "[" in str(ops[0]) and "]" in str(ops[0]) and op in _READONLY_MEM_FIRST:
        return True
    if ops and "[" in str(ops[0]) and "]" in str(ops[0]) and op in _RMW_MEM_FIRST:
        return True
    return False

def is_mem_dst(u: dict) -> bool:
    op  = (u.get("opcode") or "").lower()
    ops = u.get("raw_operands") or []
    if not ops: return False
    if not ("[" in str(ops[0]) and "]" in str(ops[0])): return False
    if op in _RMW_MEM_FIRST: return True
    if op in {"mov","movbe"}: return True
    return False

class CombModel:
    BASE: Dict[str, int] = {
        "MOV":0,"LEA":0,"NOP":0,
        "MOVSX":1,"MOVSXD":1,"MOVZX":1,"MOVBE":1,"BSWAP":1,
        "CDQE":1,"CDQ":0,
        "AND":1,"ANDN":1,"OR":1,"XOR":1,"NOT":1,"TEST":1,
        "ADD":1,"SUB":1,"NEG":1,"INC":1,"DEC":1,"CMP":1,
        "ADC":1,"SBB":1,
        "SHL":1,"SAL":1,"SHR":1,"SAR":1,"ROL":1,"ROR":1,"SHLD":2,"SHRD":2,
        "RORX":1,"SHRX":1,"SHLX":1,"SARX":1,
        "BT":1,"BTC":1,"BTR":1,"BTS":1,"BLSI":1,"BLSR":1,"BZHI":1,
        "BSF":2,"BSR":2,"TZCNT":2,"LZCNT":2,
        "IMUL":2,"MUL":2,"IDIV":6,"DIV":6,
        "VCOMISD":2,"UCOMISD":2,"COMISD":2,
    }
    @classmethod
    def latency(cls, op: str, bw: int) -> int:
        o = (op or "").upper()
        if o in {"ADD","SUB","ADC","SBB"} and bw >= 64:
            return 2
        return cls.BASE.get(o, 1)

def dsp_need(op: str, bw: int) -> int:
    o = (op or "").upper()
    if o in {"IMUL","MUL"}:
        from math import ceil
        return max(1, ceil(bw/27) * ceil(bw/18))
    if o in {"FMUL","FPMUL"}:
        return 11 if bw >= 64 else 3
    if o in {"FMA","FPFMA"}:
        return 17 if bw >= 64 else 5
    return 0

def maps_to_dsp(op: str, bw: int) -> bool:
    o = (op or "").upper()
    return o in {"IMUL","MUL","FMUL","FPMUL","FMA","FPFMA"}

def op_class(u: dict) -> str:
    op = (u.get("opcode") or "").upper()
    ld, st = is_mem_src(u), is_mem_dst(u)
    if ld and st: return "RMW"
    if ld: return "LOAD"
    if st: return "STORE"
    if op in {"IMUL","MUL"}: return "IMUL"
    if op in {"IDIV","DIV"}: return "IDIV"
    return op

_mem_bracket_re = re.compile(r'(?i)(?:[a-z]+\s+)?ptr\s*\[(?P<expr>[^\]]+)\]')
_num_re = re.compile(r'(?i)^(-?\s*(?:0x[0-9a-f]+|\d+))$')
_term_re = re.compile(r'(?i)^\s*([a-z][a-z0-9]+)\s*(?:\*\s*([1248]))?\s*$')

def _parse_disp(tok:str)->int:
    tok = tok.replace(' ','')
    sign = 1
    if tok.startswith('-'):
        sign = -1
        tok = tok[1:]
    try:
        if tok.lower().startswith('0x'):
            return sign*int(tok,16)
        return sign*int(tok)
    except Exception:
        return 0

def _classify_space(base: Optional[str]) -> str:
    if base == "RIP": return "RODATA"
    if base in {"RSP","RBP"}: return "STACK"
    return "GEN"

def _mem_width_bits(tok:str)->int:
    if not isinstance(tok,str): return 0
    m = _MEMW_RE.search(tok)
    if not m: return 0
    k = m.group(1).lower()
    return (
        8  if k=="byte"   else 16 if k=="word"   else 32 if k=="dword" else
        64 if k=="qword"  else 128 if k in {"oword","xmmword"} else
        256 if k in {"ymmword","dqword"} else 512 if k=="zmmword" else 0
    )

@dataclass(frozen=True)
class AddrKey:
    base: Optional[str]
    index: Optional[str]
    scale: int
    disp: int
    space: str
    width: int

def parse_addr(opnd: str, reg_alias: Dict[str,AddrKey]) -> Tuple[Optional[AddrKey], bool]:
    if not isinstance(opnd, str): return (None, False)
    s = opnd.strip()
    m = _mem_bracket_re.search(s)
    if not m: return (None, False)
    expr = m.group('expr')
    expr = expr.replace('-', '+-')
    terms = [t.strip() for t in expr.split('+') if t.strip()]
    base = None; index=None; scale=1; disp=0; precise=True
    for t in terms:
        if _num_re.match(t):
            disp += _parse_disp(t); continue
        tm = _term_re.match(t)
        if tm:
            reg = canon_reg(tm.group(1) or "")
            scl = int(tm.group(2)) if tm.group(2) else 1
            if reg is None: precise=False; continue
            if reg in reg_alias:
                ak = reg_alias[reg]
                disp += ak.disp
                base = base or ak.base
                if ak.index and (index is None):
                    index = ak.index; scale *= ak.scale
                elif ak.index:
                    precise=False
            else:
                if base is None: base = reg
                elif index is None: index = reg; scale = scl
                else: precise=False
            continue
        precise=False
    space = _classify_space(base)
    width = _mem_width_bits(opnd) or 0
    return (AddrKey(base, index, scale, disp, space, width), precise)

def _ranges_overlap(a:AddrKey, b:AddrKey) -> bool:
    if (a.space, a.base, a.index, a.scale) != (b.space, b.base, b.index, b.scale):
        return False
    aB = max(1, (a.width or 8)//8)
    bB = max(1, (b.width or 8)//8)
    a0, a1 = a.disp, a.disp + aB
    b0, b1 = b.disp, b.disp + bB
    return not (a1 <= b0 or b1 <= a0)

@dataclass
class Node:
    idx: int
    op: str
    bw: int
    comb: int
    dsp: int
    lut: int
    is_load: bool = False
    is_store: bool = False
    succ: int = 0
    cls: str = "ALU"
    mem_keys: List[AddrKey] = None
    mem_precise: bool = False
    flag_reads: Set[str] = None
    flag_writes: Set[str] = None
    is_atomic: bool = False

def _add_edge(edges:Set[Tuple[int,int]], a:int, b:int) -> None:
    if a != b: edges.add((a,b))

def _build_index_map(uops: List[dict]) -> Dict[int,int]:
    mp={}
    for i,u in enumerate(uops):
        if "index" in u and isinstance(u["index"], int): mp[u["index"]] = i
    return mp

def _flags_for_opcode(op: str) -> Tuple[Set[str], Set[str]]:
    o = (op or "").lower()
    m = _CMOV_RE.match(o)
    if m:
        cc = m.group(1).lower(); return (set(_CC_NEEDS.get(cc, set())), set())
    m = _SETCC_RE.match(o)
    if m:
        cc = m.group(1).lower(); return (set(_CC_NEEDS.get(cc, set())), set())
    m = _JCC_RE.match(o)
    if m:
        cc = m.group(1).lower(); return (set(_CC_NEEDS.get(cc, set())), set())
    return (set(_FLAG_READS[o]), set(_FLAG_WRITES[o]))

def split_rw_sets(u: dict) -> Tuple[Set[str], Set[str], Set[str], Set[str], str]:
    ins = set([x for x in (u.get("in_operands") or []) if isinstance(x, str)])
    outs= set([x for x in (u.get("out_operands") or []) if isinstance(x, str)])
    read_regs, write_regs = set(), set()
    def _canon(tok: str) -> Optional[str]:
        t = (tok or "").strip().upper()
        if is_flag(t) or _has_mem_brackets(t): return None
        if t in _map_legacy: return _map_legacy[t]
        if t in _rx_gpr64: return t
        if _rx_rxx.fullmatch(t):
            b = t[:t.find("D")] if "D" in t else t
            b = b[:t.find("W")] if "W" in b else b
            b = b[:t.find("B")] if "B" in b else b
            return b.upper()
        if re.fullmatch(r"(CS|DS|ES|FS|GS|SS)", t): return t
        return None
    for x in ins:
        c = _canon(x)
        if c: read_regs.add(c)
    for x in outs:
        c = _canon(x)
        if c: write_regs.add(c)
    opc = (u.get("opcode") or "")
    freads, fwrites = _flags_for_opcode(opc)
    return read_regs, write_regs, freads, fwrites, opc

def build_dag(group: dict, strict_merge: bool):
    uops   = group.get("instructions", []) or []
    merges = group.get("merge_edges", []) or []
    edges: Set[Tuple[int,int]] = set()
    nodes: List[Node] = []

    reg_addr_alias: Dict[str,AddrKey] = {}
    for u in uops:
        op = (u.get("opcode") or "").lower()
        outs = [canon_reg(x) for x in (u.get("out_operands") or []) if isinstance(x,str)]
        ins  = u.get("in_operands") or []
        ros  = u.get("raw_operands") or []
        if op == "lea" and outs:
            ak, ok = parse_addr(ins[0] if ins else "", reg_alias=reg_addr_alias)
            if ak and ok:
                reg_addr_alias[outs[0]] = ak
        elif op == "mov" and outs and len(ins)==1 and isinstance(ins[0], str) and canon_reg(ins[0]):
            src = canon_reg(ins[0])
            if src in reg_addr_alias:
                reg_addr_alias[outs[0]] = reg_addr_alias[src]
        elif outs:
            dst = outs[0]
            if dst in reg_addr_alias:
                if op in {"add","sub"} and len(ros)>=2 and isinstance(ros[1], str):
                    imm_m = re.fullmatch(r"\s*(-?\s*(?:0x[0-9a-fA-F]+|\d+))\s*", ros[1])
                    if imm_m:
                        val = int(imm_m.group(1), 0)
                        ak = reg_addr_alias[dst]
                        if op == "sub": val = -val
                        reg_addr_alias[dst] = AddrKey(ak.base, ak.index, ak.scale, ak.disp + val, ak.space, ak.width)
                elif op in {"inc","dec"}:
                    ak = reg_addr_alias[dst]
                    val = 1 if op=="inc" else -1
                    reg_addr_alias[dst] = AddrKey(ak.base, ak.index, ak.scale, ak.disp + val, ak.space, ak.width)
                elif op == "shl" and len(ros)>=2:
                    k_m = re.fullmatch(r"\s*(\d+)\s*", str(ros[1]))
                    if k_m:
                        k = int(k_m.group(1)); k = max(0, min(3, k))
                        mul = (1<<k)
                        ak = reg_addr_alias[dst]
                        reg_addr_alias[dst] = AddrKey(ak.base, ak.index, ak.scale*mul, ak.disp*mul, ak.space, ak.width)
                else:
                    reg_addr_alias.pop(dst, None)

    for i,u in enumerate(uops):
        bw   = tight_data_width(u)
        base = CombModel.latency(u.get("opcode",""), bw)
        ld   = is_mem_src(u)
        st   = is_mem_dst(u)
        opc0 = (u.get("opcode") or "").upper()
        use_dsp = maps_to_dsp(opc0, bw)
        dsp  = dsp_need(opc0, bw)
        comb = 2 if use_dsp else base
        if not use_dsp and opc0 in {"ADD","SUB","ADC","SBB"} and bw >= 64:
            comb = 2
        lut  = max(1, (bw + 31)//32)
        mem_keys: List[AddrKey] = []
        mem_precise = True
        ro = u.get("raw_operands") or []
        for tok in ro:
            ak, ok = parse_addr(str(tok), reg_alias=reg_addr_alias)
            if ak:
                w = ak.width or bw
                ak = AddrKey(ak.base, ak.index, ak.scale, ak.disp, ak.space, w)
                mem_keys.append(ak); mem_precise = mem_precise and ok
        _, _, flag_reads, flag_writes, opc_raw = split_rw_sets(u)
        is_atomic = ((opc_raw or "").lower() in _ATOMIC_OPS) and st
        nodes.append(Node(i, opc0, bw, comb, dsp, lut, ld, st, 0, op_class(u), mem_keys, mem_precise,
                          flag_reads=flag_reads, flag_writes=flag_writes, is_atomic=is_atomic))

    n = len(uops)
    if merges:
        idx_map = _build_index_map(uops)
        for me in merges:
            frm=(me.get("from") or {}).get("instr_index")
            to =(me.get("to")   or {}).get("instr_index")
            a = idx_map.get(frm, frm) if isinstance(frm,int) else None
            b = idx_map.get(to,  to ) if isinstance(to, int) else None
            if isinstance(a,int) and isinstance(b,int): _add_edge(edges, a, b)
    else:
        if strict_merge:
            raise RuntimeError("merge_edges missing; strict mode")
        for i in range(1, n): _add_edge(edges, i-1, i)

    rwinfo = [split_rw_sets(u) for u in uops]
    reads  = [r for (r,_,__,___,____) in rwinfo]
    writes = [w for (_,w,__,___,____) in rwinfo]
    freg_r = [fr for (_,__,fr,___,____) in rwinfo]
    freg_w = [fw for (_,__,___,fw,____) in rwinfo]
    add_raw=add_war=add_waw=0
    for i in range(n):
        wi, ri = writes[i], reads[i]
        for j in range(i+1, n):
            wj, rj = writes[j], reads[j]
            if (wi & rj) and (i,j) not in edges: _add_edge(edges, i, j); add_raw += 1
            if (ri & wj) and (i,j) not in edges: _add_edge(edges, i, j); add_war += 1
            if (wi & wj) and (i,j) not in edges: _add_edge(edges, i, j); add_waw += 1

    def _addr_regs_modified_between(i:int, j:int, a:AddrKey)->bool:
        touch = set(x for x in (a.base, a.index) if x)
        if not touch: return False
        for k in range(i+1, j+1):
            if writes[k] & touch:
                return True
        return False

    def _may_alias(a:AddrKey, b:AddrKey, precise_pair:bool, isW_i:bool, isW_j:bool)->bool:
        if not (isW_i or isW_j): return False
        if a.space != b.space:   return False
        same_tuple = (a.base, a.index, a.scale) == (b.base, b.index, b.scale)
        if precise_pair and same_tuple and (not _ranges_overlap(a,b)):
            return False
        return True

    add_mem_raw=add_mem_war=add_mem_waw=add_mem_cons=add_mem_rar=0
    for i in range(n):
        mi = nodes[i].mem_keys
        if not mi: continue
        for j in range(i+1, n):
            mj = nodes[j].mem_keys
            if not mj: continue
            isR_i = nodes[i].is_load and not nodes[i].is_store
            isW_i = nodes[i].is_store or nodes[i].is_atomic or (nodes[i].cls == "RMW")
            isR_j = nodes[j].is_load and not nodes[j].is_store
            isW_j = nodes[j].is_store or nodes[j].is_atomic or (nodes[j].cls == "RMW")
            dep=False
            for a in mi:
                for b in mj:
                    precise_pair = nodes[i].mem_precise and nodes[j].mem_precise
                    if _addr_regs_modified_between(i,j,a) or _addr_regs_modified_between(i,j,b):
                        precise_pair = False
                    if not (isW_i or isW_j):
                        same_tuple = (a.base,a.index,a.scale)==(b.base,b.index,b.scale)
                        if precise_pair and same_tuple and _ranges_overlap(a,b):
                            add_mem_rar += 1
                        continue
                    if _may_alias(a,b,precise_pair,isW_i,isW_j):
                        dep=True
                        if precise_pair:
                            if isW_i and isW_j: add_mem_waw += 1
                            elif isW_i and isR_j: add_mem_raw += 1
                            elif isR_i and isW_j: add_mem_war += 1
                        else:
                            add_mem_cons += 1
                    if dep: break
                if dep: break
            if dep and (i,j) not in edges:
                _add_edge(edges, i, j)

    atomic_idxs = [i for i,nd in enumerate(nodes) if nd.is_atomic]
    for i in atomic_idxs:
        ai = nodes[i]
        for j in range(n):
            if i==j: continue
            bj = nodes[j]
            if not bj.mem_keys: continue
            if any(ak.space==bk.space for ak in (ai.mem_keys or []) for bk in (bj.mem_keys or [])):
                if j < i: _add_edge(edges, j, i)
                else:     _add_edge(edges, i, j)

    add_flag_wr = 0; add_flag_anti = 0
    for j in range(n):
        need = freg_r[j]
        if not need: continue
        writers_of: Dict[str, List[int]] = defaultdict(list)
        for i in range(j):
            for f in (freg_w[i] & need):
                writers_of[f].append(i)
        if not writers_of: continue
        p = max(i for lst in writers_of.values() for i in lst)
        if (p, j) not in edges:
            _add_edge(edges, p, j); add_flag_wr += 1
        for k in range(p+1, j):
            if freg_w[k] & need:
                if (j, k) not in edges:
                    _add_edge(edges, j, k); add_flag_anti += 1

    for a,b in edges:
        nodes[a].succ += 1

    estats = {
        "base_edges": len(merges) if merges else 0,
        "added_flag_wr": add_flag_wr,
        "added_flag_anti": add_flag_anti,
        "added_raw": add_raw,
        "added_war": add_war,
        "added_waw": add_waw,
        "added_mem_raw": add_mem_raw,
        "added_mem_war": add_mem_war,
        "added_mem_waw": add_mem_waw,
        "added_mem_conservative": add_mem_cons,
        "added_mem_rar": add_mem_rar,
        "final_edges": len(edges),
    }
    return nodes, edges, estats

def topo_sort(n:int, edges:Set[Tuple[int,int]]):
    succ=[[] for _ in range(n)]; indeg=[0]*n
    for a,b in edges: succ[a].append(b); indeg[b]+=1
    q=deque(i for i,d in enumerate(indeg) if d==0); order=[]
    while q:
        u=q.popleft(); order.append(u)
        for v in succ[u]:
            indeg[v]-=1
            if indeg[v]==0: q.append(v)
    if len(order)!=n:
        raise RuntimeError("Cycle detected in DAG (hazard/merge_edges)")
    return order, succ

@dataclass
class StageMetric:
    comb:int=0; dsp:int=0; lut:int=0; cong:int=0; ops:int=0
    dops:int=0
    chain64:int=0; chain32:int=0; chain8:int=0

def _edge_weight(prod:int, nodes:List[Node]) -> int:
    n = nodes[prod]
    return 1 if (n.is_load or n.is_store or n.cls == "RMW" or n.is_atomic) else 0

@dataclass
class MemPorts:
    rd:int=2; wr:int=2; rlat:int=2; total:int=2

DEFAULT_PORTS = {
    "RODATA": MemPorts(rd=2, wr=0, rlat=2, total=2),
    "STACK":  MemPorts(rd=1, wr=1, rlat=2, total=2),
    "GEN":    MemPorts(rd=2, wr=2, rlat=2, total=2),
}

def _mem_key_for_calendar(ak:AddrKey)->Tuple[str,str]:
    return (ak.space, ak.base or "NONE")

ARCH = {
    "board": "Alveo U200",
    "family": "UltraScale+",
    "target_mhz": 300,
    "tclk_ns": 1e3/300.0,
    "clb": {"lut": 8, "ff": 16},
    "dsp": {"type":"DSP48E2"},
    "bram": {"type":"RAMB18/36", "rdlat": 2},
}

COMB_BUDGET       = 5
LUT_BUDGET        = 24
CONG_BUDGET       = 48
OPS_BUDGET        = 5
CHAIN_BUDGET_64   = 2
CHAIN_BUDGET_32   = 5
CHAIN_BUDGET_8    = 8
CONG_NODE_CAP     = 32
ALLOW_DOMINANT_FANOUT_NODE = False

DSP_BUDGET_PER_STAGE    = 64
DSP_OPS_BUDGET_PER_STAGE= 3

def _is_alu(n:Node)->bool:
    base = n.op.split('_',1)[0]
    return (not n.is_load) and (not n.is_store) and base not in {"IDIV","DIV"}

def _is_chain_sensitive(n:Node)->bool:
    base = n.op.split('_',1)[0]
    return base in {"ADD","SUB","ADC","SBB","IMUL","MUL","SHLD","SHRD","INC","DEC","NEG"}

def _wclass(n:Node)->int:
    return 64 if n.bw >= 64 else (32 if n.bw >= 32 else 8)

def _would_increase_chain(u:int, s:int, preds:List[Set[int]], nodes:List[Node], stage_of:List[int])->int:
    ps = [p for p in preds[u] if stage_of[p]==s]
    if len(ps)==1 and _is_alu(nodes[ps[0]]) and _is_alu(nodes[u]) and _is_chain_sensitive(nodes[ps[0]]) and _is_chain_sensitive(nodes[u]):
        return 1
    return 0

def _fanout_cost(n: Node) -> int:
    c = n.succ * max(1, n.comb)
    if CONG_NODE_CAP is not None:
        c = min(c, CONG_NODE_CAP)
    return c

def _fits_budget_for_node(n:Node, sm:StageMetric, chain_inc:int)->bool:
    if COMB_BUDGET  is not None and (sm.comb + n.comb) > COMB_BUDGET: return False
    if LUT_BUDGET   is not None and (sm.lut  + n.lut ) > LUT_BUDGET:  return False
    if CONG_BUDGET  is not None:
        inc = _fanout_cost(n)
        if (sm.cong + inc) > CONG_BUDGET:
            if not (ALLOW_DOMINANT_FANOUT_NODE and sm.comb==0 and sm.ops==0 and sm.lut==0):
                return False
    ops_inc = 0 if n.comb==0 else 1
    if OPS_BUDGET   is not None and (sm.ops + ops_inc) > OPS_BUDGET:  return False
    if DSP_BUDGET_PER_STAGE is not None and (sm.dsp + n.dsp) > DSP_BUDGET_PER_STAGE: return False
    if DSP_OPS_BUDGET_PER_STAGE is not None and (sm.dops + (1 if n.dsp>0 else 0)) > DSP_OPS_BUDGET_PER_STAGE: return False
    wc = _wclass(n)
    if wc==64 and (sm.chain64 + chain_inc) > CHAIN_BUDGET_64: return False
    if wc==32 and (sm.chain32 + chain_inc) > CHAIN_BUDGET_32: return False
    if wc==8  and (sm.chain8  + chain_inc) > CHAIN_BUDGET_8:  return False
    return True

def _accumulate_node(n:Node, sm:StageMetric, chain_inc:int)->None:
    sm.comb += n.comb; sm.dsp += n.dsp; sm.lut += n.lut
    sm.cong += _fanout_cost(n)
    if n.comb>0: sm.ops  += 1
    if n.dsp>0:  sm.dops += 1
    if   _wclass(n)==64: sm.chain64 += chain_inc
    elif _wclass(n)==32: sm.chain32 += chain_inc
    else:                sm.chain8  += chain_inc

def _not_fit_reasons(n:Node, sm:StageMetric, chain_inc:int)->List[str]:
    r=[]
    if COMB_BUDGET  is not None and (sm.comb + n.comb) > COMB_BUDGET: r.append(f"comb {sm.comb+n.comb}>{COMB_BUDGET}")
    if LUT_BUDGET   is not None and (sm.lut  + n.lut ) > LUT_BUDGET:  r.append(f"lut {sm.lut+n.lut}>{LUT_BUDGET}")
    inc = _fanout_cost(n)
    if CONG_BUDGET  is not None and (sm.cong + inc) > CONG_BUDGET:    r.append(f"cong {sm.cong+inc}>{CONG_BUDGET}")
    ops_inc = 0 if n.comb==0 else 1
    if OPS_BUDGET   is not None and (sm.ops + ops_inc) > OPS_BUDGET:  r.append(f"ops {sm.ops+ops_inc}>{OPS_BUDGET}")
    if DSP_BUDGET_PER_STAGE is not None and (sm.dsp + n.dsp) > DSP_BUDGET_PER_STAGE: r.append(f"dsp {sm.dsp+n.dsp}>{DSP_BUDGET_PER_STAGE}")
    if DSP_OPS_BUDGET_PER_STAGE is not None and (sm.dops + (1 if n.dsp>0 else 0)) > DSP_OPS_BUDGET_PER_STAGE: r.append(f"dops {sm.dops+(1 if n.dsp>0 else 0)}>{DSP_OPS_BUDGET_PER_STAGE}")
    wc=_wclass(n)
    if wc==64 and (sm.chain64 + chain_inc) > CHAIN_BUDGET_64: r.append(f"chain64 {sm.chain64+chain_inc}>{CHAIN_BUDGET_64}")
    if wc==32 and (sm.chain32 + chain_inc) > CHAIN_BUDGET_32: r.append(f"chain32 {sm.chain32+chain_inc}>{CHAIN_BUDGET_32}")
    if wc==8  and (sm.chain8  + chain_inc) > CHAIN_BUDGET_8:  r.append(f"chain8 {sm.chain8+chain_inc}>{CHAIN_BUDGET_8}")
    return r

def _micro_split(nodes:List[Node], edges:Set[Tuple[int,int]])->Tuple[List[Node], Set[Tuple[int,int]]]:
    new_nodes: List[Node] = []
    edges_new: Set[Tuple[int,int]] = set()
    first_last: Dict[int, Tuple[int,int]] = {}
    for i,n in enumerate(nodes):
        if n.comb <= COMB_BUDGET or n.is_load or n.is_store or n.is_atomic or n.dsp>0:
            idx=len(new_nodes)
            m=Node(idx, n.op, n.bw, n.comb, n.dsp, n.lut, n.is_load, n.is_store, 0, n.cls, n.mem_keys, n.mem_precise, n.flag_reads, n.flag_writes, n.is_atomic)
            new_nodes.append(m); first_last[i]=(idx,idx)
        else:
            k = (n.comb + COMB_BUDGET - 1)//COMB_BUDGET
            base = max(1, n.comb//k)
            rem  = max(1, n.comb - base*(k-1))
            lut_base = max(1, n.lut//k)
            lut_rem  = max(1, n.lut - lut_base*(k-1))
            prev=None; first=None
            for t in range(k):
                comb = base if t<k-1 else rem
                lut  = lut_base if t<k-1 else lut_rem
                idx=len(new_nodes)
                m=Node(idx, f"{n.op}_S{t+1}", n.bw, comb, 0, lut, False, False, 0, n.cls, [], True, set(), set(), False)
                new_nodes.append(m)
                if prev is not None: edges_new.add((prev, idx))
                prev=idx
                if first is None: first=idx
            first_last[i]=(first, prev)
    for a,b in edges:
        edges_new.add((first_last[a][1], first_last[b][0]))
    for nd in new_nodes:
        nd.succ=0
    for a,b in edges_new:
        new_nodes[a].succ+=1
    return new_nodes, edges_new

def schedule_group(group: dict, strict_merge: bool, trace: bool=False):
    nodes, edges, estats = build_dag(group, strict_merge)
    nodes, edges = _micro_split(nodes, edges)

    N = len(nodes)
    if N == 0:
        return [], [], [], 0.0, estats, nodes, edges, [], {}, {}
    order0, succ = topo_sort(N, edges)
    preds=[set() for _ in range(N)]
    for a,b in edges: preds[b].add(a)

    stage_of = [-1]*N
    stages: List[StageMetric] = []

    rd_issue = defaultdict(lambda: defaultdict(int))
    wr_issue = defaultdict(lambda: defaultdict(int))
    rd_ret   = defaultdict(lambda: defaultdict(int))
    ops_issue= defaultdict(lambda: defaultdict(int))

    stage_mem_book = defaultdict(list)

    def _ensure_stage(s:int):
        while len(stages) <= s:
            stages.append(StageMetric())

    def _conflicts_with_stage(u: int, s: int) -> bool:
        n = nodes[u]
        if not (n.is_load or n.is_store or n.is_atomic or (n.cls=="RMW")):
            return False
        keys = n.mem_keys or [AddrKey(None, None, 1, 0, "GEN", n.bw)]
        n_is_store_like = n.is_store or n.is_atomic or (n.cls == "RMW")
        for ak in keys:
            for (bk, b_is_load, b_is_store_like, b_is_atomic, b_precise) in stage_mem_book[s]:
                if ak.space != bk.space:
                    continue
                if n.is_atomic or b_is_atomic:
                    return True
                if (not n_is_store_like) and (not b_is_store_like):
                    continue
                precise_pair = n.mem_precise and b_precise
                same_tuple = (ak.base, ak.index, ak.scale) == (bk.base, bk.index, bk.scale)
                if precise_pair and same_tuple and (not _ranges_overlap(ak, bk)):
                    continue
                return True
        return False

    def _fits_mem(u:int, s:int)->bool:
        n = nodes[u]
        if not (n.is_load or n.is_store or n.is_atomic or (n.cls=="RMW")):
            return True
        if _conflicts_with_stage(u, s):
            return False
        keys = n.mem_keys or [AddrKey(None, None, 1, 0, "GEN", n.bw)]
        for ak in keys:
            sp, bb = _mem_key_for_calendar(ak)
            ports = DEFAULT_PORTS.get(sp, MemPorts())
            if n.is_load and rd_issue[s][(sp,bb)] + 1 > ports.rd: return False
            if n.is_store and wr_issue[s][(sp,bb)] + 1 > ports.wr: return False
            if n.is_load and rd_ret[s + ports.rlat][(sp,bb)] + 1 > ports.rd: return False
            need_ops = (1 if n.is_load else 0) + (1 if n.is_store else 0)
            if ops_issue[s][(sp,bb)] + need_ops > ports.total: return False
            if need_ops == 2 and ops_issue[s][(sp,bb)] > 0: return False
        return True

    def _place_mem_accounting(u:int, s:int):
        n = nodes[u]
        if n.is_load or n.is_store or n.is_atomic or (n.cls=="RMW"):
            keys = n.mem_keys or [AddrKey(None, None, 1, 0, "GEN", n.bw)]
            for ak in keys:
                sp, bb = _mem_key_for_calendar(ak)
                ports = DEFAULT_PORTS.get(sp, MemPorts())
                if n.is_load:
                    rd_issue[s][(sp,bb)] += 1
                    rd_ret[s + ports.rlat][(sp,bb)] += 1
                if n.is_store:
                    wr_issue[s][(sp,bb)] += 1
                ops_issue[s][(sp,bb)] += (1 if n.is_load else 0) + (1 if n.is_store else 0)
                stage_mem_book[s].append((ak, n.is_load, (n.is_store or n.is_atomic or (n.cls=="RMW")), n.is_atomic, n.mem_precise))

    for u in order0:
        estart = 0
        for p in preds[u]:
            estart = max(estart, stage_of[p] + _edge_weight(p, nodes))
        s = estart
        scans = 0
        MAX_SCAN = 4096
        while True:
            _ensure_stage(s)
            n  = nodes[u]
            sm = stages[s]
            if not _fits_mem(u, s):
                s += 1; scans += 1
                if scans>=MAX_SCAN:
                    raise RuntimeError(f"placement stuck (mem) for node {u} op={n.op} bw={n.bw} at stage {s}")
                continue
            chain_inc = _would_increase_chain(u, s, preds, nodes, stage_of)
            if _fits_budget_for_node(n, sm, chain_inc):
                stage_of[u] = s
                _accumulate_node(n, sm, chain_inc)
                _place_mem_accounting(u, s)
                break
            else:
                scans += 1
                if scans>=MAX_SCAN:
                    reasons = ", ".join(_not_fit_reasons(n, sm, chain_inc))
                    raise RuntimeError(f"placement stuck for node {u} op={n.op} bw={n.bw} start={estart} stage={s} reasons=({reasons})")
                s += 1

    final_order = sorted(range(N), key=lambda x:(stage_of[x], order0.index(x)))
    cut_mask = [False]*(max(0, N-1))
    for k in range(N-1):
        if stage_of[final_order[k+1]] > stage_of[final_order[k]]:
            cut_mask[k] = True

    max_s = max(stage_of) if stage_of else -1
    ff_boundaries: List[int] = []
    for s in range(max_s):
        last_u = None
        for u in final_order:
            if stage_of[u] == s: last_u = u
        if last_u is not None: ff_boundaries.append(last_u)

    cp=[sm.comb for sm in stages]
    sigma=pstdev(cp) if len(cp)>1 else 0.0

    if trace:
        print("")
        print("Stage | Comb DSP LUT | rdIssue wrIssue rdRet (unique keys)")
        for i,sm in enumerate(stages):
            ri=len(rd_issue[i]); wi=len(wr_issue[i]); rr=len(rd_ret[i])
            print(f"{i:5d} | {sm.comb:4d} {sm.dsp:3d} {sm.lut:4d} | {ri:7d} {wi:7d} {rr:5d}")

    ff_hints = list(ff_boundaries)
    cal_issue = {
        str(s): { f"{sp}:{bb}": {"rd": rd_issue[s][(sp,bb)], "wr": wr_issue[s][(sp,bb)], "ops": ops_issue[s][(sp,bb)]}
                  for (sp,bb) in set(list(rd_issue[s].keys()) + list(wr_issue[s].keys()) + list(ops_issue[s].keys())) }
        for s in range(len(stages))
    }
    cal_ret = {
        str(s): { f"{sp}:{bb}": rd_ret[s][(sp,bb)] for (sp,bb) in rd_ret[s].keys() }
        for s in rd_ret.keys()
    }
    return final_order, cut_mask, ff_boundaries, stage_of, sigma, estats, nodes, edges, ff_hints, cal_issue, cal_ret

def analyse(group:dict, strict_merge:bool, trace:bool):
    (order, cut_mask, ff, stage_of, sigma, estats,
     nodes, edges, ff_hints, cal_issue, cal_ret) = schedule_group(group, strict_merge, trace)

    group["order_map"]       = order
    group["cut_mask"]        = cut_mask
    group["ff_boundaries"]   = ff
    group["ff_hints"]        = ff_hints
    group["stage_of"]        = stage_of
    effective_stages = 1 + sum(1 for x in cut_mask if x)
    group["_stage_count_raw"] = (max(stage_of)+1) if stage_of else 1
    group["stage_count"]      = effective_stages
    group["latency_cycles"]   = effective_stages
    group["crit_path_sigma"] = sigma
    group["edge_stats"]      = estats

    group["nodes_meta"] = [
        {
            "idx": n.idx, "op": n.op, "bw": n.bw, "comb": n.comb,
            "dsp": n.dsp, "lut": n.lut,
            "is_load": n.is_load, "is_store": n.is_store, "cls": n.cls,
            "mem": [asdict(k) for k in (n.mem_keys or [])],
            "precise_addr": bool(n.mem_precise),
            "flag_reads": sorted(list(n.flag_reads or [])),
            "flag_writes": sorted(list(n.flag_writes or [])),
            "is_atomic": bool(n.is_atomic),
        } for n in nodes
    ]

    mem_calendar: Dict[str, Dict[str, Dict[str,int]]] = defaultdict(lambda: defaultdict(lambda: {"reads":0,"writes":0,"ops":0,"max_bits":0}))
    for n in nodes:
        s = stage_of[n.idx]
        if not (n.mem_keys): continue
        for ak in n.mem_keys:
            key = f"{ak.space}:{ak.base or 'NONE'}"
            if n.is_load:  mem_calendar[str(s)][key]["reads"]  += 1
            if n.is_store: mem_calendar[str(s)][key]["writes"] += 1
            mem_calendar[str(s)][key]["ops"] += (1 if n.is_load else 0) + (1 if n.is_store else 0)
            mem_calendar[str(s)][key]["max_bits"] = max(mem_calendar[str(s)][key]["max_bits"], ak.width or n.bw)

    group["mem_calendar"] = { sk: dict(vk) for sk, vk in mem_calendar.items() }
    group["_mem_issue_calendar"] = cal_issue
    group["_mem_return_calendar"] = cal_ret
    group["dsp_need_total"] = sum(n.dsp for n in nodes)
    group["_nodes"] = nodes
    group["_edges"] = list(edges)

def emit_sniper_csv(groups: List[dict], out_csv: Path, add_blank_lines: bool=True):
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    with out_csv.open("w", newline="") as f:
        w = csv.writer(f); w.writerow(["bench","src","pc","latency"])
        for g in groups:
            instrs = g.get("instructions", [])
            if not instrs: continue
            bench=g.get("bench", ""); src=g.get("src", "")
            pcs=[ins.get("address") or ins.get("pc") or "" for ins in instrs]
            D=int(g.get("stage_count", 1))
            for j, pc in enumerate(pcs):
                w.writerow([bench, src, pc, D if j==0 else 0])
            if add_blank_lines: w.writerow([])

def cli() -> argparse.Namespace:
    ap = argparse.ArgumentParser(
        "fpga_pipeline_stage (II=1, ALWAYS-SAFE mem scheduling + per-flag + atomic, U200@300MHz)"
    )
    ap.add_argument("input_json", help="filtered JSON")
    ap.add_argument("-o","--out", help="output base (no extension). Default: <input>_result")
    ap.add_argument("--trace", action="store_true", help="print per-stage packing")
    ap.add_argument("--strict-merge", action="store_true", help="require merge_edges; no fallback")
    return ap.parse_args()

def _strip_debug_keys(g:dict)->dict:
    return {k: v for (k,v) in g.items() if not k.startswith("_")}

def main() -> None:
    args = cli()
    groups = json.loads(Path(args.input_json).read_text())
    if isinstance(groups, dict) and "groups" in groups:
        groups = groups["groups"]

    out_groups=[]
    for i,g in enumerate(sorted(groups, key=lambda g:(g.get("bench",""), g.get("src",""), g.get("rank",0)))): 
        analyse(g, args.strict_merge, args.trace)
        out_groups.append(g)
        es = g['edge_stats']
        print(f"[{i:04d}] stages={g['stage_count']} II=1 OK  σ={g['crit_path_sigma']:.2f}  "
              f"E={es['final_edges']}  memE(RAW/WAR/WAW/RAR/CONS)={es['added_mem_raw']}/{es['added_mem_war']}/{es['added_mem_waw']}/{es.get('added_mem_rar',0)}/{es['added_mem_conservative']}  "
              f"dsp_need_total={g.get('dsp_need_total',0)}")

    if args.out: outb = Path(args.out)
    else:
        inp = Path(args.input_json); outb = inp.parent / f"{inp.stem}_result"

    outb.parent.mkdir(parents=True, exist_ok=True)
    serializable_groups = [_strip_debug_keys(g) for g in out_groups]

    aug = outb.parent / f"{outb.name}_augmented.json"
    aug.write_text(json.dumps(serializable_groups, indent=2))

    csvf = outb.parent / f"{outb.name}_summary.csv"
    with csvf.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(("idx","stages","latency","critσ","finalE","added_mem_raw","added_mem_war","added_mem_waw","added_mem_rar","added_mem_cons","dsp_need_total"))
        for i,g in enumerate(out_groups):
            es = g.get("edge_stats", {})
            w.writerow((i, g["stage_count"], g["latency_cycles"], g["crit_path_sigma"],
                        es.get('final_edges',0), es.get('added_mem_raw',0), es.get('added_mem_war',0),
                        es.get('added_mem_waw',0), es.get('added_mem_rar',0), es.get('added_mem_conservative',0), g.get('dsp_need_total',0)))

    sniper_csv = outb.parent / f"{outb.name}_sniper.csv"
    emit_sniper_csv(out_groups, sniper_csv, add_blank_lines=True)
    print(f"Sniper CSV -> {sniper_csv}")
    print(f"Augmented JSON -> {aug}")
    print(f"Summary CSV -> {csvf}")

if __name__=="__main__":
    try:
        main()
    except Exception as e:
        sys.exit(f"Error: {e}")
