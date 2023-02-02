#!/sbin/sh
# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# shellcheck disable=SC3043 # In POSIX sh, local is undefined

umask 022 || exit 1
set -u || true
# shellcheck disable=SC3040,SC2015
{
  # Unsupported set -o options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue and also handle the set -e case
  (set -o posix 2> /dev/null) && set -o posix || true
  (set -o pipefail 2> /dev/null) && set -o pipefail || true
}

### PREVENTIVE CHECKS ###

if test -z "${BOOTMODE:-}"; then
  printf 1>&2 '%s\n' 'Missing BOOTMODE variable'
  abort 'Missing BOOTMODE variable' 2> /dev/null || exit 1
fi
if test -z "${OUTFD:-}" || test "${OUTFD:?}" -lt 1; then
  printf 1>&2 '%s\n' 'Missing or invalid OUTFD variable'
  abort 'Missing or invalid OUTFD variable' 2> /dev/null || exit 1
fi
RECOVERY_PIPE="/proc/self/fd/${OUTFD:?}"
if test -z "${ZIPFILE:-}"; then ui_error 'Missing ZIPFILE variable'; fi
if test -z "${TMPDIR:-}" || test ! -e "${TMPDIR:?}"; then ui_error 'The temp folder is missing (2)'; fi

export BOOTMODE
export OUTFD
export RECOVERY_PIPE
export ZIPFILE
export TMPDIR
export ANDROID_ROOT
export ANDROID_DATA
unset REPLACE

### MAGISK VARIABLES ###

SKIPUNZIP=1
ASH_STANDALONE=1
export SKIPUNZIP ASH_STANDALONE

### GLOBAL VARIABLES ###

if test "${4:-}" = 'zip-install'; then readonly ZIP_INSTALL='true'; else readonly ZIP_INSTALL='false'; fi

if test "${ZIP_INSTALL:?}" = 'true' || test "${BOOTMODE:?}" = 'true' || test "${OUTFD:?}" = '1'; then
  readonly RECOVERY_OUTPUT='false'
else
  readonly RECOVERY_OUTPUT='true'
fi

readonly RECOVERY_API_VER="${1:-}"

export ZIP_INSTALL RECOVERY_OUTPUT RECOVERY_API_VER

ZIP_PATH="$(dirname "${ZIPFILE:?}")"
export ZIP_PATH

BASE_TMP_PATH="${TMPDIR:?}"
TMP_PATH="${TMPDIR:?}/custom-setup-a5k"

case "${ZIP_PATH:?}" in
  /sideload) SIDELOAD='true' ;;
  /dev/rootfs*/sideload) SIDELOAD='true' ;;
  *) SIDELOAD='false' ;;
esac
readonly SIDELOAD
export SIDELOAD

_log_path_setter()
{
  if test ! -e "${1:?}"; then return 1; fi

  local _path
  _path="$(readlink -f "${1:?}")" || _path="$(realpath "${1:?}")" || return 1
  if test -w "${_path:?}"; then
    LOG_PATH="${_path:?}/debug-a5k.log"
    return 0
  fi

  return 1
}
if test "${SIDELOAD:?}" = 'false' && _log_path_setter "${ZIP_PATH:?}"; then
  : # OK
elif _log_path_setter '/sdcard0' || _log_path_setter '/sdcard' || _log_path_setter '/mnt/sdcard'; then
  : # OK
else
  LOG_PATH="${TMPDIR:?}/debug-a5k.log"
fi
unset -f _log_path_setter || true
readonly LOG_PATH
export LOG_PATH

export KEYCHECK_ENABLED=false

### FUNCTIONS ###

ui_debug()
{
  printf '%s\n' "${1?}"
}

export DEBUG_LOG_ENABLED=0
enable_debug_log()
{
  if test "${DEBUG_LOG_ENABLED}" -eq 1; then return; fi
  export DEBUG_LOG_ENABLED=1

  ui_debug "Creating log: ${LOG_PATH:?}"
  touch "${LOG_PATH:?}" || {
    ui_warning "Unable to write the log file at: ${LOG_PATH:-}"
    export DEBUG_LOG_ENABLED=0
    return
  }

  # If they are already in use, then use alternatives
  if { true 1>&6 || true 1>&7; } 2> /dev/null; then
    export ALTERNATIVE_FDS=1
    # shellcheck disable=SC3023
    exec 88>&1 89>&2 # Backup stdout and stderr
  else
    export ALTERNATIVE_FDS=0
    exec 6>&1 7>&2 # Backup stdout and stderr
  fi
  exec 1>> "${LOG_PATH:?}" 2>&1
}

disable_debug_log()
{
  if test "${DEBUG_LOG_ENABLED}" -ne 1; then return; fi
  export DEBUG_LOG_ENABLED=0
  if test "${ALTERNATIVE_FDS:?}" -eq 0; then
    exec 1>&6 2>&7 # Restore stdout and stderr
    exec 6>&- 7>&-
  else
    exec 1>&88 2>&89 # Restore stdout and stderr
    # shellcheck disable=SC3023
    exec 88>&- 89>&-
  fi
}

