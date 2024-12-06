#!/system/bin/sh
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

readonly ZIPINSTALL_VERSION='1.2.3'

umask 022 || :
PATH="${PATH:-/system/bin}:."
END_OF_SCRIPT_REACHED=0

### PREVENTIVE CHECKS ###

_busybox_executability_check()
{
  if test ! -x busybox; then
    chmod 0755 'busybox' || {
      echo 1>&2 'ERROR: chmod failed on busybox'
      exit 100
    }
  fi
}

command 1> /dev/null -v printf || {
  if command 1> /dev/null -v busybox; then
    _busybox_executability_check
    eval ' printf() { busybox printf "${@}"; } '
  else
    EMULATED_PRINTF=1
    NO_COLOR=1

    printf()
    {
      case "${1-unset}" in
        '%s')
          _printf_backup_ifs="${IFS-unset}"
          shift && IFS='' && echo "${*}" | head -c '-1'
          if test "${_printf_backup_ifs}" = 'unset'; then unset IFS; else IFS="${_printf_backup_ifs}"; fi
          unset _printf_backup_ifs
          ;;
        '%s\n')
          shift && for _printf_val in "${@}"; do
            echo "${_printf_val}"
          done
          ;;
        '%s\n\n')
          shift && for _printf_val in "${@}"; do
            echo "${_printf_val}" && echo ''
          done
          ;;
        '\n') echo '' ;;
        '\n\n') echo '' && echo '' ;;
        '') ;;

        *)
          echo 1>&2 'ERROR: Unsupported printf parameter'
          return 2
          ;;
      esac

      unset _printf_val
      return 0
    }
  fi
}

command 1> /dev/null -v whoami || {
  whoami()
  {
    _whoami_val="$(id | grep -o -m '1' -e "uid=[0-9]*([a-z]*)" | grep -o -e "([a-z]*)")" || return "${?}"
    _whoami_val="${_whoami_val#\(}"
    _whoami_val="${_whoami_val%\)}"
    printf '%s\n' "${_whoami_val?}"
    unset _whoami_val
  }
}

command 1> /dev/null -v unzip || {
  if command 1> /dev/null -v busybox; then
    _busybox_executability_check
    alias unzip='busybox unzip'
  else
    echo 1>&2 'ERROR: "unzip" is missing'
    exit 100
  fi
}

command 1> /dev/null -v head || {
  if command 1> /dev/null -v busybox; then
    _busybox_executability_check
    alias head='busybox head'
  fi
}

### FUNCTIONS AND CODE ###

ui_info_msg()
{
  if test -n "${NO_COLOR-}"; then
    printf '%s\n' "${1}"
  elif test "${CI:-false}" = 'false'; then
    printf '\033[1;32m\r%s\n\033[0m\r    \r' "${1}"
  else
    printf '\033[1;32m%s\033[0m\n' "${1}"
  fi
}

ui_error_msg()
{
  if test -n "${NO_COLOR-}"; then
    printf 1>&2 '%s\n' "ERROR: ${1}"
  elif test "${CI:-false}" = 'false'; then
    printf 1>&2 '\033[1;31m\r%s\n\033[0m\r    \r' "ERROR: ${1}"
  else
    printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR: ${1}"
  fi
}

if test -n "${*}"; then
  for _param in "${@}"; do
    shift || {
      ui_error_msg 'shift failed'
      exit 6
    }
    # Skip empty parameters or parameters that may get passed due to buggy su implementation
    if test -z "${_param:-}" || test "${_param:?}" = '--' || test "${_param:?}" = '[su]zip-install.sh'; then continue; fi

    test -e "${_param:?}" || {
      ui_error_msg "ZIP file doesn't exist => '${_param:-}'"
      exit 7
    }

    _param_copy="${_param:?}"
    _param="$(readlink -f "${_param_copy:?}")" || _param="$(realpath "${_param_copy:?}")" || {
      ui_error_msg "Canonicalization failed => '${_param_copy:-}'"
      exit 8
    }

    set -- "${@}" "${_param:?}" || {
      ui_error_msg 'set failed'
      exit 6
    }
  done
  unset _param _param_copy
fi

if test -z "${*}"; then
  ui_error_msg 'You must specify the ZIP file to install'
  exit 5
fi

