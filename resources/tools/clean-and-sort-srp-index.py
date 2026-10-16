from os.path import dirname, isfile, realpath, sep
import re
import sys
import urllib.request

if sys.stdout.encoding != "utf-8":
	sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# cleans and sorts srp.index

CYAN   = "\033[96m"
GREEN  = "\033[92m"
YELLOW = "\033[93m"
RED    = "\033[91m"
GRAY   = "\033[90m"
BOLD   = "\033[1m"
RST    = "\033[0m"


def info(msg):
	print(f"  {GRAY}info {RST}  {msg}")


def warn(msg):
	print(f"  {YELLOW}warn {RST}  {msg}")


def error(msg):
	print(f"  {RED}ERROR{RST}  {msg}")


def rsort(ref):
	# sort by namespace (orb pos), then ONID, then TSID, then SID
	x = ref.split("_")
	return (int(x[3], 16), int(x[2], 16), int(x[1], 16), int(x[0], 16))


def is_valid_ref(value):
	"""Trimmed service reference: exactly 4 hex parts separated by underscores."""
	if value.count("_") != 3:
		return False
	if "__" in value:
		return False
	if value.startswith("_") or value.endswith("_"):
		return False
	parts = value.split("_")
	if len(parts) != 4:
		return False
	for part in parts:
		if not part or not re.match(r'^[0-9A-Fa-f]+$', part):
			return False
	if len(parts[3]) < 6:  # namespace is always at least 6 hex digits
		return False
	return True


dir_path = dirname(realpath(__file__))
filename = "srp.index"
file_path = f"{dir_path}{sep}..{sep}..{sep}build-source{sep}{filename}"

in_repo = isfile(file_path)

if not in_repo:  # tool not running from the repo, test /tmp
	file_path = f"{sep}tmp{sep}{filename}"

if not isfile(file_path):  # fetch to local from repo if necessary
	open(file_path, "w").write(urllib.request.urlopen(f"https://raw.githubusercontent.com/picons/picons/master/build-source/{filename}").read().decode())

logos = {}
logos_lines = {}  # track which line each ref was first seen on
errors = 0
missing_eq = 0
invalid_ref = 0
invalid_logo = 0
fatal_encoding = False
fixed_lines = []
error_lines = []
duplicates_removed = 0
empty_skipped = 0

try:
	with open(file_path, "rb") as f:
		raw_bytes = f.read()
except FileNotFoundError:
	error(f"File not found: {file_path!r}")
	sys.exit(1)
except OSError as e:
	error(f"Read error: {e}")
	sys.exit(1)

# Decode line by line (rather than the whole file at once) so we can
# pinpoint exactly which line/byte is bad instead of silently replacing
# bad bytes with a placeholder character and writing corrupted data back out.
decoded_lines = []
for lineno, raw_line in enumerate(raw_bytes.splitlines(keepends=True), start=1):
	try:
		decoded_lines.append(raw_line.decode("utf-8"))
	except UnicodeDecodeError as e:
		preview = raw_line.replace(b"\n", b"").replace(b"\r", b"")[:60]
		error(f"Line {lineno}: corrupted text (invalid byte 0x{raw_line[e.start]:02X} at position {e.start}) -> {preview!r}")
		fatal_encoding = True

if fatal_encoding:
	print()
	print(f"  {RED}{BOLD}Aborted:{RST} file contains corrupted/unreadable text -- file not modified. Fix the srp.index file and re-run.\n")
	sys.exit(1)

orig = "".join(decoded_lines)
total_lines = len(decoded_lines)

