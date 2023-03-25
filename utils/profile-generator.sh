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

show_error()
{
  printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR: ${*}"
}

show_warn()
{
  printf 1>&2 '\033[0;33m%s\033[0m\n\n' "WARNING: ${*}"
}

is_valid_value()
{
  # 1 = Allow unknown
  # 2 = Allow empty

  if test -z "${1?}" && test "${2:-0}" != '2'; then return 1; fi
  if test "${1?}" = 'unknown' && test "${2:-0}" != '1'; then return 1; fi
  if test "${1?}" = '00000000000'; then return 1; fi

  return 0
}

lc_text()
{
  printf '%s\n' "${1:?}" | LC_ALL=C tr '[:upper:]' '[:lower:]'
}

uc_text()
{
  printf '%s\n' "${1:?}" | LC_ALL=C tr '[:lower:]' '[:upper:]'
}

uc_first_letter()
{
  printf '%s' "${1:?}" | cut -c '1' | LC_ALL=C tr -d '\r\n' | LC_ALL=C tr '[:lower:]' '[:upper:]'
  printf '%s\n' "${1:?}" | cut -c '2-'
}

adb_start()
{
  adb 'start-server' 2> /dev/null
}

device_getprop()
{
  adb shell "getprop '${1:?}'" | LC_ALL=C tr -d '\r\n'
}

validated_device_getprop()
{
  local _value
  _value="$(device_getprop "${1:?}")" || return 1

  if ! is_valid_value "${_value?}" "${2:-}"; then
    show_error "Invalid value for ${1:-}"
    return 1
  fi

  printf '%s\n' "${_value?}"
}

find_serialno()
{
  local _serialno=''

  if test "$(lc_text "${BUILD_MANUFACTURER:?}")" = 'lenovo'; then
    _serialno="$(device_getprop 'ro.lenovosn2')" || _serialno=''
  fi
  if ! is_valid_value "${_serialno?}"; then
    _serialno="$(device_getprop 'ril.serialnumber')" || _serialno=''
  fi
  if ! is_valid_value "${_serialno?}"; then
    _serialno="$(device_getprop 'ro.serialno')" || _serialno=''
  fi
  if ! is_valid_value "${_serialno?}"; then
    _serialno="$(device_getprop 'sys.serialnumber')" || _serialno=''
  fi
  if ! is_valid_value "${_serialno?}"; then
    show_warn 'Serial number not found'
    return 1
  fi

  printf '%s\n' "${_serialno?}"
}

command -v adb 1> /dev/null || {
  show_error 'adb is NOT available'
  exit 1
}

adb_start

# Info: https://android.googlesource.com/platform/frameworks/base/+/refs/heads/master/core/java/android/os/Build.java

BUILD_BOARD="$(validated_device_getprop ro.product.board)"

BUILD_BOOTLOADER="$(validated_device_getprop 'ro.bootloader' 1)"
BUILD_BOOTLOADER_2="$(device_getprop 'ro.build.expect.bootloader')" || BUILD_BOOTLOADER_2=''
if is_valid_value "${BUILD_BOOTLOADER_2?}" && test "${BUILD_BOOTLOADER_2?}" != "${BUILD_BOOTLOADER?}"; then
  show_warn "Expected Build.BOOTLOADER do NOT match: ${BUILD_BOOTLOADER_2:-}"
fi

BUILD_BRAND="$(validated_device_getprop ro.product.brand)"
BUILD_CPU_ABI="$(validated_device_getprop ro.product.cpu.abi)"
BUILD_CPU_ABI2="$(validated_device_getprop ro.product.cpu.abi2 2)"
BUILD_DEVICE="$(validated_device_getprop ro.product.device)"
BUILD_DISPLAY="$(validated_device_getprop ro.build.display.id)"
BUILD_FINGERPRINT="$(validated_device_getprop ro.build.fingerprint)"
BUILD_HARDWARE="$(validated_device_getprop ro.hardware)"
BUILD_HOST="$(validated_device_getprop ro.build.host)"
BUILD_ID="$(validated_device_getprop ro.build.id)"
BUILD_MANUFACTURER="$(validated_device_getprop ro.product.manufacturer)"
BUILD_MODEL="$(validated_device_getprop ro.product.model)"
BUILD_PRODUCT="$(validated_device_getprop ro.product.name)"
BUILD_RADIO="$(validated_device_getprop ro.baseband 1)"
BUILD_TAGS="$(validated_device_getprop ro.build.tags)"
BUILD_TIME="$(validated_device_getprop ro.build.date.utc)""000"
BUILD_TYPE="$(validated_device_getprop ro.build.type)"
BUILD_USER="$(validated_device_getprop ro.build.user)"
BUILD_VERSION_CODENAME="$(validated_device_getprop ro.build.version.codename)"
BUILD_VERSION_INCREMENTAL="$(validated_device_getprop ro.build.version.incremental)"
BUILD_VERSION_RELEASE="$(validated_device_getprop ro.build.version.release)"
BUILD_VERSION_SECURITY_PATCH="$(validated_device_getprop ro.build.version.security_patch 2)"
BUILD_VERSION_SDK="$(validated_device_getprop ro.build.version.sdk)"
BUILD_VERSION_SDK_INT="$(validated_device_getprop ro.build.version.sdk)"    # ToDO: If not numeric or empty return 0
BUILD_SUPPORTED_ABIS="$(validated_device_getprop ro.product.cpu.abilist 2)" # ToDO: Auto-generate it if missing
SERIAL_NUMBER="$(find_serialno)"

