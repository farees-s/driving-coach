#!/usr/bin/env python
"""
Log Assetto Corsa shared‑memory telemetry to CSV (works in single‑player, CM, or server).
Requires `sim_info.py` (copied from AC SDK) in the same folder.
"""
import csv, datetime, pathlib, time, sys
from sim_info import info as ac_info      # AC’s helper exposes a global “info” object

# ---------- output ----------
OUT = pathlib.Path("data/raw")
OUT.mkdir(parents=True, exist_ok=True)
fname = OUT / f"telemetry_{datetime.datetime.now():%Y%m%d_%H%M%S}.csv"
FIELDS = ["timestamp", "speed_kmh", "throttle", "brake", "steer"]

def main() -> None:
    with open(fname, "w", newline="") as f:
        wr = csv.writer(f)
        wr.writerow(FIELDS)
        print(f"[LOGGER] Writing to {fname}  (Ctrl‑C to stop)")

        last_print = 0
        try:
            while True:
                # shared memory is updated ~333 Hz; just read current snapshot
                physics = ac_info.physics
                
                wr.writerow([
                    time.time(),
                    physics.speedKmh,
                    physics.gas,
                    physics.brake,
                    physics.steerAngle,
                ])

                # live console heartbeat once per second
                now = time.time()
                if now - last_print >= 1:
                    print(f"speed={physics.speedKmh:.1f} km/h  "
                          f"throttle={physics.gas:.2f}", end="\r")
                    last_print = now

                time.sleep(0.01)   # 100 samples/s is plenty
        except KeyboardInterrupt:
            print(f"\n[LOGGER] Stopped – file saved at {fname}")

if __name__ == "__main__":
    main()
