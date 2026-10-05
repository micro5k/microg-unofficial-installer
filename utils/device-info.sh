#!/usr/bin/env sh
# SPDX-FileCopyrightText: 2023 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later WITH LicenseRef-Archive-packaging-exception

# @name Android device info extractor
# @brief Extract and display hardware and software properties from ADB-connected Android devices or a build.prop-style file.
# @description Connects to every Android device detected by ADB, or reads
# from an input file, and collects a comprehensive set of device properties
# including model, manufacturer, Android version, SDK level, security patch
# date, Android ID, IMEI, and additional hardware identifiers.
#
# Results are printed to standard output; an anonymised variant is also
# available.
# @author ale5000

# Get the latest version from here: https://github.com/micro5k/microg-unofficial-installer/tree/main/utils

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

# @section GLOBAL CONSTANTS ----
#region
readonly SCRIPT_NAME='Android device info extractor'
readonly SCRIPT_SHORTNAME='DevInfo'
readonly SCRIPT_VERSION='2.9.42'
readonly SCRIPT_AUTHOR='ale5000'
readonly SCRIPT_YEAR='2023'

readonly EX_USAGE=64
readonly EX_UNAVAILABLE=69

# shellcheck disable=SC2034
{
  readonly ANDROID_4_1_SDK=16
  readonly ANDROID_4_2_SDK=17
  readonly ANDROID_4_3_SDK=18
  readonly ANDROID_4_4_SDK=19
  readonly ANDROID_4_4W_SDK=20
  readonly ANDROID_5_SDK=21
  readonly ANDROID_5_1_SDK=22
  readonly ANDROID_6_SDK=23
  readonly ANDROID_7_SDK=24
  readonly ANDROID_7_1_SDK=25
  readonly ANDROID_8_SDK=26
  readonly ANDROID_8_1_SDK=27
  readonly ANDROID_9_SDK=28
  readonly ANDROID_10_SDK=29
  readonly ANDROID_11_SDK=30
  readonly ANDROID_12_SDK=31
  readonly ANDROID_12_1_SDK=32
  readonly ANDROID_13_SDK=33
  readonly ANDROID_14_SDK=34
  readonly ANDROID_15_SDK=35 # Not yet released
}

readonly NL='
'
#endregion

set -u 2> /dev/null || :
# shellcheck disable=SC3040 # IGNORE: In POSIX sh, set option pipefail is undefined
case "$(set -o 2> /dev/null || set || :)" in *'pipefail'*) set -o pipefail || echo 1>&2 'ERROR: pipefail failed' ;; *) echo 1>&2 'WARNING: pipefail not supported' ;; esac
# shellcheck disable=SC3040 # IGNORE: In POSIX sh, set option 'foo' is undefined
if test -f '/usr/bin/cygpath'; then
  # IMPORTANT: Double-clicking a script file on Windows opens Bash as an interactive shell and enables 'monitor', 'history' and 'histexpand' contrary to any logic
  set +o monitor || :
  (set +o history 2> /dev/null) && set +o history || :
  (set +o histexpand 2> /dev/null) && set +o histexpand || :
fi

# @section TERMINAL SETUP & LOGGING FUNCTIONS ----
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
      cd "${BASH_SOURCE?}/.." || printf 1>&2 '%s\n' 'ERROR: Failed to set the correct working directory'
    fi
  fi
  return 0
}

set_utf8_codepage()
{
  if command -v 'chcp.com' 1> /dev/null 2>&1 && PREVIOUS_CODEPAGE="$(chcp.com 2> /dev/null | cut -d ':' -f '2' -s | tr -d ' \r')" && test "${PREVIOUS_CODEPAGE}" -ne 65001; then
    'chcp.com' 1> /dev/null 65001 || :
  else
    PREVIOUS_CODEPAGE=''
  fi
  return 0
}

restore_codepage()
{
  if test -n "${PREVIOUS_CODEPAGE-}"; then
    'chcp.com' 1> /dev/null "${PREVIOUS_CODEPAGE}" || :
    PREVIOUS_CODEPAGE=''
  fi
  return 0
}

color_init()
{
  CLR_RESET=''
  CLR_RED=''
  CLR_GREEN_PLAIN=''
  CLR_GREEN=''
  CLR_YELLOW_PLAIN=''
  CLR_YELLOW=''
  CLR_YELLOW_BG_BLUE=''
  CLR_MAGENTA=''
  CLR_CYAN=''
  CLR_LINE=''

  # IMPORTANT: Unlike other scripts, colors are disabled globally across both STDOUT and STDERR if either stream is redirected to a non-TTY target

  # shellcheck disable=SC2034 # IGNORE: 'foo' appears unused
  if test -z "${NO_COLOR-}" && test -t 1 && test -t 2; then
    CLR_RESET='\033[0m'
    CLR_RED='\033[1;31m'
    CLR_GREEN_PLAIN='\033[32m'
    CLR_GREEN='\033[1;32m'
    CLR_YELLOW_PLAIN='\033[33m'
    CLR_YELLOW='\033[1;33m'
    CLR_YELLOW_BG_BLUE='\033[1;33;44m'
    CLR_MAGENTA='\033[1;35m'
    CLR_CYAN='\033[1;36m'
    CLR_LINE='\r        \r'
  fi
  return 0
}

log_scope_init()
{
  LOG_LEVEL=0
  return 0
}

# shellcheck disable=SC2329 # NOTE: Standard boilerplate function; may not be executed in this specific script
log_scope_begin()
{
  LOG_LEVEL="$((LOG_LEVEL + 2))"
  return 0
}

# shellcheck disable=SC2329 # NOTE: Standard boilerplate function; may not be executed in this specific script
log_scope_end()
{
  test "${LOG_LEVEL}" -lt 2 || LOG_LEVEL="$((LOG_LEVEL - 2))"
  return 0
}

log_out_selected_device()
{
  printf '%b%s%b\n\n' "${CLR_YELLOW_BG_BLUE}" "SELECTED: ${1}" "${CLR_RESET}"
  return 0
}

log_out_section()
{
  printf '%b%s%b\n' "${CLR_CYAN}" "${1}" "${CLR_RESET}"
  return 0
}

log_out()
{
  printf '%*s%s\n' "${LOG_LEVEL}" '' "${1}"
}

log_out_blank()
{
  printf '\n'
  return 0
}

log_status()
{
  case "${FD}" in
    2) printf 1>&2 '%b%s%b\n' "${CLR_GREEN}" "${1}" "${CLR_RESET}" ;;
    *) printf 1>&3 '%b%s%b\n' "${CLR_GREEN}" "${1}" "${CLR_RESET}" ;;
  esac
  return 0
}

log_blank()
{
  printf 1>&2 '\n'
  return 0
}

log_warn()
{
  case "${FD}" in
    2) printf 1>&2 '%b%*s%s%b\n' "${CLR_YELLOW_PLAIN}" "${LOG_LEVEL}" '' "WARNING: ${1}" "${CLR_RESET}" ;;
    *) printf 1>&3 '%b%*s%s%b\n' "${CLR_YELLOW_PLAIN}" "${LOG_LEVEL}" '' "WARNING: ${1}" "${CLR_RESET}" ;;
  esac
  return 0
}

log_non_fatal()
{
  case "${FD}" in
    2) printf 1>&2 '%b%*s%s%b\n' "${CLR_MAGENTA}" "${LOG_LEVEL}" '' "NON-FATAL ERROR: ${1}" "${CLR_RESET}" ;;
    *) printf 1>&3 '%b%*s%s%b\n' "${CLR_MAGENTA}" "${LOG_LEVEL}" '' "NON-FATAL ERROR: ${1}" "${CLR_RESET}" ;;
  esac
  return 0
}

log_err()
{
  case "${FD}" in
    2) printf 1>&2 '\n%b%s%b\n' "${CLR_RED}" "ERROR: ${1}" "${CLR_RESET}" ;;
    *) printf 1>&3 '\n%b%s%b\n' "${CLR_RED}" "ERROR: ${1}" "${CLR_RESET}" ;;
  esac
  return 0
}

dev_status_init()
{
  DEV_WAIT_SEEN=0
  return 0
}

dev_status_done()
{
  test "${DEV_WAIT_SEEN?}" = 0 || printf 1>&2 '\n'
  unset DEV_WAIT_SEEN
  return 0
}

