#!/usr/bin/env python3
"python tools/choose_blocks.py <blk_dir> id0 id1 ... [-o out.json]"

from pathlib import Path
import argparse, json, re, sys

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("blk_dir", help="directory produced by split_block.py")
    ap.add_argument("ids", nargs="+", help="decimal ids from filename, e.g. 0 7 11")
    ap.add_argument("-o", "--out", default=None)
    args = ap.parse_args()

    blk_dir = Path(args.blk_dir)
    if not blk_dir.is_dir():
        sys.exit("blk_dir must be a directory")

    candidates = sorted(p for p in blk_dir.glob("blk*.json")
                        if re.match(r"blk\d{3}_", p.name))
    if not candidates:
        sys.exit("no block files found in the directory")

    try:
        want = {int(x) for x in args.ids}
    except ValueError:
        sys.exit("ids must be decimal numbers (e.g. 0 3 11)")

    chosen = [
        p for p in candidates
        if int(re.search(r"blk(\d{3})_", p.name).group(1)) in want
    ]
    if not chosen:
        sys.exit("no blocks matched the given ids")

    out_path = (
        Path(args.out)
        if args.out
        else blk_dir.parent / "selected_blocks.json"
    )
    blocks = [json.loads(p.read_text()) for p in chosen]
    out_path.write_text(json.dumps(blocks, indent=2))
    print(f"✓ {len(blocks)} blocks → {out_path}")

if __name__ == "__main__":
    main()
