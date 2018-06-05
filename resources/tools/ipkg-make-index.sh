#!/bin/bash

set -e

pkg_dir=$1

if [[ -z $pkg_dir ]] || [[ ! -d $pkg_dir ]]; then
    echo "Usage: ipkg-make-index <package_directory>" >&2
    exit 1
fi

touch $pkg_dir/Packages

for pkg in $(find $pkg_dir -name '*.ipk' | sort); do
    echo "Generating index for package $pkg" >&2
    file_size=$(ls -l --dereference $pkg | awk '{print $5}')
    md5sum=$(md5sum $pkg | awk '{print $1}')
    pkg_name=$(basename $pkg)
    ar p $pkg control.tar.gz | tar -xzOf- './control' | sed -e "s/^Description:/Filename: $pkg_name\\
Size: $file_size\\
MD5Sum: $md5sum\\
Description:/" >> $pkg_dir/Packages
    echo "" >> $pkg_dir/Packages
done

gzip -c $pkg_dir/Packages > $pkg_dir/Packages.gz