dev_status_not_ready()
{
  if test "${DEV_WAIT_SEEN?}" = 0; then
    DEV_WAIT_SEEN=1
    printf 1>&2 '%b%s%b' "${CLR_GREEN}" 'Device is not ready, waiting.' "${CLR_RESET}"
  else
    printf 1>&2 '%b%s%b' "${CLR_GREEN}" '.' "${CLR_RESET}"
  fi
  return 0
}

dev_status_waiting()
{
  if test "${DEV_WAIT_SEEN?}" = 0; then
    printf 1>&2 '%b%s%b\n' "${CLR_GREEN}" 'Waiting for the device...' "${CLR_RESET}"
  else
    printf 1>&2 '%b%s%b' "${CLR_GREEN_PLAIN}" '.' "${CLR_RESET}"
  fi
  return 0
}

set_title()
{
  if test "${CI:-false}" != 'false'; then return 1; fi
  TITLE_SET='true'

  if command 1> /dev/null -v title; then
    PREVIOUS_TITLE="$(title)" # Save current title
    title "${1:?}"            # Set new title
  elif test -t 1; then
    printf '\033[22;0t\r' && printf '       \r'                         # Save current title on stack
    printf '\033]0;%s\007\r' "${1:?}" && printf '    %*s \r' "${#1}" '' # Set new title
  elif test -t 2; then
    printf 1>&2 '\033[22;0t\r' && printf 1>&2 '       \r'                         # Save current title on stack
    printf 1>&2 '\033]0;%s\007\r' "${1:?}" && printf 1>&2 '    %*s \r' "${#1}" '' # Set new title
  else
    TITLE_SET='false'
  fi
}

restore_title()
{
  if test "${CI:-false}" != 'false' || test "${TITLE_SET:-false}" = 'false'; then return 1; fi

  if command 1> /dev/null -v title; then
    title "${PREVIOUS_TITLE-}" # Restore saved title
    PREVIOUS_TITLE=''
  elif test -t 1; then
    printf '\033]0;\007\r' && printf '     \r'  # Set empty title (fallback in case saving/restoring title doesn't work)
    printf '\033[23;0t\r' && printf '       \r' # Restore title from stack
  elif test -t 2; then
    printf 1>&2 '\033]0;\007\r' && printf 1>&2 '     \r'  # Set empty title (fallback in case saving/restoring title doesn't work)
    printf 1>&2 '\033[23;0t\r' && printf 1>&2 '       \r' # Restore title from stack
  fi

  TITLE_SET='false'
}

init()
{
  export LANG='en_US.UTF-8'
  set_utf8_codepage
  fix_posix_emulation_if_needed
  color_init
  log_scope_init

  FD=2
  if test "${DEBUG:-0}" != 0; then
    exec 3>&1 # Duplicate STDOUT to FD 3 to ensure output can reach the original destination without being intercepted by a command substitution
    FD=3
  fi
  return 0
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

# @section ANDROID SDK FUNCTIONS ----
#region
set_android_sdk_path_if_unset()
{
  : "${ANDROID_HOME:=${ANDROID_SDK_ROOT-}}"
  test -z "${ANDROID_HOME}" || return 0

  # Set the path of Android SDK if not already set
  if test -n "${LOCALAPPDATA-}" && test -d "${LOCALAPPDATA}/Android/Sdk"; then
    ANDROID_HOME="${LOCALAPPDATA?}/Android/Sdk" # Windows
  elif test -n "${HOME-}" && test -d "${HOME}/Library/Android/sdk"; then
    ANDROID_HOME="${HOME?}/Library/Android/sdk" # macOS
  elif test -n "${HOME-}" && test -d "${HOME}/.local/share/android/sdk"; then
    ANDROID_HOME="${HOME?}/.local/share/android/sdk" # Linux (XDG standard)
  elif test -n "${HOME-}" && test -d "${HOME}/Android/Sdk"; then
    ANDROID_HOME="${HOME?}/Android/Sdk" # Linux (Standard)
  elif test -d '/opt/android-sdk'; then
    ANDROID_HOME='/opt/android-sdk' # Linux (Global)
  elif test -d '/usr/lib/android-sdk'; then
    ANDROID_HOME='/usr/lib/android-sdk' # Linux (apt)
  elif test -d '/usr/local/lib/android/sdk'; then
    ANDROID_HOME='/usr/local/lib/android/sdk' # FreeBSD / Linux (Global alternative)
  else
    ANDROID_HOME=''
  fi
  return 0
}
#endregion

# @section STORAGE & DIRECTORY FUNCTIONS ----
#region
resolve_data_dir()
{
  local __fn_path=''

  # shellcheck disable=SC3028,SC2128 # IGNORE: In POSIX sh, BASH_SOURCE is undefined / Expanding an array without an index only gives the first element
  if test -n "${UTILS_DATA_DIR-}" && __fn_path="${UTILS_DATA_DIR}"; then
    :
  elif test -n "${BASH_SOURCE-}" && test -f "${BASH_SOURCE}" && __fn_path="$(dirname "${BASH_SOURCE}")/data"; then
    : # NOTE: Index omitted intentionally; we explicitly want the first element only
  elif test -n "${0-}" && test -f "${0}" && __fn_path="$(dirname "${0}")/data"; then
    :
  else
    __fn_path='./data'
  fi

  __fn_path="$(realpath 2> /dev/null "${__fn_path}" || readlink -f "${__fn_path}")" || return 1
  printf '%s\n' "${__fn_path:?}"
  return 0
}
#endregion

verify_adb()
{
  local __fn_pathsep=':'

  if command -v 'adb' 1> /dev/null 2>&1; then
    return 0
  fi

  set_android_sdk_path_if_unset

  if test -n "${ANDROID_HOME-}"; then
    if test "$(uname -o 2> /dev/null | tr '[:upper:]' '[:lower:]' || :)" = 'ms/windows'; then __fn_pathsep=';'; fi # BusyBox-w32

    export PATH="${ANDROID_HOME?}/platform-tools${__fn_pathsep?}${PATH:-/usr/bin}"

    if command -v 'adb' 1> /dev/null 2>&1; then
      return 0
    fi
  fi

  return 1
}

verify_adb_mode_deps()
{
  verify_adb || {
    log_err 'adb is required'
    return "${EX_UNAVAILABLE?}"
  }
  command -v 'timeout' 1> /dev/null 2>&1 || {
    log_err 'timeout is required'
    return "${EX_UNAVAILABLE?}"
  }
  return 0
}

start_adb_server()
{
  case "${PROP_TYPE}" in A) ;; *) return 1 ;; esac
  adb 2> /dev/null 'start-server'
  return "$?"
}

parse_device_status()
{
  case "${1?}" in
    'device' | 'recovery') return 0 ;;                             # OK
    *'connecting'* | *'authorizing'* | *'offline'*) return 1 ;;    # Connecting (transitory) / Authorizing (transitory) / Offline (may be transitory)
    *'unauthorized'*) return 2 ;;                                  # Unauthorized
    *'not found'* | 'disconnect') return 3 ;;                      # Disconnected (transitory after 'root', 'unroot' or 'reconnect' otherwise unrecoverable)
    *'no permissions'* | *'insufficient permissions'*) return 4 ;; # ADB configuration issue under Linux (unrecoverable)
    *'no device'*) return 4 ;;                                     # No devices/emulators (unrecoverable)
    *'closed'*) return 4 ;;                                        # ADB connection forcibly terminated on device side
    *'protocol fault'*) return 4 ;;                                # ADB connection forcibly terminated on server side
    '') return 4 ;;                                                # Unknown issue
    'sideload' | 'rescue' | 'bootloader') return 5 ;;              # Sideload / Rescue / Bootloader (not supported)
    *) ;;                                                          # Unknown (ignored)
  esac
  return 0
}

# Possible status:
# - device
# - recovery
# - unauthorized
# - authorizing
# - offline
# - no permissions
# - no device
# - unknown
# - error: device unauthorized.
# - error: device still authorizing
# - error: device offline
# - error: device 'xxx' not found
# - error: insufficient permissions for device
# - error: no devices/emulators found
# - error: closed
# - error: protocol fault (couldn't read status): connection reset

