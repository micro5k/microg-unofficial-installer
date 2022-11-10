#!/system/bin/sh
# -*- coding: utf-8 -*-

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
    echo 'ERROR: MinUtil cannot be sourced'
    exit 1
    ;;
  *) ;;
esac

_is_caller_adb_or_root()
{
  if test "$(whoami || true)" != 'shell' && test "$(whoami || true)" != 'root'; then
    echo 'ERROR: You must execute it as either ADB or root'
    return 1
  fi
}

_is_caller_root()
{
  if test "$(whoami || true)" != 'root'; then
    echo 'ERROR: You must execute it as root'
    return 1
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
  _is_caller_adb_or_root || return 1

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
      echo 'ERROR: Split package is missing'
      pm install-abandon "${_install_sid:?}"
      return 4
    fi
  done || return "${?}"

  pm install-commit "${_install_sid:?}" || return "${?}"
}

minutil_reinstall_package()
{
  _is_caller_adb_or_root || return 1

  echo "Reinstalling ${1:?}..."
  command -v -- pm 1> /dev/null || {
    echo 'ERROR: Package manager is NOT available'
    return 1
  }

  _package_path="$(_minutil_find_package "${1:?}")" || {
    echo "ERROR: Package '${1?}' not found"
    return 2
  }
  _apk_count="$(echo "${_package_path:?}" | wc -l --)"
  if test "${_apk_count:?}" -ge 2; then
    _minutil_reinstall_split_package "${_package_path:?}" || {
      _status="${?}"
      echo 'ERROR: Split package reinstall failed'
      return "${_status:?}"
    }
  else
    pm install -i 'com.android.vending' -r -g -- "${_package_path:?}" || {
      echo 'ERROR: Package reinstall failed'
      return 3
    }
  fi

  unset _package_path _apk_count
  echo "Package ${1:?} reinstalled."
}

minutil_remove_all_accounts()
{
  _is_caller_root || return 1
  mount /data 2> /dev/null || true
  test -e '/data' || {
    echo 'ERROR: /data NOT found'
    return 1
  }

  _list_account_files | while IFS='' read -r _file; do
    if test -e "${_file:?}"; then
      echo "Deleting '${_file:?}'..."
      rm -f -- "${_file}" || return 1
    fi
  done || {
    echo 'ERROR: Failed to delete accounts'
    return 4
  }

  echo "All accounts deleted. Now restart the device!!!"
}

case "${1}" in
  -i | --reinstall-package)
    minutil_reinstall_package "${2:?}"
    ;;

  --remove-all-accounts)
    minutil_remove_all_accounts
    ;;

  *)
    echo 'MinUtil
Various utility functions.

-i | --reinstall-package PACKAGE_NAME		Reinstall package as if it were installed from Play Store and grant it all permissions, example: minutil -i org.schabi.newpipe
--remove-all-accounts				Remove all accounts from the device'
    ;;
esac

\exit "${?}"
