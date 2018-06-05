#!/bin/bash

source_location=$1
style=$2

sed -e 's/^.*=//g' $source_location/$style.index | sort -u | while read line ; do
    if [[ ! -f $source_location/logos/$line.default.png ]] && [[ ! -f $source_location/logos/$line.default.svg ]]; then
        echo The following logo does not exist: $line, found in $style.index
    fi
done
