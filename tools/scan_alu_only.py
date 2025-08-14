#!/usr/bin/env python3
import json, argparse, logging, sys
from pathlib import Path

try:
    import orjson as _json
    loads = _json.loads
    dumps = lambda o: _json.dumps(o, option=_json.OPT_INDENT_2)
except ModuleNotFoundError:
    loads = json.loads
    dumps = lambda o: json.dumps(o, indent=2).encode()

ALLOWED = {
    # ---- ALU / bit ----
    "add","sub","and","andn","or","xor","neg","not",
    "sar","shr","shl","rorx","sarx","shrx","shlx",
    "blsi","blsr","bzhi","tzcnt","pxor",
    "cmp","test","ucomisd","vcomisd","vcomiss","vucomisd","vucomiss",
    "bt",
    "inc","dec",

    # ---- scalar sign/zero extend helpers ----
    "cdq","cdqe","cqo",

    # ---- SIMD logic ----
    "andpd","andps","vandpd","vandps","subss",
    "vorpd","vpor","vpxor","vxorpd","vxorps",
    "vpand","vpandn",

    # ---- mul / add / sub (no flag consume) ----
    "mul","imul","mulss","mulps",
    "vmulps","vmulpd","vmulsd","vmulss","vpmulld",
    "vpaddd","vpaddq","vpaddw","vpsubd","vpsubw","vpavgb",
    "addss","vaddss","vaddps","vaddpd","vaddsd",
    "vsubps","vsubpd","vsubss","vsubsd",

    # ---- shifts (only) ----
    "vpslld","vpsllq","vpsllw",
    "vpsrld","vpsrlq","vpsrad","vpsraw",

    # ---- broadcast / blends (immediate-mask only) ----
    "vbroadcastsd","vbroadcastss",
    "vpbroadcastb","vpbroadcastd","vpbroadcastw",
    "vpblendd","vpblendw","vblendpd",

    # ---- insert / extract / masks / misc ----
    "vpinsrb","vpinsrd","vpinsrq",
    "vpextrd","vpextrq",
    "vinsertps","vextracti128","vextractf128","vinserti128","vinsertf128",
    "vmovmskps","vpsadbw",

    # ---- vector sign/zero extend (no flags) ----
    "vpmovsxwd","vpmovzxbw","vpmovzxwd",

    # ---- MOV / loads & stores (regular) ----
    "mov","movq","movd","movdqa","movdqu","movsd","movss",
    "movapd","movaps",
    "movsx","movzx","movsxd",
    "vmovq","vmovd","vmovdqa","vmovdqu",
    "vmovaps","vmovapd",
    "vmovss","vmovsd","vmovups","vmovupd",
    "vmovhps","vmovhpd","vmovlps","vmovlpd","vmovlhps",
    "punpcklqdq",
    "lea",

    # ---- min/max ----
    "vmaxpd","vmaxps","vmaxsd","vmaxss",
    "vminpd","vminps","vminsd","vminss",

    # ---- FMA (no flags) ----
    "vfmadd132ps","vfmadd213ps","vfmadd231ps",
    "vfmadd132pd","vfmadd213pd","vfmadd231pd",
    "vfmadd132ss","vfmadd213ss","vfmadd231ss",
    "vfmadd132sd","vfmadd213sd","vfmadd231sd",
    "vfmsub132ps","vfmsub213ps","vfmsub231ps",
    "vfmsub132pd","vfmsub213pd","vfmsub231pd",
    "vfmsub132ss","vfmsub213ss","vfmsub231ss",
    "vfmsub132sd","vfmsub213sd","vfmsub231sd",
    "vfnmadd132ps","vfnmadd213ps","vfnmadd231ps",
    "vfnmadd132pd","vfnmadd213pd","vfnmadd231pd",
    "vfnmadd132ss","vfnmadd213ss","vfnmadd231ss",
    "vfnmadd132sd","vfnmadd213sd","vfnmadd231sd",
    "vfnmsub132pd","vfnmsub231sd","vfnmsub132sd",

    # ---- compares (no flag consume) ----
    "vcmppd","vcmpsd",
    "vpcmpeqb","vpcmpeqd","vpcmpgtd","vpcmpgtw",
    "vpmaxsd","vpminub","vpmovmskb","vptest",

    # ---- data dup / shuffles (safe) ----
    "vmovddup","vmovshdup","vmovsldup",
}


NOT_ALLOWED = {
    # ---- Branch / calls / system / returns ----
    "jb","jbe","jl","jle","jnb","jnbe","jnl","jnle","jns","jnz","jp","js","jz",
    "jmp","call","syscall","ret",

    # ---- Flag consumers ----
    "adc","sbb",

    # ---- Conditional move & setcc ----
    "cmovb","cmovbe","cmovl","cmovle","cmovnb","cmovnbe","cmovnle","cmovnz","cmovs","cmovz",
    "setb","setbe","setle","setnb","setnbe","setnl","setnle","setnp","setnz","setp","setz",

    # ---- Division / square root ----
    "div","idiv","divss","vdivss","vdivsd","vdivpd","vdivps","vsqrtsd","vsqrtss","vsqrtpd",

    # ---- Memory patterns exclude (streaming / gather / masked stores) ----
    "vgatherdpd","vgatherqpd","vmaskmovpd","vmovntdq",

    # ---- Stack / special state ----
    "push","pop","xchg","vstmxcsr",

    # ---- Permute / Shuffle (moved) ----
    "vpsrldq","vpslldq",
    "vpshufd","vpshufb",
    "vshufps","vshufpd",
    "vperm2i128","vpermq","vpermpd",

    # ---- Variable blends (moved) ----
    "vpblendvb","vblendvpd",

    # ---- Conversions / Rounding / Int-conversion (moved) ----
    "vcvtsd2ss","vcvtss2sd","vcvtsi2ss","vcvtsi2sd","vcvttss2si","vcvttsd2si",
    "vroundsd",

    # ---- packs / unpacks ----
    "vpunpcklqdq","vpunpckhqdq","vpunpcklwd","vpunpckldq",
    "vunpckhpd","vunpcklpd","vunpcklps",
    "vpackusdw","vpackuswb",
}

def alu_block(group: dict) -> bool:
    return all(ins["opcode"].lower() in ALLOWED for ins in group["instructions"])


def scan_file(path: Path):
    run   = path.parents[0].name     
    bench = path.parents[1].name     
    tag   = f"{bench}/{run}"          

    ok, bad = [], []
    groups = loads(path.read_bytes())   

    for idx, g in enumerate(groups):
        g["bench"] = tag                      
        g["src"]   = f"{run}/super_hot_regions:{idx}"  
        (ok if alu_block(g) else bad).append(g)
    return ok, bad

#  CLI 
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", type=Path)
    ap.add_argument("-o", "--out",    type=Path, default=Path("alu_only.json"))
    ap.add_argument("--reject",       type=Path)
    ap.add_argument("--log", default="info")
    args = ap.parse_args()
    logging.basicConfig(level=getattr(logging, args.log.upper()))

    paths = [args.root] if args.root.is_file() else list(args.root.glob("**/super_hot_regions.json"))
    if not paths:
        sys.exit("no JSON found")

    keep, drop = [], []
    for p in paths:
        g, b = scan_file(p); keep.extend(g); drop.extend(b)

    args.out.write_bytes(dumps(keep))
    logging.info("saved %d blocks -> %s", len(keep), args.out)
    if args.reject:
        args.reject.write_bytes(dumps(drop))

if __name__ == "__main__":
    main()
