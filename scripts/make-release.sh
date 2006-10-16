#!/bin/sh

if [ ! $# == 1 ]; then
  echo "Usage: $0 <release_version>"
  exit 1
fi

ORIGINAL_DIR=$PWD
ADDON_DIR=$(dirname "$(readlink -f $0/..)")

cd /tmp
cp -R "$ADDON_DIR" /tmp/
find epgp -type d -name ".svn" | xargs rm -rf
rm -rf epgp/scripts
zip -r "$ORIGINAL_DIR"/epgp-$1.zip epgp
rm -rf /tmp/epgp
