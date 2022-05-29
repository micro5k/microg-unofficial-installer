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

export OUTFD="${2}"
export RECOVERY_PIPE="/proc/self/fd/${2}"
export ZIPFILE="${3:?}"


### FUNCTIONS ###

_show_text_on_recovery()
{
  if test -e "${RECOVERY_PIPE:?}"; then
    printf "ui_print %s\nui_print \n" "${1?}" >> "${RECOVERY_PIPE:?}"
  else
    printf "ui_print %s\nui_print \n" "${1?}" 1>&"${OUTFD:?}"
  fi
}

ui_error()
{
  ERROR_CODE=79
  if test -n "${2}"; then ERROR_CODE="${2:?}"; fi
  1>&2 printf '\033[1;31m%s\033[0m\n' "ERROR ${ERROR_CODE:?}: ${1:?}"
  _show_text_on_recovery "ERROR: ${1:?}"
  exit "${ERROR_CODE:?}"
}

_updatebin_is_mounted()
{
  local _mount_result
  { test -e '/proc/mounts' && _mount_result="$(cat /proc/mounts)"; } || _mount_result="$(mount 2>/dev/null)" || ui_error '_updatebin_is_mounted has failed'

  case "${_mount_result:?}" in
    *[[:blank:]]"${1:?}"[[:blank:]]*) return 0;;  # Mounted
    *)                                            # NOT mounted
  esac
  return 1  # NOT mounted
}

set_perm()
{
  local uid="${1:?}"; local gid="${2:?}"; local mod="${3:?}"
  shift 3
  chown "${uid:?}:${gid:?}" "${@:?}" || chown "${uid:?}.${gid:?}" "${@:?}" || ui_error "chown failed on: $*"
  chmod "${mod:?}" "${@:?}" || ui_error "chmod failed on: $*"
}

package_extract_file()
{
  unzip -opq "${ZIPFILE:?}" "${1:?}" 1> "${2:?}" || ui_error "Failed to extract the file '${1}' from this archive"
  if ! test -e "${2:?}"; then ui_error "Failed to extract the file '${1}' from this archive"; fi
}


### CODE ###

echo 'PRELOADER 1'

MANUAL_TMP_MOUNT=false
if test -z "${TMPDIR:-}" && ! _updatebin_is_mounted '/tmp'; then
  MANUAL_TMP_MOUNT=true

  # Workaround: create and mount the temp folder if it isn't already mounted
  1>&2 printf '\033[0;33m%s\033[0m\n' 'WARNING: Creating and mounting the missing temp folder...'
  _show_text_on_recovery 'WARNING: Creating and mounting the missing temp folder...'
  if ! test -e '/tmp'; then mkdir -p '/tmp' || ui_error 'Failed to create the temp folder'; fi
  set_perm 0 0 0755 '/tmp'
  mount -t tmpfs -o rw tmpfs '/tmp'
  set_perm 0 2000 0775 '/tmp'

  if ! _updatebin_is_mounted '/tmp'; then ui_error 'The temp folder CANNOT be mounted'; fi
fi

# Seed the RANDOM variable
RANDOM="$$"

# shellcheck disable=SC3028
{
  if test "${RANDOM:?}" = "$$"; then ui_error "\$RANDOM is not supported"; fi  # Both BusyBox and Toybox support $RANDOM
  _updatebin_our_main_script="${TMPDIR:-/tmp}/${RANDOM:?}-customize.sh"
}

package_extract_file 'customize.sh' "${_updatebin_our_main_script:?}"
# shellcheck source=SCRIPTDIR/../../../../customize.sh
. "${_updatebin_our_main_script:?}" || ui_error "Failed to source customize.sh"
rm -f "${_updatebin_our_main_script:?}" || ui_error "Failed to delete customize.sh"

unset _updatebin_our_main_script

if test "${MANUAL_TMP_MOUNT:?}" = true; then
  umount '/tmp' || ui_error 'Failed to unmount the temp folder'
fi
