#!/usr/bin/env sh
# @name Android device info extractor
# @brief It can automatically extract device information from a device connected via adb.
# @author ale5000
# Get the latest version from here: https://github.com/micro5k/microg-unofficial-installer/tree/main/utils

# SPDX-FileCopyrightText: (c) 2023 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# shellcheck disable=SC3043 # In POSIX sh, local is undefined

set -u
# shellcheck disable=SC3040,SC2015
{
  # Unsupported set options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue
  (set -o posix 2> /dev/null) && set -o posix || true
  # shellcheck disable=SC3041
  (set +H 2> /dev/null) && set +H || true
  (set -o pipefail) && set -o pipefail || true
}

readonly SCRIPT_NAME='Android device info extractor'
readonly SCRIPT_VERSION='0.1'

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
}

show_error()
{
  printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR: ${*}"
}

show_warn()
{
  printf 1>&2 '\033[0;33m%s\033[0m\n' "WARNING: ${*}"
}

show_info()
{
  printf 1>&2 '\033[1;32m%s\033[0m\n' "${*}"
}

show_msg()
{
  printf '%s\n' "${*}"
}

is_boot_completed()
{
  if test "$(chosen_getprop 'sys.boot_completed' || true)" = '1'; then
    return 0
  fi

  return 1
}

check_boot_completed()
{
  is_boot_completed || {
    show_error 'The device has not finished booting yet!!!'
    pause_if_needed
    exit 1
  }
}

pause_if_needed()
{
  # shellcheck disable=SC3028 # In POSIX sh, SHLVL is undefined
  if test "${CI:-false}" = 'false' && test "${SHLVL:-}" = '1' && test -t 1 && test -t 2; then
    printf 1>&2 '\n\033[1;32m' || true
    # shellcheck disable=SC3045
    IFS='' read 1>&2 -r -s -n 1 -p 'Press any key to continue...' _ || true
    printf 1>&2 '\033[0m\n' || true
  fi
}

verify_adb()
{
  local _pathsep

  if command -v adb 1> /dev/null; then
    return 0
  fi

  if test "${OS:-}" = 'Windows_NT'; then
    # Set the path of Android SDK if not already set
    if test -z "${ANDROID_SDK_ROOT:-}" && test -n "${LOCALAPPDATA:-}" && test -e "${LOCALAPPDATA:?}/Android/Sdk"; then
      export ANDROID_SDK_ROOT="${LOCALAPPDATA:?}/Android/Sdk"
    fi

    if test -n "${ANDROID_SDK_ROOT:-}"; then
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
  fi

  show_error 'adb is NOT available'
  pause_if_needed
  exit 1
}

is_all_zeros()
{
  if test -n "${1?}" && test "$(printf '%s' "${1?}" | LC_ALL=C tr -d '0' || true)" = ''; then
    return 0 # True
  fi

  return 1 # False
}

is_valid_value()
{
  # 1 = Allow unknown
  # 2 = Allow empty

  if test -z "${1?}" && test "${2:-0}" != '2'; then return 1; fi
  if test "${1?}" = 'unknown' && test "${2:-0}" != '1'; then return 1; fi

  return 0 # Valid
}

