#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck disable=SC2310 # This function is invoked in an 'if' condition so set -e will be disabled
last_command="${_}" # IMPORTANT: This line must be at the start of the script before any other command otherwise it will not work

set -e
# shellcheck disable=SC3040,SC3041,SC2015 # Ignore: In POSIX sh, set option xxx is undefined. / In POSIX sh, set flag -X is undefined. / C may run when A is true.
{
  # Unsupported set options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue
  (set 2> /dev/null -o posix) && set -o posix || :
  (set 2> /dev/null +H) && set +H || :
  case "$(set 2> /dev/null -o || set || :)" in *'pipefail'*) if set -o pipefail; then export USING_PIPEFAIL='true'; else echo 1>&2 'Failed: pipefail'; fi ;; *) ;; esac
}

cat << 'LICENSE'
  SPDX-FileCopyrightText: (c) 2016-2019, 2021-2025 ale5000

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
  MAIN_DIR="$(dirname "${this_script}")" || return 1
}
detect_script_dir || return 1 2>&- || exit 1

export BUILD_CACHE_DIR="${MAIN_DIR:?}/cache/build"

unset DO_INIT_CMDLINE
# shellcheck source=SCRIPTDIR/includes/common.sh
if test "${A5K_FUNCTIONS_INCLUDED:-false}" = 'false'; then . "${MAIN_DIR:?}/includes/common.sh"; fi

if test -n "${OPENSOURCE_ONLY-}"; then
  ui_error 'You must set BUILD_TYPE instead of OPENSOURCE_ONLY'
fi

# Parse parameters
default_build_type='true'
while test "${#}" -gt 0; do
  case "${1?}" in
    --no-default-build-type) default_build_type='false' ;;
    --no-pause) export NO_PAUSE=1 ;;
    --)
      shift
      break
      ;;
    --* | -*) ;; # Ignore unsupported options
    *) break ;;
  esac

  shift
done

test "${default_build_type:?}" = 'false' || BUILD_TYPE="${BUILD_TYPE:-full}"
case "${BUILD_TYPE-}" in
  'full') export OPENSOURCE_ONLY='false' ;;
  'oss') export OPENSOURCE_ONLY='true' ;;
  *) ui_error "Invalid build type => '${BUILD_TYPE-}'" ;;
esac

save_last_title
set_title 'Building the flashable OTA zip...'

# shellcheck source=SCRIPTDIR/conf-1.sh
. "${MAIN_DIR:?}/conf-1.sh"
# shellcheck source=SCRIPTDIR/conf-2.sh
if test "${OPENSOURCE_ONLY:?}" = 'false'; then . "${MAIN_DIR:?}/conf-2.sh"; fi

_init_dir="$(pwd)" || ui_error 'Failed to read the current dir'

# Set output dir
OUT_DIR="${MAIN_DIR:?}/output"

# Set module info
MODULE_ID="$(simple_get_prop 'id' "${MAIN_DIR:?}/zip-content/module.prop")" || ui_error 'Failed to parse the module id string'
MODULE_VER="$(simple_get_prop 'version' "${MAIN_DIR:?}/zip-content/module.prop")" || ui_error 'Failed to parse the module version string'
MODULE_AUTHOR="$(simple_get_prop 'author' "${MAIN_DIR:?}/zip-content/module.prop")" || ui_error 'Failed to parse the module author string'
case "${MODULE_VER:?}" in
  *'-alpha') MODULE_IS_ALPHA='true' ;;
  *) MODULE_IS_ALPHA='false' ;;
esac

# Set short commit ID
ZIP_SHORT_COMMIT_ID=''
if test "${CI:-false}" != 'false'; then
  ZIP_SHORT_COMMIT_ID="${CI_COMMIT_SHA:-${GITHUB_SHA:?Missing commit ID}}" || ZIP_SHORT_COMMIT_ID=''
