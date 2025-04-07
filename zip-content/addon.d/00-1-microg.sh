#!/sbin/sh
# ADDOND_VERSION=3
# SPDX-FileCopyrightText: none
# SPDX-License-Identifier: CC0-1.0

# NOTE: The following file come from: https://github.com/LineageOS/android_vendor_lineage/blob/HEAD/prebuilt/common/bin/backuptool.functions
# shellcheck source=/dev/null
command . '/tmp/backuptool.functions' || { echo 1>&2 'ERROR: Failed to source backuptool.functions'; return 9; }

list_files()
{
  cat << 'EOF'
%PLACEHOLDER-1%
EOF
}

case "${1}" in
  backup)
    echo 'Backup of microG unofficial installer in progress...'
    list_files | while IFS='|' read -r FILE _; do
      if test -z "${FILE?}"; then continue; fi
      echo " ${S:?}/${FILE:?}"
      backup_file "${S:?}/${FILE:?}"
    done
    echo 'Done.'
    ;;
  restore)
    echo 'Restore of microG unofficial installer in progress...'
    list_files | while IFS='|' read -r FILE REPLACEMENT; do
      if test -z "${FILE?}"; then continue; fi
      R=''
      test -n "${REPLACEMENT?}" && R="${S:?}/${REPLACEMENT:?}"
      test -f "${C:?}/${S:?}/${FILE:?}" && restore_file "${S:?}/${FILE:?}" "${R?}"
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
    echo 1>&2 'WARNING: addon.d unknown phase'
    ;;
esac
