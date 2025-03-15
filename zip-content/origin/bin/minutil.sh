#!/system/bin/sh
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck enable=all
# shellcheck disable=SC2310 # Ignore: This function is invoked in an 'if' condition so set -e will be disabled

readonly SCRIPT_NAME='MinUtil'
readonly SCRIPT_SHORTNAME="${SCRIPT_NAME?}"
readonly SCRIPT_VERSION='1.2.15'

### CONFIGURATION ###

set -e
# shellcheck disable=SC3040 # Ignore: In POSIX sh, set option pipefail is undefined
case "$(set 2> /dev/null -o || set || :)" in *'pipefail'*) set -o pipefail || echo 1>&2 'Failed: pipefail' ;; *) ;; esac

POSIXLY_CORRECT='y'
export POSIXLY_CORRECT

### PREVENTIVE CHECKS ###

case "${0-}" in
  *'.sh') ;; # $0 => minutil.sh
  *'sh')     # $0 => sh | ash | bash | ...sh
    echo 1>&2 'ERROR: Cannot be sourced'
    # shellcheck disable=SC2317 # Ignore: Command appears to be unreachable
    return 126 2>&- || exit 126
    ;;
  *) ;;
esac

_is_head_functional()
{
  command 1> /dev/null -v 'head' || return 1
  case "$(echo 2> /dev/null 'ABCD' | head 2> /dev/null -c 2 || :)" in 'AB') return 0 ;; *) ;; esac # Some versions of head are broken or incomplete
  return 2
}

command 1> /dev/null -v printf || {
  if command 1> /dev/null -v busybox; then
    eval ' printf() { busybox printf "${@}"; } '
  else
    EMULATED_PRINTF=1
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

### BASE FUNCTIONS ###

param_msg()
{
  if test -n "${NO_COLOR-}"; then
    printf 1>&2 '%s\n' "${SCRIPT_SHORTNAME}: ${1}"
  elif test "${CI:-false}" = 'false'; then
    printf 1>&2 '\033[1;31m\r%s\n\033[0m\r    \r' "${SCRIPT_SHORTNAME}: ${1}"
  else
    printf 1>&2 '\033[1;31m%s\033[0m\n' "${SCRIPT_SHORTNAME}: ${1}"
  fi
}

error_msg()
{
  if test -n "${NO_COLOR-}"; then
    printf 1>&2 '%s\n' "ERROR: ${1}"
  elif test "${CI:-false}" = 'false'; then
    printf 1>&2 '\033[1;31m\r%s\n\033[0m\r    \r' "ERROR: ${1}"
  else
    printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR: ${1}"
  fi
}

warn_msg()
{
  if test -n "${NO_COLOR-}"; then
    printf 1>&2 '%s\n' "WARNING: ${1}"
  elif test "${CI:-false}" = 'false'; then
    printf 1>&2 '\033[0;33m\r%s\n\033[0m\r    \r' "WARNING: ${1}"
  else
    printf 1>&2 '\033[0;33m%s\033[0m\n' "WARNING: ${1}"
  fi
}

_minutil_aligned_print()
{
  if test "${EMULATED_PRINTF-}" != '1'; then
    printf '\t%-37s %s\n' "${@}"
  else
    echo "${@}"
  fi
}

#_is_caller_user_0()
#{
#  case "${CURRENT_USER?}" in 'u0_a'*) return 0 ;; *) ;; esac
#  return 1
#}

#_is_caller_adb_or_root_or_user_0()
#{
#  if test "${CURRENT_USER?}" = 'shell' || test "${CURRENT_USER?}" = 'root' || _is_caller_user_0; then return 0; fi
#  error_msg 'You must execute it as either ADB or root or user 0'
#  return 1
#}

_is_caller_adb_or_root()
{
  if test "${CURRENT_USER?}" != 'shell' && test "${CURRENT_USER?}" != 'root'; then
    error_msg 'You must execute it as either ADB or root'
    return 1
  fi
}

_is_caller_root()
{
  if test "${CURRENT_USER?}" != 'root'; then
    error_msg 'You must execute it as root'
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
  getopt -T -- 2> /dev/null || getopt_test="${?}"
  if test "${getopt_test:?}" != '4'; then
    warn_msg 'Limited or missing getopt'
    return 1
  fi
  unset getopt_test

  return 0
}

set_status_if_error()
{
  test "${1:?}" -eq 0 || STATUS="${1:?}"
}

### FUNCTIONS AND CODE ###

STATUS=0
SYSTEM_API=''
SCRIPT_VERBOSE='false'
DISPLAY_HELP='false'

if test ! -e '/system/bin'; then mount 2> /dev/null -t 'auto' '/system' || :; fi
if test ! -e '/data/data'; then mount 2> /dev/null -t 'auto' -o 'rw' '/data' || :; fi

if test -r '/system/build.prop' && SYSTEM_API="$(_minutil_getprop 'ro.build.version.sdk' '/system/build.prop')" && test -n "${SYSTEM_API?}"; then
  :
elif command 1> /dev/null -v 'getprop' && SYSTEM_API="$(getprop 'ro.build.version.sdk')" && test -n "${SYSTEM_API?}"; then
  :
else
  warn_msg 'Failed to parse system API'
  SYSTEM_API='999'
fi
readonly SYSTEM_API

if CURRENT_USER="$(whoami)" && test -n "${CURRENT_USER?}"; then
  :
else
  error_msg 'Current user NOT found'
  exit 126
fi
readonly CURRENT_USER

if test "${#}" -eq 0; then
  DISPLAY_HELP='true'
elif test "${#}" -eq 1 && test "${1?}" = '--'; then
  DISPLAY_HELP='true'
fi

if _minutil_check_getopt; then
  test -n "${NO_COLOR-}" || printf 1>&2 '\033[1;31m\r       \r' || :

  if minutil_args="$(
    getopt -o '+vVhsri:' -l 'version,help,rescan-storage,reset-battery,remove-all-accounts,force-gcm-reconnection,reset-gms-data,reinstall-package:' -n "${SCRIPT_SHORTNAME:?}" -- "${@}"
  )"; then
    eval ' \set' '--' "${minutil_args?}" || exit 126
  else
    set_status_if_error '2'
    set -- || :
    _minutil_newline='true'
  fi
  unset minutil_args

  test -n "${NO_COLOR-}" || printf 1>&2 '\033[0m\r    \r' || :
