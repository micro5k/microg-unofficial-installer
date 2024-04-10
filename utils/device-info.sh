#!/usr/bin/env sh
# @name Android device info extractor
# @brief It can automatically extract device information from all devices connected via adb or from a file.
# @author ale5000
# Get the latest version from here: https://github.com/micro5k/microg-unofficial-installer/tree/main/utils

# SPDX-FileCopyrightText: (c) 2023 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

set -u
# shellcheck disable=SC3040,SC3041,SC2015
{
  # Unsupported set options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue
  (set -o posix 2> /dev/null) && set -o posix || true
  (set +H 2> /dev/null) && set +H || true
  (set -o pipefail) && set -o pipefail || true
}

readonly SCRIPT_NAME='Android device info extractor'
readonly SCRIPT_SHORTNAME='DeviceInfo'
readonly SCRIPT_VERSION='2.7'

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

DEBUG="${DEBUG:-0}"

set_utf8_codepage()
{
  PREVIOUS_CODEPAGE=''
  if command 1> /dev/null -v chcp.com; then
    PREVIOUS_CODEPAGE="$(chcp.com 2> /dev/null | LC_ALL=C tr -d '\r' | cut -d ':' -f '2-' -s | trim_space_left)"
    chcp.com 1> /dev/null 65001
  fi
}

restore_codepage()
{
  if test -n "${PREVIOUS_CODEPAGE?}" && test "${PREVIOUS_CODEPAGE:?}" -ne 65001; then
    chcp.com 1> /dev/null "${PREVIOUS_CODEPAGE:?}"
  fi
  PREVIOUS_CODEPAGE=''
}

show_status_info()
{
  printf 1>&2 '\033[1;32m%s\033[0m\n' "${*}"
}

show_status_warn()
{
  printf 1>&2 '\033[0;33m%s\033[0m\n' "WARNING: ${*}"
  if "${STDOUT_REDIRECTED?}" && test "${DEBUG:?}" != 0; then printf 1>&3 '%s\n' "WARNING: ${*}"; fi
}

show_status_error()
{
  printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR: ${*}"
  if "${STDOUT_REDIRECTED?}" && test "${DEBUG:?}" != 0; then printf 1>&3 '%s\n' "ERROR: ${*}"; fi
}

device_not_ready_status_msg_initialize()
{
  static_device_not_ready_displayed='false'
}

show_device_not_ready_status_msg()
{
  if test "${static_device_not_ready_displayed:?}" = 'false'; then
    static_device_not_ready_displayed='true'
    printf 1>&2 '\033[1;32m%s\033[0m' 'Device is not ready, waiting.'
  else
    printf 1>&2 '\033[1;32m%s\033[0m' '.'
  fi
}

device_not_ready_status_msg_terminate()
{
  if test "${static_device_not_ready_displayed:?}" != 'false'; then printf 1>&2 '\n'; fi
  static_device_not_ready_displayed=''
}

show_device_waiting_status_msg()
{
  if test "${static_device_not_ready_displayed:?}" = 'false'; then
    printf 1>&2 '\033[1;32m%s\033[0m\n' 'Waiting for the device...'
  else
    printf 1>&2 '\033[32m%s\033[0m' '.'
  fi
}

show_msg()
{
  printf '%s\n' "${*}"
}

show_warn()
{
  printf 1>&2 '\033[0;33m%s\033[0m\n' "WARNING: ${*}"
  if "${STDOUT_REDIRECTED?}" && test "${DEBUG:?}" != 0; then printf 1>&3 '%s\n' "WARNING: ${*}"; fi
}

show_error()
{
  printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR: ${*}"
  if "${STDOUT_REDIRECTED?}" && test "${DEBUG:?}" != 0; then printf 1>&3 '%s\n' "ERROR: ${*}"; fi
}

show_script_name()
{
  printf 1>&2 '\033[1;32m%s\033[0m\n' "${*}"
  if "${STDOUT_REDIRECTED?}"; then printf 1>&3 '%s\n' "${*}"; fi
}

show_selected_device()
{
  if test -t 1; then
    printf '\033[1;31;103m%s\033[0m\n' "SELECTED: ${*}"
  else
    printf '%s\n' "SELECTED: ${*}"
  fi
}

show_section()
{
  if test -t 1; then
    printf '\033[1;36m%s\033[0m\n' "${*}"
  else
    printf '%s\n' "${*}"
  fi
}

set_title()
{
  if test "${CI:-false}" != 'false'; then return 1; fi

  if command 1> /dev/null -v title; then
    PREVIOUS_TITLE="$(title)" # Save current title
    title "${1:?}"            # Set new title
  elif test -t 1; then
    printf '\033[22;0t\r' && printf '       \r'                         # Save current title on stack
    printf '\033]0;%s\007\r' "${1:?}" && printf '    %*s \r' "${#1}" '' # Set new title
  elif test -t 2; then
    printf 1>&2 '\033[22;0t\r' && printf 1>&2 '       \r'                         # Save current title on stack
    printf 1>&2 '\033]0;%s\007\r' "${1:?}" && printf 1>&2 '    %*s \r' "${#1}" '' # Set new title
  fi
}

