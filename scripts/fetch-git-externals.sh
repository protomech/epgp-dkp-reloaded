#!/bin/sh
#
# Usage: fetch-git-externals.sh OUTPUTDIR < repo-list

set -e

[ ! -d $1 ] && mkdir $1
cd $1

while read dirname gitrepo; do
    if [ -n "$dirname" -a -n "$gitrepo" ]; then
	rm -rf tmp-git-repo && mkdir tmp-git-repo
	git clone $gitrepo tmp-git-repo/$dirname
	rm -rf $dirname && mkdir $dirname
	cd tmp-git-repo/$dirname
	git archive master > ../../$dirname.tar.gz
	cd ../../$dirname
	tar xfv ../$dirname.tar.gz
	cd ..
	rm -rf tmp-git-repo $dirname.tar.gz
    fi
done