DEVICE_INFO="$(uc_first_letter "${BUILD_BRAND:?} ${BUILD_MODEL:?}")"
LOS_VERSION="$(device_getprop ro.cm.build.version)" || LOS_VERSION=''
if is_valid_value "${LOS_VERSION?}"; then
  ROM_INFO="LineageOS ${LOS_VERSION:?}"
else
  ROM_INFO="Android ${BUILD_VERSION_RELEASE:?}"
fi

printf '%s\n' "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<!--
    SPDX-FileCopyrightText: none
    SPDX-License-Identifier: CC0-1.0
    SPDX-FileType: SOURCE
-->

<profile name=\"${DEVICE_INFO:?} (${ROM_INFO:?})\" product=\"${BUILD_PRODUCT:?}\" sdk=\"${BUILD_VERSION_SDK_INT:?}\" id=\"${BUILD_PRODUCT:?}_${BUILD_VERSION_SDK:?}\" auto=\"true\">
    <data key=\"Build.BOARD\" value=\"${BUILD_BOARD:?}\" />
    <data key=\"Build.BOOTLOADER\" value=\"${BUILD_BOOTLOADER:?}\" />
    <data key=\"Build.BRAND\" value=\"${BUILD_BRAND:?}\" />
    <data key=\"Build.CPU_ABI\" value=\"${BUILD_CPU_ABI:?}\" />
    <data key=\"Build.CPU_ABI2\" value=\"${BUILD_CPU_ABI2?}\" />
    <data key=\"Build.DEVICE\" value=\"${BUILD_DEVICE:?}\" />
    <data key=\"Build.DISPLAY\" value=\"${BUILD_DISPLAY:?}\" />
    <data key=\"Build.FINGERPRINT\" value=\"${BUILD_FINGERPRINT:?}\" />
    <data key=\"Build.HARDWARE\" value=\"${BUILD_HARDWARE:?}\" />
    <data key=\"Build.HOST\" value=\"${BUILD_HOST:?}\" />
    <data key=\"Build.ID\" value=\"${BUILD_ID:?}\" />
    <data key=\"Build.MANUFACTURER\" value=\"${BUILD_MANUFACTURER:?}\" />
    <data key=\"Build.MODEL\" value=\"${BUILD_MODEL:?}\" />
    <data key=\"Build.PRODUCT\" value=\"${BUILD_PRODUCT:?}\" />
    <data key=\"Build.RADIO\" value=\"${BUILD_RADIO:?}\" />
    <data key=\"Build.TAGS\" value=\"${BUILD_TAGS:?}\" />
    <data key=\"Build.TIME\" value=\"${BUILD_TIME:?}\" />
    <data key=\"Build.TYPE\" value=\"${BUILD_TYPE:?}\" />
    <data key=\"Build.USER\" value=\"${BUILD_USER:?}\" />
    <data key=\"Build.VERSION.CODENAME\" value=\"${BUILD_VERSION_CODENAME:?}\" />
    <data key=\"Build.VERSION.INCREMENTAL\" value=\"${BUILD_VERSION_INCREMENTAL:?}\" />
    <data key=\"Build.VERSION.RELEASE\" value=\"${BUILD_VERSION_RELEASE:?}\" />
    <data key=\"Build.VERSION.SECURITY_PATCH\" value=\"${BUILD_VERSION_SECURITY_PATCH?}\" />
    <data key=\"Build.VERSION.SDK\" value=\"${BUILD_VERSION_SDK:?}\" />
    <data key=\"Build.VERSION.SDK_INT\" value=\"${BUILD_VERSION_SDK_INT:?}\" />
    <data key=\"Build.SUPPORTED_ABIS\" value=\"${BUILD_SUPPORTED_ABIS?}\" />

    <serial template=\"${SERIAL_NUMBER?}\" />
</profile>

<!-- Automatically generated from Android device profile generator by ale5000 -->"
