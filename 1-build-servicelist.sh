#!/bin/bash

#####################
## Setup locations ##
#####################
location=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
logfile=$(mktemp --suffix=.servicelist.log)

echo "$(date +'%H:%M:%S') - INFO: Log file located at: $logfile"

########################################################
## Search for required commands and exit if not found ##
########################################################
commands=( sed grep column cat sort find rm wc iconv awk printf python3 )

if [[ -f $location/build-input/tvheadend.serverconf ]]; then
    commands+=( jq curl )
fi

for i in ${commands[@]}; do
    if ! which $i &> /dev/null; then
        missingcommands="$i $missingcommands"
    fi
done
if [[ ! -z $missingcommands ]]; then
    echo "$(date +'%H:%M:%S') - ERROR: The following commands are not found: $missingcommands"
    exit 1
fi

###########################
## Check path for spaces ##
###########################
if [[ $location == *" "* ]]; then
    echo "$(date +'%H:%M:%S') - ERROR: The path contains spaces, please move the repository to a path without spaces!"
    exit 1
fi

#######################################################
## Ask the user whether to build UTF8SNP, SNP or SRP ##
#######################################################
if [[ -z $1 ]]; then
    echo "Which style are you going to build?"
    select choice in "Service Reference" "UTF8 Service Name" "Service Name (Being made redundant, please move to UTF8 Service Name)"; do
        case $choice in
            "Service Reference" ) style="srp"; break;;
            "UTF8 Service Name" ) style="utf8snp"; break;;
            "Service Name (Being made redundant, please move to UTF8 Service Name)" ) style="snp"; break;;
        esac
    done
else
    style=$1
fi

#############################
## Check if style is valid ##
#############################
if [[ ! $style = "srp" ]] && [[ ! $style = "snp" ]] && [[ ! $style = "utf8snp" ]]; then
    echo "$(date +'%H:%M:%S') - ERROR: Unknown style!"
    exit 1
fi

##########################################################################################
## Optional orbital-position (namespace) filter - srp only.                             ##
## Builds straight from the index for the chosen position(s),                           ##
## with no lamedb/bouquet read at all. snp/utf8snp index keys                           ##
## carry no namespace, so filtering isn't possible for those;                           ##
## they always run the full lamedb/bouquet match instead.                               ##
## Usage: ./1-build-servicelist.sh srp 11A,600_FFFF                                     ##
## Usage: ./1-build-servicelist.sh srp all       (every index entry, no lamedb/bouquet) ##
## Usage: ./1-build-servicelist.sh srp enigma2   (lamedb/bouquet build, unchanged)      ##
##########################################################################################
nsfilter=$2

if [[ -n $nsfilter ]] && [[ ! $style = "srp" ]]; then
    echo "$(date +'%H:%M:%S') - INFO: Orbital-position filter ignored: not supported for style \"$style\", running the full lamedb/bouquet match instead."
    nsfilter=""
fi

#####################
## Read index file ##
#####################
index=$(<"$location/build-source/$style.index")

##################################
## Enigma2 servicelist creation ##
##################################

#######################################################################
## srp only: work out which orbital position(s) to build.            ##
## The last 4 hex digits of a namespace are the "subnet" (varies     ##
## per multi-feed transponder), so we group/match on the orbital     ##
## prefix only, e.g. 11Axxxx rather than 11A0000. Cable (FFFFxxxx)   ##
## and Terrestrial (EEEExxxx) aren't tied to a physical position -   ##
## every operator on cable/terrestrial shares that same namespace    ##
## prefix, so those two are additionally keyed by onid (e.g.         ##
## 600_FFFFxxxx, 233A_EEEExxxx) to tell operators apart.             ##
##                                                                   ##
## Choosing specific orbital position(s), or "all", builds straight  ##
## from the $style.index file - no lamedb or bouquet files are read  ##
## or required. Choosing "enigma2" builds against your enigma2       ##
## folder (lamedb/bouquet), exactly as before.                       ##
#######################################################################

