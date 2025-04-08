#!/sbin/sh
# ADDOND_VERSION=3
# SPDX-FileCopyrightText: none
# SPDX-License-Identifier: CC0-1.0

_init_debug_log()
{
  DEBUG_LOG=0
  DEBUG_LOG_FILE=''

  if command 1> /dev/null -v 'getprop' && test "$(getprop 'zip.common.DEBUG_LOG' '0' || :)" = 1; then
    if test -d "${TMPDIR:-/tmp}" && DEBUG_LOG_FILE="${TMPDIR:-/tmp}/debug-a5k.log" && touch "${DEBUG_LOG_FILE:?}"; then DEBUG_LOG=1; fi
  fi
}

_display_msg()
{
  echo "${1?}"
  test "${DEBUG_LOG:?}" = 0 || echo "${1?}" 1>> "${DEBUG_LOG_FILE:?}"
}

# NOTE: The following file come from => https://github.com/LineageOS/android_vendor_lineage/blob/HEAD/prebuilt/common/bin/backuptool.functions
# shellcheck source=/dev/null
command . '/tmp/backuptool.functions' || {
  _init_debug_log
  _display_msg 1>&2 'ERROR: Failed to source backuptool.functions'
  return 9 || exit 9
}

list_files()
{
  cat << 'EOF'
%PLACEHOLDER-1%
EOF
}

case "${1-}" in
  backup)
    _init_debug_log
    _display_msg 'Backup of microG unofficial installer in progress...'
    list_files | while IFS='|' read -r FILE _; do
      if test -z "${FILE?}"; then continue; fi
      _display_msg " ${S:?}/${FILE:?}"
      backup_file "${S:?}/${FILE:?}"
    done
    _display_msg 'Done.'
    ;;
  restore)
    _init_debug_log
    _display_msg 'Restore of microG unofficial installer in progress...'
    list_files | while IFS='|' read -r FILE REPLACEMENT; do
      if test -z "${FILE?}"; then continue; fi
      R=''
      test -n "${REPLACEMENT?}" && R="${S:?}/${REPLACEMENT:?}"
      test -f "${C:?}/${S:?}/${FILE:?}" && restore_file "${S:?}/${FILE:?}" "${R?}"
    done
    _display_msg 'Done.'
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
    _init_debug_log
    _display_msg 1>&2 "WARNING: addon.d unknown phase => ${1-}"
    ;;
esac
