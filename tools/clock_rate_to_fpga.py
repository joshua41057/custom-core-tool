# clock_rate_to_fpga.py
from __future__ import annotations
import csv, sys
from pathlib import Path

FPGA_FREQ_MHZ = 350.0

CPUS = [
    ("Intel Atom D510", 1670.0, "AtomD510_1.67GHz"),
    ("Intel Atom C2750", 2400.0, "AtomC2750_2.40GHz"),
    ("Intel Atom E3845", 1910.0, "AtomE3845_1.91GHz"),
    ("Intel Core i7-4770K", 3500.0, "Core_i7_4770K_3.50GHz"),
    ("Intel Xeon X5560(Gainestown)", 2800.0, "Xeon_X5560_2.80GHz"),
]

def adjust_latency_cell(val: str, cpu_mhz: float) -> str:
    try:
        v = float(val)
    except Exception:
        return val
    if v <= 0:
        return "0"
    ratio = cpu_mhz / FPGA_FREQ_MHZ
    scaled = int(round(v * ratio))
    return str(max(1, scaled))

def process(in_csv: Path) -> list[Path]:
    if not in_csv.exists():
        raise FileNotFoundError(f"Input CSV not found: {in_csv}")

    with in_csv.open("r", newline="") as f:
        rows = list(csv.reader(f))

    if not rows:
        raise ValueError("Input CSV is empty.")

    header = rows[0]
    try:
        lat_idx = header.index("latency")
    except ValueError:
        raise ValueError("CSV header must contain a 'latency' column.")

    out_paths: list[Path] = []
    for _, cpu_mhz, tag in CPUS:
        out_path = in_csv.parent / f"{in_csv.stem}_scaled_{tag}.csv"
        with out_path.open("w", newline="") as fo:
            w = csv.writer(fo)
            w.writerow(header)
            for r in rows[1:]:
                if len(r) == 0:
                    w.writerow(r) 
                    continue
                r2 = r[:]
                if len(r2) > lat_idx:
                    r2[lat_idx] = adjust_latency_cell(r2[lat_idx], cpu_mhz)
                w.writerow(r2)
        out_paths.append(out_path)
    return out_paths

def main():
    if len(sys.argv) != 2:
        print("Usage: python .py <input_csv_path>")
        sys.exit(1)
    in_csv = Path(sys.argv[1])
    outs = process(in_csv)
    print("Generated files:")
    for p in outs:
        print(p)

if __name__ == "__main__":
    main()
