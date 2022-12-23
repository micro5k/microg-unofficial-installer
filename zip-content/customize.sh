#!/sbin/sh
# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# shellcheck disable=SC3043 # In POSIX sh, local is undefined

set -u || true
umask 022 || exit 1

### PREVENTIVE CHECKS ###

DEBUG_LOG=0
if test -z "${BOOTMODE:-}"; then
  printf 1>&2 '%s\n' 'Missing BOOTMODE variable'
  abort 'Missing BOOTMODE variable' 2> /dev/null || exit 1
fi
if test -z "${OUTFD:-}"; then
  printf 1>&2 '%s\n' 'Missing OUTFD variable'
  abort 'Missing OUTFD variable' 2> /dev/null || exit 1
fi
RECOVERY_PIPE="/proc/self/fd/${OUTFD:?}"
if test -z "${ZIPFILE:-}"; then ui_error 'Missing ZIPFILE variable'; fi
if test -z "${TMPDIR:-}" || test ! -e "${TMPDIR:?}"; then ui_error 'The temp folder is missing (2)'; fi

export DEBUG_LOG
export BOOTMODE
export OUTFD
export RECOVERY_PIPE
export ZIPFILE
export TMPDIR
unset REPLACE

### MAGISK VARIABLES ###

SKIPUNZIP=1
export SKIPUNZIP

### GLOBAL VARIABLES ###

export RECOVERY_API_VER="${1:-}"
ZIP_PATH="$(dirname "${ZIPFILE:?}")"
export ZIP_PATH

BASE_TMP_PATH="${TMPDIR:?}"
TMP_PATH="${TMPDIR:?}/custom-setup-a5k"

export LIVE_SETUP_POSSIBLE=false
export KEYCHECK_ENABLED=false

### FUNCTIONS ###

export DEBUG_LOG_ENABLED=0
enable_debug_log()
{
  if test "${DEBUG_LOG_ENABLED}" -eq 1; then return; fi
  DEBUG_LOG_ENABLED=1
  exec 3>&1 4>&2 # Backup stdout and stderr
  exec 1>> "${ZIP_PATH}/debug-a5k.log" 2>&1
}

disable_debug_log()
{
  if test "${DEBUG_LOG_ENABLED}" -eq 0; then return; fi
  DEBUG_LOG_ENABLED=0
  exec 1>&3 2>&4 # Restore stdout and stderr
}

_show_text_on_recovery()
{
  if test "${BOOTMODE:?}" = 'true'; then
    printf '%s\n' "${1?}"
    return
  elif test -e "${RECOVERY_PIPE:?}"; then
    printf 'ui_print %s\nui_print\n' "${1?}" >> "${RECOVERY_PIPE:?}"
  else
    printf 'ui_print %s\nui_print\n' "${1?}" 1>&"${OUTFD:?}"
  fi

  if test "${DEBUG_LOG:?}" -ne 0; then printf '%s\n' "${1?}"; fi
}

ui_error()
{
  ERROR_CODE=79
  if test -n "${2:-}"; then ERROR_CODE="${2:?}"; fi
  _show_text_on_recovery "ERROR: ${1:?}"
  printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR ${ERROR_CODE:?}: ${1:?}"
  abort '' 2> /dev/null || exit "${ERROR_CODE:?}"
}

ui_warning()
{
  _show_text_on_recovery "WARNING: ${1:?}"
  printf 1>&2 '\033[0;33m%s\033[0m\n' "WARNING: ${1:?}"
}

ui_msg()
{
  _show_text_on_recovery "${1:?}"
}

ui_debug()
{
  printf '%s\n' "${1?}"
}

set_perm()
{
  local uid="$1"
  local gid="$2"
  local mod="$3"
  shift 3
  chown "${uid}:${gid}" "$@" || chown "${uid}.${gid}" "$@" || ui_error "chown failed on: $*" 81
  chmod "${mod}" "$@" || ui_error "chmod failed on: $*" 81
}

