#!/sbin/sh
# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# shellcheck disable=SC3043
# SC3043: In POSIX sh, local is undefined

umask 022

# shellcheck disable=SC3040
set -o pipefail || true

### GLOBAL VARIABLES ###

export DEBUG_LOG=0
export RECOVERY_API_VER="${1}"
export OUTFD="${2}"
export RECOVERY_PIPE="/proc/self/fd/${2}"
export ZIP_FILE="${3}"
ZIP_PATH="$(dirname "${ZIP_FILE:?}")"
export ZIP_PATH
BASE_TMP_PATH="${TMPDIR:-/tmp}"
TMP_PATH="${TMPDIR:-/tmp}/custom-setup-a5k"

MANUAL_TMP_MOUNT=0
GENER_ERROR=0
STATUS=1

LIVE_SETUP_POSSIBLE=false
export KEYCHECK_ENABLED=false
export BOOTMODE=false


### FUNCTIONS ###

DEBUG_LOG_ENABLED=0
enable_debug_log()
{
  if test "${DEBUG_LOG_ENABLED}" -eq 1; then return; fi
  DEBUG_LOG_ENABLED=1
  exec 3>&1 4>&2  # Backup stdout and stderr
  exec 1>>"${ZIP_PATH}/debug-a5k.log" 2>&1
}

disable_debug_log()
{
  if test "${DEBUG_LOG_ENABLED}" -eq 0; then return; fi
  DEBUG_LOG_ENABLED=0
  exec 1>&3 2>&4  # Restore stdout and stderr
}

_show_text_on_recovery()
{
  if test -e "${RECOVERY_PIPE}"; then
    printf "ui_print %s\nui_print \n" "${1}" >> "${RECOVERY_PIPE}"
  else
    printf "ui_print %s\nui_print \n" "${1}" 1>&"${OUTFD}"
  fi
}

ui_error()
{
  ERROR_CODE=79
  if test -n "$2"; then ERROR_CODE="$2"; fi
  echo "ERROR ${ERROR_CODE}: $1" >&2
  _show_text_on_recovery "ERROR: $1"
  exit "${ERROR_CODE}"
}

ui_warning()
{
  echo "WARNING: $1" >&2
  _show_text_on_recovery "WARNING: $1"
}

ui_msg()
{
  if test "${DEBUG_LOG}" -ne 0; then echo "$1"; fi
  if test -e "${RECOVERY_PIPE}"; then
    printf "ui_print %s\nui_print \n" "${1}" >> "${RECOVERY_PIPE}"
  else
    printf "ui_print %s\nui_print \n" "${1}" 1>&"${OUTFD}"
  fi
}

ui_debug()
{
  echo "$1"
}

is_mounted()
{
  local _partition _mount_result
  _partition="$(readlink -f "${1:?}")" || { _partition="${1:?}"; ui_warning "Failed to canonicalize '${1}'"; }
  _mount_result="$(mount)" || { test -e '/proc/mounts' && _mount_result="$(cat /proc/mounts)"; } || ui_error 'is_mounted has failed'

  case "${_mount_result:?}" in
    *[[:blank:]]"${_partition:?}"[[:blank:]]*) return 0;;  # Mounted
    *)                                                     # NOT mounted
  esac
  return 1  # NOT mounted
}

set_perm()
{
  local uid="$1"; local gid="$2"; local mod="$3"
  shift 3
  chown "${uid}:${gid}" "$@" || chown "${uid}.${gid}" "$@" || ui_error "chown failed on: $*" 81
  chmod "${mod}" "$@" || ui_error "chmod failed on: $*" 81
}

set_perm_safe()
{
  local uid="$1"; local gid="$2"; local mod="$3"
  shift 3
  chown "${uid}:${gid}" "$@" || chown "${uid}.${gid}" "$@" || ui_error "chown failed on: $*" 81
  "${OUR_BB}" chmod "${mod}" "$@" || ui_error "chmod failed on: $*" 81
}

package_extract_file()
{
  unzip -opq "${ZIP_FILE}" "$1" > "$2" || ui_error "Failed to extract the file '$1' from this archive" 82
  if ! test -e "$2"; then ui_error "Failed to extract the file '$1' from this archive" 82; fi
}

package_extract_file_safe()
{
  "${OUR_BB}" unzip -opq "${ZIP_FILE}" "$1" > "$2" || ui_error "Failed to extract the file '$1' from this archive" 83
  if ! test -e "$2"; then ui_error "Failed to extract the file '$1' from this archive" 83; fi
}