_show_text_on_recovery()
{
  if test "${RECOVERY_OUTPUT:?}" != 'true'; then return; fi # Nothing to do here

  if test -e "${RECOVERY_PIPE:?}"; then
    printf 'ui_print %s\nui_print\n' "${1?}" >> "${RECOVERY_PIPE:?}"
  else
    printf 'ui_print %s\nui_print\n' "${1?}" 1>&"${OUTFD:?}"
  fi

  if test "${DEBUG_LOG_ENABLED:?}" -eq 1; then printf 1>&2 '%s\n' "${1?}"; fi
}

ui_error()
{
  ERROR_CODE=79
  if test -n "${2:-}"; then ERROR_CODE="${2:?}"; fi

  if test "${RECOVERY_OUTPUT:?}" = 'true'; then
    _show_text_on_recovery "ERROR ${ERROR_CODE:?}: ${1:?}"
  else
    printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR ${ERROR_CODE:?}: ${1:?}"
  fi

  abort '' 2> /dev/null || exit "${ERROR_CODE:?}"
}

ui_warning()
{
  if test "${RECOVERY_OUTPUT:?}" = 'true'; then
    _show_text_on_recovery "WARNING: ${1:?}"
  else
    printf 1>&2 '\033[0;33m%s\033[0m\n' "WARNING: ${1:?}"
  fi
}

ui_msg()
{
  if test "${RECOVERY_OUTPUT:?}" = 'true'; then
    _show_text_on_recovery "${1:?}"
  else
    printf '%s\n' "${1:?}"
  fi
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
DEVICE_MOUNT="$(command -v mount)" || DEVICE_MOUNT=''
readonly DEVICE_MOUNT
export DEVICE_MOUNT

if test "${TEST_INSTALL:-false}" = 'false'; then
  create_dir_safe "${TMP_PATH:?}/bin"
  # Clean search path so only internal BusyBox applets will be used
  export PATH="${TMP_PATH:?}/bin"

  # Setup BusyBox in the temp folder
  "${OUR_BB:?}" --install -s "${TMP_PATH:?}/bin" || ui_error "Failed to setup BusyBox"
fi

DEBUG_LOG="${DEBUG_LOG:-0}"
test "${DEBUG_LOG:?}" -ne 0 && enable_debug_log # Enable file logging if needed

LIVE_SETUP_ALLOWED='false'
KEYCHECK_PATH=''
if test "${ZIP_INSTALL:?}" = 'true' || test "${TEST_INSTALL:-false}" != 'false'; then
  # Enable the binary-free live setup when using zip-install.sh or when inside the recovery simulator
  LIVE_SETUP_ALLOWED='true'
  "${OUR_BB:?}" rm -f "${BASE_TMP_PATH:?}/keycheck" || ui_error "Failed to remove keycheck"
else
  # Setup Keycheck in the temp folder
  if test -e "${BASE_TMP_PATH:?}/keycheck"; then
    LIVE_SETUP_ALLOWED='true'
    KEYCHECK_PATH="${TMP_PATH:?}/bin/keycheck"
    "${OUR_BB:?}" mv -f "${BASE_TMP_PATH:?}/keycheck" "${KEYCHECK_PATH:?}" || ui_error "Failed to move keycheck to the bin folder"
    # Give execution rights
    "${OUR_BB:?}" chmod 0755 "${KEYCHECK_PATH:?}" || ui_error "chmod failed on keycheck"
    KEYCHECK_ENABLED='true'
  fi
fi

# Live setup under continuous integration systems doesn't make sense
# Live setup doesn't work when executed through Gradle
if test "${CI:-false}" != 'false' || test "${APP_NAME:-false}" = 'Gradle'; then
  LIVE_SETUP_ALLOWED='false'
fi

readonly LIVE_SETUP_ALLOWED KEYCHECK_PATH
export LIVE_SETUP_ALLOWED KEYCHECK_PATH

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
test "${DEBUG_LOG:?}" -ne 0 && enable_debug_log # Enable file logging if needed

# If the debug log was enabled at startup (not in the settings or in the live setup) we cannot allow overriding it from the settings
if test "${DEBUG_LOG_ENABLED}" -eq 1; then export DEBUG_LOG=1; fi

ui_debug ''
ui_debug 'Starting installation script...'
"${OUR_BB:?}" sh "${TMP_PATH:?}/install.sh" Preloader "${TMP_PATH:?}"
export STATUS="${?}"
if test -f "${TMP_PATH:?}/installed"; then export UNKNOWN_ERROR=0; else export UNKNOWN_ERROR=1; fi

disable_debug_log # Disable debug log if it was enabled and restore normal output

export PATH="${PREVIOUS_PATH?}"
delete_recursive_safe "${TMP_PATH:?}"

#!!! UNSAFE ENVIRONMENT FROM HERE !!!#

delete_safe "${BASE_TMP_PATH:?}/busybox"