set_perm_safe()
{
  local uid="$1"
  local gid="$2"
  local mod="$3"
  shift 3
  chown "${uid}:${gid}" "$@" || chown "${uid}.${gid}" "$@" || ui_error "chown failed on: $*" 81
  "${OUR_BB}" chmod "${mod}" "$@" || ui_error "chmod failed on: $*" 81
}

package_extract_file()
{
  unzip -opq "${ZIPFILE:?}" "${1:?}" 1> "${2:?}" || ui_error "Failed to extract the file '${1}' from this archive" 82
  if ! test -e "${2:?}"; then ui_error "Failed to extract the file '${1}' from this archive" 82; fi
}

package_extract_file_safe()
{
  "${OUR_BB}" unzip -opq "${ZIPFILE:?}" "${1:?}" 1> "${2:?}" || ui_error "Failed to extract the file '${1}' from this archive" 83
  if ! test -e "${2:?}"; then ui_error "Failed to extract the file '${1}' from this archive" 83; fi
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

### CODE ###

ui_debug 'PRELOADER 2'

detect_recovery_arch()
{
  case "$(uname -m)" in
    x86_64 | x64)                       RECOVERY_ARCH='x86_64' ;;
    x86 | x86abi | i686 | i586)         RECOVERY_ARCH='x86' ;;
    aarch64 | arm64* | armv9* | armv8*) RECOVERY_ARCH='arm64-v8a' ;;
    armv7*)                             RECOVERY_ARCH='armeabi-v7a' ;;
    armv6* | armv5*)                    RECOVERY_ARCH='armeabi' ;;
    #mips64)                             RECOVERY_ARCH='mips64' ;;
    #mips)                               RECOVERY_ARCH='mips' ;;
    *) ui_error "Unsupported architecture: $(uname -m || true)" ;;
  esac
}
detect_recovery_arch

OUR_BB="${BASE_TMP_PATH:?}/busybox"
if test -n "${CUSTOM_BUSYBOX:-}" && test -e "${CUSTOM_BUSYBOX:?}"; then
  OUR_BB="${CUSTOM_BUSYBOX:?}"
  ui_debug "Using custom BusyBox... '${OUR_BB:?}'"
elif test "${RECOVERY_ARCH}" = 'x86_64'; then
  ui_debug 'Extracting 64-bit x86 BusyBox...'
  package_extract_file 'misc/busybox/busybox-x86_64.bin' "${OUR_BB:?}"
elif test "${RECOVERY_ARCH}" = 'x86'; then
  ui_debug 'Extracting x86 BusyBox...'
  package_extract_file 'misc/busybox/busybox-x86.bin' "${OUR_BB:?}"
elif test "${RECOVERY_ARCH}" = 'arm64-v8a'; then
  ui_debug 'Extracting 64-bit ARM BusyBox...'
  package_extract_file 'misc/busybox/busybox-arm64.bin' "${OUR_BB:?}"
  package_extract_file 'misc/keycheck/keycheck-arm.bin' "${BASE_TMP_PATH:?}/keycheck"
elif test "${RECOVERY_ARCH}" = 'armeabi-v7a' || test "${RECOVERY_ARCH}" = 'armeabi'; then
  ui_debug 'Extracting ARM BusyBox...'
  package_extract_file 'misc/busybox/busybox-arm.bin' "${OUR_BB:?}"
  package_extract_file 'misc/keycheck/keycheck-arm.bin' "${BASE_TMP_PATH:?}/keycheck"
fi
if ! test -e "${OUR_BB:?}"; then ui_error 'BusyBox not found'; fi

# Give execution rights (if needed)
if test -z "${CUSTOM_BUSYBOX:-}" || test "${OUR_BB:?}" != "${CUSTOM_BUSYBOX:?}"; then
  # Legacy versions of chmod don't support +x and --
  chmod 0755 "${OUR_BB:?}" || ui_error "chmod failed on '${OUR_BB:?}'" # Needed to make working the "safe" functions
fi