create_dir()
{
  mkdir -p "$1" || ui_error "Failed to create the dir: $1" 84
  set_perm 0 0 0755 "$1"
}

create_dir_safe()
{
  "${OUR_BB}" mkdir -p "$1" || ui_error "Failed to create the dir: $1" 84
  set_perm_safe 0 0 0755 "$1"
}

delete_safe()
{
  "${OUR_BB}" rm -f "$@" || ui_error "Failed to delete files" 85
}

delete_recursive_safe()
{
  "${OUR_BB}" rm -rf "$@" || ui_error "Failed to delete files/folders" 86
}

parse_busybox_version()
{
  head -n1 | grep -oE 'BusyBox v[0-9]+\.[0-9]+\.[0-9]+' | cut -d 'v' -f 2
}

numerically_comparable_version()
{
  echo "${@:?}" | awk -F. '{ printf("%d%03d%03d%03d\n", $1, $2, $3, $4); }'
}

# Input related functions
check_key()
{
  case "${1?}" in
    42)   # Vol +
      return 3;;
    21)   # Vol -
      return 2;;
    132)  # Error (example: Illegal instruction)
      return 1;;
    *)
      return 0;;
  esac
}

_choose_remapper()
{
  case "${1:?}" in
    '+')  # +
      return 3;;
    '-')  # -
      return 2;;
    'Enter')
      return 0;;
    *)    # All other keys
      return 0;;
  esac
}

choose_binary_timeout()
{
  local _timeout_ver
  local key_code=1

  _timeout_ver="$(timeout --help 2>&1 | parse_busybox_version)" || _timeout_ver=''
  if test -z "${_timeout_ver?}" || test "$(numerically_comparable_version "${_timeout_ver:?}" || true)" -ge "$(numerically_comparable_version '1.30.0' || true)"; then
    timeout "${1:?}" keycheck; key_code="${?}"
  else
    timeout -t "${1:?}" keycheck; key_code="${?}"
  fi

  # Timeout return 127 when it cannot execute the binary
  if test "${key_code?}" = '143'; then
    ui_msg 'Key code: No key pressed'
    return 0
  elif test "${key_code?}" = '127' || test "${key_code?}" = '132'; then
    ui_msg 'WARNING: Key detection failed'
    return 1
  fi

  ui_msg "Key code: ${key_code?}"
  check_key "${key_code?}"
  return "${?}"
}

choose_timeout()
{
  local _key _status
  _status='0'

  # shellcheck disable=SC3045
  IFS='' read -rsn1 -t"${1:?}" -- _key || _status="${?}"
  case "${_status:?}" in
    0)        # 0: Command terminated successfully
      if test -z "${_key?}"; then _key='Enter'; fi;;
    1 | 142)  # 1: Command timed out on BusyBox, 142: Command timed out on Bash
      ui_msg 'Key: No key pressed'
      return 0;;
    *)
      ui_warning 'Key detection failed'
      return 1;;
  esac

  ui_msg "Key: ${_key:?}"
  _choose_remapper "${_key:?}"
  return "${?}"
}

choose_binary()
{
  local key_code=1
  ui_msg "QUESTION: ${1:?}"
  ui_msg "${2:?}"
  ui_msg "${3:?}"
  keycheck; key_code="${?}"
  ui_msg "Key code: ${key_code?}"
  check_key "${key_code?}"
  return "${?}"
}

choose_shell()
{
  local _key
  ui_msg "QUESTION: ${1:?}"
  ui_msg "${2:?}"
  ui_msg "${3:?}"
  # shellcheck disable=SC3045
  IFS='' read -rsn1 -- _key || { ui_warning 'Key detection failed'; return 1; }
  if test -z "${_key?}"; then _key='Enter'; fi

  ui_msg "Key press: ${_key:?}"
  _choose_remapper "${_key:?}"
  return "${?}"
}

choose()
{
  if "${KEYCHECK_ENABLED:?}"; then
    choose_binary "${@}"
  else
    choose_shell "${@}"
  fi
  return "${?}"
}


### CODE ###

test "${DEBUG_LOG}" -eq 1 && enable_debug_log  # Enable file logging if needed

