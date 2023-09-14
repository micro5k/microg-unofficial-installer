#!/system/bin/sh
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck disable=SC2310 # This function is invoked in an 'if' condition so set -e will be disabled #

set -e
# shellcheck disable=SC3040,SC3041,SC2015
{
  # Unsupported set options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue
  (set -o posix 2> /dev/null) && set -o posix || true
  (set +H 2> /dev/null) && set +H || true
  (set -o pipefail 2> /dev/null) && set -o pipefail || true
}

### GLOBAL VARIABLES ###

readonly MINUTIL_NAME='MinUtil'
readonly MINUTIL_VERSION='1.0'

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

command 1> /dev/null -v basename || {
  basename()
  {
    printf '%s\n' "${1##*/}"
  }
}

_minutil_initialize()
{
  case "${0:?}" in
    *'.sh') ;; # $0 => minutil.sh
    *'sh')     # $0 => sh | ash | bash | ...sh
      printf 1>&2 '\033[1;31m%s\033[0m\n' "[${MINUTIL_NAME:-}] ERROR: Cannot be sourced"
      exit 1
      ;;
    *) ;;
  esac

  if ! _minutil_current_user="$(\whoami)" || test -z "${_minutil_current_user?}"; then
    printf 1>&2 '\033[1;31m%s\033[0m\n' "[${MINUTIL_NAME:-}] ERROR: Invalid user"
    exit 1
  fi
  readonly _minutil_current_user
}
_minutil_initialize

### BASE FUNCTIONS ###

_minutil_error()
{
  printf 1>&2 '\033[1;31m%s\033[0m\n' "[${MINUTIL_NAME:-}] ERROR: ${*}"
}

_minutil_warn()
{
  printf 1>&2 '\033[0;33m%s\033[0m\n\n' "WARNING: ${*}"
}

_minutil_aligned_print()
{
  printf '\t%-37s %s\n' "${@}"
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
  if test "${_minutil_current_user?}" != 'shell' && test "${_minutil_current_user?}" != 'root' && ! _is_caller_user_0; then
    _minutil_error 'You must execute it as either ADB or root or user 0'
    return 1
  fi
}

_is_caller_adb_or_root()
{
  if test "${_minutil_current_user?}" != 'shell' && test "${_minutil_current_user?}" != 'root'; then
    _minutil_error 'You must execute it as either ADB or root'
    return 1
  fi
}

_is_caller_root()
{
  if test "${_minutil_current_user?}" != 'root'; then
    _minutil_error 'You must execute it as root'
    return 1
  fi
}

_minutil_getprop()
{
  grep -m 1 -F -e "${1:?}=" "${2:?}" | cut -d '=' -f '2-' -s
}

_minutil_check_getopt()
{
  unset GETOPT_COMPATIBLE
  getopt_test='0'
  \getopt -T -- 2> /dev/null || getopt_test="${?}"
  if test "${getopt_test:?}" != '4'; then
    _minutil_warn 'Limited or missing getopt'
    return 1
  fi
  unset getopt_test

  return 0
}

### FUNCTIONS AND CODE ###

MINUTIL_VERBOSE='false'
_minutil_display_help='false'

if _minutil_check_getopt; then
  if minutil_args="$(
    unset POSIXLY_CORRECT
    \getopt -o 'vhsi:' -l 'help,version,remove-all-accounts,rescan-storage,reset-battery,force-gcm-reconnection,reinstall-package:' -n 'MinUtil' -- "${@}"
  )"; then
    \eval ' \set' '--' "${minutil_args?}" || exit 1
  else
    \set -- '--help' '--' || exit 1
    _minutil_newline='true'
  fi
  unset minutil_args
fi

if test -z "${*}" || test "${*}" = '--'; then
  _minutil_display_help='true'
else
  for param in "${@}"; do
    if test "${param?}" = '-v'; then
      MINUTIL_VERBOSE='true'
      : "${MINUTIL_VERBOSE}" # UNUSED
      break
    fi
  done
  unset param
