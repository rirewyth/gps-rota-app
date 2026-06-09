
import os

path = r'c:\213\mountaineering_app\lib\screens\home_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Line 1111 (0-indexed 1110) is '              ),'
# We want to add '            ),' after it.
# Check if it matches to be safe.
if '),' in lines[1110]:
    lines.insert(1111, '            ),\n')
    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print("Fixed home_screen.dart")
else:
    print(f"Line 1111 mismatch: {repr(lines[1110])}")
