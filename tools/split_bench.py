import json, pathlib, re, shutil, sys

def safe(s:str)->str: return re.sub(r"[^A-Za-z0-9_\-\.]+","_",s)[:80]

if len(sys.argv)!=3:
    print("usage: split_bench.py <augmented.json> <outdir>")
    sys.exit(1)

src = pathlib.Path(sys.argv[1]).resolve()
out = pathlib.Path(sys.argv[2]).resolve()

groups = json.loads(src.read_text())

if out.exists(): shutil.rmtree(out)
out.mkdir(parents=True)

buckets = {}
for g in groups:
    key = g.get("bench","UNKNOWN").split("/")[0]
    buckets.setdefault(key, []).append(g)

for bench, lst in buckets.items():
    d = out / safe(bench)
    d.mkdir(parents=True, exist_ok=True)
    (d / "bench_blocks.json").write_text(json.dumps(lst, indent=2))

print(f"done: {len(buckets)} benches -> {out}")