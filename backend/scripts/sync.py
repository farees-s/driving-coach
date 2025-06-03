"""
sync.py  – aligns telemetry.csv with lane.csv using a brake spike
Writes sync.json  
"""
import sys, json, pandas as pd, numpy as np, pathlib

def _first_spike(series, thresh):
    idx = series.gt(thresh).idxmax() ## checks for brake spike
    return idx if series.iloc[idx] > thresh else None

def run(tele_csv, lane_csv, out_json, brake_thresh=75, light_thresh=50): ## now it runs it
    tele = pd.read_csv(tele_csv)
    lane = pd.read_csv(lane_csv)
    i_horn  = _first_spike(tele["brake"], brake_thresh)
    i_light = _first_spike(lane["intensity"], light_thresh)
    if i_horn is None or i_light is None:
        sys.exit("Sync spike not found in one of the files")
    t0_tele = float(tele.loc[i_horn, "timestamp"])
    t0_lane = float(lane.loc[i_light, "timestamp"])
    offset  = t0_tele - t0_lane
    pathlib.Path(out_json).write_text(json.dumps({"t0": t0_tele, "offset": offset}))
    print(f"wrote {out_json}  (offset {offset:+.2f}s)")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: python src/sync.py telemetry.csv lane.csv sync.json")
    run(*sys.argv[1:])
