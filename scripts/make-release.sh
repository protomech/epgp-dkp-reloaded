#!/bin/sh

if [ ! $# == 1 ]; then
  echo "Usage: $0 <release_version>"
  exit 1
fi

if [ ! -f epgp.toc ]; then
  echo "You must run this script from the root of the epgp directory!"
  exit 1
fi

RELEASE_ZIP="$HOME/Desktop/epgp-$1.zip"

cd ..
zip -r "$RELEASE_ZIP" epgp -x \*/.svn/\* -x \*/scripts/\*

echo "Release file at $RELEASE_ZIP"
