"""
Reads sample.mp4 + yolo type text line masks made by lane_car_detect.py
writes lane.csv:
csv columns: frame, timestamp_ms, lane_offset_px
"""
import cv2, csv, pathlib, numpy as np, time, sys

def lane_center(txt_path):
    if not txt_path.exists():
        return None         
    data = np.loadtxt(txt_path)
    if data.size == 0:        
        return None
    if data.ndim == 1:       
        data = data.reshape(1, -1)
    pts = data[:, :4]   
    x_mids = (pts[:, 0] + pts[:, 2]) / 2
    return x_mids.mean() if len(x_mids) else None

def run(video, txt_dir, out_csv):
    cap = cv2.VideoCapture(str(video))
    fps = cap.get(cv2.CAP_PROP_FPS)
    with open(out_csv, "w", newline="") as f:
        w = csv.writer(f); w.writerow(["frame","timestamp_ms","lane_offset_px"])
        i = 0
        while True:
            ok, _ = cap.read()
            if not ok: break
            lane_mid = lane_center(txt_dir / f"{i:06}.txt")
            if lane_mid:
                frame_mid = cap.get(cv2.CAP_PROP_FRAME_WIDTH)/2
                w.writerow([i, round(i*1000/fps), lane_mid - frame_mid])
            i += 1
    cap.release()

if __name__ == "__main__":
    vid = pathlib.Path(sys.argv[1])
    txt = pathlib.Path(sys.argv[2])
    out = pathlib.Path(sys.argv[3])
    out.parent.mkdir(parents=True, exist_ok=True)
    run(vid, txt, out)