else
  ZIP_SHORT_COMMIT_ID="$(git 2> /dev/null rev-parse HEAD)" || ZIP_SHORT_COMMIT_ID=''
fi
if test -n "${ZIP_SHORT_COMMIT_ID?}"; then
  ZIP_SHORT_COMMIT_ID="$(printf '%s' "${ZIP_SHORT_COMMIT_ID:?}" | cut -b '-8')" || ZIP_SHORT_COMMIT_ID=''
fi

if test "${OPENSOURCE_ONLY:?}" != 'false'; then
  if ! is_oss_only_build_enabled; then
    echo 'WARNING: The OSS only build is disabled'
    set_title 'OSS only build is disabled'

    # Save info for later use
    if test "${GITHUB_JOB:-false}" != 'false'; then
      {
        printf 'ZIP_FOLDER=%s\n' "${OUT_DIR?}"
        printf 'ZIP_FILENAME=\n'
        printf 'ZIP_VERSION=%s\n' "${MODULE_VER?}"
        printf 'ZIP_SHORT_COMMIT_ID=%s\n' "${ZIP_SHORT_COMMIT_ID?}"
        printf 'ZIP_BUILD_TYPE=%s\n' "${BUILD_TYPE?}"
        printf 'ZIP_BUILD_TYPE_SUPPORTED=%s\n' 'false'
        printf 'ZIP_BRANCH_NAME=\n'
        printf 'ZIP_IS_ALPHA=%s\n' "${MODULE_IS_ALPHA?}"
        printf 'ZIP_SHA256=\n'
        printf 'ZIP_MD5=\n'
      } >> "${GITHUB_OUTPUT?}"
    fi

    # shellcheck disable=SC2317
    return 0 2>&- || exit 0
  fi
  if test ! -f "${MAIN_DIR:?}/zip-content/settings-oss.conf"; then ui_error 'The settings file is missing'; fi
fi

# Check dependencies
command 1> /dev/null 2>&1 -v 'printf' || ui_error 'Missing: printf'
command 1> /dev/null 2>&1 -v 'zip' || ui_error 'Missing: zip'
command 1> /dev/null 2>&1 -v 'java' || ui_error 'Missing: java'
command 1> /dev/null 2>&1 -v 'grep' || ui_error 'Missing: grep'

command 1> /dev/null 2>&1 -v 'wget' || ui_error 'Missing: wget'
command 1> /dev/null 2>&1 -v 'cut' || ui_error 'Missing: cut'
command 1> /dev/null 2>&1 -v 'sed' || ui_error 'Missing: sed'
command 1> /dev/null 2>&1 -v 'rev' || ui_error 'Missing: rev'

# Create the output dir
mkdir -p "${OUT_DIR:?}" || ui_error 'Failed to create the output dir'

# Create the temp dir
TEMP_DIR="$(mktemp -d -t ZIPBUILDER-XXXXXX)" || ui_error 'Failed to create our temp dir'
if test -z "${TEMP_DIR}"; then ui_error 'Failed to create our temp dir'; fi

