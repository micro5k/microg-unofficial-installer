#!/system/bin/sh
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# shellcheck disable=SC2310 # This function is invoked in an 'if' condition so set -e will be disabled

set -e
# shellcheck disable=SC3040,SC2015
{
  # Unsupported set -o options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue and also handle the set -e case
  (set -o posix 2> /dev/null) && set -o posix || true
  (set -o pipefail 2> /dev/null) && set -o pipefail || true
}

MINUTIL_NAME='MinUtil'
MINUTIL_VERSION='0.5'

### PREVENTIVE CHECKS ###

_minutil_initialize()
{
  case "${0:?}" in
    *'.sh') ;; # $0 => minutil.sh
    *'sh')     # $0 => sh | ash | bash | ...sh
      \printf 1>&2 '\033[1;31m%s\033[0m\n' "[${MINUTIL_NAME:-}] ERROR: Cannot be sourced"
      \exit 1
      ;;
    *) ;;
  esac

  if ! _minutil_current_user="$(\whoami || \id -un)" || \test -z "${_minutil_current_user?}"; then
    \printf 1>&2 '\033[1;31m%s\033[0m\n' "[${MINUTIL_NAME:-}] ERROR: Invalid user"
    \exit 1
  fi
  \readonly _minutil_current_user
}
\readonly MINUTIL_NAME MINUTIL_VERSION
\_minutil_initialize

### BASE FUNCTIONS ###

_minutil_error()
{
  \printf 1>&2 '\033[1;31m%s\033[0m\n' "[${MINUTIL_NAME:-}] ERROR: ${*}"
}

_minutil_warn()
{
  \printf 1>&2 '\033[0;33m%s\033[0m\n\n' "WARNING: ${*}"
}

_minutil_aligned_print()
{
  printf '\t%-37s %s\n' "${@:?}"
}

_is_caller_user_0()
{
  case "${_minutil_current_user?}" in
    'u0_a'*) return 0 ;;
    *) ;;
  esac

  return 1
}

_is_caller_adb_or_root_or_user_0()
{
  if \test "${_minutil_current_user?}" != 'shell' && \test "${_minutil_current_user?}" != 'root' && ! _is_caller_user_0; then
    \_minutil_error 'You must execute it as either ADB or root or user 0'
    \return 1
  fi
}

_is_caller_adb_or_root()
{
  if \test "${_minutil_current_user?}" != 'shell' && \test "${_minutil_current_user?}" != 'root'; then
    \_minutil_error 'You must execute it as either ADB or root'
    \return 1
  fi
}

_is_caller_root()
{
  if \test "${_minutil_current_user?}" != 'root'; then
    \_minutil_error 'You must execute it as root'
    \return 1
  fi
}

_minutil_check_getopt()
{
  \unset GETOPT_COMPATIBLE
  getopt_test='0'
  \getopt -T -- 2> /dev/null || getopt_test="${?}"
  if \test "${getopt_test:?}" != '4'; then
    \_minutil_warn 'Limited or missing getopt'
    \return 1
  fi
  \unset getopt_test

  return 0
}

### FUNCTIONS AND CODE ###

_minutil_display_help='false'
if \_minutil_check_getopt; then
  for param in "${@}"; do
    \shift
    if \test "${param?}" = '-?'; then # Workaround for getopt issues with the question mark
      _minutil_display_help='true'
    else
      \set -- "${@}" "${param?}" || \exit 1
    fi
  done
  \unset param

  if minutil_args="$(
    \unset POSIXLY_CORRECT
    \getopt -o 'hsi:' -l 'help,remove-all-accounts,rescan-storage,force-gcm-reconnection,reinstall-package:' -n 'MinUtil' -- "${@}"
  )"; then
    \eval ' \set' '--' "${minutil_args?}" || \exit 1
  else
    \set -- '--help' '--' || \exit 1
    _minutil_newline='true'
  fi
  \unset minutil_args
fi
if \test -z "${*:-}" || \test "${*:-}" = '--'; then
  _minutil_display_help='true'
fi

_minutil_getprop()
{
  grep -m 1 -F -e "${1:?}=" "${2:?}" | cut -d '=' -f 2
}

if test -e '/system/build.prop'; then
  if ! MINUTIL_SYSTEM_SDK="$(_minutil_getprop 'ro.build.version.sdk' '/system/build.prop')" || test -z "${MINUTIL_SYSTEM_SDK:-}"; then
    MINUTIL_SYSTEM_SDK='0'
    _minutil_warn 'Failed to parse system SDK'
  fi
