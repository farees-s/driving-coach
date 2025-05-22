import csv, datetime, pathlib, time, sys
from sim_info import info as ac_info     ## the "shared memory" into actually extracting it out and saving it to a csv

"""
Log Assetto Corsa shared‑memory telemetry to CSV (works in single‑player, CM, or server).
Requires `sim_info.py` (copied from AC SDK) in the same folder.
"""

OUT = pathlib.Path("data/raw") # output goes  here
OUT.mkdir(parents=True, exist_ok=True)
fname = OUT / f"telemetry_{datetime.datetime.now():%Y%m%d_%H%M%S}.csv" ## googled how to do the specific date and time thing
FIELDS = ["timestamp", "speed_kmh", "throttle", "brake", "steer"]

def main() -> None:
    with open(fname, "w", newline="") as f:
        wr = csv.writer(f) # plenty of documentation to make a csv writer
        wr.writerow(FIELDS)
        print(f"[LOGGER] Writing to {fname}  (Ctrl‑C to stop)") ## asked chat how to get it clearly as debug in git bash

        last_print = 0
        try:
            while True: ## for now this goes until i ^c and manually sstop it -- will change in later version when more developed
                # shared memory is updated ~333 Hz; just read current snapshot
                physics = ac_info.physics
                
                wr.writerow([ ## writerow function to.. write each thing to the csv. self explanatory
                    time.time(),
                    physics.speedKmh,
                    physics.gas,
                    physics.brake,
                    physics.steerAngle,
                ])

                now = time.time() # get time to have a timer to update something to the console every second
                if now - last_print >= 1:
                    print(f"speed={physics.speedKmh:.1f} km/h  "
                          f"throttle={physics.gas:.2f}", end="\r") # prints to console
                    last_print = now

                time.sleep(0.01)   # taking 100 data points per second 
        except KeyboardInterrupt:
            print(f"\n[LOGGER] Stopped – file saved at {fname}") # chat for how to mark it again

if __name__ == "__main__":
    main()