fi

if test "${#}" -gt 0; then
  for param in "${@}"; do
    if test "${param?}" = '-v'; then
      SCRIPT_VERBOSE='true'
      : "${SCRIPT_VERBOSE}" # UNUSED
      break
    fi
  done
  unset param
fi

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

  if test "${SYSTEM_API:?}" -lt 21; then
    error_msg 'This version of Android does NOT support split APKs'
    return 125
  fi

  if test "${SYSTEM_API:?}" -ge 23; then
    _install_sid="$(pm install-create -r -g -i 'com.android.vending' | grep -m 1 -F -e 'Success: created install session' | grep -m 1 -o -w -e '[0-9][0-9]*')" || return "${?}"
  else
    _install_sid="$(pm install-create -r -i 'com.android.vending' | grep -m 1 -F -e 'Success: created install session' | grep -m 1 -o -w -e '[0-9][0-9]*')" || return "${?}"
  fi
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
      error_msg 'Split package is missing'
      pm install-abandon "${_install_sid:?}"
      return 4
    fi
  done || return "${?}"

  pm install-commit "${_install_sid:?}" || return "${?}"
}

minutil_reinstall_package()
{
  _is_caller_adb_or_root || return 1

  printf '%s\n' "Reinstalling ${1?}..."
  test -n "${1?}" || {
    error_msg 'Empty argument'
    return 1
  }
  command -v pm 1> /dev/null || {
    error_msg 'Package manager is NOT available'
    return 1
  }

  if ! _package_path="$(_minutil_find_package "${1:?}")" || test -z "${_package_path:-}"; then
    error_msg "Package '${1?}' not found"
    return 2
  fi
  _apk_count="$(printf '%s\n' "${_package_path:-}" | wc -l)"
  if test "${_apk_count:?}" -ge 2; then
    _minutil_reinstall_split_package "${_package_path:?}" || {
      _status="${?}"
      error_msg 'Split package reinstall failed'
      return "${_status:?}"
    }
  else
    if test ! -e "${_package_path:?}"; then
      error_msg "Package '${1?}' found but file missing"
      return 2
    fi
    if test "${SYSTEM_API:?}" -ge 23; then
      pm install -r -g -i 'com.android.vending' -- "${_package_path:?}" || {
        error_msg 'Package reinstall failed'
        return 3
      }
    else
      pm install -r -i 'com.android.vending' -- "${_package_path:?}" || {
        error_msg 'Package reinstall failed (legacy)'
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
    error_msg 'Activity manager is NOT available'
    return 1
  }

  am broadcast -a 'org.microg.gms.gcm.FORCE_TRY_RECONNECT' -n 'com.google.android.gms/org.microg.gms.gcm.TriggerReceiver' || {
    error_msg 'GCM reconnection failed!'
    return 3
  }
  printf '%s\n' "Done!"
}

