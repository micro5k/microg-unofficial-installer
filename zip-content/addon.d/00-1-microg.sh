#!/sbin/sh
#
# /system/addon.d/00-1-microg.sh
# During a ROM upgrade, this script backs up microG,
# /system is formatted and reinstalled, then files are restored.
#

. /tmp/backuptool.functions

list_files()
{
cat <<EOF
%PLACEHOLDER%
EOF
}

case "$1" in
  backup)
    echo 'Backup of microG unofficial installer in progress...'
    list_files | while read FILE DUMMY; do
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
