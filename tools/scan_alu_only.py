#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse, json, logging, sys, re
from pathlib import Path
from collections import Counter

ALLOWED = {
    "add","addpd","addps","addsd","addss","and","andn","andpd","andps",
    "blsi","blsr","bsf","bsr","bswap","bt","btc","btr","bts","bzhil","bzhi",
    "cbw","cdq","cdqe","clc","cld","clflush","clflushopt","cltq","cmpeqps",
    "cmp","cmppd","cmpps","cmpsd","cmpss","comisd","comiss","cpuid","cqo",
    "cvtdq2pd","cvtdq2ps","cvtpd2dq","cvtpd2ps","cvtpi2ps","cvtps2dq","cvtps2pd",
    "cvtsd2si","cvtsd2ss","cvtsi2sd","cvtsi2ss","cvtss2sd","cvttsd2si","cwde",
    "data16","dec","div","divsd","divss","fld","fnstcw","fnstsw","fstp","idiv",
    "imul","inc","lea","leave","lock","lzcnt","maxsd","mfence","minsd","mov",
    "movapd","movaps","movbe","movd","movddup","movdqa","movdqu","movhpd","movhps",
    "movlhps","movlpd","movlps","movmskpd","movmskps","movq","movsd","movshdup",
    "movsldup","movsx","movsxd","movupd","movups","movzx","mul","mulsd","mulss",
    "neg","nop","not","or","orpd","orps","packusdw","packuswb","paddd","paddq",
    "paddw","pand","pandn","pause","pavgb","pblendw","pblendvb","pdep","pext",
    "pextrd","pextrq","pinsrb","pinsrd","pinsrq","pmovmskb","pmovsxwd","pmovzxbw",
    "pmovzxwd","pmulld","por","psadbw","pshufb","pshufd","pslld","psllq","psllw",
    "psrad","psraw","psrld","psrldq","psrlq","psubd","psubw","ptest","punpckhqdq",
    "punpckldq","punpcklqdq","punpcklwd","pxor","rcl","rcr","rep","retf","rol",
    "ror","rorx","roundsd","sar","sarx","sbb","seta","setae","setb","setbe","setl",
    "setle","setnb","setnbe","setnl","setnle","setnp","setnz","seto","setp","setz",
    "sfence","shl","shld","shlx","shr","shrd","shrx","sqrtpd","sqrtsd","sqrtss",
    "stmxcsr","sub","subpd","subps","subsd","subss","test","tzcnt","ucomisd",
    "ucomiss","unpckhpd","unpckhps","unpcklpd","unpcklps","vaddpd","vaddps","vaddsd",
    "vaddss","vandpd","vandps","vblendpd","vblendvpd","vbroadcastsd","vbroadcastss",
    "vcmppd","vcmpsd","vcomisd","vcomiss","vcvtsd2ss","vcvtsi2sd","vcvtsi2ss",
    "vcvtss2sd","vcvttsd2si","vcvttss2si","vdivpd","vdivps","vdivsd","vdivss",
    "vextractf128","vextracti128","vfmadd132pd","vfmadd132ps","vfmadd132sd",
    "vfmadd132ss","vfmadd213pd","vfmadd213sd","vfmadd213ss","vfmadd231pd",
    "vfmadd231ps","vfmadd231sd","vfmadd231ss","vfmsub132pd","vfmsub132ps",
    "vfmsub132sd","vfmsub132ss","vfmsub213pd","vfmsub213ss","vfmsub231pd",
    "vfmsub231sd","vfmsub231ss","vfnmadd132pd","vfnmadd132ps","vfnmadd132sd",
    "vfnmadd213pd","vfnmadd213ps","vfnmadd213sd","vfnmadd213ss","vfnmadd231pd",
    "vfnmadd231sd","vfnmadd231ss","vfnmsub132pd","vfnmsub132sd","vfnmsub231sd",
    "vinsertf128","vinserti128","vinsertps","vmaxpd","vmaxsd","vmaxss","vminpd",
    "vminsd","vminss","vmovapd","vmovaps","vmovd","vmovddup","vmovdqa","vmovdqu",
    "vmovhpd","vmovhps","vmovlhps","vmovlpd","vmovlps","vmovmskps","vmovq","vmovsd",
    "vmovshdup","vmovsldup","vmovss","vmovupd","vmovups","vmulpd","vmulps","vmulsd",
    "vmulss","vorpd","vpackusdw","vpackuswb","vpaddd","vpaddq","vpaddw","vpand",
    "vpandn","vpavgb","vpblendd","vpblendw","vpbroadcastb","vpbroadcastd","vpbroadcastw",
    "vpcmpeqb","vpcmpeqd","vpcmpgtd","vpcmpgtw","vperm2i128","vpermpd","vpermq",
    "vpextrd","vpextrq","vpinsrb","vpinsrd","vpinsrq","vpmaxsd","vpminub","vpmovmskb",
    "vpmovsxwd","vpmovzxbw","vpmovzxwd","vpmulld","vpor","vpsadbw","vpshufb","vpshufd",
    "vpslld","vpsllq","vpsllw","vpsrad","vpsraw","vpsrld","vpsrldq","vpsrlq","vpsubd",
    "vpsubw","vptest","vpunpckhqdq","vpunpckldq","vpunpcklqdq","vpunpcklwd","vpxor",
    "vroundsd","vshufpd","vshufps","vsqrtpd","vsqrtsd","vsqrtss","vsubpd","vsubps",
    "vsubsd","vsubss","vucomisd","vucomiss","vunpckhpd","vunpcklpd","vunpcklps",
    "vxorpd","vxorps","vzeroupper","xadd","xchg","xor","xorpd","xorps",
    "adc","cmpxchg"
}