ui_debug 'PRELOADER'
if ! is_mounted "${BASE_TMP_PATH:?}"; then
  # Workaround: create and mount the temp folder if it isn't already mounted
  MANUAL_TMP_MOUNT=1
  ui_msg 'WARNING: Creating and mounting the missing temp folder...'
  if ! test -e "${BASE_TMP_PATH:?}"; then create_dir "${BASE_TMP_PATH:?}"; fi
  mount -t tmpfs -o rw tmpfs "${BASE_TMP_PATH:?}"
  set_perm 0 2000 0775 "${BASE_TMP_PATH:?}"

  if ! is_mounted "${BASE_TMP_PATH:?}"; then ui_error 'The temp folder CANNOT be mounted'; fi
fi

detect_recovery_arch()
{
  case "$(uname -m)" in
    x86_64 | x64              ) RECOVERY_ARCH='x86_64';;
    x86 | i686                ) RECOVERY_ARCH='x86';;
    aarch64 | arm64* | armv8* ) RECOVERY_ARCH='arm64-v8a';;
    armv7*                    ) RECOVERY_ARCH='armeabi-v7a';;
    armv6* | armv5*           ) RECOVERY_ARCH='armeabi';;
    *) ui_error "Unsupported architecture: $(uname -m || true)"
  esac
}
detect_recovery_arch

OUR_BB="${BASE_TMP_PATH}/busybox"
if test -n "${CUSTOM_BUSYBOX:-}" && test -e "${CUSTOM_BUSYBOX}"; then
  OUR_BB="${CUSTOM_BUSYBOX}"
  ui_debug "Using custom BusyBox... '${OUR_BB}'"
elif test "${RECOVERY_ARCH}" = 'x86_64'; then
  ui_debug 'Extracting 64-bit x86 BusyBox...'
  package_extract_file 'misc/busybox/busybox-x86_64.bin' "${OUR_BB}"
elif test "${RECOVERY_ARCH}" = 'x86'; then
  ui_debug 'Extracting x86 BusyBox...'
  package_extract_file 'misc/busybox/busybox-x86.bin' "${OUR_BB}"
elif test "${RECOVERY_ARCH}" = 'arm64-v8a'; then
  ui_debug 'Extracting 64-bit ARM BusyBox...'
  package_extract_file 'misc/busybox/busybox-arm64.bin' "${OUR_BB}"
  package_extract_file 'misc/keycheck/keycheck-arm' "${BASE_TMP_PATH}/keycheck"
elif test "${RECOVERY_ARCH}" = 'armeabi-v7a' || test "${RECOVERY_ARCH}" = 'armeabi'; then
  ui_debug 'Extracting ARM BusyBox...'
  package_extract_file 'misc/busybox/busybox-arm.bin' "${OUR_BB}"
  package_extract_file 'misc/keycheck/keycheck-arm' "${BASE_TMP_PATH}/keycheck"
fi
if ! test -e "${OUR_BB}"; then ui_error 'BusyBox not found'; fi

# Give execution rights (if needed)
if test -z "${CUSTOM_BUSYBOX:-}" || test "${OUR_BB}" != "${CUSTOM_BUSYBOX}"; then
  chmod +x "${OUR_BB}" || ui_error "chmod failed on '${OUR_BB}'" 81  # Needed to make working the "safe" functions
  set_perm 0 0 0755 "${OUR_BB}"
fi

# Delete previous traces
delete_recursive_safe "${TMP_PATH}"
create_dir_safe "${TMP_PATH}"
create_dir_safe "${TMP_PATH}/bin"

PREVIOUS_PATH="${PATH}"
DEVICE_MOUNT="$(command -v -- mount)" || DEVICE_MOUNT=''
export DEVICE_MOUNT

if test "${TEST_INSTALL:-false}" = 'false'; then
  # Clean search path so only internal BusyBox applets will be used
  export PATH="${TMP_PATH}/bin"

  # Temporarily setup BusyBox
  "${OUR_BB}" --install -s "${TMP_PATH}/bin" || ui_error "Failed to setup BusyBox"
fi

# Temporarily setup Keycheck
if test -e "${BASE_TMP_PATH}/keycheck"; then
  "${OUR_BB}" mv -f "${BASE_TMP_PATH}/keycheck" "${TMP_PATH}/bin/keycheck" || ui_error "Failed to move keycheck to the bin folder"
  # Give execution rights
  set_perm_safe 0 0 0755 "${TMP_PATH}/bin/keycheck"
  LIVE_SETUP_POSSIBLE=true
  KEYCHECK_ENABLED=true
