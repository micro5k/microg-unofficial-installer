#!/sbin/sh
#
# ADDOND_VERSION=2
#
# /system/addon.d/00-1-microg.sh
#

# This script backup and restore microG during a ROM upgrade.

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
    list_files | while read FILE _; do
      if test -z "$FILE"; then continue; fi
      echo " $S/$FILE"
      backup_file "$S/$FILE"
    done
    echo 'Done.'
  ;;
  restore)
    echo 'Restore of microG unofficial installer in progress...'
    list_files | while read FILE REPLACEMENT; do
      if test -z "$FILE"; then continue; fi
      R=""
      [ -n "$REPLACEMENT" ] && R="$S/$REPLACEMENT"
      [ -f "$C/$S/$FILE" ] && restore_file "$S/$FILE" "$R"
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
