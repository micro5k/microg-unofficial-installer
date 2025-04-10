#!/sbin/sh
# ADDOND_VERSION=3
# SPDX-FileCopyrightText: none
# SPDX-License-Identifier: CC0-1.0

BASE_NAME='microG unofficial installer'

_init_debug_log()
{
  test -z "${DEBUG_LOG-}" || return
  DEBUG_LOG=0
  DEBUG_LOG_FILE=''

  if command 1> /dev/null -v 'getprop' && test "$(getprop 'zip.common.DEBUG_LOG' '0' || :)" = 1; then
    if test -w "${TMPDIR:-/tmp}" && DEBUG_LOG_FILE="${TMPDIR:-/tmp}/debug-a5k.log"; then :; else test -w '/postinstall/tmp' && DEBUG_LOG_FILE='/postinstall/tmp/debug-a5k.log'; fi
    if test -n "${DEBUG_LOG_FILE?}" && touch "${DEBUG_LOG_FILE:?}"; then
      echo 1>&2 "Writing log: ${DEBUG_LOG_FILE?}"
      DEBUG_LOG=1
    fi
  fi
}

_display_msg()
{
  _init_debug_log
  echo "${1?}"
  test "${DEBUG_LOG:?}" = 0 || echo "${1?}" 1>> "${DEBUG_LOG_FILE:?}"
}

# NOTE: The following file come from => https://github.com/LineageOS/android_vendor_lineage/blob/HEAD/prebuilt/common/bin/backuptool.functions
# shellcheck source=/dev/null
command . /tmp/backuptool.functions || {
  _display_msg 1>&2 'ERROR: Failed to source backuptool.functions'
  # shellcheck disable=SC2317
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
    _display_msg "${BASE_NAME?} - stage: ${1?}..."
    list_files | while IFS='|' read -r FILE _; do
      test -n "${FILE?}" || continue
      _display_msg " ${S:?}/${FILE:?}"
      backup_file "${S:?}/${FILE:?}"
    done
    _display_msg 'Done.'
    ;;
  restore)
    _display_msg "${BASE_NAME?} - stage: ${1?}..."
    list_files | while IFS='|' read -r FILE REPLACEMENT; do
      test -n "${FILE?}" || continue
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
    _display_msg 1>&2 "WARNING: addon.d unknown phase => ${1-}"
    ;;
esac
