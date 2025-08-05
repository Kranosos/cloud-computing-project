# File: recognize_flower.py (FINAL - Uses MobileNetV2)
import os
import json
import numpy as np
import sys
import cv2

# Import the necessary components from TensorFlow/Keras
from tensorflow.keras.applications.mobilenet_v2 import MobileNetV2, preprocess_input, decode_predictions
from tensorflow.keras.preprocessing import image as keras_image

# --- Configuration ---
# MobileNetV2 was trained on images of size 224x224
IMAGE_SIZE = 224

# --- Load Model ---
# This line downloads the MobileNetV2 model pre-trained on ImageNet.
# It only happens once and is cached inside the container for future runs.
try:
    print("Loading MobileNetV2 model...")
    model = MobileNetV2(weights='imagenet')
    print("MobileNetV2 model loaded successfully.")
except Exception as e:
    print(f"FATAL: Error loading model: {e}")
    sys.exit(1)


def predict_flower(image_path):
    """Predicts the object in an image and returns the name if it's a known flower."""
    try:
        # Load and prepare the image for the model
        img = keras_image.load_img(image_path, target_size=(IMAGE_SIZE, IMAGE_SIZE))
        img_array = keras_image.img_to_array(img)
        img_array_expanded = np.expand_dims(img_array, axis=0)
        
        # This is the special preprocessing function required for MobileNetV2
        processed_img = preprocess_input(img_array_expanded)

        # Get the model's prediction
        prediction = model.predict(processed_img, verbose=0)
        
        # Decode the prediction into human-readable labels from ImageNet
        decoded = decode_predictions(prediction, top=3)[0]

        # This list can be expanded with other flower types found in ImageNet
        known_flower_types = ['daisy', 'sunflower', 'poppy', 'rose', 'iris', 'tulip', 'water_lily', 'carnation', 'magnolia', 'bellflower', 'dandelion']
        
        for imagenet_id, name, score in decoded:
            if score > 0.1:
                print(f"-> Prediction: {name} ({score:.2f})")
                return name

        print(f"-> No confident prediction for {os.path.basename(image_path)}")
        return None
        
    except Exception as e:
        print(f"Warning: Could not process image {image_path}. Error: {e}")
        return None

def recognize_flowers_in_directory(directory_path):
    """Processes all images in a directory and its subdirectories."""
    recognized_flowers = set()
    print(f"\nScanning for flowers in directory: {directory_path}")
    if not os.path.exists(directory_path):
        print(f"Error: Input directory '{directory_path}' does not exist.")
        return []

    for root, dirs, files in os.walk(directory_path):
        for filename in files:
            if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
                image_path = os.path.join(root, filename)
                flower_name = predict_flower(image_path)
                if flower_name:
                    print(f"-> Found '{flower_name}' in {filename}")
                    recognized_flowers.add(flower_name)
    return list(recognized_flowers)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python recognize_flower.py <path_to_image_directory>")
        sys.exit(1)
        
    input_directory = sys.argv[1]
    output_dir = os.getenv('OUTPUT_DIR', 'storage/results')
    
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    final_flower_list = recognize_flowers_in_directory(input_directory)
    
    # Ensure the list is not empty before writing
    if not final_flower_list:
        print("\nNo flowers were recognized in any of the images.")
        # Write an empty list to the JSON file to signal no flowers were found
        final_flower_list = []
    else:
        print("\n--- Recognition Complete ---")
        print("Unique flowers found:", final_flower_list)

    output_filepath = os.path.join(output_dir, 'recognized_flowers.json')
    with open(output_filepath, 'w') as f:
        json.dump(final_flower_list, f, indent=2)
    print(f"Results saved to: {output_filepath}")