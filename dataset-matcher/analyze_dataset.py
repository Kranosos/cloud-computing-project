import pandas as pd

def find_matches():
    """
    Loads the PFAF dataset and finds which of the 16 flower classes
    have medicinal properties listed.
    """
    # Define the list of the 16 flower classes your model recognizes
    flower_classes = [
        'astilbe', 'bellflower', 'black_eyed_susan', 'calendula',
        'california_poppy', 'carnation', 'common_daisy', 'coreopsis',
        'dandelion', 'iris', 'rose', 'sunflower', 'tulip', 'water_lily',
        'magnolia', 'foxglove'
    ]

    csv_file = 'pfaf_plants_merged.csv'

    try:
        df = pd.read_csv(csv_file)
        print(f"Successfully loaded {csv_file}")

        # Prepare for case-insensitive matching
        df['Common Name Lower'] = df['Common Name'].str.lower()

        # Filter the DataFrame to find matches
        matches = df[df['Common Name Lower'].isin(flower_classes)]

        if not matches.empty:
            print("\n--- ✅ Found Matches ---")
            for index, row in matches.iterrows():
                common_name = row['Common Name']
                properties = row['Medicinal Properties']

                if pd.notna(properties):
                    print(f"\n🌸 Flower: {common_name}")
                    print(f"   Properties: {properties}")
                else:
                    print(f"\n🌸 Flower: {common_name}")
                    print(f"   Properties: None listed.")
            print("\n----------------------")
        else:
            print("\n--- ❌ No Matches Found ---")
            print("Could not find any of the 16 flower classes in the CSV file.")

    except FileNotFoundError:
        print(f"Error: The file '{csv_file}' was not found in this directory.")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == '__main__':
    find_matches()