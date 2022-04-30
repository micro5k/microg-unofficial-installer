#!/usr/bin/env bash
# shellcheck disable=SC3043
last_command="${_}"  # IMPORTANT: This line must be at the start of the script before any other command otherwise it will not work

cat <<'LICENSE'
  SPDX-FileCopyrightText: (c) 2016-2019, 2021-2022 ale5000
  SPDX-License-Identifier: GPL-3.0-or-later
  SPDX-FileType: SOURCE

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
echo ''

detect_script_dir()
{
  local this_script

  # shellcheck disable=SC3028,SC2128
  if test "${#BASH_SOURCE}" -ge 1; then this_script="${BASH_SOURCE}"  # Expanding an array without an index gives the first element (it is intended)
  else
    local current_shell
    # shellcheck disable=SC2009
    current_shell="$(ps -o 'pid,comm' | grep -Fw "$$" | while IFS=' ' read -r _ current_shell; do echo "${current_shell}"; done || true)"

    if test -n "$0" && test -n "${current_shell}" && test "$0" != "${current_shell}" && test "$0" != "-${current_shell}"; then this_script="$0"
    elif test -n "${last_command}"; then this_script="${last_command}"
    else echo 'ERROR: The script filename cannot be found'; return 1; fi
  fi
  unset last_command

  this_script="$(realpath "${this_script}" 2>&-)" || return 1
  SCRIPT_DIR="$(dirname "${this_script}")" || return 1
}
detect_script_dir || return 1 2>&- || exit 1

# shellcheck disable=SC2154
if test -z "${CI}"; then printf '\033]0;%s\007' 'Building the flashable OTA zip...' && printf '\r                                             \r'; fi

# shellcheck source=SCRIPTDIR/scripts/common.sh
if test "${A5K_FUNCTIONS_INCLUDED:-false}" = 'false'; then . "${SCRIPT_DIR}/scripts/common.sh"; fi
# shellcheck source=SCRIPTDIR/conf.sh
. "${SCRIPT_DIR}/conf.sh"

# Check dependencies
hash 'zip' 2>&- || ui_error 'Zip is missing'
hash 'java' 2>&- || ui_error 'Java is missing'

# Create the output dir
OUT_DIR="${SCRIPT_DIR}/output"
mkdir -p "${OUT_DIR}" || ui_error 'Failed to create the output dir'

# Create the temp dir
TEMP_DIR="$(mktemp -d -t ZIPBUILDER-XXXXXX)" || ui_error 'Failed to create our temp dir'
if test -z "${TEMP_DIR}"; then ui_error 'Failed to create our temp dir'; fi

