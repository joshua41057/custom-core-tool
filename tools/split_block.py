"""
python tools/split_block.py  examples/result_augmented.json
"""

import json, pathlib, re, shutil, sys

def safe(s:str)->str: return re.sub(r"[^A-Za-z0-9\-]","",s)[:40] or "BLK"

root = pathlib.Path(sys.argv[1]).resolve()

if not root.is_dir():
    print("usage: split_block_fixed.py <by_bench_dir>")
    sys.exit(1)

for bench_dir in sorted(root.iterdir()):
    if not bench_dir.is_dir(): continue

    src = bench_dir / "bench_blocks.json"

    if not src.exists(): continue

    blocks = json.loads(src.read_text())
    out = bench_dir / "blocks"

    if out.exists(): shutil.rmtree(out)

    out.mkdir()

    seen_pc = set()
    kept=0

    for idx,g in enumerate(blocks):
        pc = g["instructions"][0]["address"]

        if pc in seen_pc: continue

        seen_pc.add(pc)
        g["pc"] = pc
        rank = g.get("rank",0)

        sig = "-".join(i["opcode"].upper() for i in g["instructions"])
        fn = f"blk{idx:03d}_r{rank:03d}_{safe(sig)}.json"
        
        (out/fn).write_text(json.dumps(g, indent=2))
        kept+=1
    print(f"[{bench_dir.name}] {kept} blocks -> {out}")