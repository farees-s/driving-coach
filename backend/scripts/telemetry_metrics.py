#telemetry_metrics.py - get accel & jerk from raw telemetry.csv
#puts out telemetry_metrics.csv in same folder unless -o given.

import sys, pandas as pd, numpy as np, pathlib

def run(sourceCSV, destinationCSV=None): ##pandas jawn
    df = pd.read_csv(sourceCSV).sort_values("timestamp")
    dt   = df["timestamp"].diff()
    df["accel"] = df["speed_kmh"].diff()/dt
    df["jerk"]  = df["accel"].diff()/dt
    out = pathlib.Path(destinationCSV or pathlib.Path(src_csv).with_name("telemetry_metrics.csv"))
    df.to_csv(out, index=False)
    print(f"saved {out}")

if __name__ == "__main__": #what i haved learned from previous chatgpt tutorial of how to do the runner args
    if len(sys.argv) not in (2,3):
        sys.exit("usage: python src/telemetry_metrics.py telemetry.csv [out.csv]")
    run(*sys.argv[1:])
