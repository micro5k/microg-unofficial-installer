#!/usr/bin/env bash

<<LICENSE
  Copyright (C) 2017-2018  ale5000
  This file was created by ale5000 (ale5000-git on GitHub).

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version, w/ zip exception.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
LICENSE

ui_error()
{
  >&2 echo "ERROR: $1"
  test -n "$2" && exit "$2"
  exit 1
}

# Detect OS and set OS specific info
SEP='/'
PATHSEP=':'
UNAME=$(uname)
if [[ "$UNAME" == 'Linux' ]]; then
  PLATFORM='linux'
elif [[ "$UNAME" == 'Windows_NT' ]]; then
  PLATFORM='win'
  SEP='\'
  PATHSEP=';'
#elif [[ "$UNAME" == 'Darwin' ]]; then
  #PLATFORM='macos'
#elif [[ "$UNAME" == 'FreeBSD' ]]; then
  #PLATFORM='freebsd'
else
  ui_error 'Unsupported OS'
fi

# Detect script dir (with absolute path)
CURDIR=$(pwd)
BASEDIR=$(dirname "$0")
if [[ "${BASEDIR:0:1}" == '/' ]] || [[ "$PLATFORM" == 'win' && "${BASEDIR:1:1}" == ':' ]]; then
  :  # If already absolute leave it as is
else
  if [[ "$BASEDIR" == '.' ]]; then BASEDIR=''; else BASEDIR="/$BASEDIR"; fi
  if [[ "$CURDIR" != '/' ]]; then BASEDIR="$CURDIR$BASEDIR"; fi
fi
WGET_CMD='wget'
TOOLS_DIR="${BASEDIR}${SEP}tools${SEP}${PLATFORM}"
PATH="${TOOLS_DIR}${PATHSEP}${PATH}"

verify_sha1()
{
  local file_name="$1"
  local hash="$2"
  local file_hash=$(sha1sum "$file_name" | cut -d ' ' -f 1)

  if [[ $hash != "$file_hash" ]]; then return 1; fi  # Failed
  return 0  # Success
}

corrupted_file()
{
  rm -f "$1" || echo 'Failed to remove the corrupted file.'
  ui_error "The file '$1' is corrupted."
}

dl_file()
{
  if [[ ! -e "$3/$2/$1" ]]; then
    mkdir -p "$3/$2"
    "$WGET_CMD" -O "$3/$2/$1" -U 'Mozilla/5.0 (X11; Linux x86_64; rv:56.0) Gecko/20100101 Firefox/56.0' "$4" || ui_error "Failed to download the file '$2/$1'."
    echo ''
  fi
  verify_sha1 "$3/$2/$1" "$5" || corrupted_file "$3/$2/$1"
}

. "$BASEDIR/conf.sh"

# Check dependencies
which 'zip' || ui_error 'zip command is missing'

# Create the output dir
OUT_DIR="$BASEDIR/output"
mkdir -p "$OUT_DIR" || ui_error 'Failed to create the output dir'

# Create the temp dir
TEMP_DIR=$(mktemp -d -t ZIPBUILDER-XXXXXX)

# Set filename and version
VER=$(cat "$BASEDIR/zip-content/inc/VERSION")
FILENAME="$NAME-v$VER-signed"

. "$BASEDIR/addition.sh"

# Download files if they are missing
dl_file 'PlayStore-recent.apk' 'zip-content/files/variants' "$BASEDIR" 'https://www.apkmirror.com/wp-content/themes/APKMirror/download.php?id=137220' '6c60fa863dd7befef49082c0dcf6278947a09333'
dl_file 'PlayStore-legacy.apk' 'zip-content/files/variants' "$BASEDIR" 'https://www.apkmirror.com/wp-content/themes/APKMirror/download.php?id=2911' 'd78b377db43a2bc0570f37b2dd0efa4ec0b95746'

dl_file 'keycheck-arm' 'zip-content/misc/keycheck' "$BASEDIR" 'https://github.com/someone755/kerneller/raw/9bb15ca2e73e8b81e412d595b52a176bdeb7c70a/extract/tools/keycheck' '77d47e9fb79bf4403fddab0130f0b4237f6acdf0'

# Copy data
cp -rf "$BASEDIR/zip-content" "$TEMP_DIR/" || ui_error 'Failed to copy data to the temp dir'
cp -rf "$BASEDIR/"LICENSE* "$TEMP_DIR/zip-content/" || ui_error 'Failed to copy license to the temp dir'

# Remove the previous file
rm -f "$OUT_DIR/$FILENAME.zip" || ui_error 'Failed to remove the previous zip file'

### IMPORTANT: Keep using 'zip' for compression since 'zipadjust' isn't compatible with zip archives created by '7za' and it will corrupt them

# Compress and sign
cd "$TEMP_DIR/zip-content" || ui_error 'Failed to change folder'
zip -r9X "$TEMP_DIR/zip-1.zip" * || ui_error 'Failed compressing'
echo ''
java -jar "$BASEDIR/tools/signapk.jar" "$BASEDIR/certs"/*.x509.pem "$BASEDIR/certs"/*.pk8 "$TEMP_DIR/zip-1.zip" "$TEMP_DIR/zip-2.zip" || ui_error 'Failed signing'
"$BASEDIR/tools/$PLATFORM/zipadjust" "$TEMP_DIR/zip-2.zip" "$TEMP_DIR/zip-3.zip" || ui_error 'Failed zipadjusting'
java -jar "$BASEDIR/tools/minsignapk.jar" "$BASEDIR/certs"/*.x509.pem "$BASEDIR/certs"/*.pk8 "$TEMP_DIR/zip-3.zip" "$TEMP_DIR/zip-4.zip" || ui_error 'Failed minsigning'
cd "$OUT_DIR"

cp -f "$TEMP_DIR/zip-4.zip" "$OUT_DIR/$FILENAME.zip" || ui_error 'Failed to copy the final file'

# Cleanup remnants
rm -rf "$TEMP_DIR" || ui_error 'Failed to cleanup'

echo ''
echo 'Done.'
