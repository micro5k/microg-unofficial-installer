#!/usr/bin/env sh
# @name Android permissions retriever
# @brief Retrieve the list of Android system permissions
# @author ale5000
# Get the latest version from here: https://github.com/micro5k/microg-unofficial-installer/tree/main/tools

# SPDX-FileCopyrightText: (c) 2025 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

readonly SCRIPT_NAME='Android permissions retriever'
readonly SCRIPT_SHORTNAME='DlPermList'
readonly SCRIPT_VERSION='0.3.0'
readonly SCRIPT_AUTHOR='ale5000'

set -u
# shellcheck disable=SC3040,SC3041,SC2015
{
  # Unsupported set options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue
  (set +H 2> /dev/null) && set +H || true
  (set -o pipefail 2> /dev/null) && set -o pipefail || true
}

readonly BASE_URL='https://android.googlesource.com/platform/frameworks/base/'
readonly MAX_API='36'

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
  readonly TAG_API_36='android-16.0.0_r2'  # Android 16
}

readonly WGET_CMD='wget'
readonly DL_UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0'
readonly DL_ACCEPT_HEADER='Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
readonly DL_ACCEPT_LANG_HEADER='Accept-Language: en-US,en;q=0.5'

show_status()
{
  printf 1>&2 '\033[1;32m%s\033[0m\n' "${1?}"
}

show_error()
{
  printf 1>&2 '\n\033[1;31m%s\033[0m\n\n' "ERROR: ${1?}"
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
  printf '%s\n' '<manifest xmlns:android="http://schemas.android.com/apk/res/android">' 1> "${DATA_DIR:?}/perms/base-permissions-api-${1:?}.xml" || return "${?}"

  dl "${BASE_URL:?}+/refs/tags/${2:?}/core/res/AndroidManifest.xml?format=text" '-' |
    base64 -d |
    tr -s -- '\n' ' ' |
    sed -e 's|>|>\n|g' |
    grep -F -e '<permission' 1>> "${DATA_DIR:?}/perms/base-permissions-api-${1:?}.xml" || return "${?}"

  printf '%s\n' '</manifest>' 1>> "${DATA_DIR:?}/perms/base-permissions-api-${1:?}.xml" || return "${?}"
}

main()
{
  local api tag

  command 1> /dev/null -v "${WGET_CMD:?}" || {
    show_error 'Missing: wget'
    return 255
  }

  DATA_DIR="$(find_data_dir || create_and_return_data_dir)" || return 1
  test -d "${DATA_DIR:?}/perms" || mkdir -p -- "${DATA_DIR:?}/perms" || return 1

  for api in $(seq -- 23 "${MAX_API:?}"); do
    tag="$(eval " printf '%s\n' \"\${TAG_API_${api:?}:?}\" ")" || {
      printf '%s\n' "Failed to get tag for API ${api?}"
      return 4
    }
    printf '%s\n' "API ${api:?}: ${tag:?}"
    download_and_parse_permissions "${api:?}" "${tag:?}" || {
      printf '%s\n' "Failed to download/parse XML for API ${api?}"
      return 5
    }
  done
}

STATUS=0
execute_script='true'

while test "${#}" -gt 0; do
  case "${1?}" in
    -V | --version)
      printf '%s\n' "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?}"
      printf '%s\n' "Copy""right (c) 2025 ${SCRIPT_AUTHOR:?}"
      printf '%s\n' 'License GPL-3.0+ OR Apache-2.0'
      execute_script='false'
      ;;

    --)
      shift
      break
      ;;

    --*)
      printf 1>&2 '%s\n' "${SCRIPT_SHORTNAME?}: unrecognized option '${1}'"
      execute_script='false'
      STATUS=2
      ;;

    -*)
      printf 1>&2 '%s\n' "${SCRIPT_SHORTNAME?}: invalid option -- '${1#-}'"
      execute_script='false'
      STATUS=2
      ;;

    *)
      break
      ;;
  esac

  shift
done

if test "${execute_script:?}" = 'true'; then
  show_status "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?} by ${SCRIPT_AUTHOR:?}"

  if test "${#}" -eq 0; then set -- ''; fi
  main "${@}" || STATUS="${?}"
fi

exit "${STATUS:?}"