fi

if test ! -e '/system/bin'; then mount -t 'auto' '/system' 2> /dev/null || true; fi
if test ! -e '/data/data'; then mount -t 'auto' -o 'rw' '/data' 2> /dev/null || true; fi

if test -r '/system/build.prop' && MINUTIL_SYSTEM_SDK="$(_minutil_getprop 'ro.build.version.sdk' '/system/build.prop')" && test -n "${MINUTIL_SYSTEM_SDK?}"; then
  :
elif command -v getprop 1> /dev/null && MINUTIL_SYSTEM_SDK="$(getprop 'ro.build.version.sdk')" && test -n "${MINUTIL_SYSTEM_SDK?}"; then
  :
else
  _minutil_warn 'Failed to parse system SDK'
  MINUTIL_SYSTEM_SDK='999'
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
  _is_caller_adb_or_root || return 1

  if test "${MINUTIL_SYSTEM_SDK:?}" -lt 23; then
    _minutil_error "Split package reinstalling isn't currently supported on this version of Android"
    return 125
  fi

  _install_sid="$(pm install-create -r -g -i 'com.android.vending' | grep -m 1 -F -e 'Success: created install session' | grep -m 1 -o -w -e '[0-9][0-9]*')" || return "${?}"
  _file_index=0
  if test -z "${_install_sid:-}"; then return 2; fi

  printf '%s\n' "${1:?}" | while IFS='' read -r _file; do
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
  _is_caller_adb_or_root || return 1

  printf '%s\n' "Reinstalling ${1:-}..."
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
        _minutil_error 'Package reinstall failed (legacy)'
        return 3
      }
    fi
  fi

  unset _package_path _apk_count
  printf '%s\n' "Package ${1:-} reinstalled."
}

minutil_force_gcm_reconnection()
{
  _is_caller_adb_or_root || return 1

  printf '%s\n' "GCM reconnection..."
  command -v am 1> /dev/null || {
    _minutil_error 'Activity manager is NOT available'
    return 1
  }

  am broadcast -a 'org.microg.gms.gcm.FORCE_TRY_RECONNECT' -n 'com.google.android.gms/org.microg.gms.gcm.TriggerReceiver' || {
    _minutil_error 'GCM reconnection failed!'
    return 3
  }
  printf '%s\n' "Done!"
}

minutil_remove_all_accounts()
{
  _is_caller_root || return 1

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
      printf '%s\n' "Deleting '${_file:?}'..."
      rm -f -- "${_file}" || return 1
    fi
  done || {
    _minutil_error 'Failed to delete accounts'
    return 4
  }

  printf '%s\n' "All accounts deleted. Now restart the device!!!"
}

minutil_media_rescan()
{
  _is_caller_root || return 1

  printf '%s\n' "Media rescanning..."
  command -v am 1> /dev/null || {
    _minutil_error 'Activity manager is NOT available'
    return 1
  }

  am broadcast -a 'android.intent.action.BOOT_COMPLETED' -n 'com.android.providers.media/.MediaScannerReceiver' || {
    _minutil_error 'Media rescanning failed!'
    return 3
  }
  printf '%s\n' "Done!"
}

