#!/sbin/sh
# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined #

### INIT OPTIONS ###

umask 022 || :
set -u 2> /dev/null || :

# Unsupported set options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue
{
  # shellcheck disable=all
  (set -o pipefail 1> /dev/null 2>&1) && set -o pipefail || :
}

### PREVENTIVE CHECKS ###

if test -z "${BOOTMODE-}"; then
  printf 1>&2 '%s\n' 'Missing BOOTMODE variable'
  abort 2> /dev/null 'Missing BOOTMODE variable'
  exit 1
fi
if test -z "${ZIPFILE-}"; then
  printf 1>&2 '%s\n' 'Missing ZIPFILE variable'
  abort 2> /dev/null 'Missing ZIPFILE variable'
  exit 1
fi
if test -z "${TMPDIR-}" || test ! -w "${TMPDIR:?}"; then
  printf 1>&2 '%s\n' 'The temp folder is missing (2)'
  abort 2> /dev/null 'The temp folder is missing (2)'
  exit 1
fi
if test -z "${OUTFD-}" || test "${OUTFD:?}" -lt 1; then
  printf 1>&2 '%s\n' 'Missing or invalid OUTFD variable'
  abort 2> /dev/null  'Missing or invalid OUTFD variable'
  exit 1
fi
RECOVERY_PIPE="/proc/self/fd/${OUTFD:?}"
test -e "${RECOVERY_PIPE:?}" || RECOVERY_PIPE=''

export BOOTMODE
export ZIPFILE
export TMPDIR
export OUTFD
export RECOVERY_PIPE
export ANDROID_ROOT
export ANDROID_DATA
unset REPLACE

### MAGISK VARIABLES ###

SKIPUNZIP=1
ASH_STANDALONE=1
readonly SKIPUNZIP ASH_STANDALONE
export SKIPUNZIP ASH_STANDALONE

### GLOBAL VARIABLES ###

export DEBUG_LOG_ENABLED=0
readonly FORCE_HW_KEYS="${FORCE_HW_KEYS:-0}"

readonly RECOVERY_API_VER="${1:-}"
if test "${4:-}" = 'zip-install'; then
  readonly ZIP_INSTALL='true'
  readonly ZIPINSTALL_VERSION="${5:-}"
else
  readonly ZIP_INSTALL='false'
  readonly ZIPINSTALL_VERSION=''
fi
export RECOVERY_API_VER ZIP_INSTALL ZIPINSTALL_VERSION

if test "${ZIP_INSTALL:?}" = 'true' || test "${BOOTMODE:?}" = 'true' || test "${OUTFD:?}" -le 2; then
  readonly RECOVERY_OUTPUT='false'
else
  readonly RECOVERY_OUTPUT='true'
fi
export RECOVERY_OUTPUT

if test "${FORCE_HW_KEYS:?}" = '0' && test -t 0 && { # Check if STDIN (0) is valid
  test "${ZIP_INSTALL:?}" = 'true' || test "${TEST_INSTALL:-false}" != 'false'
}; then
  readonly INPUT_FROM_TERMINAL='true'
else
  readonly INPUT_FROM_TERMINAL='false'
fi
export INPUT_FROM_TERMINAL

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
  _path="$(readlink 2> /dev/null -f "${1:?}")" || _path="$(realpath "${1:?}")" || return 1
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

### FUNCTIONS ###

_send_text_to_recovery()
{
  if test "${RECOVERY_OUTPUT:?}" != 'true'; then return; fi # Nothing to do here

  if test -n "${RECOVERY_PIPE?}"; then
    printf 'ui_print %s\nui_print\n' "${1?}" 1>> "${RECOVERY_PIPE:?}"
  else
    printf 'ui_print %s\nui_print\n' "${1?}" 1>&"${OUTFD:?}"
  fi

  if test "${DEBUG_LOG_ENABLED:?}" = '1'; then printf 1>&2 '%s\n' "${1?}"; fi
}

_print_text()
{
  if test -n "${NO_COLOR-}"; then
    printf '%s\n' "${2?}"
  else
    # shellcheck disable=SC2059
    printf "${1:?}\n" "${2?}"
  fi

  if test "${DEBUG_LOG_ENABLED:?}" = '1' && test -n "${ORIGINAL_STDERR_FD_PATH?}"; then printf '%s\n' "${2?}" 1>> "${ORIGINAL_STDERR_FD_PATH:?}"; fi
}