detect_status_and_wait_connection()
{
  local __fn_dev_state='' __fn_recon='false'

  if test "${2:-1}" = 1; then DEVICE_STATE='unknown'; fi
  dev_status_init

  : "${1:?}" # Ensure $1 is set and non-empty

  for _ in 1 2 3 4 5 6 7 8 9 10; do
    __fn_dev_state="$(LC_ALL=C adb 2>&1 -s "${1}" 'get-state' | LC_ALL=C tr -d '\r' || :)"
    parse_device_status "${__fn_dev_state}"
    case "$?" in
      1) dev_status_not_ready ;; # Wait up to 5 seconds for transient states (10 attempts * 0.5 sec sleep)
      2)
        dev_status_not_ready
        if test "${__fn_recon}" = 'false'; then
          __fn_recon='true'
          # Force reconnect if the device is unauthorized, then wait 5 sec for the authentication prompt
          adb 1> /dev/null 2>&1 -s "${1}" reconnect offline && sleep 5 || :
        fi
        ;;
      3)
        if test "${2:-1}" != 1; then
          # NOTE: Device might temporarily disappear for a few seconds after commands like 'adb root', 'adb unroot', or 'adb reconnect'
          dev_status_not_ready
        else
          break
        fi
        ;;
      *) break ;;
    esac

    sleep 2> /dev/null '0.5' || sleep 1 || break
  done

  # Previous loop terminates with success or critical error (recoverable errors already handled at this point)
  parse_device_status "${__fn_dev_state}"
  if test "$?" -ne 0; then
    dev_status_done
    return 10
  fi

  if test "${2:-1}" = 1; then
    case "${__fn_dev_state}" in
      'device' | 'recovery' | 'sideload' | 'rescue' | 'bootloader') DEVICE_STATE="${__fn_dev_state?}" ;;
      *)
        dev_status_done
        log_err "Unexpected device state: '${__fn_dev_state?}'"
        return 11
        ;;
    esac
  elif test "${__fn_dev_state?}" != "${DEVICE_STATE?}"; then
    dev_status_done
    log_err "Device state mismatch: expected '${DEVICE_STATE?}', got '${__fn_dev_state?}'"
    return 12
  fi

  dev_status_waiting
  dev_status_done
  adb 2> /dev/null -s "${1:?}" "wait-for-${DEVICE_STATE?}"
  return "$?"
}

is_timeout()
{
  if test "${1:?}" -eq 124 || test "${1:?}" -eq 143; then
    return 0 # Timed out
  fi

  return 1 # OK
}

adb_unfroze()
{
  case "${PROP_TYPE}" in A) ;; *) return 0 ;; esac
  log_non_fatal 'adb was frozen, reconnecting...'
  adb 1> /dev/null 2>&1 -s "${1:?}" reconnect # Root and unroot commands may freeze the adb connection of some devices, workaround the problem
  detect_status_and_wait_connection "${1:?}" 0
}

adb_root()
{
  case "${PROP_TYPE}" in A) ;; *) return 0 ;; esac
  if test "$(adb 2>&1 -s "${1:?}" shell 'whoami' | LC_ALL=C tr -d '\r' || true)" = 'root'; then return 0; fi # Already rooted

  timeout 1> /dev/null 2>&1 -- 6 adb -s "${1:?}" root
  if is_timeout "$?"; then
    adb_unfroze "${1:?}"
    return 0
  fi

  detect_status_and_wait_connection "${1:?}" 0

  # Dummy command to check if adb is frozen
  timeout -- 3 adb -s "${1:?}" shell ':'
  if is_timeout "$?"; then adb_unfroze "${1:?}"; fi
}

is_all_zeros()
{
  if test -n "${1?}" && test "$(printf '%s\n' "${1:?}" | tr -d '0' || true)" = ''; then
    return 0 # True
  fi

  return 1 # False
}

is_valid_value()
{
  case "${1}" in
    '' | 'unknown') return 1 ;;
    *) ;;
  esac
  return 0
}

is_valid_length()
{
  if test "${#1}" -lt "${2:?}" || test "${#1}" -gt "${3:?}"; then
    return 1 # NOT valid
  fi

  return 0 # Valid
}

lc_text()
{
  printf '%s' "${1}" | tr '[:upper:]' '[:lower:]'
  return "$?"
}

compare_nocase()
{
  if test "$(lc_text "${1?}" || true)" = "$(lc_text "${2?}" || true)"; then
    return 0 # True
  fi

  return 1 # False
}

contains()
{
  case "${2?}" in
    *"${1:?}"*) return 0 ;; # Found
    *) ;;                   # NOT found
  esac
  return 1 # NOT found
}

trim_space_left()
{
  local _var
  _var="$(cat)" || return 1

  printf '%s\n' "${_var# }"
  return 0
}

trim_space_on_sides()
{
  local _var
  _var="$(cat -u)" || return 1
  test "${#_var}" -gt 0 || return 1

  _var="${_var# }"
  printf '%s' "${_var% }"
}

convert_dec_to_hex()
{
  if test -z "${1?}"; then return; fi

  if command 1> /dev/null -v bc; then
    printf 'obase=16;%s\n' "${1?}" | bc -s | tr '[:upper:]' '[:lower:]'
  else
    printf '%x\n' "${1?}"
  fi
}

anonymize_string()
{
  printf '%s\n' "${1?}" | tr '[:digit:]' '0' | tr 'a-f' 'f' | tr 'g-z' 'x' | tr 'A-F' 'F' | tr 'G-Z' 'X'
}

anonymize_code()
{
  local _string _prefix_length

  if test "${#1}" -lt 2; then
    anonymize_string "${1?}"
    return
  fi

  _prefix_length="$((${#1} / 2))"
  if test "${_prefix_length:?}" -gt 6; then _prefix_length='6'; fi

  printf '%s\n' "${1:?}" | cut -c "-${_prefix_length:?}" | LC_ALL=C tr -d '\n'

  _string="$(printf '%s\n' "${1:?}" | cut -c "$((${_prefix_length:?} + 1))-")"
  anonymize_string "${_string:?}"
}

is_valid_serial()
{
  if test "${#1}" -lt 2 || is_all_zeros "${1:?}"; then
    return 1 # NOT valid
  fi

  return 0 # Valid
}

is_valid_android_id()
{
  if test "${#1}" -ne 16 || test "${1:?}" = '9774d56d682e549c'; then
    return 1 # NOT valid
  fi

  return 0 # Valid
}

is_valid_imei()
{
  # We should have also checked the following invalid value: null
  # but it is already excluded from the length check.
  if test "${#1}" -ne 15 || test "${1:?}" = '000000000000000' || test "${1:?}" = '004999010640000'; then
    return 1 # NOT valid
  fi

  return 0 # Valid
}

is_valid_line_number()
{
  if printf '%s\n' "${1?}" | grep -q -e '^+\{0,1\}[0-9-]\{5,15\}$'; then
    return 0 # Valid
  fi

  return 1 # NOT valid
}

is_valid_color()
{
  if test -z "${1?}" || compare_nocase "${1:?}" 'Unknown touchpad'; then
    return 1 # NOT valid
  fi

  return 0 # Valid
}

# shellcheck disable=SC2329
get_device_live_prop()
{
  RET_VAL="$(adb -s "${1}" shell "getprop '${2}'" | LC_ALL=C tr -d '\r')" || return 1
  return 0
}

dump_device_props()
{
  adb -s "${1}" shell 'getprop' | LC_ALL=C tr -d '\r'
}

get_device_cached_prop()
{
  : "${ALL_PROPS:=$(dump_device_props "${1}" || log_err 'dump_device_props() failed' || :)}"
  RET_VAL="$(printf '%s\n' "${ALL_PROPS}" | sed -n -e '/^\['"${2}"'\]:/ { p' -e ':a' -e 'n' -e 'ba' -e '}' | LC_ALL=C cut -d ':' -f '2-' -s)" || return 1
  RET_VAL="${RET_VAL#" ["}"
  RET_VAL="${RET_VAL%"]"}"
  return 0
}

parse_getprop_dump()
{
  RET_VAL="$(grep -m 1 -e '^\['"${2}"'\]:' -- "${1}" | LC_ALL=C cut -d ':' -f '2-' -s | LC_ALL=C tr -d '\r')" || return 1
  RET_VAL="${RET_VAL#" ["}"
  RET_VAL="${RET_VAL%"]"}"
  return 0
}

parse_build_prop()
{
  RET_VAL="$(grep -m 1 -e "^${2}=" -- "${1}" | LC_ALL=C cut -d '=' -f '2-' -s | LC_ALL=C tr -d '\r')" || return 1
  return 0
}

prop_get()
{
  RET_VAL=''
  case "${PROP_TYPE}" in
    A) get_device_cached_prop "${SELECTED_DEVICE}" "${1}" || return 1 ;;
    G) parse_getprop_dump "${SELECTED_DEVICE}" "${1}" || return 1 ;;
    B) parse_build_prop "${SELECTED_DEVICE}" "${1}" || return 1 ;;
    *) return 2 ;;
  esac
  return 0
}

