#!/sbin/sh
#
# /system/addon.d/00-1-microg.sh
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

    echo 'Backup of microG in progress...'
    list_files | while read FILE DUMMY; do
      if test -z "$FILE"; then continue; fi
      echo " "$S/"$FILE"
      backup_file $S/"$FILE"
    done

    echo 'Backup of microG libs in progress...'
    for entry in $S/"priv-app/GmsCore/lib"/*; do
      for sub_entry in "${entry}"/*; do
        echo " ${sub_entry}"
        backup_file "${sub_entry}"
      done
    done

    echo 'Done.'

  ;;
  restore)
    list_files | while read FILE REPLACEMENT; do
      if test -z "$FILE"; then continue; fi
      R=""
      [ -n "$REPLACEMENT" ] && R="$S/$REPLACEMENT"
      [ -f "$C/$S/$FILE" ] && restore_file $S/"$FILE" "$R"
    done
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
