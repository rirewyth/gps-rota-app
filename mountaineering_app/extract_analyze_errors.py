import os

def filter_analyze(input_file, output_file):
    if not os.path.exists(input_file):
        print(f"{input_file} not found")
        return
        
    # Try different encodings for Windows PowerShell output
    for enc in ['utf-16', 'utf-8', 'cp1252']:
        try:
            with open(input_file, 'r', encoding=enc, errors='replace') as f:
                lines = f.readlines()
            print(f"Read {len(lines)} lines with {enc}")
            break
        except Exception:
            continue
    else:
        print("Could not read file with any encoding")
        return

    errors = [line.strip() for line in lines if ' error ' in line.lower() or line.strip().lower().startswith('error')]
    
    with open(output_file, 'w', encoding='utf-8') as f:
        if not errors:
            f.write("No errors found in the analysis log.\n")
        for err in errors:
            f.write(err + "\n")
    print(f"Wrote {len(errors)} errors to {output_file}")

if __name__ == "__main__":
    filter_analyze('analyze_full.txt', 'filtered_errors.txt')