# Deprecated
auto_getprop_legacy()
{
  prop_get "${1}" || return "$?"
  printf '%s\n' "${RET_VAL?}"
  return 0
}

is_boot_completed()
{
  prop_get 'sys.boot_completed' || return 1
  case "${RET_VAL?}" in
    1) return 0 ;;
    *) ;;
  esac
  return 1
}

ensure_boot_completed()
{
  case "${PROP_TYPE?}" in
    A)
      if test "${DEVICE_STATE?}" = 'device'; then
        is_boot_completed || {
          log_warn 'Device has not finished booting yet, skipped'
          return 1
        }
      fi
      ;;
    G)
      is_boot_completed || {
        log_err 'Getprop comes from a device that has not finished booting yet, skipped'
        return 1
      }
      ;;
    *) ;;
  esac
  return 0
}

get_and_check_prop()
{
  prop_get "${1}" || RET_VAL=''
  case "${RET_VAL}" in
    '' | 'unknown')
      log_non_fatal "The value of property '${1?}' is missing or invalid"
      return 1
      ;;
    *) ;;
  esac
  printf '%s\n' "${RET_VAL}"
  return 0
}

get_and_check_prop_silent()
{
  prop_get "${1}" || return 1
  case "${RET_VAL}" in
    '' | 'unknown') return 1 ;;
    *) ;;
  esac
  printf '%s\n' "${RET_VAL}"
  return 0
}

device_get_file_content()
{
  case "${PROP_TYPE}" in A) ;; *) return 1 ;; esac
  adb -s "${1:?}" shell "test -r '${2:?}' && cat '${2}'" | LC_ALL=C tr -d '\r'
}

find_serialno()
{
  local _val

  if compare_nocase "${BUILD_MANUFACTURER?}" 'Lenovo' && _val="$(auto_getprop_legacy 'ro.lenovosn2')" && is_valid_serial "${_val?}"; then # Lenovo tablets
    :
  elif _val="$(auto_getprop_legacy 'ril.serialnumber')" && is_valid_serial "${_val?}"; then # Samsung phones / tablets (possibly others)
    :
  elif _val="$(auto_getprop_legacy 'ro.ril.oem.psno')" && is_valid_serial "${_val?}"; then # Xiaomi phones (possibly others)
    :
  elif _val="$(auto_getprop_legacy 'ro.ril.oem.sno')" && is_valid_serial "${_val?}"; then # Xiaomi phones (possibly others)
    :
  elif _val="$(auto_getprop_legacy 'ro.serialno')" && is_valid_serial "${_val?}"; then
    :
  elif _val="$(auto_getprop_legacy 'sys.serialnumber')" && is_valid_serial "${_val?}"; then
    :
  elif _val="$(auto_getprop_legacy 'ro.boot.serialno')" && is_valid_serial "${_val?}"; then
    :
  elif _val="$(auto_getprop_legacy 'ro.kernel.androidboot.serialno')" && is_valid_serial "${_val?}"; then
    :
  else
    return 1
  fi

  printf '%s' "${_val?}"
}

find_cpu_serialno()
{
  local _val

  if _val="$(device_get_file_content "${1:?}" '/proc/cpuinfo' | grep -i -F -e "serial" | cut -d ':' -f '2-' -s | trim_space_on_sides)" && is_valid_serial "${_val?}"; then
    :
  else
    return 1
  fi

  printf '%s' "${_val?}"
}

get_android_id()
{
  local _val
  _val="$(device_shell "${1:?}" 'settings 2> /dev/null get secure android_id')" && test -n "${_val?}" && printf '%016x' "0x${_val:?}"
}

get_gsf_id()
{
  local _val _my_command
  case "${PROP_TYPE}" in A) ;; *) return 1 ;; esac

  # We want this without expansion, since it will happens later inside adb shell
  # shellcheck disable=SC2016
  _my_command='PATH="${PATH:-/sbin}:/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin"; export PATH; readonly my_query="SELECT * FROM main WHERE name = \"android_id\";"; { test -e "/data/data/com.google.android.gsf/databases/gservices.db" && sqlite3 2> /dev/null -line "/data/data/com.google.android.gsf/databases/gservices.db" "${my_query?}"; } || { test -e "/data/data/com.google.android.gms/databases/gservices.db" && sqlite3 2> /dev/null -line "/data/data/com.google.android.gms/databases/gservices.db" "${my_query?}"; }'

  _val="$(adb -s "${1:?}" shell "${_my_command:?}")" || _val=''
  if test -z "${_val?}"; then
    _val="$(adb -s "${1:?}" shell "su 2> /dev/null 0 sh -c '${_my_command:?}'")" || _val=''
  fi

  test -n "${_val?}" || return 1
  _val="$(printf '%s' "${_val?}" | grep -m 1 -e 'value' | cut -d '=' -f '2-' -s)"

  printf '%s' "${_val# }"
}

get_advertising_id()
{
  local adid
  case "${PROP_TYPE}" in A) ;; *) return 1 ;; esac

  adid="$(adb -s "${1:?}" shell 'cat "/data/data/com.google.android.gms/shared_prefs/adid_settings.xml" 2> /dev/null')" || adid=''
  test "${adid?}" != '' || return 1

  adid="$(printf '%s' "${adid?}" | grep -m 1 -o -e '"adid_key"[^<]*' | grep -o -e ">.*$")"

  printf '%s' "${adid#>}"
}

get_device_color()
{
  local _val

  if _val="$(auto_getprop_legacy 'ro.config.devicecolor')" && is_valid_color "${_val?}"; then # Huawei (possibly others)
    :
  elif _val="$(auto_getprop_legacy 'vendor.panel.color')" && is_valid_color "${_val?}"; then # Xiaomi (possibly others)
    :
  elif _val="$(auto_getprop_legacy 'sys.panel.color')" && is_valid_color "${_val?}"; then # Xiaomi (possibly others)
    :
  else
    _val=''
  fi

  display_info_or_warn 'Device color' "${_val?}" 0 'non-sensitive'
}

get_device_back_color()
{
  local _val

  if _val="$(auto_getprop_legacy 'ro.config.backcolor')" && is_valid_color "${_val?}"; then # Huawei (possibly others)
    :
  else
    _val=''
  fi

  display_info_or_warn 'Device back color' "${_val?}" 0 'non-sensitive'
}

device_shell()
{
  local __fn_dev="${1:?}"
  case "${PROP_TYPE}" in A) ;; *) return 1 ;; esac

  shift
  case "${1-}" in '') return 2 ;; *) ;; esac
  adb -s "${__fn_dev}" shell "$*" | LC_ALL=C tr -d '\r'
  return "$?"
}

device_get_devpath()
{
  local _val
  case "${PROP_TYPE}" in A) ;; *) return 1 ;; esac

  if _val="$(adb -s "${1:?}" 'get-devpath' | LC_ALL=C tr -d '\r')" && test "${_val?}" != 'unknown'; then
    printf '%s\n' "${_val?}"
    return 0
  fi

  return 1
}

apply_phonesubinfo_deviation()
{
  local __fn_mcode="${1:?}"

  if compare_nocase "${BUILD_MANUFACTURER?}" 'HUAWEI' && test "${BUILD_VERSION_SDK:?}" -eq "${ANDROID_9_SDK:?}"; then
    if test "${1:?}" -ge 3; then __fn_mcode="$((__fn_mcode + 1))"; fi
  elif compare_nocase "${BUILD_MANUFACTURER?}" 'samsung' && test "${BUILD_VERSION_SDK:?}" -eq "${ANDROID_11_SDK:?}"; then
    # Seen on Samsung Galaxy A50 (Android 11)
    # An unknown method at position 11 shift everything by 1
    if test "${1:?}" -ge 11; then __fn_mcode="$((__fn_mcode + 1))"; fi
  fi

  printf '%s' "${__fn_mcode}"
}

