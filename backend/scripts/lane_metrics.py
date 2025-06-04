##Reads sample.mp4 + yolo type text line masks made by lane_car_detect.py
##writes lane.csv:
##csv columns: frame, timestamp_ms, lane_offset_px

import cv2, csv, pathlib, numpy as np, time, sys

def lane_center(txt_path): ## deciding lane center
    if not txt_path.exists():
        return None         
    data = np.loadtxt(txt_path)
    if data.size == 0:        
        return None
    if data.ndim == 1:       
        data = data.reshape(1, -1)
    points = data[:, :4] ## first 4
    left_x = points[:, 0] ## first left lane
    right_x = points[:, 2] ## first right lane
    x_midpoints = (left_x + right_x) / 2 


    if x_midpoints.size > 0:
        overall_lane_center = x_midpoints.mean()
    else:
        overall_lane_center = None
        
    return overall_lane_center

def run(video, txt_dir, out_csv):
    video_capture = cv2.VideoCapture(str(video))
    fps = video_capture.get(cv2.CAP_PROP_FPS)
    with open(out_csv, "w", newline="") as output_file:
        csv_writer = csv.writer(output_file)
        csv_writer.writerow(["frame", "timestamp_ms", "lane_offset_px"])
        frame_count = 0
        while True:
            success, frame = video_capture.read()
            if not success:
                break
            lane_center_position = lane_center(txt_dir / f"{frame_count:06}.txt") ## lane center for current frame
            if lane_center_position:
                frame_middle = video_capture.get(cv2.CAP_PROP_FRAME_WIDTH) / 2 # midpoint of frame                
                timestamp_ms = round(frame_count * 1000 / fps)
                csv_writer.writerow([frame_count, timestamp_ms, lane_center_position - frame_middle])            
            frame_count += 1    
    video_capture.release()

if __name__ == "__main__": # runner, chatgpt interfacing for running w command line args
    vid = pathlib.Path(sys.argv[1])
    txt = pathlib.Path(sys.argv[2])
    out = pathlib.Path(sys.argv[3])
    out.parent.mkdir(parents=True, exist_ok=True)
    run(vid, txt, out)
