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
# shellcheck disable=SC3040,SC3041,SC2015
{
  # Unsupported set options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue
  (set -o posix 2> /dev/null) && set -o posix || true
  (set +H 2> /dev/null) && set +H || true
  (set -o pipefail) && set -o pipefail || true
}

readonly SCRIPT_NAME='Android device info extractor'
readonly SCRIPT_VERSION='0.9'

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
}

show_status_msg()
{
  printf 1>&2 '\033[1;32m%s\033[0m\n' "${*}"
}

show_warn()
{
  printf 1>&2 '\033[0;33m%s\033[0m\n' "WARNING: ${*}"
}

show_error()
{
  printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR: ${*}"
}

show_section()
{
  printf '\033[1;36m%s\033[0m\n' "${*}"
}

show_msg()
{
  printf '%s\n' "${*}"
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

  show_error 'adb is NOT available'
  pause_if_needed
  exit 1
}

start_adb_server()
{
  adb 2> /dev/null 'start-server' || true
}

wait_connection()
{
  show_status_msg 'Waiting for the device...'
  if test "${DEVICE_IN_RECOVERY:?}" = 'true'; then
    adb 'wait-for-recovery'
  else
    adb 'wait-for-device'
  fi
}

adb_root()
{
  adb 1> /dev/null 'root' &
  adb 1> /dev/null 'reconnect' # Root and unroot commands may freeze the adb connection of some devices, workaround the problem
  wait_connection
}

adb_unroot()
{
  adb 1> /dev/null 2> /dev/null 'unroot' &
  adb 1> /dev/null 'reconnect' & # Root and unroot commands may freeze the adb connection of some devices, workaround the problem
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
  # ${2:-0} => 2 (Allow empty value)

  if test -z "${1?}" && test "${2:-0}" != '2'; then return 1; fi
  if test "${1?}" = 'unknown'; then return 1; fi

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
  _var="$(cat -u)" || return 1
  test "${#_var}" -gt 0 || return 1

  _var="${_var# }"
  printf '%s' "${_var% }"
}

