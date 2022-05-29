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
BASE_TMP_PATH="${TMPDIR:-/tmp}"
TMP_PATH="${TMPDIR:-/tmp}/custom-setup-a5k"
MANUAL_TMP_MOUNT=0


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
  1>&2 echo "ERROR ${ERROR_CODE:?}: ${1:?}"
  _show_text_on_recovery "ERROR: ${1:?}"
  exit "${ERROR_CODE:?}"
}

ui_warning()
{
  1>&2 echo "WARNING: ${1:?}"
  _show_text_on_recovery "WARNING: ${1:?}"
}

ui_debug()
{
  echo "${1?}"
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
  local uid="${1:?}"; local gid="${2:?}"; local mod="${3:?}"
  shift 3
  chown "${uid:?}:${gid:?}" "${@:?}" || chown "${uid:?}.${gid:?}" "${@:?}" || ui_error "chown failed on: $*"
  chmod "${mod:?}" "${@:?}" || ui_error "chmod failed on: $*"
}

package_extract_file()
{
  unzip -opq "${ZIPFILE:?}" "${1:?}" > "${2:?}" || ui_error "Failed to extract the file '${1}' from this archive"
  if ! test -e "${2:?}"; then ui_error "Failed to extract the file '${1}' from this archive"; fi
}


### CODE ###

ui_debug 'PRELOADER'

if ! is_mounted "${BASE_TMP_PATH:?}"; then
  # Workaround: create and mount the temp folder if it isn't already mounted
  MANUAL_TMP_MOUNT=1
  ui_warning 'Creating and mounting the missing temp folder...'
  if ! test -e "${BASE_TMP_PATH:?}"; then create_dir "${BASE_TMP_PATH:?}"; fi
  mount -t tmpfs -o rw tmpfs "${BASE_TMP_PATH:?}"
  set_perm 0 2000 0775 "${BASE_TMP_PATH:?}"

  if ! is_mounted "${BASE_TMP_PATH:?}"; then ui_error 'The temp folder CANNOT be mounted'; fi
fi

# Delete previous traces and setup our temp folder
rm -rf "${TMP_PATH:?}" || ui_error "Failed to delete previous files"
mkdir -p "${TMP_PATH:?}" || ui_error "Failed to create the temp folder"
set_perm 0 0 0755 "${TMP_PATH:?}"

# Seed the RANDOM variable
RANDOM="$$"

_updatebin_our_main_script="${TMPDIR:-/tmp}/${RANDOM:?}-customize.sh"

package_extract_file 'customize.sh' "${_updatebin_our_main_script:?}"
# shellcheck source=SCRIPTDIR/../../../../customize.sh
. "${_updatebin_our_main_script:?}" || ui_error "Failed to execute customize.sh"
rm -f "${_updatebin_our_main_script:?}" || ui_error "Failed to delete customize.sh"

unset _updatebin_our_main_script

if test "${MANUAL_TMP_MOUNT}" -ne 0; then
  umount "${BASE_TMP_PATH:?}" || ui_error 'Failed to unmount the temp folder'
fi
