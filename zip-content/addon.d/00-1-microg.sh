#!/sbin/sh
# ADDOND_VERSION=3

# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# INFO: This script backup and restore microG during ROM upgrades

# NOTE: The file come from: https://github.com/LineageOS/android_vendor_lineage/blob/master/prebuilt/common/bin/backuptool.functions
# shellcheck source=/dev/null
. '/tmp/backuptool.functions'

list_files()
{
cat <<'EOF'
%PLACEHOLDER-1%
EOF
}

case "${1}" in
  backup)
    echo 'Backup of microG unofficial installer in progress...'
    list_files | while read -r FILE _; do
      if test -z "${FILE?}"; then continue; fi
      echo " ${S:?}/${FILE:?}"
      backup_file "${S:?}/${FILE:?}"
    done
    echo 'Done.'
  ;;
  restore)
    echo 'Restore of microG unofficial installer in progress...'
    list_files | while read -r FILE REPLACEMENT; do
      if test -z "${FILE?}"; then continue; fi
      R=''
      [ -n "${REPLACEMENT?}" ] && R="${S:?}/${REPLACEMENT:?}"
      [ -f "${C:?}/${S:?}/${FILE:?}" ] && restore_file "${S:?}/${FILE:?}" "${R?}"
    done
    echo 'Done.'
  ;;
  pre-backup)
    # Stub
  ;;
  post-backup)
    # Stub
  ;;
  pre-restore)
    # Stub
  ;;
  post-restore)
    # Stub
  ;;
  *)
    echo 'ERROR'
  ;;
esac
