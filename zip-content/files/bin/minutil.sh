#!/system/bin/sh
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

set -e
# shellcheck disable=SC3040
set -o posix 2>/dev/null || true
# shellcheck disable=SC3040
set -o pipefail || true

if test "$(whoami || true)" != 'shell' && test "$(whoami || true)" != 'root'; then
  echo 'ERROR: You must execute it as either ADB or root'
  exit 1
fi

_minutil_find_package()
{
  pm path -- "${1:?}" | cut -d ':' -f 2 || return 1
}

_list_account_files()
{
  cat <<'EOF'
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

minutil_reinstall_package()
{
  # shellcheck disable=2310
  _package_path="$(_minutil_find_package "${1:?}")" || { echo "ERROR: Package '${1?}' not found"; return 2; }
  pm install -i 'com.android.vending' -r -g -- "${_package_path:?}" || { echo 'ERROR: Package reinstall failed'; return 3; }
  unset _package_path
  echo "Package ${1:?} reinstalled."
}

minutil_remove_all_accounts()
{
  # shellcheck disable=2310
  _list_account_files | while IFS='' read -r _file; do
    if test -e "${_file:?}"; then
      echo "Deleting '${_file:?}'..."
      rm -f -- "${_file}" || return 1
    fi
  done || { echo 'ERROR: Failed to delete accounts'; return 4; }
  echo "All accounts deleted."
}


case "${1}" in
  -i | --reinstall-package )
    minutil_reinstall_package "${2:?}";;

  --remove-all-accounts )
    minutil_remove_all_accounts;;

  * )
    echo 'MinUtil
Various utility functions.

-i | --reinstall-package PACKAGE_NAME		Reinstall package as if it were installed from Play Store and grant it all permissions, example: minutil -i org.schabi.newpipe
--remove-all-accounts				Remove all accounts from the device';;
esac
