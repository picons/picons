import unicodedata
from os.path import dirname, isfile, realpath, sep, splitext
import re
import sys
import urllib.request

# Workaround for when run on Windows.
if sys.stdout.encoding != "utf-8":
	sys.stdout.reconfigure(encoding='utf-8')
# End workaround

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


dir_path = dirname(realpath(__file__))
filename = "utf8snp.index"
file_path = f"{dir_path}{sep}..{sep}..{sep}build-source{sep}{filename}"

in_repo = isfile(file_path)

if not in_repo:  # tool not running from the repo, test /tmp
	file_path = f"{sep}tmp{sep}{filename}"

if not isfile(file_path):  # fetch to local from repo if necessary
	open(file_path, "w").write(urllib.request.urlopen(f"https://raw.githubusercontent.com/picons/picons/master/build-source/{filename}").read().decode())

SRP_RE = re.compile(r"^[0-9A-F]+_[0-9A-F]+_[0-9A-F]+_[0-9A-F]{6,}$", re.IGNORECASE)


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


def _is_hex(s):
	return len(s) > 0 and all(c in "0123456789abcdefABCDEF" for c in s)


def looks_like_srp_attempt(value):
	"""True if value looks like a botched SRP-style channel identifier (e.g. 1_282_1_64),
	as opposed to an ordinary channel name that happens to contain
	underscores (e.g. AL_JAZEERA_HD)."""
	if value.count("_") not in (2, 3, 4):
		return False
	non_empty = [p for p in value.split("_") if p]
	if len(non_empty) < 3:
		return False
	hex_count = sum(1 for p in non_empty if _is_hex(p))
	return hex_count >= len(non_empty) - 1


def lsort(listItem):
	# sort by logo, then servicename
	# if servicename is sref, sort by logo, then namespace, ONID, TSID, SID
	sname, logo = listItem.rsplit("=", 1)
	if SRP_RE.match(sname):
		x = sname.split("_")
		return (logo, 0, int(x[3], 16), int(x[2], 16), int(x[1], 16), int(x[0], 16))
	return (logo, 1, sname)


snames = {}
sname_lines = {}  # track which line each sname was first seen on
errors = 0
missing_eq = 0
invalid_srp = 0
invalid_logo = 0
fatal_encoding = False
fixed_lines = []     # line numbers where an auto-correction (case/sanitize) was applied
error_lines = []      # line numbers where an error was logged (kept, not aborted)
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
# pinpoint exactly which line/byte is bad instead of crashing with a
# raw traceback on the first invalid byte anywhere in the file.
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
	print(f"  {RED}{BOLD}Aborted:{RST} file contains corrupted/unreadable text -- file not modified. Fix the utf8snp.index file and re-run.\n")
	sys.exit(1)

orig = "".join(decoded_lines)
total_lines = len(decoded_lines)

for i, line in enumerate(orig.splitlines(), start=1):
	stripped = line.strip()
	if not stripped:
		empty_skipped += 1
		continue

	rsp = line.rstrip().rsplit("=", 1)
	if not len(rsp) == 2:
		error(f"Line {i}: missing '=' sign: {line!r}")
		missing_eq += 1
		continue
	name, logo = rsp

	# Channel identifiers that look like a botched SRP-style entry (wrong hex,
	# bad underscores, wrong part count) must be fixed by the submitter,
	# not silently dropped -- so this aborts the whole save.
	if not SRP_RE.match(name) and looks_like_srp_attempt(name):
		error(f"Line {i}: {name!r} looks like an SRP-style channel identifier but is invalid (bad underscores, wrong part count, or non-hex value)")
		invalid_srp += 1
		continue

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

	if SRP_RE.match(name):
		sname = name.upper()
	else:
		sname = name and (x := sanitizeFilename(name)) and x.lower()

	if sname in snames:
		warn(f"Line {i}: duplicate channel identifier {sname!r} (first seen at line {sname_lines[sname]}) — removed")
		duplicates_removed += 1
		continue

	if sname and sname != "__":
		snames[sname] = logo
		sname_lines[sname] = i
		if sname != name:
			info(f"Line {i}: channel identifier sanitized  {name!r} -> {sname!r}")
			fixed_lines.append(i)
	else:
		error(f"Line {i}: {line!r} -- channel identifier is empty/invalid after sanitizing, removed")
		errors += 1
		error_lines.append(i)

if missing_eq or invalid_srp or invalid_logo:
	print()
	if missing_eq:
		print(f"  {RED}{BOLD}Aborted:{RST} {missing_eq} line(s) missing '=' sign -- file not modified. Fix the utf8snp.index file and re-run.")
	if invalid_srp:
		print(f"  {RED}{BOLD}Aborted:{RST} {invalid_srp} invalid SRP-style entry(ies) found -- file not modified. Fix the utf8snp.index file and re-run.")
	if invalid_logo:
		print(f"  {RED}{BOLD}Aborted:{RST} {invalid_logo} invalid logo name(s) found -- file not modified. Fix the utf8snp.index file and re-run.")
	print()
	sys.exit(1)

out = "".join(sorted([k + "=" + v + "\n" for k, v in snames.items()], key=lambda listItem: lsort(listItem)))
saved = out != orig
if saved:
	if in_repo:
		open(file_path, 'w', encoding="utf-8", newline="\n").write(out)
		save_msg = f"changes saved in {file_path}"
	else:
		open(file_path + ".cleaned", 'w', encoding="utf-8", newline="\n").write(out)
		save_msg = f"changes saved in {file_path}.cleaned"
else:
	save_msg = "no changes were required"

fixed_lines = sorted(set(fixed_lines))


def row(label, value, color):
	return f"  {color}{label:<18}{BOLD}{value:>6}{RST}"


print()
print(f"  {BOLD}UTF8SNP Index  {GRAY}{file_path}{RST}")
print(f"  {GRAY}{'─' * 30}{RST}")
print(row("Lines read",  total_lines,        CYAN))
print(row("Written",     len(snames),        GREEN))
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
