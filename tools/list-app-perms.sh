#!/usr/bin/env sh
# @name List apps permissions
# @brief List the permissions used by Android applications
# @author ale5000
# Get the latest version from here: https://github.com/micro5k/microg-unofficial-installer/tree/main/tools

# SPDX-FileCopyrightText: (c) 2025 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

readonly SCRIPT_NAME='List apps permissions'
readonly SCRIPT_SHORTNAME='ListAppPerms'
readonly SCRIPT_VERSION='0.1.0'
readonly SCRIPT_AUTHOR='ale5000'

# shellcheck disable=SC3040 # Ignore: In POSIX sh, set option pipefail is undefined
case "$(set 2> /dev/null -o || set || :)" in *'pipefail'*) set -o pipefail || echo 1>&2 'Failed: pipefail' ;; *) ;; esac

pause_if_needed()
{
  # shellcheck disable=SC3028 # Ignore: In POSIX sh, SHLVL is undefined
  if test "${NO_PAUSE:-0}" = '0' && test "${no_pause:-0}" = '0' && test "${CI:-false}" = 'false' && test "${TERM_PROGRAM:-unknown}" != 'vscode' && test "${SHLVL:-1}" = '1' && test -t 0 && test -t 1 && test -t 2; then
    if test -n "${NO_COLOR-}"; then
      printf 1>&2 '\n%s' 'Press any key to exit... ' || :
    else
      printf 1>&2 '\n\033[1;32m\r%s' 'Press any key to exit... ' || :
    fi
    # shellcheck disable=SC3045 # Ignore: In POSIX sh, read -s / -n is undefined
    IFS='' read 2> /dev/null 1>&2 -r -s -n1 _ || IFS='' read 1>&2 -r _ || :
    printf 1>&2 '\n' || :
    test -n "${NO_COLOR-}" || printf 1>&2 '\033[0m\r    \r' || :
  fi
  unset no_pause || :
  return "${1:-0}"
}

show_status()
{
  printf 1>&2 '\033[1;32m%s\033[0m\n' "${1?}"
}

show_error()
{
  printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR: ${1?}"
}

find_android_build_tool()
{
  local _tool_path

  if _tool_path="$(command -v "${1:?}")" && test -n "${_tool_path?}"; then
    :
  elif test -n "${ANDROID_SDK_ROOT-}" && test -d "${ANDROID_SDK_ROOT:?}/build-tools" && _tool_path="$(find "${ANDROID_SDK_ROOT:?}/build-tools" -maxdepth 2 -iname "${1:?}*" | LC_ALL=C sort -V -r | head -n 1)" && test -n "${_tool_path?}"; then
    :
  else
    return 1
  fi

  printf '%s\n' "${_tool_path:?}"
}

main()
{
  test -n "${1-}" || {
    show_error "You must pass the filename of the file to be processed."
    return 3
  }

  : "${AAPT_PATH:="$(find_android_build_tool 'aapt2' || find_android_build_tool 'aapt' || :)"}"

  if test -n "${AAPT_PATH-}"; then
    "${AAPT_PATH:?}" dump permissions "${@}" | grep -F -e 'uses-permission: ' | cut -d ':' -f '2-' -s | cut -b '2-' | LC_ALL=C sort || return "${?}"
  else
    return 255
  fi
}

STATUS=0
execute_script='true'

while test "${#}" -gt 0; do
  case "${1?}" in
    -V | --version)
      printf '%s\n' "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?}"
      printf '%s\n' "Copy""right (c) 2025 ${SCRIPT_AUTHOR:?}"
      printf '%s\n' 'License GPLv3+'
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

pause_if_needed "${STATUS:?}"
exit "${?}"
