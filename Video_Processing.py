import cv2
import numpy as np
import os

def exctract_keyframes_time_based(video_path, output_folder, trhld=30, max_time_interval=5):
    """
    Exctract keyframe base on a change of scene OR a specified time interval.

    Args:
        video path (str): path to the video on input.
        output folder(str): folder in which we will save the output.
        treshold (int): difference treshold for catching a changing scene.
        max_time_interval (int): maximum time that can pass between one sampling and another.
    """
    # try open the video
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"Error: impossible to open the file: {video_path}")
        return

    # Get the frame rate of the video (FPS) for calculate time
    fps = cap.get(cv2.CAP_PROP_FPS)
    if fps == 0:
        print("Error: impossible to establish the frame rate (FPS). Default value: 25")
        fps = 25 # Default value

    # Setting maximum number of frames that can pass without extracting 
    max_frames_interval = int(max_time_interval * fps)
    print(f"video info: {fps:.2f} FPS. A keyframe will be extract every {max_time_interval} second (~{max_frames_interval} frames) without any scene change.")

    # Creating output folder if not already existing
    if not os.path.exists(output_folder):
        print(f"creating out folder {output_folder}")
        os.makedirs(output_folder)

    # read the first frame
    ret, previous_frame = cap.read()
    if not ret:
        print("Error: Impossible to read the first frame of the video.")
        return

    previous_gray = cv2.cvtColor(previous_frame, cv2.COLOR_BGR2GRAY)

    # Always save the first frame
    file_name = os.path.join(output_folder, "keyframe_0000.jpg")
    cv2.imwrite(file_name, previous_frame)
    print(f"keyframe saved (Frame #0): {file_name} - reason: starting frame")

    keyframe_number = 1
    current_frame_num= 0
    # keep the count of the numebr of frames untill the last one
    last_frame_num = 0

    while True:
        ret, current_frame = cap.read()
        if not ret:
            break

        current_frame_num += 1
        current_gray = cv2.cvtColor(current_frame, cv2.COLOR_BGR2GRAY)
        
        # Calculating difference on the scene
        diff = cv2.absdiff(current_gray, previous_gray)
        mean_diff = np.mean(diff)

        # Calculating how many frames are passed since the last extraction
        frames_from_last_keyframe = current_frame_num - last_keyframe_num

        # --- Combined Logic Extraction ---
        # First Condition: Scene changing
        scene_change = mean_diff > trhld
        # Second condition: time passed
        time_passed = frames_from_last_keyframe >= max_frames_interval

        if scene_change or time_passed:
            reason = ""
            if scene_change:
                reason = f"Scene Changing (Diff: {mean_diff:.2f})"
            else:
                reason = "Time limit achived"

            # Saving keyframe
            file_name = os.path.join(output_folder, f"keyframe_{keyframe_number:04d}.jpg")
            cv2.imwrite(file_name, current_frame)
            print(f"Salvato keyframe (Frame #{current_frame_num}): {file_name} - Motivo: {reason}")
            
            # Updating counters
            keyframe_number += 1
            last_keyframe_num = current_frame_num # Reset the counter

        # Update the frame for the next one
        previous_gray = current_gray

    # realising resource
    cap.release()
    print("\nCompleted extraction.")
    print(f"Total frames analysed: {current_frame_num}")
    print(f"Total keyframe extracted: {keyframe_number}")


if __name__ == '__main__':
    # --- settings ---
    # video path
    file_video_input = 'input.mp4'
    
    # folder name for savings the images
    output_folder_images = 'keyframes_estratti_tempo'
    
    # Treshold for detect a changing scene (the lower it is more sensible it is)
    Treshold_difference = 25
    
    # Max second interval between two extraction
    max_second_interval = 5.0

    # --- execution ---
    if not os.path.exists(file_video_input):
        print(f"video file not founded: '{file_video_input}'. Ensure that the file exist and the path it's correct.")
    else:
        exctract_keyframes_time_based(
            file_video_input, 
            output_folder_images, 
            Treshold=Treshold_difference, 
            max_time=max_second_interval
        )