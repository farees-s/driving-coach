#!/usr/bin/env python
"""
Lane detection demo (no vehicles)
Draws left/right lane fill using Canny + Hough and
Outputs an annotated MP4 in outputs folder
"""
import argparse, pathlib, sys, time
import cv2, numpy as np

def region_of_interest(img: np.ndarray, vertices):
    mask = np.zeros_like(img)
    cv2.fillPoly(mask, vertices, 255)
    return cv2.bitwise_and(img, mask) ## plenty of docs

def process_video(src, dst): ## main video process
    capture = cv2.VideoCapture(str(src)) 
    if not capture.isOpened():
        sys.exit(f"Cannot open {src}")

    fourcc = cv2.VideoWriter_fourcc(*"mp4v") ## specific video codec for mp4 to get data out
    out_w, out_h = int(capture.get(3)), int(capture.get(4))
    out = cv2.VideoWriter(str(dst), fourcc, capture.get(cv2.CAP_PROP_FPS), (out_w, out_h))

    total = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
    processed = 0
    t0 = time.time()

    while True: ## reading while frfames are there, will break when it runs out
        ret, frame = capture.read()
        if not ret:
            break

        height, width = frame.shape[:2]
        roi_vertices = np.array([[
            (int(width * 0.15), int(height * 0.70)), 
            (int(width * 0.40), int(height * 0.52)),  
            (int(width * 0.60), int(height * 0.52)),  
            (int(width * 0.85), int(height * 0.70))   
        ]], dtype=np.int32)

        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        edges = cv2.Canny(gray, 100, 200)
        cropped = region_of_interest(edges, roi_vertices)

        lines = cv2.HoughLinesP(
            cropped,
            rho=2,
            theta=np.pi / 180,
            threshold=100,
            minLineLength=50,
            maxLineGap=50
        )

        if lines is not None:
            left, right = [], []
            for x1, y1, x2, y2 in lines[:,0]:
                slope = (y2 - y1) / (x2 - x1 + 1e-6)
                if slope < -0.5:   left.append((x1, y1, x2, y2))
                elif slope >  0.5: right.append((x1, y1, x2, y2))

            def make_line(points):
                xs = [p[0] for p in points] + [p[2] for p in points]
                ys = [p[1] for p in points] + [p[3] for p in points]
                if len(xs) < 2: return None
                poly = np.polyfit(xs, ys, 1)
                y1, y2 = height, int(height * 0.6)
                x1, x2 = int((y1 - poly[1]) / poly[0]), int((y2 - poly[1]) / poly[0])
                return np.array([[x1, y1, x2, y2]])

            for line_pts in (make_line(left), make_line(right)):
                if line_pts is not None:
                    x1,y1,x2,y2 = line_pts[0]
                    cv2.line(frame, (x1,y1), (x2,y2), (0,255,0), 8)

        out.write(frame)
        processed += 1
        if processed % 20 == 0 or processed == total:
            pct = processed/total*100
            elapsed = time.time()-t0
            print(f"processing {processed}/{total}  ({pct:5.1f}%)  {elapsed:5.1f}s", end="\r")

    print()  # newline after the final carriage return
    out.release()
    capture.release()
    print(f"Saved annotated video to {dst}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", help="input video file (mp4)")
    parser.add_argument("-o", "--output", help="output mp4", default=None)
    args = parser.parse_args()

    src = pathlib.Path(args.source).expanduser()
    dst = pathlib.Path(
        args.output or f"outputs/{src.stem}_annotated.mp4"
    ).expanduser()
    dst.parent.mkdir(parents=True, exist_ok=True)

    process_video(src, dst)
