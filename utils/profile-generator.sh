#!/usr/bin/env sh
# @name Android device profile generator
# @brief It can automatically generate a device profile (usable by microG) from a device connected via adb.
# @author ale5000

# SPDX-FileCopyrightText: (c) 2023 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# shellcheck disable=SC3043 # In POSIX sh, local is undefined

set -u

# shellcheck disable=SC3040,SC2015
{
  # Unsupported set -o options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue and also handle the set -e case
  (set -o posix 2> /dev/null) && set -o posix || true
  (set -o pipefail) && set -o pipefail || true
}

readonly PROFGEN_NAME='Android device profile generator'
readonly PROFGEN_SHORTNAME='Device ProfGen'
readonly PROFGEN_VERSION='0.3'

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

uc_text()
{
  printf '%s' "${1?}" | LC_ALL=C tr '[:lower:]' '[:upper:]'
}

uc_first_char()
{
  printf '%s' "${1?}" | cut -c '1' | LC_ALL=C tr -d '\r\n' | LC_ALL=C tr '[:lower:]' '[:upper:]'
  printf '%s\n' "${1?}" | cut -c '2-'
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

is_string_starting_with()
{
  case "${2?}" in
    "${1:?}"*) return 0 ;; # Found
    *) ;;                  # NOT found
  esac
  return 1 # NOT found
}

is_string_nocase_starting_with()
{
  local _val_1 _val_2
  _val_1="$(lc_text "${1?}")"
  _val_2="$(lc_text "${2?}")"

  case "${_val_2?}" in
    "${_val_1:?}"*) return 0 ;; # Found
    *) ;;                       # NOT found
  esac
  return 1 # NOT found
}

