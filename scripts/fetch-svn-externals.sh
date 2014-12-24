#!/bin/sh
#
# Usage: fetch-svn-externals.sh OUTPUTDIR < repo-list

set -e

[ ! -d $1 ] && mkdir $1
cd $1

while read dirname svnpath; do
    if [ -n "$dirname" -a -n "$svnpath" ]; then
	rm -rf $dirname && svn export $svnpath $dirname
    fi
done