else
  MINUTIL_SYSTEM_SDK='99' # We are most likely in the recovery
fi
readonly MINUTIL_SYSTEM_SDK

_list_account_files()
{
  cat << 'EOF'
/data/system_de/0/accounts_de.db
/data/system_de/0/accounts_de.db-journal
/data/system_ce/0/accounts_ce.db
/data/system_ce/0/accounts_ce.db-journal
/data/system/users/0/accounts.db
/data/system/users/0/accounts.db-journal
/data/system/accounts.db
/data/system/accounts.db-journal
/data/data/com.google.android.gms/shared_prefs/accounts.xml
/data/system/sync/stats.bin
/data/system/sync/pending.xml
/data/system/sync/accounts.xml
/data/system/sync/status.bin
EOF
}

_minutil_find_package()
{
  pm path "${1:?}" 2> /dev/null | cut -d ':' -f 2 -s || return 1
}

_minutil_reinstall_split_package()
{
  \_is_caller_adb_or_root || \return 1

  _install_sid="$(pm install-create -r -g -i 'com.android.vending' | grep -m 1 -F -e 'Success: created install session' | grep -m 1 -o -w -e '[0-9][0-9]*')" || return "${?}"
  _file_index=0
  if test -z "${_install_sid:-}"; then return 2; fi

  echo "${1:?}" | while IFS='' read -r _file; do
    if test -n "${_file:-}" && test -e "${_file:?}"; then
      pm install-write -- "${_install_sid:?}" "${_file_index:?}" "${_file:?}" || {
        pm install-abandon "${_install_sid:?}"
        return 3
      }
      _file_index="$((_file_index + 1))"
    else
      _minutil_error 'Split package is missing'
      pm install-abandon "${_install_sid:?}"
      return 4
    fi
  done || return "${?}"

  pm install-commit "${_install_sid:?}" || return "${?}"
}

minutil_reinstall_package()
{
  \_is_caller_adb_or_root || \return 1

  echo "Reinstalling ${1:-}..."
  command -v pm 1> /dev/null || {
    _minutil_error 'Package manager is NOT available'
    return 1
  }

  if ! _package_path="$(_minutil_find_package "${1:?}")" || test -z "${_package_path:-}"; then
    _minutil_error "Package '${1:-}' not found"
    return 2
  fi
  _apk_count="$(printf '%s\n' "${_package_path:-}" | wc -l)"
  if test "${_apk_count:?}" -ge 2; then
    _minutil_reinstall_split_package "${_package_path:?}" || {
      _status="${?}"
      _minutil_error 'Split package reinstall failed'
      return "${_status:?}"
    }
  else
    if test ! -e "${_package_path:?}"; then
      _minutil_error "Package '${1:-}' found but file missing"
      return 2
    fi
    if test "${MINUTIL_SYSTEM_SDK:?}" -ge 23; then
      pm install -r -g -i 'com.android.vending' -- "${_package_path:?}" || {
        _minutil_error 'Package reinstall failed'
        return 3
      }
    else
      pm install -r -i 'com.android.vending' -- "${_package_path:?}" || {
        _minutil_error 'Package reinstall failed'
        return 3
      }
    fi
  fi

  unset _package_path _apk_count
  echo "Package ${1:-} reinstalled."
}

minutil_force_gcm_reconnection()
{
  \_is_caller_adb_or_root || \return 1

  echo "GCM reconnection..."
  command -v am 1> /dev/null || {
    _minutil_error 'Activity manager is NOT available'
    return 1
  }

  am broadcast -a 'org.microg.gms.gcm.FORCE_TRY_RECONNECT' -n 'com.google.android.gms/org.microg.gms.gcm.TriggerReceiver' || {
    _minutil_error 'GCM reconnection failed!'
    return 3
  }
  echo "Done!"
}

minutil_remove_all_accounts()
{
  \_is_caller_root || \return 1
  mount -t 'auto' -o 'rw' '/data' 2> /dev/null || true
  test -e '/data' || {
    _minutil_error '/data NOT found'
    return 1
  }
  test -w '/data' || {
    _minutil_error '/data is NOT writable'
    return 1
  }

  _list_account_files | while IFS='' read -r _file; do
    if test -e "${_file:?}"; then
      echo "Deleting '${_file:?}'..."
      rm -f -- "${_file}" || return 1
    fi
  done || {
    _minutil_error 'Failed to delete accounts'
    return 4
  }

  echo "All accounts deleted. Now restart the device!!!"
}