call_phonesubinfo()
{
  local __fn_dev="${1:?}" __fn_mcode
  case "${PROP_TYPE}" in A) ;; *) return 1 ;; esac

  __fn_mcode="$(apply_phonesubinfo_deviation "${2}")" || return 2
  shift 2

  test "$#" -ne 0 || set -- '' # Avoid issues on Bash under Mac
  adb -s "${__fn_dev}" shell "service call iphonesubinfo ${__fn_mcode} $*" | LC_ALL=C cut -d "'" -f 2 -s | LC_ALL=C tr -d -s -- '.[:cntrl:]' ' ' | trim_space_on_sides
}
# https://android.googlesource.com/platform/frameworks/base/+/master/telephony/java/com/android/internal/telephony/IPhoneSubInfo.aidl
# https://android.googlesource.com/platform/frameworks/opt/telephony/+/master/src/java/com/android/internal/telephony/PhoneSubInfoController.java
# https://android.googlesource.com/platform/frameworks/opt/telephony/+/master/src/java/com/android/internal/telephony/PhoneFactory.java
# https://android.googlesource.com/platform/frameworks/base/+/master/telephony/java/android/telephony/SubscriptionManager.java

is_phonesubinfo_response_valid()
{
  if test -z "${1?}" || contains 'Requires READ_PHONE_STATE' "${1?}" || contains 'does not belong to' "${1?}" || contains 'Parcel data not fully consumed' "${1?}"; then
    return 1
  fi

  return 0
}

display_info()
{
  log_out "${1?}: ${2?}"
}

display_info_or_warn()
{
  local _is_valid
  _is_valid="${3:?}" # It is a return value, so 0 is true

  if test -z "${2?}"; then
    log_warn "${1?} not found"
    return 1
  fi

  if test "${_is_valid:?}" -ne 0; then
    log_warn "Invalid ${1?}: ${2?}"
    return 2
  fi

  if test "${PRIVACY_MODE?}" = 'true' && test "${4:-}" != 'non-sensitive'; then
    display_info "${1?}" "$(anonymize_code "${2?}" || true)"
  else
    display_info "${1?}" "${2?}"
  fi
  return 0
}

display_phonesubinfo_or_warn()
{
  local _is_valid
  _is_valid="${3:?}" # It is a return value, so 0 is true

  if test -z "${2?}"; then
    log_warn "${1?} not found"
    return 1
  fi

  if ! is_phonesubinfo_response_valid "${2?}"; then
    local _err
    _err="$(printf '%s\n' "${2?}" | cut -c '2-70')"
    log_warn "Cannot find ${1?} due to '${_err?}'"
    return 3
  fi

  if test "${_is_valid:?}" -ne 0; then
    log_warn "Invalid ${1?}: ${2?}"
    return 2
  fi

  if test "${PRIVACY_MODE?}" = 'true' && test "${4:-}" != 'non-sensitive'; then
    display_info "${1?}" "$(anonymize_code "${2?}" || true)"
  else
    display_info "${1?}" "${2?}"
  fi
  return 0
}

# Deprecated
validate_and_display_info()
{
  if ! is_valid_value "${2?}"; then
    log_warn "${1:-} not found"
    return 1
  fi

  if ! is_phonesubinfo_response_valid "${2?}"; then
    local _err
    _err="$(printf '%s\n' "${2?}" | cut -c '2-69')"
    log_warn "Cannot find ${1:-} due to '${_err:-}'"
    return 3
  fi

  if test -n "${4:-}"; then
    if test "${#2}" -lt "${3?}" || test "${#2}" -gt "${4?}"; then
      log_warn "Invalid ${1:-}: ${2:-}"
      return 2
    fi
  elif test -n "${3:-}" && test "${#2}" -ne "${3?}"; then
    log_warn "Invalid ${1:-}: ${2:-}"
    return 2
  fi

  log_out "${1?}: ${2?}"
}

open_device_status_info()
{
  local _device
  case "${PROP_TYPE}" in A) ;; *) return 1 ;; esac

  _device="${1:?}"

  log_status 'Opening About phone > Status...'

  adb -s "${_device:?}" shell 'svc 2> /dev/null power stayon true'

  # ==============================================
  # ANDROID LOCKSCREEN DETECTION STRINGS REFERENCE
  # ==============================================
  # - mShowingLockscreen  -> Android 4.0 to 11 (Standard AOSP flag)
  # - mKeyguardShowing    -> Android 4.4 to 9  (Legacy window policy flag)
  # - mDreamingLockscreen -> Android 6.0 to 11 (Active during ambient mode)
  # - isStatusBarKeyguard -> Android 7.0 to 11 (Status bar container state)
  # - isKeyguardShowing   -> Android 10 to 13  (Refactored API variable)
  # - KeyguardShowing     -> Android 12 to 17  (Modern SystemUI refactored output)
  # ==============================================

  adb -s "${_device:?}" shell '
    input keyevent KEYCODE_WAKEUP || :

    # If the screen is locked then unlock it (only swipe is supported)
    if dumpsys window policy 2>/dev/null | grep -q -F -e "mShowingLockscreen=true" -e "mKeyguardShowing=true" -e "mDreamingLockscreen=true" -e "isStatusBarKeyguard=true" -e "isKeyguardShowing=true" -e "KeyguardShowing=true"; then
      echo 1>&2 "Device is locked. Unlocking screen..."
      input swipe 200 650 200 0
    elif ! dumpsys window policy 2>/dev/null | grep -q -F -e "mShowingLockscreen=" -e "mKeyguardShowing=" -e "mDreamingLockscreen=" -e "isStatusBarKeyguard=" -e "isKeyguardShowing=" -e "KeyguardShowing="; then
      echo 1>&2 "ERROR: Failed to determine lockscreen status."
      exit 3
    fi

    am 1> /dev/null 2>&1 start -a "android.settings.DEVICE_INFO_SETTINGS"
    input 2> /dev/null keyevent KEYCODE_BACK

    # If we are still in Android settings, let it go back again
    if uiautomator 2> /dev/null dump --compressed "/proc/self/fd/1" | grep -q -F -e "package=\"com.android.settings\""; then
      input 2> /dev/null keyevent KEYCODE_BACK
    fi

    am start -a "android.settings.DEVICE_INFO_SETTINGS"

    input 2> /dev/null keyevent KEYCODE_DPAD_UP
    input 2> /dev/null keyevent KEYCODE_DPAD_UP
    input 2> /dev/null keyevent KEYCODE_DPAD_UP
    input 2> /dev/null keyevent KEYCODE_DPAD_DOWN
    input 2> /dev/null keyevent KEYCODE_ENTER
  '

  adb -s "${_device:?}" shell 'svc 2> /dev/null power stayon false'
}

get_kernel_version()
{
  local _val
  case "${PROP_TYPE}" in A) ;; *) return 1 ;; esac

  if _val="$(adb -s "${1:?}" shell 'if command 1> /dev/null -v "uname" && uname 2> /dev/null -r; then :; elif test -r "/proc/version"; then cat "/proc/version"; fi' | LC_ALL=C tr -d '\r')"; then
    case "${_val?}" in
      '') ;;
      'Linux version '*)
        printf '%s\n' "${_val?}" | cut -c '15-' | grep -m 1 -o -e "^[^(]*" && return 0
        ;;
      *)
        printf '%s\n' "${_val?}" && return 0
        ;;
    esac
  fi

  return 1
}

get_imei_via_MMI_code()
{
  local _device
  case "${PROP_TYPE}" in A) ;; *) return 1 ;; esac

  _device="${1:?}"

  adb 1> /dev/null 2>&1 -s "${_device:?}" shell '
    svc power stayon true

    # If the screen is locked then unlock it (only swipe is supported)
    if uiautomator 2> /dev/null dump --compressed "/proc/self/fd/1" | grep -q -F -e "com.android.systemui:id/keyguard_message_area"; then
      #echo 1>&2 "Unlocking screen..."
      input swipe 200 650 200 0
    fi
  ' || true

  # shellcheck disable=SC2016
  adb 2> /dev/null -s "${_device:?}" shell '
    test -e "/proc/self/fd/1" || exit 1
    alias dump_ui="uiautomator 2> /dev/null dump --compressed \"/proc/self/fd/1\"" || exit 2

    am 1> /dev/null 2>&1 start -a "com.android.phone.action.TOUCH_DIALER" || true

    _current_ui="$(dump_ui)" || exit 3

    if echo "${_current_ui?}" | grep -q -F -e "com.android.dialer:id/dialpad_key_number" -e "com.android.contacts:id/dialpad_key_letters"; then
      # Dialpad
      input keyevent KEYCODE_MOVE_HOME &&
        input keyevent KEYCODE_STAR &&
        input keyevent KEYCODE_POUND &&
        input text "06" &&
        input keyevent KEYCODE_POUND &&
        _current_ui="$(dump_ui)"
    fi

    if echo "${_current_ui?}" | grep -q -F -e "text=\"IMEI\""; then
      # IMEI window
      echo "${_current_ui?}"

      input keyevent KEYCODE_DPAD_UP
      input keyevent KEYCODE_ENTER
    else
      # Failure
      exit 4
    fi
  ' |
    sed 's/>/>\n/g' |
    grep -F -m 1 -A 1 -e 'IMEI' |
    tail -n 1 |
    grep -o -m 1 -e 'text="[0-9 /]*"' |
    cut -d '"' -f '2' -s |
    LC_ALL=C tr -d ' '

  adb 1> /dev/null 2>&1 -s "${_device:?}" shell 'input keyevent KEYCODE_HOME; svc power stayon false' || true
}

