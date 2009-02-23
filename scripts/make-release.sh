#!/bin/bash

function Confirm() {
  local text=$1
  local reply
  while [ 1 = 1 ]; do
    echo -n $text " (y/N) "
    read reply
    case "$reply" in
      "y"|"Y") return 0;;
      "n"|"N"|"") return 1;;
    esac
  done
  return 1
}

if [ ! $# == 1 ]; then
  echo "Usage: $0 <release_version>"
  exit 1
fi

if [ ! -f epgp.toc ]; then
  echo "You must run this script from the root of the epgp directory!"
  exit 1
fi

STAGE_DIR=$TMPDIR/epgp
RELEASE_ZIP=$TMPDIR/epgp-$1.zip

# Stage the addon
rm -rf $STAGE_DIR $RELEASE_ZIP
mkdir -p $STAGE_DIR
find . \
    \( \
    -name '*.lua' -or \
    -name '*.xml' -or \
    -name 'epgp.toc' -or \
    -regex './[A-Z]*' \
    \) -and \
    \( \
    -type f -and \
    -not -path './scripts**' \
    \) | \
    tar --create --file=- --files-from=- | \
    ( cd $STAGE_DIR && tar --extract --file=- )
# Add the version in the .toc file
pushd $STAGE_DIR
mv epgp.toc epgp.toc.templ
sed -e"s/Version:.*/Version: $1/" epgp.toc.templ > epgp.toc
rm epgp.toc.templ
popd

# Make the release zip
pushd $STAGE_DIR/..
zip -r $RELEASE_ZIP epgp
popd

# Tag the release
if Confirm "Do you want to import this release to the repository?"; then
  command="svn import $STAGE_DIR https://epgp.googlecode.com/svn/tags/epgp-$1"
  echo "Running: $command"
  $command
fi

# Upload the release
if Confirm "Do you want to upload the archive?"; then
  command="$PWD/scripts/googlecode/googlecode_upload.py -s epgp-$1 -p epgp -u evlogimenos -l Featured $RELEASE_ZIP"
  echo "Running: $command"
  $command
fi
