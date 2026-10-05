"""
deletefromsrp.py

Removes entries from srp.index based on a list of IDs / logos to delete.

Works in two places:

  1. On your PC, inside the picons repo
     srp.index          : <repo>/build-source/srp.index
     linestodelete.txt  : same folder as srp.index
     Result             : srp.index is replaced in place (check with git diff)

  2. On the receiver (script not inside the repo)
     srp.index          : /tmp/srp.index
     linestodelete.txt  : /tmp/linestodelete.txt
     Result             : /tmp/new.srp.index  (srp.index is left untouched)
     Run with: python /tmp/deletefromsrp.py

linestodelete.txt, one entry per line, e.g.:
    13A8_7ED_2_11A0000      (ID match)
    =123livehd              (logo match)
    13A8_7ED_2_11A0000=abc  (whole line match)

A line is deleted if its whole content, its ID (before '='), or its logo
(after '=') matches an entry. Matching ignores upper/lower case.
"""

from os.path import dirname, isfile, realpath, sep
import sys

if sys.stdout.encoding != "utf-8":
	sys.stdout.reconfigure(encoding="utf-8", errors="replace")

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


def normalise(text):
	"""IDs are compared in upper case, logos in lower case."""
	if "=" in text:
		ref, logo = text.split("=", 1)
		return ref.upper() + "=" + logo.lower()
	return text.upper()


# --- find the files ---------------------------------------------------------

dir_path = dirname(realpath(__file__))
filename = "srp.index"
file_path = f"{dir_path}{sep}..{sep}..{sep}build-source{sep}{filename}"

in_repo = isfile(file_path)

if not in_repo:  # not running from the repo, use /tmp (receiver)
	file_path = f"{sep}tmp{sep}{filename}"

work_dir = dirname(file_path)
delete_path = f"{work_dir}{sep}linestodelete.txt"
out_path = file_path if in_repo else f"{work_dir}{sep}new.{filename}"

for path in (file_path, delete_path):
	if not isfile(path):
		error(f"File not found: {path!r}")
		sys.exit(1)

# --- load the delete list ---------------------------------------------------

targets = {}  # normalised entry -> original text (for reporting)
with open(delete_path, encoding="utf-8") as f:
	for line in f:
		entry = line.strip()
		if entry:
			targets[normalise(entry)] = entry

if not targets:
	warn("linestodelete.txt is empty, nothing to do")
	sys.exit(0)

# --- go through srp.index ---------------------------------------------------

kept = []
deleted = []
used = set()
total_lines = 0

with open(file_path, encoding="utf-8") as f:
	for line in f:
		total_lines += 1
		stripped = line.strip()
		if not stripped:
			kept.append(line)
			continue

		whole = normalise(stripped)
		parts = stripped.split("=", 1)
		key = parts[0].upper()  # ID before '='
		logo = "=" + parts[1].lower() if len(parts) > 1 else ""  # '=' + logo

		hit = next((c for c in (whole, key, logo) if c and c in targets), None)
		if hit:
			used.add(hit)
			deleted.append(stripped)
			print(f"  {RED}deleting:{RST} {stripped}")
		else:
			kept.append(line)

# --- save -------------------------------------------------------------------

if deleted or not in_repo:
	with open(out_path, "w", encoding="utf-8", newline="\n") as out:
		out.writelines(kept)
	save_msg = f"saved in {out_path}"
else:
	save_msg = "no changes were required"

not_found = [targets[t] for t in targets if t not in used]

print()
print(f"  {BOLD}SRP Delete  {GRAY}{file_path}{RST}")
print(f"  {GRAY}{'─' * 26}{RST}")
print(f"  {CYAN}{'Lines read':<18}{BOLD}{total_lines:>6}{RST}")
print(f"  {RED}{'Deleted':<18}{BOLD}{len(deleted):>6}{RST}")
print()
print(f"  {save_msg}")

if not_found:
	print()
	warn(f"{len(not_found)} entry(ies) in linestodelete.txt matched nothing (typo?):")
	for entry in not_found:
		print(f"        {entry}")

print()
