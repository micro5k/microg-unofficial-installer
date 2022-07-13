#!/system/bin/sh
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

set -e
# shellcheck disable=SC3040
set -o posix 2>/dev/null || true
# shellcheck disable=SC3040
set -o pipefail || true

_minutil_find_package()
{
  pm path -- "${1:?}" | cut -d ':' -f 2 || return 1
}

_minutil_reinstall_package()
{
  # shellcheck disable=2310
  _package_path="$(_minutil_find_package "${1:?}")" || { echo 'ERROR: Package not found'; return 1; }
  pm install -i 'com.android.vending' -r -g -- "${_package_path:?}" || { echo 'ERROR: Package reinstall failed'; return 2; }
  unset _package_path
  echo "Package ${1:?} reinstalled."
}


case "${1}" in
  -r | --reinstall-package )
    _minutil_reinstall_package "${2:?}"
  ;;

  * )
    echo "MinUtil
Various utility functions.

-r | --reinstall-package PACKAGE_NAME			Reinstall package as if it were installed from Play Store and grant it all permissions, example: minutil -r org.schabi.newpipe"
  ;;
esac
