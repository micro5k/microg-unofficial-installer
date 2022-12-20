#!/system/bin/sh
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

ui_show_error()
{
  printf 1>&2 '\033[1;31mERROR: %s\033[0m\n' "${1:?}"
}

umask 022 || exit 1

if test "$(whoami || true)" != 'root'; then
  ui_show_error 'You must execute this as root'
  exit 2
fi

if test -z "${1:-}" || test ! -e "${1:?}"; then
  ui_show_error 'You must specify the ZIP file to install'
  exit 2
fi
ZIPFILE="$(realpath -- "${1:?}")" || ZIPFILE="$(readlink -f -- "${1:?}")" || exit 2

_clean_at_exit()
{
  if test -n "${SCRIPT_NAME:-}" && test -e "${SCRIPT_NAME:?}"; then
    rm -f -- "${SCRIPT_NAME:?}" || true
  fi
  unset SCRIPT_NAME
  if test "${TMPDIR:-}" = '/dev/tmp' && test -e "${TMPDIR:?}"; then
    # Legacy versions of rmdir doesn't accept any parameter (not even --)
    rmdir "${TMPDIR:?}" 2> /dev/null || rmdir -- "${TMPDIR:?}" 2> /dev/null || true
    unset TMPDIR
  fi
}
unset SCRIPT_NAME
trap ' _clean_at_exit' 0 2 3 6 15

TMPDIR="${TMPDIR:-}"
if test -n "${TMPDIR:-}" && test -w "${TMPDIR:?}"; then
  : # Already ready
elif test -w '/tmp'; then
  TMPDIR='/tmp'
elif test -e '/dev'; then
  mkdir -p -- '/dev/tmp' || { ui_show_error 'Failed to create a temp folder'; exit 3; }
  TMPDIR='/dev/tmp'
fi

if test -z "${TMPDIR:-}" || test ! -w "${TMPDIR:?}"; then
  ui_show_error 'Unable to create a temp folder'
  exit 4
fi
export TMPDIR

SCRIPT_NAME="${TMPDIR:?}/update-binary.sh" || exit 5
unzip -p -qq "${ZIPFILE:?}" 'META-INF/com/google/android/update-binary' 1> "${SCRIPT_NAME:?}" || { ui_show_error 'Failed to extract update-binary'; exit 6; }

STATUS=0
sh -- "${SCRIPT_NAME:?}" 3 1 "${ZIPFILE:?}" || STATUS="${?}"

_clean_at_exit

# Already cleaned, so unset traps
trap - 0 2 3 6 15 || true

if test "${STATUS:-1}" != '0'; then
  ui_show_error 'ZIP installation failed'
  exit "${STATUS:-1}"
fi
