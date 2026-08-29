#!/usr/bin/env sh
# SPDX-FileCopyrightText: 2025 ale5000
# SPDX-License-Identifier: Apache-2.0 OR GPL-3.0-or-later WITH LicenseRef-Archive-packaging-exception

# @name AOSP system permissions downloader
# @brief Download and parse AOSP system permission declarations for each supported Android API level.
# @description For every supported Android API level (23 to 36) fetches the
# corresponding AndroidManifest.xml from AOSP, extracts all <permission>
# entries, and saves one XML file per API level under data/perms/.
#
# The resulting files are consumed by generate-perm-xml.sh.
# @author ale5000

# Get the latest version from here: https://github.com/micro5k/microg-unofficial-installer/tree/main/tools
# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

readonly SCRIPT_NAME='AOSP system permissions downloader'
readonly SCRIPT_SHORTNAME='SysPermDl'
readonly SCRIPT_VERSION='0.3.9'
readonly SCRIPT_AUTHOR='ale5000'
readonly SCRIPT_YEAR='2025'

set -u
# shellcheck disable=SC3040,SC3041,SC2015
{
  # Unsupported set options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue
  (set +H 2> /dev/null) && set +H || true
  (set -o pipefail 2> /dev/null) && set -o pipefail || true
}

readonly BASE_URL='https://android.googlesource.com/platform/frameworks/base/'
readonly MAX_API='37'

# shellcheck disable=SC2034
{
  readonly TAG_API_23='android-6.0.1_r81'  # Android 6
  readonly TAG_API_24='android-7.0.0_r36'  # Android 7.0
  readonly TAG_API_25='android-7.1.2_r39'  # Android 7.1
  readonly TAG_API_26='android-8.0.0_r51'  # Android 8.0
  readonly TAG_API_27='android-8.1.0_r81'  # Android 8.1
  readonly TAG_API_28='android-9.0.0_r61'  # Android 9
  readonly TAG_API_29='android-10.0.0_r47' # Android 10
  readonly TAG_API_30='android-11.0.0_r48' # Android 11
  readonly TAG_API_31='android-12.0.0_r34' # Android 12.0
  readonly TAG_API_32='android-12.1.0_r27' # Android 12.1
  readonly TAG_API_33='android-13.0.0_r84' # Android 13
  readonly TAG_API_34='android-14.0.0_r75' # Android 14
  readonly TAG_API_35='android-15.0.0_r36' # Android 15
  readonly TAG_API_36='android-16.0.0_r4'  # Android 16
  readonly TAG_API_37='android-17.0.0_r1'  # Android 17
}

readonly WGET_CMD='wget'
readonly DL_UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0'
readonly DL_ACCEPT_HEADER='Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
readonly DL_ACCEPT_LANG_HEADER='Accept-Language: en-US,en;q=0.5'

fix_posix_emulation_if_needed()
{
  # Workarounds for shells using Windows-POSIX emulation layers (e.g., Git Bash under Windows)
  if test -f '/usr/bin/cygpath'; then
    # Prioritize POSIX-emulated binaries over Windows natives to prevent hangs and obscure errors
    if test "${USR_BIN_FIXED:-0}" = '0'; then
      case "${PATH-}" in '/usr/bin:'*) ;; *) PATH="/usr/bin:${PATH:-%empty}" ;; esac
    fi

    # Resolve an issue where dragging and dropping a file onto the script inexplicably resets the
    #  working directory to 'C:\WINDOWS\system32'
    # shellcheck disable=SC3028 # IGNORE: In POSIX sh, BASH_SOURCE is undefined
    if test "$(/usr/bin/cygpath -m -- "${PWD:?}" || :)" = "$(/usr/bin/cygpath -m -S || :)" && test -n "${BASH_SOURCE-}"; then
      cd "${BASH_SOURCE:?}/.." || printf '%s\n' 'ERROR: Failed to restore the correct working directory'
    fi
  fi
}

pause_if_needed()
{
  # shellcheck disable=SC3028 # Ignore: In POSIX sh, SHLVL is undefined
  if test "${NO_PAUSE:-0}" = '0' && test "${no_pause:-0}" = '0' && test "${CI:-false}" = 'false' && test "${TERM_PROGRAM:-none}" != 'vscode' && test "${SHLVL:-1}" = '1' && test -t 0 && test -t 1 && test -t 2; then
    if test -n "${NO_COLOR-}"; then
      printf 1>&2 '\n%s' 'Press any key to exit... ' || :
    else
      printf 1>&2 '\n\033[1;32m\r%s' 'Press any key to exit... ' || :
    fi
    # shellcheck disable=SC3045 # Ignore: In POSIX sh, read -s / -n is undefined
    IFS='' read 2> /dev/null 1>&2 -r -s -n1 _ || IFS='' read 1>&2 -r _ || :
    if test -n "${NO_COLOR-}"; then printf 1>&2 '\n' || :; else printf 1>&2 '\n\033[0m\r    \r' || :; fi
  fi
  unset no_pause
  return "${1:-0}"
}

show_status()
{
  printf 1>&2 '\033[1;32m%s\033[0m\n' "${1?}"
}

show_error()
{
  printf 1>&2 '\n\033[1;31m%s\033[0m\n' "ERROR: ${1?}"
}

