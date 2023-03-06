#!/bin/bash

location=$1
temp=$2
style=$3

echo "#!/bin/sh" > $temp/create-symlinks-dvbviewer.sh
chmod 755 $temp/create-symlinks-dvbviewer.sh

##########################################
## Create symlinks using only snp-index ##
##########################################
sed '1!G;h;$!d' $location/build-source/snp.index | while read line ; do
    IFS="="
    link_snp=($line)
    logo_snp=${link_snp[1]}
    snpname=${link_snp[0]}

    if [[ ! $snpname == *"_"* ]]; then
        echo "ln -s -f logos/$logo_snp.png $temp/package/picon/$snpname.png" >> $temp/create-symlinks-dvbviewer.sh
    fi
done
