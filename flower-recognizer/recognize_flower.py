import os
import cv2
import json
import numpy as np
from keras.models import load_model
import sys

# --- Configuration ---
MODEL_PATH = "flower_classifier_model.h5"
CLASSES_PATH = "flower_classes.json"
IMAGE_SIZE = 128 # Must be the same size as used in training (128x128)

# --- Load the pre-trained model and class labels ---
try:
    model = load_model(MODEL_PATH)
    with open(CLASSES_PATH, 'r') as f:
        class_names = json.load(f)
    print("Model and class labels loaded successfully.")
except Exception as e:
    print(f"Error loading model or class labels: {e}")
    sys.exit(1)


def predict_flower(image_path):
    """
    Takes an image path, preprocesses it, and returns the predicted flower name.
    """
    try:
        # Load and preprocess the image
        img = cv2.imread(image_path)
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        im = cv2.resize(img_rgb, (IMAGE_SIZE, IMAGE_SIZE))
        im = np.expand_dims(im, axis=0) / 255.0

        # Make a prediction
        prediction = model.predict(im)
        predicted_class_index = np.argmax(prediction)
        predicted_class_name = class_names[predicted_class_index]

        return predicted_class_name
    except Exception as e:
        print(f"Could not process image {image_path}. Error: {e}")
        return None

def recognize_flowers_in_directory(directory_path):
    """
    Processes all images in a directory and returns a unique list of recognized flowers.
    """
    if not os.path.isdir(directory_path):
        print(f"Error: Directory not found at {directory_path}")
        return []

    recognized_flowers = set()
    print(f"\nScanning images in directory: {directory_path}")

    # Process subdirectories created by the video processor
    for dir_name in os.listdir(directory_path):
        sub_dir_path = os.path.join(directory_path, dir_name)
        if os.path.isdir(sub_dir_path):
            for filename in os.listdir(sub_dir_path):
                if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
                    image_path = os.path.join(sub_dir_path, filename)
                    flower_name = predict_flower(image_path)
                    if flower_name:
                        print(f"-> Found '{flower_name}' in {filename}")
                        recognized_flowers.add(flower_name)

    return list(recognized_flowers)


if __name__ == '__main__':
    # --- MODIFIED SECTION ---

    # 1. Get the input directory from command-line arguments
    if len(sys.argv) < 2:
        print("Usage: python recognize_flower.py <path_to_image_directory>")
        sys.exit(1)
    input_directory = sys.argv[1]

    # 2. Get the output directory from an environment variable
    output_dir = os.getenv('OUTPUT_DIR', 'storage/results')
    
    # Ensure the output directory exists
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        print(f"Created output directory: {output_dir}")

    # 3. Run the recognition process
    final_flower_list = recognize_flowers_in_directory(input_directory)

    # 4. Write the output to a JSON file
    output_filepath = os.path.join(output_dir, 'recognized_flowers.json')
    with open(output_filepath, 'w') as f:
        json.dump(final_flower_list, f, indent=2)

    # 5. Print a confirmation message to the console/logs
    if final_flower_list:
        print("\n--- Recognition Complete ---")
        print("Unique flowers found:", final_flower_list)
        print(f"Results have been saved to: {output_filepath}")
        print("--------------------------")
    else:
        print("\nNo flowers were recognized in the provided directory.")