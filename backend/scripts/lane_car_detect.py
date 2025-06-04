
##Lane detection -- NO YOLOV8
##Draws left/right lane fill using Canny + Hough and
##Outputs annotated MP4 in outputs folder

import argparse, pathlib, sys, time
import cv2, numpy as np

def region_of_interest(img: np.ndarray, vertices):
    mask = np.zeros_like(img)
    cv2.fillPoly(mask, vertices, 255)
    return cv2.bitwise_and(img, mask) ## plenty of docs

def process_video(source, destination): ## main video process
    capture = cv2.VideoCapture(str(source)) 
    if not capture.isOpened():
        sys.exit(f"Cannot open {source}")

    codec = cv2.VideoWriter_fourcc(*"mp4v") ## specific video codec for mp4 to get data out
    output_width, output_height = int(capture.get(3)), int(capture.get(4))
    writer = cv2.VideoWriter(str(destination), codec, capture.get(cv2.CAP_PROP_FPS), (output_width, output_height))

    frames = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
    processed = 0
    start = time.time()

    while True: ## reading while frames are there, will break when it runs out
        success, frame = capture.read()
        if not success:
            break
        index = processed
        
        height, width = frame.shape[:2]
        vertices = np.array([[ ## chat fixed this, boundaries for region of interest
            (int(width * 0.15), int(height * 0.70)), 
            (int(width * 0.40), int(height * 0.52)),  
            (int(width * 0.60), int(height * 0.52)),  
            (int(width * 0.85), int(height * 0.70))   
        ]], dtype=np.int32)

        grayscale = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        edges = cv2.Canny(grayscale, 100, 200)
        roi = region_of_interest(edges, vertices)

        lines = cv2.HoughLinesP( ## documentation of how to use houghlinesp
            roi,
            rho=2,
            theta=np.pi / 180,
            threshold=100,
            minLineLength=50,
            maxLineGap=50
        )

        if lines is not None:
            left_points, right_points = [], []
            for x1, y1, x2, y2 in lines[:,0]:
                slope = (y2 - y1) / (x2 - x1 + 1e-6)
                if slope < -0.5:   left_points.append((x1, y1, x2, y2))
                elif slope >  0.5: right_points.append((x1, y1, x2, y2)) ## FROM SOME TUTORIAL

            def make_lane_line(points):
                x_coords = [p[0] for p in points] + [p[2] for p in points]
                y_coords = [p[1] for p in points] + [p[3] for p in points]
                if len(x_coords) < 2: return None
                fit = np.polyfit(x_coords, y_coords, 1) ## polynomial fit to get the line
                top = int(height * 0.6)
                bottom = height
                x_top = int((top - fit[1]) / fit[0])
                x_bottom = int((bottom - fit[1]) / fit[0])
                return np.array([[x_bottom, bottom, x_top, top]]) 

            for lane in (make_lane_line(left_points), make_lane_line(right_points)):
                if lane is not None:
                    x1,y1,x2,y2 = lane[0]
                    cv2.line(frame, (x1,y1), (x2,y2), (0,255,0), 8)
            directory = pathlib.Path("data/yolo/lane_demo/labels")
            directory.mkdir(parents=True, exist_ok=True)
            if lane is not None:
                np.savetxt(directory / f"{index:06}.txt",
                        lane.reshape(1,4),
                        fmt='%d')
        writer.write(frame)
        processed += 1
        if processed % 20 == 0 or processed == frames:
            percent = processed/frames*100
            elapsed = time.time()-start
            print(f"processing {processed}/{frames}  ({percent:5.1f}%)  {elapsed:5.1f}s", end="\r")

    print()  # newline after the final return
    writer.release()
    capture.release()
    print(f"Saved annotated video to {destination}")


    
if __name__ == "__main__": ## runner, chatgpt interfacing for running w command line args
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