if test "$(whoami || :)" != 'root'; then
  if test "${AUTO_ELEVATED:-false}" = 'false'; then
    printf '%s\n' 'Auto-rooting attempt...'

    # First verify that "su" is working (user 0 is root)
    su 0 sh -c 'command' '[su]verification' || {
      _status="${?}" # Usually it return 1 or 255 when root is present but disabled
      ui_error_msg 'Auto-rooting failed, you must execute this as root!!!'
      exit "${_status:-2}"
    }

    ZIP_INSTALL_SCRIPT="$(readlink -f "${0:?}")" || ZIP_INSTALL_SCRIPT="$(realpath "${0:?}")" || {
      ui_error_msg 'Unable to find myself'
      exit 3
    }
    exec su 0 sh -c "AUTO_ELEVATED=true DEBUG_LOG='${DEBUG_LOG:-0}' FORCE_HW_BUTTONS='${FORCE_HW_BUTTONS:-0}' CI='${CI:-false}' TMPDIR='${TMPDIR:-}' sh -- '${ZIP_INSTALL_SCRIPT:?}' \"\${@}\"" '[su]zip-install.sh' "${@}" || ui_error_msg 'failed: exec'
    exit "${?}"
  fi

  ui_error_msg 'You must execute this as root!!!'
  exit 4
fi

unset SCRIPT_NAME
_clean_at_exit()
{
  if test -n "${SCRIPT_NAME:-}" && test -e "${SCRIPT_NAME:?}"; then
    rm -f "${SCRIPT_NAME:?}" || :
  fi
  if test -n "${UPD_SCRIPT_NAME:-}" && test -e "${UPD_SCRIPT_NAME:?}"; then
    rm -f "${UPD_SCRIPT_NAME:?}" || :
  fi
  unset SCRIPT_NAME
  if test "${TMPDIR:-}" = '/dev/tmp'; then
    if test -e "${TMPDIR:?}"; then
      # Legacy versions of rmdir don't accept any parameter (not even --)
      rmdir "${TMPDIR:?}" 2> /dev/null || :
    fi
    unset TMPDIR
  fi
}
trap ' _clean_at_exit' 0 2 3 6 15

if test -n "${TMPDIR:-}" && test -w "${TMPDIR:?}" && test "${TMPDIR:?}" != '/data/local/tmp'; then
  : # Already ready
elif test -w '/tmp'; then
  TMPDIR='/tmp'
elif test -e '/dev'; then
  mkdir -p '/dev/tmp' || {
    ui_error_msg 'Failed to create a temp folder'
    exit 9
  }
  chmod 01775 '/dev/tmp' || {
    ui_error_msg "chmod failed on '/dev/tmp'"
    rmdir '/dev/tmp' 2> /dev/null || :
    exit 10
  }
  TMPDIR='/dev/tmp'
fi

if test -z "${TMPDIR:-}" || test ! -w "${TMPDIR:?}"; then
  ui_error_msg 'Unable to find a temp folder'
  exit 11
fi
export TMPDIR

SCRIPT_NAME="${TMPDIR:?}/update-binary" || exit 12
UPD_SCRIPT_NAME="${TMPDIR:?}/updater-script" || exit 12
ZIPFILE="${1:?}"

unzip -p -qq "${ZIPFILE:?}" 'META-INF/com/google/android/update-binary' 1> "${SCRIPT_NAME:?}" || {
  ui_error_msg "Failed to extract update-binary from => '${ZIPFILE:-}'"
  exit 13
}
test -s "${SCRIPT_NAME:?}" || {
  ui_error_msg "Failed to extract update-binary (2) from => '${ZIPFILE:-}'"
  exit 14
}

unzip -p -qq "${ZIPFILE:?}" 'META-INF/com/google/android/updater-script' 1> "${UPD_SCRIPT_NAME:?}" || : # Not strictly needed

STATUS=0
if ! command 1> /dev/null -v head || test '#!' = "$(head -q -c 2 -- "${SCRIPT_NAME:?}" || :)"; then
  printf '%s\n' 'Executing script...'

  # Use STDERR (2) for recovery messages to avoid possible problems with subshells intercepting output
  sh -- "${SCRIPT_NAME:?}" 3 2 "${ZIPFILE:?}" 'zip-install' "${ZIPINSTALL_VERSION:?}" || STATUS="${?}"
else
  printf '%s\n' 'Executing binary...'

  # Legacy versions of chmod don't support +x and --
  chmod 0755 "${SCRIPT_NAME:?}" || {
    ui_error_msg "chmod failed on '${SCRIPT_NAME:?}'"
    exit 15
  }
  "${SCRIPT_NAME:?}" 3 2 "${ZIPFILE:?}" 'zip-install' "${ZIPINSTALL_VERSION:?}" || STATUS="${?}"
fi
END_OF_SCRIPT_REACHED=1

_clean_at_exit
trap - 0 2 3 6 15 || : # Already cleaned, so unset traps

if test "${STATUS:-20}" != '0'; then
  ui_error_msg "ZIP installation failed with error ${STATUS:-20}"
  exit "${STATUS:-20}"
fi

# This should theoretically never happen, but it's just to protect against unknown shell bugs
if test "${END_OF_SCRIPT_REACHED:-0}" != '1'; then
  ui_error_msg "ZIP installation failed with an unknown error"
  exit 120
fi

ui_info_msg 'The ZIP installation is completed, now restart your device!!!'
exit 0