minutil_reset_gms_data()
{
  _is_caller_root || return 1

  printf '%s\n' 'Resetting GMS data of all apps...'
  if test -e '/data/data/'; then
    find /data/data/*/shared_prefs -name 'com.google.android.gms.*.xml' -delete
  fi
}

minutil_remove_all_accounts()
{
  _is_caller_root || return 1

  test -e '/data' || {
    error_msg '/data NOT found'
    return 1
  }
  test -w '/data' || {
    error_msg '/data is NOT writable'
    return 1
  }

  _list_account_files | while IFS='' read -r _file; do
    if test -e "${_file:?}"; then
      printf '%s\n' "Deleting '${_file:?}'..."
      rm -f -- "${_file}" || return 1
    fi
  done || {
    error_msg 'Failed to delete accounts'
    return 4
  }

  printf '%s\n' "All accounts deleted. Now restart the device!!!"
}

minutil_media_rescan()
{
  _is_caller_root || return 1

  printf '%s\n' "Media rescanning..."
  command -v am 1> /dev/null || {
    error_msg 'Activity manager is NOT available'
    return 1
  }

  am broadcast -a 'android.intent.action.BOOT_COMPLETED' -n 'com.android.providers.media/.MediaScannerReceiver' || {
    error_msg 'Media rescanning failed!'
    return 3
  }
  printf '%s\n' "Done!"
}

minutil_manual_media_rescan()
{
  _is_caller_adb_or_root || return 1

  printf '%s\n' "Manual media rescanning..."
  command -v am 1> /dev/null || {
    error_msg 'Activity manager is NOT available'
    return 1
  }

  # First check if the broadcast is working
  am broadcast -a 'android.intent.action.MEDIA_SCANNER_SCAN_FILE' 1>&- || {
    error_msg 'Manual media rescanning failed!'
    return 3
  }

  if test -e '/storage/emulated'; then
    find /storage/emulated/* -type 'd' '(' -path '/storage/emulated/*/Android' -o -path '/storage/emulated/*/.android_secure' ')' -prune -o -mtime '-3' -type 'f' ! -name '\.*' -exec sh -c 'am 1>&- broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://${*}"' _ '{}' ';' || true
  elif test -e '/storage'; then
    find /storage/* -type 'd' '(' -path '/storage/*/Android' -o -path '/storage/*/.android_secure' ')' -prune -o -mtime '-3' -type 'f' ! -name '\.*' -exec sh -c 'am 1>&- broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://${*}"' _ '{}' ';' || true
  else
    error_msg 'Manual media rescanning failed!'
    return 3
  fi
  printf '%s\n' "Done!"
  return 0
}

_fuel_gauge_reset()
{
  test -e "${1:?}" || return 1
  printf '%s\n' 'Resetting fuel gauge...'
  printf '%s\n' '1' 1> "${1:?}" || return "${?}"

  return 0
}

minutil_reset_battery()
{
  _is_caller_root || return 1

  printf '%s\n' 'Resetting battery stats...'
  rm -f -- '/data/system/batterystats.bin' || :
  rm -f -- '/data/system/batterystats-daily.xml' || :
  rm -f -- '/data/system/batterystats-checkin.bin' || :

  if _fuel_gauge_reset '/sys/devices/platform/i2c-gpio.9/i2c-9/9-0036/power_supply/fuelgauge/fg_reset_soc'; then
    : # Samsung Galaxy S2
  elif _fuel_gauge_reset '/sys/class/power_supply/battery/fg_reset_cap'; then
    : # Samsung Galaxy Tab 7.7 (maybe also others)
  else
    error_msg 'Fuel gauge reset failed!'
    return 2
  fi

  printf '%s\n' "Done!"
  return 0
}

minutil_display_version()
{
  printf '%s\n' "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?} (Minimal utilities)"
  printf '%s\n' "Copyright (c) 2022 ale5000"
  printf '%s\n' "License GPLv3+"
}

validate_param_argument()
{
  case "${2?}" in
    'unset' | '-'*)
      if test "${#1}" -eq 2; then
        param_msg "option requires an argument -- '${1#-}'"
      else
        param_msg "option '${1}' requires an argument"
      fi
      set_status_if_error '2'
      return 2
      ;;
    *) ;;
  esac

  return 0
}

invalid_param()
{
  param_msg "${1?}"
  set_status_if_error '2'
}

while test "${#}" -gt 0; do
  case "${1?}" in
    -v) ;; # Early parameters, already parsed

    -V | --version)
      minutil_display_version
      ;;

    -h | --help | '-?')
      DISPLAY_HELP='true'
      ;;

    -i | --reinstall-package)
      if validate_param_argument "${1?}" "${2-unset}"; then
        minutil_reinstall_package "${2?}" || set_status_if_error "${?}"
        shift
      fi
      ;;

    --remove-all-accounts)
      minutil_remove_all_accounts
      ;;

    -s | --rescan-storage)
      if test "${CURRENT_USER?}" = 'root'; then
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
      minutil_reset_gms_data
      ;;

    -R | --reset-permissions)
      printf '%s\n' 'Not yet supported'
      set_status_if_error '1'
      ;;

    --)
      shift
      break
      ;;

    --*) invalid_param "unrecognized option '${1}'" ;;
    -*) invalid_param "invalid option -- '${1#-}'" ;;
    *) break ;;
  esac

  set_status_if_error "${?}"
  shift
done || :

test "${#}" -eq 0 || invalid_param "invalid parameter '${1-}'"

if test "${DISPLAY_HELP:?}" = 'true'; then
  if test "${_minutil_newline:-false}" != 'false'; then printf '\n'; fi
  _minutil_script_name="$(basename "${0:?}")" || exit 1
  readonly _minutil_script_name

  printf '%s\n' "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?} - Minimal utilities"
  printf '%s\n\n' 'Licensed under GPLv3+'
  printf '%s\n\n' "Usage: ${_minutil_script_name:?} [OPTIONS] [--]"

  _minutil_aligned_print '-h,--help' 'Show this help'
  _minutil_aligned_print '-s,--rescan-storage' 'Rescan storage to find file changes'
  _minutil_aligned_print '--reset-battery' 'Reset battery stats and, if possible, also reset battery fuel gauge chip (need root)'
  _minutil_aligned_print '--remove-all-accounts' 'Remove all accounts from the device (need root)'
  _minutil_aligned_print '--force-gcm-reconnection' 'Force GCM reconnection'
  _minutil_aligned_print '-r,--reset-gms-data' 'Reset GMS data of all apps (need root)'
  _minutil_aligned_print '-i,--reinstall-package PACKAGE_NAME' 'Reinstall PACKAGE_NAME as if it were installed from Play Store and grant it all permissions'

  printf '%s\n' "
Examples:

${_minutil_script_name:?} -i org.schabi.newpipe
${_minutil_script_name:?} --rescan-storage
"
elif test "${STATUS:?}" -ne 0; then
  printf 1>&2 '%s\n' "Try '$(basename "${0-script}" || echo "${0-script}" || :) --help' for more information."
fi

exit "${STATUS:?}"
