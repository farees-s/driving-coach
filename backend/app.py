from fastapi import FastAPI, UploadFile, File
from fastapi.responses import JSONResponse
from pathlib import Path
import subprocess, uuid

app = FastAPI(title="Driving Coach backend")

BASE = Path.home() / "DrivingCoachData" # directory for storing session data
BASE.mkdir(parents=True, exist_ok=True)

def run(cmd): # running shell commands
    subprocess.check_call(cmd,
        stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT) #

@app.post("/process") 
async def process_video(video: UploadFile = File(...)): # process video file
    sid = uuid.uuid4().hex # session id maker
    sess = BASE / sid # session dir
    sess.mkdir()

    vid_path = sess / "drive.mp4"
    with open(vid_path, "wb") as f:
        f.write(await video.read())

    run(["python3", "scripts/lane_car_detect.py",
         str(vid_path), "-o", str(sess/"annotated.mp4")]) ## running lane detection

    run(["python3", "scripts/lane_metrics.py", ## extracting yolo like metrics
         str(vid_path),
         "data/yolo/lane_demo/labels",
         str(sess/"lane.csv")])

    return JSONResponse({ ## returning the session id and path to lane metrics csv
        "id": sid,
        "lane_csv": str(sess/"lane.csv") ## path to the lane metrics csv
    })
