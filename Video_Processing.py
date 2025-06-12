import cv2
import numpy as np
import os

def extract_keyframes_time_based(video_path, output_folder, threshold=30, max_time_interval=5):
    """
    Extract keyframes based on scene changes OR a specified time interval.

    Args:
        video_path (str): Path to the input video.
        output_folder (str): Folder where the extracted keyframes will be saved.
        threshold (int): Difference threshold to detect a scene change.
        max_time_interval (int): Maximum time (in seconds) allowed between two keyframes.
    """
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"Error: Unable to open the file: {video_path}")
        return

    fps = cap.get(cv2.CAP_PROP_FPS)
    if fps == 0:
        print("Warning: Unable to determine the frame rate. Using default value: 25 FPS.")
        fps = 25

    max_frames_interval = int(max_time_interval * fps)
    print(f"Video Info: {fps:.2f} FPS. A keyframe will be extracted every {max_time_interval} seconds (~{max_frames_interval} frames) if no scene change is detected.")

    if not os.path.exists(output_folder):
        print(f"Creating output folder: {output_folder}")
        os.makedirs(output_folder)

    ret, previous_frame = cap.read()
    if not ret:
        print("Error: Unable to read the first frame of the video.")
        return

    previous_gray = cv2.cvtColor(previous_frame, cv2.COLOR_BGR2GRAY)

    file_name = os.path.join(output_folder, "keyframe_0000.jpg")
    cv2.imwrite(file_name, previous_frame)
    print(f"Keyframe saved (Frame #0): {file_name} - Reason: Initial frame")

    keyframe_number = 1
    current_frame_num = 0
    last_keyframe_num = 0

    while True:
        ret, current_frame = cap.read()
        if not ret:
            break

        current_frame_num += 1
        current_gray = cv2.cvtColor(current_frame, cv2.COLOR_BGR2GRAY)

        diff = cv2.absdiff(current_gray, previous_gray)
        mean_diff = np.mean(diff)

        frames_since_last_keyframe = current_frame_num - last_keyframe_num

        scene_change = mean_diff > threshold
        time_exceeded = frames_since_last_keyframe >= max_frames_interval

        if scene_change or time_exceeded:
            reason = "Scene change" if scene_change else "Time interval exceeded"
            file_name = os.path.join(output_folder, f"keyframe_{keyframe_number:04d}.jpg")
            cv2.imwrite(file_name, current_frame)
            print(f"Keyframe saved (Frame #{current_frame_num}): {file_name} - Reason: {reason}")

            keyframe_number += 1
            last_keyframe_num = current_frame_num

        previous_gray = current_gray

    cap.release()
    print("\nExtraction complete.")
    print(f"Total frames analyzed: {current_frame_num}")
    print(f"Total keyframes extracted: {keyframe_number}")


if __name__ == '__main__':
    # --- Settings ---
    input_video_path = "C:/UNI/Distributed System and Cloud Computing/cloud-computing-project/input.mp4"
    output_folder_path = "C:/UNI/Distributed System and Cloud Computing/cloud-computing-project/key_frame_output_folder"
    threshold_difference = 25
    max_seconds_between_keyframes = 5.0

    # --- Execution ---
    if not os.path.exists(input_video_path):
        print(f"Video file not found: '{input_video_path}'. Please check the path.")
    else:
        extract_keyframes_time_based(
            video_path=input_video_path,
            output_folder=output_folder_path,
            threshold=threshold_difference,
            max_time_interval=max_seconds_between_keyframes
        )