convert_dec_to_hex()
{
  if command -v bc 1> /dev/null; then
    printf 'obase=16;%s' "${1?}" | bc -s | LC_ALL=C tr '[:upper:]' '[:lower:]'
  else
    printf '%x' "${1?}"
  fi
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

is_recovery()
{
  if test "$(adb 2> /dev/null 'get-state' || true)" = 'recovery'; then
    return 0;
  fi
  return 1
}

is_boot_completed()
{
  if test "${DEVICE_IN_RECOVERY:?}" = 'true' || test "$(chosen_getprop 'sys.boot_completed' || true)" = '1'; then
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

find_serialno()
{
  local _serialno=''
  BUILD_MANUFACTURER="$(validated_chosen_getprop 'ro.product.manufacturer')"

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

get_gsf_id()
{
  local _val _my_command

  # We want this without expansion, since it will happens later inside adb shell
  # shellcheck disable=SC2016
  _my_command='PATH="${PATH:-/sbin}:/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin"; export PATH; readonly my_query="SELECT * FROM main WHERE name = \"android_id\";"; { test -e "/data/data/com.google.android.gsf/databases/gservices.db" && sqlite3 2> /dev/null -line "/data/data/com.google.android.gsf/databases/gservices.db" "${my_query?}"; } || { test -e "/data/data/com.google.android.gms/databases/gservices.db" && sqlite3 2> /dev/null -line "/data/data/com.google.android.gms/databases/gservices.db" "${my_query?}"; }'

  _val="$(adb shell "${_my_command:?}")" || _val=''
  if test -z "${_val?}"; then
    _val="$(adb shell "su 0 sh -c '${_my_command:?}'")" || _val=''
  fi

  test -n "${_val?}" || return 1
  _val="$(printf '%s' "${_val?}" | grep -m 1 -e 'value' | cut -d '=' -f '2-' -s)"

  printf '%s' "${_val# }"
}

get_advertising_id()
{
  local adid

  adid="$(adb shell 'cat "/data/data/com.google.android.gms/shared_prefs/adid_settings.xml" 2> /dev/null')" || adid=''
  test "${adid?}" != '' || return 1

  adid="$(printf '%s' "${adid?}" | grep -m 1 -o -e '"adid_key"[^<]*' | grep -o -e ">.*$")"

  printf '%s' "${adid#>}"
}

get_phone_info()
{
  adb shell "service call iphonesubinfo ${*}" | cut -d "'" -f '2' -s | LC_ALL=C tr -d -s '.[:cntrl:]' '[:space:]' | trim_space_on_sides
}

display_info()
{
  show_msg "${1?}: ${2?}"
}

validate_and_display_info()
{
  if contains 'Requires READ_PHONE_STATE' "${2?}" || contains 'does not belong to' "${2?}"; then
    local _err
    _err="$(printf '%s\n' "${2?}" | cut -c '2-70')"
    show_warn "Unable to find ${1:-} due to: ${_err:-}"
    return 3
  fi

  if ! is_valid_value "${2?}"; then
    show_warn "${1:-} not found"
    return 1
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

get_imei()
{
  local _val

  _val="$(get_phone_info 1 s16 'com.android.shell')" || _val=''
  validate_and_display_info 'IMEI' "${_val?}" 15

  if test "${BUILD_VERSION_SDK:?}" -gt "${ANDROID_14_SDK:?}"; then
    :
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_11_SDK:?}"; then
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

  if test "${BUILD_VERSION_SDK:?}" -gt "${ANDROID_14_SDK:?}"; then
    :
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_11_SDK:?}"; then
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

  if test "${BUILD_VERSION_SDK:?}" -gt "${ANDROID_14_SDK:?}"; then
    :
  elif test "${BUILD_VERSION_SDK:?}" -ge "${ANDROID_11_SDK:?}"; then
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
  validate_and_display_info 'ICCID' "${_val?}" 19 20
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
  _path="$(get_data_folder)" || return 1
  rm -f "${_path:?}/nv_data.bin" || return 1

  adb 1> /dev/null pull '/efs/nv_data.bin' "${_path:?}/nv_data.bin" || return 1
  if test ! -r "${_path:?}/nv_data.bin"; then return 1; fi

  HARDWARE_VERSION="$(dd if="${_path:?}/nv_data.bin" skip=1605636 count=18 iflag=skip_bytes,count_bytes status=none)"
  PRODUCT_CODE="$(dd if="${_path:?}/nv_data.bin" skip=1605654 count=20 iflag=skip_bytes,count_bytes status=none)"

  rm -f "${_path:?}/nv_data.bin" || return 1
}

get_csc_region_code()
{
  adb shell 'if test -r "/efs/imei/mps_code.dat"; then cat "/efs/imei/mps_code.dat"; fi'
}

get_efs_serialno()
{
  adb shell 'if test -r "/efs/FactoryApp/serial_no"; then cat "/efs/FactoryApp/serial_no"; fi'
}

main()
{
  verify_adb
  start_adb_server
  if is_recovery; then
    readonly DEVICE_IN_RECOVERY='true'
  else
    readonly DEVICE_IN_RECOVERY='false'
  fi
  wait_connection
  show_status_msg 'Finding info...'
  check_boot_completed
  show_status_msg ''

  BUILD_VERSION_SDK="$(validated_chosen_getprop 'ro.build.version.sdk')"
  readonly BUILD_VERSION_SDK

  show_section 'BASIC INFO'
  show_msg ''

  if EMU_NAME="$(chosen_getprop 'ro.boot.qemu.avd_name' | LC_ALL=C tr -- '_' ' ')" && is_valid_value "${EMU_NAME?}"; then
    display_info 'Emulator' "${EMU_NAME?}"
  elif LEAPD_VERSION="$(chosen_getprop 'ro.leapdroid.version')" && is_valid_value "${LEAPD_VERSION?}"; then
    display_info 'Emulator' 'Leapdroid'
  fi

  BUILD_MODEL="$(validated_chosen_getprop 'ro.product.model')" && display_info 'Model' "${BUILD_MODEL?}"
  SERIAL_NUMBER="$(find_serialno)" && display_info 'Serial number' "${SERIAL_NUMBER?}"

  show_msg ''

  get_imei
  get_iccid
  get_line_number

  show_msg ''

  ANDROID_ID="$(get_android_id)"
  validate_and_display_info 'Android ID' "${ANDROID_ID?}" 16

  show_msg ''
  show_msg ''

  show_section 'ADVANCED INFO (root may be required)'
  adb_root
  show_msg ''

  adb shell "if test -e '/system' && test ! -e '/system/bin/sh'; then mount -t 'auto' -o 'ro' '/system' 2> /dev/null || true; fi"
  adb shell "if test -e '/data' && test ! -e '/data/data'; then mount -t 'auto' -o 'ro' '/data' 2> /dev/null || true; fi"
  adb shell "if test -e '/efs'; then mount -t 'auto' -o 'ro' '/efs' 2> /dev/null || true; fi"

  GSF_ID=''
  GSF_ID_DEC="$(get_gsf_id)"
  if validate_and_display_info 'GSF ID (decimal)' "${GSF_ID_DEC?}" 19; then
    GSF_ID="$(convert_dec_to_hex "${GSF_ID_DEC?}")"
    validate_and_display_info 'GSF ID' "${GSF_ID?}" 16
  fi

  show_msg ''

  ADVERTISING_ID="$(get_advertising_id)"
  validate_and_display_info 'Advertising ID' "${ADVERTISING_ID?}" 36

  show_msg ''
  show_msg ''

  show_section 'EFS INFO (root may be required)'
  show_msg ''

  parse_nv_data
  validate_and_display_info 'Hardware version' "${HARDWARE_VERSION?}"
  validate_and_display_info 'Product code' "${PRODUCT_CODE?}"

  CSC_REGION_CODE="$(get_csc_region_code)"
  validate_and_display_info 'CSC region code' "${CSC_REGION_CODE?}" 3

  EFS_SERIALNO="$(get_efs_serialno)"
  validate_and_display_info 'Serial number' "${EFS_SERIALNO?}"
  

  adb_unroot
}

show_status_msg "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?} by ale5000"
main "${@}"
pause_if_needed
