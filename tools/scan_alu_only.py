#!/usr/bin/env python3
"""
scan_alu_only_debug_v2.py  <ROOT_DIR>  [-o out.json]
"""
import json
import argparse
import pathlib

ALU_INSTRUCTIONS = {
    "ADD", "ADC", "SUB", "SBB", "INC", "DEC", "NEG", "CMP",
    "AND", "OR", "XOR", "NOT", "TEST",
    "SHL", "SAL", "SHR", "SAR", "ROL", "ROR", "RCL", "RCR", "SHLD", "SHRD", "MUL", "IMUL", "DIV", "IDIV"
}

def process_json(jpath):
    print(f"Processing file: {jpath}")
    try:
        with open(jpath, 'r') as f:
            meta = json.load(f)
        filtered_groups = []
        for group in meta:
            instructions = group.get("instructions", [])
            if not instructions:
                print(f"  No instructions in group, skipping: {jpath}")
                continue
            non_alu = [
                instr.get("opcode", "MISSING_OPCODE")
                for instr in instructions
                if instr.get("opcode", "MISSING_OPCODE").upper() not in ALU_INSTRUCTIONS
            ]
            if non_alu:
                print(f"  Non-ALU instructions in group: {non_alu}")
            else:
                print(f"  Found ALU-only group with {len(instructions)} instructions: {[instr.get('opcode') for instr in instructions]}")
                filtered_groups.append(group)
        return filtered_groups
    except json.JSONDecodeError as e:
        print(f"  JSON parsing error in {jpath}: {e}")
        return []
    except Exception as e:
        print(f"  Error in {jpath}: {e}")
        return []

def main(root, out):
    root = pathlib.Path(root)
    print(f"Scanning root directory: {root}")
    files = list(root.glob("**/super_hot_regions.json"))
    if not files:
        print("No super_hot_regions.json files found in the directory tree.")
    all_filtered_groups = []
    
    for p in files:
        filtered_groups = process_json(p)
        for group in filtered_groups:
            group["src_json"] = str(p)
        all_filtered_groups.extend(filtered_groups)
    
    with open(out, 'w') as f:
        json.dump(all_filtered_groups, f, indent=2)
    print(f"Scanned {len(all_filtered_groups)} groups with only ALU instructions → {out}")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("root", help="root of SPEC_CPU_RATE_result tree")
    ap.add_argument("-o", "--out", default="groups_with_alu_instructions.json")
    args = ap.parse_args()
    main(args.root, args.out)