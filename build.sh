#!/usr/bin/env bash

<<LICENSE
    Copyright (C) 2017  ale5000
    This file is part of microG unofficial installer by @ale5000.

    microG unofficial installer is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version, w/microG unofficial installer zip exception.

    microG unofficial installer is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with microG unofficial installer.  If not, see <http://www.gnu.org/licenses/>.
LICENSE

ui_error()
{
  >&2 echo "ERROR: $1"
  test -n "$2" && exit "$2"
  exit 1
}

# Detect script dir
BASEDIR=$(dirname "$0")
if [[ "${BASEDIR:0:1}" != '/' ]]; then
  if [[ "$BASEDIR" == '.' ]]; then BASEDIR=''; else BASEDIR="/$BASEDIR"; fi
  CURDIR=$(pwd)
  if [[ "$CURDIR" != '/' ]]; then BASEDIR="$CURDIR$BASEDIR"; fi
fi

# Create the output dir
OUT_DIR="$BASEDIR/output"
mkdir -p "$OUT_DIR" || ui_error 'Failed to create the output dir'

# Create the temp dir
TEMP_DIR=$(mktemp -d -t ZIPBUILDER-XXXXXX)

# Set filename and version
FILENAME='microG-unofficial-installer-ale5000'
VER=$(cat "$BASEDIR/sources/inc/VERSION")

# Copy data
cp -rf "$BASEDIR/sources" "$TEMP_DIR/" || ui_error 'Failed to copy data to the temp dir'
cp -rf "$BASEDIR/"LICENSE* "$TEMP_DIR/sources/" || ui_error 'Failed to copy license to the temp dir'

# Remove previous file
rm -f "$OUT_DIR/$FILENAME-v$VER.zip" || ui_error 'Failed to remove the previous zip file'

# Compress
cd "$TEMP_DIR/sources" || ui_error 'Failed to change folder'
zip -r9X "$OUT_DIR/$FILENAME-v$VER.zip" * || ui_error 'Failed compression'
cd "$OUT_DIR"

# Cleanup remnants
rm -rf "$TEMP_DIR" || ui_error 'Failed to cleanup'
