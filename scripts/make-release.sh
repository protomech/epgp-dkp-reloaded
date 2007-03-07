#!/bin/sh

if [ ! $# == 1 ]; then
  echo "Usage: $0 <release_version>"
  exit 1
fi

if [ ! -f epgp.toc ]; then
  echo "You must run this script from the root of the epgp directory!"
  exit 1
fi

EPGP_DIR=$PWD
RELEASE_ZIP="$EPGP_DIR/epgp-$1.zip"

pushd ..
zip -r "$RELEASE_ZIP" epgp -x \*/.svn/\* -x \*/scripts/\* -x \*/wiki/\* -x \*~
popd

unzip "$RELEASE_ZIP"

pushd epgp
sed -itmp -e"s/@VERSION@/$1/" epgp.toc
popd

zip -u -r "$RELEASE_ZIP" epgp/epgp.toc

cat <<INFO
=============================================================================
The release file is located at:
$RELEASE_ZIP

Tag this release in svn:
svn import \"$EPGP_DIR/epgp\" https://epgp.googlecode.com/svn/tags/epgp-$1

Upload release file to googlecode:
"$EPGP_DIR/scripts/googlecode/googlecode-upload.py" -s "epgp-$1" -p epgp -u evlogimenos "$RELEASE_ZIP"
=============================================================================
INFO
