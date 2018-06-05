#!/bin/bash

#####################
## Setup locations ##
#####################
location=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
temp=$(mktemp -d --suffix=.picons)
logfile=$(mktemp --suffix=.picons.log)

path_inkscape=$(find /c/PROGRA~1/Inkscape* -maxdepth 0 -type d 2>>/dev/null); if [[ -n $path_inkscape ]]; then export PATH=$PATH:$path_inkscape; fi
path_imagemagick=$(find /c/PROGRA~1/ImageMagick* -maxdepth 0 -type d 2>>/dev/null); if [[ -n $path_imagemagick ]]; then export PATH=$PATH:$path_imagemagick; fi

echo -e "\nLog file located at: $logfile\n"

###########################
## Check path for spaces ##
###########################
if [[ $location == *" "* ]]; then
    echo "ERROR: The path contains spaces, please move the repository to a path without spaces!" >> $logfile
    echo "TERMINATED: Read the log file!"
    exit 1
fi

########################################################
## Search for required commands and exit if not found ##
########################################################
commands=( tar sed grep tr cat sort find mkdir rm cp mv ln readlink )
for i in ${commands[@]}; do
    if ! which $i &> /dev/null; then
        missingcommands="$i $missingcommands"
    fi
done
if [[ -z $missingcommands ]]; then
    echo "INFO: All required commands are found!" >> $logfile
else
    echo "ERROR: The following commands are not found: $missingcommands" >> $logfile
    echo "TERMINATED: Read the log file!"
    exit 1
fi

if which ar &> /dev/null; then
    skipipk="false"
    echo "INFO: Creation of ipk files enabled!" >> $logfile
else
    skipipk="true"
    echo "WARNING: Creation of ipk files disabled! Try installing: ar (found in package: binutils)" >> $logfile
fi

if which xz &> /dev/null; then
    compressor="xz -9 --extreme --memlimit=40%" ; ext="xz"
    echo "INFO: Using xz as compression!" >> $logfile
elif which bzip2 &> /dev/null; then
    compressor="bzip2 -9" ; ext="bz2"
    echo "INFO: Using bzip2 as compression!" >> $logfile
else
    echo "ERROR: No archiver has been found! Try installing: xz (or: bzip2)" >> $logfile
    echo "TERMINATED: Read the log file!"
    exit 1
fi

if which pngquant &> /dev/null; then
    pngquant="pngquant"
    echo "INFO: Image compression enabled!" >> $logfile
else
    pngquant="cat"
    echo "WARNING: Image compression disabled! Try installing: pngquant" >> $logfile
fi

if which convert &> /dev/null; then
    echo "INFO: ImageMagick was found!" >> $logfile
else
    echo "ERROR: ImageMagick was not found! Try installing: imagemagick" >> $logfile
    echo "TERMINATED: Read the log file!"
    exit 1
fi

if [[ -f $location/build-input/svgconverter.conf ]]; then
    svgconverterconf=$location/build-input/svgconverter.conf
else
    echo "$(date +'%H:%M:%S') - No \"svgconverter.conf\" file found in \"build-input\", using default file!"
    svgconverterconf=$location/build-source/config/svgconverter.conf
fi
if which inkscape &> /dev/null && [[ $(grep -v -e '^#' -e '^$' $svgconverterconf) = "inkscape" ]]; then
    svgconverter="inkscape -w 850 --without-gui --export-area-drawing --export-png="
    echo "INFO: Using inkscape as svg converter!" >> $logfile
elif which rsvg-convert &> /dev/null && [[ $(grep -v -e '^#' -e '^$' $svgconverterconf) = "rsvg" ]]; then
    svgconverter="rsvg-convert -w 1000 --keep-aspect-ratio --output "
    echo "INFO: Using rsvg as svg converter!" >> $logfile
else
    echo "ERROR: SVG converter: $(grep -v -e '^#' -e '^$' $svgconverterconf), was not found!" >> $logfile
    echo "       Try installing on Ubuntu: librsvg2-bin (or: inkscape)" >> $logfile
    echo "       Try installing in Cygwin: rsvg (or: inkscape)" >> $logfile
    echo "       Try installing on Windows: inkscape" >> $logfile
    echo "TERMINATED: Read the log file!"
    exit 1
fi

##############################################
## Ask the user whether to build SNP or SRP ##
##############################################
if [[ -z $1 ]]; then
    echo "Which style are you going to build?"
    select choice in "Service Reference" "Service Reference (Full)" "Service Name" "Service Name (Full)"; do
        case $choice in
            "Service Reference" ) style=srp; break;;
            "Service Reference (Full)" ) style=srp-full; break;;
            "Service Name" ) style=snp; break;;
            "Service Name (Full)" ) style=snp-full; break;;
        esac
    done
else
    style=$1
fi

#############################################
## Check if previously chosen style exists ##
#############################################
if [[ ! $style = "srp-full" ]] && [[ ! $style = "snp-full" ]]; then
    for file in $location/build-output/servicelist-*-$style.txt ; do
        if [[ ! -f $file ]]; then
            echo "ERROR: No $style servicelist has been found!" >> $logfile
            echo "TERMINATED: Read the log file!"
            exit 1
        fi
    done
fi

###########################################
## Cleanup binaries folder and re-create ##
###########################################
binaries=$location/build-output/binaries-$style
if [[ -d $binaries ]]; then rm -rf $binaries; fi
mkdir $binaries

##############################
## Determine version number ##
##############################
if [[ -d $location/.git ]] && which git &> /dev/null; then
    cd $location
    hash=$(git rev-parse --short HEAD)
    version=$(date --date=@$(git show -s --format=%ct $hash) +'%Y-%m-%d--%H-%M-%S')
    timestamp=$(date --date=@$(git show -s --format=%ct $hash) +'%Y%m%d%H%M.%S')
