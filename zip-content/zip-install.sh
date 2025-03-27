#!/system/bin/sh
# @name ZIP install
# @brief It can execute a flashable ZIP directly without the need of a Recovery.
# @author ale5000
# Get the latest version from here: https://github.com/micro5k/microg-unofficial-installer/blob/HEAD/zip-content/zip-install.sh

# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck enable=all

readonly ZIPINSTALL_VERSION='1.3.7'

END_OF_SCRIPT=0
PATH="${PATH:-/system/bin}:."
umask 022 || :

### PREVENTIVE CHECKS ###

command 1> /dev/null -v 'echo' || {
  echo || :
  exit 100
}

case "$(:)" in '') ;; *)
  echo 1>&2 'ERROR: Command substitution NOT supported by your shell'
  exit 100
  ;;
esac

command 1> /dev/null -v 'test' || {
  echo 1>&2 'ERROR: "test" is missing'
  exit 100
}

_is_busybox_available()
{
  if test -f './busybox'; then test -x './busybox' || chmod 0755 './busybox' || echo 1>&2 'WARNING: Chmod failed on busybox'; fi

  command 1> /dev/null -v 'busybox' || {
    echo 'false'
    return
  }

  PROPAGATE_BUSYBOX='true'
  echo 'true'
}

_is_head_functional()
{
  command 1> /dev/null -v 'head' || return 1
  case "$(echo 2> /dev/null 'ABCD' | head 2> /dev/null -c 2 || :)" in 'AB') return 0 ;; *) ;; esac # Some versions of head are broken or incomplete
  return 2
}

_redirect_command()
{
  eval " ${1:?}() { busybox '${1:?}' \"\${@}\"; } " || {
    echo 1>&2 "ERROR: Replacing ${1?} failed"
    exit 100
  }
}

_is_head_functional || {
  if "${IS_BUSYBOX_AVAILABLE:=$(_is_busybox_available || :)}"; then _redirect_command 'head'; fi
}

command 1> /dev/null -v 'printf' || {
  if "${IS_BUSYBOX_AVAILABLE:=$(_is_busybox_available || :)}"; then
    _redirect_command 'printf'
  else
    NO_COLOR=1

    printf()
    {
      case "${1-unset}" in
        '%s')
          _printf_backup_ifs="${IFS-unset}"
          if _is_head_functional; then
            shift && IFS='' && echo "${*}" | head -c '-1'
          else
            shift && IFS='' && echo "${*}"
          fi
          if test "${_printf_backup_ifs}" = 'unset'; then unset IFS; else IFS="${_printf_backup_ifs}"; fi
          unset _printf_backup_ifs
          ;;
        '%s\n')
          shift && for _printf_val in "${@}"; do echo "${_printf_val}"; done
          ;;
        '%s\n\n')
          shift && for _printf_val in "${@}"; do echo "${_printf_val}" && echo ''; done
          ;;
        '\n') echo '' ;;
        '\n\n') echo '' && echo '' ;;
        '') ;;

        *)
          echo 1>&2 'ERROR: Unsupported printf parameter'
          return 2
          ;;
      esac

      unset _printf_val || :
      return 0
    }
  fi
}

