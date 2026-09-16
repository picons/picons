#!/bin/bash
# Counts srp.index entries grouped by orbital position / cable / terrestrial
# provider, ordered and labelled the same way as 1-build-servicelist.sh's
# menu (Satellite by ascending position, Cable/Terrestrial by onid - named
# providers first, Unclassified by hex value, then Common Positions/
# Providers). Pass --by-count to sort each section by entry count instead.
# Usage: ./count-srpindex-entries.sh [--by-count] [path/to/srp.index]

sort_by_count=0
index_file=""
for arg in "$@"; do
    case $arg in
        --by-count|-c) sort_by_count=1 ;;
        *) index_file=$arg ;;
    esac
done
index_file=${index_file:-build-source/srp.index}

if [[ ! -f $index_file ]]; then
    echo "ERROR: index file not found: $index_file" >&2
    echo "Run this from the picons folder (containing build-source/srp.index), or pass the path as an argument." >&2
    exit 1
fi

declare -A ns_onid_names=(
    [1_EEEE0000]="Luxembourg"
    [20FA_EEEE0000]="France"
    [2114_EEEE0000]="Germany"
    [2174_EEEE0000]="Saorview"
    [2038_EEEE0000]="Belgium"
    [22FC_EEEE0000]="Thailand"
    [233A_EEEE0000]="UK Freeview"
    [531_EEEE0000]="Portugal"
    [600_FFFF0000]="NLD Ziggo"
    [8C9_FFFF0000]="NLD Caiway"
    [10EF_FFFF0000]="NLD Delta"
    [25A8_FFFF0000]="NLD SKV"
)

# Same "priority order" lists as 1-build-servicelist.sh - keep in sync
# if you add/remove entries there.
ns_common_orbital=(
    82   # 13.0E
    C0   # 19.2E
    EB   # 23.5E
    11A  # 28.2E
)
ns_common_providers=(
    600_FFFF   # NLD Ziggo
    233A_EEEE  # UK Freeview
)

ns_label() {
    local key=$1 prefix onid dec deg label name
    if [[ $key == *_* ]]; then onid=${key%_*}; prefix=${key#*_}; else prefix=$key; fi
    case $prefix in
        FFFF) name=${ns_onid_names[${onid}_FFFF0000]}; label=${name:-Cable} ;;
        EEEE) name=${ns_onid_names[${onid}_EEEE0000]}; label=${name:-Terrestrial} ;;
        *)
            dec=$((16#$prefix))
            if (( dec > 3599 )); then
                label="Unclassified"
            elif (( dec <= 1800 )); then
                deg=$(awk -v d="$dec" 'BEGIN{printf "%.1f", d/10}')
                label="${deg}°E"
            else
                deg=$(awk -v d="$dec" 'BEGIN{printf "%.1f", (3600-d)/10}')
                label="${deg}°W"
            fi
            ;;
    esac
    if [[ -n $onid ]]; then echo "$label (${onid}_${prefix}xxxx)"; else echo "$label (namespace ${prefix}xxxx)"; fi
}

#############################################
## Count entries per key, keep in a lookup  ##
#############################################
declare -A counts=()
ns_available=""
while read -r count key; do
    counts[$key]=$count
    ns_available+="$key"$'\n'
done < <(
    awk -F'=' '{print $1}' "$index_file" \
    | awk -F'_' '{
        ns=$NF; onid=$(NF-1);
        prefix=(length(ns)>4)?substr(ns,1,length(ns)-4):ns;
        if (prefix=="FFFF" || prefix=="EEEE") print onid"_"prefix;
        else print prefix
      }' \
    | sort | uniq -c
)

#####################################################
## Group into satellite / cable / terrestrial /     ##
## unclassified, same logic as ns_group_and_sort.   ##
#####################################################
ns_cable=() ; ns_terrestrial=() ; ns_satellite=() ; ns_other=()
while read -r key; do
    [[ -z $key ]] && continue
    if [[ $key == *_* ]]; then onid=${key%_*}; prefix=${key#*_}; else prefix=$key; onid=""; fi
    case $prefix in
        FFFF) ns_cable+=("$key") ;;
        EEEE) ns_terrestrial+=("$key") ;;
        *) if (( $((16#$prefix)) > 3599 )); then ns_other+=("$key"); else ns_satellite+=("$key"); fi ;;
    esac
done <<< "$ns_available"

if [[ ${#ns_cable[@]} -gt 0 ]]; then
    ns_cable=($(for key in "${ns_cable[@]}"; do
        onid=${key%_*}; named=0; [[ -n ${ns_onid_names[${key}0000]:-} ]] && named=1
        printf '%d\t%d\t%s\n' "$named" "$((16#$onid))" "$key"
    done | sort -n -k1,1 -k2,2 | cut -f3))
fi
if [[ ${#ns_terrestrial[@]} -gt 0 ]]; then
    ns_terrestrial=($(for key in "${ns_terrestrial[@]}"; do
        onid=${key%_*}; named=0; [[ -n ${ns_onid_names[${key}0000]:-} ]] && named=1
        printf '%d\t%d\t%s\n' "$named" "$((16#$onid))" "$key"
    done | sort -n -k1,1 -k2,2 | cut -f3))
fi
if [[ ${#ns_satellite[@]} -gt 0 ]]; then
    ns_satellite=($(for key in "${ns_satellite[@]}"; do
        dec=$((16#$key))
        if (( dec <= 1800 )); then signed=$dec; else signed=$(( -(3600-dec) )); fi
        printf '%d\t%s\n' "$signed" "$key"
    done | sort -n -k1,1 | cut -f2))
fi
if [[ ${#ns_other[@]} -gt 0 ]]; then
    ns_other=($(for key in "${ns_other[@]}"; do printf '%d\t%s\n' "$((16#$key))" "$key"; done | sort -n -k1,1 | cut -f2))
fi

ns_named=()
for key in "${ns_common_providers[@]}"; do
    for candidate in "${ns_cable[@]}" "${ns_terrestrial[@]}"; do
        [[ $candidate = "$key" ]] && ns_named+=("$key")
    done
done

ns_common=()
for prefix in "${ns_common_orbital[@]}"; do
    for key in "${ns_satellite[@]}"; do
        [[ $key = "$prefix" ]] && ns_common+=("$key")
    done
done

print_section() {
    local title=$1; shift
    local keys=("$@")
    [[ ${#keys[@]} -eq 0 ]] && return
    if [[ $sort_by_count -eq 1 ]]; then
        keys=($(for key in "${keys[@]}"; do printf '%d\t%s\n' "${counts[$key]}" "$key"; done | sort -rn -k1,1 | cut -f2))
    fi
    echo "-- $title --"
    for key in "${keys[@]}"; do
        printf '%6d  %s\n' "${counts[$key]}" "$(ns_label "$key")"
    done
}

print_section "Satellite positions" "${ns_satellite[@]}"
print_section "Cable" "${ns_cable[@]}"
print_section "Terrestrial" "${ns_terrestrial[@]}"
print_section "Unclassified" "${ns_other[@]}"
print_section "Common Positions/Providers" "${ns_common[@]}" "${ns_named[@]}"
