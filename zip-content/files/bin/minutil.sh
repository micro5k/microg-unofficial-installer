#!/system/bin/sh
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# shellcheck disable=SC2310

set -e
# shellcheck disable=SC3040
set -o posix 2> /dev/null || true
# shellcheck disable=SC3040
set -o pipefail || true

case "${0:?}" in
  *'.sh') ;;
  *'sh')
    \printf 1>&2 '\033[1;31m%s\033[0m\n' 'ERROR: MinUtil cannot be sourced'
    \exit 1
    ;;
  *) ;;
esac

_minutil_error()
{
  \printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR: ${*?}"
}

_minutil_check_getopt()
{
  \unset GETOPT_COMPATIBLE
  getopt_test='0'
  \getopt -T -- 2> /dev/null || getopt_test="${?}"
  if \test "${getopt_test:?}" != '4'; then
    \printf 1>&2 '\033[0;33m%s\033[0m\n' 'WARNING: Limited or missing getopt'
    \return 1
  fi
  \unset getopt_test

  return 0
}

if \_minutil_check_getopt; then
  if minutil_args="$(\unset POSIXLY_CORRECT; \getopt -o 'hi:' -l 'help,reinstall-package:,remove-all-accounts' -n 'MinUtil' -- "${@}")" && \test "${minutil_args:?}" != ' --'; then
    \eval ' \set' '--' "${minutil_args:?}" || \exit 1
  else
    \set -- '--help' '--' || \exit 1
  fi
  \unset minutil_args
elif \test "${*}" = ''; then
  \set -- '--help' '--' || \exit 1
fi

_is_caller_adb_or_root()
{
  if \test "$(\whoami || true)" != 'shell' && \test "$(\whoami || true)" != 'root'; then
    \_minutil_error 'You must execute it as either ADB or root'
    \return 1
  fi
}

_is_caller_root()
{
  if \test "$(\whoami || true)" != 'root'; then
    \_minutil_error 'You must execute it as root'
    \return 1
  fi
}

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
  pm path -- "${1:?}" | cut -d ':' -f 2 || return 1
}

_minutil_reinstall_split_package()
{
  \_is_caller_adb_or_root || \return 1

  _install_sid="$(pm install-create -i 'com.android.vending' -r -g -- | grep -F -e 'Success: created install session' | grep -oE -e '[0-9]+')" || return "${?}"
  _file_index=0
  echo "${1:?}" | while IFS='' read -r _file; do
    if test -e "${_file:?}"; then
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

  echo "Reinstalling ${1:?}..."
  command -v -- pm 1> /dev/null || {
    _minutil_error 'Package manager is NOT available'
    return 1
  }

  _package_path="$(_minutil_find_package "${1:?}")" || {
    _minutil_error "Package '${1?}' not found"
    return 2
  }
  _apk_count="$(echo "${_package_path:?}" | wc -l --)"
  if test "${_apk_count:?}" -ge 2; then
    _minutil_reinstall_split_package "${_package_path:?}" || {
      _status="${?}"
      _minutil_error 'Split package reinstall failed'
      return "${_status:?}"
    }
  else
    pm install -i 'com.android.vending' -r -g -- "${_package_path:?}" || {
      _minutil_error 'Package reinstall failed'
      return 3
    }
  fi

  unset _package_path _apk_count
  echo "Package ${1:?} reinstalled."
}

minutil_remove_all_accounts()
{
  \_is_caller_root || \return 1
  mount /data 2> /dev/null || true
  test -e '/data' || {
    _minutil_error '/data NOT found'
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

_minutil_display_help='false'
while true; do
  case "${1}" in
    -h | --help | -\?)
      _minutil_display_help='true'
      ;;

    -i | --reinstall-package)
      \minutil_reinstall_package "${2:?}"
      shift
      ;;

    --remove-all-accounts)
      \minutil_remove_all_accounts
      ;;

    --)
      break
      ;;

    '')
      ;; # Ignore empty parameters

    *)
      _minutil_display_help='true'
      \printf 1>&2 'MinUtil: invalid option -- %s\n' "'${1#-}'"
      ;;
  esac
  \shift || \break
done

if test "${_minutil_display_help:?}" = 'true'; then
  printf '\n%s\n' 'MinUtil
Various utility functions.

-i | --reinstall-package PACKAGE_NAME		Reinstall package as if it were installed from Play Store and grant it all permissions, example: minutil -i org.schabi.newpipe
--remove-all-accounts				Remove all accounts from the device'
fi

\exit "${?}"
