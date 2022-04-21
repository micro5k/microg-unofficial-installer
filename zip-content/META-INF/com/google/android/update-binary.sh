#!/sbin/sh
# shellcheck disable=SC3043
# SC3043: In POSIX sh, local is undefined

# SPDX-FileCopyrightText: (c) 2016-2019, 2021 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

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

KEYCHECK_ENABLED=false
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
  case $(mount) in
    *[[:blank:]]"$1"[[:blank:]]*) return 0;;  # Mounted
    *)                                        # NOT mounted
  esac
  return 1  # NOT mounted
}

set_perm()
{
  local uid="$1"; local gid="$2"; local mod="$3"
  shift 3
  if test "${TEST_INSTALL:-false}" = 'false'; then
    chown "${uid}:${gid}" "$@" || chown "${uid}.${gid}" "$@" || ui_error "chown failed on: $*" 81
  fi
  chmod "${mod}" "$@" || ui_error "chmod failed on: $*" 81
}

set_perm_safe()
{
  local uid="$1"; local gid="$2"; local mod="$3"
  shift 3
  if test "${TEST_INSTALL:-false}" = 'false'; then
    "${OUR_BB}" chown "${uid}:${gid}" "$@" || "${OUR_BB}" chown "${uid}.${gid}" "$@" || ui_error "chown failed on: $*" 81
  fi
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

# Input related functions
check_key()
{
  case "$1" in
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

choose_timeout()
{
  local key_code=1
  timeout -t "$1" keycheck; key_code="$?"  # Timeout return 127 when it cannot execute the binary
  if test "${key_code}" -eq 143; then
    ui_msg 'Key code: No key pressed'
    return 0
  elif test "${key_code}" -eq 127 || test "${key_code}" -eq 132; then
    ui_msg 'WARNING: Key detection failed'
    return 1
  fi

  ui_msg "Key code: ${key_code}"
  check_key "${key_code}"
  return "$?"
}

choose()
{
  local key_code=1
  ui_msg "QUESTION: $1"
  ui_msg "$2"
  ui_msg "$3"
  keycheck; key_code="$?"
  ui_msg "Key code: ${key_code}"
  check_key "${key_code}"
  return "$?"
}


### CODE ###

test "${DEBUG_LOG}" -eq 1 && enable_debug_log  # Enable file logging if needed

ui_debug 'PRELOADER'
if ! is_mounted '/tmp'; then
  # Workaround: create and mount /tmp if it isn't already mounted
  MANUAL_TMP_MOUNT=1
  ui_msg 'WARNING: Creating missing /tmp...'
  if [ ! -e '/tmp' ]; then create_dir '/tmp'; fi
  mount -t tmpfs -o rw tmpfs /tmp
  set_perm 0 2000 0775 '/tmp'

  if ! is_mounted '/tmp'; then ui_error '/tmp is NOT mounted'; fi
fi

detect_recovery_arch()
{
  case "$(uname -m)" in
    x86_64                    ) RECOVERY_ARCH='x86_64';;
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
if test "${OUR_BB}" != "${CUSTOM_BUSYBOX}"; then
  chmod +x "${OUR_BB}" || ui_error "chmod failed on '${OUR_BB}'" 81  # Needed to make working the "safe" functions
  set_perm 0 0 0755 "${OUR_BB}"
fi

# Delete previous traces
delete_recursive_safe "${TMP_PATH}"
create_dir_safe "${TMP_PATH}"
create_dir_safe "${TMP_PATH}/bin"

PREVIOUS_PATH="${PATH}"

# Clean search path so only internal BusyBox applets will be used
export PATH="${TMP_PATH}/bin"

# Temporarily setup BusyBox
"${OUR_BB}" --install -s "${TMP_PATH}/bin"

# Temporarily setup Keycheck
if test -e "${BASE_TMP_PATH}/keycheck"; then
  "${OUR_BB}" mv -f "${BASE_TMP_PATH}/keycheck" "${TMP_PATH}/bin/keycheck" || ui_error "Failed to move keycheck to the bin folder"
  # Give execution rights
  set_perm_safe 0 0 0755 "${TMP_PATH}/bin/keycheck"
  KEYCHECK_ENABLED=true
fi

# Extract scripts
ui_debug 'Extracting scripts...'
create_dir_safe "${TMP_PATH}/inc"
package_extract_file_safe 'inc/common.sh' "${TMP_PATH}/inc/common.sh"
package_extract_file_safe 'uninstall.sh' "${TMP_PATH}/uninstall.sh"
package_extract_file_safe 'install.sh' "${TMP_PATH}/install.sh"
# Give execution rights
set_perm_safe 0 0 0755 "${TMP_PATH}/inc/common.sh"
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
if "${KEYCHECK_ENABLED}" && [ "${LIVE_SETUP}" -eq 0 ] && [ "${LIVE_SETUP_TIMEOUT}" -ge 1 ]; then
  ui_msg '---------------------------------------------------'
  ui_msg 'INFO: Select the VOLUME + key to enable live setup.'
  ui_msg "Waiting input for ${LIVE_SETUP_TIMEOUT} seconds..."
  choose_timeout "${LIVE_SETUP_TIMEOUT}"
  if test "$?" -eq 3; then export LIVE_SETUP=1; fi
fi

if [ "${LIVE_SETUP}" -eq 1 ]; then
  ui_msg 'LIVE SETUP ENABLED!'
  if [ "${DEBUG_LOG}" -eq 0 ]; then
    choose 'Do you want to enable the debug log?' '+) Yes' '-) No'; if [ "$?" -ne 2 ]; then export DEBUG_LOG=1; enable_debug_log; fi
  fi
fi

ui_msg ''
ui_debug 'Starting installation script...'
"${OUR_BB}" ash "${TMP_PATH}/install.sh" Preloader "${TMP_PATH}"; STATUS="$?"

test -f "${TMP_PATH}/installed" || GENER_ERROR=1

export PATH="${PREVIOUS_PATH}"
delete_recursive_safe "${TMP_PATH}"

#!!! UNSAFE ENVIRONMENT FROM HERE !!!#

test "${DEBUG_LOG}" -eq 1 && disable_debug_log  # Disable debug log and restore normal output

if test "${MANUAL_TMP_MOUNT}" -ne 0; then
  "${OUR_BB}" umount '/tmp' || ui_error "Failed to unmount '/tmp'"
fi

if test "${STATUS}" -ne 0; then ui_error "Installation script failed with error ${STATUS}" "${STATUS}"; fi
if test "${GENER_ERROR}" -ne 0; then ui_error 'Installation failed with an unknown error'; fi

delete_safe "${BASE_TMP_PATH}/busybox"