#####################################################################
## Friendly names for Cable/Terrestrial onids - most people won't  ##
## recognise a bare onid, so fill this in as you identify them.    ##
## Format: [onid]="Friendly Name". Uncomment/add lines as needed.  ##
#####################################################################
declare -A ns_onid_names=(
      [600]="Ziggo National"
	  # [3E8]="Ziggo (legacy)"
      [233A]="UK Freeview"
)

ns_label() {
    local key=$1 prefix onid dec deg label name
    if [[ $key == *_* ]]; then onid=${key%_*}; prefix=${key#*_}; else prefix=$key; fi
    case $prefix in
        FFFF) name=${ns_onid_names[$onid]}; label=${name:-Cable} ;;
        EEEE) name=${ns_onid_names[$onid]}; label=${name:-Terrestrial} ;;
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
    if [[ -n $onid ]]; then echo "$label (namespace ${prefix}xxxx, onid $onid)"; else echo "$label (namespace ${prefix}xxxx)"; fi
}
ns_pattern_index() {
    local key=$1 prefix onid
    if [[ $key == *_* ]]; then
        onid=${key%_*}; prefix=${key#*_}
        echo "_${onid}_${prefix}[0-9A-F]{4}="
    else
        prefix=$key
        echo "_${prefix}[0-9A-F]{4}="
    fi
}
normalize_ns_token() {
    local tok=${1^^} onid prefix deg dir dec
    if [[ $tok == *_* ]]; then onid=${tok%_*}; prefix=${tok#*_}; else prefix=$tok; fi
    if [[ $prefix =~ ^([0-9]+(\.[0-9]+)?)(E|W)\.?$ ]]; then
        deg=${BASH_REMATCH[1]}; dir=${BASH_REMATCH[3]}
        if [[ $dir = "E" ]]; then
            dec=$(awk -v d="$deg" 'BEGIN{printf "%d", (d*10)+0.5}')
        else
            dec=$(awk -v d="$deg" 'BEGIN{printf "%d", (3600-(d*10))+0.5}')
        fi
        prefix=$(printf '%X' "$dec")
    else
        prefix=${prefix%XXXX}
    fi
    if [[ -n $onid ]]; then echo "${onid}_${prefix}"; else echo "$prefix"; fi
}

ns_group_and_sort() {
    # Reads $ns_available (newline list of keys) into sorted globals:
    # ns_cable, ns_terrestrial (by onid, numeric), ns_satellite (by
    # signed degree, West negative -> East positive, ascending), and
    # ns_other (out-of-range namespace values, by hex, listed last).
    local key prefix onid dec signed
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
        ns_cable=($(for key in "${ns_cable[@]}"; do onid=${key%_*}; printf '%d\t%s\n' "$((16#$onid))" "$key"; done | sort -n -k1,1 | cut -f2))
    fi
    if [[ ${#ns_terrestrial[@]} -gt 0 ]]; then
        ns_terrestrial=($(for key in "${ns_terrestrial[@]}"; do onid=${key%_*}; printf '%d\t%s\n' "$((16#$onid))" "$key"; done | sort -n -k1,1 | cut -f2))
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
}

resolve_ns_token() {
    # Resolves one answer/CLI token to one or more group keys (one per
    # line). Tries, in order: an exact menu number (interactive only),
    # a rough (case-insensitive substring) match against named Cable/
    # Terrestrial entries, then normalize_ns_token (hex/xxxx/degree/
    # onid_prefix). Prints nothing if none of these match.
    local tok=$1 upper key onid found=0
    if [[ $tok =~ ^[0-9]+$ ]] && [[ -n ${ns_menu[$tok]:-} ]]; then
        echo "${ns_menu[$tok]}"
        return
    fi
    upper=${tok^^}
    for key in "${ns_cable[@]}" "${ns_terrestrial[@]}"; do
        onid=${key%_*}
        if [[ -n ${ns_onid_names[$onid]:-} ]] && [[ ${ns_onid_names[$onid]^^} == *"$upper"* ]]; then
            echo "$key"
            found=1
        fi
    done
    if [[ $found -eq 1 ]]; then return; fi
    normalize_ns_token "$tok"
}

ns_mode="full"
unset ns_menu; declare -A ns_menu
if [[ $style = "srp" ]]; then
    ns_available=$(awk -F'=' '{print $1}' <<< "$index" | awk -F'_' '{ns=$NF; onid=$(NF-1); prefix=(length(ns)>4)?substr(ns,1,length(ns)-4):ns; if (prefix=="FFFF" || prefix=="EEEE") print onid"_"prefix; else print prefix}' | sort -u)
    ns_group_and_sort

    if [[ -n $nsfilter ]]; then
        case $nsfilter in
            all) ns_mode="index" ;;
            enigma2) ns_mode="full" ;;
            *)
                ns_mode="orbital"
                ns_selected=$(tr ',' '\n' <<< "$nsfilter" | while read -r tok; do resolve_ns_token "$tok"; done | sort -u)
                ;;
        esac
    else
        echo "Which orbital position(s) do you want to build?"
        i=0
        if [[ ${#ns_cable[@]} -gt 0 ]]; then
            echo "-- Cable --"
            for key in "${ns_cable[@]}"; do ((i++)); ns_menu[$i]=$key; echo "  $i) $(ns_label "$key")"; done
        fi
        if [[ ${#ns_terrestrial[@]} -gt 0 ]]; then
            echo "-- Terrestrial --"
            for key in "${ns_terrestrial[@]}"; do ((i++)); ns_menu[$i]=$key; echo "  $i) $(ns_label "$key")"; done
        fi
        if [[ ${#ns_satellite[@]} -gt 0 ]]; then
            echo "-- Satellite positions --"
            for key in "${ns_satellite[@]}"; do ((i++)); ns_menu[$i]=$key; echo "  $i) $(ns_label "$key")"; done
        fi
        if [[ ${#ns_other[@]} -gt 0 ]]; then
            echo "-- Unclassified --"
            for key in "${ns_other[@]}"; do ((i++)); ns_menu[$i]=$key; echo "  $i) $(ns_label "$key")"; done
        fi
        echo "  'all'     - every reference in the $style.index (no lamedb/bouquet)"
        echo "  'enigma2' - filter against your enigma2 folder (lamedb/bouquet)"
        echo "  'cancel'  - exit without building anything"
        read -p "Enter number(s), position(s) (e.g. 28.2E), name(s) (e.g. Ziggo), 'all'/'enigma2' (no response defaults to 'enigma2'), or 'cancel': " ns_answer
        case $ns_answer in
            cancel|quit|exit)
                echo "$(date +'%H:%M:%S') - INFO: Cancelled, nothing was built."
                exit 0
                ;;
            ""|enigma2) ns_mode="full" ;;
            all) ns_mode="index" ;;
            *)
                ns_mode="orbital"
                ns_selected=$(tr ',' '\n' <<< "$ns_answer" | while read -r tok; do resolve_ns_token "$tok"; done | sort -u)
                ;;
        esac
    fi
fi

if [[ $ns_mode = "orbital" ]]; then
    ################################################################
    ## Orbital-position build: straight from the index, no        ##
    ## lamedb/bouquet read or required.                           ##
    ################################################################
    file=$location/build-output/servicelist-enigma2-$style.txt
    tempfile=$(mktemp --suffix=.servicelist)

    patterns=()
    while read -r key; do patterns+=("$(ns_pattern_index "$key")"); done <<< "$ns_selected"
    index_regex=$(IFS='|'; echo "${patterns[*]}")

    grep -E "$index_regex" <<< "$index" | while IFS='=' read -r key logo; do
        echo -e "1_0_1_${key}_0_0_0\t\t${key}=${logo}" >> "$tempfile"
    done

    sort -t $'\t' -k 2,2 "$tempfile" | sed -e 's/\t/^|/g' | column -t -s $'^' | sed -e 's/|/  |  /g' > "$file"
    rm "$tempfile"
    echo "$(date +'%H:%M:%S') - INFO: Enigma2: Exported to $file (orbital-position filter, no lamedb/bouquet used)"
elif [[ $ns_mode = "index" ]]; then
    #####################################################################
    ## Full index build: every entry in $style.index, no filtering,    ##
    ## no lamedb/bouquet read or required.                             ##
    #####################################################################
    file=$location/build-output/servicelist-enigma2-$style.txt
    tempfile=$(mktemp --suffix=.servicelist)

    while IFS='=' read -r key logo; do
        echo -e "1_0_1_${key}_0_0_0\t\t${key}=${logo}" >> "$tempfile"
    done <<< "$index"

    sort -t $'\t' -k 2,2 "$tempfile" | sed -e 's/\t/^|/g' | column -t -s $'^' | sed -e 's/|/  |  /g' > "$file"
    rm "$tempfile"
    echo "$(date +'%H:%M:%S') - INFO: Enigma2: Exported to $file (full index, no lamedb/bouquet used)"
elif [[ -d $location/build-input/enigma2 ]]; then
    file=$location/build-output/servicelist-enigma2-$style.txt
    tempfile=$(mktemp --suffix=.servicelist)
    lamedb=$(<"$location/build-input/enigma2/lamedb")
    channelcount=$(cat "$location/build-input/enigma2/"*bouquet.* | grep -o '#SERVICE .*:0:.*:.*:.*:.*:.*:0:0:0' | sort -u | wc -l)

    ## Build a serviceref->name map from bouquet #DESCRIPTION lines
    ## Includes standard services and IPTV entries (excludes folder type 64 and sub-bouquet type 320)
    bouquetmap=$(mktemp --suffix=.bouquetmap)
    awk '
        /^#DESCRIPTION/ { desc = substr($0, 14); sub(/\r/, "", desc); next }
        /^#SERVICE/ {
            if ($0 ~ /^#SERVICE 1:64:/ || $0 ~ /^#SERVICE 1:320:/) { desc = ""; next }
            if (desc != "") {
                ref = $0; sub(/^#SERVICE /, "", ref); sub(/:[\r]?$/, "", ref)
                gsub(/:/, "_", ref); print toupper(ref) "\t" desc; desc = ""
            }
        }
    ' $location/build-input/enigma2/*bouquet.* | sort -u > "$bouquetmap"

    cat $location/build-input/enigma2/*bouquet.* | grep -o '#SERVICE .*:0:.*:.*:.*:.*:.*:0:0:0' | sed -e 's/#SERVICE //g' -e 's/.*/\U&\E/' -e 's/:/_/g' | sort -u | while read serviceref ; do
        ((currentline++))
        if [[ $- == *i* ]]; then
            echo -ne "Enigma2: Converting channel: $currentline/$channelcount"\\r
        fi

        serviceref_id=$(sed -e 's/^[^_]*_0_[^_]*_//g' -e 's/_0_0_0$//g' <<< "$serviceref")
        unique_id=$serviceref_id
        channelref=(${serviceref//_/ })

        logo_srp=$(grep -i -m 1 "^$unique_id" <<< "$index" | sed -n -e 's/.*=//p')
        if [[ -z $logo_srp ]]; then logo_srp="--------"; fi

        if [[ $style = "utf8snp" ]]; then
            channelname_lamedb=$(grep -i -A1 "0*${channelref[3]}:.*${channelref[6]}:.*${channelref[4]}:.*${channelref[5]}:.*:.*" <<< "$lamedb" | sed -n "2p" 2>> $logfile | sed -e 's/^[ \t]*//' -e 's/|//g' -e 's/\xef\xbb\xbf//g')
            channelname_bouquet=$(grep -m 1 "^${serviceref}	" "$bouquetmap" | cut -f2)
            channelname=${channelname_lamedb:-$channelname_bouquet}
            utf8snpname=$(python3 -c "import unicodedata,sys; print(unicodedata.normalize('NFD', sys.argv[1]))" "$channelname" | sed -e 's/\(.*\)/\L\1/g' -e 's/[<>:"\/\\|?*]//g' -e 's/\.\+$//')
            if [[ -z $utf8snpname ]]; then utf8snpname="--------"; fi
            logo_utf8snp=$(grep -i -m 1 "^$utf8snpname=" <<< "$index" | sed -n -e 's/.*=//p')
            if [[ -z $logo_utf8snp ]]; then logo_utf8snp="--------"; fi
            echo -e "$serviceref\t$channelname\t$serviceref_id=$logo_srp\t$utf8snpname=$logo_utf8snp" >> $tempfile
            ## If bouquet name differs from lamedb name (case-insensitive), output a second row
            if [[ -n $channelname_lamedb ]] && [[ -n $channelname_bouquet ]] && [[ "${channelname_lamedb,,}" != "${channelname_bouquet,,}" ]]; then
                utf8snpname2=$(python3 -c "import unicodedata,sys; print(unicodedata.normalize('NFD', sys.argv[1]))" "$channelname_bouquet" | sed -e 's/\(.*\)/\L\1/g' -e 's/[<>:"\/\\|?*]//g' -e 's/\.\+$//')
                if [[ -z $utf8snpname2 ]]; then utf8snpname2="--------"; fi
                logo_utf8snp2=$(grep -i -m 1 "^$utf8snpname2=" <<< "$index" | sed -n -e 's/.*=//p')
                if [[ -z $logo_utf8snp2 ]]; then logo_utf8snp2="--------"; fi
                echo -e "$serviceref\t$channelname_bouquet\t$serviceref_id=$logo_srp\t$utf8snpname2=$logo_utf8snp2" >> $tempfile
            fi
        elif [[ $style = "snp" ]]; then
            channelname_lamedb=$(grep -i -A1 "0*${channelref[3]}:.*${channelref[6]}:.*${channelref[4]}:.*${channelref[5]}:.*:.*" <<< "$lamedb" | sed -n "2p" | iconv -f utf-8 -t ascii//translit 2>> $logfile | sed -e 's/^[ \t]*//' -e 's/|//g' -e 's/\xef\xbb\xbf//g')
            channelname_bouquet=$(grep -m 1 "^${serviceref}	" "$bouquetmap" | cut -f2 | iconv -f utf-8 -t ascii//translit 2>> $logfile | sed -e 's/\xef\xbb\xbf//g')
            channelname=${channelname_lamedb:-$channelname_bouquet}
            snpname=$(sed -e 's/&/and/g' -e 's/*/star/g' -e 's/+/plus/g' -e 's/\(.*\)/\L\1/g' -e 's/[^a-z0-9]//g' <<< "$channelname")
            if [[ -z $snpname ]]; then snpname="--------"; fi
            logo_snp=$(grep -i -m 1 "^$snpname=" <<< "$index" | sed -n -e 's/.*=//p')
            if [[ -z $logo_snp ]]; then logo_snp="--------"; fi
            echo -e "$serviceref\t$channelname\t$serviceref_id=$logo_srp\t$snpname=$logo_snp" >> $tempfile
            ## If bouquet name differs from lamedb name (case-insensitive), output a second row
            if [[ -n $channelname_lamedb ]] && [[ -n $channelname_bouquet ]] && [[ "${channelname_lamedb,,}" != "${channelname_bouquet,,}" ]]; then
                snpname2=$(sed -e 's/&/and/g' -e 's/*/star/g' -e 's/+/plus/g' -e 's/\(.*\)/\L\1/g' -e 's/[^a-z0-9]//g' <<< "$channelname_bouquet")
                if [[ -z $snpname2 ]]; then snpname2="--------"; fi
                logo_snp2=$(grep -i -m 1 "^$snpname2=" <<< "$index" | sed -n -e 's/.*=//p')
                if [[ -z $logo_snp2 ]]; then logo_snp2="--------"; fi
                echo -e "$serviceref\t$channelname_bouquet\t$serviceref_id=$logo_srp\t$snpname2=$logo_snp2" >> $tempfile
            fi
        else
            channelname=$(grep -i -A1 "0*${channelref[3]}:.*${channelref[6]}:.*${channelref[4]}:.*${channelref[5]}:.*:.*" <<< "$lamedb" | sed -n "2p" | iconv -f utf-8 -t ascii//translit 2>> $logfile | sed -e 's/^[ \t]*//' -e 's/|//g' -e 's/\xef\xbb\xbf//g')
            if [[ -z $channelname ]]; then channelname=$(grep -m 1 "^${serviceref}\t" "$bouquetmap" | cut -f2 | iconv -f utf-8 -t ascii//translit 2>> $logfile | sed -e 's/\xef\xbb\xbf//g'); fi
            echo -e "$serviceref\t$channelname\t$serviceref_id=$logo_srp" >> $tempfile
        fi
    done

    sort -t $'\t' -k 2,2 "$tempfile" | sed -e 's/\t/^|/g' | column -t -s $'^' | sed -e 's/|/  |  /g' > $file
    rm $tempfile "$bouquetmap"
    echo "$(date +'%H:%M:%S') - INFO: Enigma2: Exported to $file"
else
    echo "$(date +'%H:%M:%S') - ERROR: Enigma2: $location/build-input/enigma2 not found"
fi

######################################################
## TvHeadend servicelist creation (from server API) ##
######################################################
if [[ -f $location/build-input/tvheadend.serverconf ]]; then
    # ...set default credentials for tvh server
    TVH_HOST="localhost"
    TVH_PORT="9981"
    TVH_USER=""
    TVH_PASS=""
    TVH_HTTP_ROOT=""

    # ...replace default credentials by those configured in file
    source $location/build-input/tvheadend.serverconf

    # ...set file name for the service list to generate
    file=$location/build-output/servicelist-tvheadend-servermode-$style.txt
    tempfile=$(mktemp --suffix=.servicelist)

    # ...the server url
    [[ -n $TVH_USER ]] && url="http://$TVH_USER:$TVH_PASS@$TVH_HOST:$TVH_PORT" || url="http://$TVH_HOST:$TVH_PORT"

    # ...check if we need to append a base url to the tvheadend url
    [[ -n $TVH_HTTP_ROOT ]] && url="$url/$TVH_HTTP_ROOT"

    # ...reading the number of channel from the server
    channelcount=$(curl -s --anyauth $url'/api/channel/grid?start=0&limit=1' | jq -r '.total' )

    if [[ -n $channelcount ]]; then
        # looping trough the given number of channels and fetch one by one to parse the json object
        for ((channel=0; channel<$channelcount; channel++)); do
            if [[ $- == *i* ]]; then
                echo -ne "TvHeadend (server-mode): Converting channel: $channel/$channelcount"\\r
            fi

            # fetching next channel
            rx_buf=$(curl -s --anyauth $url'/api/channel/grid?start='$channel'&limit=1' )

            # extracting service reference; IPTV channels won't have one in this form
            serviceref=$(echo $rx_buf |  jq -r '.entries[].icon'  | grep -o '1_0_.*_.*_.*_.*_.*_0_0_0')

            # skip if no service reference and style is srp (nothing useful to do without one)
            if [[ ! -n $serviceref ]] && [[ $style = "srp" ]]; then
                continue
            fi

            channelname_raw=$(echo $rx_buf | jq -r '.entries | .[] | .name' | sed -e 's/\xef\xbb\xbf//g')

            if [[ -n $serviceref ]]; then
                serviceref_id=$(sed -e 's/^[^_]*_0_[^_]*_//g' -e 's/_0_0_0$//g' <<< "$serviceref")
                unique_id=$(echo "$serviceref" | sed -n -e 's/^1_0_[^_]*_//p' | sed -n -e 's/_0_0_0$//p')
                logo_srp=$(grep -i -m 1 "^$unique_id" <<< "$index" | sed -n -e 's/.*=//p')
            fi
            if [[ -z $logo_srp ]]; then logo_srp="--------"; fi

            if [[ $style = "utf8snp" ]]; then
                channelname=$channelname_raw
                # TVHeadend uses NFC for filenames; normalise to NFD only for index lookup, then convert back to NFC for output
                utf8snpname_nfd=$(python3 -c "import unicodedata,sys; print(unicodedata.normalize('NFD', sys.argv[1]))" "$channelname" | sed -e 's/\(.*\)/\L\1/g' -e 's/[<>:"\/\\|?*]//g' -e 's/\.\+$//')
                utf8snpname=$(python3 -c "import unicodedata,sys; print(unicodedata.normalize('NFC', sys.argv[1]))" "$channelname" | sed -e 's/\(.*\)/\L\1/g')
                if [[ -z $utf8snpname ]]; then utf8snpname="--------"; fi
                logo_utf8snp=$(grep -i -m 1 "^$utf8snpname_nfd=" <<< "$index" | sed -n -e 's/.*=//p')
                if [[ -z $logo_utf8snp ]]; then logo_utf8snp="--------"; fi
                echo -e "$serviceref\t$channelname\t$serviceref_id=$logo_srp\t$utf8snpname=$logo_utf8snp" >> $tempfile
            elif [[ $style = "snp" ]]; then
                channelname=$(iconv -f utf-8 -t ascii//TRANSLIT <<< "$channelname_raw" | sed -e 's/\xef\xbb\xbf//g')
                snpname=$(sed -e 's/&/and/g' -e 's/*/star/g' -e 's/+/plus/g' -e 's/\(.*\)/\L\1/g' -e 's/[^a-z0-9]//g' <<< "$channelname")
                if [[ -z $snpname ]]; then snpname="--------"; fi
                logo_snp=$(grep -i -m 1 "^$snpname=" <<< "$index" | sed -n -e 's/.*=//p')
                if [[ -z $logo_snp ]]; then logo_snp="--------"; fi
                echo -e "$serviceref\t$channelname\t$serviceref_id=$logo_srp\t$snpname=$logo_snp" >> $tempfile
            else
                channelname=$(iconv -f utf-8 -t ascii//TRANSLIT <<< "$channelname_raw" | sed -e 's/\xef\xbb\xbf//g')
                echo -e "$serviceref\t$channelname\t$serviceref_id=$logo_srp" >> $tempfile
            fi
        done

        sort -t $'\t' -k 2,2 "$tempfile" | sed -e 's/\t/^|/g' | column -t -s $'^' | sed -e 's/|/  |  /g' > $file
        rm $tempfile
        echo "$(date +'%H:%M:%S') - INFO: TvHeadend (server-mode): Exported to $file"
    else
        echo "$(date +'%H:%M:%S') - ERROR: TvHeadend (server-mode): \"${TVH_HOST}\" is not reachable or has no channels."
    fi
else
    echo "$(date +'%H:%M:%S') - ERROR: TvHeadend (server-mode): $location/build-input/tvheadend.serverconf not found"
fi

##############################
## VDR servicelist creation ##
##############################
if [[ -f $location/build-input/channels.conf ]]; then
    file=$location/build-output/servicelist-vdr-$style.txt
    tempfile=$(mktemp --suffix=.servicelist)
    channelcount=$(grep -o '.*:.*:.*:.*:.*:.*:.*:.*:.*:.*:.*:.*:0' "$location/build-input/channels.conf" | sort -u | wc -l)

    grep -o '.*:.*:.*:.*:.*:.*:.*:.*:.*:.*:.*:.*:0' $location/build-input/channels.conf | sort -u | while read channel ; do
        ((currentline++))
        if [[ $- == *i* ]]; then
            echo -ne "VDR: Converting channel: $currentline/$channelcount"\\r
        fi

        IFS=":"
        vdrchannel=($channel)
        IFS=";"

        sid=$(printf "%x\n" ${vdrchannel[9]})
        tid=$(printf "%x\n" ${vdrchannel[11]})
        nid=$(printf "%x\n" ${vdrchannel[10]})

        case ${vdrchannel[3]} in
            *"W") namespace=$(printf "%x\n" $(sed -e 's/S//' -e 's/W//' <<< "${vdrchannel[3]}" | awk '{printf "%.0f\n", 3600-($1*10)}'));;
            *"E") namespace=$(printf "%x\n" $(sed -e 's/S//' -e 's/E//' <<< "${vdrchannel[3]}" | awk '{printf "%.0f\n", $1*10}'));;
            "T") namespace="EEEE";;
            "C") namespace="FFFF";;
        esac
        case ${vdrchannel[5]} in
            "0") channeltype="2";;
            *"=2") channeltype="1";;
            *"=27") channeltype="19";;
        esac

        unique_id=$(sed -e 's/.*/\U&\E/' <<< "$sid"'_'"$tid"'_'"$nid"'_'"$namespace")
        serviceref='1_0_'"$channeltype"'_'"$unique_id"'0000_0_0_0'
        serviceref_id="$unique_id"'0000'
        channelname_raw=(${vdrchannel[0]})
        channelname_raw="${channelname_raw[0]}"

        logo_srp=$(grep -i -m 1 "^$unique_id" <<< "$index" | sed -n -e 's/.*=//p')
        if [[ -z $logo_srp ]]; then logo_srp="--------"; fi

        if [[ $style = "utf8snp" ]]; then
            # VDR uses NFC for filenames; normalise to NFD only for index lookup, then convert back to NFC for output
            channelname=$(sed -e 's/^[ \t]*//' -e 's/|//g' -e 's/\xef\xbb\xbf//g' <<< "$channelname_raw")
            utf8snpname_nfd=$(python3 -c "import unicodedata,sys; print(unicodedata.normalize('NFD', sys.argv[1]))" "$channelname" | sed -e 's/\(.*\)/\L\1/g' -e 's/[<>:"\/\\|?*]//g' -e 's/\.\+$//')
            utf8snpname=$(python3 -c "import unicodedata,sys; print(unicodedata.normalize('NFC', sys.argv[1]))" "$channelname" | sed -e 's/\(.*\)/\L\1/g')
            if [[ -z $utf8snpname ]]; then utf8snpname="--------"; fi
            logo_utf8snp=$(grep -i -m 1 "^$utf8snpname_nfd=" <<< "$index" | sed -n -e 's/.*=//p')
            if [[ -z $logo_utf8snp ]]; then logo_utf8snp="--------"; fi
            echo -e "$serviceref\t$channelname\t$serviceref_id=$logo_srp\t$utf8snpname=$logo_utf8snp" >> $tempfile
        elif [[ $style = "snp" ]]; then
            channelname=$(iconv -f utf-8 -t ascii//translit <<< "$channelname_raw" 2>> $logfile | sed -e 's/^[ \t]*//' -e 's/|//g' -e 's/\xef\xbb\xbf//g')
            snpname=$(sed -e 's/&/and/g' -e 's/*/star/g' -e 's/+/plus/g' -e 's/\(.*\)/\L\1/g' -e 's/[^a-z0-9]//g' <<< "$channelname")
            if [[ -z $snpname ]]; then snpname="--------"; fi
            logo_snp=$(grep -i -m 1 "^$snpname=" <<< "$index" | sed -n -e 's/.*=//p')
            if [[ -z $logo_snp ]]; then logo_snp="--------"; fi
            echo -e "$serviceref\t$channelname\t$serviceref_id=$logo_srp\t$snpname=$logo_snp" >> $tempfile
        else
            channelname=$(iconv -f utf-8 -t ascii//translit <<< "$channelname_raw" 2>> $logfile | sed -e 's/^[ \t]*//' -e 's/|//g' -e 's/\xef\xbb\xbf//g')
            echo -e "$serviceref\t$channelname\t$serviceref_id=$logo_srp" >> $tempfile
        fi
    done

    sort -t $'\t' -k 2,2 "$tempfile" | sed -e 's/\t/^|/g' | column -t -s $'^' | sed -e 's/|/  |  /g' > $file
    rm $tempfile
    echo "$(date +'%H:%M:%S') - INFO: VDR: Exported to $file"
else
    echo "$(date +'%H:%M:%S') - ERROR: VDR: $location/build-input/channels.conf not found"
fi

exit 0
