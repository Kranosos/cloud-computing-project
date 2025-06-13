import csv

plant_to_data = {}

def load_dataset(file_path):
    with open(file_path, newline='', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            plant_name = row["Common Name"].strip()
            latin_name = row["Scientific Name"].strip()
            raw_effects = row["Medicinal Properties"]

            if not raw_effects or not plant_name or not latin_name:
                continue

            effects = {e.strip().lower() for e in raw_effects.split(";")}
            plant_to_data[plant_name] = (latin_name, effects)

def get_plants_for_effects(required_effects):
    required = set(effect.lower() for effect in required_effects)
    matching_plants = []

    for common_name, (latin_name, effects) in plant_to_data.items():
        if required.issubset(effects):
            matching_plants.append((common_name, latin_name))

    return matching_plants

def parse_user_input(user_input):
    separators = [",", ";"]
    for sep in separators:
        if sep in user_input:
            return [e.strip().lower() for e in user_input.split(sep) if e.strip()]
    return [user_input.strip().lower()] if user_input.strip() else []

def main():
    print("Loading dataset...")
    load_dataset("pfaf_plants_merged.csv")

    print("Medicinal Plant Finder")
    user_input = input("Enter desired effects (comma- or semicolon-separated): ")
    effects = parse_user_input(user_input)

    if not effects:
        print("No valid effects provided.")
        return

    plant_list = get_plants_for_effects(effects)
    if plant_list:
        print("\nPlants matching all effects:")
        for common_name, latin_name in plant_list:
            print(f"- {common_name}, {latin_name}")
    else:
        print("No matching plants found.")

if __name__ == "__main__":
    main()
