#!/sbin/sh
# ADDOND_VERSION=2
# INFO: This script backup and restore microG during ROM upgrades

# SPDX-FileCopyrightText: Copyright (C) 2016-2019, 2021 ale5000
# SPDX-License-Identifer: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# shellcheck source=/dev/null
. /tmp/backuptool.functions

list_files()
{
cat <<'EOF'
%PLACEHOLDER-1%
EOF
}

case "$1" in
  backup)
    echo 'Backup of microG unofficial installer in progress...'
    list_files | while read -r FILE _; do
      if test -z "${FILE}"; then continue; fi
      # shellcheck disable=SC2154
      echo " ${S}/${FILE}"
      backup_file "${S}/${FILE}"
    done
    echo 'Done.'
  ;;
  restore)
    echo 'Restore of microG unofficial installer in progress...'
    list_files | while read -r FILE REPLACEMENT; do
      if test -z "${FILE}"; then continue; fi
      R=""
      [ -n "${REPLACEMENT}" ] && R="${S}/${REPLACEMENT}"
      # shellcheck disable=SC2154
      [ -f "${C}/${S}/${FILE}" ] && restore_file "${S}/${FILE}" "${R}"
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
esac
