#!/bin/sh

ORIGINAL_DIR=$PWD
ADDON_DIR=$(dirname "$(readlink -f $0/..)")

cd /tmp
cp -R "$ADDON_DIR" /tmp/
find epgp -type d -name ".svn" | xargs rm -rf
rm -rf epgp/scripts
zip -r "$ORIGINAL_DIR"/epgp.zip epgp
rm -rf /tmp/epgp
