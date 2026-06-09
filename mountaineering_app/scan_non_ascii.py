import os
import re

# Regex for non-ASCII characters
non_ascii = re.compile(r'[^\x00-\x7F]')

def scan_dir(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                path = os.path.join(root, file)
                try:
                    with open(path, 'r', encoding='utf-8') as f:
                        lines = f.readlines()
                    for i, line in enumerate(lines):
                        if non_ascii.search(line):
                            # Filter out strings and comments if possible, but for now just show all
                            # We care about identifiers like _çevrimdışıHaritaİndir
                            print(f"{path}:{i+1}: {line.strip()}")
                except Exception as e:
                    print(f"Error reading {path}: {e}")

if __name__ == "__main__":
    scan_dir('lib')
