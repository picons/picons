import unicodedata
from os.path import dirname, isfile, realpath, sep, splitext
import re
import sys


# Reports duplicate entries in utf8snp.index and srp.index
# Does not modify any files
# Exits with code 1 if invalid characters are found in utf8snp.index


dir_path = dirname(realpath(__file__))


def sanitizeFilename(filename, maxlen=255):
	"""
	This function is a copy of enigma2 Directories.sanitizeFilename so we can be consistent with enigma2
	"""
	blacklist = ["\\", "/", ":", "*", "?", "\"", "<", ">", "|", "\0"]
	reserved = [
		"CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5",
		"COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5",
		"LPT6", "LPT7", "LPT8", "LPT9",
	]
	filename = unicodedata.normalize("NFKD", "".join(c for c in filename if c not in blacklist and ord(c) > 31)).strip()
	if all([x == "." for x in filename]) or filename in reserved:
		filename = "__" + filename
	root, ext = splitext(filename.encode(encoding='utf-8', errors='ignore'))
	if len(ext) > maxlen - (1 if root else 0):
		ext = ext[:maxlen - (1 if root else 0)]
	filename = root[:maxlen - len(ext)].decode(encoding='utf-8', errors='ignore') + ext.decode(encoding='utf-8', errors='ignore')
	filename = filename.rstrip(". ")
	if len(filename) == 0:
		filename = "__"
	return filename


def check_utf8snp(file_path):
	print(f"=== Checking {file_path} for duplicates ===")
	snames = {}
	sname_lines = {}
	duplicates = 0
	invalid = 0
	for i, line in enumerate(open(file_path, 'r', encoding="utf-8").read().splitlines()):
		rsp = line.rstrip().rsplit("=", 1)
		if len(rsp) != 2:
			continue
		name, logo = rsp
		if not re.match("^[0-9A-F]+[_][0-9A-F]+[_][0-9A-F]+[_][0-9A-F]+$", name, re.IGNORECASE):
			if any(c in name for c in ["\\", "/", ":", "*", "?", "\"", "<", ">", "|", "\0"]):
				print(f"line {i}, invalid character in name '{name}'")
				invalid += 1
		if re.match("^[0-9A-F]+[_][0-9A-F]+[_][0-9A-F]+[_][0-9A-F]+$", name, re.IGNORECASE):
			sname = name.upper()
		else:
			sname = name and (x := sanitizeFilename(name)) and x.lower()
		if not sname or sname == "__":
			continue
		if sname in snames:
			print(f"line {i}, duplicate key '{sname}' already seen on line {sname_lines[sname]} (existing logo: {snames[sname]}, skipping logo: {logo} on line {i})")
			duplicates += 1
		else:
			snames[sname] = logo
			sname_lines[sname] = i
	if duplicates == 0:
		print("no duplicates found")
	else:
		print(f"{duplicates} duplicate(s) found")
	return invalid


def check_srp(file_path):
	print(f"=== Checking {file_path} for duplicates ===")
	logos = {}
	logos_lines = {}
	duplicates = 0
	for i, line in enumerate(open(file_path, 'r', encoding="utf-8").read().splitlines()):
		rsp = line.rstrip().rsplit("=", 1)
		if len(rsp) != 2:
			continue
		ref, logo = rsp
		ref = ref.upper()
		if ref in logos:
			print(f"line {i}, duplicate key '{ref}' already seen on line {logos_lines[ref]} (existing logo: {logos[ref]}, skipping logo: {logo} on line {i})")
			duplicates += 1
		else:
			logos[ref] = logo
			logos_lines[ref] = i
	if duplicates == 0:
		print("no duplicates found")
	else:
		print(f"{duplicates} duplicate(s) found")


build_source = f"{dir_path}{sep}..{sep}..{sep}build-source"

utf8snp_path = f"{build_source}{sep}utf8snp.index"
srp_path = f"{build_source}{sep}srp.index"

invalid = 0

if isfile(utf8snp_path):
	invalid = check_utf8snp(utf8snp_path)
else:
	print(f"utf8snp.index not found at {utf8snp_path}")

print()

if isfile(srp_path):
	check_srp(srp_path)
else:
	print(f"srp.index not found at {srp_path}")

if invalid > 0:
	print(f"\n{invalid} invalid character(s) found in utf8snp.index - failing build")
	sys.exit(1)
