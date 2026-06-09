import os

def find_errors(filename):
    if not os.path.exists(filename):
        print(f"File {filename} not found.")
        return

    with open(filename, 'r', encoding='utf-8', errors='replace') as f:
        lines = f.readlines()

    found_anything = False
    for i, line in enumerate(lines):
        # Search for common failure indicators
        lower_line = line.lower()
        if 'error:' in lower_line or 'failed' in line or 'exception' in lower_line:
            found_anything = True
            print("-" * 40)
            print(f"Match found at line {i+1}:")
            # Print context (5 lines before and after)
            start = max(0, i - 10)
            end = min(len(lines), i + 10)
            for j in range(start, end):
                prefix = ">>>" if j == i else "   "
                print(f"{prefix} {j+1}: {lines[j].strip()}")
            print("-" * 40)
    
    if not found_anything:
        print("No obvious errors found in the log.")

if __name__ == "__main__":
    find_errors('full_build_log.txt')