is_valid_serial()
{
  if test -z "${1?}" || test "${#1}" -lt 2 || test "${1?}" = 'unknown' || is_all_zeros "${1?}"; then
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

trim_space_on_sides()
{
  local _var
  IFS='' read -r _var || return 1
  test "${#_var}" -ne 0 || return 1

  _var="${_var# }"
  printf '%s' "${_var% }"
}

wait_device()
{
  show_info 'Waiting for the device...'
  adb 'start-server' 2> /dev/null || true
  adb 'wait-for-device'
}

device_getprop()
{
  adb shell "getprop '${1:?}'" | LC_ALL=C tr -d '[:cntrl:]'
}

chosen_getprop()
{
  device_getprop "${@}"
}

validated_chosen_getprop()
{
  local _value
  if ! _value="$(chosen_getprop "${1:?}")" || ! is_valid_value "${_value?}" "${2:-}"; then
    show_error "Invalid value for ${1:-}"
    return 1
  fi

  printf '%s\n' "${_value?}"
}

find_serialno()
{
  local _serialno=''
  BUILD_MANUFACTURER="$(validated_chosen_getprop ro.product.manufacturer)"

  if compare_nocase "${BUILD_MANUFACTURER?}" 'Lenovo'; then
    _serialno="$(chosen_getprop 'ro.lenovosn2')" || _serialno=''
  fi
  if ! is_valid_serial "${_serialno?}"; then
    _serialno="$(chosen_getprop 'ril.serialnumber')" || _serialno=''
  fi
  if ! is_valid_serial "${_serialno?}"; then
    _serialno="$(chosen_getprop 'ro.serialno')" || _serialno=''
  fi
  if ! is_valid_serial "${_serialno?}"; then
    _serialno="$(chosen_getprop 'sys.serialnumber')" || _serialno=''
  fi
  if ! is_valid_serial "${_serialno?}"; then
    _serialno="$(chosen_getprop 'ro.boot.serialno')" || _serialno=''
  fi
  if ! is_valid_serial "${_serialno?}"; then
    _serialno="$(chosen_getprop 'ro.kernel.androidboot.serialno')" || _serialno=''
  fi
  if ! is_valid_serial "${_serialno?}"; then
    show_warn 'Serial number not found'
    return 1
  fi

  printf '%s\n' "${_serialno?}"
}

get_android_id()
{
  adb shell 'settings get secure android_id 2> /dev/null' | LC_ALL=C tr -d '[:cntrl:]'
}

get_phone_info()
{
  adb shell "service call iphonesubinfo ${*}" | cut -d "'" -f '2' -s | {
    LC_ALL=C tr -d -s -- '.[:cntrl:]' '[:space:]' && printf '\n'
  } | trim_space_on_sides
}

display_info()
{
  show_msg "${1?}: ${2?}"
}

validate_and_display_info()
{
  if contains 'Requires READ_PHONE_STATE' "${2?}" || contains 'does not belong to' "${2?}"; then
    local _val
    _val="$(printf '%s' "${2?}" | grep -o -e '[^[:digit:]].*')"
    show_warn "Unable to find ${1:-} due to: ${_val:-}"
    return 3
  fi

  if ! is_valid_value "${2?}"; then
    show_warn "${1:-} not found"
    return 1
  fi

  if test -n "${3:-}" && test "${#2}" -ne "${3?}"; then
    show_warn "Invalid ${1:-}: ${2:-}"
    return 2
  fi

  show_msg "${1?}: ${2?}"
}

get_imei()
{
  local _val

  _val="$(get_phone_info 1 s16 'com.android.shell')" || _val=''
  validate_and_display_info 'IMEI' "${_val?}" 15

  if test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_11_SDK:?}"; then
    _val="$(get_phone_info 6 s16 'com.android.shell')" || _val=''
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_5_1_SDK:?}"; then
    _val="$(get_phone_info 5 s16 'com.android.shell')" || _val=''
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_5_SDK:?}"; then
    _val="$(get_phone_info 4)" || _val=''
  else
    _val="$(get_phone_info 2)" || _val=''
  fi
  validate_and_display_info 'IMEI SV' "${_val?}" 2
}

get_line_number()
{
  local _val

  if test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_11_SDK:?}"; then
    _val="$(get_phone_info 15 s16 'com.android.shell')" || _val=''
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_9_SDK:?}"; then
    _val="$(get_phone_info 12 s16 'com.android.shell')" || _val=''
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_5_1_SDK:?}"; then
    _val="$(get_phone_info 13 s16 'com.android.shell')" || _val=''
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_5_SDK:?}"; then
    _val="$(get_phone_info 11)" || _val=''
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_4_3_SDK:?}"; then
    _val="$(get_phone_info 6)" || _val=''
  else
    _val="$(get_phone_info 5)" || _val=''
  fi
  validate_and_display_info 'Line number' "${_val?}"
}

get_iccid()
{
  local _val

  if test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_11_SDK:?}"; then
    _val="$(get_phone_info 12 s16 'com.android.shell')" || _val=''
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_9_SDK:?}"; then
    _val="$(get_phone_info 10 s16 'com.android.shell')" || _val=''
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_5_1_SDK:?}"; then
    _val="$(get_phone_info 11 s16 'com.android.shell')" || _val=''
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_5_SDK:?}"; then
    _val="$(get_phone_info 9)" || _val=''
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_4_3_SDK:?}"; then
    _val="$(get_phone_info 5)" || _val=''
  else
    _val="$(get_phone_info 4)" || _val=''
  fi
  validate_and_display_info 'ICCID' "${_val?}"
}

show_info "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?} by ale5000"

verify_adb
wait_device
show_info 'Finding info...'
check_boot_completed
show_info ''

BUILD_VERSION_SDK="$(validated_chosen_getprop ro.build.version.sdk)"
readonly BUILD_VERSION_SDK

if EMU_NAME="$(chosen_getprop 'ro.boot.qemu.avd_name' | LC_ALL=C tr -- '_' ' ')" && is_valid_value "${EMU_NAME?}"; then
  display_info 'Emulator' "${EMU_NAME?}"
elif LEAPD_VERSION="$(chosen_getprop 'ro.leapdroid.version')" && is_valid_value "${LEAPD_VERSION?}"; then
  display_info 'Emulator' 'Leapdroid'
fi

BUILD_MODEL="$(validated_chosen_getprop ro.product.model)" && display_info 'Model' "${BUILD_MODEL?}"
SERIAL_NUMBER="$(find_serialno)" && display_info 'Serial number' "${SERIAL_NUMBER?}"

printf '\n'

ANDROID_ID="$(get_android_id)" && validate_and_display_info 'Android ID' "${ANDROID_ID?}"

printf '\n'

get_imei
get_iccid
get_line_number

pause_if_needed
