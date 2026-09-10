#!/usr/bin/env sh
# SPDX-FileCopyrightText: 2025 ale5000
# SPDX-License-Identifier: Apache-2.0 OR GPL-3.0-or-later WITH LicenseRef-Archive-packaging-exception

# @name Android app permissions lister
# @brief Dump and list the permission names declared by Android APK files.
# @description Uses aapt2 or aapt to dump and extract the uses-permission
# entries declared in one or more APK files, and prints a sorted list of
# the required permission names.
# @author ale5000

# Get the latest version from here: https://github.com/micro5k/microg-unofficial-installer/tree/main/tools

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

# @section GLOBAL CONSTANTS ----
#region
readonly SCRIPT_NAME='Android app permissions lister'
readonly SCRIPT_SHORTNAME='AppPermList'
readonly SCRIPT_VERSION='0.1.17'
readonly SCRIPT_AUTHOR='ale5000'
readonly SCRIPT_YEAR='2025'

readonly EX_USAGE=64
readonly EX_DATAERR=65
readonly EX_NOINPUT=66
readonly EX_UNAVAILABLE=69
readonly EX_OSERR=71
#endregion

set -u 2> /dev/null || :
# shellcheck disable=SC3040 # IGNORE: In POSIX sh, set option pipefail is undefined
case "$(set -o 2> /dev/null || set || :)" in *'pipefail'*) set -o pipefail || echo 1>&2 'ERROR: pipefail failed' ;; *) echo 1>&2 'WARNING: pipefail not supported' ;; esac

# @section UTILITY & UI FUNCTIONS ----
#region
fix_posix_emulation_if_needed()
{
  # Workarounds for shells using Windows-POSIX emulation layers (e.g., Git Bash under Windows)
  if test -f '/usr/bin/cygpath'; then
    # Prioritize POSIX-emulated binaries over Windows natives to prevent hangs and obscure errors
    if test "${USR_BIN_FIXED:-0}" = '0'; then
      case "${PATH-}" in '/usr/bin:'*) ;; *) PATH="/usr/bin:${PATH:-/bin}" ;; esac
    fi

    # Resolve an issue where dragging and dropping a file onto the script inexplicably resets the
    #  working directory to 'C:\WINDOWS\system32'
    # shellcheck disable=SC3028 # IGNORE: In POSIX sh, BASH_SOURCE is undefined
    if test "$(/usr/bin/cygpath -m -- "${PWD:?}" || :)" = "$(/usr/bin/cygpath -m -S || :)" && test -n "${BASH_SOURCE-}"; then
      cd "${BASH_SOURCE:?}/.." || printf 1>&2 '%s\n' 'ERROR: Failed to set the correct working directory'
    fi
  fi
}

init_colors()
{
  CLR_RESET=''
  CLR_RED=''
  CLR_GREEN=''
  CLR_YELLOW_PLAIN=''
  CLR_YELLOW=''
  CLR_CYAN=''
  CLR_LINE=''

  # shellcheck disable=SC2034 # IGNORE: 'foo' appears unused
  if test -z "${NO_COLOR-}" && test -t 2; then
    CLR_RESET='\033[0m'
    CLR_RED='\033[1;31m'
    CLR_GREEN='\033[1;32m'
    CLR_YELLOW_PLAIN='\033[0;33m'
    CLR_YELLOW='\033[1;33m'
    CLR_CYAN='\033[1;36m'
    CLR_LINE='\r        \r'
  fi
}

set_yellow_color()
{
  printf 1>&2 '%b' "${CLR_YELLOW}"
}

reset_color()
{
  printf 1>&2 '%b' "${CLR_RESET}"
}

log_status()
{
  printf 1>&2 '%b%s%b\n' "${CLR_GREEN}" "${1}" "${CLR_RESET}"
}

log_warn()
{
  printf 1>&2 '%b%s%b\n' "${CLR_YELLOW_PLAIN}" "WARNING: ${1}" "${CLR_RESET}"
}