BANNED_ALWAYS = {
    "addr32","bnd","call",
    "jb","jbe","jl","jle","jnb","jnbe","jnl","jnle","jns","jnz","jo","jp","jz",
    "jmp","js","jnp","jno","ret","retf","syscall","push","pop","vmovntdq",
    "vgatherdpd","vgatherqpd","vmaskmovpd","vstmxcsr","xrstor","xsave","xsavec","xsaveopt",
    "lock","data16","rep","leave",
    "cpuid","mfence","sfence","stmxcsr","fnstcw","fnstsw","fld","fstp","pause",
}

_BRACKET_OK_OPS = {"lea"}
_PTR_RE   = re.compile(r"\b(?:byte|word|dword|qword|xmmword|ymmword|zmmword)\s*ptr\b", re.I)
_MSIZE_RE = re.compile(r"^m(?:8|16|32|64|128|256|512)$", re.I)
_IMPLICIT_MEM_OPS = {"push","pop","vmovntdq","vgatherdpd","vgatherqpd","vmaskmovpd","vstmxcsr","leave"}

SEG_OVERRIDE_RE = re.compile(r'\b(?:fs|gs)\s*:\s*\[', re.I)

def has_seg_override(g):
    for ins in g.get("instructions", []):
        for op in (ins.get("raw_operands") or []):
            if SEG_OVERRIDE_RE.search(str(op)):
                return True
    return False

def operand_is_memory(op_str: str) -> bool:
    s = (op_str or "").lower().strip()
    if not s: return False
    if "[" in s and "]" in s: return True
    if _PTR_RE.search(s):     return True
    if _MSIZE_RE.fullmatch(s):return True
    return False

def touches_memory(ins: dict) -> bool:
    opc = (ins.get("opcode") or "").lower()
    if opc in _BRACKET_OK_OPS:  # e.g., lea
        return False
    if opc in _IMPLICIT_MEM_OPS:
        return True
    for op in (ins.get("raw_operands") or []):
        try:
            if operand_is_memory(str(op)):
                return True
        except Exception:
            return True
    return False

def has_mem_operand(ins: dict) -> bool:
    for op in (ins.get("raw_operands") or []):
        if operand_is_memory(str(op)):
            return True
    return False

