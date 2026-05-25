FILE_NAME = "build-source/utf8snp.index"

# log levels
INFO  = "info"
WARN  = "warn"
ERROR = "error"

_log: list[tuple[str, str]] = []

def log(level: str, msg: str) -> None:
    _log.append((level, msg))


def is_srp_key(value: str) -> bool:
    """Return True if value matches the SRP format: exactly 4 hex parts separated by underscores."""
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
        try:
            int(part, 16)
        except ValueError:
            return False
    return True


def validate_line(i: int, line: str) -> tuple[bool, str, str]:
    """
    Validate a single line. Returns (is_valid, left, right).
    - Missing '=' is a fatal structural error: line is skipped.
    - Invalid chars on right side are logged as ERROR but line is kept.
    - Left side is kept exactly as-is.
    - Right side is lowercased automatically.
    """
    import re

    if "=" not in line:
        log(ERROR, f"Line {i}: missing '=' — removed")
        return False, "", ""

    left, right = line.split("=", 1)

    if right != right.lower():
        log(INFO, f"Line {i}: right side lowercased  {right!r} -> {right.lower()!r}")
        right = right.lower()

    # whitelist check: log ERROR but still include the line
    invalid = sorted(set(c for c in right if not re.match(r'[a-z0-9_-]', c)))
    if invalid:
        chars = ", ".join(repr(c) for c in invalid)
        log(ERROR, f"Line {i}: invalid character(s) {chars} in right side {right!r}")

    return True, left, right


def flush_log() -> None:
    CYAN   = "\033[96m"
    GREEN  = "\033[92m"
    YELLOW = "\033[93m"
    RED    = "\033[91m"
    GRAY   = "\033[90m"
    BOLD   = "\033[1m"
    RST    = "\033[0m"

    grouped: list[tuple[str, str]] = []
    i = 0
    while i < len(_log):
        level, msg = _log[i]
        if msg.startswith("empty:"):
            start = int(msg.split(":")[1])
            end   = start
            while i + 1 < len(_log) and _log[i + 1][1].startswith("empty:"):
                i += 1
                end = int(_log[i][1].split(":")[1])
            if start == end:
                grouped.append((INFO, f"Removed empty line {start}"))
            else:
                grouped.append((INFO, f"Removed empty lines {start}-{end} ({end - start + 1} lines)"))
        else:
            grouped.append((level, msg))
        i += 1

    color_map = {INFO: GRAY, WARN: YELLOW, ERROR: RED}
    label_map = {INFO: "info ", WARN: "warn ", ERROR: "ERROR"}

    non_errors = [(lv, msg) for lv, msg in grouped if lv != ERROR]
    errors     = [(lv, msg) for lv, msg in grouped if lv == ERROR]
    for level, msg in non_errors + errors:
        c = color_map.get(level, GRAY)
        l = label_map.get(level, "     ")
        print(f"  {c}{l}{RST}  {msg}")
    if grouped:
        print()


def main():
    import os, sys
    sys.stdout.reconfigure(encoding="utf-8", errors="strict")
    os.system("cls" if os.name == "nt" else "clear")

    fatal_encoding = False

    try:
        with open(FILE_NAME, "rb") as f:
            raw_bytes = f.read()
        lines = []
        for lineno, raw_line in enumerate(raw_bytes.splitlines(keepends=True), start=1):
            try:
                lines.append(raw_line.decode("utf-8"))
            except UnicodeDecodeError as e:
                preview = raw_line.replace(b"\n", b"").replace(b"\r", b"")[:60]
                log(ERROR, f"Line {lineno}: invalid UTF-8 byte 0x{raw_line[e.start]:02X} at position {e.start} -> {preview!r} — skipped")
                fatal_encoding = True
    except FileNotFoundError:
        log(ERROR, f"File not found: {FILE_NAME!r}")
        for _, msg in _log: print(f"  ERROR  {msg}")
        return
    except OSError as e:
        log(ERROR, f"Read error: {e}")
        for _, msg in _log: print(f"  ERROR  {msg}")
        return

    sort_list = []
    seen    = {}   # left (alias) -> first line number seen
    skipped = 0
    fatal   = 0

    for i, raw_line in enumerate(lines, start=1):
        line = raw_line.strip()

        if not line:
            log(INFO, f"empty:{i}")
            skipped += 1
            continue

        is_valid, left, right = validate_line(i, line)
        if not is_valid:
            skipped += 1
            fatal += 1
            continue

        normalized = f"{left}={right}"

        if left in seen:
            log(WARN, f"Line {i}: duplicate alias {left!r} (first seen at line {seen[left]}) — removed")
            skipped += 1
            continue

        seen[left] = i
        # Sort key: always group by right (channel id) first.
        # Within the same right, if left matches SRP format use numeric hex sort;
        # otherwise sort alphabetically by left.
        if is_srp_key(left):
            parts = left.split("_")
            sort_key = (right, 0, int(parts[3], 16), int(parts[2], 16), int(parts[1], 16), int(parts[0], 16), "")
        else:
            sort_key = (right, 1, 0, 0, 0, 0, left)
        sort_list.append((sort_key, normalized))

    sort_list.sort(key=lambda item: item[0])
    sorted_order = [line for _, line in sort_list]

    output_lines = [line + "\n" for line in sorted_order]

    if fatal_encoding:
        flush_log()
        print(f"  \033[91m\033[1mAborted:\033[0m invalid UTF-8 — file not saved.\n")
        return

    try:
        with open(FILE_NAME, "w", encoding="utf-8", newline="\n") as f:
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

    errors = sum(1 for lv, _ in _log if lv == ERROR)

    def row(label, value, color):
        return f"  {color}{label:<18}{BOLD}{value:>6}{RST}"

    print()
    print(f"  {BOLD}UTF8SNP Index  {GRAY}{FILE_NAME}{RST}")
    print(f"  {GRAY}{'─' * 30}{RST}")
    print(row("Lines read",  total,   CYAN))
    print(row("Written",     written, GREEN))
    if skipped: print(row("Removed", skipped, RED))
    if errors:  print(row("Errors",  errors,  RED))
    print()

    warnings = sum(1 for lv, _ in _log if lv in (INFO, WARN))
    if not warnings and not errors:
        print(f"  {GREEN}{BOLD}✓{RST}  File is clean, no corrections needed.")
    elif warnings and not errors:
        print(f"  {GREEN}{BOLD}✓{RST}  All corrections applied and saved.")
    elif warnings and errors:
        print(f"  {GREEN}{BOLD}✓{RST}  Corrections (info/warn) applied and saved.")
        print(f"  {RED}{BOLD}✗{RST}  {errors} error(s) were logged but not fixed — review manually.")
    elif errors:
        print(f"  {RED}{BOLD}✗{RST}  {errors} error(s) were logged but not fixed — review manually.")
    print()


if __name__ == "__main__":
    main()