log_err()
{
  printf 1>&2 '\n%b%s%b\n' "${CLR_RED}" "ERROR: ${1}" "${CLR_RESET}"
}

pause_if_needed()
{
  # shellcheck disable=SC3028 # IGNORE: In POSIX sh, SHLVL is undefined
  if test "${no_pause:-0}" = '0' && test "${NO_PAUSE:-0}" = '0' && test "${SHLVL:-1}" = '1' && test -t 0 && test -t 1 && test -t 2 && test "${CI:-false}" = 'false' && test "${TERM_PROGRAM:-none}" != 'vscode'; then
    case "$-" in *s*) return "${1:-0}" ;; *) ;; esac
    printf 1>&2 '\n%b%s' "${CLR_GREEN-}${CLR_LINE-}" 'Press any key to exit... ' || :
    # shellcheck disable=SC3045 # IGNORE: In POSIX sh, read -s / -n is undefined
    IFS='' read 2> /dev/null 1>&2 -r -s -n1 _ || IFS='' read 1>&2 -r _ || :
    printf 1>&2 '\n%b' "${CLR_RESET-}${CLR_LINE-}" || :
  fi
  return "${1:-0}"
}
#endregion

# @section CORE FUNCTIONS ----
#region
set_android_sdk_path_if_unset()
{
  test -z "${ANDROID_HOME-}" || return

  # Set the path of Android SDK if not already set
  if test -n "${LOCALAPPDATA-}" && test -d "${LOCALAPPDATA?}/Android/Sdk"; then
    ANDROID_HOME="${LOCALAPPDATA?}/Android/Sdk" # Windows
  elif test -n "${HOME-}" && test -d "${HOME?}/Library/Android/sdk"; then
    ANDROID_HOME="${HOME?}/Library/Android/sdk" # macOS
  elif test -n "${HOME-}" && test -d "${HOME?}/.local/share/android/sdk"; then
    ANDROID_HOME="${HOME?}/.local/share/android/sdk" # Linux (XDG)
  elif test -n "${HOME-}" && test -d "${HOME?}/Android/Sdk"; then
    ANDROID_HOME="${HOME?}/Android/Sdk" # Linux (Standard)
  elif test -d '/usr/lib/android-sdk'; then
    ANDROID_HOME='/usr/lib/android-sdk' # Linux (APT)
  fi
}

find_android_build_tool()
{
  local __fn_tool_path

  if __fn_tool_path="$(
    unalias "${1:?}" 2> /dev/null
    command 2> /dev/null -v "${1:?}"
  )" && test -n "${__fn_tool_path?}"; then
    :
  elif test -n "${ANDROID_HOME-}" && test -d "${ANDROID_HOME?}/build-tools" && __fn_tool_path="$(find "${ANDROID_HOME?}/build-tools" -maxdepth 2 -iname "${1:?}*" | sort -V -r | head -n 1)" && test -n "${__fn_tool_path?}"; then
    :
  else
    return 1
  fi

  printf '%s\n' "${__fn_tool_path:?}"
}
#endregion

