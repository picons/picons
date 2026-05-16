"""
deletefromsrp.py

Removes entries from an SRP index file based on a list of IDs to delete.

Input files:
  /tmp/linestodelete.txt  - one ID per line (e.g. 13A8_7ED_2_11A0000)
  /tmp/srp.index          - index file with lines in format ID=name
                            (or just ID with no =name)

To run, issue the following command.
python /tmp/deletefromsrp.py

Output:
  /tmp/new.srp.index      - copy of srp.index with matching lines removed

A line is deleted if:
  - its full content matches an entry in the delete list, OR
  - its ID (the part before '=') matches an entry in the delete list
"""

to_delete_file = "/tmp/linestodelete.txt"
to_test_file = "/tmp/srp.index"
outfile = "/tmp/new.srp.index"

to_delete = set()

# Load the list of IDs to remove
with open(to_delete_file) as f:
    for line in f:
        to_delete.add(line.strip())

# Copy index to output, skipping any lines that match the delete list
with open(to_test_file) as f, open(outfile, "w") as out:
    for line in f:
        stripped = line.strip()
        key = stripped.split("=")[0]  # extract ID before the '='
        if stripped in to_delete or key in to_delete:
            print("deleting:", stripped)
        else:
            out.write(line)

print("done")f.close()
       
out.close()

print ("done")