else
    epoch="date +%s"
    version=$(date --date=@$($epoch) +'%Y-%m-%d--%H-%M-%S')
    timestamp=$(date --date=@$($epoch) +'%Y%m%d%H%M.%S')
fi

echo "$(date +'%H:%M:%S') - Version: $version"

#############################################
## Some basic checking of the source files ##
#############################################
echo "$(date +'%H:%M:%S') - Checking index"
$location/resources/tools/check-index.sh $location/build-source srp
$location/resources/tools/check-index.sh $location/build-source snp

echo "$(date +'%H:%M:%S') - Checking logos"
$location/resources/tools/check-logos.sh $location/build-source/logos

#####################
## Create symlinks ##
#####################
echo "$(date +'%H:%M:%S') - Creating symlinks"
$location/resources/tools/create-symlinks.sh $location $temp $style

####################################################################
## Start the actual conversion to picons and creation of packages ##
####################################################################
logocollection=$(grep -v -e '^#' -e '^$' $temp/create-symlinks.sh | sed -e 's/^.*logos\///g' -e 's/.png.*$//g' | sort -u )
logocount=$(echo "$logocollection" | wc -l)
mkdir -p $temp/cache

if [[ -f $location/build-input/backgrounds.conf ]]; then
    backgroundsconf=$location/build-input/backgrounds.conf
else
    echo "$(date +'%H:%M:%S') - No \"backgrounds.conf\" file found in \"build-input\", using default file!"
    backgroundsconf=$location/build-source/config/backgrounds.conf
fi

grep -v -e '^#' -e '^$' $backgroundsconf | while read lines ; do
    currentlogo=""

    OLDIFS=$IFS
    IFS=";"
    line=($lines)
    IFS=$OLDIFS

    resolution=${line[0]}
    resize=${line[1]}
    type=${line[2]}
    background=${line[3]}

    packagenamenoversion=$style.$resolution-$resize.$type.on.$background
    packagename=$style.$resolution-$resize.$type.on.${background}_${version}

    mkdir -p $temp/package/picon/logos

    echo "$(date +'%H:%M:%S') -----------------------------------------------------------"
    echo "$(date +'%H:%M:%S') - Creating picons: $packagenamenoversion"

    echo "$logocollection" | while read logoname ; do
        ((currentlogo++))
        echo -ne "           Converting logo: $currentlogo/$logocount"\\r

        if [[ -f $location/build-source/logos/$logoname.$type.png ]] || [[ -f $location/build-source/logos/$logoname.$type.svg ]]; then
            logotype=$type
        else
            logotype=default
        fi

        echo $logoname.$logotype >> $logfile

        if [[ -f $location/build-source/logos/$logoname.$logotype.svg ]]; then
            logo=$temp/cache/$logoname.$logotype.png
            if [[ ! -f $logo ]]; then
                $svgconverter$logo $location/build-source/logos/$logoname.$logotype.svg 2>> $logfile >> $logfile
            fi
        else
            logo=$location/build-source/logos/$logoname.$logotype.png
        fi

        convert $location/build-source/backgrounds/$resolution/$background.png \( $logo -background none -bordercolor none -border 100 -trim -border 1% -resize $resize -gravity center -extent $resolution +repage \) -layers merge - 2>> $logfile | $pngquant - 2>> $logfile > $temp/package/picon/logos/$logoname.png
    done

    echo "$(date +'%H:%M:%S') - Creating binary packages: $packagenamenoversion"
    $temp/create-symlinks.sh
    find $temp/package -exec touch --no-dereference -t $timestamp {} \;

    if [[ $skipipk = "false" ]] && [[ $OSTYPE != "msys" ]]; then
        mkdir $temp/package/CONTROL ; cat > $temp/package/CONTROL/control <<-EOF
			Package: enigma2-plugin-picons-$packagenamenoversion
			Version: $version
			Section: base
			Architecture: all
			Maintainer: http://picons.eu
			Source: http://picons.eu
			Description: $packagenamenoversion
			OE: enigma2-plugin-picons-$packagenamenoversion
			HomePage: http://picons.eu
			License: unknown
			Priority: optional
		EOF
        touch --no-dereference -t $timestamp $temp/package/CONTROL/control
        $location/resources/tools/ipkg-build.sh -o root -g root $temp/package $binaries >> $logfile
    fi

    mv $temp/package/picon $temp/package/$packagename

    if [[ $OSTYPE != "msys" ]]; then
        tar --dereference --owner=root --group=root -cf - --directory=$temp/package $packagename --exclude=logos | $compressor 2>> $logfile > $binaries/$packagename.hardlink.tar.$ext
        tar --owner=root --group=root -cf - --directory=$temp/package $packagename | $compressor 2>> $logfile > $binaries/$packagename.symlink.tar.$ext
    else
        tar --dereference --owner=root --group=root -cf - --directory=$temp/package $packagename --exclude=logos | $compressor 2>> $logfile > $binaries/$packagename.nolink.tar.$ext
        rm -rf $temp/package/$packagename/*.png
        sed -e "s|$temp/package/picon/||g" $temp/create-symlinks.sh > $temp/package/$packagename/create-symlinks.sh
        chmod 755 $temp/package/$packagename/create-symlinks.sh
        tar --owner=root --group=root -cf - --directory=$temp/package $packagename | $compressor 2>> $logfile > $binaries/$packagename.script.tar.$ext
    fi

    find $binaries -exec touch -t $timestamp {} \;
    rm -rf $temp/package
done

######################################
## Cleanup temporary files and exit ##
######################################
if [[ -d $temp ]]; then rm -rf $temp; fi

echo "$(date +'%H:%M:%S') - FINISHED!"
exit 0
