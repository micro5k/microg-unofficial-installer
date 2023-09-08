#!/sbin/sh
# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck disable=SC3043 # In POSIX sh, local is undefined #

echo 'PRELOADER'

### INIT OPTIONS ###

umask 022 || true
set -u || true
# shellcheck disable=SC3040,SC2015
{
  # Unsupported set options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue
  (set -o posix 2> /dev/null) && set -o posix || true
  (set -o pipefail 2> /dev/null) && set -o pipefail || true
}

### GLOBAL VARIABLES ###

export OUTFD="${2:?}"
export ZIPFILE="${3:?}"

### PREVENTIVE CHECKS ###

command 1> /dev/null -v printf || {
  if command 1> /dev/null -v busybox; then
    alias printf='busybox printf'
  else
    {
      printf()
      {
        if test "${1:-}" = '%s\n\n'; then _printf_newline='true'; fi
        if test "${#}" -gt 1; then shift; fi
        echo "${@}"

        test "${_printf_newline:-false}" = 'false' || echo ''
        unset _printf_newline
      }
    }
  fi
}

command 1> /dev/null -v uname || {
  if command 1> /dev/null -v getprop; then
    uname()
    {
      if test "${1:-}" != '-m'; then ui_error 'Unsupported parameters for uname'; fi

      _uname_val="$(getprop 'ro.product.cpu.abi')"
      case "${_uname_val?}" in
        'armeabi-v7a') _uname_val='armv7l' ;;
        'armeabi') _uname_val='armv6l' ;;
        *) ;;
      esac

      printf '%s\n' "${_uname_val?}"
      unset _uname_val
    }
  fi
}

command 1> /dev/null -v dirname || {
  dirname()
  {
    printf '%s\n' "${1%/*}"
  }
}

command 1> /dev/null -v unzip || {
  if command 1> /dev/null -v busybox; then
    alias unzip='busybox unzip'
  else
    printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR: Missing => unzip"
    exit 100
  fi
}

### FUNCTIONS AND CODE ###

# Detect whether we are in boot mode
_ub_detect_bootmode()
{
  if test -n "${BOOTMODE:-}"; then return; fi
  BOOTMODE=false
  # shellcheck disable=SC2009
  if pgrep -f -x 'zygote' 1> /dev/null 2>&1 || pgrep -f -x 'zygote64' 1> /dev/null 2>&1 || ps | grep 'zygote' | grep -v 'grep' 1> /dev/null || ps -A 2> /dev/null | grep 'zygote' | grep -v 'grep' 1> /dev/null; then
    BOOTMODE=true
  fi
  readonly BOOTMODE
  export BOOTMODE
}

_show_text_on_recovery()
{
  if test "${BOOTMODE:?}" = 'true'; then
    printf '%s\n' "${1?}"
    return
  elif test -e "/proc/self/fd/${OUTFD:?}"; then
    printf 'ui_print %s\nui_print\n' "${1?}" >> "/proc/self/fd/${OUTFD:?}"
  else
    printf 'ui_print %s\nui_print\n' "${1?}" 1>&"${OUTFD:?}"
  fi
}

ui_error()
{
  ERROR_CODE=79
  if test -n "${2:-}"; then ERROR_CODE="${2:?}"; fi
  _show_text_on_recovery "ERROR ${ERROR_CODE:?}: ${1:?}"
  printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR ${ERROR_CODE:?}: ${1:?}"
  abort '' 2> /dev/null || exit "${ERROR_CODE:?}"
}

set_perm()
{
  local uid="${1:?}"
  local gid="${2:?}"
  local mod="${3:?}"
  shift 3
  test -n "${*}" || ui_error "Missing parameter on set_perm: $*"
  chown "${uid:?}:${gid:?}" "${@}" || chown "${uid:?}.${gid:?}" "${@}" || ui_error "chown failed on: $*"
  chmod "${mod:?}" "${@}" || ui_error "chmod failed on: $*"
}

package_extract_file()
{
  unzip -opq "${ZIPFILE:?}" "${1:?}" 1> "${2:?}" || ui_error "Failed to extract the file '${1}' from this archive"
  if ! test -e "${2:?}"; then ui_error "Failed to extract the file '${1}' from this archive"; fi
}

_ub_detect_bootmode
_ub_we_mounted_tmp=false

# Workaround: Create (if needed) and mount the temp folder if it isn't already mounted
{
  _ub_is_mounted()
  {
    local _mount_result
    {
      test -e '/proc/mounts' && _mount_result="$(cat /proc/mounts)"
    } || _mount_result="$(mount 2> /dev/null)" || ui_error '_ub_is_mounted has failed'

    case "${_mount_result:?}" in
      *[[:blank:]]"${1:?}"[[:blank:]]*) return 0 ;; # Mounted
      *) ;;                                         # NOT mounted
    esac
    return 1 # NOT mounted
  }

  if test -n "${TMPDIR:-}" && test -w "${TMPDIR:?}"; then
    : # Already ready
  elif test -w '/tmp' && _ub_is_mounted '/tmp'; then
    TMPDIR='/tmp'
  elif test -e '/dev' && _ub_is_mounted '/dev'; then
    mkdir -p '/dev/tmp' || ui_error 'Failed to create the temp folder'
    set_perm 0 2000 01775 '/dev/tmp'
    TMPDIR='/dev/tmp'
  else
    _ub_we_mounted_tmp=true

    _show_text_on_recovery 'WARNING: Creating (if needed) and mounting the temp folder...'
    printf 1>&2 '\033[0;33m%s\033[0m\n' 'WARNING: Creating (if needed) and mounting the temp folder...'
    if test ! -e '/tmp'; then
      mkdir -p '/tmp' || ui_error 'Failed to create the temp folder'
      set_perm 0 0 0755 '/tmp'
    fi

    mount -t 'tmpfs' -o 'rw' tmpfs '/tmp' || ui_error 'Failed to mount the temp folder'
    if ! _ub_is_mounted '/tmp'; then ui_error 'The temp folder CANNOT be mounted'; fi
    set_perm 0 2000 01775 '/tmp'

    TMPDIR='/tmp'
  fi
  unset -f _ub_is_mounted || ui_error 'Failed to unset _ub_is_mounted'

  if test -z "${TMPDIR:-}" || test ! -w "${TMPDIR:?}"; then
    ui_error 'The temp folder is missing or not writable'
  fi
  export TMPDIR
}

# Seed the RANDOM variable
RANDOM="${$:?}${$:?}"

# shellcheck disable=SC3028
{
  if test "${RANDOM:?}" = "${$:?}${$:?}"; then ui_error "\$RANDOM is not supported"; fi # Both BusyBox and Toybox support $RANDOM
  _ub_our_main_script="${TMPDIR:?}/${RANDOM:?}-customize.sh"
}

STATUS=1
UNKNOWN_ERROR=1

package_extract_file 'customize.sh' "${_ub_our_main_script:?}"
# shellcheck source=SCRIPTDIR/../../../../customize.sh
. "${_ub_our_main_script:?}" || ui_error "Failed to source customize.sh"
rm -f "${_ub_our_main_script:?}" || ui_error "Failed to delete customize.sh"
unset _ub_our_main_script

if test "${_ub_we_mounted_tmp:?}" = true; then
  umount '/tmp' || ui_error 'Failed to unmount the temp folder'
fi

if test "${STATUS:?}" -ne 0; then ui_error "Installation script failed" "${STATUS}"; fi
if test "${UNKNOWN_ERROR:?}" -ne 0; then ui_error 'Installation failed with an unknown error'; fi
