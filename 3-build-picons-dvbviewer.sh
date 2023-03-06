
#!/bin/bash

#####################
## Setup locations ##
#####################
location=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
temp=$(mktemp -d --suffix=.picons)
logfile=$(mktemp --suffix=.picons.log)

echo "$(date +'%H:%M:%S') - INFO: Log file located at: $logfile"

###########################
## Check path for spaces ##
###########################
if [[ $location == *" "* ]]; then
    echo "$(date +'%H:%M:%S') - ERROR: The path contains spaces, please move the repository to a path without spaces!"
    exit 1
fi

########################################################
## Search for required commands and exit if not found ##
########################################################
commands=( zip sed grep tr cat sort find mkdir rm cp mv ln readlink cut awk )
for i in ${commands[@]}; do
    if ! which $i &> /dev/null; then
        missingcommands="$i $missingcommands"
    fi
done
if [[ -z $missingcommands ]]; then
    echo "$(date +'%H:%M:%S') - INFO: All required commands are found!"
else
    echo "$(date +'%H:%M:%S') - ERROR: The following commands are not found: $missingcommands"
    exit 1
fi

if which pngquant &> /dev/null; then
    pngquant="pngquant --skip-if-larger --speed 1 --strip --quality 60-100 --transbug"
    echo "$(date +'%H:%M:%S') - INFO: Image compression enabled!"
else
    pngquant="cat"
    echo "$(date +'%H:%M:%S') - WARNING: Image compression disabled! Try installing: pngquant"
fi
if which optipng &> /dev/null; then
    optipng="optipng"
    echo "$(date +'%H:%M:%S') - INFO: Image compression enabled!"
else
    optipng="cat"
    echo "$(date +'%H:%M:%S') - WARNING: Image compression disabled! Try installing: optipng"
fi

if which convert &> /dev/null; then
    echo "$(date +'%H:%M:%S') - INFO: ImageMagick was found!"
else
    echo "$(date +'%H:%M:%S') - ERROR: ImageMagick was not found! Try installing: imagemagick"
    exit 1
fi

if [[ -f $location/build-input/svgconverter.conf ]]; then
    svgconverterconf=$location/build-input/svgconverter.conf
else
    echo "$(date +'%H:%M:%S') - WARNING: No \"svgconverter.conf\" file found in \"build-input\", using default file!"
    svgconverterconf=$location/build-source/config/svgconverter.conf
fi
if which inkscape &> /dev/null && [[ $(grep -v -e '^#' -e '^$' $svgconverterconf) = "inkscape" ]]; then
    svgconverter="inkscape --without-gui --export-area-drawing --export-png=-"
    echo "$(date +'%H:%M:%S') - INFO: Using inkscape as svg converter!"
elif which rsvg-convert &> /dev/null && [[ $(grep -v -e '^#' -e '^$' $svgconverterconf) = "rsvg" ]]; then
    svgconverter="rsvg-convert -a -f png "
    echo "$(date +'%H:%M:%S') - INFO: Using rsvg as svg converter!"
else
    echo "$(date +'%H:%M:%S') - ERROR: SVG converter: $(grep -v -e '^#' -e '^$' $svgconverterconf), was not found!"
    exit 1
fi

###########################################
## Cleanup binaries folder and re-create ##
###########################################
binaries=$location/build-output/archives-dvbviewer
if [[ -d $binaries ]]; then rm -rf $binaries; fi
mkdir $binaries

##############################
## Determine version number ##
##############################
if [[ -d $location/.git ]] && which git &> /dev/null; then
    cd $location
    hash=$(git rev-parse --short HEAD)
    version=$(date --utc --date=@$(git show -s --format=%ct $hash) +'%Y-%m-%d--%H-%M-%S')
    timestamp=$(date --utc --date=@$(git show -s --format=%ct $hash) +'%Y%m%d%H%M.%S')
else
    epoch="date --utc +%s"
    version=$(date --utc --date=@$($epoch) +'%Y-%m-%d--%H-%M-%S')
    timestamp=$(date --utc --date=@$($epoch) +'%Y%m%d%H%M.%S')
fi

echo "$(date +'%H:%M:%S') - INFO: Version: $version"

#############################################
## Some basic checking of the source files ##
#############################################
if [[ $- == *i* ]]; then
    echo "$(date +'%H:%M:%S') - EXECUTING: Checking index"
    $location/resources/tools/check-index.sh $location/build-source srp
    $location/resources/tools/check-index.sh $location/build-source snp

    echo "$(date +'%H:%M:%S') - EXECUTING: Checking logos"
    $location/resources/tools/check-logos.sh $location/build-source/logos
fi

style="snp-full"

#####################
## Create symlinks ##
#####################
echo "$(date +'%H:%M:%S') - EXECUTING: Creating symlinks"
$location/resources/tools/create-symlinks-dvbviewer.sh $location $temp $style

####################################################################
## Start the actual conversion to picons and creation of packages ##
####################################################################
logocollection=$(grep -v -e '^#' -e '^$' $temp/create-symlinks-dvbviewer.sh | sed -e 's/^.*logos\///g' -e 's/.png.*$//g' | sort -u )
logocount=$(echo "$logocollection" | wc -l)
mkdir -p $temp/cache

if [[ -f $location/build-input/backgrounds.conf ]]; then
    backgroundsconf=$location/build-input/backgrounds.conf