restore_title()
{
  if test "${CI:-false}" != 'false'; then return 1; fi

  if command 1> /dev/null -v title; then
    title "${PREVIOUS_TITLE?}" # Restore saved title
    PREVIOUS_TITLE=''
  elif test -t 1; then
    printf '\033]0;\007\r' && printf '     \r'  # Set empty title (fallback in case saving/restoring title doesn't work)
    printf '\033[23;0t\r' && printf '       \r' # Restore title from stack
  elif test -t 2; then
    printf 1>&2 '\033]0;\007\r' && printf 1>&2 '     \r'  # Set empty title (fallback in case saving/restoring title doesn't work)
    printf 1>&2 '\033[23;0t\r' && printf 1>&2 '       \r' # Restore title from stack
  fi
}

pause_if_needed()
{
  # shellcheck disable=SC3028 # In POSIX sh, SHLVL is undefined
  if test "${CI:-false}" = 'false' && test "${SHLVL:-}" = '1' && test -t 0 && test -t 1 && test -t 2; then
    printf 1>&2 '\n\033[1;32m%s\033[0m' 'Press any key to exit...' || true
    # shellcheck disable=SC3045
    IFS='' read 1>&2 -r -s -n 1 _ || true
    printf 1>&2 '\n' || true
  fi
}

verify_adb()
{
  if command -v adb 1> /dev/null; then
    return 0
  fi

  if test "${OS:-}" = 'Windows_NT'; then
    # Set the path of Android SDK if not already set
    if test -z "${ANDROID_SDK_ROOT:-}" && test -n "${LOCALAPPDATA:-}" && test -e "${LOCALAPPDATA:?}/Android/Sdk"; then
      export ANDROID_SDK_ROOT="${LOCALAPPDATA:?}/Android/Sdk"
    fi
  fi

  if test -n "${ANDROID_SDK_ROOT:-}"; then
    local _pathsep
    if test "$(uname -o 2> /dev/null | LC_ALL=C tr '[:upper:]' '[:lower:]' || true)" = 'ms/windows'; then
      _pathsep=';' # BusyBox-w32
    else
      _pathsep=':' # Other shells on Windows
    fi

    # shellcheck disable=SC2123
    export PATH="${ANDROID_SDK_ROOT:?}/platform-tools${_pathsep:?}${PATH}"

    if command -v adb 1> /dev/null; then
      return 0
    fi
  fi

  show_status_error 'adb is NOT available'
  pause_if_needed
  exit 1
}

verify_adb_mode_deps()
{
  verify_adb

  if ! command -v timeout 1> /dev/null; then
    show_status_error 'timeout is NOT available'
    pause_if_needed
    exit 1
  fi
}

start_adb_server()
{
  if test "${INPUT_TYPE:?}" != 'adb'; then return 0; fi

  adb 2> /dev/null 'start-server'
}

parse_device_status()
{
  case "${1?}" in
    'device' | 'recovery') return 0 ;;                          # OK
    *'connecting'* | *'authorizing'* | *'offline'*) return 1 ;; # Connecting (transitory) / Authorizing (transitory) / Offline (may be transitory)
    *'unauthorized'*) return 2 ;;                               # Unauthorized
    *'not found'*) return 3 ;;                                  # Disconnected (unrecoverable)
    *'no permissions'*) return 4 ;;                             #
    *'no device'*) return 4 ;;                                  # No devices/emulators (unrecoverable)
    *'closed'*) return 4 ;;                                     # ADB connection forcibly terminated on device side
    *'protocol fault'*) return 4 ;;                             # ADB connection forcibly terminated on server side
    'sideload') return 5 ;;                                     # Sideload (not supported)
    *) ;;                                                       # Others / Unknown => ignored
  esac
  return 0

  # Possible status:
  # - device
  # - recovery
  # - unauthorized
  # - authorizing
  # - offline
  # - no device
  # - unknown
  # - error: device unauthorized.
  # - error: device still authorizing
  # - error: device offline
  # - error: device 'xxx' not found
  # - error: no devices/emulators found
  # - error: closed
  # - error: protocol fault (couldn't read status): connection reset
}

