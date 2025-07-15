#!/usr/bin/env python3
"""
run_all.py  examples/bench
"""
from pathlib import Path, PurePath
import subprocess, sys

root = Path(sys.argv[1]).resolve()
TOOLS  = Path(__file__).resolve().parent / "tools" 

# 루트에 JSON이 쌓여 있으면 그것부터, 아니면 기존 방식(폴더)
json_files = list(root.glob("*_alu.json"))
if json_files:                               # “파일 모드”
    todo = json_files
else:                                        # “폴더 모드” (예전과 동일)
    todo = sorted(root.iterdir())

for target in todo:
    if target.is_file():                     # ← JSON 한 장
        alu_json = target
        tag      = alu_json.stem.replace("_alu","")
        bench    = root / tag                # 새 작업 폴더
        bench.mkdir(exist_ok=True)
        (bench/"constraints").mkdir(exist_ok=True)
        (bench/"rtl").mkdir(exist_ok=True)
        (bench/"blocks").mkdir(exist_ok=True)
        # 이미 같은 곳에 있지 않으면 복사/링크
        if alu_json.parent != bench:
            alu_json_dst = bench/alu_json.name
            alu_json_dst.write_bytes(alu_json.read_bytes())
            alu_json = alu_json_dst
    else:                                    # ← 예전 폴더 구조
        bench    = target
        alu_list = list(bench.glob("*_alu.json"))
        if not alu_list:
            print(f"[skip] {bench.name}: no *_alu.json")
            continue
        alu_json = alu_list[0]
        tag      = alu_json.stem.replace("_alu","")

    # 2) stage / FF
    subprocess.check_call([
        "python3", TOOLS/"pipeline_staging_estimator.py", alu_json,
        "--emit_tcl", "--tcl_dir", str(bench/"constraints")
    ])

    # 3) split
    aug_json = alu_json.with_name(f"{alu_json.stem}_result_augmented.json")
    subprocess.check_call([
        "python3", TOOLS/"split_block.py", aug_json,
        "-o", str(bench/"blocks")
    ])
    
    # 5) len table
    subprocess.check_call([
        "python3", TOOLS/"gen_len_table.py", bench/"blocks",
        "-o", bench/"rtl"/"len_table_pkg.sv"
    ])

    print(f"[OK] {bench.name}")