prepend_with_space()
{
  printf '%s' "${1?}"
  if test -n "${2?}"; then
    printf ' %s' "${2?}"
  fi
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

getprop_output_parse()
{
  local _value

  # Return success even if the property isn't found, it will be checked later
  _value="$(grep -m 1 -e "^\[${2:?}\]\:" "${1:?}" | LC_ALL=C tr -d '[:cntrl:]' | cut -d ':' -f '2-' -s | grep -m 1 -o -e '^[[:blank:]]\[.*\]$')" || return 0
  if test "${#_value}" -gt 3; then
    printf '%s' "${_value?}" | cut -c "3-$((${#_value} - 1))"
  fi
}

prop_output_parse()
{
  local _value

  # Return success even if the property isn't found, it will be checked later
  grep -m 1 -e "^${2:?}=" "${1:?}" | LC_ALL=C tr -d '[:cntrl:]' | cut -d '=' -f '2-' -s || return 0
}

chosen_getprop()
{
  if test "${INPUT_TYPE:?}" = 'adb'; then
    device_getprop "${@}"
  elif test "${PROP_TYPE:?}" = '1'; then
    getprop_output_parse "${INPUT_TYPE:?}" "${@}"
  else
    prop_output_parse "${INPUT_TYPE:?}" "${@}"
  fi
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

generate_device_info()
{
  local _info _info_prefix
  _info_prefix=''

  if is_valid_value "${MARKETING_DEVICE_INFO?}"; then
    _info="${MARKETING_DEVICE_INFO:?}"
  else
    if test -n "${BUILD_BRAND?}" && ! compare_nocase "${BUILD_BRAND:?}" "${BUILD_MANUFACTURER?}" && ! compare_nocase "${BUILD_BRAND:?}" 'Android'; then
      _info_prefix="$(uc_first_char "${BUILD_BRAND:?}")"
    fi
    _info="${BUILD_MODEL?}"
  fi

  if test -n "${BUILD_MANUFACTURER?}" && ! is_string_nocase_starting_with "${BUILD_MANUFACTURER:?} " "${_info?}"; then
    _info_prefix="$(prepend_with_space "${BUILD_MANUFACTURER:?}" "${_info_prefix?}")"
  fi

  if test -n "${_info_prefix?}"; then
    printf '%s %s' "$(uc_first_char "${_info_prefix?}" || true)" "${_info?}"
  else
    printf '%s' "$(uc_first_char "${_info?}" || true)"
  fi
}

find_bootloader()
{
  local _val

  if _val="$(chosen_getprop 'ro.bootloader')" && is_valid_value "${_val?}"; then
    :
  elif _val="$(chosen_getprop 'ro.boot.bootloader')" && is_valid_value "${_val?}"; then
    :
  else
    show_warn 'Build.BOOTLOADER not found'
    printf '%s' 'unknown'
    return 1
  fi

  printf '%s' "${_val?}"
}

find_radio()
{
  local _val

  if _val="$(chosen_getprop 'gsm.version.baseband')" && is_valid_value "${_val?}"; then
    :
  elif _val="$(chosen_getprop 'ro.baseband')" && is_valid_value "${_val?}"; then
    :
  elif _val="$(chosen_getprop 'ro.boot.baseband')" && is_valid_value "${_val?}"; then
    :
  elif _val="$(chosen_getprop 'ril.sw_ver')" && is_valid_value "${_val?}"; then
    :
  else
    show_warn 'Build.RADIO not found'
    printf '%s' 'unknown'
    return 1
  fi

  printf '%s' "${_val?}"
}

find_serialno()
{
  local _val

  if compare_nocase "${BUILD_MANUFACTURER?}" 'Lenovo' && _val="$(chosen_getprop 'ro.lenovosn2')" && is_valid_serial "${_val?}"; then
    :
  elif _val="$(chosen_getprop 'ril.serialnumber')" && is_valid_serial "${_val?}"; then
    :
  elif _val="$(chosen_getprop 'ro.serialno')" && is_valid_serial "${_val?}"; then
    :
  elif _val="$(chosen_getprop 'sys.serialnumber')" && is_valid_serial "${_val?}"; then
    :
  elif _val="$(chosen_getprop 'ro.boot.serialno')" && is_valid_serial "${_val?}"; then
    :
  elif _val="$(chosen_getprop 'ro.kernel.androidboot.serialno')" && is_valid_serial "${_val?}"; then
    :
  else
    show_warn 'Serial number not found'
    return 1
  fi

  printf '%s' "${_val?}"
}

find_imei()
{
  local _imei
  if test "${INPUT_TYPE:?}" != 'adb'; then return 2; fi
  _imei="$(adb shell 'service call iphonesubinfo 1' | cut -d "'" -f '2' -s | LC_ALL=C tr -d '.[:cntrl:]')" || _imei=''

  if contains 'Requires READ_PHONE_STATE' "${_imei?}"; then
    show_warn 'Unable to find IMEI due to lack of permissions'
    return 1
  fi

  if ! is_valid_value "${_imei?}"; then
    show_warn 'IMEI not found'
    return 1
  fi

  printf '%s\n' "${_imei?}"
}

anonymize_string()
{
  printf '%s' "${1?}" | LC_ALL=C tr '[:digit:]' '0' | LC_ALL=C tr 'a-f' 'f' | LC_ALL=C tr 'g-z' 'x' | LC_ALL=C tr 'A-F' 'F' | LC_ALL=C tr 'G-Z' 'X'
}

anonymize_serialno()
{
  local _string _prefix_length

  if test "${#1}" -lt 2; then
    show_error 'Invalid serial number'
    return 1
  fi

  _prefix_length="$((${#1} / 2))"
  if test "${_prefix_length:?}" -gt 6; then _prefix_length='6'; fi

  printf '%s' "${1:?}" | cut -c "-${_prefix_length:?}" | LC_ALL=C tr -d '[:cntrl:]'

  _string="$(printf '%s' "${1:?}" | cut -c "$((${_prefix_length:?} + 1))-" | LC_ALL=C tr -d '[:cntrl:]')"
  anonymize_string "${_string:?}"
}

show_info "${PROFGEN_NAME:?} ${PROFGEN_VERSION:?} by ale5000"
if test -z "${*}"; then
  readonly INPUT_TYPE='adb'
else
  readonly INPUT_TYPE="${1:?}"
fi

if test "${INPUT_TYPE:?}" = 'adb'; then
  command -v adb 1> /dev/null || {
    show_error 'adb is NOT available'
    exit 1
  }

  wait_device
  show_info 'Generating profile...'
else
  test -e "${INPUT_TYPE:?}" || {
    show_error "Input file doesn't exist => '${INPUT_TYPE:-}'"
    exit 1
  }

  show_info 'Generating profile...'
  if grep -m 1 -q -e '^\[.*\]\:[[:blank:]]\[.*\]' -- "${INPUT_TYPE:?}"; then
    readonly PROP_TYPE='1'
  else
    readonly PROP_TYPE='2'
    show_warn 'Profiles generated this way will be incomplete!!!'
  fi
fi

# Infos:
# - https://github.com/microg/GmsCore/blob/master/play-services-base/core/src/main/kotlin/org/microg/gms/profile/ProfileManager.kt
# - https://android.googlesource.com/platform/frameworks/base/+/refs/heads/master/core/java/android/os/Build.java

BUILD_BOARD="$(validated_chosen_getprop ro.product.board)"

BUILD_BOOTLOADER="$(find_bootloader)"
BUILD_BOOTLOADER_EXPECT="$(chosen_getprop 'ro.build.expect.bootloader')" || BUILD_BOOTLOADER_EXPECT=''
if is_valid_value "${BUILD_BOOTLOADER_EXPECT?}" && test "${BUILD_BOOTLOADER_EXPECT?}" != "${BUILD_BOOTLOADER?}"; then
  show_warn "Build.BOOTLOADER does NOT match, current: ${BUILD_BOOTLOADER:-}, expected: ${BUILD_BOOTLOADER_EXPECT:-}"
fi

BUILD_BRAND="$(validated_chosen_getprop ro.product.brand)"
BUILD_CPU_ABI="$(validated_chosen_getprop ro.product.cpu.abi)"
BUILD_CPU_ABI2="$(validated_chosen_getprop ro.product.cpu.abi2 2)"
BUILD_DEVICE="$(validated_chosen_getprop ro.product.device)"
BUILD_DISPLAY="$(validated_chosen_getprop ro.build.display.id)"
BUILD_FINGERPRINT="$(validated_chosen_getprop ro.build.fingerprint)"
BUILD_HARDWARE="$(validated_chosen_getprop ro.hardware)"
BUILD_HOST="$(validated_chosen_getprop ro.build.host)"
BUILD_ID="$(validated_chosen_getprop ro.build.id)"
BUILD_MANUFACTURER="$(validated_chosen_getprop ro.product.manufacturer)"
BUILD_MODEL="$(validated_chosen_getprop ro.product.model)"
BUILD_PRODUCT="$(validated_chosen_getprop ro.product.name)"

BUILD_RADIO="$(find_radio)"
BUILD_RADIO_EXPECT="$(chosen_getprop 'ro.build.expect.baseband')" || BUILD_RADIO_EXPECT=''
if is_valid_value "${BUILD_RADIO_EXPECT?}" && test "${BUILD_RADIO_EXPECT?}" != "${BUILD_RADIO?}"; then
  show_warn "Build.RADIO does NOT match, current: ${BUILD_RADIO:-}, expected: ${BUILD_RADIO_EXPECT:-}"
fi

BUILD_TAGS="$(validated_chosen_getprop ro.build.tags)"

BUILD_TIME_HUMAN=''
if BUILD_TIME="$(validated_chosen_getprop ro.build.date.utc)"; then
  BUILD_TIME_HUMAN="$(LC_ALL=C date -u -d "@${BUILD_TIME:?}" '+%a %b %d %H:%M:%S %Z %Y')"
  BUILD_TIME="${BUILD_TIME:?}000"
fi

BUILD_TYPE="$(validated_chosen_getprop ro.build.type)"
BUILD_USER="$(validated_chosen_getprop ro.build.user)"
BUILD_VERSION_CODENAME="$(validated_chosen_getprop ro.build.version.codename)"
BUILD_VERSION_INCREMENTAL="$(validated_chosen_getprop ro.build.version.incremental)"
BUILD_VERSION_RELEASE="$(validated_chosen_getprop ro.build.version.release)"
BUILD_VERSION_SECURITY_PATCH="$(validated_chosen_getprop ro.build.version.security_patch 2)"
BUILD_VERSION_SDK="$(validated_chosen_getprop ro.build.version.sdk)"        # ToDO: If not numeric or empty return 0
BUILD_SUPPORTED_ABIS="$(validated_chosen_getprop ro.product.cpu.abilist 2)" # ToDO: Auto-generate it if missing

if IMEI="$(find_imei)"; then
  show_info "IMEI: ${IMEI:-}"
else
  IMEI=''
fi

ANON_SERIAL_NUMBER=''
if SERIAL_NUMBER="$(find_serialno)"; then
  show_info "Serial number: ${SERIAL_NUMBER:-}"
  ANON_SERIAL_NUMBER="$(anonymize_serialno "${SERIAL_NUMBER:?}")"
fi

MARKETING_DEVICE_INFO="$(chosen_getprop 'ro.config.marketing_name')" || MARKETING_DEVICE_INFO=''
DEVICE_INFO="$(generate_device_info)"
REAL_SECURITY_PATCH=''

ROM_MOD_VER="$(chosen_getprop 'ro.mod.version')" || ROM_MOD_VER=''
if LOS_VERSION="$(chosen_getprop 'ro.cm.build.version')" && is_valid_value "${LOS_VERSION?}"; then
  ROM_INFO="LineageOS ${LOS_VERSION:?} - ${BUILD_VERSION_RELEASE:?}"
elif EMUI_VERSION="$(chosen_getprop 'ro.build.version.emui')" && is_valid_value "${EMUI_VERSION?}"; then # Huawei
  EMUI_VERSION="$(printf '%s' "${EMUI_VERSION:?}" | cut -d '_' -f 2)"
  ROM_INFO="EMUI ${EMUI_VERSION:?} - ${BUILD_VERSION_RELEASE:?}"

  if REAL_SECURITY_PATCH="$(chosen_getprop 'ro.huawei.build.version.security_patch')" && is_valid_value "${REAL_SECURITY_PATCH?}"; then
    REAL_SECURITY_PATCH=" <!-- Real security patch: ${REAL_SECURITY_PATCH:-} -->"
  fi
elif MIUI_VERSION="$(chosen_getprop 'ro.miui.ui.version.name')" && is_valid_value "${MIUI_VERSION?}"; then # Xiaomi
  ROM_INFO="MIUI ${MIUI_VERSION:?} - ${BUILD_VERSION_RELEASE:?}"
elif LEAPD_VERSION="$(chosen_getprop 'ro.leapdroid.version')" && is_valid_value "${LEAPD_VERSION?}"; then
  ROM_INFO="Leapdroid - ${BUILD_VERSION_RELEASE:?}"
elif is_valid_value "${ROM_MOD_VER?}"; then
  ROM_INFO="Android MOD ${ROM_MOD_VER?} - ${BUILD_VERSION_RELEASE:?}"
else
  ROM_INFO="Android ${BUILD_VERSION_RELEASE?}"
fi

printf 1>&2 '\n'
printf '%s\n' "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<!--
    SPDX-FileCopyrightText: none
    SPDX-License-Identifier: CC0-1.0
    SPDX-FileType: SOURCE
-->

<profile name=\"${DEVICE_INFO?} (${ROM_INFO:?})\" product=\"${BUILD_PRODUCT:?}\" sdk=\"${BUILD_VERSION_SDK:?}\" id=\"${BUILD_PRODUCT:?}_${BUILD_VERSION_SDK:?}\" auto=\"true\">
    <!-- Generated by ${PROFGEN_SHORTNAME:?} ${PROFGEN_VERSION:?} of ale5000 -->
    <data key=\"Build.BOARD\" value=\"${BUILD_BOARD?}\" />
    <data key=\"Build.BOOTLOADER\" value=\"${BUILD_BOOTLOADER?}\" />
    <data key=\"Build.BRAND\" value=\"${BUILD_BRAND?}\" />
    <data key=\"Build.CPU_ABI\" value=\"${BUILD_CPU_ABI?}\" />
    <data key=\"Build.CPU_ABI2\" value=\"${BUILD_CPU_ABI2?}\" />
    <data key=\"Build.DEVICE\" value=\"${BUILD_DEVICE?}\" />
    <data key=\"Build.DISPLAY\" value=\"${BUILD_DISPLAY?}\" />
    <data key=\"Build.FINGERPRINT\" value=\"${BUILD_FINGERPRINT?}\" />
    <data key=\"Build.HARDWARE\" value=\"${BUILD_HARDWARE?}\" />
    <data key=\"Build.HOST\" value=\"${BUILD_HOST?}\" />
    <data key=\"Build.ID\" value=\"${BUILD_ID?}\" />
    <data key=\"Build.MANUFACTURER\" value=\"${BUILD_MANUFACTURER?}\" />
    <data key=\"Build.MODEL\" value=\"${BUILD_MODEL?}\" />
    <data key=\"Build.PRODUCT\" value=\"${BUILD_PRODUCT:?}\" />
    <data key=\"Build.RADIO\" value=\"${BUILD_RADIO?}\" />
    <data key=\"Build.TAGS\" value=\"${BUILD_TAGS?}\" />
    <data key=\"Build.TIME\" value=\"${BUILD_TIME?}\" /> <!-- ${BUILD_TIME_HUMAN?} -->
    <data key=\"Build.TYPE\" value=\"${BUILD_TYPE?}\" />
    <data key=\"Build.USER\" value=\"${BUILD_USER?}\" />
    <data key=\"Build.VERSION.CODENAME\" value=\"${BUILD_VERSION_CODENAME?}\" />
    <data key=\"Build.VERSION.INCREMENTAL\" value=\"${BUILD_VERSION_INCREMENTAL?}\" />
    <data key=\"Build.VERSION.RELEASE\" value=\"${BUILD_VERSION_RELEASE?}\" />
    <data key=\"Build.VERSION.SECURITY_PATCH\" value=\"${BUILD_VERSION_SECURITY_PATCH?}\" />${REAL_SECURITY_PATCH?}
    <data key=\"Build.VERSION.SDK\" value=\"${BUILD_VERSION_SDK:?}\" />
    <data key=\"Build.VERSION.SDK_INT\" value=\"${BUILD_VERSION_SDK:?}\" />
    <data key=\"Build.SUPPORTED_ABIS\" value=\"${BUILD_SUPPORTED_ABIS?}\" />

    <serial template=\"${ANON_SERIAL_NUMBER?}\" />
</profile>"

# shellcheck disable=SC3028 # In POSIX sh, SHLVL is undefined
if test "${CI:-false}" = 'false' && test "${SHLVL:-}" = '1' && test -t 1 && test -t 2; then
  printf 1>&2 '\n\033[1;32m' || true
  # shellcheck disable=SC3045
  IFS='' read 1>&2 -r -s -n 1 -p 'Press any key to continue...' _ || true
  printf 1>&2 '\033[0m\n' || true
fi
