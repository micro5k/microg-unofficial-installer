#!/system/bin/sh
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined
# shellcheck disable=SC2310 # Ignore: This function is invoked in an 'if' condition so set -e will be disabled

readonly SCRIPT_NAME='MinUtil'
readonly SCRIPT_SHORTNAME="${SCRIPT_NAME?}"
readonly SCRIPT_VERSION='1.3.5'

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

contains()
{
  case "${2?}" in
    *"${1:?}"*) return 0 ;; # Found
    *) ;;                   # NOT found
  esac
  return 1 # NOT found
}

_minutil_fix_tmpdir()
{
  # In some cases ${TMPDIR} is not set and it cause errors with HereDocs
  if test -z "${TMPDIR-}"; then
    if test -w '/tmp'; then TMPDIR='/tmp'; elif test -w '/postinstall/tmp'; then TMPDIR='/postinstall/tmp'; elif test -w '/data/local/tmp'; then TMPDIR='/data/local/tmp'; fi
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
    getopt -o '+vVhsmri:' -l 'version,help,rescan-storage,fix-microg,reset-battery,remove-all-accounts,force-gcm-reconnection,reset-gms-data,reinstall-package:' -n "${SCRIPT_SHORTNAME:?}" -- "${@}"
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
      break
    fi
  done
  unset param
fi

_list_account_files()
{
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
  } || {
    error_msg 'HereDoc failed'
    return 1
  }
}

_gms_list_perms()
{
  {
    cat << 'EOF'
android.permission.ACCESS_COARSE_LOCATION
android.permission.ACCESS_FINE_LOCATION
android.permission.ACCESS_BACKGROUND_LOCATION
android.permission.ACCESS_NETWORK_STATE
android.permission.ACCESS_WIFI_STATE
android.permission.AUTHENTICATE_ACCOUNTS
android.permission.BLUETOOTH
android.permission.BLUETOOTH_ADMIN
android.permission.BLUETOOTH_ADVERTISE
android.permission.BLUETOOTH_CONNECT
android.permission.BLUETOOTH_SCAN
android.permission.BODY_SENSORS
android.permission.CAMERA
android.permission.CHANGE_DEVICE_IDLE_TEMP_WHITELIST
android.permission.CHANGE_WIFI_STATE
android.permission.FAKE_PACKAGE_SIGNATURE
android.permission.FOREGROUND_SERVICE
android.permission.GET_ACCOUNTS
android.permission.INSTALL_LOCATION_PROVIDER
android.permission.INTERACT_ACROSS_PROFILES
android.permission.INTERACT_ACROSS_USERS
android.permission.INTERNET
android.permission.LOCATION_HARDWARE
android.permission.MANAGE_ACCOUNTS
android.permission.MANAGE_USB
android.permission.MODIFY_PHONE_STATE
android.permission.NETWORK_SCAN
android.permission.NFC
android.permission.POST_NOTIFICATIONS
android.permission.READ_CONTACTS
android.permission.READ_EXTERNAL_STORAGE
android.permission.READ_PHONE_STATE
android.permission.READ_SYNC_SETTINGS
android.permission.READ_SYNC_STATS
android.permission.RECEIVE_BOOT_COMPLETED
android.permission.RECEIVE_SMS
android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
android.permission.START_ACTIVITIES_FROM_BACKGROUND
android.permission.SYSTEM_ALERT_WINDOW
android.permission.UPDATE_APP_OPS_STATS
android.permission.UPDATE_DEVICE_STATS
android.permission.USE_BIOMETRIC
android.permission.USE_CREDENTIALS
android.permission.USE_FINGERPRINT
android.permission.WAKE_LOCK
android.permission.WATCH_APPOPS
android.permission.WRITE_EXTERNAL_STORAGE
android.permission.WRITE_SYNC_SETTINGS
com.google.android.c2dm.permission.RECEIVE
com.google.android.c2dm.permission.SEND
com.google.android.gms.auth.api.phone.permission.SEND
com.google.android.gms.auth.permission.GOOGLE_ACCOUNT_CHANGE
com.google.android.gms.nearby.exposurenotification.EXPOSURE_CALLBACK
com.google.android.gms.permission.AD_ID
com.google.android.gtalkservice.permission.GTALK_SERVICE
org.microg.gms.STATUS_BROADCAST
EOF
  } || {
    error_msg 'HereDoc failed'
    return 1
  }
}

_store_list_perms()
{
  {
    cat << 'EOF'
android.permission.ACCESS_COARSE_LOCATION
android.permission.ACCESS_NETWORK_STATE
android.permission.DELETE_PACKAGES
android.permission.FAKE_PACKAGE_SIGNATURE
android.permission.FOREGROUND_SERVICE
android.permission.GET_ACCOUNTS
android.permission.INSTALL_PACKAGES
android.permission.INTERACT_ACROSS_PROFILES
android.permission.INTERACT_ACROSS_USERS
android.permission.INTERNET
android.permission.POST_NOTIFICATIONS
android.permission.QUERY_ALL_PACKAGES
android.permission.REQUEST_INSTALL_PACKAGES
android.permission.USE_CREDENTIALS
com.google.android.gms.auth.permission.GOOGLE_ACCOUNT_CHANGE
com.google.android.gms.permission.READ_SETTINGS
org.microg.gms.permission.READ_SETTINGS
EOF
  } || {
    error_msg 'HereDoc failed'
    return 1
  }
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

_minutil_package_is_microg()
{
  if dumpsys 2> /dev/null package "${1:?}" | grep -q -m 1 -F -e '/org.microg.gms.'; then
    printf '%s\n' "  ${2?}"
    return 0
  fi

  return 1
}

_minutil_is_perm_granted()
{
  if contains " ${1:?}: granted=true" "${CACHE_GRANTED_PERMS?}" && ! contains " ${1:?}: granted=false" "${CACHE_GRANTED_PERMS?}"; then
    return 0
  fi

  return 1
}

_minutil_is_system_perm()
{
  case "${1:?}" in
    'android.permission.'* | 'com.android.permission.'*) return 0 ;;
    *) ;;
  esac
  return 1
}

