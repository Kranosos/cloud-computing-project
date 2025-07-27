import os
import cv2
import json
import numpy as np
from keras.models import load_model
import sys

# --- Configuration ---
MODEL_PATH = "flower_classifier_model.h5"
CLASSES_PATH = "flower_classes.json"
IMAGE_SIZE = 128

# --- Load Model and Classes ---
try:
    model = load_model(MODEL_PATH)
    with open(CLASSES_PATH, 'r') as f:
        class_names = json.load(f)
    print("Model and class labels loaded successfully.")
except Exception as e:
    print(f"Error loading model or class labels: {e}")
    sys.exit(1)

def predict_flower(image_path):
    """Predicts the flower name from a single image path."""
    try:
        img = cv2.imread(image_path)
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        im = cv2.resize(img_rgb, (IMAGE_SIZE, IMAGE_SIZE))
        im = np.expand_dims(im, axis=0) / 255.0
        prediction = model.predict(im, verbose=0)
        predicted_class_index = np.argmax(prediction)
        return class_names[predicted_class_index]
    except Exception as e:
        print(f"Could not process image {image_path}. Error: {e}")
        return None

def recognize_flowers_in_directory(directory_path):
    """Processes all images in a directory and its subdirectories."""
    recognized_flowers = set()
    print(f"\nScanning images in directory: {directory_path}")
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
    
    output_filepath = os.path.join(output_dir, 'recognized_flowers.json')
    with open(output_filepath, 'w') as f:
        json.dump(final_flower_list, f, indent=2)

    if final_flower_list:
        print("\n--- Recognition Complete ---")
        print("Unique flowers found:", final_flower_list)
        print(f"Results saved to: {output_filepath}")
    else:
        print("\nNo flowers were recognized.")