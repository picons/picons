import unicodedata
from os.path import dirname, isfile, realpath, sep, splitext
import re
import sys

if sys.stdout.encoding != "utf-8":
	sys.stdout.reconfigure(encoding="utf-8", errors="replace")


# Validates utf8snp.index and srp.index
# Checks utf8snp.index for: invalid characters in name, invalid characters in logo name (must match [a-z0-9_-]), duplicate keys
# Checks srp.index for: non-ASCII logo names, duplicate keys
# Exits with code 1 if any invalid characters or duplicates are found in utf8snp.index, or non-ASCII logo names in srp.index
# Duplicate srp keys are reported but do not cause a failure
# Does not modify any files



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
	print(f"=== Checking {file_path} ===")
	snames = {}
	sname_lines = {}
	invalid_msgs = []
	invalid_logo_msgs = []
	duplicate_msgs = []

	for i, line in enumerate(open(file_path, 'r', encoding="utf-8").read().splitlines()):
		rsp = line.rstrip().rsplit("=", 1)
		if len(rsp) != 2:
			continue
		name, logo = rsp
		if not re.match("^[0-9A-F]+[_][0-9A-F]+[_][0-9A-F]+[_][0-9A-F]+$", name, re.IGNORECASE):
			if any(c in name for c in ["\\", "/", ":", "*", "?", "\"", "<", ">", "|", "\0"]):
				invalid_msgs.append(f"line {i}, invalid character in name '{name}'")
				continue  # skip duplicate check for invalid entries
		invalid_logo_chars = sorted(set(c for c in logo if not re.match(r'[a-z0-9_-]', c)))
		if invalid_logo_chars:
			chars = ", ".join(repr(c) for c in invalid_logo_chars)
			invalid_logo_msgs.append(f"line {i}, invalid character(s) {chars} in logo name '{logo}'")
			continue  # skip duplicate check for invalid entries
		if re.match("^[0-9A-F]+[_][0-9A-F]+[_][0-9A-F]+[_][0-9A-F]+$", name, re.IGNORECASE):
			sname = name.upper()
		else:
			sname = name and (x := sanitizeFilename(name)) and x.lower()
		if not sname or sname == "__":
			continue
		if sname in snames:
			duplicate_msgs.append(f"line {i}, duplicate key '{sname}' already seen on line {sname_lines[sname]} (existing logo: {snames[sname]}, skipping logo: {logo} on line {i})")
		else:
			snames[sname] = logo
			sname_lines[sname] = i

	if invalid_msgs:
		print(f"{len(invalid_msgs)} invalid character(s) found in name:")
		for msg in invalid_msgs:
			print(msg)
	else:
		print("no invalid characters found in name")

	if invalid_logo_msgs:
		print(f"{len(invalid_logo_msgs)} invalid logo name(s) found:")
		for msg in invalid_logo_msgs:
			print(msg)
	else:
		print("no invalid logo names found")

	if duplicate_msgs:
		print(f"{len(duplicate_msgs)} duplicate(s) found:")
		for msg in duplicate_msgs:
			print(msg)
	else:
		print("no duplicates found")

	return len(invalid_msgs) + len(invalid_logo_msgs), len(duplicate_msgs)


def check_srp(file_path):
	print(f"=== Checking {file_path} ===")
	logos = {}
	logos_lines = {}
	invalid_msgs = []
	duplicate_msgs = []

	for i, line in enumerate(open(file_path, 'r', encoding="utf-8", errors='replace').read().splitlines()):
		rsp = line.rstrip().rsplit("=", 1)
		if len(rsp) != 2:
			continue
		ref, logo = rsp
		if not logo.isascii():
			invalid_msgs.append(f"line {i}, non-ASCII characters in logo name '{logo}'")
			continue
		ref = ref.upper()
		if ref in logos:
			duplicate_msgs.append(f"line {i}, duplicate key '{ref}' already seen on line {logos_lines[ref]} (existing logo: {logos[ref]}, skipping logo: {logo} on line {i})")
		else:
			logos[ref] = logo
			logos_lines[ref] = i

	if invalid_msgs:
		print(f"{len(invalid_msgs)} invalid logo name(s) found:")
		for msg in invalid_msgs:
			print(msg)
	else:
		print("no invalid logo names found")

	if duplicate_msgs:
		print(f"{len(duplicate_msgs)} duplicate(s) found:")
		for msg in duplicate_msgs:
			print(msg)
	else:
		print("no duplicates found")

	return len(invalid_msgs), len(duplicate_msgs)


build_source = f"{dir_path}{sep}..{sep}..{sep}build-source"

utf8snp_path = f"{build_source}{sep}utf8snp.index"
srp_path = f"{build_source}{sep}srp.index"

invalid = 0
duplicates = 0

if isfile(utf8snp_path):
	invalid, duplicates = check_utf8snp(utf8snp_path)
else:
	print(f"utf8snp.index not found at {utf8snp_path}")

print()

srp_invalid = 0
srp_duplicates = 0

if isfile(srp_path):
	srp_invalid, srp_duplicates = check_srp(srp_path)
else:
	print(f"srp.index not found at {srp_path}")

if invalid > 0 or duplicates > 0 or srp_invalid > 0:
	print()
	if invalid > 0:
		print(f"{invalid} invalid character(s) found in utf8snp.index (in name or logo) - logo names must only contain [a-z0-9_-], please correct before merging")
	if duplicates > 0:
		print(f"{duplicates} duplicate utf8snp name(s) found in utf8snp.index - please remove duplicate entries before merging")
	if srp_invalid > 0:
		print(f"{srp_invalid} non-ASCII logo name(s) found in srp.index - please correct before merging")
	if srp_duplicates > 0:
		print(f"{srp_duplicates} duplicate srp key(s) found in srp.index - please remove duplicate entries before merging")
	sys.exit(1)
