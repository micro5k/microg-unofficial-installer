#!/system/bin/sh
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

set -e
# shellcheck disable=SC3040
set -o posix 2>/dev/null || true
# shellcheck disable=SC3040
set -o pipefail || true

if test "$(whoami)" != 'shell' && test "$(whoami)" != 'root'; then
  echo 'ERROR: You must execute it as either ADB or root'
  exit 1
fi

_minutil_find_package()
{
  pm path -- "${1:?}" | cut -d ':' -f 2 || return 1
}

minutil_reinstall_package()
{
  # shellcheck disable=2310
  _package_path="$(_minutil_find_package "${1:?}")" || { echo "ERROR: Package '${1?}' not found"; return 2; }
  pm install -i 'com.android.vending' -r -g -- "${_package_path:?}" || { echo 'ERROR: Package reinstall failed'; return 3; }
  unset _package_path
  echo "Package ${1:?} reinstalled."
}


case "${1}" in
  -i | --reinstall-package )
    minutil_reinstall_package "${2:?}"
  ;;

  * )
    echo "MinUtil
Various utility functions.

-i | --reinstall-package PACKAGE_NAME			Reinstall package as if it were installed from Play Store and grant it all permissions, example: minutil -i org.schabi.newpipe"
  ;;
esac
