import os
import cv2
import numpy as np
from google.cloud import storage
import tempfile

# --- Configuration ---
# These values are read from environment variables set in docker-compose.yml or GCP.
INPUT_BUCKET_NAME = os.getenv('INPUT_BUCKET')
OUTPUT_BUCKET_NAME = os.getenv('OUTPUT_BUCKET')

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
    """
    Main workflow to download, process, and upload videos.
    """
    if not INPUT_BUCKET_NAME or not OUTPUT_BUCKET_NAME:
        print("Error: INPUT_BUCKET and OUTPUT_BUCKET environment variables must be set.")
        return

    storage_client = storage.Client()
    input_bucket = storage_client.bucket(INPUT_BUCKET_NAME)
    output_bucket = storage_client.bucket(OUTPUT_BUCKET_NAME)

    print("--- Starting Video Processing Service ---")
    print(f"Scanning for videos in bucket: gs://{INPUT_BUCKET_NAME}/")

    blobs_to_process = list(storage_client.list_blobs(INPUT_BUCKET_NAME))
    
    if not blobs_to_process:
        print("No videos found in the input bucket. Exiting.")
        return

    for blob in blobs_to_process:
        video_filename = blob.name
        # Use a temporary directory that gets automatically cleaned up
        with tempfile.TemporaryDirectory() as temp_dir:
            local_video_path = os.path.join(temp_dir, video_filename)
            local_keyframe_dir = os.path.join(temp_dir, "keyframes")

            print(f"\nProcessing '{video_filename}'...")
            
            # 1. Download video from GCS
            blob.download_to_filename(local_video_path)
            
            # 2. Extract keyframes to a local temporary folder
            extract_keyframes(local_video_path, local_keyframe_dir)

            # 3. Upload extracted keyframes to the output GCS bucket
            video_name_base = os.path.splitext(video_filename)[0]
            for frame_file in os.listdir(local_keyframe_dir):
                destination_blob_name = f"{video_name_base}/{frame_file}"
                local_frame_path = os.path.join(local_keyframe_dir, frame_file)
                
                new_blob = output_bucket.blob(destination_blob_name)
                new_blob.upload_from_filename(local_frame_path)
            
            print(f"Finished uploading keyframes for '{video_filename}'.")

    print("\n--- Video Processing Service Finished ---")

if __name__ == "__main__":
    main()