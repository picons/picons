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
commands=( sed grep column cat sort find rm wc iconv awk printf )

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

##############################################
## Ask the user whether to build SNP or SRP ##
##############################################
if [[ -z $1 ]]; then
    echo "Which style are you going to build?"
    select choice in "Service Reference" "Service Name"; do
        case $choice in
            "Service Reference" ) style="srp"; break;;
            "Service Name" ) style="snp"; break;;
        esac
    done
else
    style=$1
fi

#############################
## Check if style is valid ##
#############################
if [[ ! $style = "srp" ]] && [[ ! $style = "snp" ]]; then
    echo "$(date +'%H:%M:%S') - ERROR: Unknown style!"
    exit 1
fi

#####################
## Read index file ##
#####################
index=$(<"$location/build-source/$style.index")

##################################
## Enigma2 servicelist creation ##
##################################
if [[ -d $location/build-input/enigma2 ]]; then
    file=$location/build-output/servicelist-enigma2-$style.txt
    tempfile=$(mktemp --suffix=.servicelist)
    lamedb=$(<"$location/build-input/enigma2/lamedb")
    channelcount=$(cat "$location/build-input/enigma2/"*bouquet.* | grep -o '#SERVICE .*:0:.*:.*:.*:.*:.*:0:0:0' | sort -u | wc -l)

    cat $location/build-input/enigma2/*bouquet.* | grep -o '#SERVICE .*:0:.*:.*:.*:.*:.*:0:0:0' | sed -e 's/#SERVICE //g' -e 's/.*/\U&\E/' -e 's/:/_/g' | sort -u | while read serviceref ; do
        ((currentline++))
        if [[ $- == *i* ]]; then
            echo -ne "Enigma2: Converting channel: $currentline/$channelcount"\\r
        fi

        serviceref_id=$(sed -e 's/^[^_]*_0_[^_]*_//g' -e 's/_0_0_0$//g' <<< "$serviceref")
        unique_id=${serviceref_id%????}
        channelref=(${serviceref//_/ })
        channelname=$(grep -i -A1 "${channelref[3]}:.*${channelref[6]}:.*${channelref[4]}:.*${channelref[5]}:.*:.*" <<< "$lamedb" | sed -n "2p" | iconv -f utf-8 -t ascii//translit 2>> $logfile | sed -e 's/^[ \t]*//' -e 's/|//g' -e 's/^//g')

        logo_srp=$(grep -i -m 1 "^$unique_id" <<< "$index" | sed -n -e 's/.*=//p')
        if [[ -z $logo_srp ]]; then logo_srp="--------"; fi

        if [[ $style = "snp" ]]; then
            snpname=$(sed -e 's/&/and/g' -e 's/*/star/g' -e 's/+/plus/g' -e 's/\(.*\)/\L\1/g' -e 's/[^a-z0-9]//g' <<< "$channelname")
            if [[ -z $snpname ]]; then snpname="--------"; fi
            logo_snp=$(grep -i -m 1 "^$snpname=" <<< "$index" | sed -n -e 's/.*=//p')
            if [[ -z $logo_snp ]]; then logo_snp="--------"; fi
            echo -e "$serviceref\t$channelname\t$serviceref_id=$logo_srp\t$snpname=$logo_snp" >> $tempfile
        else
            echo -e "$serviceref\t$channelname\t$serviceref_id=$logo_srp" >> $tempfile
        fi
    done

    sort -t $'\t' -k 2,2 "$tempfile" | sed -e 's/\t/^|/g' | column -t -s $'^' | sed -e 's/|/  |  /g' > $file
    rm $tempfile
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

            # extracting service reference and skip the rest if nothing usable found
            serviceref=$(echo $rx_buf |  jq -r '.entries[].icon'  | grep -o '1_0_.*_.*_.*_.*_.*_0_0_0')

            if [[ ! -n $serviceref ]]; then
                continue
            fi

            serviceref_id=$(sed -e 's/^[^_]*_0_[^_]*_//g' -e 's/_0_0_0$//g' <<< "$serviceref")
            unique_id=$(echo "$serviceref" | sed -n -e 's/^1_0_[^_]*_//p' | sed -n -e 's/_0_0_0$//p')
            channelname=$(echo $rx_buf | jq -r '.entries | .[] | .name' | iconv -f utf-8 -t ascii//TRANSLIT)

            logo_srp=$(grep -i -m 1 "^$unique_id" <<< "$index" | sed -n -e 's/.*=//p')
            if [[ -z $logo_srp ]]; then logo_srp="--------"; fi

            if [[ $style = "snp" ]]; then
                snpname=$(sed -e 's/&/and/g' -e 's/*/star/g' -e 's/+/plus/g' -e 's/\(.*\)/\L\1/g' -e 's/[^a-z0-9]//g' <<< "$channelname")
                if [[ -z $snpname ]]; then snpname="--------"; fi
                logo_snp=$(grep -i -m 1 "^$snpname=" <<< "$index" | sed -n -e 's/.*=//p')
                if [[ -z $logo_snp ]]; then logo_snp="--------"; fi
                echo -e "$serviceref\t$channelname\t$serviceref_id=$logo_srp\t$snpname=$logo_snp" >> $tempfile
            else
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
        channelname=(${vdrchannel[0]})
        channelname=$(iconv -f utf-8 -t ascii//translit <<< "${channelname[0]}" 2>> $logfile | sed -e 's/^[ \t]*//' -e 's/|//g' -e 's/^//g')

        logo_srp=$(grep -i -m 1 "^$unique_id" <<< "$index" | sed -n -e 's/.*=//p')
        if [[ -z $logo_srp ]]; then logo_srp="--------"; fi

        if [[ $style = "snp" ]]; then
            snpname=$(sed -e 's/&/and/g' -e 's/*/star/g' -e 's/+/plus/g' -e 's/\(.*\)/\L\1/g' -e 's/[^a-z0-9]//g' <<< "$channelname")
            if [[ -z $snpname ]]; then snpname="--------"; fi
            logo_snp=$(grep -i -m 1 "^$snpname=" <<< "$index" | sed -n -e 's/.*=//p')
            if [[ -z $logo_snp ]]; then logo_snp="--------"; fi
            echo -e "$serviceref\t$channelname\t$serviceref_id=$logo_srp\t$snpname=$logo_snp" >> $tempfile
        else
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