ui_error()
{
  local _error_code
  _error_code=79
  test -z "${2-}" || _error_code="${2:?}"

  if test "${RECOVERY_OUTPUT:?}" = 'true'; then
    _send_text_to_recovery "ERROR ${_error_code:?}: ${1:?}"
  else
    _print_text 1>&2 '\033[1;31m%s\033[0m' "ERROR ${_error_code:?}: ${1:?}"
  fi

  exit "${_error_code:?}"
}

ui_warning()
{
  if test "${RECOVERY_OUTPUT:?}" = 'true'; then
    _send_text_to_recovery "WARNING: ${1:?}"
  else
    _print_text 1>&2 '\033[0;33m%s\033[0m' "WARNING: ${1:?}"
  fi
}

ui_msg()
{
  if test "${RECOVERY_OUTPUT:?}" = 'true'; then
    _send_text_to_recovery "${1:?}"
  else
    _print_text '%s' "${1:?}"
  fi
}

ui_debug()
{
  _print_text 1>&2 '%s' "${1?}"
}

enable_debug_log()
{
  if test "${DEBUG_LOG_ENABLED}" -eq 1; then return; fi
  local _backup_stderr

  ui_debug "Creating log: ${LOG_PATH:?}"
  _send_text_to_recovery "Creating log: ${LOG_PATH:?}"

  touch "${LOG_PATH:?}" || {
    export DEBUG_LOG_ENABLED=0
    ui_warning "Unable to write the log file at: ${LOG_PATH:-}"
    return
  }

  # If they are already in use, then use alternatives
  if {
    command 1>&6 || command 1>&7
  } 2> /dev/null; then
    export ALTERNATIVE_FDS=1
    # shellcheck disable=SC3023
    exec 88>&1 89>&2 # Backup stdout and stderr
    _backup_stderr=89
  else
    export ALTERNATIVE_FDS=0
    exec 6>&1 7>&2 # Backup stdout and stderr
    _backup_stderr=7
  fi

  exec 1>> "${LOG_PATH:?}" 2>&1

  export NO_COLOR=1
  if test -e "/proc/$$/fd/${_backup_stderr:?}"; then
    export ORIGINAL_STDERR_FD_PATH="/proc/$$/fd/${_backup_stderr:?}"
  else
    export ORIGINAL_STDERR_FD_PATH=''
  fi
  export DEBUG_LOG_ENABLED=1
}

