#!/usr/bin/env python3
"""
scan_alu_only.py <DIR|FILE> [-o out.json] [--min-len N]
"""
import json
import argparse
from pathlib import Path

ALU_INSTRUCTIONS = {
    "ADD", "ADC", "SUB", "SBB", "INC", "DEC", "NEG", "CMP",
    "AND", "OR", "XOR", "NOT", "TEST",
    "SHL", "SAL", "SHR", "SAR", "ROL", "ROR", "RCL", "RCR", "SHLD", "SHRD", "MUL", "IMUL", "DIV", "IDIV"
}

def process_json(jpath: Path, min_len: int) -> list[dict]:
    """Return ALU-only groups in the JSON file."""
    with jpath.open() as f:
        meta = json.load(f)

    out = []
    for g in meta:
        inst = g.get("instructions", [])
        if len(inst) < min_len:
            continue
        if all(i.get("opcode","").upper() in ALU_INSTRUCTIONS for i in inst):
            out.append(g)
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", help="directory or JSON file")
    ap.add_argument("-o","--out", default=str(
        Path(__file__).resolve().parents[1] / "examples" / "alu_only.json"))
    ap.add_argument("--min-len", type=int, default=1,
                    help="minimum uops per group")
    args = ap.parse_args()

    root = Path(args.root)
    json_files = []
    if root.is_file():
        json_files = [root]
    else:
        json_files = list(root.glob("**/super_hot_regions.json"))

    if not json_files:
        print("No JSON files found."); return

    filtered = []
    for p in json_files:
        filtered.extend(process_json(p, args.min_len))

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(filtered, indent=2))
    print(f"✓ {len(filtered)} ALU-only groups → {args.out}")

if __name__ == "__main__":
    main()