# Empty our temp dir (should be already empty, but we must be sure)
rm -rf "${TEMP_DIR:?}"/* || ui_error 'Failed to empty our temp dir'

# Set filename and version
VER="$(simple_get_prop 'version' "${SCRIPT_DIR:?}/zip-content/module.prop")" || ui_error 'Failed to parse the version string'
AUTHOR="$(simple_get_prop 'author' "${SCRIPT_DIR:?}/zip-content/module.prop")" || ui_error 'Failed to parse the author string'
FILENAME="${NAME:?}-${VER:?}-by-${AUTHOR:?}"
# shellcheck disable=SC2154
if test -n "${OPENSOURCE_ONLY}"; then FILENAME="${FILENAME:?}-OSS"; fi

# shellcheck source=SCRIPTDIR/addition.sh
. "${SCRIPT_DIR}/addition.sh"

# Download files if they are missing
mkdir -p "${SCRIPT_DIR}/cache"

oss_files_to_download | while IFS='|' read -r LOCAL_FILENAME LOCAL_PATH DL_HASH DL_URL DL_MIRROR _; do
  dl_file "${LOCAL_PATH}" "${LOCAL_FILENAME}" "${DL_HASH}" "${DL_URL}" "${DL_MIRROR}"
done
STATUS="$?"; if test "${STATUS}" -ne 0; then return "${STATUS}" 2>&- || exit "${STATUS}"; fi

if test -z "${OPENSOURCE_ONLY}"; then
  files_to_download | while IFS='|' read -r LOCAL_FILENAME LOCAL_PATH DL_HASH DL_URL DL_MIRROR _; do
    dl_file "${LOCAL_PATH}" "${LOCAL_FILENAME}" "${DL_HASH}" "${DL_URL}" "${DL_MIRROR}"
  done
  STATUS="$?"; if test "${STATUS}" -ne 0; then return "${STATUS}" 2>&- || exit "${STATUS}"; fi

  dl_file 'misc/keycheck' 'keycheck-arm' '77d47e9fb79bf4403fddab0130f0b4237f6acdf0' 'https://github.com/someone755/kerneller/raw/9bb15ca2e73e8b81e412d595b52a176bdeb7c70a/extract/tools/keycheck' ''
else
  echo 'Skipped not OSS files!'
fi

# Copy data
cp -rf "${SCRIPT_DIR}/zip-content" "${TEMP_DIR}/" || ui_error 'Failed to copy data to the temp dir'
cp -rf "${SCRIPT_DIR}/"LICENSES* "${TEMP_DIR}/zip-content/" || ui_error 'Failed to copy the licenses folder to the temp dir'
cp -f "${SCRIPT_DIR}/LICENSE.rst" "${TEMP_DIR}/zip-content/" || ui_error 'Failed to copy the license to the temp dir'
cp -f "${SCRIPT_DIR}/LIC-ADDITION.rst" "${TEMP_DIR}/zip-content/" || ui_error 'Failed to copy the license to the temp dir'
cp -f "${SCRIPT_DIR}/CHANGELOG.rst" "${TEMP_DIR}/zip-content/" || ui_error 'Failed to copy the changelog to the temp dir'

# Do not ship currently unused binaries and unused files
rm -rf "${TEMP_DIR}/zip-content/misc/aapt" || ui_error 'Failed to delete unused files in the temp dir'
rm -f "${TEMP_DIR}/zip-content/misc/busybox/busybox-"mips* || ui_error 'Failed to delete unused files in the temp dir'
rm -f "${TEMP_DIR}/zip-content/LICENSES/Info-ZIP.txt" || ui_error 'Failed to delete unused files in the temp dir'

if test -n "${OPENSOURCE_ONLY}"; then
  printf '%s\n%s\n\n%s\n' '# SPDX-FileCopyrightText: none' '# SPDX-License-Identifier: CC0-1.0' 'Include only Open source components.' > "${TEMP_DIR}/zip-content/OPENSOURCE-ONLY" || ui_error 'Failed to create the OPENSOURCE-ONLY file'
else
  files_to_download | while IFS='|' read -r LOCAL_FILENAME LOCAL_PATH _; do
    mkdir -p "${TEMP_DIR}/zip-content/${LOCAL_PATH}"
    cp -f "${SCRIPT_DIR}/cache/${LOCAL_PATH}/${LOCAL_FILENAME}" "${TEMP_DIR}/zip-content/${LOCAL_PATH}/" || ui_error "Failed to copy to the temp dir the file => '${LOCAL_PATH}/${LOCAL_FILENAME}'"
  done
  STATUS="$?"; if test "${STATUS}" -ne 0; then return "${STATUS}" 2>&- || exit "${STATUS}"; fi

  mkdir -p "${TEMP_DIR}/zip-content/misc/keycheck"
  cp -f "${SCRIPT_DIR}/cache/misc/keycheck/keycheck-arm" "${TEMP_DIR}/zip-content/misc/keycheck/" || ui_error "Failed to copy to the temp dir the file => 'misc/keycheck/keycheck-arm'"
fi

# Prepare the data before compression (also uniform attributes - useful for reproducible builds)
BASE_TMP_SCRIPT_DIR="${TEMP_DIR}/zip-content/META-INF/com/google/android"
mv -f "${BASE_TMP_SCRIPT_DIR}/update-binary.sh" "${BASE_TMP_SCRIPT_DIR}/update-binary" || ui_error 'Failed to rename a file'
mv -f "${BASE_TMP_SCRIPT_DIR}/updater-script.sh" "${BASE_TMP_SCRIPT_DIR}/updater-script" || ui_error 'Failed to rename a file'
find "${TEMP_DIR}/zip-content" -type d -exec chmod 0700 '{}' + -o -type f -exec chmod 0600 '{}' + || ui_error 'Failed to set permissions of files'
if test "${PLATFORM}" == 'win'; then
  ATTRIB -R -A -S -H "${TEMP_DIR}/zip-content/*" /S /D
fi
find "${TEMP_DIR}/zip-content" -exec touch -c -t 200802290333.46 '{}' + || ui_error 'Failed to set the modification date of files'

# Remove the previously built files (if they exist)
rm -f "${OUT_DIR:?}/${FILENAME}".zip* || ui_error 'Failed to remove the previously built files'
rm -f "${OUT_DIR:?}/${FILENAME}-signed".zip* || ui_error 'Failed to remove the previously built files'

# Compress (it ensure that the list of files to compress is in the same order under all OSes)
# Note: Unicode filenames in the zip are disabled since we don't need them and also zipsigner.jar chokes on them
cd "${TEMP_DIR}/zip-content" || ui_error 'Failed to change the folder'
echo 'Zipping...'
find . -type f | LC_ALL=C sort | zip -D -9 -X -UN=n -nw "${TEMP_DIR}/flashable.zip" -@ || ui_error 'Failed compressing'
FILENAME="${FILENAME}-signed"

# Sign and zipalign
echo ''
echo 'Signing and zipaligning...'
mkdir -p "${TEMP_DIR}/zipsign"
java -Duser.timezone=UTC -Dzip.encoding=Cp437 -Djava.io.tmpdir="${TEMP_DIR}/zipsign" -jar "${SCRIPT_DIR}/tools/zipsigner.jar" "${TEMP_DIR}/flashable.zip" "${TEMP_DIR}/${FILENAME}.zip" || ui_error 'Failed signing and zipaligning'

if test "${FAST_BUILD:-false}" = 'false'; then
  echo ''
  zip -T "${TEMP_DIR}/${FILENAME}.zip" || ui_error 'The zip file is corrupted'
fi
cp -f "${TEMP_DIR}/${FILENAME}.zip" "${OUT_DIR}/${FILENAME}.zip" || ui_error 'Failed to copy the final file'

cd "${OUT_DIR}" || ui_error 'Failed to change the folder'

# Cleanup remnants
rm -rf "${TEMP_DIR:?}" &
#pid="${!}"

# Create checksum files
echo ''
sha256sum "${FILENAME}.zip" > "${OUT_DIR}/${FILENAME}.zip.sha256" || ui_error 'Failed to compute the sha256 hash'
sha256_hash="$(cat "${OUT_DIR}/${FILENAME}.zip.sha256")" || ui_error 'Failed to display the sha256 hash'
echo 'SHA-256:'
if test "${GITHUB_JOB:-false}" != 'false'; then
  echo "::notice::${sha256_hash}"
else
  echo "${sha256_hash}"
fi

if test "${FAST_BUILD:-false}" = 'false'; then
  echo ''
  md5sum "${FILENAME}.zip" > "${OUT_DIR}/${FILENAME}.zip.md5" || ui_error 'Failed to compute the md5 hash'
  echo 'MD5:'
  cat "${OUT_DIR}/${FILENAME}.zip.md5" || ui_error 'Failed to display the md5 hash'
fi

cd "${INIT_DIR}" || ui_error 'Failed to change back the folder'

echo ''
echo 'Done.'
if test -z "${CI}"; then printf '\033]0;Done\007' && printf '\r                    \r'; fi

#wait "${pid}"
exit "$?"