detect_status_and_wait_connection()
{
  local _status _reconnected

  device_not_ready_status_msg_initialize

  _reconnected='false'
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    _status="$(LC_ALL=C adb 2>&1 -s "${1:?}" 'get-state' | LC_ALL=C tr -d '\r' || true)"
    parse_device_status "${_status?}"
    case "${?}" in
      1)
        show_device_not_ready_status_msg # Wait 5 seconds maximum for transitory states
        ;;
      2)
        show_device_not_ready_status_msg
        if test "${_reconnected:?}" = 'false'; then
          _reconnected='true'
          adb 1> /dev/null 2>&1 -s "${1:?}" reconnect offline && sleep 3 # If the device is unauthorized, reconnect to request authorization and then wait
        fi
        ;;
      3)
        if test "${2:-false}" = 'false'; then
          show_device_not_ready_status_msg # Note: The device may disappear for a few seconds after "adb root", "adb unroot" or "adb reconnect"
        else
          break
        fi
        ;;
      *) break ;;
    esac

    sleep 0.5
  done

  parse_device_status "${_status?}"
  if test "${?}" -ne 0; then
    device_not_ready_status_msg_terminate
    return 1
  fi

  if test "${2:-false}" != 'false'; then
    case "${_status?}" in
      'recovery' | 'sideload') DEVICE_STATE="${_status:?}" ;;
      *) DEVICE_STATE='device' ;;
    esac
  fi

  show_device_waiting_status_msg

  device_not_ready_status_msg_terminate

  adb 2> /dev/null -s "${1:?}" "wait-for-${DEVICE_STATE:?}"
  return "${?}"
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
  if test "${INPUT_TYPE:?}" != 'adb'; then return; fi

  show_status_error 'adb was frozen, reconnecting...'
  adb 1> /dev/null -s "${1:?}" reconnect || true # Root and unroot commands may freeze the adb connection of some devices, workaround the problem
  detect_status_and_wait_connection "${1:?}"
}

adb_root()
{
  if test "${INPUT_TYPE:?}" != 'adb'; then return; fi
  if test "$(adb 2>&1 -s "${1:?}" shell 'whoami' | LC_ALL=C tr -d '[:cntrl:]' || true)" = 'root'; then return; fi # Already rooted

  timeout 1> /dev/null 2>&1 -- 6 adb -s "${1:?}" root
  if is_timeout "${?}"; then
    adb_unfroze "${1:?}"
  else
    detect_status_and_wait_connection "${1:?}"
  fi

  # Dummy command to check if adb is frozen
  timeout -- 3 adb -s "${1:?}" shell ':'
  if is_timeout "${?}"; then adb_unfroze "${1:?}"; fi
}

adb_unroot()
{
  if test "${INPUT_TYPE:?}" != 'adb'; then return; fi

  adb 1> /dev/null -s "${1:?}" unroot &
  adb 1> /dev/null -s "${1:?}" reconnect # Root and unroot commands may freeze the adb connection of some devices, workaround the problem
}

is_all_zeros()
{
  if test -n "${1?}" && test "$(printf '%s\n' "${1:?}" | LC_ALL=C tr -d '0' || true)" = ''; then
    return 0 # True
  fi

  return 1 # False
}

is_valid_value()
{
  # ${2:-0} => 2 (Allow empty value)

  if test -z "${1?}" && test "${2:-0}" != '2'; then return 1; fi
  if test "${1?}" = 'unknown'; then return 1; fi

  return 0 # Valid
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
  printf '%s' "${1?}" | LC_ALL=C tr '[:upper:]' '[:lower:]'
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
    printf 'obase=16;%s\n' "${1?}" | bc -s | LC_ALL=C tr '[:upper:]' '[:lower:]'
  else
    printf '%x\n' "${1?}"
  fi
}

anonymize_string()
{
  printf '%s' "${1?}" | LC_ALL=C tr '[:digit:]' '0' | LC_ALL=C tr 'a-f' 'f' | LC_ALL=C tr 'g-z' 'x' | LC_ALL=C tr 'A-F' 'F' | LC_ALL=C tr 'G-Z' 'X'
}