_minutil_grant_perms()
{
  local _status _result

  CACHE_GRANTED_PERMS="$(dumpsys package "${1:?}" | grep -F -e 'granted=')" || return 3

  _status=0
  while IFS='' read -r _perm; do
    if _minutil_is_perm_granted "${_perm:?}"; then continue; fi

    _result="$(pm 2>&1 grant "${1:?}" "${_perm:?}")" || {
      case "${_result?}" in
        *"Unknown permission: ${_perm:?}"*)
          # Unknown permission
          if test "${SCRIPT_VERBOSE:?}" != 'false'; then
            # ${CACHE_USABLE_PERMS} does NOT always list all permissions so it can't be used to filter permissions earlier in the code
            if _minutil_is_system_perm "${_perm:?}" && ! contains "${_perm:?}" "${CACHE_USABLE_PERMS:?}"; then
              warn_msg "Permission NOT supported by your ROM => ${_perm?}"
            else
              warn_msg "Unknown permission => ${_perm?}"
            fi
          fi
          ;;
        *"Package ${1:?} has not requested permission ${_perm:?}"*)
          # Permission has NOT been requested by the app (probably it is an old version of microG)
          test "${SCRIPT_VERBOSE:?}" = 'false' || warn_msg "Permission has NOT been requested by the app => ${_perm?}"
          ;;
        *"Permission ${_perm:?} is not a changeable permission type"* | *"Permission ${_perm:?} requested by ${1:?} is not a changeable permission type"*)
          # Permission CANNOT be granted manually
          test "${SCRIPT_VERBOSE:?}" = 'false' || warn_msg "NOT a changeable permission => ${_perm?}"
          ;;
        *"Permission ${_perm:?} is managed by role"*)
          # Permission CANNOT be granted manually
          warn_msg "Permission is managed by role => ${_perm?}"
          ;;
        *)
          _status=255
          warn_msg "Failed to grant '${_perm?}' to '${1?}'"
          ;;
      esac
      continue
    }
    printf '%s\n' "    Granted '${_perm?}' to '${1?}'"
  done || {
    _status=2
    warn_msg "Failed to grant permissions to '${1?}'"
  }

  unset CACHE_GRANTED_PERMS
  return "${_status:?}"
}

_minutil_set_installer()
{
  test -n "{2?}" || return 2
  su "${2:?}" pm set-installer "${1:?}" 'com.android.vending'
}

minutil_fix_microg()
{
  local _store_uid

  _minutil_fix_tmpdir

  CACHE_USABLE_PERMS="$(pm list permissions | grep -F -e 'permission:' | cut -d ':' -f '2-' -s)" || return 2
  _store_uid="$(dumpsys 2> /dev/null package 'com.android.vending' | grep -m 1 -F -e 'userId=' | cut -d '=' -f '2-' -s || :)" # Get store uid

  printf '%s\n\n' 'Granting permissions to microG...'
  if _minutil_package_is_microg 'com.google.android.gms' 'microG Services'; then
    _gms_list_perms | _minutil_grant_perms 'com.google.android.gms' || set_status_if_error "${?}"
    _minutil_set_installer 1> /dev/null 2>&1 'com.google.android.gms' "${_store_uid?}" || :
    printf '\n'
  fi
  if _minutil_package_is_microg 'com.android.vending' 'microG Companion'; then
    _store_list_perms | _minutil_grant_perms 'com.android.vending' || set_status_if_error "${?}"
    _minutil_set_installer 1> /dev/null 2>&1 'com.android.vending' "${_store_uid?}" || :
    printf '\n'
  fi

  unset CACHE_USABLE_PERMS
  printf '%s\n' 'Done'
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

  test -d '/data' || {
    error_msg '/data NOT found'
    return 1
  }
  test -w '/data' || {
    error_msg '/data is NOT writable'
    return 1
  }

  _minutil_fix_tmpdir

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

    -m | --fix-microg)
      if test "${SYSTEM_API:?}" -ge 24; then
        minutil_fix_microg
      else
        printf '%s\n' 'Not yet supported'
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
  _minutil_aligned_print '-m,--fix-microg'
  _minutil_aligned_print '--force-gcm-reconnection' 'Force GCM reconnection'
  _minutil_aligned_print '--remove-all-accounts' 'Remove all accounts from the device (need root)'
  _minutil_aligned_print '--reset-battery' 'Reset battery stats and, if possible, also reset battery fuel gauge chip (need root)'
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