minutil_media_rescan()
{
  \_is_caller_root || \return 1

  echo "Media rescanning..."
  command -v am 1> /dev/null || {
    _minutil_error 'Activity manager is NOT available'
    return 1
  }

  am broadcast -a 'android.intent.action.BOOT_COMPLETED' -n 'com.android.providers.media/.MediaScannerReceiver' || {
    _minutil_error 'Media rescanning failed!'
    return 3
  }
  echo "Done!"
}

minutil_manual_media_rescan()
{
  \_is_caller_adb_or_root || \return 1

  echo "Manual media rescanning..."
  command -v am 1> /dev/null || {
    _minutil_error 'Activity manager is NOT available'
    return 1
  }

  # First check if the broadcast is working
  am broadcast -a 'android.intent.action.MEDIA_SCANNER_SCAN_FILE' 1>&- || {
    _minutil_error 'Manual media rescanning failed!'
    return 3
  }

  if test -e '/storage/emulated'; then
    find /storage/emulated/* -type 'd' '(' -path '/storage/emulated/*/Android' -o -path '/storage/emulated/*/.android_secure' ')' -prune -o -mtime '-3' -type 'f' ! -name '\.*' -exec sh -c 'am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://${*:?}" 1>&-' _ '{}' ';' || true
  elif test -e '/storage'; then
    find /storage/* -type 'd' '(' -path '/storage/*/Android' -o -path '/storage/*/.android_secure' ')' -prune -o -mtime '-3' -type 'f' ! -name '\.*' -exec sh -c 'am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://${*:?}" 1>&-' _ '{}' ';' || true
  else
    _minutil_error 'Manual media rescanning failed!'
    return 3
  fi
  echo "Done!"
  return 0
}

while true; do
  case "${1}" in
    -h | --help | -\?)
      _minutil_display_help='true'
      ;;

    -i | --reinstall-package)
      \minutil_reinstall_package "${2:?Package name not specified}"
      shift
      ;;

    --remove-all-accounts)
      \minutil_remove_all_accounts
      ;;

    -s | --rescan-storage)
      if \test "${_minutil_current_user?}" = 'root'; then
        \minutil_media_rescan
      else
        \minutil_manual_media_rescan
      fi
      ;;

    --force-gcm-reconnection)
      \minutil_force_gcm_reconnection
      ;;

    -r | --reset-gms-data)
      echo 'Not yet supported'
      ;;

    -R | --reset-permissions)
      echo 'Not yet supported'
      ;;

    --)
      break
      ;;

    '') ;; # Ignore empty parameters

    *)
      _minutil_display_help='true'
      _minutil_newline='true'
      \printf 1>&2 'MinUtil: invalid option -- %s\n' "'${1#-}'" || true
      ;;
  esac

  # Note: 'shift' with nothing to shift cause some shells to exit and it can't be avoided so check it before using
  if \test "${#}" -gt 0; then
    \shift 2> /dev/null || \break
  else
    \break
  fi
done

if test "${_minutil_display_help:?}" = 'true'; then

  if test "${_minutil_newline:-false}" != 'false'; then printf '\n'; fi
  _minutil_script_name="$(\basename "${0:?}")" || \exit 1
  \readonly _minutil_script_name

  printf '%s\n' "${MINUTIL_NAME:?} v${MINUTIL_VERSION:?} - Minimal utilities"
  printf '%s\n\n' 'Licensed under GPLv3+'
  printf 'Usage: %s [OPTIONS] [--]\n\n' "${_minutil_script_name:?}"

  _minutil_aligned_print '-h,-?,--help' 'Show this help'
  _minutil_aligned_print '-s,--rescan-storage' 'Rescan storage to find file changes'
  _minutil_aligned_print '--remove-all-accounts' 'Remove all accounts from the device (need root)'
  _minutil_aligned_print '--force-gcm-reconnection' 'Force GCM reconnection'
  _minutil_aligned_print '-i,--reinstall-package PACKAGE_NAME' 'Reinstall PACKAGE_NAME as if it were installed from Play Store and grant it all permissions'

  printf '
Examples:

%s -i org.schabi.newpipe
%s --rescan-storage
\n' "${_minutil_script_name:?}" "${_minutil_script_name:?}"

fi

\exit "${?}"
