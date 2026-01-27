from os.path import dirname, isfile, realpath, sep, splitext
import re
import urllib.request


# cleans and sorts srp.index


def rsort(listItem):
	# sort by namespace (orb pos), then ONID, then TSID, then SID
	return (int((x := listItem.split("_"))[3], 16), int(x[2], 16), int(x[1], 16), int(x[0], 16))


dir_path = dirname(realpath(__file__))

filename = "srp.index"

file_path = f"{dir_path}{sep}..{sep}..{sep}build-source{sep}{filename}"  # repo path

if not isfile(file_path):  # tool not running from the repo, test /tmp
	file_path = f"{sep}tmp{sep}{filename}"

if not isfile(file_path):  # fetch to local from repo if necessary
	open(file_path, "w").write(urllib.request.urlopen(f"https://raw.githubusercontent.com/picons/picons/master/build-source/{filename}").read().decode())


logos = {}

for i, line in enumerate((orig := open(file_path, 'r', encoding="utf-8").read()).splitlines()):
	rsp = line.rstrip().rsplit("=", 1)
	if not len(rsp) == 2:
		print(f"error on line {i}, {line}")
		continue
	ref, logo = rsp
	if ref != ref.upper():
		ref = ref.upper()
		print(f"line {i}, sref contains lower case")
	if ref in logos:
		print(f"line {i}, skip duplicate entries for {ref}, {logos[ref]} and {logo}")
		continue
	logos[ref] = logo

out = "".join([k + "=" + logos[k] + "\n" for k in sorted(logos.keys(), key=lambda listItem: rsort(listItem))])
if out != orig:
	open(file_path + "-orb-sorted", 'w', encoding="utf-8").write(out)
	print(f"changes saved in {file_path}-orb-sorted")
else:
	print("no changes were required")
