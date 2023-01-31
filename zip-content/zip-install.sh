#!/system/bin/sh
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

umask 022 || exit 1

ui_show_error()
{
  printf 1>&2 '\033[1;31mERROR: %s\033[0m\n' "${1:?}"
}

if test "$(whoami || id -un || true)" != 'root'; then
  if test "${AUTO_ELEVATED:-false}" = 'false' && {
    test "${FORCE_ROOT:-false}" != 'false' || command -v su 1> /dev/null
  }; then

    # First check if root is working (0 => root)
    su -c '' -- 0 -- || {
      _status="${?}" # Usually it return 1 or 255 when fail
      ui_show_error 'Auto-rooting failed, you must execute this as root!!!'
      exit "${_status:-1}"
    }

    ZIP_INSTALL_SCRIPT="$(readlink -f "${0:?}")" || ZIP_INSTALL_SCRIPT="$(realpath "${0:?}")" || {
      ui_show_error 'Unable to find this script'
      exit 2
    }
    exec su -c "export AUTO_ELEVATED=true; sh -- '${ZIP_INSTALL_SCRIPT:?}' \"\${@}\"" -- 0 -- _ "${@}" || ui_show_error 'failed: exec'
    exit 127

  fi

  ui_show_error 'You must execute this as root!!!'
  exit 2
fi

if test -z "${1:-}"; then
  ui_show_error 'You must specify the ZIP file to install'
  exit 3
fi
if test ! -e "${1:?}"; then
  ui_show_error "The selected ZIP file doesn't exist => '${1:-}'"
  exit 4
fi
ZIPFILE="$(readlink -f "${1:?}")" || ZIPFILE="$(realpath "${1:?}")" || exit 4
unset SCRIPT_NAME

_clean_at_exit()
{
  if test -n "${SCRIPT_NAME:-}" && test -e "${SCRIPT_NAME:?}"; then
    rm -f "${SCRIPT_NAME:?}" || true
  fi
  unset SCRIPT_NAME
  if test "${TMPDIR:-}" = '/dev/tmp'; then
    if test -e "${TMPDIR:?}"; then
      # Legacy versions of rmdir don't accept any parameter (not even --)
      rmdir "${TMPDIR:?}" 2> /dev/null || true
    fi
    unset TMPDIR
  fi
}
trap ' _clean_at_exit' 0 2 3 6 15

if test -n "${TMPDIR:-}" && test -w "${TMPDIR:?}"; then
  : # Already ready
elif test -w '/tmp'; then
  TMPDIR='/tmp'
elif test -e '/dev'; then
  mkdir -p '/dev/tmp' || {
    ui_show_error 'Failed to create a temp folder'
    exit 5
  }
  chmod 01775 '/dev/tmp' || {
    ui_show_error "chmod failed on '/dev/tmp'"
    exit 5
  }
  TMPDIR='/dev/tmp'
fi

if test -z "${TMPDIR:-}" || test ! -w "${TMPDIR:?}"; then
  ui_show_error 'Unable to create a temp folder'
  exit 6
fi
export TMPDIR

SCRIPT_NAME="${TMPDIR:?}/update-binary.sh" || exit 7
unzip -p -qq "${ZIPFILE:?}" 'META-INF/com/google/android/update-binary' 1> "${SCRIPT_NAME:?}" || {
  ui_show_error 'Failed to extract update-binary'
  exit 8
}
test -e "${SCRIPT_NAME:?}" || {
  ui_show_error 'Failed to extract update-binary (2)'
  exit 9
}

# Use STDERR for recovery messages to avoid possible problems with subshells intercepting output
STATUS=0
sh -- "${SCRIPT_NAME:?}" 3 2 "${ZIPFILE:?}" 'zip-install' || STATUS="${?}"

_clean_at_exit
trap - 0 2 3 6 15 || true # Already cleaned, so unset traps

if test "${STATUS:-1}" != '0'; then
  ui_show_error "ZIP installation failed with error ${STATUS:-1}"
  exit "${STATUS:-1}"
fi

printf '\033[1;32m%s\033[0m\n' 'The ZIP installation is completed, now restart your device!!!'
