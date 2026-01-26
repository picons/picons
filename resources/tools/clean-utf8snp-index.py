import unicodedata
from os.path import dirname, isfile, realpath, sep, splitext
import re
import urllib.request


# cleans and sorts utf8snp.index


# Workaround for when run on Windows.
# The interpreter thinks, for some reason that we'll probably never know, that
# sys.stdout is feeding to a terminal emulator that doesn't handle Unicode, only
# CP1257, and therefore print (actually sys.stdout.write) must convert from
# Unicode to CP1257 before printing, and any character not in the CP1257
# repertoire can't be printed at all, so throws an exception.
import sys
if sys.stdout.encoding != "utf-8":
	sys.stdout.reconfigure(encoding='utf-8')
# End workaround


dir_path = dirname(realpath(__file__))

filename = "utf8snp.index"

file_path = f"{dir_path}{sep}..{sep}..{sep}build-source{sep}{filename}"  # repo path

if not isfile(file_path):  # tool not running from the repo, test /tmp
	file_path = f"{sep}tmp{sep}{filename}"

if not isfile(file_path):  # fetch to local from repo if necessary
	open(file_path, "w").write(urllib.request.urlopen(f"https://raw.githubusercontent.com/picons/picons/master/build-source/{filename}").read().decode())


snames = {}


def sanitizeFilename(filename, maxlen=255):  # 255 is max length in ext4 (and most other file systems)
	"""
	This function is a copy of enigma2 Directories.sanitizeFilename so we can be consistent with enigma2

	Return a fairly safe version of the filename.

	We don't limit ourselves to ascii, because we want to keep municipality
	names, etc, but we do want to get rid of anything potentially harmful,
	and make sure we do not exceed filename length limits.
	Hence a less safe blacklist, rather than a whitelist.
	"""
	blacklist = ["\\", "/", ":", "*", "?", "\"", "<", ">", "|", "\0"]
	reserved = [
		"CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5",
		"COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5",
		"LPT6", "LPT7", "LPT8", "LPT9",
	]  # Reserved words on Windows
	# Remove any blacklisted chars. Remove all charcters below code point 32. Normalize. Strip.
	filename = unicodedata.normalize("NFKD", "".join(c for c in filename if c not in blacklist and ord(c) > 31)).strip()
	if all([x == "." for x in filename]) or filename in reserved:  # if filename is a string of dots
		filename = "__" + filename
	# Most Unix file systems typically allow filenames of up to 255 bytes.
	# However, the actual number of characters allowed can vary due to the
	# representation of Unicode characters. Therefore length checks must
	# be done in bytes, not unicode.
	#
	# Also we cannot leave the byte truncate in the middle of a multi-byte
	# utf8 character! So, convert to bytes, truncate then get back to unicode,
	# ignoring errors along the way, the result will be valid unicode.
	# Prioritise maintaining the complete extension if possible.
	# Any truncation of root or ext will be done at the end of the string
	root, ext = splitext(filename.encode(encoding='utf-8', errors='ignore'))
	if len(ext) > maxlen - (1 if root else 0):  # leave at least one char for root if root
		ext = ext[:maxlen - (1 if root else 0)]
	# convert back to unicode, ignoring any incomplete utf8 multibyte chars
	filename = root[:maxlen - len(ext)].decode(encoding='utf-8', errors='ignore') + ext.decode(encoding='utf-8', errors='ignore')
	filename = filename.rstrip(". ")  # Windows does not allow these at end
	if len(filename) == 0:
		filename = "__"
	return filename

def lsort(listItem):
	# sort by logo, then servicename
	# if servicename is sref, sort by logo, then namespace, ONID, TSID, SID
	sname, logo = listItem.rsplit("=", 1)
	if re.match("^[0-9A-F]+[_][0-9A-F]+[_][0-9A-F]+[_][0-9A-F]+$", sname, re.IGNORECASE):
		return (logo, 1, int((x := sname.split("_"))[3], 16), int(x[2], 16), int(x[1], 16), int(x[0], 16))
	return (logo, 0, sname)


for i, line in enumerate((orig := open(file_path, 'r', encoding="utf-8").read()).splitlines()):
	rsp = line.rstrip().rsplit("=", 1)
	if not len(rsp) == 2:
		print(f"error on line {i}, {line}")
		continue
	name, logo = rsp
	
	if re.match("^[0-9A-F]+[_][0-9A-F]+[_][0-9A-F]+[_][0-9A-F]+$", name, re.IGNORECASE):
		sname = name.upper()
	else:
		sname = name and (x := sanitizeFilename(name)) and x.lower()
	if sname in snames:
		f"line {i}, skip duplicate entries for {sname}, {snames[sname]} and {logo}"
		print(f"line {i}, skip duplicate entries for {sname}, {snames[sname]} and {logo}")
		continue
	if sname and sname != "__":
		snames[sname] = logo
		if sname != name:
			print(f"line {str(i)}, changed {str(name)} to {str(sname)}")
	else:
		print(f"error on line {i}, {line}")

out = "".join(sorted([k + "=" + v + "\n" for k, v in snames.items()], key=lambda listItem: lsort(listItem)))
if out != orig:
	open(file_path + ".cleaned", 'w', encoding="utf-8").write(out)
	print(f"changes saved in {file_path}.cleaned")
else:
	print("no changes were required")
