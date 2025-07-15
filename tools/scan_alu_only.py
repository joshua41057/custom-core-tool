#!/usr/bin/env python3
"""
scan_alu_only.py <DIR|FILE> [-o out.json] [--min-len N]
"""
from __future__ import annotations
import argparse, json, re, sys
from pathlib import Path
from typing import List, Dict


try:
    import op_alias
except ModuleNotFoundError:
    op_alias = None 

ALLOW_SET = {

    #  ALU BIT COUNT
    "adc","add","and","andn","blsi","blsr","bt","bzhi","cmp","dec","div",
    "idiv","imul","inc","mul","neg","not","or","rorx","sar","sarx","sbb",
    "shl","shlx","shr","shrx","sub","test","tzcnt","xor",
    # SIMD INT
    "pxor","punpcklqdq","vpackusdw","vpackuswb","vpaddd","vpaddq","vpaddw",
    "vpand","vpandn","vpavgb","vpblendd","vpblendvb","vpblendw",
    "vpbroadcastb","vpbroadcastd","vpbroadcastw","vpcmpeqb","vpcmpeqd",
    "vpcmpgtd","vpcmpgtw","vpmaxsd","vpminub","vpmovmskb","vpmovsxwd",
    "vpmovzxbw","vpmovzxwd","vpmulld","vpor","vpsadbw","vpshufb","vpshufd",
    "vpslld","vpsllq","vpsllw","vpsrad","vpsraw","vpsrld","vpsrldq","vpsrlq",
    "vpsubd","vpsubw","vptest","vpunpckhqdq","vpunpckldq","vpunpcklqdq",
    "vpunpcklwd","vpxor",
    # SIMD FP / FMA
    "addss","divss","mulss","subss","ucomisd","vaddpd","vaddps","vaddsd",
    "vaddss","vandpd","vandps","vblendpd","vblendvpd","vbroadcastsd",
    "vbroadcastss","vcmppd","vcmpsd","vcomisd","vcomiss","vcvtsd2ss",
    "vcvtsi2sd","vcvtsi2ss","vcvtss2sd","vcvttsd2si","vcvttss2si",
    "vdivpd","vdivps","vdivsd","vdivss","vfmadd132pd","vfmadd132ps",
    "vfmadd132sd","vfmadd132ss","vfmadd213pd","vfmadd213sd","vfmadd213ss",
    "vfmadd231pd","vfmadd231ps","vfmadd231sd","vfmadd231ss","vfmsub132pd",
    "vfmsub132ps","vfmsub132sd","vfmsub132ss","vfmsub213pd","vfmsub213ss",
    "vfmsub231pd","vfmsub231sd","vfmsub231ss","vfnmadd132pd","vfnmadd132ps",
    "vfnmadd132sd","vfnmadd213pd","vfnmadd213ps","vfnmadd213sd",
    "vfnmadd213ss","vfnmadd231pd","vfnmadd231sd","vfnmadd231ss",
    "vfnmsub132pd","vfnmsub132sd","vfnmsub231sd","vmaxpd","vmaxsd","vmaxss",
    "vminpd","vminsd","vminss","vmulpd","vmulps","vmulsd","vmulss","vorpd",
    "vroundsd","vshufpd","vshufps","vsqrtpd","vsqrtsd","vsqrtss","vsubpd",
    "vsubps","vsubsd","vsubss","vucomisd","vucomiss","vxorpd","vxorps",

    "mov","movapd","movaps","movd","movdqa","movdqu","movq","movsd","movss",
    "movsx","movsxd","movzx",
    "vmovapd","vmovaps","vmovd","vmovddup","vmovdqa","vmovdqu","vmovhpd",
    "vmovhps","vmovlhps","vmovlpd","vmovlps","vmovmskps","vmovntdq","vmovq",
    "vmovsd","vmovshdup","vmovsldup","vmovss","vmovupd","vmovups",
    "cmovb","cmovbe","cmovl","cmovle","cmovnb","cmovnbe","cmovnle",
    "cmovnz","cmovs","cmovz",
}

def supported_opcode(mnem: str) -> bool:
    m = mnem.lower()
    if op_alias is not None:
        try:
            return op_alias.rtl_op(m) != "OP_NOP"
        except KeyError:
            return False
    return m in ALLOW_SET

REG_RX = re.compile(
    r"""^(r(1?[0-5])?[a-z]*|e?[abcd]x|[sb]p|[sd]i|
          [abcd][lh]|
          [xyz]mm\d+|k\d+|
          flag|imm\d+)$""", re.X | re.I)

IMM_RX = re.compile(r"^[-+]?(0x[0-9a-f]+|\d+)$", re.I)

def is_mem_operand(tok: str) -> bool:
    t = tok.strip().lower()
    if '[' in t or 'ptr' in t:
        return True
    if REG_RX.fullmatch(t) or IMM_RX.fullmatch(t):
        return False
    return t.startswith(('m', 'rel'))

def pure_alu_instruction(ins: Dict) -> bool:
    if not supported_opcode(ins.get("opcode", "")):
        return False
    return not any(is_mem_operand(tok) for tok in ins.get("raw_operands", []))

def pure_block(group: Dict) -> bool:

    insts = group.get("instructions", [])
    if not all(pure_alu_instruction(i) for i in insts):
        return False
    for me in group.get("merge_edges", []):
        cond = me.get("condition", "")
        if not cond.startswith("reg vs reg"):
            return False
    return True

def process_json(jpath: Path, min_len: int) -> tuple[List[Dict], List[Dict]]:
    """return (passed, rejected) tuple for this JSON file"""
    with jpath.open(encoding="utf-8") as f:
        meta = json.load(f)

    passed:  List[Dict] = []
    rejected: List[Dict] = []
    bench_root = jpath.parents[1].name
    subdir     = jpath.parent.name
    bench_id   = f"{bench_root}/{subdir}"
    json_tag   = jpath.stem

    for idx, g in enumerate(meta):
        insts = g.get("instructions", [])
        if len(insts) < min_len or not pure_block(g):
            rejected.append(g)
        else:
            gg          = g.copy()
            gg["bench"] = bench_id
            gg["src"]   = f"{subdir}/{json_tag}:{idx}"
            passed.append(gg)
    return passed, rejected


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("root", help="directory or JSON file")
    ap.add_argument(
        "-o", "--out",
        default=str(Path(__file__).resolve().parents[1] /
                    "examples" / "alu_only.json"),
    )
    ap.add_argument("--min-len", type=int, default=1,
                    help="minimum uops per group")
    ap.add_argument("--dump-reject", type=str, default=None,
                    help="(debug) save rejected groups here")
    args = ap.parse_args()

    root = Path(args.root)
    json_files = [root] if root.is_file() else list(
        root.glob("**/super_hot_regions.json"))

    if not json_files:
        sys.exit("No JSON files found.")

    filtered, rejected = [], []
    for p in json_files:
        ok, bad = process_json(p, args.min_len)
        filtered.extend(ok)
        rejected.extend(bad)

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(filtered, indent=2))
    print(f"Done, {len(filtered)} pure-ALU groups -> {args.out}")

    if args.dump_reject:
        rej_path = Path(args.dump_reject)
        rej_path.parent.mkdir(parents=True, exist_ok=True)
        rej_path.write_text(json.dumps(rejected, indent=2))
        print(f"Filtered, {len(rejected)} groups rejected -> {args.dump_reject}")

if __name__ == "__main__":
    main()