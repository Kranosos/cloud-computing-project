import os
import cv2
import numpy as np
import sys

# Get paths from environment variables provided by docker-compose.yml
INPUT_DIR = os.getenv('INPUT_DIR', 'storage/input')
OUTPUT_DIR = os.getenv('OUTPUT_DIR', 'storage/processed')

def extract_keyframes(video_path, output_folder, threshold=25, max_time_interval=5.0):
    # At the start of extract_keyframes
    print(f"[METRIC] START video_processing for {video_path}")
    """Extracts keyframes from a single video file."""
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"Error: Unable to open video: {video_path}")
        return
        
    fps = cap.get(cv2.CAP_PROP_FPS)
    if fps == 0: fps = 25 # Default FPS if unable to determine
    
    max_frames_interval = int(max_time_interval * fps)
    
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
        
    ret, prev_frame = cap.read()
    if not ret:
        print(f"Error: Could not read the first frame of {video_path}")
        cap.release()
        return
        
    prev_gray = cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY)
    cv2.imwrite(os.path.join(output_folder, "keyframe_0000.jpg"), prev_frame)
    
    count = 1
    frame_num = 0
    last_keyframe_num = 0
    
    while True:
        ret, frame = cap.read()
        if not ret:
            break
            
        frame_num += 1
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        diff = cv2.absdiff(gray, prev_gray)
        
        if (np.mean(diff) > threshold) or (frame_num - last_keyframe_num >= max_frames_interval):
            cv2.imwrite(os.path.join(output_folder, f"keyframe_{count:04d}.jpg"), frame)
            count += 1
            last_keyframe_num = frame_num
            
        prev_gray = gray
        
    cap.release()
    print(f"Extracted {count} keyframes from {os.path.basename(video_path)}")
    # At the end of extract_keyframes
    print(f"[METRIC] END video_processing for {video_path}")

if __name__ == "__main__":
    print(f"--- Video Processor Service ---")
    print(f"Watching for videos in: {INPUT_DIR}")
    
    # Check if the input directory is empty
    if not os.listdir(INPUT_DIR):
        print("Input directory is empty. No videos to process.")
    else:
        for filename in os.listdir(INPUT_DIR):
            if filename.lower().endswith(('.mp4', '.mov', '.avi')):
                video_path = os.path.join(INPUT_DIR, filename)
                video_name = os.path.splitext(filename)[0]
                output_subdir = os.path.join(OUTPUT_DIR, video_name)
                print(f"Processing {filename}...")
                extract_keyframes(video_path, output_subdir)
                
    print("--- Video processing complete. ---")