"""
python tools/split_block.py  examples/result_augmented.json
"""

import json, pathlib, re, shutil, sys

src = pathlib.Path(sys.argv[1]).resolve()
out = src.parent / "blocks"

if out.exists():
    shutil.rmtree(out)
out.mkdir(parents=True)

safe = lambda s: re.sub(r"[^A-Za-z0-9\-]", "", s)[:30] or "BLK"

groups = json.loads(src.read_text())

seen_pc = set()
kept = 0

for idx, g in enumerate(groups):
    pc = g["instructions"][0]["address"]   
    if pc in seen_pc:                      
        continue
    seen_pc.add(pc)
    g["pc"] = pc

    rank = g.get("rank", 0)
    sig  = "-".join(i["opcode"].upper() for i in g["instructions"])
    blk  = f"blk{idx:03d}_r{rank:03d}_{safe(sig)}.json"
    (out / blk).write_text(json.dumps(g, indent=2))
    kept += 1

print("Done, ", kept, "unique blocks ->", out)