anonymize_code()
{
  local _string _prefix_length

  if test "${#1}" -lt 2; then
    anonymize_string "${1:?}"
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

device_getprop()
{
  adb -s "${1:?}" shell "getprop '${2:?}'" | LC_ALL=C tr -d '\r'
}

getprop_output_parse()
{
  local _val

  if _val="$(grep -m 1 -e "^\[${2:?}\]\:" -- "${1:?}" | LC_ALL=C tr -d '\r' | cut -d ':' -f '2-' -s | grep -m 1 -o -e '^[[:blank:]]\[.*\]$')" && test "${#_val}" -gt 3; then
    printf '%s\n' "${_val?}" | cut -c "3-$((${#_val} - 1))"
    return "${?}"
  fi

  return 1
}

prop_output_parse()
{
  grep -m 1 -e "^${2:?}=" -- "${1:?}" | LC_ALL=C tr -d '\r' | cut -d '=' -f '2-' -s
}

auto_getprop()
{
  local _val

  if test "${INPUT_TYPE:?}" = 'adb'; then
    _val="$(device_getprop "${SELECTED_DEVICE:?}" "${@}")" || return 1
  elif test "${PROP_TYPE:?}" = '1'; then
    _val="$(getprop_output_parse "${INPUT_SELECTION:?}" "${@}")" || return 1
  else
    _val="$(prop_output_parse "${INPUT_SELECTION:?}" "${@}")" || return 1
  fi

  if test -z "${_val?}" || test "${_val:?}" = 'unknown'; then
    return 2
  fi

  printf '%s\n' "${_val:?}"
  return 0
}

validated_chosen_getprop()
{
  local _value
  if ! _value="$(auto_getprop "${1:?}")" || ! is_valid_value "${_value?}" "${2:-}"; then
    show_error "Invalid value for ${1:-}"
    return 1
  fi

  printf '%s\n' "${_value?}"
}

is_boot_completed()
{
  if test "$(auto_getprop 2> /dev/null 'sys.boot_completed' || true)" = '1'; then
    return 0
  fi

  return 1
}

ensure_boot_completed()
{
  if test "${INPUT_TYPE:?}" = 'adb' && test "${DEVICE_STATE?}" = 'device'; then
    is_boot_completed || {
      show_status_warn 'Device has not finished booting yet, skipped'
      return 1
    }
  elif test "${INPUT_TYPE:?}" = 'file' && test "${PROP_TYPE:?}" = 1; then
    is_boot_completed || {
      show_status_error 'Getprop comes from a device that has not finished booting yet, skipped'
      return 1
    }
  fi

  return 0
}

device_get_file_content()
{
  if test "${INPUT_TYPE:?}" != 'adb'; then return 1; fi
  adb -s "${1:?}" shell "test -r '${2:?}' && cat '${2:?}'" | LC_ALL=C tr -d '\r'
}

find_serialno()
{
  local _val

  if compare_nocase "${BUILD_MANUFACTURER?}" 'Lenovo' && _val="$(auto_getprop 'ro.lenovosn2')" && is_valid_serial "${_val?}"; then # Lenovo tablets
    :
  elif _val="$(auto_getprop 'ril.serialnumber')" && is_valid_serial "${_val?}"; then # Samsung phones / tablets (possibly others)
    :
  elif _val="$(auto_getprop 'ro.ril.oem.psno')" && is_valid_serial "${_val?}"; then # Xiaomi phones (possibly others)
    :
  elif _val="$(auto_getprop 'ro.ril.oem.sno')" && is_valid_serial "${_val?}"; then # Xiaomi phones (possibly others)
    :
  elif _val="$(auto_getprop 'ro.serialno')" && is_valid_serial "${_val?}"; then
    :
  elif _val="$(auto_getprop 'sys.serialnumber')" && is_valid_serial "${_val?}"; then
    :
  elif _val="$(auto_getprop 'ro.boot.serialno')" && is_valid_serial "${_val?}"; then
    :
  elif _val="$(auto_getprop 'ro.kernel.androidboot.serialno')" && is_valid_serial "${_val?}"; then
    :
  else
    show_warn 'Serial number not found'
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
    show_warn 'CPU serial number not found'
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

  if test "${INPUT_TYPE:?}" != 'adb'; then return 1; fi

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

  if test "${INPUT_TYPE:?}" != 'adb'; then return 1; fi

  adid="$(adb -s "${1:?}" shell 'cat "/data/data/com.google.android.gms/shared_prefs/adid_settings.xml" 2> /dev/null')" || adid=''
  test "${adid?}" != '' || return 1

  adid="$(printf '%s' "${adid?}" | grep -m 1 -o -e '"adid_key"[^<]*' | grep -o -e ">.*$")"

  printf '%s' "${adid#>}"
}

get_device_color()
{
  local _val

  if _val="$(auto_getprop 'ro.config.devicecolor')" && is_valid_color "${_val?}"; then # Huawei (possibly others)
    :
  elif _val="$(auto_getprop 'vendor.panel.color')" && is_valid_color "${_val?}"; then # Xiaomi (possibly others)
    :
  elif _val="$(auto_getprop 'sys.panel.color')" && is_valid_color "${_val?}"; then # Xiaomi (possibly others)
    :
  else
    _val=''
  fi

  display_info_or_warn 'Device color' "${_val?}" 0 'non-sensitive'
}

get_device_back_color()
{
  local _val

  if _val="$(auto_getprop 'ro.config.backcolor')" && is_valid_color "${_val?}"; then # Huawei (possibly others)
    :
  else
    _val=''
  fi

  display_info_or_warn 'Device back color' "${_val?}" 0 'non-sensitive'
}

device_shell()
{
  local _device
  if test "${INPUT_TYPE:?}" != 'adb'; then return 1; fi

  _device="${1:?}"
  shift

  adb -s "${_device:?}" shell "${*}" | LC_ALL=C tr -d '\r'
}

device_get_devpath()
{
  local _val
  if test "${INPUT_TYPE:?}" != 'adb'; then return 1; fi

  if _val="$(adb -s "${1:?}" 'get-devpath' | LC_ALL=C tr -d '\r')" && test "${_val?}" != 'unknown'; then
    printf '%s\n' "${_val?}"
    return 0
  fi

  return 1
}

apply_phonesubinfo_deviation()
{
  local _method_code
  _method_code="${1:?}"

  if compare_nocase "${BUILD_MANUFACTURER?}" 'HUAWEI' && test "${BUILD_VERSION_SDK:?}" -eq "${ANDROID_9_SDK:?}"; then

    if test "${1:?}" -ge 3; then
      _method_code="$((_method_code + 1))"
    fi

  fi

  printf '%s\n' "${_method_code:?}"
}

call_phonesubinfo()
{
  local _device _method_code
  if test "${INPUT_TYPE:?}" != 'adb'; then return 1; fi

  _device="${1:?}"
  _method_code="$(apply_phonesubinfo_deviation "${2:?}")"
  shift 2

  # https://android.googlesource.com/platform/frameworks/base/+/master/telephony/java/com/android/internal/telephony/IPhoneSubInfo.aidl
  # https://android.googlesource.com/platform/frameworks/opt/telephony/+/master/src/java/com/android/internal/telephony/PhoneSubInfoController.java

  if test "${#}" -eq 0; then set ''; fi # Avoid issues on Bash under Mac
  adb -s "${_device:?}" shell "service call iphonesubinfo ${_method_code:?} ${*}" | cut -d "'" -f '2' -s | LC_ALL=C tr -d -s '.[:cntrl:]' '[:space:]' | trim_space_on_sides
}

is_phonesubinfo_response_valid()
{
  if test -z "${1?}" || contains 'Requires READ_PHONE_STATE' "${1?}" || contains 'does not belong to' "${1?}" || contains 'Parcel data not fully consumed' "${1?}"; then
    return 1
  fi

  return 0
}

display_info()
{
  show_msg "${1?}: ${2?}"
}

display_info_or_warn()
{
  local _is_valid
  _is_valid="${3:?}" # It is a return value, so 0 is true

  if test -z "${2?}"; then
    show_warn "${1?} not found"
    return 1
  fi

  if test "${_is_valid:?}" -ne 0; then
    show_warn "Invalid ${1?}: ${2?}"
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
    show_warn "${1?} not found"
    return 1
  fi

  if ! is_phonesubinfo_response_valid "${2?}"; then
    local _err
    _err="$(printf '%s\n' "${2?}" | cut -c '2-70')"
    show_warn "Cannot find ${1?} due to '${_err?}'"
    return 3
  fi

  if test "${_is_valid:?}" -ne 0; then
    show_warn "Invalid ${1?}: ${2?}"
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
    show_warn "${1:-} not found"
    return 1
  fi

  if ! is_phonesubinfo_response_valid "${2?}"; then
    local _err
    _err="$(printf '%s\n' "${2?}" | cut -c '2-69')"
    show_warn "Cannot find ${1:-} due to '${_err:-}'"
    return 3
  fi

  if test -n "${4:-}"; then
    if test "${#2}" -lt "${3?}" || test "${#2}" -gt "${4?}"; then
      show_warn "Invalid ${1:-}: ${2:-}"
      return 2
    fi
  elif test -n "${3:-}" && test "${#2}" -ne "${3?}"; then
    show_warn "Invalid ${1:-}: ${2:-}"
    return 2
  fi

  show_msg "${1?}: ${2?}"
}

open_device_status_info()
{
  adb 1> /dev/null 2>&1 shell '
    svc power stayon true

    # If the screen is locked then unlock it (only swipe is supported)
    if uiautomator 2> /dev/null dump --compressed "/proc/self/fd/1" | grep -q -F -e "com.android.systemui:id/keyguard_message_area"; then
      #echo 1>&2 "Screen unlocking..."
      input swipe 200 650 200 0
    fi
  ' || true

  adb 2> /dev/null shell '
    am 1> /dev/null 2>&1 start -a "android.settings.DEVICE_INFO_SETTINGS" &&
      input keyevent KEYCODE_BACK &&
      am 1> /dev/null 2>&1 start -a "android.settings.DEVICE_INFO_SETTINGS"

    input keyevent KEYCODE_DPAD_UP &&
      input keyevent KEYCODE_DPAD_DOWN &&
      input keyevent KEYCODE_ENTER
  '

  adb 1> /dev/null 2>&1 shell 'svc power stayon false' || true
}

get_kernel_version()
{
  local _val
  if test "${INPUT_TYPE:?}" != 'adb'; then return 1; fi

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
  _device="${1:?}"

  if test "${INPUT_TYPE:?}" != 'adb'; then return 1; fi

  adb 1> /dev/null 2>&1 -s "${_device:?}" shell '
    svc power stayon true

    # If the screen is locked then unlock it (only swipe is supported)
    if uiautomator 2> /dev/null dump --compressed "/proc/self/fd/1" | grep -q -F -e "com.android.systemui:id/keyguard_message_area"; then
      #echo 1>&2 "Screen unlocking..."
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
      display_phonesubinfo_or_warn 'IMEI' "${INFO_IMEI?}" "${?}"
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
    if _prop="$(auto_getprop "ro.ril.miui.imei${_slot_index:?}")" && is_valid_value "${_prop?}"; then # Xiaomi
      _val="${_prop:?}"
    elif _prop="$(auto_getprop "ro.ril.oem.imei${_slot:?}")" && is_valid_value "${_prop?}"; then
      _val="${_prop:?}"
    elif _prop="$(auto_getprop "persist.radio.imei${_slot:?}")" && is_valid_value "${_prop?}"; then
      _val="${_prop:?}"
    fi
  fi

  is_valid_imei "${_val?}"
  display_phonesubinfo_or_warn 'IMEI' "${_val?}" "${?}"
}

get_imei()
{
  local _backup_ifs _tmp
  local _val _index _imei_sv

  _val=''
  _imei_sv=''

  if _val="$(device_shell "${1:?}" 'dumpsys iphonesubinfo' | grep -m 1 -F -e 'Device ID' | cut -d '=' -f '2-' -s | trim_space_on_sides)" && is_valid_imei "${_val?}"; then
    : # Presumably Android 1.0-4.4W (but it doesn't work on all devices)
  elif _val="$(call_phonesubinfo "${1:?}" 1 s16 'com.android.shell')" && is_valid_imei "${_val?}"; then
    : # Android 1.0-14 => Function: String getDeviceId(String callingPackage)
  elif _tmp="$(auto_getprop 'gsm.baseband.imei')" && is_valid_value "${_tmp?}"; then
    _val="${_tmp:?}"
  elif _tmp="$(auto_getprop 'ro.gsm.imei')" && is_valid_value "${_tmp?}"; then
    _val="${_tmp:?}"
  elif _tmp="$(auto_getprop 'gsm.imei')" && is_valid_value "${_tmp?}"; then
    _val="${_tmp:?}"
  elif _tmp="$(auto_getprop 'ril.imei')" && is_valid_value "${_tmp?}"; then
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
  else
    _val=''
  fi

  INFO_IMEI="${_val?}"
  is_valid_imei "${_val?}"
  display_phonesubinfo_or_warn 'IMEI' "${_val?}" "${?}"

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
  display_phonesubinfo_or_warn 'IMEI SV' "${_val?}" "${?}" 'non-sensitive'
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
      display_phonesubinfo_or_warn 'Line number' "${INFO_LINE_NUMBER?}" "${?}"
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
  display_phonesubinfo_or_warn 'Line number' "${_val?}" "${?}"
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
  display_phonesubinfo_or_warn 'Line number' "${_val?}" "${?}"
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
  display_phonesubinfo_or_warn 'ICCID (SIM serial number)' "${_val?}" "${?}"
}

get_data_folder()
{
  local _path

  # shellcheck disable=SC3028
  if test -n "${UTILS_DATA_DIR:-}"; then
    _path="${UTILS_DATA_DIR:?}"
  elif test -n "${BASH_SOURCE:-}" && _path="$(dirname "${BASH_SOURCE:?}")/data"; then # Expanding an array without an index gives the first element (it is intended)
    :
  elif test -n "${0:-}" && _path="$(dirname "${0:?}")/data"; then
    :
  else
    _path='./data'
  fi

  _path="$(realpath "${_path:?}")" || return 1

  if test ! -e "${_path:?}"; then
    mkdir -p "${_path:?}" || return 1
  fi

  printf '%s\n' "${_path:?}"
}

parse_nv_data()
{
  local _path
  HARDWARE_VERSION=''
  PRODUCT_CODE=''

  if test "${INPUT_TYPE:?}" != 'adb'; then return 1; fi

  _path="$(get_data_folder)" || return 1
  rm -f "${_path:?}/nv_data.bin" || return 1

  adb 1> /dev/null -s "${1:?}" pull '/efs/nv_data.bin' "${_path:?}/nv_data.bin" || return 1
  if test ! -r "${_path:?}/nv_data.bin"; then return 1; fi

  HARDWARE_VERSION="$(dd if="${_path:?}/nv_data.bin" skip=1605636 count=18 iflag=skip_bytes,count_bytes status=none)"
  PRODUCT_CODE="$(dd if="${_path:?}/nv_data.bin" skip=1605654 count=20 iflag=skip_bytes,count_bytes status=none)"

  rm -f "${_path:?}/nv_data.bin" || return 1
}

get_slot_info()
{
  local IFS _states _state _i
  SLOT1_STATE=''
  SLOT2_STATE=''
  SLOT3_STATE=''
  SLOT4_STATE=''
  _states="$(auto_getprop 'gsm.sim.state')" || _states=''

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
    show_warn 'Unable to get slot count, defaulting to 1'
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

extract_all_info()
{
  SELECTED_DEVICE="${1:?}"
  if ! ensure_boot_completed; then return 2; fi

  show_status_info 'Finding info...'
  show_status_info ''

  BUILD_VERSION_SDK="$(validated_chosen_getprop 'ro.build.version.sdk')" || BUILD_VERSION_SDK='999'

  show_section 'BASIC INFO'
  show_msg ''

  if EMU_NAME="$(auto_getprop 'ro.boot.qemu.avd_name' | LC_ALL=C tr -- '_' ' ')" && is_valid_value "${EMU_NAME?}"; then
    display_info 'Emulator' "${EMU_NAME?}"
  elif EMU_NAME="$(auto_getprop 'ro.kernel.qemu.avd_name' | LC_ALL=C tr -- '_' ' ')" && is_valid_value "${EMU_NAME?}"; then
    display_info 'Emulator' "${EMU_NAME?}"
  elif LEAPD_VERSION="$(auto_getprop 'ro.leapdroid.version')" && is_valid_value "${LEAPD_VERSION?}"; then
    display_info 'Emulator' 'Leapdroid'
  fi

  {
    BUILD_MANUFACTURER="$(auto_getprop 'ro.product.manufacturer')" || BUILD_MANUFACTURER="$(auto_getprop 'ro.product.brand')"
  } && display_info 'Manufacturer' "${BUILD_MANUFACTURER?}"
  BUILD_MODEL="$(validated_chosen_getprop 'ro.product.model')" && display_info 'Model' "${BUILD_MODEL?}"
  {
    BUILD_DEVICE="$(auto_getprop 'ro.product.device')" || BUILD_DEVICE="$(auto_getprop 'ro.build.product')"
  } && display_info 'Device' "${BUILD_DEVICE?}"
  ANDROID_VERSION="$(validated_chosen_getprop 'ro.build.version.release')" && display_info 'Android version' "${ANDROID_VERSION?}"
  KERNEL_VERSION="$(get_kernel_version "${SELECTED_DEVICE:?}")" && display_info 'Kernel version' "${KERNEL_VERSION?}"

  {
    SQLITE_VERSION="$(device_shell "${SELECTED_DEVICE:?}" 'sqlite3 2> /dev/null --version' | cut -d ' ' -f '1')"
    display_info_or_warn 'SQLite version' "${SQLITE_VERSION?}" "${?}" 'non-sensitive'
  }

  get_device_color
  get_device_back_color

  {
    DEVICE_PATH="$(device_get_devpath "${SELECTED_DEVICE:?}")"
    display_info_or_warn 'Device path' "${DEVICE_PATH?}" "${?}" 'non-sensitive'
  }

  show_msg ''

  SERIAL_NUMBER="$(find_serialno)"
  display_info_or_warn 'Serial number' "${SERIAL_NUMBER?}" "${?}"
  CPU_SERIAL_NUMBER="$(find_cpu_serialno "${SELECTED_DEVICE:?}")"
  display_info_or_warn 'CPU serial number' "${CPU_SERIAL_NUMBER?}" "${?}"

  show_msg ''

  ANDROID_ID="$(get_android_id "${SELECTED_DEVICE:?}")"
  is_valid_android_id "${ANDROID_ID?}"
  display_info_or_warn 'Android ID' "${ANDROID_ID?}" "${?}"

  show_msg ''

  DISPLAY_SIZE="$(device_shell "${SELECTED_DEVICE:?}" 'wm 2> /dev/null size' | cut -d ':' -f '2-' -s | trim_space_left)"
  display_info_or_warn 'Display size' "${DISPLAY_SIZE?}" "${?}" 'non-sensitive'
  DISPLAY_DENSITY="$(device_shell "${SELECTED_DEVICE:?}" 'wm 2> /dev/null density' | cut -d ':' -f '2-' -s | trim_space_left)"
  display_info_or_warn 'Display density' "${DISPLAY_DENSITY?}" "${?}" 'non-sensitive'

  show_msg ''

  show_section 'SLOT INFO'
  show_msg ''

  # https://android.googlesource.com/platform/frameworks/base/+/HEAD/telephony/java/com/android/internal/telephony/TelephonyProperties.java
  get_slot_info

  display_info 'Slot count' "${SLOT_COUNT?}"

  show_msg ''

  show_msg "DEFAULT SLOT"
  get_imei "${SELECTED_DEVICE:?}"
  get_iccid "${SELECTED_DEVICE:?}"
  get_line_number "${SELECTED_DEVICE:?}"

  show_msg ''

  DATA_RAW_OPERATOR1="$(auto_getprop 'gsm.sim.operator.alpha')" || DATA_RAW_OPERATOR1="$(auto_getprop 'gsm.sim.operator.orig.alpha')"
  DATA_RAW_OPERATOR2="$(auto_getprop 'gsm.operator.alpha')" || DATA_RAW_OPERATOR2="$(auto_getprop 'gsm.operator.orig.alpha')"
  DATA_RAW_OPERATOR3="$(auto_getprop 'gsm.sim.operator.spn')"
  # ToDO: Check 'gsm.operator.alpha.vsim'

  local _index slot_state operator_current_slot
  for _index in $(seq "${SLOT_COUNT:?}"); do
    show_msg "SLOT ${_index:?}"
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
    display_info_or_warn "Operator" "${operator_current_slot?}" "${?}" 'non-sensitive'

    if ! compare_nocase "${slot_state?}" 'ABSENT'; then
      get_line_number_multi_slot "${SELECTED_DEVICE:?}" "${_index:?}"
    fi

    show_msg ''
  done

  show_section 'ADVANCED INFO (root may be required)'
  adb_root "${SELECTED_DEVICE:?}"
  show_msg ''

  device_shell "${SELECTED_DEVICE:?}" "if test -e '/system' && test ! -e '/system/bin/sh'; then mount -t 'auto' -o 'ro' '/system' 2> /dev/null || true; fi"
  device_shell "${SELECTED_DEVICE:?}" "if test -e '/data' && test ! -e '/data/data'; then mount -t 'auto' -o 'ro' '/data' 2> /dev/null || true; fi"
  device_shell "${SELECTED_DEVICE:?}" "if test -e '/efs'; then mount -t 'auto' -o 'ro' '/efs' 2> /dev/null || true; fi"

  {
    GSF_ID_DEC="$(get_gsf_id "${SELECTED_DEVICE:?}")"

    GSF_ID="$(convert_dec_to_hex "${GSF_ID_DEC?}")" && is_valid_length "${GSF_ID?}" 16 16
    display_info_or_warn 'GSF ID' "${GSF_ID?}" "${?}"

    is_valid_length "${GSF_ID_DEC?}" 19 19
    display_info_or_warn 'GSF ID (decimal)' "${GSF_ID_DEC?}" "${?}"
  }

  show_msg ''

  ADVERTISING_ID="$(get_advertising_id "${SELECTED_DEVICE:?}")"
  validate_and_display_info 'Advertising ID' "${ADVERTISING_ID?}" 36

  show_msg ''

  show_section 'EFS INFO (root may be required)'
  show_msg ''

  parse_nv_data "${SELECTED_DEVICE:?}"
  validate_and_display_info 'Hardware version' "${HARDWARE_VERSION?}"
  validate_and_display_info 'Product code' "${PRODUCT_CODE?}"

  CSC_REGION_CODE="$(device_get_file_content "${SELECTED_DEVICE:?}" '/efs/imei/mps_code.dat')"
  validate_and_display_info 'CSC region code' "${CSC_REGION_CODE?}" 3

  EFS_SERIALNO="$(device_get_file_content "${SELECTED_DEVICE:?}" '/efs/FactoryApp/serial_no')"
  validate_and_display_info 'Serial number' "${EFS_SERIALNO?}"
}

main()
{
  local _found || {
    show_status_error "Local variables aren't supported!!!"
    return 99
  }

  set_utf8_codepage
  show_script_name "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?} by ale5000"

  DEVICE_STATE=''

  if test -z "${1?}" || test "${1:?}" = 'adb'; then
    INPUT_TYPE='adb'
    INPUT_SELECTION=''
    PROP_TYPE=''
  else
    INPUT_TYPE='file'
    INPUT_SELECTION="${1:?}"
  fi

  if test "${INPUT_TYPE:?}" = 'adb'; then

    verify_adb_mode_deps
    start_adb_server || {
      show_status_error 'Failed to start ADB'
      return 10
    }

    local _device

    _found='false'
    for _device in $(adb devices | grep -v -i -F -e 'list' | cut -f '1' -s); do
      if test -z "${_device?}"; then continue; fi

      show_msg ''
      show_selected_device "${_device:?}"

      if detect_status_and_wait_connection "${_device:?}" 'true'; then
        _found='true'
        extract_all_info "${_device:?}"
      else
        show_status_warn 'Device is offline/unauthorized, skipped'
      fi
    done

    if test "${_found:?}" = 'false'; then
      show_status_error 'No devices/emulators found'
      return 11
    fi

  else

    test -f "${INPUT_SELECTION:?}" || {
      show_status_error "Input file doesn't exist => '${INPUT_SELECTION?}'"
      return 12
    }

    show_selected_device "${INPUT_SELECTION:?}"

    if grep -m 1 -q -e '^\[.*\]\:[[:blank:]]\[.*\]' -- "${INPUT_SELECTION:?}"; then
      PROP_TYPE='1'
      show_warn 'Operating in getprop mode, the extracted info will be severely limited!!!'

      extract_all_info "${INPUT_SELECTION:?}"
    elif grep -m 1 -q -e '^.*\..*=' -- "${INPUT_SELECTION:?}"; then
      PROP_TYPE='2'
      show_warn 'Operating in build.prop mode, the extracted info will be severely limited!!!'

      extract_all_info "${INPUT_SELECTION:?}"
    else
      show_status_error "Unknown input file => '${INPUT_SELECTION?}'"
      return 13
    fi

  fi

  restore_codepage

  return 0
}

set_title "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?} by ale5000"
execute_script='true'

STATUS=0
PRIVACY_MODE='false'
if test -t 1; then STDOUT_REDIRECTED='false'; else STDOUT_REDIRECTED='true'; fi
exec 3>&1 # Create a copy of stdout

while test "${#}" -gt 0; do
  case "${1}" in
    --version)
      printf '%s\n' "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?}"
      printf '%s\n' 'Copyright (c) 2024 ale5000'
      printf '%s\n' 'License GPLv3+'
      execute_script='false'
      ;;

    -p | --privacy-mode)
      PRIVACY_MODE='true'
      ;;

    --)
      break
      ;;

    --*)
      printf 1>&3 '%s\n' "${SCRIPT_SHORTNAME?}: unrecognized option '${1}'"
      execute_script='false'
      STATUS=2
      ;;

    -*)
      printf 1>&3 '%s\n' "${SCRIPT_SHORTNAME?}: invalid option -- '${1#-}'"
      execute_script='false'
      STATUS=2
      ;;

    *)
      break
      ;;
  esac

  if test "${#}" -ne 0; then shift; fi # Important: 'shift' with nothing to shift cause some shells to exit so check it before using
done

if test "${execute_script:?}" = 'true'; then
  if test "${#}" -eq 0; then set ''; fi
  main "${@}"
  STATUS="${?}"
fi
pause_if_needed

restore_title

exit "${STATUS:?}"