find_data_dir()
{
  local _path

  # shellcheck disable=SC3028 # Ignore: In POSIX sh, BASH_SOURCE is undefined
  if test -n "${TOOLS_DATA_DIR-}" && _path="${TOOLS_DATA_DIR:?}" && test -d "${_path:?}"; then
    :
  elif test -n "${BASH_SOURCE-}" && _path="$(dirname "${BASH_SOURCE:?}")/data" && test -d "${_path:?}"; then
    : # It is expected: expanding an array without an index gives the first element
  elif test -n "${0-}" && _path="$(dirname "${0:?}")/data" && test -d "${_path:?}"; then
    :
  elif _path='./data' && test -d "${_path:?}"; then
    :
  else
    return 1
  fi

  _path="$(realpath 2> /dev/null "${_path:?}" || readlink -f "${_path:?}")" || return 1
  printf '%s\n' "${_path:?}"
}

create_and_return_data_dir()
{
  local _path

  # shellcheck disable=SC3028 # Ignore: In POSIX sh, BASH_SOURCE is undefined
  if test -n "${TOOLS_DATA_DIR-}" && _path="${TOOLS_DATA_DIR:?}"; then
    :
  elif test -n "${BASH_SOURCE-}" && test -f "${BASH_SOURCE:?}" && _path="$(dirname "${BASH_SOURCE:?}")/data"; then
    : # It is expected: expanding an array without an index gives the first element
  elif test -n "${0-}" && test -f "${0:?}" && _path="$(dirname "${0:?}")/data"; then
    :
  elif _path='./data'; then
    :
  else
    return 1
  fi

  test -d "${_path:?}" || mkdir -p -- "${_path:?}" || return 1

  _path="$(realpath 2> /dev/null "${_path:?}" || readlink -f "${_path:?}")" || return 1
  printf '%s\n' "${_path:?}"
}

dl()
{
  "${WGET_CMD:?}" -q -O "${2:?}" -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" --no-cache -- "${1:?}" || return "${?}"
}

download_and_parse_permissions()
{
  # REUSE-IgnoreStart
  {
    printf '%s\n%s\n%s\n%s\n' '<!--' ' SPDX-FileCopyrightText: 2006 The Android Open Source Project' ' SPDX-License-Identifier: Apache-2.0' '-->' || return "${?}"
    printf '%s\n' '<manifest xmlns:android="http://schemas.android.com/apk/res/android">' || return "${?}"
  } 1> "${DATA_DIR:?}/perms/base-permissions-api-${1:?}.xml" || return "${?}"
  # REUSE-IgnoreEnd

  dl "${BASE_URL:?}+/refs/tags/${2:?}/core/res/AndroidManifest.xml?format=text" '-' |
    base64 -d - |
    tr -s -- '\n' ' ' |
    sed -e 's|>|>\n|g' |
    grep -F -e '<permission' |
    sed -e 's|">|" />|g' 1>> "${DATA_DIR:?}/perms/base-permissions-api-${1:?}.xml" ||
    return "${?}"

  printf '%s\n' '</manifest>' 1>> "${DATA_DIR:?}/perms/base-permissions-api-${1:?}.xml" || return "${?}"
}

clean_perms_dir_if_empty()
{
  if test -n "${DATA_DIR-}" && test -d "${DATA_DIR?}/perms"; then
    rmdir 2> /dev/null -- "${DATA_DIR?}/perms" || :
  fi
}

main()
{
  local api='' tag=''

  fix_posix_emulation_if_needed

  DATA_DIR="$(find_data_dir || create_and_return_data_dir)" || return 1

  command 1> /dev/null -v "${WGET_CMD:?}" || {
    show_error 'Missing: wget'
    return 255
  }

  test -d "${DATA_DIR:?}/perms" || mkdir -p -- "${DATA_DIR:?}/perms" || return 1
  rm -f -- "${DATA_DIR:?}/perms/.completed"

  for api in $(seq -- 23 "${MAX_API:?}"); do
    tag="$(eval " printf '%s\n' \"\${TAG_API_${api:?}:?}\" ")" || {
      printf '%s\n' "Failed to get tag for API ${api?}"
      return 4
    }
    printf '%s\n' "API ${api:?}: ${tag:?}"
    download_and_parse_permissions "${api:?}" "${tag:?}" || {
      printf '%s\n' "Failed to download/parse XML for API ${api?}"
      rm -f -- "${DATA_DIR:?}/perms/base-permissions-api-${api:?}.xml"
      return 5
    }
  done

  touch -- "${DATA_DIR:?}/perms/.completed"
}

execute_script='true'
STATUS=0

while test "$#" -gt 0; do
  case "${1?}" in
    -V | --version)
      execute_script='false'
      # REUSE-IgnoreStart
      printf '%s\n' "${SCRIPT_NAME:?}, version ${SCRIPT_VERSION:?}"
      printf '%s\n' "Copyright (C) ${SCRIPT_YEAR:?} ${SCRIPT_AUTHOR:?}"
      printf '%s\n\n' 'License Apache-2.0 or GPLv3+ with APE.'
      printf '%s\n' 'There is NO WARRANTY, to the extent permitted by law.'
      # REUSE-IgnoreEnd
      ;;

    -) # Read from STDIN (implies end of options)
      break
      ;;
    --) # End of options / Positional arguments follow
      shift
      break
      ;;
    --*)
      execute_script='false'
      STATUS=2
      printf 1>&2 '%s\n' "${SCRIPT_SHORTNAME?}: unrecognized option '${1}'"
      ;;
    -*)
      execute_script='false'
      STATUS=2
      printf 1>&2 '%s\n' "${SCRIPT_SHORTNAME?}: invalid option -- '${1#-}'"
      ;;
    *) break ;;
  esac

  shift
done

if test "${execute_script:?}" = 'true'; then
  show_status "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?} by ${SCRIPT_AUTHOR:?}"

  test "$#" -ne 0 || set -- ''
  main "${@}" || STATUS="${?}"
  clean_perms_dir_if_empty
fi

pause_if_needed "${STATUS:?}"
exit "${?}"