# Empty our temp dir (should be already empty, but we must be sure)
rm -rf "${TEMP_DIR:?}"/* || ui_error 'Failed to empty our temp dir'

# Set filename
sanitize_filename_part()
{
  # The "-" character must be replaced because it is used to separate the various parts of the filename
  printf '%s' "${1:?}" | tr -- '-\\/:*?"<>|\r\n\0' '_' || ui_error 'Failed to sanitize filename part'
}

BRANCH_NAME=''
FILENAME_COMMIT_ID="g${ZIP_SHORT_COMMIT_ID?}"
test "${FILENAME_COMMIT_ID:?}" != 'g' || FILENAME_COMMIT_ID='NOGIT'
FILENAME_START="${MODULE_ID:?}-${MODULE_VER:?}-"
FILENAME_MIDDLE="${FILENAME_COMMIT_ID:?}"
FILENAME_END="-${BUILD_TYPE:?}-by-${MODULE_AUTHOR:?}"

if test "${CI:-false}" != 'false'; then
  if test -n "${CI_COMMIT_BRANCH-}" && test "${CI_COMMIT_BRANCH:?}" != "${CI_DEFAULT_BRANCH:-unknown}"; then
    BRANCH_NAME="$(sanitize_filename_part "${CI_COMMIT_BRANCH:?}" || :)" # GitLab
  elif test "${GITHUB_REF_TYPE-}" = 'branch' && test -n "${GITHUB_REF_NAME-}" && test "${GITHUB_REF_NAME:?}" != "${GITHUB_REPOSITORY_DEFAULT_BRANCH:-main}"; then
    BRANCH_NAME="$(sanitize_filename_part "${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:?}}" || :)" # GitHub
  fi
  test -z "${BRANCH_NAME?}" || FILENAME_MIDDLE="${BRANCH_NAME:?}-${FILENAME_MIDDLE:?}"
  if test "${CI_PROJECT_NAMESPACE:-${GITHUB_REPOSITORY_OWNER:-unknown}}" != 'micro''5k'; then
    FILENAME_MIDDLE="fork-${FILENAME_MIDDLE:?}" # GitLab / GitHub
  fi
else
  BRANCH_NAME="$(git 2> /dev/null branch --show-current)" || BRANCH_NAME="$(git 2> /dev/null rev-parse --abbrev-ref HEAD)" || BRANCH_NAME=''
  if test -n "${BRANCH_NAME?}" && test "${BRANCH_NAME:?}" != 'main' && test "${BRANCH_NAME:?}" != 'HEAD'; then
    FILENAME_MIDDLE="$(sanitize_filename_part "${BRANCH_NAME:?}" || :)-${FILENAME_MIDDLE:?}"
  fi
fi

FILENAME="${FILENAME_START:?}${FILENAME_MIDDLE:?}${FILENAME_END:?}"
FILENAME_EXT='.zip'

# shellcheck source=SCRIPTDIR/addition.sh
. "${MAIN_DIR}/addition.sh"

# Verify files in the files list to avoid creating broken packages
if test -e "${MAIN_DIR:?}/zip-content/origin/file-list.dat"; then
  while IFS='|' read -r LOCAL_FILENAME _ _ _ _ _ FILE_HASH _; do
    printf '.'

    full_filename="${MAIN_DIR:?}/zip-content/origin/${LOCAL_FILENAME:?}"
    if test -f "${full_filename:?}.apk"; then full_filename="${full_filename:?}.apk"; else full_filename="${full_filename:?}.jar"; fi

    verify_sha1 "${full_filename:?}" "${FILE_HASH:?}" || {
      printf '\n'
      ui_error "Verification of '${LOCAL_FILENAME:-}' failed"
    }
  done 0< "${MAIN_DIR:?}/zip-content/origin/file-list.dat" || ui_error 'Failed to open the list of files to verify'
  printf '\n'
fi

# Download files if they are missing
{
  current_dl_list="$(oss_files_to_download)" || ui_error 'Missing download list'
  dl_list "${current_dl_list?}" || ui_error 'Failed to download the necessary files'

  if test "${OPENSOURCE_ONLY:?}" = 'false'; then
    current_dl_list="$(files_to_download)" || ui_error 'Missing download list'
    dl_list "${current_dl_list?}" || ui_error 'Failed to download the necessary files'

    dl_file 'misc/keycheck' 'keycheck-arm.bin' '77d47e9fb79bf4403fddab0130f0b4237f6acdf0' 'github.com/someone755/kerneller/raw/9bb15ca2e73e8b81e412d595b52a176bdeb7c70a/extract/tools/keycheck' ''
  else
    echo 'Skipped not OSS files!'
  fi

  clear_dl_temp_dir || ui_error 'Failed to remove the DL temp dir'

  unset current_dl_list
}

# Copy data
cp -rf "${MAIN_DIR:?}/zip-content" "${TEMP_DIR:?}/" || ui_error 'Failed to copy data to the temp dir'
cp -rf "${MAIN_DIR:?}/"LICENSES* "${TEMP_DIR:?}/zip-content/" || ui_error 'Failed to copy the licenses folder to the temp dir'
cp -f "${MAIN_DIR:?}/LICENSE.rst" "${TEMP_DIR:?}/zip-content/" || ui_error 'Failed to copy the license to the temp dir'
cp -f "${MAIN_DIR:?}/LICENSE-ADDITION.rst" "${TEMP_DIR:?}/zip-content/" || ui_error 'Failed to copy the license to the temp dir'
mkdir -p "${TEMP_DIR:?}/zip-content/docs"
cp -f "${MAIN_DIR:?}/CHANGELOG.rst" "${TEMP_DIR:?}/zip-content/docs/" || ui_error 'Failed to copy the changelog to the temp dir'

if test "${OPENSOURCE_ONLY:?}" != 'false'; then
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
rm -f "${TEMP_DIR}/zip-content/LICENSES/Unlicense.txt" || ui_error 'Failed to delete unused files in the temp dir'

printf '%s\n%s\n%s\n\n%s\n' '# -*- coding: utf-8; mode: conf-unix -*-' '# SPDX-FileCopyrightText: NONE' '# SPDX-License-Identifier: CC0-1.0' "buildType=${BUILD_TYPE:?}" 1> "${TEMP_DIR:?}/zip-content/info.prop" || ui_error "Failed to create the 'info.prop' file"

if test "${OPENSOURCE_ONLY:?}" = 'false'; then
  files_to_download | while IFS='|' read -r LOCAL_FILENAME LOCAL_PATH MIN_API MAX_API FINAL_FILENAME INTERNAL_NAME FILE_HASH _; do
    mkdir -p -- "${TEMP_DIR:?}/zip-content/origin/${LOCAL_PATH:?}"
    cp -f -- "${BUILD_CACHE_DIR:?}/${LOCAL_PATH:?}/${LOCAL_FILENAME:?}.apk" "${TEMP_DIR:?}/zip-content/origin/${LOCAL_PATH:?}/" || ui_error "Failed to copy to the temp dir the file => '${LOCAL_PATH}/${LOCAL_FILENAME}.apk'"

    _extract_libs=''
    if test "${LOCAL_FILENAME:?}" = 'PlayStore' || test "${LOCAL_FILENAME:?}" = 'PlayStoreARM64'; then _extract_libs='libs'; fi

    printf '%s\n' "${LOCAL_PATH:?}/${LOCAL_FILENAME:?}|${MIN_API:?}|${MAX_API?}|${FINAL_FILENAME:?}|${_extract_libs?}|${INTERNAL_NAME:?}|${FILE_HASH:?}" >> "${TEMP_DIR:?}/zip-content/origin/file-list.dat"
  done
  STATUS="$?"
  if test "${STATUS:?}" -ne 0; then return "${STATUS}" 2>&- || exit "${STATUS}"; fi

  mkdir -p "${TEMP_DIR}/zip-content/misc/keycheck"
  cp -f "${BUILD_CACHE_DIR:?}/misc/keycheck/keycheck-arm.bin" "${TEMP_DIR}/zip-content/misc/keycheck/" || ui_error "Failed to copy to the temp dir the file => 'misc/keycheck/keycheck-arm'"
fi

printf '%s\n' 'Setting name;Visibility;Type' 1> "${TEMP_DIR:?}/zip-content/setprop-settings-list.csv" || ui_error 'Failed to generate setprop settings list (1)'
printf '%s\n' 'DRY_RUN;local;integer' 1>> "${TEMP_DIR:?}/zip-content/setprop-settings-list.csv" || ui_error 'Failed to generate setprop settings list (2)'
printf '%s\n' 'KEY_TEST_ONLY;local;numeric-boolean' 1>> "${TEMP_DIR:?}/zip-content/setprop-settings-list.csv" || ui_error 'Failed to generate setprop settings list (3)'

while IFS='#=; ' read -r _ PROP_NAME PROP_VALUE PROP PROP_VISIBILITY PROP_TYPE _; do
  if test "${PROP?}" != 'setprop'; then continue; fi

  : "UNUSED ${PROP_VALUE:?}"
  printf '%s\n' "${PROP_NAME:?};${PROP_VISIBILITY:?};${PROP_TYPE:?}"
done 0< "${TEMP_DIR:?}/zip-content/settings.conf" 1>> "${TEMP_DIR:?}/zip-content/setprop-settings-list.csv" || ui_error 'Failed to generate setprop settings list'

printf '\n'

# Remove the build cache folder only if it is empty
test ! -d "${BUILD_CACHE_DIR:?}" || rmdir --ignore-fail-on-non-empty "${BUILD_CACHE_DIR:?}" || ui_error 'Failed to remove the empty build cache folder'

# Prepare the data before compression (also uniform attributes - useful for reproducible builds)
BASE_TMP_SCRIPT_DIR="${TEMP_DIR}/zip-content/META-INF/com/google/android"
mv -f "${BASE_TMP_SCRIPT_DIR}/update-binary.sh" "${BASE_TMP_SCRIPT_DIR}/update-binary" || ui_error 'Failed to rename a file'
mv -f "${BASE_TMP_SCRIPT_DIR}/updater-script.dat" "${BASE_TMP_SCRIPT_DIR}/updater-script" || ui_error 'Failed to rename a file'
find "${TEMP_DIR}/zip-content" -type d -exec chmod 0700 '{}' + -o -type f -exec chmod 0600 '{}' + || ui_error 'Failed to set permissions of files'
if test "${PLATFORM:?}" = 'win' && command 1> /dev/null -v 'attrib.exe'; then
  MSYS_NO_PATHCONV=1 attrib.exe -R -A -S -H "${TEMP_DIR:?}/zip-content/*" /S /D
fi
find "${TEMP_DIR}/zip-content" -exec touch -c -t 200802290333.46 '{}' + || ui_error 'Failed to set the modification date of files'

# Remove the previously built files (if they exist)
rm -f "${OUT_DIR:?}/${FILENAME_START:?}"*"${FILENAME_END:?}"*"${FILENAME_EXT:?}" || ui_error 'Failed to remove the previously built files'
rm -f "${OUT_DIR:?}/${FILENAME_START:?}"*"${FILENAME_END:?}"*"${FILENAME_EXT:?}".md5 || ui_error 'Failed to remove the previously built files'
rm -f "${OUT_DIR:?}/${FILENAME_START:?}"*"${FILENAME_END:?}"*"${FILENAME_EXT:?}".sha256 || ui_error 'Failed to remove the previously built files'

# Compress (it ensure that the list of files to compress is in the same order under all OSes)
# Note: Unicode filenames in the zip are disabled since we don't need them and also zipsigner.jar chokes on them
cd "${TEMP_DIR}/zip-content" || ui_error 'Failed to change the folder'
echo 'Zipping...'
find . -type f | LC_ALL=C sort | zip -D -9 -X -UN=n -nw "${TEMP_DIR}/flashable${FILENAME_EXT:?}" -@ || ui_error 'Failed compressing'
FILENAME="${FILENAME:?}-signed"

# Sign and zipalign
echo ''
echo 'Signing and zipaligning...'
mkdir -p "${TEMP_DIR:?}/zipsign"
java -Duser.timezone=UTC -Dzip.encoding=Cp437 -Djava.io.tmpdir="${TEMP_DIR:?}/zipsign" -jar "${MAIN_DIR:?}/tools/zipsigner.jar" "${TEMP_DIR:?}/flashable${FILENAME_EXT:?}" "${TEMP_DIR:?}/${FILENAME:?}${FILENAME_EXT:?}" || ui_error 'Failed signing and zipaligning'

if test "${FAST_BUILD:-false}" = 'false'; then
  echo ''
  zip -T "${TEMP_DIR:?}/${FILENAME:?}${FILENAME_EXT:?}" || ui_error 'The zip file is corrupted'
fi
cp -f "${TEMP_DIR:?}/${FILENAME:?}${FILENAME_EXT:?}" "${OUT_DIR:?}/${FILENAME:?}${FILENAME_EXT:?}" || ui_error 'Failed to copy the final file'

cd "${OUT_DIR:?}" || ui_error 'Failed to change the folder'

# Cleanup remnants (skip on CI)
pid=''
if test "${CI:-false}" = 'false'; then
  rm -r -f -- "${TEMP_DIR:?}" &
  #pid="${!}"
fi
echo ''

# Generate info
sha256sum "${FILENAME:?}${FILENAME_EXT:?}" > "${OUT_DIR:?}/${FILENAME:?}${FILENAME_EXT:?}.sha256" || ui_error 'Failed to compute the SHA-256 hash'
ZIP_SHA256="$(cut -d ' ' -f '1' -s 0< "${OUT_DIR:?}/${FILENAME:?}${FILENAME_EXT:?}.sha256")" || ui_error 'Failed to read the SHA-256 hash'

ZIP_MD5=''
if test "${FAST_BUILD:-false}" = 'false'; then
  md5sum "${FILENAME:?}${FILENAME_EXT:?}" > "${OUT_DIR:?}/${FILENAME:?}${FILENAME_EXT:?}.md5" || ui_error 'Failed to compute the MD5 hash'
  ZIP_MD5="$(cut -d ' ' -f '1' -s 0< "${OUT_DIR:?}/${FILENAME:?}${FILENAME_EXT:?}.md5")" || ui_error 'Failed to read the MD5 hash'
fi

if test -n "${ZIP_SHORT_COMMIT_ID?}"; then
  printf '%s\n' "Short commit ID: ${ZIP_SHORT_COMMIT_ID:?}"
fi
printf '%s\n' "Filename: ${FILENAME:?}${FILENAME_EXT:?}"
printf '%s\n' "SHA-256: ${ZIP_SHA256:?}"
if test -n "${ZIP_MD5?}"; then
  printf '%s\n' "MD5: ${ZIP_MD5:?}"
fi

# Save info for later use
if test "${GITHUB_JOB:-false}" != 'false'; then
  {
    printf 'ZIP_FOLDER=%s\n' "${OUT_DIR?}"
    printf 'ZIP_FILENAME=%s\n' "${FILENAME?}${FILENAME_EXT?}"
    printf 'ZIP_VERSION=%s\n' "${MODULE_VER?}"
    printf 'ZIP_SHORT_COMMIT_ID=%s\n' "${ZIP_SHORT_COMMIT_ID?}"
    printf 'ZIP_BUILD_TYPE=%s\n' "${BUILD_TYPE?}"
    printf 'ZIP_BUILD_TYPE_SUPPORTED=%s\n' 'true'
    printf 'ZIP_BRANCH_NAME=%s\n' "${BRANCH_NAME?}"
    printf 'ZIP_IS_ALPHA=%s\n' "${MODULE_IS_ALPHA?}"
    printf 'ZIP_SHA256=%s\n' "${ZIP_SHA256?}"
    printf 'ZIP_MD5=%s\n' "${ZIP_MD5?}"
  } >> "${GITHUB_OUTPUT?}"
fi

cd "${_init_dir:?}" || ui_error 'Failed to change back the folder'

echo ''
echo 'Done.'
set_title 'Done'

set +e

# Ring bell
beep

test -z "${pid?}" || wait "${pid:?}" || :

pause_if_needed
restore_saved_title_if_exist
