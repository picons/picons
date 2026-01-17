import unicodedata
from pathlib import Path
import sys
"""
Normalize the UTF-8 index file to Unicode Normalization Form C (NFC).

This module reads the file located at ../../build-source/utf8snp.index (relative to
this script), normalizes each line to Unicode Normalization Form C using
unicodedata.normalize('NFC'), strips leading/trailing whitespace from each line,
ensures a single trailing newline for each entry, and then overwrites the same
file with the normalized lines using UTF-8 encoding.

Intended purpose:
- Canonicalize Unicode sequences (e.g., combine decomposed characters into
    composed forms) in the repository's index file so downstream tools see
    consistent text representations.

Important notes:
- The operation is destructive: the original file is overwritten. Back up the
    file before running if preservation is required.
- The script relies on the given relative path; run it from the expected working
    directory or adjust the path accordingly.
- Empty or whitespace-only lines are trimmed to a single newline in the output.
"""

script_dir = Path(__file__).resolve().parent
# build-source is located at the repository root (two levels up from this script)
index_path = script_dir.parent.parent / 'build-source' / 'utf8snp.index'

if not index_path.exists():
    print(f"Error: index file not found: {index_path}")
    sys.exit(2)

with index_path.open('r', encoding='utf-8') as file:
    lines = file.readlines()

normalized_lines = [unicodedata.normalize('NFC', line.strip()) + '\n' for line in lines]

with index_path.open('w', encoding='utf-8') as file:
    file.writelines(normalized_lines)
