import csv
import os
import json

plant_to_data = {}

def load_dataset(file_path):
    """Loads the flower benefits dataset from a CSV file."""
    with open(file_path, newline='', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            # Using .lower() for case-insensitive matching
            plant_name = row["Common Name"].strip().lower()
            latin_name = row["Scientific Name"].strip()
            raw_effects = row["Medicinal Properties"]

            if not raw_effects or not plant_name or not latin_name:
                continue

            effects = {e.strip().lower() for e in raw_effects.split(";")}
            plant_to_data[plant_name] = (latin_name, effects)

def parse_user_input(user_input):
    """Parses a string of effects into a list."""
    separators = [",", ";"]
    for sep in separators:
        if sep in user_input:
            return [e.strip().lower() for e in user_input.split(sep) if e.strip()]
    return [user_input.strip().lower()] if user_input.strip() else []

def find_matching_flower(recognized_flowers, required_effects):
    """
    Finds the first flower from the recognized list that satisfies all required effects.
    """
    required = set(effect.lower() for effect in required_effects)
    
    # Iterate through the flowers that were actually found in the user's images
    for flower_name in recognized_flowers:
        flower_name_lower = flower_name.lower()
        # Check if we have this flower in our benefits dataset
        if flower_name_lower in plant_to_data:
            latin_name, available_effects = plant_to_data[flower_name_lower]
            # Check if this flower has all the effects the user wants
            if required.issubset(available_effects):
                # Found a suitable flower!
                return {"common_name": flower_name, "latin_name": latin_name}
    
    # If no match is found after checking all recognized flowers
    return None

def main():
    """
    Main function to run the matching process.
    """
    print("\n--- Task 3: Dataset Matcher ---")
    print("Loading dataset...")
    load_dataset("pfaf_plants_merged.csv")

    # Get the input directory from an environment variable
    input_dir = os.getenv('INPUT_DIR', 'storage/results')
    
    recognized_flowers_path = os.path.join(input_dir, 'recognized_flowers.json')
    desired_effect_path = os.path.join(input_dir, 'desired_effect.txt')

    # 1. Load the list of recognized flowers from the previous step
    try:
        with open(recognized_flowers_path, 'r') as f:
            recognized_flowers = json.load(f)
        print(f"Successfully loaded recognized flowers: {recognized_flowers}")
    except FileNotFoundError:
        print(f"Error: Could not find '{recognized_flowers_path}'. Aborting.")
        return

    # 2. Load the user's desired effect from a text file
    try:
        with open(desired_effect_path, 'r') as f:
            user_input = f.read().strip()
        effects = parse_user_input(user_input)
        print(f"Successfully loaded desired effects: {effects}")
    except FileNotFoundError:
        print(f"Error: Could not find '{desired_effect_path}'. Please create it. Aborting.")
        return

    if not recognized_flowers or not effects:
        print("Input data is missing. Cannot perform matching.")
        return

    # 3. Find the first recognized flower that matches the desired effects
    matching_flower = find_matching_flower(recognized_flowers, effects)

    # 4. Print the final result
    if matching_flower:
        print("\n--- Match Found! ---")
        print(f"The most suitable flower from your images is:")
        print(f"  - Common Name: {matching_flower['common_name']}")
        print(f"  - Scientific Name: {matching_flower['latin_name']}")
        print("--------------------")
    else:
        print("\n--- No Match Found ---")
        print("None of the flowers recognized in your images match the desired effects.")
        print("----------------------")

if __name__ == "__main__":
    main()