# @section MAIN FUNCTION ----
#region
main()
{
  local backup_ifs="${IFS-unset}"
  local status=0 base_name='' cmd_output='' pkg_name=''

  fix_posix_emulation_if_needed

  # BEGIN: Global config (overridable via env)
  export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  set_android_sdk_path_if_unset
  export AAPT_PATH="${AAPT_PATH:-$(find_android_build_tool 'aapt2' || find_android_build_tool 'aapt' || :)}"
  # END: Global config

  if test -z "${AAPT_PATH?}"; then
    log_err 'Neither "aapt2" nor "aapt" could be found. You need to set AAPT_PATH'
    return "${EX_UNAVAILABLE?}"
  fi

  unset JAVA_TOOL_OPTIONS
  readonly NL='
'

  # Process arguments supplied via standard input when '-' is specified
  if test "$#" -eq 1 && test "${1:-empty}" = '-'; then
    IFS="${NL:?}"
    set -f || :
    # shellcheck disable=SC2046 # NOTE: Word splitting is intended here to split standard input line-by-line
    set -- $(cat || printf '%s\n' '__CAT_FAILED__' || :) ||
      {
        log_err 'Too many arguments received from standard input or shell allocation failed'
        set +f || :
        if test "${backup_ifs?}" = 'unset'; then unset IFS; else IFS="${backup_ifs}"; fi
        return "${EX_OSERR?}"
      }
    set +f || :
    if test "${backup_ifs?}" = 'unset'; then unset IFS; else IFS="${backup_ifs}"; fi
  fi

  case "${1-}" in
    '')
      log_err 'Missing required argument. Please specify one or more APK file paths to process'
      return "${EX_USAGE?}"
      ;;
    '__CAT_FAILED__')
      log_err 'Failed to read arguments from standard input'
      return "${EX_NOINPUT?}"
      ;;
    *) ;;
  esac

  while test "$#" -gt 0; do
    reset_color
    base_name="$(basename "${1:-''}" || printf '%s\n' 'unknown')"
    printf '\n%s\n\n' "Filename: ${base_name:?}"

    log_status 'Using aapt...'
    set_yellow_color
    cmd_output="$("${AAPT_PATH?}" dump permissions "${1?}")" || {
      log_err "Failed to extract package manifest metadata from '${1?}' (exit code: ${?})"
      status="${EX_DATAERR?}"
      shift
      continue
    }
    reset_color

    pkg_name="$(printf '%s\n' "${cmd_output:?}" | grep -F -e 'package: ' | cut -d ':' -f '2-' -s | cut -b '2-')" || pkg_name=''
    if test -z "${pkg_name?}"; then
      log_err "Failed to parse package name from metadata for '${1?}'"
      status="${EX_DATAERR?}"
      shift
      continue
    fi

    printf '%s\n' "${cmd_output?}" | grep -F -e 'uses-permission: ' | cut -d ':' -f '2-' -s | cut -b '2-' | LC_ALL='C.UTF-8' sort || {
      log_warn 'This APK file does NOT request any permissions'
    }
    cmd_output=''

    shift
  done

  return "${status:?}"
}
#endregion

# @section CLI ARGUMENTS PARSING ----
#region
execute_script='true'
no_pause=0
STATUS=0

while test "$#" -gt 0; do
  case "${1?}" in
    -V | --version)
      execute_script='false'
      no_pause=1
      # REUSE-IgnoreStart
      printf '%s\n' "${SCRIPT_NAME:?}, version ${SCRIPT_VERSION:?}"
      printf '%s\n' "Copyright (C) ${SCRIPT_YEAR:?} ${SCRIPT_AUTHOR:?}"
      printf '%s\n\n' 'License Apache-2.0 or GPLv3+ with APE.'
      printf '%s\n' 'There is NO WARRANTY, to the extent permitted by law.'
      # REUSE-IgnoreEnd
      ;;

    --no-pause)
      no_pause=1
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
      no_pause=1
      STATUS=2
      printf 1>&2 '%s\n' "${SCRIPT_SHORTNAME?}: unrecognized option '${1}'"
      ;;
    -*)
      execute_script='false'
      no_pause=1
      STATUS=2
      printf 1>&2 '%s\n' "${SCRIPT_SHORTNAME?}: invalid option -- '${1#-}'"
      ;;
    *) break ;;
  esac

  shift
done
#endregion

# @section EXECUTION ENTRY POINT ----
#region
if test "${execute_script:?}" = 'true'; then
  init_colors
  log_status "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?} by ${SCRIPT_AUTHOR:?}"

  test "$#" -ne 0 || set -- ''
  main "${@}" || STATUS="${?}"
  reset_color
fi

pause_if_needed "${STATUS:?}"
exit "${?}"
#endregion
