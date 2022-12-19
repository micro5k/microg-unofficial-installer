#!/system/bin/sh
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

umask 022 || exit 1

if test "$(whoami || true)" != 'root'; then
  printf 'ERROR: %s\n' 'You must execute it as root'
  exit 2
fi

if test -z "${1:-}" || test ! -e "${1:?}"; then
  printf 'ERROR: %s\n' 'You must specify the ZIP file to install'
  exit 2
fi
ZIPFILE="$(realpath -- "${1:?}")" || ZIPFILE="$(readlink -f -- "${1:?}")" || exit 2

TMPDIR="${TMPDIR:-}"
if test -n "${TMPDIR:-}" && test -w "${TMPDIR:?}"; then
  : # Already ready
elif test -w '/tmp'; then
  TMPDIR='/tmp'
elif test -e '/dev'; then
  mkdir -p -- '/dev/tmp' || { printf 'ERROR: %s\n' 'Failed to create a temp folder'; exit 3; }
  TMPDIR='/dev/tmp'
fi

if test -z "${TMPDIR:-}" || test ! -w "${TMPDIR:?}"; then
  printf 'ERROR: %s\n' 'Unable to create a temp folder'
  exit 4
fi
export TMPDIR

SCRIPT_NAME="${TMPDIR:?}/update-binary.sh" || exit 5
unzip -p -qq "${ZIPFILE:?}" 'META-INF/com/google/android/update-binary' 1> "${SCRIPT_NAME:?}" || { printf 'ERROR: %s\n' 'Failed to extract update-binary'; exit 6; }

STATUS=0
sh -- "${SCRIPT_NAME:?}" 3 1 "${ZIPFILE:?}" || STATUS="${?}"

rm -f -- "${SCRIPT_NAME:?}" || true
if test "${TMPDIR:?}" = '/dev/tmp'; then
  rmdir --ignore-fail-on-non-empty -- "${TMPDIR:?}" || true
fi

if test "${STATUS:-1}" != '0'; then
  printf 'ERROR: %s\n' 'ZIP installation failed'
  exit "${STATUS:-1}"
fi
