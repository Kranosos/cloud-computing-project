import os
import cv2
import numpy as np
from google.cloud import storage
import tempfile

# --- Configuration ---
# These values are read from environment variables set in docker-compose.yml or GCP.
INPUT_BUCKET_NAME = os.getenv('INPUT_DIR')
OUTPUT_BUCKET_NAME = os.getenv('OUTPUT_DIR')

def extract_keyframes(video_path, output_folder, threshold=30, max_time_interval=5):
    """
    Extracts keyframes based on scene changes OR a specified time interval.
    This is your original, proven logic.
    """
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"Error: Unable to open video file: {video_path}")
        return 0

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
        return 0

    previous_gray = cv2.cvtColor(previous_frame, cv2.COLOR_BGR2GRAY)
    
    # Save the first frame
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
    print(f"Extraction complete. Found {keyframe_count} keyframes.")
    return keyframe_count

def main():
    if not INPUT_BUCKET_NAME or not OUTPUT_BUCKET_NAME:
        print("Error: INPUT_DIR and OUTPUT_DIR environment variables must be set.")
        return

    if not os.path.exists(INPUT_BUCKET_NAME):
        print(f"Error: Input directory '{INPUT_BUCKET_NAME}' does not exist.")
        return

    os.makedirs(OUTPUT_BUCKET_NAME, exist_ok=True)

    video_files = [
        f for f in os.listdir(INPUT_BUCKET_NAME)
        if f.lower().endswith(('.mp4', '.avi', '.mov'))
    ]

    if not video_files:
        print("No videos found in the input directory. Exiting.")
        return

    print("--- Starting Video Processing Service ---")

    for video_filename in video_files:
        video_path = os.path.join(INPUT_BUCKET_NAME, video_filename)
        video_name_base = os.path.splitext(video_filename)[0]
        output_subdir = os.path.join(OUTPUT_BUCKET_NAME, video_name_base)
        os.makedirs(output_subdir, exist_ok=True)

        print(f"\nProcessing '{video_filename}'...")
        keyframe_count = extract_keyframes(video_path, output_subdir)

        if keyframe_count > 0:
            print(f"Extracted {keyframe_count} keyframes to '{output_subdir}'.")
        else:
            print(f"Failed to extract keyframes from '{video_filename}'.")

    print("\n--- Video Processing Service Finished ---")


if __name__ == "__main__":
    main()