"""
python tools/split_block.py  examples/result_augmented.json
"""

import json, pathlib, re, sys
src  = pathlib.Path(sys.argv[1]).resolve()
out  = src.parent / "blocks"; out.mkdir(exist_ok=True)

def safe(name): return re.sub(r"[^A-Za-z0-9\-]","",name)[:30] or "BLK"
for g in json.loads(src.read_text()):
    ops = "-".join(i["opcode"].upper() for i in g["instructions"])
    blk = f"blk{g['rank']:02d}_{safe(ops)}.json"
    (out/blk).write_text(json.dumps(g,indent=2))
print("✓", len(list(out.glob('*.json'))), "blocks →", out)