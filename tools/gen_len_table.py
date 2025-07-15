#!/usr/bin/env python3
"""
python tools/gen_len_table.py  examples/blocks/.json  --out rtl/len_table_pkg.sv
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
import argparse

OPS_MAP = {
    "NOP": "OP_NOP",
    "ADD": "OP_ADD",
    "ADC": "OP_ADC",
    "SUB": "OP_SUB",
    "SBB": "OP_SBB",
    "INC": "OP_INC",
    "DEC": "OP_DEC",
    "NEG": "OP_NEG",
    "CMP": "OP_CMP",
    "AND": "OP_AND",
    "OR":  "OP_OR",
    "XOR": "OP_XOR",
    "NOT": "OP_NOT",
    "TEST": "OP_TEST",
    "SHL": "OP_SHL",
    "SAL": "OP_SAL",
    "SHR": "OP_SHR",
    "SAR": "OP_SAR",
    "ROL": "OP_ROL",
    "ROR": "OP_ROR",
    "RCL": "OP_RCL",
    "RCR": "OP_RCR",
    "RORX": "OP_RORX",
    "SHRX": "OP_SHRX",
    "SHLD": "OP_SHLD",
    "SHRD": "OP_SHRD",
    "MUL": "OP_MUL",
    "IMUL": "OP_IMUL",
    "DIV": "OP_DIV",
    "IDIV": "OP_IDIV",
    "MOV": "OP_MOV",
    "MOVSX": "OP_MOVSX",
    "MOVSXD": "OP_MOVSXD",
    "MOVZX": "OP_MOVZX",

    "FADD": "OP_FADD",
    "FSUB": "OP_FSUB",
    "FMUL": "OP_FMUL",
    "FMA":  "OP_FMA",
    "FCMP": "OP_FCMP",
    "ICONV": "OP_ICONV",

    "SUBSS":       "OP_SUBSS",
    "VADDSD":      "OP_VADDSD",
    "VSUBSD":      "OP_VSUBSD",
    "VCOMISD":     "OP_VCOMISD",
    "VCVTSI2SD":   "OP_VCVTSI2SD",
    "VDIVSD":      "OP_VDIVSD",
    "VFMADD132SD": "OP_VFMADD132SD",
    "VFNMADD132SD":"OP_VFNMADD132SD",
    "VMAXSD":      "OP_VMAXSD",
    "VMINSD":      "OP_VMINSD",
    "VMOVD":       "OP_VMOVD",
    "VMOVQ":       "OP_VMOVQ",
    "VMOVSD":      "OP_VMOVSD",
    "VMOVSLDUP":   "OP_VMOVSLDUP",
    "VMULSD":      "OP_VMULSD",
    "VPBROADCASTB":"OP_VPBROADCASTB",
    "VPBROADCASTW":"OP_VPBROADCASTW",
    "VPSHUFD":     "OP_VPSHUFD",
    "VXORPD":      "OP_VXORPD",

    "VADDSD256":        "OP_VADDSD256",
    "VSUBSD256":        "OP_VSUBSD256",
    "VPBROADCASTB256":  "OP_VPBROADCASTB256",
    "VPBROADCASTW256":  "OP_VPBROADCASTW256"
}


def bits(msk, width):  # FF list → bitmask
    v = 0
    for i in msk:
        v |= 1 << i
    hex_w = (width + 3) // 4
    return f"{{{width}'h{v:0{hex_w}x}}}"


def hex32(tok):  # imm → 32-bit hex
    v = int(tok, 0) if isinstance(tok, str) else int(tok)
    return f"32'h{v&0xffffffff:08x}"


def load_blocks(path: str):
    p = Path(path)
    if path == "-":
        return json.load(sys.stdin)

    if p.is_dir():
        blocks = []
        for f in sorted(p.glob("*.json")):
            blk = json.loads(f.read_text())
            # always append the dict itself
            blocks.append(blk)
        return blocks
    else:
        obj = json.loads(p.read_text())
        # single file may be dict or list
        return obj if isinstance(obj, list) else [obj]


# make_pkg 
def make_pkg(blocks) -> str:
    n = len(blocks)
    max_len = max(len(b["instructions"]) for b in blocks)
    out = []

    o = out.append
    o("package len_table_pkg;")
    o("  import uop_pkg::*;")
    o(f"  localparam int N_CASE = {n};")

    # LEN / STAGE
    o(f"  localparam int MAX_LEN = {max_len};")
    o("  localparam int LEN_LUT [N_CASE] = '{")
    o(",\n".join(f"    {len(b['instructions'])}" for b in blocks))
    o("  };")
    o("  localparam int STAGE_LUT [N_CASE] = '{")
    o(",\n".join(f"    {b['stage_count']}" for b in blocks))
    o("  };")


    # FF mask
    o("  /* variable-width FF mask */")
    o("  localparam logic [MAX_LEN-1:0] FF_MASK_LUT [N_CASE] = '{")
    o(
        ",\n".join(
            f"    {bits(b['ff_boundaries'], len(b['instructions']))}" for b in blocks
        )
    )
    o("  };")

    # OPS
    o("  localparam op_t OPS_LUT [N_CASE][MAX_LEN] = '{")
    for idx, b in enumerate(blocks):
        ops = [OPS_MAP[i["opcode"].upper()] for i in b["instructions"]]
        ops += ["OP_NOP"] * (max_len - len(ops))
        o("    '{ " + ", ".join(ops) + " }" + ("" if idx == n - 1 else ","))
    o("  };")

    # IMM
    o("  localparam logic [31:0] IMM_LUT [N_CASE][MAX_LEN] = '{")
    for idx, b in enumerate(blocks):
        imm = [
            (
                hex32(i["raw_operands"][1])
                if i["opcode"].lower() == "test" and len(i["raw_operands"]) == 2
                else "32'h00000000"
            )
            for i in b["instructions"]
        ]
        imm += ["32'h00000000"] * (max_len - len(imm))
        o("    '{ " + ", ".join(imm) + " }" + ("" if idx == n - 1 else ","))
    o("  };")

    # USE_IMM
    o("  localparam logic USE_IMM_LUT [N_CASE][MAX_LEN] = '{")
    for idx, b in enumerate(blocks):
        use = [
            (
                "1'b1"
                if i["opcode"].lower() == "test" and len(i["raw_operands"]) == 2
                else "1'b0"
            )
            for i in b["instructions"]
        ]
        use += ["1'b0"] * (max_len - len(use))
        o("    '{ " + ", ".join(use) + " }" + ("" if idx == n - 1 else ","))
    o("  };")

    o("endpackage")
    return "\n".join(out) + "\n"

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("src", help="json file | dir | -")
    ap.add_argument("-o","--out", default="rtl/len_table_pkg.sv")
    args = ap.parse_args()

    blocks = load_blocks(args.src)
    pkg = make_pkg(blocks)

    out = Path(args.out)
    out.parent.mkdir(exist_ok=True)
    out.write_text(pkg, encoding="utf-8", newline="\n")
    print(f"Done, {out}  (N_CASE={len(blocks)})")