get_imei_multi_slot()
{
  local _val _prop _slot _slot_index
  _val=''
  _slot="${2:?}"
  _slot_index="$((_slot - 1))" # Slot index start from 0

  if test "${BUILD_VERSION_SDK:?}" -lt "${ANDROID_5_SDK:?}"; then
    if test "${_slot:?}" -eq 1; then
      is_valid_imei "${INFO_IMEI?}"
      display_phonesubinfo_or_warn 'IMEI' "${INFO_IMEI?}" "$?"
    fi

    return # No multi-SIM support
  fi

  # Function: String getDeviceIdForPhone(int phoneId, String callingPackage, optional String callingFeatureId)
  if test "${BUILD_VERSION_SDK:?}" -gt "${ANDROID_14_SDK:?}"; then
    :
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_11_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 4 i32 "${_slot_index:?}" s16 'com.android.shell')" # Android 11-14
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_5_1_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 3 i32 "${_slot_index:?}" s16 'com.android.shell')" # Android 5.1-10
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_5_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 2 i32 "${_slot_index:?}")" # Android 5.0 (need test)
  fi

  if ! is_valid_imei "${_val?}"; then
    if _prop="$(get_and_check_prop_silent "ro.ril.miui.imei${_slot_index:?}")"; then # Xiaomi
      _val="${_prop:?}"
    elif _prop="$(get_and_check_prop_silent "ro.ril.oem.imei${_slot:?}")"; then
      _val="${_prop:?}"
    elif _prop="$(get_and_check_prop_silent "persist.radio.imei${_slot:?}")"; then
      _val="${_prop:?}"
    fi
  fi

  is_valid_imei "${_val?}"
  display_phonesubinfo_or_warn 'IMEI' "${_val?}" "$?"
}

get_imei()
{
  local _backup_ifs _tmp
  local _val='' _index _imei_sv=''

  if _val="$(device_shell "${1:?}" 'dumpsys iphonesubinfo' | grep -m 1 -F -e 'Device ID' | cut -d '=' -f '2-' -s | trim_space_on_sides)" && is_valid_imei "${_val?}"; then
    : # Presumably Android 1.0-4.4W (but it doesn't work on all devices)
  elif _val="$(call_phonesubinfo "${1:?}" 1 s16 'com.android.shell')" && is_valid_imei "${_val?}"; then
    : # Android 1.0-14 => Function: String getDeviceId(String callingPackage)
  elif _tmp="$(get_and_check_prop_silent 'gsm.baseband.imei')"; then
    _val="${_tmp:?}"
  elif _tmp="$(get_and_check_prop_silent 'ro.gsm.imei')"; then
    _val="${_tmp:?}"
  elif _tmp="$(get_and_check_prop_silent 'gsm.imei')"; then
    _val="${_tmp:?}"
  elif _tmp="$(get_and_check_prop_silent 'ril.imei')"; then
    _val="${_tmp:?}"
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_4_4_SDK:?}" && test "${BUILD_VERSION_SDK:?}" -le "${ANDROID_5_1_SDK:?}"; then
    # Use only as absolute last resort
    if _tmp="$(get_imei_via_MMI_code "${1:?}")" && is_valid_value "${_tmp?}"; then
      _backup_ifs="${IFS:-}"
      IFS="${NL:?}"

      # It can also be in the format: IMEI/IMEI SV
      _index=1
      for elem in $(printf '%s\n' "${_tmp:?}" | tr '/' '\n'); do
        case "${_index:?}" in
          1) _val="${elem?}" ;;
          2) _imei_sv="${elem?}" ;;
          *) break ;;
        esac
        _index="$((_index + 1))"
      done

      IFS="${_backup_ifs:-}"
    fi
  fi

  INFO_IMEI="${_val?}"
  is_valid_imei "${_val?}"
  display_phonesubinfo_or_warn 'IMEI' "${_val?}" "$?"

  # Function: String getDeviceSvn(String callingPackage, optional String callingFeatureId)
  if test -n "${_imei_sv?}"; then
    _val="${_imei_sv:?}"
  elif test "${BUILD_VERSION_SDK:?}" -gt "${ANDROID_14_SDK:?}"; then
    _val=''
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_11_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 6 s16 'com.android.shell')" || _val='' # Android 11-14
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_5_1_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 5 s16 'com.android.shell')" || _val='' # Android 5.1-10
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_5_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 4)" || _val='' # Android 5.0
  else
    _val="$(call_phonesubinfo "${1:?}" 2)" || _val='' # Android 1.0-4.4W (unverified)
  fi

  #INFO_IMEI_SV="${_val?}"
  is_valid_length "${_val?}" 2 2
  display_phonesubinfo_or_warn 'IMEI SV' "${_val?}" "$?" 'non-sensitive'
}

get_line_number_multi_slot()
{
  local _val _slot _slot_index
  _val=''
  _slot="${2:?}"
  _slot_index="$((_slot - 1))" # Slot index start from 0

  if test "${BUILD_VERSION_SDK:?}" -lt "${ANDROID_5_SDK:?}"; then
    if test "${_slot:?}" -eq 1; then
      is_valid_line_number "${INFO_LINE_NUMBER?}"
      display_phonesubinfo_or_warn 'Line number' "${INFO_LINE_NUMBER?}" "$?"
    fi

    return # No multi-SIM support
  fi

  # Function: String getLine1NumberForSubscriber(int subId, String callingPackage, optional String callingFeatureId)
  if test "${BUILD_VERSION_SDK:?}" -gt "${ANDROID_14_SDK:?}"; then
    :
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_11_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 16 i32 "${_slot_index:?}" s16 'com.android.shell')" # Android 11-14
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_9_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 13 i32 "${_slot_index:?}" s16 'com.android.shell')" # Android 9-10
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_5_1_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 14 i32 "${_slot_index:?}" s16 'com.android.shell')" # Android 5.1-8.1
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_5_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 12 i32 "${_slot_index:?}")" # Android 5.0
  fi

  if ! is_valid_line_number "${_val?}"; then
    # Function: String getMsisdnForSubscriber(int subId, String callingPackage, optional String callingFeatureId)
    if test "${BUILD_VERSION_SDK:?}" -gt "${ANDROID_14_SDK:?}"; then
      :
    elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_11_SDK:?}"; then
      _val="$(call_phonesubinfo "${1:?}" 20 i32 "${_slot_index:?}" s16 'com.android.shell')" # Android 11-14
    elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_9_SDK:?}"; then
      _val="$(call_phonesubinfo "${1:?}" 17 i32 "${_slot_index:?}" s16 'com.android.shell')" # Android 9-10
    elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_5_1_SDK:?}"; then
      _val="$(call_phonesubinfo "${1:?}" 18 i32 "${_slot_index:?}" s16 'com.android.shell')" # Android 5.1-8.1
    elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_5_SDK:?}"; then
      _val="$(call_phonesubinfo "${1:?}" 16 i32 "${_slot_index:?}")" # Android 5.0
    fi
  fi

  is_valid_line_number "${_val?}"
  display_phonesubinfo_or_warn 'Line number' "${_val?}" "$?"
}

get_line_number()
{
  local _val
  _val=''

  # Function: String getLine1Number(String callingPackage, optional String callingFeatureId)
  if test "${BUILD_VERSION_SDK:?}" -gt "${ANDROID_14_SDK:?}"; then
    :
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_11_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 15 s16 'com.android.shell')" # Android 11-14
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_9_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 12 s16 'com.android.shell')" # Android 9-10
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_5_1_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 13 s16 'com.android.shell')" # Android 5.1-8.1
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_5_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 11)" # Android 5.0
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_4_3_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 6)" # Android 4.3-4.4W
  else
    _val="$(call_phonesubinfo "${1:?}" 5)" # Android 1.0-4.2 (unverified)
  fi

  INFO_LINE_NUMBER="${_val?}"
  is_valid_line_number "${_val?}"
  display_phonesubinfo_or_warn 'Line number' "${_val?}" "$?"
}

