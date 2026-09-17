#!/bin/bash
#
# Lists picon names that are reused by more than one channel-name entry in
# a utf8snp-style index file (lines of the form "channelname=picon").
# Useful to spot the picon "hubs": the ones that absorb many name variants
# (regional splits, HD/SD duplicates, kabelio/movistar-style prefixes...).
#
# Usage: ./list_reused_picons.sh [OPTIONS] [path/to/utf8snp.index]
#
# Options:
#   -m, --min N        Only show picons reused by at least N channel names
#                       (default: 10).
#   -n, --top N         Only show the top N most-reused picons.
#   -l, --list-names    Also print the channel names sharing each picon.
#   -h, --help          Show this help and exit.
#
# Examples:
#   # Default view: grid of picons reused by >= 10 channel names
#   ./list_reused_picons.sh utf8snp.index
#
#   # Only the 15 most-reused picons overall, sorted by reuse count
#   ./list_reused_picons.sh --top 15 utf8snp.index
#
#   # Quick outlier check: picons reused by a LOT of names may signal a
#   # too-generic simplified name (e.g. "itv1" absorbing every regional
#   # ITV feed); inspect the channel names behind the top offenders
#   ./list_reused_picons.sh --top 5 --list-names utf8snp.index
#
#   # Looser threshold, to catch smaller clusters too (e.g. a 3-region
#   # local network sharing one picon)
#   ./list_reused_picons.sh --min 3 utf8snp.index
#
#   # Save a full report to file (grid layout still applies, sized to a
#   # wide terminal via COLUMNS)
#   COLUMNS=200 ./list_reused_picons.sh --min 5 utf8snp.index > report.txt
#
#   # Pipe into less for paging through a long, low-threshold list
#   ./list_reused_picons.sh --min 2 utf8snp.index | less

set -euo pipefail

min_reuse=10
top_n=0
list_names=0
index_file=""

usage() {
    sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'
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
    index_file=${index_file:-build-source/utf8snp.index}
}

validate_index() {
    [[ -f $index_file ]] || die "index file not found: $index_file
Run this from the picons folder (containing build-source/utf8snp.index), or pass the path as an argument."
    [[ -s $index_file ]] || die "index file is empty: $index_file"
}

# Prints "count<TAB>picon<TAB>name1, name2, ..." for every picon reused by
# at least $min_reuse channel names, sorted by count descending.
build_reuse_table() {
    awk -F'=' -v min="$min_reuse" '
        NF < 2 { next }
        {
            picon = $NF
            $NF = ""
            sub(/=$/, "", $0)
            name = $0
            count[picon]++
            names[picon] = (names[picon] == "" ? name : names[picon] ", " name)
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
    local count picon names shown=0
    local -a cells=()

    while IFS=$'\t' read -r count picon names; do
        (( top_n > 0 && shown >= top_n )) && break
        if [[ $list_names -eq 1 ]]; then
            printf '%d  %s\n' "$count" "$picon"
            printf -- '%s\n' "$names"
        else
            cells+=("$(printf '%d  %s' "$count" "$picon")")
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
    # (e.g. ./list_reused_picons.sh --min 5 utf8snp.index > report.txt).
    if [[ -t 1 ]]; then
        clear
    fi
    return 0
}

main() {
    parse_args "$@"
    validate_index
    clear_screen
    print_table | sed -E 's/^[[:space:]]+//'
}

main "$@"
