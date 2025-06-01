import subprocess, numpy as np, pathlib, sys, pandas as pd

def test_offsets(tmp_path):
    # fake two frames + masks
    w,h = 640,480
    frames = np.zeros((2,h,w,3), np.uint8)
    vid = tmp_path/"test.mp4"
    import cv2; fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    out = cv2.VideoWriter(str(vid), fourcc, 1, (w,h))
    out.write(frames[0]); out.write(frames[1]); out.release()

    label_dir = tmp_path/"labels"; label_dir.mkdir()
    np.savetxt(label_dir/"000000.txt", [[100,0, 100,h]], fmt='%d')
    np.savetxt(label_dir/"000001.txt", [[540,0, 540,h]], fmt='%d')

    csv_out = tmp_path/"lane.csv"
    subprocess.run([sys.executable, "src/lane_metrics.py", vid, label_dir, csv_out], check=True)    
    df = pd.read_csv(csv_out)
    assert df["lane_offset_px"].iloc[0] < 0 
    assert df["lane_offset_px"].iloc[1] > 0  
