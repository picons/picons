"""
deletefromsrp.py

Removes entries from an SRP index file based on a list of IDs to delete.

Input files:
  /tmp/linestodelete.txt  - one entry per line, e.g.:
                              13A8_7ED_2_11A0000   (ID match)
                              =123livehd           (logo/value match)
  /tmp/srp.index          - index file with lines in format ID=name
                            (or just ID with no =name)

To run, issue the following command.
python /tmp/deletefromsrp.py

Output:
  /tmp/new.srp.index      - copy of srp.index with matching lines removed

A line is deleted if:
  - its full content matches an entry in the delete list, OR
  - its ID (the part before '=') matches an entry in the delete list, OR
  - its logo/value (the part after '=') matches an entry in the delete list
    (entries in the delete list starting with '=' are treated as logo matches)
"""

to_delete_file = "/tmp/linestodelete.txt"
to_test_file = "/tmp/srp.index"
outfile = "/tmp/new.srp.index"

to_delete = set()

# Load the list of IDs/logos to remove
with open(to_delete_file) as f:
    for line in f:
        to_delete.add(line.strip())

# Copy index to output, skipping any lines that match the delete list
with open(to_test_file) as f, open(outfile, "w") as out:
    for line in f:
        stripped = line.strip()
        parts = stripped.split("=", 1)
        key = parts[0]                          # ID before '='
        logo = "=" + parts[1] if len(parts) > 1 else ""  # value after '=', prefixed with '='
        if stripped in to_delete or key in to_delete or logo in to_delete:
            print("deleting:", stripped)
        else:
            out.write(line)

print("done")
