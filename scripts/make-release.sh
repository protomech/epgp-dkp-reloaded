#!/bin/sh

if [ ! $# == 1 ]; then
  echo "Usage: $0 <release_version>"
  exit 1
fi

ORIGINAL_DIR=$PWD
SCRIPT_NAME=$(readlink -f $0)

echo "Script: $SCRIPT_NAME"

ADDON_DIR=$(dirname $(dirname $SCRIPT_NAME))

echo "Addon directory: $ADDON_DIR"

cd /tmp
cp -R "$ADDON_DIR" /tmp/
find epgp -type d -name ".svn" | xargs rm -rf
rm -rf epgp/scripts
zip -r "$ORIGINAL_DIR"/epgp-$1.zip epgp
rm -rf /tmp/epgp