# Delete previous traces (if they exist) and setup our temp folder
"${OUR_BB:?}" rm -rf "${TMP_PATH:?}" || ui_error "Failed to delete previous files"
"${OUR_BB:?}" mkdir -p "${TMP_PATH:?}" || ui_error "Failed to create the temp folder"
set_perm_safe 0 0 0755 "${TMP_PATH:?}"

PREVIOUS_PATH="${PATH}"
DEVICE_MOUNT="$(command -v -- mount)" || DEVICE_MOUNT=''
export DEVICE_MOUNT

if test "${TEST_INSTALL:-false}" = 'false'; then
  create_dir_safe "${TMP_PATH:?}/bin"
  # Clean search path so only internal BusyBox applets will be used
  export PATH="${TMP_PATH:?}/bin"

  # Temporarily setup BusyBox
  "${OUR_BB:?}" --install -s "${TMP_PATH:?}/bin" || ui_error "Failed to setup BusyBox"

  # Temporarily setup Keycheck
  if test -e "${BASE_TMP_PATH:?}/keycheck"; then
    "${OUR_BB:?}" mv -f "${BASE_TMP_PATH:?}/keycheck" "${TMP_PATH:?}/bin/keycheck" || ui_error "Failed to move keycheck to the bin folder"
    # Give execution rights
    "${OUR_BB:?}" chmod 0755 "${TMP_PATH:?}/bin/keycheck" || ui_error "chmod failed on keycheck"
    LIVE_SETUP_POSSIBLE=true
    KEYCHECK_ENABLED=true
  fi
fi

# Enable the binary-free live setup when inside the recovery simulator
if test "${TEST_INSTALL:-false}" != 'false'; then
  LIVE_SETUP_POSSIBLE=true
  KEYCHECK_ENABLED=false
fi

# Live setup isn't supported under continuous integration system
# Live setup doesn't work when executed through Gradle
if test "${CI:-false}" != 'false' || test "${APP_NAME:-false}" = 'Gradle'; then
  LIVE_SETUP_POSSIBLE=false
fi

# Extract scripts
ui_debug 'Extracting scripts...'
create_dir_safe "${TMP_PATH:?}/inc"
package_extract_file_safe 'inc/common-functions.sh' "${TMP_PATH:?}/inc/common-functions.sh"
package_extract_file_safe 'scripts/uninstall.sh' "${TMP_PATH:?}/uninstall.sh"
package_extract_file_safe 'scripts/install.sh' "${TMP_PATH:?}/install.sh"
# Give execution rights
set_perm_safe 0 0 0755 "${TMP_PATH:?}/inc/common-functions.sh"
set_perm_safe 0 0 0755 "${TMP_PATH:?}/uninstall.sh"
set_perm_safe 0 0 0755 "${TMP_PATH:?}/install.sh"

package_extract_file_safe 'settings.conf' "${TMP_PATH:?}/default-settings.conf"
# shellcheck source=SCRIPTDIR/settings-full.conf
. "${TMP_PATH:?}/default-settings.conf"
test "${DEBUG_LOG}" -eq 1 && enable_debug_log # Enable file logging if needed

# If the debug log was enabled at startup (not in the settings or in the live setup) we cannot allow overriding it from the settings
if [ "${DEBUG_LOG_ENABLED}" -eq 1 ]; then export DEBUG_LOG=1; fi

ui_debug ''
ui_debug 'Starting installation script...'
"${OUR_BB:?}" sh "${TMP_PATH:?}/install.sh" Preloader "${TMP_PATH:?}"
export STATUS="${?}"
if test -f "${TMP_PATH:?}/installed"; then export UNKNOWN_ERROR=0; else export UNKNOWN_ERROR=1; fi

export PATH="${PREVIOUS_PATH?}"
delete_recursive_safe "${TMP_PATH:?}"

#!!! UNSAFE ENVIRONMENT FROM HERE !!!#

test "${DEBUG_LOG}" -eq 1 && disable_debug_log # Disable debug log and restore normal output
delete_safe "${BASE_TMP_PATH:?}/busybox"