_CMOV_RE  = re.compile(r"^cmov[a-z]+$")
_SETCC_RE = re.compile(r"^set[a-z]+$")
_JCC_SET  = {"jb","jbe","jl","jle","jnb","jnbe","jnl","jnle","jns","jnz","jp","js","jz"}
_CONTROL_FLOW = _JCC_SET | {"jmp","call","ret","retf","syscall"}

def is_flag_consumer(opc: str) -> bool:
    o = (opc or "").lower()
    if _CMOV_RE.match(o) or _SETCC_RE.match(o): return True
    if o in {"adc","sbb","cmpxchg"}: return True
    if o in _JCC_SET: return True
    return False

DIV_OPS = {"div","idiv","divss","divsd","vdivps","vdivpd","vdivss","vdivsd","fdiv","fdivr"}
def is_division(ins: dict) -> bool:
    return (ins.get("opcode","").lower() in DIV_OPS)

SIMD_SUFFIXES = ("ps","pd","ss","sd")
SIMD_REG_RE = re.compile(r"\b([xyz]mm\d+|mm\d+)\b", re.I)
P_SIMD_OPS = {
    "paddd","paddq","paddw","pand","pandn","pavgb","pblendd","pblendw","pblendvb",
    "pmovmskb","pmovsxwd","pmovzxbw","pmovzxwd","pmulld","por","psadbw","pshufb","pshufd",
    "pslld","psllq","psllw","psrad","psraw","psrld","psrldq","psrlq","psubd","psubw",
    "ptest","punpckhqdq","punpckldq","punpcklqdq","punpcklwd","pxor"
}
def is_simd(ins: dict) -> bool:
    opc = (ins.get("opcode") or "").lower()
    if any(opc.endswith(suf) for suf in SIMD_SUFFIXES): return True
    if opc.startswith("v") and opc in ALLOWED:          return True
    if opc in P_SIMD_OPS:                               return True
    for op in (ins.get("raw_operands") or []):
        if SIMD_REG_RE.search(str(op)): return True
    return False

FLAG_WRITER_OPS = {
    # arithmetic/logical
    "add","sub","inc","dec","neg","cmp","test","and","or","xor","andn",
    # shifts/rotates (classic variants)
    "shl","shr","sar","shld","shrd","rol","ror","rcl","rcr",
    # bit scan/manip
    "bsf","bsr","tzcnt","lzcnt","bt","btc","btr","bts","blsi","blsr","bzhi","bzhil","pdep","pext",
    # multiply/divide
    "mul","imul","div","idiv",
}
def is_flag_writer(ins: dict) -> bool:
    return (ins.get("opcode","").lower() in FLAG_WRITER_OPS)

def block_ok_base(group: dict):
    instrs = group.get("instructions", [])
    for ins in instrs:
        opc = (ins.get("opcode") or "").lower()
        if (opc not in ALLOWED) and (not _CMOV_RE.match(opc)) and (not _SETCC_RE.match(opc)):
            return False, f"unknown-opcode:{opc}"
        if opc in BANNED_ALWAYS:
            return False, f"banned-always:{opc}"
    for ins in instrs:
        if (ins.get("opcode") or "").lower() in _CONTROL_FLOW:
            return False, "control-flow"
    if has_seg_override(group):
        return False, "seg-override"
    for ins in instrs:
        opc = (ins.get("opcode") or "").lower()
        if opc in {"xchg","xadd"} and has_mem_operand(ins):
            return False, "atomic-mem"
    return True, ""

def scan_groups(groups, predicate, tag_reason):
    keep, drop = [], []
    for g in groups:
        ok, reason = predicate(g)
        if ok:
            keep.append(g)
        else:
            gg = dict(g); gg["_reject_reason"] = reason if isinstance(reason,str) else tag_reason
            drop.append(gg)
    return keep, drop

def has_div(g):   return any(is_division(i) for i in g.get("instructions",[]))
def has_simd(g):  return any(is_simd(i)     for i in g.get("instructions",[]))

