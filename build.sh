#!/usr/bin/env bash

ui_error()
{
  >&2 echo "ERROR: $1"
  test -n "$2" && exit "$2"
  exit 1
}

BASEDIR=$(dirname "$0")
if [[ "${BASEDIR:0:1}" != '/' ]]; then
  if [[ "$BASEDIR" == '.' ]]; then BASEDIR=''; else BASEDIR="/$BASEDIR"; fi
  CURDIR=$(pwd)
  if [[ "$CURDIR" != '/' ]]; then BASEDIR="$CURDIR$BASEDIR"; fi
fi

FILENAME='microG-unofficial-installer-ale5000'
VER=$(cat "$BASEDIR/sources/inc/VERSION")

# Create the output dir
OUT_DIR="$BASEDIR/output"
mkdir -p "$OUT_DIR" || ui_error "Failed to create the output dir"

# Remove previous file
rm -f "$OUT_DIR/$FILENAME-v$VER.zip" || ui_error "Failed to remove the previous zip file"

# Copy license
cp -rpf "$BASEDIR/"LICENSE* "$BASEDIR/sources" || ui_error "Failed to copy license"

cd "$BASEDIR/sources" || ui_error "Failed to change folder"
zip -r9X "$OUT_DIR/$FILENAME-v$VER.zip" * || ui_error "Failed compression"

# Cleanup remnants
rm -f "$BASEDIR/sources/"LICENSE* || ui_error "Failed to cleanup"