minutil_manual_media_rescan()
{
  _is_caller_adb_or_root || return 1

  printf '%s\n' "Manual media rescanning..."
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
    find /storage/emulated/* -type 'd' '(' -path '/storage/emulated/*/Android' -o -path '/storage/emulated/*/.android_secure' ')' -prune -o -mtime '-3' -type 'f' ! -name '\.*' -exec sh -c 'am 1>&- broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://${*}"' _ '{}' ';' || true
  elif test -e '/storage'; then
    find /storage/* -type 'd' '(' -path '/storage/*/Android' -o -path '/storage/*/.android_secure' ')' -prune -o -mtime '-3' -type 'f' ! -name '\.*' -exec sh -c 'am 1>&- broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://${*}"' _ '{}' ';' || true
  else
    _minutil_error 'Manual media rescanning failed!'
    return 3
  fi
  printf '%s\n' "Done!"
  return 0
}

minutil_reset_battery()
{
  printf '%s\n' 'Resetting battery stats...'
  rm -f -- '/data/system/batterystats.bin' || true
  rm -f -- '/data/system/batterystats-daily.xml' || true
  rm -f -- '/data/system/batterystats-checkin.bin' || true

  _fuel_gauge_reset()
  {
    if test -e "${1:?}"; then
      printf '%s\n' 'Resetting fuel gauge...'
      printf '%s\n' '1' 1> "${1:?}" || true
    fi
  }

  _fuel_gauge_reset '/sys/devices/platform/i2c-gpio.9/i2c-9/9-0036/power_supply/fuelgauge/fg_reset_soc' # Samsung Galaxy S2
  _fuel_gauge_reset '/sys/class/power_supply/battery/fg_reset_cap' # Samsung Galaxy Tab 7.7 (maybe also others)
}

minutil_display_version()
{
  printf '%s\n' "${MINUTIL_NAME:?} v${MINUTIL_VERSION:?} (Minimal utilities)"
  printf '%s\n' "Copyright (c) 2022 ale5000"
  printf '%s\n' "License GPLv3+"
}

while true; do
  case "${1}" in
    -v) ;; # Early parameters, already parsed

    -h | --help)
      _minutil_display_help='true'
      ;;

    --version)
      minutil_display_version
      ;;

    -i | --reinstall-package)
      minutil_reinstall_package "${2:?Package name not specified}"
      shift
      ;;

    --remove-all-accounts)
      minutil_remove_all_accounts
      ;;

    -s | --rescan-storage)
      if test "${_minutil_current_user?}" = 'root'; then
        minutil_media_rescan
      else
        minutil_manual_media_rescan
      fi
      ;;

    --reset-battery)
      minutil_reset_battery
      ;;

    --force-gcm-reconnection)
      minutil_force_gcm_reconnection
      ;;

    -r | --reset-gms-data)
      printf '%s\n' 'Not yet supported'
      ;;

    -R | --reset-permissions)
      printf '%s\n' 'Not yet supported'
      ;;

    --)
      break
      ;;

    '') ;; # Ignore empty parameters

    *)
      _minutil_display_help='true'
      _minutil_newline='true'
      printf 1>&2 '%s\n' "MinUtil: invalid option -- '${1#-}'" || true
      ;;
  esac

  # Note: 'shift' with nothing to shift cause some shells to exit and it can't be avoided so check it before using
  if test "${#}" -gt 0; then
    shift 2> /dev/null || break
  else
    break
  fi
done

if test "${_minutil_display_help:?}" = 'true'; then

  if test "${_minutil_newline:-false}" != 'false'; then printf '\n'; fi
  _minutil_script_name="$(basename "${0:?}")" || exit 1
  readonly _minutil_script_name

  printf '%s\n' "${MINUTIL_NAME:?} v${MINUTIL_VERSION:?} - Minimal utilities"
  printf '%s\n\n' 'Licensed under GPLv3+'
  printf '%s\n\n' "Usage: ${_minutil_script_name:?} [OPTIONS] [--]"

  _minutil_aligned_print '-h,--help' 'Show this help'
  _minutil_aligned_print '-s,--rescan-storage' 'Rescan storage to find file changes'
  _minutil_aligned_print '--reset-battery' ''
  _minutil_aligned_print '--remove-all-accounts' 'Remove all accounts from the device (need root)'
  _minutil_aligned_print '--force-gcm-reconnection' 'Force GCM reconnection'
  _minutil_aligned_print '-i,--reinstall-package PACKAGE_NAME' 'Reinstall PACKAGE_NAME as if it were installed from Play Store and grant it all permissions'

  printf '%s\n' "
Examples:

${_minutil_script_name:?} -i org.schabi.newpipe
${_minutil_script_name:?} --rescan-storage
"

fi

exit "${?}"
