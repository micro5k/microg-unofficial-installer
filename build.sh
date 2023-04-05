#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# shellcheck disable=SC2310 # This function is invoked in an 'if' condition so set -e will be disabled
last_command="${_}" # IMPORTANT: This line must be at the start of the script before any other command otherwise it will not work

set -e
# shellcheck disable=SC3040
set -o pipefail || true
# shellcheck disable=SC3040
set -o posix 2> /dev/null || true

cat << 'LICENSE'
  SPDX-FileCopyrightText: (c) 2016-2019, 2021-2023 ale5000

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
  # shellcheck disable=SC3043
  local this_script

  # shellcheck disable=SC3028,SC2128
  if test "${#BASH_SOURCE}" -ge 1; then
    this_script="${BASH_SOURCE}" # Expanding an array without an index gives the first element (it is intended)
  else
    # shellcheck disable=SC3043
    local current_shell
    # shellcheck disable=SC2009
    current_shell="$(ps -o 'pid,comm' | grep -Fw "$$" | while IFS=' ' read -r _ current_shell; do echo "${current_shell}"; done || true)"

    if test -n "$0" && test -n "${current_shell}" && test "$0" != "${current_shell}" && test "$0" != "-${current_shell}"; then
      this_script="$0"
    elif test -n "${last_command}"; then
      this_script="${last_command}"
    else
      echo 'ERROR: The script filename cannot be found'
      return 1
    fi
  fi
  unset last_command

  this_script="$(realpath "${this_script}" 2> /dev/null)" || return 1
  SCRIPT_DIR="$(dirname "${this_script}")" || return 1
}
detect_script_dir || return 1 2>&- || exit 1

# shellcheck source=SCRIPTDIR/includes/common.sh
if test "${A5K_FUNCTIONS_INCLUDED:-false}" = 'false'; then . "${SCRIPT_DIR}/includes/common.sh"; fi

save_last_title
change_title 'Building the flashable OTA zip...'

# shellcheck source=SCRIPTDIR/conf-1.sh
. "${SCRIPT_DIR}/conf-1.sh"
# shellcheck source=SCRIPTDIR/conf-2.sh
if test "${OPENSOURCE_ONLY:-false}" = 'false'; then . "${SCRIPT_DIR}/conf-2.sh"; fi

if test "${OPENSOURCE_ONLY:-false}" != 'false'; then
  if ! is_oss_only_build_enabled; then
    echo 'WARNING: The OSS only build is disabled'
    change_title 'OSS only build is disabled'
    # shellcheck disable=SC2317
    return 0 2>&- || exit 0
  fi
  if test ! -f "${SCRIPT_DIR:?}/zip-content/settings-oss.conf"; then ui_error 'The settings file is missing'; fi
fi

_init_dir="$(pwd)" || ui_error 'Failed to read the current dir'

# Check dependencies
command -v 'zip' 1> /dev/null || ui_error 'Zip is missing'
command -v 'java' 1> /dev/null || ui_error 'Java is missing'

# Create the output dir
OUT_DIR="${SCRIPT_DIR}/output"
mkdir -p "${OUT_DIR}" || ui_error 'Failed to create the output dir'

# Create the temp dir
TEMP_DIR="$(mktemp -d -t ZIPBUILDER-XXXXXX)" || ui_error 'Failed to create our temp dir'
if test -z "${TEMP_DIR}"; then ui_error 'Failed to create our temp dir'; fi

