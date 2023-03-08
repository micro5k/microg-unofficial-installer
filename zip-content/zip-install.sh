#!/system/bin/sh
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

readonly ZIPINSTALL_VERSION='0.1'

umask 022 || exit 6

ui_show_error()
{
  printf 1>&2 '\033[1;31mERROR: %s\033[0m\n' "${1:-}"
}

if test -n "${*:-}"; then
  for _param in "${@}"; do
    shift || {
      ui_show_error 'shift failed'
      exit 6
    }
    # Skip empty parameters or parameters that may get passed due to buggy su implementation
    if test -z "${_param:-}" || test "${_param:?}" = '--' || test "${_param:?}" = '[su] zip-install.sh'; then continue; fi

    test -e "${_param:?}" || {
      ui_show_error "ZIP file doesn't exist => '${_param:-}'"
      exit 7
    }

    _param_copy="${_param:?}"
    _param="$(readlink -f "${_param_copy:?}")" || _param="$(realpath "${_param_copy:?}")" || {
      ui_show_error "Canonicalization failed => '${_param_copy:-}'"
      exit 8
    }

    set -- "${@}" "${_param:?}" || {
      ui_show_error 'set failed'
      exit 6
    }
  done
  unset _param _param_copy
fi

if test -z "${*:-}"; then
  ui_show_error 'You must specify the ZIP file to install'
  exit 5
fi

if test "$(whoami || id -un || true)" != 'root'; then
  if test "${AUTO_ELEVATED:-false}" = 'false' && {
    test "${FORCE_ROOT:-0}" != '0' || command -v su 1> /dev/null
  }; then

    printf '%s\n' 'Auto-rooting attempt...'

    # First check if root is working (0 => root)
    su -c 'command' -- 0 -- _ || {
      _status="${?}" # Usually it return 1 or 255 when fail
      ui_show_error 'Auto-rooting failed, you must execute this as root!!!'
      exit "${_status:-2}"
    }

    ZIP_INSTALL_SCRIPT="$(readlink -f "${0:?}")" || ZIP_INSTALL_SCRIPT="$(realpath "${0:?}")" || {
      ui_show_error 'Unable to find myself'
      exit 3
    }
    exec su -c "AUTO_ELEVATED=true DEBUG_LOG='${DEBUG_LOG:-0}' FORCE_HW_BUTTONS='${FORCE_HW_BUTTONS:-0}' sh -- '${ZIP_INSTALL_SCRIPT:?}' \"\${@}\"" -- 0 -- '[su] zip-install.sh' "${@}" || ui_show_error 'failed: exec'
    exit 127

  fi

  ui_show_error 'You must execute this as root!!!'
  exit 4
fi

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
    exit 9
  }
  chmod 01775 '/dev/tmp' || {
    ui_show_error "chmod failed on '/dev/tmp'"
    rmdir '/dev/tmp' 2> /dev/null || true
    exit 10
  }
  TMPDIR='/dev/tmp'
fi

if test -z "${TMPDIR:-}" || test ! -w "${TMPDIR:?}"; then
  ui_show_error 'Unable to find a temp folder'
  exit 11
fi
export TMPDIR

SCRIPT_NAME="${TMPDIR:?}/update-binary.sh" || exit 12
ZIPFILE="${1:?}"
unzip -p -qq "${ZIPFILE:?}" 'META-INF/com/google/android/update-binary' 1> "${SCRIPT_NAME:?}" || {
  ui_show_error "Failed to extract update-binary from => '${ZIPFILE:-}'"
  exit 13
}
test -e "${SCRIPT_NAME:?}" || {
  ui_show_error "Failed to extract update-binary (2) from => '${ZIPFILE:-}'"
  exit 14
}

# Use STDERR (2) for recovery messages to avoid possible problems with subshells intercepting output
STATUS=0
sh -- "${SCRIPT_NAME:?}" 3 2 "${ZIPFILE:?}" 'zip-install' "${ZIPINSTALL_VERSION:?}" || STATUS="${?}"

_clean_at_exit
trap - 0 2 3 6 15 || true # Already cleaned, so unset traps

if test "${STATUS:-20}" != '0'; then
  ui_show_error "ZIP installation failed with error ${STATUS:-20}"
  exit "${STATUS:-20}"
fi

printf '\033[1;32m%s\033[0m\n' 'The ZIP installation is completed, now restart your device!!!'
exit 0
