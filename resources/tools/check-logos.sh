#!/bin/bash

cd $1

for file in * ; do
    if [[ ! -f ${file%.*.*}.default.png ]] && [[ ! -f ${file%.*.*}.default.svg ]]; then
        echo The following logo has no default version: $file
    fi
    
    if [[ $file == *.svg && ( -f ${file%.*.*}.default.png || -f ${file%.*.*}.light.png || -f ${file%.*.*}.dark.png || -f ${file%.*.*}.black.png || -f ${file%.*.*}.white.png ) ]]; then
        echo The following logo is an svg, but has one or more png alternatives: $file
    fi
    
    if [[ $file == *.svg ]]; then
        if grep -q -e "</text>" -e "data:image/png" $file; then
            echo This svg contains text or a png image: $file
        fi
    fi
done