else
    echo "$(date +'%H:%M:%S') - WARNING: No \"backgrounds.conf\" file found in \"build-input\", using default file!"
    backgroundsconf=$location/build-source/config/backgrounds.conf
fi

scaleimage(){
    ((currentlogo++))
    if [[ $- == *i* ]]; then
        echo "           Converting logo: $currentlogo/$logocount"\\r
    fi

    if [[ -f $location/build-source/logos/$logoname.$type.png ]] || [[ -f $location/build-source/logos/$logoname.$type.svg ]]; then
        logotype=$type
    else
        logotype=default
    fi

    echo $logoname.$logotype >> $logfile

    targetwidth=$(echo $resize | cut -f1 -d "x")
    targetheight=$(echo $resize | cut -f2 -d "x")
    if [[ -f $location/build-source/logos/$logoname.$logotype.svg ]]; then
        logo=$location/build-source/logos/$logoname.$logotype.svg
        sourcesize=$($svgconverter -w 1000 $logo 2>> $logfile | identify -format '%wx%h' -)
        sourcewidth=$(echo $sourcesize | cut -f1 -d "x")
        sourceheight=$(echo $sourcesize | cut -f2 -d "x")
        sourceaspectratio=$(echo "$sourcewidth $sourceheight" | awk '{print $1 / $2}')
        targetaspectratio=$(echo "$targetwidth $targetheight" | awk '{print $1 / $2}')
        if [[ $(echo $sourceaspectratio $targetaspectratio | awk '{if ($1 > $2) print $1; else print $2}') = $sourceaspectratio ]]; then
            scaleaxis=" -w $targetwidth"
        else
            scaleaxis=" -h $targetheight"
        fi
        if [[ $shadow != "" ]]; then
            $svgconverter$scaleaxis $logo 2>> $logfile | convert png:- -background none -gravity center -extent $resolution +repage \( +clone -background none -shadow $shadow \) -compose DstOver -layers flatten +repage - 2>> $logfile | $pngquant - 2>> $logfile > $temp/package/picon/logos/$logoname.png
        else
            $svgconverter$scaleaxis $logo 2>> $logfile | convert png:- -background none -gravity center -extent $resolution +repage - 2>> $logfile | $pngquant - 2>> $logfile > $temp/package/picon/logos/$logoname.png
        fi
    else
        logo=$location/build-source/logos/$logoname.$logotype.png
        #resize2=$(echo "$targetwidth $targetheight" | awk '{ x=$1*1.5; y=$2*1.5; printf("%.0fx%.0f", x, y) }')
        #resize3=$(echo "$targetwidth $targetheight" | awk '{ x=$1/1.5; y=$2/1.5; printf("%.0fx%.0f", x, y) }')
        #convert $logo -colorspace RGB -density 384 -background none -resize $resize2\> -resize $resize3\< -adaptive-resize $resize -colorspace sRGB -gravity center -extent $resolution +repage \( +clone -background none $shadow \) -compose DstOver -layers flatten +repage - 2>> $logfile | $pngquant - 2>> $logfile > $temp/package/picon/logos/$logoname.png
        if [[ $shadow != "" ]]; then
            convert $logo -colorspace RGB -density 384 -background none -resize $resize -colorspace sRGB -gravity center -extent $resolution +repage \( +clone -background none -shadow $shadow \) -compose DstOver -layers flatten +repage - 2>> $logfile | $pngquant - 2>> $logfile > $temp/package/picon/logos/$logoname.png
        else
            convert $logo -colorspace RGB -density 384 -background none -resize $resize -colorspace sRGB -gravity center -extent $resolution +repage - 2>> $logfile | $pngquant - 2>> $logfile > $temp/package/picon/logos/$logoname.png
        fi
    fi
    $optipng $temp/package/picon/logos/$logoname.png 2>> $logfile
}

grep -v -e '^#' -e '^$' $backgroundsconf | while read lines ; do
    currentlogo=""

    OLDIFS=$IFS
    IFS=";"
    line=($lines)
    IFS=$OLDIFS

    resolution=${line[0]}
    resize=${line[1]}
    shadow=${line[4]}

    packagenamenoversion=$style.$resolution.${line[4]}
    packagename=$style.$resolution.${line[4]}_${version}

    mkdir -p $temp/package/picon/logos

    echo "$(date +'%H:%M:%S') - EXECUTING: Creating picons: $packagenamenoversion"

    echo "$logocollection" | while read logoname ; do
        $(scaleimage) &
        # At most as number of CPU cores
        [ $( jobs | wc -l ) -ge $( nproc ) ] && wait
    done
    wait

    echo "$(date +'%H:%M:%S') - EXECUTING: Creating archives: $packagenamenoversion"
    $temp/create-symlinks-dvbviewer.sh
    find $temp/package -exec touch --no-dereference -t $timestamp {} \;

    zip $binaries/$packagename.zip $temp/package/picon/* --junk-paths >> $logfile

    find $binaries -exec touch -t $timestamp {} \;
    rm -rf $temp/package
done

######################################
## Cleanup temporary files and exit ##
######################################
#if [[ -d $temp ]]; then rm -rf $temp; fi

echo "$(date +'%H:%M:%S') - INFO: Finished building!"
exit 0
