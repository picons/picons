#!/bin/bash

location=$1
temp=$2
style=$3

echo "#!/bin/sh" > $temp/create-symlinks.sh
chmod 755 $temp/create-symlinks.sh

##############################################################
## Create symlinks for UTF8SNP, SNP & SRP using servicelist ##
##############################################################
if [[ $style = "snp" ]] || [[ $style = "srp" ]] || [[ $style = "utf8snp" ]]; then
    cat $location/build-output/servicelist-*-$style.txt | tr -d [:blank:] | tr -d [=*=] | while read line ; do
        IFS="|"
        line_data=($line)
        serviceref=${line_data[0]}
        link_srp=${line_data[2]}
        link_snp=${line_data[3]}
        link_utf8snp=${line_data[3]}

        IFS="="
        link_srp=($link_srp)
        logo_srp=${link_srp[1]}
        link_snp=($link_snp)
        logo_snp=${link_snp[1]}
        snpname=${link_snp[0]}
        link_utf8snp=($link_utf8snp)
        logo_utf8snp=${link_utf8snp[1]}
        utf8snpname=${link_utf8snp[0]}

        if [[ ! $logo_srp = "--------" ]]; then
            echo "ln -s -f 'logos/$logo_srp.png' '$temp/package/picon/$serviceref.png'" >> $temp/create-symlinks.sh
        fi

        if [[ $style = "snp" ]] && [[ ! $logo_snp = "--------" ]]; then
            echo "ln -s -f 'logos/$logo_snp.png' '$temp/package/picon/$snpname.png'" >> $temp/create-symlinks.sh
        fi

        if [[ $style = "utf8snp" ]] && [[ ! $logo_utf8snp = "--------" ]]; then
            echo "ln -s -f 'logos/$logo_utf8snp.png' '$temp/package/picon/$utf8snpname.png'" >> $temp/create-symlinks.sh
        fi
    done
fi

##########################################
## Create symlinks using only snp-index ##
##########################################
if [[ $style = "snp-full" ]]; then
    sed '1!G;h;$!d' $location/build-source/snp.index | while read line ; do
        IFS="="
        link_snp=($line)
        logo_snp=${link_snp[1]}
        snpname=${link_snp[0]}

        if [[ $snpname == *"_"* ]]; then
            echo "ln -s -f 'logos/$logo_snp.png' '$temp/package/picon/1_0_1_"$snpname"_0_0_0.png'" >> $temp/create-symlinks.sh
        else
            echo "ln -s -f 'logos/$logo_snp.png' '$temp/package/picon/$snpname.png'" >> $temp/create-symlinks.sh
        fi
    done
fi

##########################################
## Create symlinks using only srp-index ##
##########################################
if [[ $style = "srp-full" ]]; then
    sed '1!G;h;$!d' $location/build-source/srp.index | while read line ; do
        IFS="="
        link_srp=($line)
        logo_srp=${link_srp[1]}
        unique_id=${link_srp[0]}

        echo "ln -s -f 'logos/$logo_srp.png' '$temp/package/picon/1_0_1_"$unique_id"_0_0_0.png'" >> $temp/create-symlinks.sh
    done
fi

##############################################
## Create symlinks using only utf8snp-index ##
##############################################
if [[ $style = "utf8snp-full" ]]; then
    sed '1!G;h;$!d' $location/build-source/utf8snp.index | while read line ; do
        IFS="="
        link_utf8snp=($line)
        logo_utf8snp=${link_utf8snp[1]}
        utf8snpname=${link_utf8snp[0]}

        if [[ $utf8snpname == *"_"* ]]; then
            echo "ln -s -f 'logos/$logo_utf8snp.png' '$temp/package/picon/1_0_1_"$utf8snpname"_0_0_0.png'" >> $temp/create-symlinks.sh
        else
            echo "ln -s -f 'logos/$logo_utf8snp.png' '$temp/package/picon/$utf8snpname.png'" >> $temp/create-symlinks.sh
        fi
    done
fi
