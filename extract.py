import json
import csv
import sys
from pathlib import Path

def main(json_path: Path, csv_path: Path):
    with json_path.open() as f:
        blocks = json.load(f)

    with csv_path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["bench", "src", "pc", "latency"])
        for blk in blocks:
            bench       = blk.get("bench", "")
            src         = blk.get("src", "")
            pcs_list    = blk.get("pcs", [])
            stage_count = blk.get("stage_count", 0)

            for idx, pc in enumerate(pcs_list):
                latency = stage_count if idx == 0 else 0
                writer.writerow([bench, src, pc, latency])

            writer.writerow([])

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} result_augmented.json summary.csv")
        sys.exit(1)
    json_path = Path(sys.argv[1])
    csv_path  = Path(sys.argv[2])
    main(json_path, csv_path)
