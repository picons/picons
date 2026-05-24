FILE_NAME = "build-source/srp.index"

# log levels
INFO  = "info"
WARN  = "warn"
ERROR = "error"

_log: list[tuple[str, str]] = []

def log(level: str, msg: str) -> None:
    _log.append((level, msg))

ILLEGAL_CHARS = set('<>:"/\\|?*')

def validate_underscores(value: str) -> bool:
    """Check that value contains exactly 3 underscores and none are adjacent."""
    if value.count("_") != 3:
        return False
    if "__" in value:
        return False
    if value.startswith("_") or value.endswith("_"):
        return False
    return True

def validate_line(i: int, line: str) -> tuple[bool, str, str, list[str]]:
    """
    Validate a single line. Returns (is_valid, left, right, parts).
    Prints a descriptive error message on failure.
    """
    found = [c for c in line if c in ILLEGAL_CHARS]
    if found:
        chars = ", ".join(repr(c) for c in sorted(set(found)))
        cleaned = "".join(c for c in line if c not in ILLEGAL_CHARS)
        log(WARN, f"Line {i}: illegal chars {chars} removed  {line!r} -> {cleaned!r}")
        line = cleaned

    if " " in line or "\t" in line:
        cleaned = line.replace(" ", "").replace("\t", "")
        log(WARN, f"Line {i}: spaces removed  {line!r} -> {cleaned!r}")
        line = cleaned

    if "=" not in line:
        log(ERROR, f"Line {i}: missing '=' — skipped")
        return False, "", "", []

    left, right = line.split("=", 1)

    if left != left.upper():
        log(INFO, f"Line {i}: left side uppercased  {left!r} -> {left.upper()!r}")
        left = left.upper()

    if right != right.lower():
        log(INFO, f"Line {i}: right side lowercased  {right!r} -> {right.lower()!r}")
        right = right.lower()

    line = f"{left}={right}"

    if not validate_underscores(left):
        log(ERROR, f"Line {i}: bad underscores in {left!r} — skipped")
        return False, "", "", []

    parts = left.split("_")
    if len(parts) != 4:
        log(ERROR, f"Line {i}: wrong part count in {left!r} — skipped")
        return False, "", "", []

    for part in parts:
        try:
            int(part, 16)
        except ValueError:
            log(ERROR, f"Line {i}: non-hex value in {left!r} — skipped")
            return False, "", "", []

    return True, left, right, parts


def flush_log() -> None:
    CYAN   = "\033[96m"
    GREEN  = "\033[92m"
    YELLOW = "\033[93m"
    RED    = "\033[91m"
    GRAY   = "\033[90m"
    BOLD   = "\033[1m"
    RST    = "\033[0m"
    grouped: list[tuple[str,str]] = []
    i = 0
    while i < len(_log):
        level, msg = _log[i]
        if msg.startswith("empty:"):
            start = int(msg.split(":")[1])
            end   = start
            while i + 1 < len(_log) and _log[i+1][1].startswith("empty:"):
                i += 1
                end = int(_log[i][1].split(":")[1])
            if start == end:
                grouped.append((INFO, f"Skipped empty line {start}"))
            else:
                grouped.append((INFO, f"Skipped empty lines {start}-{end} ({end-start+1} lines)"))
        else:
            grouped.append((level, msg))
        i += 1
    color_map = {INFO: GRAY, WARN: YELLOW, ERROR: RED}
    label_map = {INFO: "info ", WARN: "warn ", ERROR: "ERROR"}
    for level, msg in grouped:
        c = color_map.get(level, GRAY)
        l = label_map.get(level, "     ")
        print(f"  {c}{l}{RST}  {msg}")
    if grouped:
        print()


def main():
    import os
    os.system("cls" if os.name == "nt" else "clear")

    try:
        with open(FILE_NAME, "r") as f:
            lines = f.readlines()
    except FileNotFoundError:
        log(ERROR, f"File not found: {FILE_NAME!r}")
        for _, msg in _log: print(f"  ERROR  {msg}")
        return
    except OSError as e:
        log(ERROR, f"Read error: {e}")
        for _, msg in _log: print(f"  ERROR  {msg}")
        return

    sort_list = []
    seen      = {}   # line -> first line number seen
    skipped   = 0
    fatal     = 0

    for i, raw_line in enumerate(lines, start=1):
        line = raw_line.strip()

        if not line:
            log(INFO, f"empty:{i}")
            skipped += 1
            continue

        is_valid, left, right, parts = validate_line(i, line)
        if not is_valid:
            skipped += 1
            fatal  += 1
            continue

        normalized = f"{left}={right}"

        if left in seen:
            log(WARN, f"Line {i}: duplicate key {left!r} (first seen at line {seen[left]}) — skipped")
            skipped += 1
            continue

        seen[left] = i
        sort_key = (int(parts[3], 16), int(parts[2], 16), int(parts[1], 16), int(parts[0], 16))
        sort_list.append((sort_key, normalized))

    original_order = [line for _, line in sort_list]
    sort_list.sort(key=lambda item: item[0])
    sorted_order = [line for _, line in sort_list]

    # Build rank maps: position of each line in each ordering
    orig_rank = {line: i for i, line in enumerate(original_order)}
    sort_rank = {line: i for i, line in enumerate(sorted_order)}

    # A line truly moved only if its rank relative to its neighbours changed.
    # We detect this by comparing the sort order of consecutive pairs:
    # if line A came before line B in original but after in sorted, at least
    # one of them moved. We collect lines that are out of the original sequence.
    moved_lines = []
    for i in range(1, len(sorted_order)):
        prev = sorted_order[i - 1]
        curr = sorted_order[i]
        if orig_rank[prev] > orig_rank[curr]:
            # curr was before prev originally — curr is out of place
            if curr not in moved_lines:
                moved_lines.append(curr)

    for line in moved_lines:
        o = orig_rank[line] + 1
        s = sort_rank[line] + 1
        log(WARN, f"Line moved: {line!r} ({o} -> {s})")

    moved = len(moved_lines)

    output_lines = [line + "\n" for line in sorted_order]

    if fatal > 0:
        flush_log()
        print(f"  \033[91m\033[1mAborted:\033[0m {fatal} uncorrectable error(s) — file not saved.\n")
        return

    try:
        with open(FILE_NAME, "w") as f:
            f.writelines(output_lines)
    except OSError as e:
        log(ERROR, f"Write error: {e}")
        return

    total   = len(lines)
    written = len(sort_list)

    flush_log()

    CYAN   = "\033[96m"
    GREEN  = "\033[92m"
    YELLOW = "\033[93m"
    RED    = "\033[91m"
    GRAY   = "\033[90m"
    BOLD   = "\033[1m"
    RST    = "\033[0m"

    def row(label, value, color):
        return f"  {color}{label:<18}{BOLD}{value:>6}{RST}"

    print()
    print(f"  {BOLD}SRP Index  {GRAY}{FILE_NAME}{RST}")
    print(f"  {GRAY}{'─' * 26}{RST}")
    print(row("Lines read",  total,   CYAN))
    print(row("Written",     written, GREEN))
    print(row("Skipped",     skipped, RED    if skipped else GRAY))
    print(row("Moved",       moved,   YELLOW if moved   else GRAY))
    print()


if __name__ == "__main__":
    main()
