import cv2
import numpy as np
import os

def extract_keyframes(video_path, output_folder, threshold=30, max_time_interval=5):
    """
    Extracts keyframes based on scene changes OR a specified time interval.
    """
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"Error: Unable to open video file: {video_path}")
        return

    fps = cap.get(cv2.CAP_PROP_FPS)
    if fps == 0:
        print("Warning: Unable to determine FPS. Defaulting to 25.")
        fps = 25

    max_frames_interval = int(max_time_interval * fps)
    
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    ret, previous_frame = cap.read()
    if not ret:
        print("Error: Unable to read the first frame.")
        cap.release()
        return

    previous_gray = cv2.cvtColor(previous_frame, cv2.COLOR_BGR2GRAY)
    cv2.imwrite(os.path.join(output_folder, "keyframe_0000.jpg"), previous_frame)
    
    keyframe_count = 1
    frame_num = 0
    last_keyframe_num = 0

    while True:
        ret, current_frame = cap.read()
        if not ret:
            break

        frame_num += 1
        current_gray = cv2.cvtColor(current_frame, cv2.COLOR_BGR2GRAY)
        diff = cv2.absdiff(current_gray, previous_gray)
        mean_diff = np.mean(diff)

        if (mean_diff > threshold) or (frame_num - last_keyframe_num >= max_frames_interval):
            filename = os.path.join(output_folder, f"keyframe_{keyframe_count:04d}.jpg")
            cv2.imwrite(filename, current_frame)
            keyframe_count += 1
            last_keyframe_num = frame_num

        previous_gray = current_gray

    cap.release()
    print(f"Extraction complete for {video_path}. Found {keyframe_count} keyframes.")

if __name__ == '__main__':
    input_dir = os.getenv('INPUT_DIR', 'storage/input')
    output_dir = os.getenv('OUTPUT_DIR', 'storage/processed')
    
    print(f"Searching for videos in: {input_dir}")
    if not os.path.isdir(input_dir):
        print(f"Input directory not found: '{input_dir}'. Exiting.")
    else:
        for filename in os.listdir(input_dir):
            if filename.lower().endswith(('.mp4', '.mov', '.avi')):
                video_path = os.path.join(input_dir, filename)
                print(f"\n--- Processing video: {filename} ---")
                
                video_name_without_ext = os.path.splitext(filename)[0]
                video_output_folder = os.path.join(output_dir, video_name_without_ext)
                
                extract_keyframes(
                    video_path=video_path,
                    output_folder=video_output_folder
                )