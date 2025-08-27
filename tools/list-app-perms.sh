#!/usr/bin/env sh
# SPDX-FileCopyrightText: (c) 2025 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

export SCRIPT_NAME='List permissions used by apps'
export SCRIPT_VERSION='0.0.3'

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

find_android_build_tool()
{
  local _tool_path

  if test -n "${2-}" && _tool_path="${2:?}"; then
    :
  elif _tool_path="$(command -v "${1:?}")" && test -n "${_tool_path?}"; then
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
  AAPT2_PATH="$(find_android_build_tool 'aapt2' "${AAPT2_PATH-}")" || AAPT_PATH="$(find_android_build_tool 'aapt' "${AAPT_PATH-}")" || :

  if test -n "${AAPT2_PATH-}"; then
    "${AAPT2_PATH:?}" dump permissions "${@}" | grep -F -e 'uses-permission: ' | cut -d ':' -f '2-' -s | cut -b '2-' | LC_ALL=C sort || return "${?}"
  elif test -n "${AAPT_PATH-}"; then
    "${AAPT_PATH:?}" dump permissions "${@}" | grep -F -e 'uses-permission: ' | cut -d ':' -f '2-' -s | cut -b '2-' | LC_ALL=C sort || return "${?}"
  else
    return 255
  fi
}

main "${@}"
pause_if_needed "${?}"