get_iccid()
{
  local _val=''

  if test "${BUILD_VERSION_SDK:?}" -gt "${ANDROID_14_SDK:?}"; then
    :
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_11_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 12 s16 'com.android.shell')" || _val=''
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_9_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 10 s16 'com.android.shell')" || _val=''
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_5_1_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 11 s16 'com.android.shell')" || _val=''
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_5_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 9)" || _val=''
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_4_3_SDK:?}"; then
    _val="$(call_phonesubinfo "${1:?}" 5)" || _val=''
  else
    _val="$(call_phonesubinfo "${1:?}" 4)" || _val=''
  fi
  is_valid_length "${_val?}" 19 20
  display_phonesubinfo_or_warn 'ICCID (SIM serial number)' "${_val?}" "$?"
}

parse_nv_data()
{
  local __fn_path
  HARDWARE_VERSION=''
  PRODUCT_CODE=''
  case "${PROP_TYPE}" in A) ;; *) return 1 ;; esac

  if __fn_path="$(resolve_data_dir)" && mkdir -p -- "${__fn_path}"; then
    :
  else
    log_non_fatal 'Unable to create the data directory'
    return 2
  fi

  rm -f "${__fn_path}/nv_data.bin" || return 3
  MSYS_NO_PATHCONV=1 adb -s "${1:?}" pull '/efs/nv_data.bin' "${__fn_path}/nv_data.bin" 1> /dev/null 2>&1 || return 4
  test -f "${__fn_path}/nv_data.bin" || return 5

  HARDWARE_VERSION="$(dd if="${__fn_path}/nv_data.bin" skip=1605636 count=18 iflag=skip_bytes,count_bytes status=none | LC_ALL=C tr -d '\0')"
  PRODUCT_CODE="$(dd if="${__fn_path}/nv_data.bin" skip=1605654 count=20 iflag=skip_bytes,count_bytes status=none | LC_ALL=C tr -d '\0')"

  rm -f "${__fn_path}/nv_data.bin" || :
  return 0
}

get_slot_info()
{
  local IFS _states _state _i
  SLOT1_STATE=''
  SLOT2_STATE=''
  SLOT3_STATE=''
  SLOT4_STATE=''
  _states="$(get_and_check_prop 'gsm.sim.state' || :)"

  IFS=','
  _i=0
  for _state in ${_states?}; do
    _i="$((_i + 1))"
    case "${_i:?}" in
      1) SLOT1_STATE="${_state?}" ;;
      2) SLOT2_STATE="${_state?}" ;;
      3) SLOT3_STATE="${_state?}" ;;
      4) SLOT4_STATE="${_state?}" ;;
      *) break ;;
    esac
  done

  if test "${_i:?}" -lt 1 || test "${_i:?}" -gt 4; then
    log_warn 'Unable to get slot count, defaulting to 1'
    #printf '%s\n' '1'
    SLOT_COUNT='1'
    return
  fi

  #printf '%s\n' "${_i:?}"
  SLOT_COUNT="${_i:?}"
}

parse_prop_helper_multi_slot()
{
  if test "${1:?}" -eq 1; then
    printf '%s\n' "${2?}" | cut -d ',' -f '1'
  else
    printf '%s\n' "${2?}" | cut -d ',' -f "${1:?}" -s
  fi
}

get_operator_alpha_multi_slot()
{
  local _val _slot
  _slot="${1:?}"

  if _val="$(parse_prop_helper_multi_slot "${_slot:?}" "${DATA_RAW_OPERATOR1?}")" && test -n "${_val?}"; then
    :
  elif _val="$(parse_prop_helper_multi_slot "${_slot:?}" "${DATA_RAW_OPERATOR2?}")" && test -n "${_val?}"; then
    :
  elif _val="$(parse_prop_helper_multi_slot "${_slot:?}" "${DATA_RAW_OPERATOR3?}")" && test -n "${_val?}"; then
    :
  else
    return 1
  fi

  printf '%s\n' "${_val:?}"
}