def load_groups_from_root(path: Path):
    if path.is_file():
        arr = json.loads(path.read_text())
        if not isinstance(arr, list):
            raise SystemExit(f"Expected a list at top-level: {path}")
        return arr
    json_paths = list(path.glob("**/super_hot_regions.json"))
    if not json_paths:
        raise SystemExit("no JSON found")
    groups = []
    for p in json_paths:
        tag = f"{p.parents[1].name}/{p.parents[0].name}"
        arr = json.loads(p.read_text())
        for idx, g in enumerate(arr):
            g = dict(g)
            g.setdefault("bench", tag)
            g.setdefault("src", f"{p.parents[0].name}/super_hot_regions:{idx}")
            groups.append(g)
    return groups

def summarize(groups):
    c = Counter(); ex = 0
    for g in groups:
        c["blocks"] += 1
        c["instrs"] += len(g.get("instructions", []))
        try: ex += int(g.get("execution_count",0) or 0)
        except: pass
    return c, ex

def opcode_hist(groups):
    h = Counter()
    for g in groups:
        for ins in g.get("instructions", []):
            h[(ins.get("opcode") or "").lower()] += 1
    return h

def write_stats(prefix: Path, variant: str, keep, drop):
    kc, ke = summarize(keep); dc, de = summarize(drop)
    stats = {
        "variant": variant,
        "kept": dict(kc), "dropped": dict(dc),
        "exec_count_sum_kept": int(ke), "exec_count_sum_dropped": int(de),
        "opcode_hist_kept": dict(opcode_hist(keep)),
        "opcode_hist_dropped": dict(opcode_hist(drop)),
    }
    prefix.with_suffix(f".{variant}.stats.json").write_text(json.dumps(stats, indent=2))

def run(root: Path, out_prefix: Path, save_rejects: bool):
    all_groups = load_groups_from_root(root)

    base_keep, base_drop = scan_groups(
        all_groups, block_ok_base, "base-filter"
    )
    out_prefix.with_suffix(".base.json").write_text(json.dumps(base_keep, indent=2))
    write_stats(out_prefix, "base", base_keep, base_drop)
    if save_rejects:
        out_prefix.with_suffix(".base.rejects.json").write_text(json.dumps(base_drop, indent=2))

    keep1, drop1 = [], []
    for g in base_keep:
        if has_div(g):
            gg = dict(g); gg["_reject_reason"] = "div-op"
            drop1.append(gg)
        else:
            keep1.append(g)
    out_prefix.with_suffix(".no_div.json").write_text(json.dumps(keep1, indent=2))
    write_stats(out_prefix, "no_div", keep1, drop1)
    if save_rejects:
        out_prefix.with_suffix(".no_div.rejects.json").write_text(json.dumps(drop1, indent=2))

    keep2, drop2 = [], []
    for g in keep1:
        if has_simd(g):
            gg = dict(g); gg["_reject_reason"] = "simd-op"
            drop2.append(gg)
        else:
            keep2.append(g)
    out_prefix.with_suffix(".no_div_no_simd.json").write_text(json.dumps(keep2, indent=2))
    write_stats(out_prefix, "no_div_no_simd", keep2, drop2)
    if save_rejects:
        out_prefix.with_suffix(".no_div_no_simd.rejects.json").write_text(json.dumps(drop2, indent=2))

def main():
    ap = argparse.ArgumentParser(description="3-stage offload filter (base[MEM/FLAGS OK + hazard bans] → no_div → no_div_no_simd)")
    ap.add_argument("root", type=Path, help="Aggregated JSON (e.g., alu_mem.json) OR a root dir containing **/super_hot_regions.json")
    ap.add_argument("-o","--out", type=Path, default=Path("alu3"))
    ap.add_argument("--reject", action="store_true", help="Also write per-stage rejects")
    ap.add_argument("--log", default="info")
    args = ap.parse_args()
    logging.basicConfig(level=getattr(logging, args.log.upper()))
    run(args.root, args.out, args.reject)

if __name__ == "__main__":
    main()
