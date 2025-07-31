fileName = "build-source/srp.index"

sort_list = []
output = []

lines = open(fileName, "r").readlines()

for i, line in enumerate(lines):
    try:
        ref = line.split("=")[0].split("_")
    except Exception:
        print("Error in line:", line)
        continue

    sort_list.append((i, (int(ref[3], 16), int(ref[2], 16), int(ref[1], 16), int(ref[0], 16))))

sort_list = sorted(sort_list, key=lambda listItem: listItem[1])

for item in sort_list:
    output.append(lines[item[0]])

with open(fileName, "w") as f:
    f.write(''.join(output))