# Empty our temp dir (should be already empty, but we must be sure)
rm -rf "${TEMP_DIR:?}"/* || ui_error 'Failed to empty our temp dir'

# Set filename and version
MODULE_ID="$(simple_get_prop 'id' "${SCRIPT_DIR:?}/zip-content/module.prop")" || ui_error 'Failed to parse the module id string'
MODULE_VER="$(simple_get_prop 'version' "${SCRIPT_DIR:?}/zip-content/module.prop")" || ui_error 'Failed to parse the module version string'
MODULE_AUTHOR="$(simple_get_prop 'author' "${SCRIPT_DIR:?}/zip-content/module.prop")" || ui_error 'Failed to parse the module author string'
FILENAME="${MODULE_ID:?}-${MODULE_VER:?}-by-${MODULE_AUTHOR:?}"
# shellcheck disable=SC2154
if test "${OPENSOURCE_ONLY:-false}" != 'false'; then FILENAME="${FILENAME:?}-OSS"; fi

# shellcheck source=SCRIPTDIR/addition.sh
. "${SCRIPT_DIR}/addition.sh"

# Verify files in the files list to avoid creating broken packages
if test -e "${SCRIPT_DIR:?}/zip-content/origin/file-list.dat"; then
  while IFS='|' read -r LOCAL_FILENAME _ _ _ _ FILE_HASH _; do
    printf '.'
    verify_sha1 "${SCRIPT_DIR:?}/zip-content/origin/${LOCAL_FILENAME:?}.apk" "${FILE_HASH:?}" || ui_error "Verification of '${LOCAL_FILENAME:-}' failed"
  done 0< "${SCRIPT_DIR:?}/zip-content/origin/file-list.dat" || ui_error 'Failed to open the list of files to verify'
  printf '\n'
fi

# Download files if they are missing
mkdir -p "${SCRIPT_DIR}/cache"

# shellcheck disable=SC3040
set +o posix 2> /dev/null || true

# shellcheck disable=SC3001,SC2312
dl_list < <(oss_files_to_download || ui_error 'Missing download list') || ui_error 'Failed to download the necessary files'

if test "${OPENSOURCE_ONLY:-false}" = 'false'; then
  # shellcheck disable=SC3001,SC2312
  dl_list < <(files_to_download || ui_error 'Missing download list') || ui_error 'Failed to download the necessary files'

  dl_file 'misc/keycheck' 'keycheck-arm.bin' '77d47e9fb79bf4403fddab0130f0b4237f6acdf0' 'github.com/someone755/kerneller/raw/9bb15ca2e73e8b81e412d595b52a176bdeb7c70a/extract/tools/keycheck' ''
else
  echo 'Skipped not OSS files!'
fi

# shellcheck disable=SC3040
set -o posix 2> /dev/null || true

# Copy data
cp -rf "${SCRIPT_DIR}/zip-content" "${TEMP_DIR}/" || ui_error 'Failed to copy data to the temp dir'
cp -rf "${SCRIPT_DIR}/"LICENSES* "${TEMP_DIR}/zip-content/" || ui_error 'Failed to copy the licenses folder to the temp dir'
cp -f "${SCRIPT_DIR}/LICENSE.rst" "${TEMP_DIR}/zip-content/" || ui_error 'Failed to copy the license to the temp dir'
cp -f "${SCRIPT_DIR}/LIC-ADDITION.rst" "${TEMP_DIR}/zip-content/" || ui_error 'Failed to copy the license to the temp dir'
mkdir -p "${TEMP_DIR}/zip-content/docs"
cp -f "${SCRIPT_DIR}/CHANGELOG.rst" "${TEMP_DIR}/zip-content/docs/" || ui_error 'Failed to copy the changelog to the temp dir'

if test "${OPENSOURCE_ONLY:-false}" != 'false'; then
  mv -f "${TEMP_DIR}/zip-content/settings-oss.conf" "${TEMP_DIR}/zip-content/settings.conf" || ui_error 'Failed to choose the settings file'
else
  mv -f "${TEMP_DIR}/zip-content/settings-full.conf" "${TEMP_DIR}/zip-content/settings.conf" || ui_error 'Failed to choose the settings file'
fi
rm -f "${TEMP_DIR}/zip-content/settings-oss.conf"
rm -f "${TEMP_DIR}/zip-content/settings-full.conf"

# Do not ship currently unused binaries and unused files
rm -rf "${TEMP_DIR}/zip-content/misc/aapt" || ui_error 'Failed to delete unused files in the temp dir'
rm -f "${TEMP_DIR}/zip-content/misc/busybox/busybox-"mips* || ui_error 'Failed to delete unused files in the temp dir'
rm -f "${TEMP_DIR}/zip-content/LICENSES/Info-ZIP.txt" || ui_error 'Failed to delete unused files in the temp dir'

if test "${OPENSOURCE_ONLY:-false}" != 'false'; then
  printf '%s\n%s\n\n%s\n' '# SPDX-FileCopyrightText: none' '# SPDX-License-Identifier: CC0-1.0' 'Include only Open source components.' > "${TEMP_DIR}/zip-content/OPENSOURCE-ONLY" || ui_error 'Failed to create the OPENSOURCE-ONLY file'
else
  files_to_download | while IFS='|' read -r LOCAL_FILENAME LOCAL_PATH MIN_API MAX_API FINAL_FILENAME INTERNAL_NAME FILE_HASH _; do
    mkdir -p -- "${TEMP_DIR:?}/zip-content/origin/${LOCAL_PATH:?}"
    cp -f -- "${SCRIPT_DIR:?}/cache/${LOCAL_PATH:?}/${LOCAL_FILENAME:?}.apk" "${TEMP_DIR:?}/zip-content/origin/${LOCAL_PATH:?}/" || ui_error "Failed to copy to the temp dir the file => '${LOCAL_PATH}/${LOCAL_FILENAME}.apk'"
    printf '%s\n' "${LOCAL_PATH:?}/${LOCAL_FILENAME:?}|${MIN_API:?}|${MAX_API?}|${FINAL_FILENAME:?}|${INTERNAL_NAME:?}|${FILE_HASH:?}" >> "${TEMP_DIR:?}/zip-content/origin/file-list.dat"
  done
  STATUS="$?"
  if test "${STATUS:?}" -ne 0; then return "${STATUS}" 2>&- || exit "${STATUS}"; fi

  mkdir -p "${TEMP_DIR}/zip-content/misc/keycheck"
  cp -f "${SCRIPT_DIR}/cache/misc/keycheck/keycheck-arm.bin" "${TEMP_DIR}/zip-content/misc/keycheck/" || ui_error "Failed to copy to the temp dir the file => 'misc/keycheck/keycheck-arm'"
fi

printf '\n'

# Remove the cache folder only if it is empty
rmdir --ignore-fail-on-non-empty "${SCRIPT_DIR}/cache" || ui_error 'Failed to remove the empty cache folder'

# Prepare the data before compression (also uniform attributes - useful for reproducible builds)
BASE_TMP_SCRIPT_DIR="${TEMP_DIR}/zip-content/META-INF/com/google/android"
mv -f "${BASE_TMP_SCRIPT_DIR}/update-binary.sh" "${BASE_TMP_SCRIPT_DIR}/update-binary" || ui_error 'Failed to rename a file'
mv -f "${BASE_TMP_SCRIPT_DIR}/updater-script.dat" "${BASE_TMP_SCRIPT_DIR}/updater-script" || ui_error 'Failed to rename a file'
find "${TEMP_DIR}/zip-content" -type d -exec chmod 0700 '{}' + -o -type f -exec chmod 0600 '{}' + || ui_error 'Failed to set permissions of files'
if test "${PLATFORM:?}" = 'win'; then
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
rm -rf -- "${TEMP_DIR:?}" &
#pid="${!}"

# Create checksum files
echo ''
sha256sum "${FILENAME}.zip" > "${OUT_DIR}/${FILENAME}.zip.sha256" || ui_error 'Failed to compute the sha256 hash'
sha256_hash="$(cat "${OUT_DIR}/${FILENAME}.zip.sha256")" || ui_error 'Failed to read the sha256 hash'
echo 'SHA-256:'
echo "${sha256_hash:?}" || ui_error 'Failed to display the sha256 hash'

if test "${GITHUB_JOB:-false}" != 'false'; then
  printf 'sha256_hash=%s\n' "${sha256_hash:?}" >> "${GITHUB_OUTPUT:?}" # Save hash for later use
fi

if test "${FAST_BUILD:-false}" = 'false'; then
  md5sum "${FILENAME}.zip" > "${OUT_DIR}/${FILENAME}.zip.md5" || ui_error 'Failed to compute the md5 hash'
  echo 'MD5:'
  cat "${OUT_DIR}/${FILENAME}.zip.md5" || ui_error 'Failed to read the md5 hash'
fi

cd "${_init_dir:?}" || ui_error 'Failed to change back the folder'

echo ''
echo 'Done.'
change_title 'Done'

set +e

# Ring bell
if test "${CI:-false}" = 'false'; then printf '%b' '\007' || true; fi

#wait "${pid:?}" || true

# Pause
if test "${CI:-false}" = 'false' && test "${APP_BASE_NAME:-false}" != 'gradlew' && test "${APP_BASE_NAME:-false}" != 'gradlew.'; then
  # shellcheck disable=SC3045
  IFS='' read -rsn 1 -p 'Press any key to continue...' _ || true
  printf '\n' || true
fi
restore_saved_title_if_exist