dump_device_info()
{
  SELECTED_DEVICE="${1:?}"
  ALL_PROPS=''
  ensure_boot_completed || return 3

  if test "${PRIVACY_MODE?}" = 'true'; then
    log_warn 'PRIVACY MODE is enabled, all sensitive data will be anonymized!'
  fi

  log_status 'Finding info...'
  log_status ''

  BUILD_VERSION_SDK="$(get_and_check_prop 'ro.build.version.sdk')" || BUILD_VERSION_SDK='999'

  log_out_section 'BASIC INFO'
  log_out_blank

  if EMU_NAME="$(get_and_check_prop_silent 'ro.boot.qemu.avd_name' | LC_ALL=C tr -- '_' ' ')"; then
    display_info 'Emulator' "${EMU_NAME?}"
  elif EMU_NAME="$(get_and_check_prop_silent 'ro.kernel.qemu.avd_name' | LC_ALL=C tr -- '_' ' ')"; then
    display_info 'Emulator' "${EMU_NAME?}"
  elif LEAPD_VERSION="$(get_and_check_prop_silent 'ro.leapdroid.version')"; then
    display_info 'Emulator' 'Leapdroid'
    : "${LEAPD_VERSION}"
  fi

  BUILD_MANUFACTURER="$(get_and_check_prop_silent 'ro.product.manufacturer' || get_and_check_prop_silent 'ro.product.brand')" && display_info 'Manufacturer' "${BUILD_MANUFACTURER?}"
  BUILD_MODEL="$(get_and_check_prop 'ro.product.model')" && display_info 'Model' "${BUILD_MODEL?}"
  BUILD_DEVICE="$(get_and_check_prop_silent 'ro.product.device' || get_and_check_prop_silent 'ro.build.product')" && display_info 'Device' "${BUILD_DEVICE?}"
  ANDROID_VERSION="$(get_and_check_prop 'ro.build.version.release')" && display_info 'Android version' "${ANDROID_VERSION?}"
  KERNEL_VERSION="$(get_kernel_version "${SELECTED_DEVICE:?}")" && display_info 'Kernel version' "${KERNEL_VERSION?}"

  {
    SQLITE_VERSION="$(device_shell "${SELECTED_DEVICE:?}" 'sqlite3 2> /dev/null --version' | cut -d ' ' -f '1')"
    display_info_or_warn 'SQLite version' "${SQLITE_VERSION?}" "$?" 'non-sensitive'
  }

  get_device_color
  get_device_back_color

  {
    DEVICE_PATH="$(device_get_devpath "${SELECTED_DEVICE:?}")"
    display_info_or_warn 'Device path' "${DEVICE_PATH?}" "$?" 'non-sensitive'
  }

  log_out_blank

  SERIAL_NUMBER="$(find_serialno)"
  display_info_or_warn 'Serial number' "${SERIAL_NUMBER?}" "$?"
  CPU_SERIAL_NUMBER="$(find_cpu_serialno "${SELECTED_DEVICE:?}")"
  display_info_or_warn 'CPU serial number' "${CPU_SERIAL_NUMBER?}" "$?"

  log_out_blank

  ANDROID_ID="$(get_android_id "${SELECTED_DEVICE:?}")"
  is_valid_android_id "${ANDROID_ID?}"
  display_info_or_warn 'Android ID' "${ANDROID_ID?}" "$?"

  log_out_blank

  DISPLAY_SIZE="$(device_shell "${SELECTED_DEVICE:?}" 'wm 2> /dev/null size' | cut -d ':' -f '2-' -s | trim_space_left)"
  display_info_or_warn 'Display size' "${DISPLAY_SIZE?}" "$?" 'non-sensitive'
  DISPLAY_DENSITY="$(device_shell "${SELECTED_DEVICE:?}" 'wm 2> /dev/null density' | cut -d ':' -f '2-' -s | trim_space_left)"
  display_info_or_warn 'Display density' "${DISPLAY_DENSITY?}" "$?" 'non-sensitive'

  log_out_blank

  log_out_section 'SLOT INFO'
  log_out_blank

  DATA_RAW_OPERATOR1="$(get_and_check_prop_silent 'gsm.sim.operator.alpha' || get_and_check_prop_silent 'gsm.sim.operator.orig.alpha' || :)"
  DATA_RAW_OPERATOR2="$(get_and_check_prop_silent 'gsm.operator.alpha' || get_and_check_prop_silent 'gsm.operator.orig.alpha' || :)"
  DATA_RAW_OPERATOR3="$(get_and_check_prop_silent 'gsm.sim.operator.spn' || :)"
  # ToDO: Check 'gsm.operator.alpha.vsim'

  # https://android.googlesource.com/platform/frameworks/base/+/HEAD/telephony/java/com/android/internal/telephony/TelephonyProperties.java
  get_slot_info

  display_info 'Slot count' "${SLOT_COUNT?}"

  log_out_blank

  log_out "DEFAULT SLOT"
  get_imei "${SELECTED_DEVICE:?}"
  get_iccid "${SELECTED_DEVICE:?}"

  operator_current_slot="$(get_operator_alpha_multi_slot '1')"
  display_info_or_warn "Operator" "${operator_current_slot?}" "$?" 'non-sensitive'

  get_line_number "${SELECTED_DEVICE:?}"

  log_out_blank

  local _index slot_state operator_current_slot
  for _index in $(seq "${SLOT_COUNT:?}"); do
    log_out "SLOT ${_index:?}"
    case "${_index:?}" in
      1)
        slot_state="${SLOT1_STATE?}"
        ;;
      2)
        slot_state="${SLOT2_STATE?}"
        ;;
      3)
        slot_state="${SLOT3_STATE?}"
        ;;
      4)
        slot_state="${SLOT4_STATE?}"
        ;;
      *)
        slot_state=''
        ;;
    esac

    # https://developer.android.com/reference/android/telephony/TelephonyManager#SIM_STATE_ABSENT
    # https://android.googlesource.com/platform/frameworks/base.git/+/HEAD/telephony/java/com/android/internal/telephony/IccCardConstants.java
    # UNKNOWN, ABSENT, PIN_REQUIRED, PUK_REQUIRED, NETWORK_LOCKED, READY, NOT_READY, PERM_DISABLED, CARD_IO_ERROR, CARD_RESTRICTED, LOADED
    display_info_or_warn "Slot state" "${slot_state?}" 0 'non-sensitive'

    get_imei_multi_slot "${SELECTED_DEVICE:?}" "${_index:?}"

    operator_current_slot="$(get_operator_alpha_multi_slot "${_index:?}")"
    display_info_or_warn "Operator" "${operator_current_slot?}" "$?" 'non-sensitive'

    if ! compare_nocase "${slot_state?}" 'ABSENT'; then
      get_line_number_multi_slot "${SELECTED_DEVICE:?}" "${_index:?}"
    fi

    log_out_blank
  done

  log_out_section 'ADVANCED INFO (root may be required)'
  adb_root "${SELECTED_DEVICE:?}"
  log_out_blank

  device_shell "${SELECTED_DEVICE:?}" "if test -e '/system' && test ! -e '/system/bin/sh'; then mount -t 'auto' -o 'ro' '/system' 2> /dev/null || :; fi"
  device_shell "${SELECTED_DEVICE:?}" "if test -e '/data' && test ! -e '/data/data'; then mount -t 'auto' -o 'ro' '/data' 2> /dev/null || :; fi"
  device_shell "${SELECTED_DEVICE:?}" "if test -e '/efs'; then mount -t 'auto' -o 'ro' '/efs' 2> /dev/null || :; fi"

  {
    GSF_ID_DEC="$(get_gsf_id "${SELECTED_DEVICE:?}")"

    GSF_ID="$(convert_dec_to_hex "${GSF_ID_DEC?}")" && is_valid_length "${GSF_ID?}" 16 16
    display_info_or_warn 'GSF ID' "${GSF_ID?}" "$?"

    is_valid_length "${GSF_ID_DEC?}" 19 19
    display_info_or_warn 'GSF ID (decimal)' "${GSF_ID_DEC?}" "$?"
  }

  log_out_blank

  ADVERTISING_ID="$(get_advertising_id "${SELECTED_DEVICE:?}")"
  validate_and_display_info 'Advertising ID' "${ADVERTISING_ID?}" 36

  log_out_blank

  log_out_section 'EFS INFO (root may be required)'
  log_out_blank

  parse_nv_data "${SELECTED_DEVICE:?}"
  validate_and_display_info 'Hardware version' "${HARDWARE_VERSION?}"
  validate_and_display_info 'Product code' "${PRODUCT_CODE?}"

  CSC_REGION_CODE="$(device_get_file_content "${SELECTED_DEVICE:?}" '/efs/imei/mps_code.dat')"
  validate_and_display_info 'CSC region code' "${CSC_REGION_CODE?}" 3

  EFS_SERIALNO="$(device_get_file_content "${SELECTED_DEVICE:?}" '/efs/FactoryApp/serial_no')"
  validate_and_display_info 'Serial number' "${EFS_SERIALNO?}"

  unset ALL_PROPS RET_VAL
  return 0
}

main()
{
  local status=0 found=0 first=1 _device_id='' _current=''

  if test 'adb' = "${1-}"; then
    PROP_TYPE='A'

    verify_adb_mode_deps || return "$?"
    start_adb_server || {
      log_err 'Failed to start ADB'
      return 10
    }

    for _device_id in $(adb devices | grep -v -F -e 'List of devices' | cut -f 1 -s); do
      test -n "${_device_id?}" || continue

      if test "${first?}" = 0; then printf '\n=== DEVICE-BREAK ===\n\n'; else
        first=0
        log_blank
      fi
      log_out_selected_device "${_device_id?}"

      if detect_status_and_wait_connection "${_device_id?}"; then
        found=1

        if test "${OPEN_DEVICE_STATUS_INFO_ONLY?}" = 'true'; then
          open_device_status_info "${_device_id?}" || status="$?"
          continue
        fi

        dump_device_info "${_device_id?}" || status="$?"
      else
        log_warn 'Device is offline/unauthorized, skipped'
      fi
    done

    test "${found:?}" = 1 || {
      log_err 'No devices or emulators found. Please connect a device or start an emulator'
      return 11
    }
  else
    case "${1-}" in
      '')
        log_err 'Missing required argument. Please specify one or more files to process'
        return "${EX_USAGE?}"
        ;;
      *) ;;
    esac

    for _current in "$@"; do
      test -f "${_current}" || {
        log_err "Input file doesn't exist => '${_current}'"
        status=12
        continue
      }

      if test "${first?}" = 0; then printf '\n=== DEVICE-BREAK ===\n\n'; else
        first=0
        log_blank
      fi
      log_out_selected_device "${_current}"

      if grep -m 1 -q -e '^\[.*\]: \[.*\]' -- "${_current}"; then
        PROP_TYPE='G'
        log_warn "Operating in restricted 'getprop' mode. Extracted information will be incomplete!!!"
      elif grep -m 1 -q -e '^.*\..*=' -- "${_current}"; then
        PROP_TYPE='B'
        log_warn "Operating in restricted 'build.prop' mode. Extracted information will be incomplete!!!"
      else
        log_err "Unknown input file => '${_current}'"
        status=13
        continue
      fi

      dump_device_info "${_current}" || status="$?"
    done
  fi

  return "${status:?}"
}

# @section CLI ARGUMENTS PARSING ----
#region
execute_script='true'
change_title='true'
no_pause=0
STATUS=0
PRIVACY_MODE='false'
OPEN_DEVICE_STATUS_INFO_ONLY='false'

while test "$#" -gt 0; do
  case "${1?}" in
    -V | --version)
      execute_script='false'
      no_pause=1
      # REUSE-IgnoreStart
      printf '%s\n' "${SCRIPT_NAME:?}, version ${SCRIPT_VERSION:?}"
      printf '%s\n' "Copyright (C) ${SCRIPT_YEAR:?} ${SCRIPT_AUTHOR:?}"
      printf '%s\n\n' 'License GPLv3+ with APE.'
      printf '%s\n' 'There is NO WARRANTY, to the extent permitted by law.'
      # REUSE-IgnoreEnd
      ;;

    -I | --open-device-status-info)
      OPEN_DEVICE_STATUS_INFO_ONLY='true'
      ;;

    -p | --privacy-mode)
      PRIVACY_MODE='true'
      ;;

    --no-title)
      change_title='false'
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
  init
  if test "${change_title:?}" = 'true'; then set_title "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?} by ale5000"; fi
  log_status "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?} by ${SCRIPT_AUTHOR:?}"

  test "$#" -ne 0 || set -- 'adb'
  main "${@}" || STATUS="$?"
  exec 3>&- # Close descriptor
  restore_codepage
fi

pause_if_needed
restore_title
exit "${STATUS:?}"
#endregion