fi

# Enable the binary-free live setup when inside the recovery simulator
if test "${TEST_INSTALL:-false}" != 'false'; then LIVE_SETUP_POSSIBLE=true; KEYCHECK_ENABLED=false; fi

# Live setup isn't supported under continuous integration system
# Live setup doesn't work when executed through Gradle
if test "${CI:-false}" != 'false' || test "${APP_NAME:-false}" = 'Gradle'; then
  LIVE_SETUP_POSSIBLE=false
  LIVE_SETUP=0
fi

# Extract scripts
ui_debug 'Extracting scripts...'
create_dir_safe "${TMP_PATH}/inc"
package_extract_file_safe 'inc/common-functions.sh' "${TMP_PATH}/inc/common-functions.sh"
package_extract_file_safe 'uninstall.sh' "${TMP_PATH}/uninstall.sh"
package_extract_file_safe 'install.sh' "${TMP_PATH}/install.sh"
# Give execution rights
set_perm_safe 0 0 0755 "${TMP_PATH}/inc/common-functions.sh"
set_perm_safe 0 0 0755 "${TMP_PATH}/uninstall.sh"
set_perm_safe 0 0 0755 "${TMP_PATH}/install.sh"

package_extract_file_safe 'settings.conf' "${TMP_PATH}/default-settings.conf"
# shellcheck source=SCRIPTDIR/../../../../settings.conf
. "${TMP_PATH}/default-settings.conf"
test "${DEBUG_LOG}" -eq 1 && enable_debug_log  # Enable file logging if needed

# If the debug log was enabled at startup (not in the settings or in the live setup) we cannot allow overriding it from the settings
if [ "${DEBUG_LOG_ENABLED}" -eq 1 ]; then export DEBUG_LOG=1; fi

# Detect boot mode
# shellcheck disable=SC2009
(ps | grep zygote | grep -v grep >/dev/null) && BOOTMODE=true
# shellcheck disable=SC2009
"${BOOTMODE}" || (ps -A 2>/dev/null | grep zygote | grep -v grep >/dev/null && BOOTMODE=true)

# Live setup
if "${LIVE_SETUP_POSSIBLE:?}" && test "${LIVE_SETUP:?}" -eq 0 && test "${LIVE_SETUP_TIMEOUT:?}" -ge 1; then
  ui_msg '---------------------------------------------------'
  ui_msg 'INFO: Select the VOLUME + key to enable live setup.'
  ui_msg "Waiting input for ${LIVE_SETUP_TIMEOUT} seconds..."
  if "${KEYCHECK_ENABLED}"; then
    choose_binary_timeout "${LIVE_SETUP_TIMEOUT}"
  else
    choose_timeout "${LIVE_SETUP_TIMEOUT}"
  fi
  if test "${?}" = '3'; then export LIVE_SETUP=1; fi
fi

if test "${LIVE_SETUP}" = '1'; then
  ui_msg 'LIVE SETUP ENABLED!'
  if test "${DEBUG_LOG}" = '0'; then
    choose 'Do you want to enable the debug log?' '+) Yes' '-) No'; if test "${?}" = '3'; then export DEBUG_LOG=1; enable_debug_log; fi
  fi
fi

ui_debug ''
ui_debug 'Starting installation script...'
"${OUR_BB}" sh "${TMP_PATH}/install.sh" Preloader "${TMP_PATH}"; STATUS="$?"

test -f "${TMP_PATH}/installed" || GENER_ERROR=1

export PATH="${PREVIOUS_PATH}"
delete_recursive_safe "${TMP_PATH}"

#!!! UNSAFE ENVIRONMENT FROM HERE !!!#

test "${DEBUG_LOG}" -eq 1 && disable_debug_log  # Disable debug log and restore normal output

if test "${MANUAL_TMP_MOUNT}" -ne 0; then
  "${OUR_BB}" umount "${BASE_TMP_PATH:?}" || ui_error 'Failed to unmount the temp folder'
fi

if test "${STATUS}" -ne 0; then ui_error "Installation script failed with error ${STATUS}" "${STATUS}"; fi
if test "${GENER_ERROR}" -ne 0; then ui_error 'Installation failed with an unknown error'; fi

delete_safe "${BASE_TMP_PATH}/busybox"