disable_debug_log()
{
  if test "${DEBUG_LOG_ENABLED}" -ne 1; then return; fi

  export DEBUG_LOG_ENABLED=0
  unset ORIGINAL_STDERR_FD_PATH
  unset NO_COLOR

  if test "${ALTERNATIVE_FDS:?}" -eq 0; then
    exec 1>&6 2>&7 # Restore stdout and stderr
    exec 6>&- 7>&-
  else
    exec 1>&88 2>&89 # Restore stdout and stderr
    # shellcheck disable=SC3023
    exec 88>&- 89>&-
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
  {
    unzip -o -p -qq "${ZIPFILE:?}" "${1:?}" 1> "${2:?}" && test -s "${2:?}"
  } ||
    {
      rm -f -- "${2:?}" || true
      ui_error "Failed to extract the file '${1}' from this archive" 82
    }
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

ui_debug 'LOADER'

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
if test -n "${CUSTOM_BUSYBOX-}" && test -x "${CUSTOM_BUSYBOX:?}"; then
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
elif test "${RECOVERY_ARCH}" = 'armeabi-v7a' || test "${RECOVERY_ARCH}" = 'armeabi'; then
  ui_debug 'Extracting ARM BusyBox...'
  package_extract_file 'misc/busybox/busybox-arm.bin' "${OUR_BB:?}"
fi
if test ! -e "${OUR_BB:?}"; then ui_error 'BusyBox not found'; fi

# Give execution rights (if needed)
if test -z "${CUSTOM_BUSYBOX-}" || test "${OUR_BB:?}" != "${CUSTOM_BUSYBOX:?}"; then
  # Legacy versions of chmod don't support +x and --
  chmod 0755 "${OUR_BB:?}" || ui_error "chmod failed on '${OUR_BB:?}'" # Needed to make working the "safe" functions
fi

# Delete previous traces (if they exist) and setup our temp folder
"${OUR_BB:?}" rm -rf "${TMP_PATH:?}" || ui_error "Failed to delete previous files"
"${OUR_BB:?}" mkdir -p "${TMP_PATH:?}" || ui_error "Failed to create the temp folder"
set_perm_safe 0 0 0755 "${TMP_PATH:?}"

PREVIOUS_PATH="${PATH:-%empty}"
DEVICE_TWRP="$(command -v twrp)" || DEVICE_TWRP=''
DEVICE_GETPROP="$(command -v getprop)" || DEVICE_GETPROP=''
DEVICE_MOUNT="$(command -v mount)" || DEVICE_MOUNT=''
DEVICE_DUMPSYS="$(command -v dumpsys)" || DEVICE_DUMPSYS=''
DEVICE_STAT="$(command -v stat)" || DEVICE_STAT=''
DEVICE_PM="$(command -v pm)" || DEVICE_PM=''
DEVICE_AM="$(command -v am)" || DEVICE_AM=''
DEVICE_APPOPS="$(command -v appops)" || DEVICE_APPOPS=''
readonly PREVIOUS_PATH DEVICE_TWRP DEVICE_GETPROP DEVICE_MOUNT DEVICE_DUMPSYS DEVICE_STAT DEVICE_PM DEVICE_AM DEVICE_APPOPS
export PREVIOUS_PATH DEVICE_TWRP DEVICE_GETPROP DEVICE_MOUNT DEVICE_DUMPSYS DEVICE_STAT DEVICE_PM DEVICE_AM DEVICE_APPOPS

if test "${TEST_INSTALL:-false}" = 'false'; then
  create_dir_safe "${TMP_PATH:?}/bin"
  # Clean search path so only internal BusyBox applets will be used
  export PATH="${TMP_PATH:?}/bin"

  # Setup BusyBox in the temp folder
  "${OUR_BB:?}" cp -p -f -- "${OUR_BB:?}" "${TMP_PATH:?}/bin/busybox" || ui_error "Failed to setup BusyBox"
  "${OUR_BB:?}" --install -s "${TMP_PATH:?}/bin" || ui_error "Failed to setup BusyBox"
fi

ui_debug 'Parsing common settings...'

simple_getprop()
{
  local _val

  if test -n "${DEVICE_GETPROP?}" && _val="$(PATH="${PREVIOUS_PATH:?}" "${DEVICE_GETPROP:?}" "${@}")"; then
    :
  elif command 1> /dev/null -v 'getprop' && _val="$(getprop "${@}")"; then
    :
  else
    return 2
  fi

  test -n "${_val?}" || return 1
  printf '%s\n' "${_val:?}"
}

_get_common_setting()
{
  simple_getprop "zip.common.${1:?}" ||
    printf '%s\n' "${2?}" # Fallback to the default value
}

DEBUG_LOG="$(_get_common_setting 'DEBUG_LOG' "${DEBUG_LOG:-0}")"

test "${DEBUG_LOG:?}" -ne 0 && enable_debug_log # Enable file logging if needed

LIVE_SETUP_ALLOWED="${LIVE_SETUP_ALLOWED:-true}"
if test "${CI:-false}" != 'false'; then LIVE_SETUP_ALLOWED='false'; fi # Live setup under continuous integration systems doesn't make sense

readonly LIVE_SETUP_ALLOWED
export LIVE_SETUP_ALLOWED

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
ui_debug 'Starting main script...'
if test "${COVERAGE:-false}" = 'false'; then
  "${OUR_BB:?}" sh "${TMP_PATH:?}/install.sh" Preloader "${TMP_PATH:?}"
else
  "${COVERAGE_SHELL:?}" -x -- "${TMP_PATH:?}/install.sh" Preloader "${TMP_PATH:?}"
fi
export STATUS="${?}"
if test -f "${TMP_PATH:?}/installed"; then export UNKNOWN_ERROR=0; else export UNKNOWN_ERROR=1; fi

# Safety check to allow unmounting even in case of failure
if test -e "${TMP_PATH:?}/system_mountpoint"; then
  "${OUR_BB:?}" 2> /dev/null umount "${TMP_PATH:?}/system_mountpoint" || umount 2> /dev/null "${TMP_PATH:?}/system_mountpoint" || true
  "${OUR_BB:?}" rmdir -- "${TMP_PATH:?}/system_mountpoint" || ui_error 'Failed to unmount/delete the temp mountpoint'
fi

ui_debug ''
disable_debug_log # Disable debug log if it was enabled and restore normal output

export PATH="${PREVIOUS_PATH?}"
delete_recursive_safe "${TMP_PATH:?}"

#!!! UNSAFE ENVIRONMENT FROM HERE !!!#

delete_safe "${BASE_TMP_PATH:?}/busybox"
