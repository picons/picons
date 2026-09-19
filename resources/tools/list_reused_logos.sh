#!/bin/bash
#
# Lists logo files that are used by more than one channel-name
# entry in the utf8snp.index file (lines of the form
# "channelname=logo"). Useful to spot the logo files that are shared by
# many channel-name symlinks (regional splits, HD/SD duplicates,
# kabelio/movistar-style prefixes...).
#
# Terminology: the "logo" is the source logo file used on this repository.
# "utfsnp names/channel names" are a symlink pointing to a logo.
# Many channel names can legitimately point to the same logo,
# different name variants); this script only counts and lists that reuse,
# it does not judge it.
#
# Usage: ./list_reused_logos.sh [OPTIONS] [path/to/utf8snp.index]
#
# Options:
#   -m, --min N        Only show logos reused by at least N channel names
#                       (default: 10).
#   -n, --top N         Only show the top N most-reused logos.
#   -l, --list-names    Also print the channel names sharing each logo.
#   -h, --help          Show this help and exit.
#
# Index file lookup:
#   If no path is given, the script checks the current directory first
#   for utf8snp.index. If not found there, it goes two levels back from
#   the script's location (e.g. from picons/resources/tools back to
#   picons) and looks for utf8snp.index inside build-source/ there.
#
# Examples:
#   # Default view: grid of logos reused by >= 10 channel names
#   ./list_reused_logos.sh
#
#   # Only the 15 most-reused logos overall, sorted by reuse count
#   ./list_reused_logos.sh --top 15
#
#   # Quick outlier check: a logo reused by a LOT of channel names may be
#   # worth a look at the channel names behind it
#   ./list_reused_logos.sh --top 5 --list-names
#
#   # Looser threshold, to catch smaller clusters too (e.g. a 3-region
#   # local network sharing one logo)
#   ./list_reused_logos.sh --min 3
#
#   # Save a full report to file (grid layout still applies, sized to a
#   # wide terminal via COLUMNS)
#   COLUMNS=200 ./list_reused_logos.sh --min 5 > report.txt
#
#   # Pipe into less for paging through a long, low-threshold list
#   ./list_reused_logos.sh --min 2 | less

set -euo pipefail

min_reuse=10
top_n=0
list_names=0
index_file=""

usage() {
    sed -n '2,46p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --min|-m)
                [[ -n ${2:-} && $2 =~ ^[0-9]+$ ]] || die "--min requires a numeric argument"
                min_reuse=$2
                shift
                ;;
            --top|-n)
                [[ -n ${2:-} && $2 =~ ^[0-9]+$ ]] || die "--top requires a numeric argument"
                top_n=$2
                shift
                ;;
            --list-names|-l) list_names=1 ;;
            --help|-h) usage; exit 0 ;;
            --) shift; [[ -n ${1:-} ]] && index_file=$1; break ;;
            -*) die "unknown option: $1 (see --help)" ;;
            *) index_file=$1 ;;
        esac
        shift
    done
}

# Resolves index_file: uses the explicit path if given, otherwise
# Firtsly checks the current directory for utf8snp.index. If not found
# there, it goes two levels back from the script's location (e.g. from
# picons/resources/tools back to picons) and looks for
# utf8snp.index inside build-source/ folder.
resolve_index() {
    if [[ -n $index_file ]]; then
        return 0
    fi

    local self script_dir repo_root

    self=${BASH_SOURCE[0]}
    if command -v readlink &>/dev/null; then
        self=$(readlink -f -- "$self" 2>/dev/null || echo "$self")
    fi
    script_dir=$(cd -- "$(dirname -- "$self")" &>/dev/null && pwd)
    repo_root=$(cd -- "$script_dir/../.." &>/dev/null && pwd)

    if [[ -f "$PWD/utf8snp.index" ]]; then
        index_file="$PWD/utf8snp.index"
    elif [[ -f "$repo_root/build-source/utf8snp.index" ]]; then
        index_file="$repo_root/build-source/utf8snp.index"
    else
        index_file="$repo_root/build-source/utf8snp.index"
    fi
}

validate_index() {
    [[ -f $index_file ]] || die "index file not found: $index_file
Run this script from the resources/tools folder, or from the folder containing utf8snp.index, or pass the path as an argument."
    [[ -s $index_file ]] || die "index file is empty: $index_file"
}

# Prints "count<TAB>logo<TAB>channel_name1, channel_name2, ..." for every
# logo file reused by at least $min_reuse channel names, sorted by
# count descending.
build_reuse_table() {
    awk -F'=' -v min="$min_reuse" '
        NF < 2 { next }
        {
            logo = $NF
            $NF = ""
            sub(/=$/, "", $0)
            channel_name = $0
            count[logo]++
            names[logo] = (names[logo] == "" ? channel_name : names[logo] ", " channel_name)
        }
        END {
            for (p in count) {
                if (count[p] >= min) {
                    print count[p] "\t" p "\t" names[p]
                }
            }
        }
    ' "$index_file" | sort -t $'\t' -rn -k1,1
}

print_table() {
    local count logo names shown=0
    local -a cells=()

    while IFS=$'\t' read -r count logo names; do
        (( top_n > 0 && shown >= top_n )) && break
        if [[ $list_names -eq 1 ]]; then
            printf '%d  %s\n' "$count" "$logo"
            printf -- '%s\n' "$names"
        else
            cells+=("$(printf '%d  %s' "$count" "$logo")")
        fi
        shown=$(( shown + 1 ))
    done < <(build_reuse_table)

    [[ $list_names -eq 1 || ${#cells[@]} -eq 0 ]] && return 0
    print_grid cells
    return 0
}

# Lays out the given array (by name) in as many columns as fit the
# terminal width, padded to the widest cell.
print_grid() {
    local -n items=$1
    local term_width cell_width columns i row_start

    term_width=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
    cell_width=0
    for i in "${items[@]}"; do (( ${#i} > cell_width )) && cell_width=${#i}; done
    cell_width=$(( cell_width + 3 ))
    columns=$(( term_width / cell_width ))
    (( columns < 1 )) && columns=1

    for (( i=0; i<${#items[@]}; i++ )); do
        printf '%s' "${items[$i]}"
        printf '%*s' "$((cell_width - ${#items[$i]}))" ''
        (( (i + 1) % columns == 0 )) && echo
    done
    (( ${#items[@]} % columns != 0 )) && echo
    return 0
}

clear_screen() {
    # Never emit terminal control sequences when stdout is redirected
    # (e.g. ./list_reused_logos.sh --min 5 > report.txt).
    if [[ -t 1 ]]; then
        clear
    fi
    return 0
}

main() {
    parse_args "$@"
    resolve_index
    validate_index
    clear_screen
    print_table | sed -E 's/^[[:space:]]+//'
}

main "$@"