command 1> /dev/null -v 'unzip' || {
  if "${IS_BUSYBOX_AVAILABLE:=$(_is_busybox_available || :)}"; then
    _redirect_command 'unzip'
  else
    echo 1>&2 'ERROR: "unzip" is missing'
    exit 100
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

is_root()
{
  if command 1> /dev/null -v 'whoami'; then
    case "$(whoami || :)" in 'root') return 0 ;; *) ;; esac
  else
    command 1> /dev/null -v 'grep' || {
      if "${IS_BUSYBOX_AVAILABLE:=$(_is_busybox_available || :)}"; then
        _redirect_command 'grep'
      else
        echo 1>&2 'ERROR: "grep" is missing'
        exit 100
      fi
    }

    if id | grep -m '1' -q -e "uid=0[ (]"; then
      return 0
    fi
  fi

  return 1
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
    _param="$(readlink 2> /dev/null -f "${_param_copy:?}")" || _param="$(realpath "${_param_copy:?}")" || {
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

if ! is_root; then
  if test "${AUTO_ELEVATED:-false}" = 'false'; then
    printf '%s\n' 'Auto-rooting attempt...'

    # First verify that "su" is working (user 0 is root)
    su 0 sh -c 'command' '[su]verification' || {
      _status="${?}" # Usually it return 1 or 255 when root is present but disabled
      ui_error_msg 'Auto-rooting failed, you must execute this as root!!!'
      exit "${_status:-2}"
    }

    ZIP_INSTALL_SCRIPT="$(readlink 2> /dev/null -f "${0:?}")" || ZIP_INSTALL_SCRIPT="$(realpath "${0:?}")" || {
      ui_error_msg 'Unable to find myself'
      exit 3
    }
    exec su 0 sh -c "AUTO_ELEVATED=true DEBUG_LOG='${DEBUG_LOG-}' DRY_RUN='${DRY_RUN-}' KEY_TEST_ONLY='${KEY_TEST_ONLY-}' FORCE_HW_KEYS='${FORCE_HW_KEYS-}' CI='${CI:-false}' TMPDIR='${TMPDIR:-}' sh -- '${ZIP_INSTALL_SCRIPT:?}' \"\${@}\"" '[su]zip-install.sh' "${@}" || ui_error_msg 'failed: exec'
    exit "${?}"
  fi

  ui_error_msg 'You must execute this as root!!!'
  exit 4
fi

test -n "${DEBUG_LOG-unset}" || unset DEBUG_LOG
test -n "${DRY_RUN-unset}" || unset DRY_RUN
test -n "${KEY_TEST_ONLY-unset}" || unset KEY_TEST_ONLY
test -n "${FORCE_HW_KEYS-unset}" || unset FORCE_HW_KEYS

propagate_busybox()
{
  mkdir -p "${TMPDIR:?}/bb-applets" || {
    ui_error_msg 'Failed to create a temp folder for busybox applets'
    return
  }
  busybox 2> /dev/null --install -s "${TMPDIR:?}/bb-applets" || {
    ui_error_msg 'Failed to propagate busybox'
    return
  }
  PATH="${PATH?}:${TMPDIR:?}/bb-applets"
}

unset SCRIPT_NAME
_clean_at_exit()
{
  if test -n "${SCRIPT_NAME-}" && test -f "${SCRIPT_NAME:?}"; then
    # Legacy versions of rm don't accept any parameter (except -r and -R)
    rm "${SCRIPT_NAME:?}" || :
  fi
  if test -n "${UPD_SCRIPT_NAME-}" && test -f "${UPD_SCRIPT_NAME:?}"; then
    rm "${UPD_SCRIPT_NAME:?}" || :
  fi
  if test -n "${TMPDIR-}" && test -d "${TMPDIR:?}/bb-applets"; then
    rm -r "${TMPDIR:?}/bb-applets" || :
  fi

  unset SCRIPT_NAME
  if test "${TMPDIR:-}" = '/dev/tmp'; then
    if test -d "${TMPDIR:?}"; then
      # Legacy versions of rmdir don't accept any parameter (not even --)
      rmdir "${TMPDIR:?}" 2> /dev/null || :
    fi
    unset TMPDIR
  fi
}
trap ' _clean_at_exit' 0 2 3 6 15

if test -n "${TMPDIR-}" && test "${TMPDIR:?}" != '/data/local/tmp' && test -w "${TMPDIR:?}"; then
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
    rmdir 2> /dev/null '/dev/tmp' || :
    exit 10
  }
  TMPDIR='/dev/tmp'
fi

if test -z "${TMPDIR:-}" || test ! -w "${TMPDIR:?}"; then
  ui_error_msg 'Unable to find a temp folder'
  exit 11
fi
export TMPDIR

test "${PROPAGATE_BUSYBOX:-false}" = 'false' || propagate_busybox

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
if ! _is_head_functional || test '#!' = "$(head -c 2 -- "${SCRIPT_NAME:?}" || :)"; then
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
END_OF_SCRIPT=1

_clean_at_exit
trap - 0 2 3 6 15 || : # Already cleaned, so unset traps

if test "${STATUS:-20}" != '0'; then
  ui_error_msg "ZIP installation failed with error ${STATUS:-20}"
  exit "${STATUS:-20}"
fi

# This should theoretically never happen, but it's just to protect against unknown shell bugs
if test "${END_OF_SCRIPT:-0}" != '1'; then
  ui_error_msg "ZIP installation failed with an unknown error"
  exit 120
fi

ui_info_msg 'The ZIP installation is completed, now restart your device!!!'
exit 0