for i, line in enumerate(orig.splitlines(), start=1):
	stripped = line.strip()
	if not stripped:
		empty_skipped += 1
		continue

	if line != line.rstrip():
		info(f"Line {i}: trailing whitespace removed")
		line = line.rstrip()
		fixed_lines.append(i)

	rsp = line.rsplit("=", 1)
	if not len(rsp) == 2:
		error(f"Line {i}: missing '=' sign: {line!r}")
		missing_eq += 1
		continue
	ref, logo = rsp

	if logo != logo.lower():
		info(f"Line {i}: logo lowercased  {logo!r} -> {logo.lower()!r}")
		logo = logo.lower()
		fixed_lines.append(i)

	# Invalid characters (e.g. a stray space) or an empty logo name are
	# mistakes the submitter needs to fix -- this aborts the whole save.
	if not logo:
		error(f"Line {i}: empty logo name")
		invalid_logo += 1
		continue

	invalid_logo_chars = sorted(set(c for c in logo if not re.match(r'[a-z0-9_-]', c)))
	if invalid_logo_chars:
		chars = ", ".join(repr(c) for c in invalid_logo_chars)
		error(f"Line {i}: invalid character(s) {chars} in logo name '{logo}'")
		invalid_logo += 1
		continue

	if not is_valid_ref(ref):
		error(f"Line {i}: {ref!r} is not a valid trimmed service reference (bad underscores, wrong part count, non-hex value, or namespace too short)")
		invalid_ref += 1
		continue

	if ref != ref.upper():
		info(f"Line {i}: service reference uppercased  {ref!r} -> {ref.upper()!r}")
		ref = ref.upper()
		fixed_lines.append(i)

	if ref in logos:
		warn(f"Line {i}: duplicate service reference {ref!r} (first seen at line {logos_lines[ref]}) — removed")
		duplicates_removed += 1
		continue

	logos[ref] = logo
	logos_lines[ref] = i

if missing_eq or invalid_ref or invalid_logo:
	print()
	if missing_eq:
		print(f"  {RED}{BOLD}Aborted:{RST} {missing_eq} line(s) missing '=' sign -- file not modified. Fix the srp.index file and re-run.")
	if invalid_ref:
		print(f"  {RED}{BOLD}Aborted:{RST} {invalid_ref} invalid service reference(s) found -- file not modified. Fix the srp.index file and re-run.")
	if invalid_logo:
		print(f"  {RED}{BOLD}Aborted:{RST} {invalid_logo} invalid logo name(s) found -- file not modified. Fix the srp.index file and re-run.")
	print()
	sys.exit(1)

out = "".join([k + "=" + logos[k] + "\n" for k in sorted(logos.keys(), key=rsort)])
saved = out != orig
if saved:
	if in_repo:
		open(file_path, 'w', encoding="utf-8", newline="\n").write(out)
		save_msg = f"changes saved in {file_path}"
	else:
		open(file_path + "-orb-sorted", 'w', encoding="utf-8", newline="\n").write(out)
		save_msg = f"changes saved in {file_path}-orb-sorted"
else:
	save_msg = "no changes were required"

fixed_lines = sorted(set(fixed_lines))


def row(label, value, color):
	return f"  {color}{label:<18}{BOLD}{value:>6}{RST}"


print()
print(f"  {BOLD}SRP Index  {GRAY}{file_path}{RST}")
print(f"  {GRAY}{'─' * 26}{RST}")
print(row("Lines read",  total_lines,        CYAN))
print(row("Written",     len(logos),         GREEN))
if empty_skipped:        print(row("Empty removed",  empty_skipped,        RED))
if duplicates_removed:   print(row("Duplicates removed", duplicates_removed, RED))
if fixed_lines:           print(row("Fixed",          len(fixed_lines),    YELLOW))
if errors:                print(row("Errors",         errors,              RED))
print()
print(f"  {save_msg}")

if fixed_lines:
	line_list = ", ".join(str(n) for n in fixed_lines)
	print(f"  Fixed line(s): {line_list}")

if error_lines:
	line_list = ", ".join(str(n) for n in error_lines)
	print(f"  {RED}Error line(s): {line_list}{RST}")

print()

if not saved and not errors:
	print(f"  {GREEN}{BOLD}✓{RST}  File is clean, no changes needed.")
elif saved and not errors:
	print(f"  {GREEN}{BOLD}✓{RST}  Changes applied and saved.")
elif saved and errors:
	print(f"  {GREEN}{BOLD}✓{RST}  Changes applied and saved.")
	print(f"  {RED}{BOLD}✗{RST}  {errors} error(s) were logged but not fixed — review manually.")
elif errors:
	print(f"  {RED}{BOLD}✗{RST}  {errors} error(s) were logged but not fixed — review manually.")
print()

if errors:
	sys.exit(1)
