"""
Lane detection demo (no vehicles)
Draws left/right lane fill using Canny + Hough and
Outputs an annotated MP4 in outputs folder
"""
import argparse, pathlib, sys, time
import cv2, numpy as np
from tqdm import tqdm
from ultralytics import YOLO

def region_of_interest(img: np.ndarray, vertices):
    mask = np.zeros_like(img)
    cv2.fillPoly(mask, vertices, 255)
    return cv2.bitwise_and(img, mask) ## plenty of docs

def estimate_distance(bbox_w: float, focal_px=1000, car_w=2.0) -> float: ## this is chat i didnt know the math
    return (car_w * focal_px) / bbox_w

def process_video(src, dst, model_path, conf=0.25): ## main video process
    model = YOLO(model_path) # load yolo
    capture = cv2.VideoCapture(str(src)) 
    if not capture.isOpened():
        sys.exit(f"Cannot open {src}")

    fourcc = cv2.VideoWriter_fourcc(*"mp4v") ## specific video codec for mp4 to get data out
    out_w, out_h = int(capture.get(3)), int(capture.get(4))
    out = cv2.VideoWriter(str(dst), fourcc, capture.get(cv2.CAP_PROP_FPS), (out_w, out_h))

    frameCount = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
    pbar = tqdm(total=frameCount, unit="f", desc="processing")

    while True: ## reading while frfames are there, will break when it runs out
        ret, frame = capture.read()
        if not ret:
            break

        height, width = frame.shape[:2]
        roi_vertices = np.array([[ # boundaries for the region of interest
            (0, height),
            (int(width * 0.45), int(height * 0.6)),
            (int(width * 0.55), int(height * 0.6)),
            (width, height)
        ]], dtype=np.int32)

        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        edges = cv2.Canny(gray, 100, 200)
        cropped = region_of_interest(edges, roi_vertices)

        lines = cv2.HoughLinesP( ## from tutorial for how to use HoughLinesP
            cropped,
            rho=6,
            theta=np.pi / 60,
            threshold=160,
            minLineLength=40, 
            maxLineGap=25
        )

        if lines is not None:
            left, right = [], []
            for x1, y1, x2, y2 in lines[:,0]:
                slope = (y2 - y1) / (x2 - x1 + 1e-6)
                if slope < -0.3:   left.append((x1, y1, x2, y2))
                elif slope >  0.3: right.append((x1, y1, x2, y2)) ## THIS IS FROM A TUTORIAL

            def make_line(points):
                xs = [p[0] for p in points] + [p[2] for p in points]
                ys = [p[1] for p in points] + [p[3] for p in points]
                if len(xs) < 2: return None
                poly = np.polyfit(xs, ys, 1)
                y1, y2 = height, int(height * 0.6)
                x1, x2 = int((y1 - poly[1]) / poly[0]), int((y2 - poly[1]) / poly[0])
                return np.array([[x1, y1, x2, y2]])

            for line_pts, color in ((make_line(left), (0,255,0)),
                                    (make_line(right),(0,255,0))):
                if line_pts is not None:
                    x1,y1,x2,y2 = line_pts[0]
                    cv2.line(frame, (x1,y1), (x2,y2), color, 8)

        out.write(frame)
        pbar.update(1)

    pbar.close()
    out.release()
    capture.release()
    print(f"✅ Saved annotated video to {dst}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", help="input video file (mp4)")
    parser.add_argument("-o", "--output", help="output mp4", default=None)
    parser.add_argument("-m", "--model", help="YOLO weight",
                        default="models/yolov8n.pt")
    parser.add_argument("--conf", type=float, default=0.25)
    args = parser.parse_args()

    src = pathlib.Path(args.source).expanduser()
    dst = pathlib.Path(
        args.output or f"outputs/{src.stem}_annotated.mp4"
    ).expanduser()
    dst.parent.mkdir(parents=True, exist_ok=True)

    t0 = time.time()
    process_video(src, dst, args.model, args.conf)
    print(f"⏱️  Done in {time.time()-t0:.1f}s")