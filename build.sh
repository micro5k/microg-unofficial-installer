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

# Detect OS
UNAME=$(uname)
if [[ "$UNAME" == 'Linux' ]]; then
  PLATFORM='linux'
elif [[ "$UNAME" == 'Windows_NT' ]]; then
  PLATFORM='win'
#elif [[ "$UNAME" == 'Darwin' ]]; then
  #PLATFORM='macos'
#elif [[ "$UNAME" == 'FreeBSD' ]]; then
  #PLATFORM='freebsd'
else
  ui_error 'Unsupported OS'
fi

# Create the output dir
OUT_DIR="$BASEDIR/output"
mkdir -p "$OUT_DIR" || ui_error 'Failed to create the output dir'

# Create the temp dir
TEMP_DIR=$(mktemp -d -t ZIPBUILDER-XXXXXX)

# Set filename and version
FILENAME='microG-unofficial-installer-ale5000'
VER=$(cat "$BASEDIR/sources/inc/VERSION")

# Download Play Store if missing
if [[ ! -e "$BASEDIR/sources/files/priv-app/Phonesky.apk" ]]; then
  wget -O "$BASEDIR/sources/files/priv-app/Phonesky.apk" -U 'Mozilla/5.0 (X11; Linux x86_64; rv:54.0) Gecko/20100101 Firefox/54.0' 'http://www.apkmirror.com/wp-content/themes/APKMirror/download.php?id=2911' || ui_error 'Failed to download Play Store'
  echo ''
fi

# Copy data
cp -rf "$BASEDIR/sources" "$TEMP_DIR/" || ui_error 'Failed to copy data to the temp dir'
cp -rf "$BASEDIR/"LICENSE* "$TEMP_DIR/sources/" || ui_error 'Failed to copy license to the temp dir'

# Remove the previous file
rm -f "$OUT_DIR/$FILENAME-v$VER-signed.zip" || ui_error 'Failed to remove the previous zip file'

# Compress and sign
cd "$TEMP_DIR/sources" || ui_error 'Failed to change folder'
zip -r9X "$TEMP_DIR/zip-1.zip" * || ui_error 'Failed compressing'
echo ''
java -jar "$BASEDIR/tools/signapk.jar" "$BASEDIR/certs"/*.x509.pem "$BASEDIR/certs"/*.pk8 "$TEMP_DIR/zip-1.zip" "$TEMP_DIR/zip-2.zip" || ui_error 'Failed signing'
"$BASEDIR/tools/$PLATFORM/zipadjust" "$TEMP_DIR/zip-2.zip" "$TEMP_DIR/zip-3.zip" || ui_error 'Failed zipadjusting'
java -jar "$BASEDIR/tools/minsignapk.jar" "$BASEDIR/certs"/*.x509.pem "$BASEDIR/certs"/*.pk8 "$TEMP_DIR/zip-3.zip" "$TEMP_DIR/zip-4.zip" || ui_error 'Failed minsigning'
cd "$OUT_DIR"

cp -f "$TEMP_DIR/zip-4.zip" "$OUT_DIR/$FILENAME-v$VER-signed.zip" || ui_error 'Failed to copy the final file'

# Cleanup remnants
rm -rf "$TEMP_DIR" || ui_error 'Failed to cleanup'

echo ''
echo 'Done.'
