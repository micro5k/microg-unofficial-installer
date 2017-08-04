#!/sbin/sh

<<LICENSE
  Copyright (C) 2016-2017  ale5000
  This file is part of microG unofficial installer by @ale5000.

  microG unofficial installer is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version, w/microG unofficial installer zip exception.

  microG unofficial installer is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with microG unofficial installer.  If not, see <http://www.gnu.org/licenses/>.
LICENSE

if [[ -z "$RECOVERY_PIPE" || -z "$ZIP_FILE" || -z "$TMP_PATH" ]]; then
  echo 'Some variables are NOT set.'
  exit 90
fi

### FUNCTIONS ###

# Message related functions
ui_msg()
{
  echo -e "ui_print $1\nui_print" >> $RECOVERY_PIPE
  if [[ "$DEBUG_LOG" -ne 0 ]]; then echo "$1"; fi
}

ui_msg_sameline_start()
{
  echo -n "ui_print $1" >> $RECOVERY_PIPE
}

ui_msg_sameline_end()
{
  echo -e " $1\nui_print" >> $RECOVERY_PIPE
}

ui_debug()
{
  echo "$1"
}

ui_error()
{
  #>&2 echo "ERROR: $1"
  ui_msg "ERROR: $1"
  test -n "$2" && exit "$2"
  exit 91
}

# Error checking functions
validate_return_code()
{
  if [[ "$1" != 0 ]]; then ui_error "ERROR: $2"; fi
}

# Mounting related functions
is_mounted()
{
  case `mount` in
    *" $1 "*) return 0;;  # Mounted
  esac;
  return 1  # NOT mounted
}

is_mounted_read_write()
{
  mount | grep " $1 " | head -n1 | grep -qi -e "[(\s,]rw[\s,)]"
}

get_mount_status()
{
  local mount_line=$(mount | grep " $1 " | head -n1)
  if [[ -z "$mount_line" ]]; then return 1; fi  # NOT mounted
  if echo "$mount_line" | grep -qi -e "[(\s,]rw[\s,)]"; then return 0; fi  # Mounted read-write (RW)
  return 2  # Mounted read-only (RO)
}

remount_read_write()
{
  mount -v -o remount,rw "$1" "$1"
}

remount_read_only()
{
  mount -v -o remount,ro "$1" "$1"
}

# Getprop related functions
getprop()
{
  (test -e '/sbin/getprop' && /sbin/getprop "ro.${1}") || (grep "^ro\.${1}=" '/default.prop' | head -n1 | cut -d '=' -f 2)
}

build_getprop()
{
  grep "^ro\.${1}=" "$TMP_PATH/build.prop" | head -n1 | cut -d '=' -f 2
}

# String related functions
is_substring()
{
  case "$2" in
    *"$1"*) return 0;;  # Found
  esac;
  return 1  # NOT found
}

# Permission related functions
set_perm()
{
  local uid="$1"; local gid="$2"; local mod="$3"
  shift 3
  chown $uid:$gid "$@" || ui_error "chown failed on '$@'" 92
  chmod $mod "$@" || ui_error "chmod failed on '$@'" 93
}

set_std_perm_recursive()  # Use it only if you know your version of 'find' handle spaces correctly
{
  find "$1" -type d -exec chmod 0755 '{}' + -o -type f -exec chmod 0644 '{}' +
  validate_return_code "$?" 'Failed to set permissions recursively'
}

# Extraction related functions
package_extract_file()
{
  local dir=$(dirname "$2")
  mkdir -p "$dir" || ui_error "Failed to create the dir '$dir' for extraction" 94
  set_perm 0 0 0755 "$dir"
  unzip -opq "$ZIP_FILE" "$1" > "$2" || ui_error "Failed to extract the file '$1' from this archive" 94
}

custom_package_extract_dir()
{
  mkdir -p "$2" || ui_error "Failed to create the dir '$2' for extraction" 95
  set_perm 0 0 0755 "$2"
  unzip -oq "$ZIP_FILE" "$1/*" -d "$2" || ui_error "Failed to extract the dir '$1' from this archive" 95
}

zip_extract_dir()
{
  mkdir -p "$3" || ui_error "Failed to create the dir '$3' for extraction" 96
  set_perm 0 0 0755 "$3"
  unzip -oq "$1" "$2/*" -d "$3" || ui_error "Failed to extract the dir '$2' from the archive '$1'" 96
}

# Hash related functions
verify_sha1()
{
  local file_name="$1"
  local hash="$2"
  local file_hash=$(sha1sum "$file_name" | cut -d ' ' -f 1)

  if [[ $hash != "$file_hash" ]]; then return 1; fi  # Failed
  return 0  # Success
}

# File related functions
create_dir()
{
  mkdir -p "$1" || ui_error "Failed to create the dir '$dir'" 97
  set_perm 0 0 0755 "$1"
}

copy_dir_content()
{
  cp -rpf "$1"/* "$2"/ || ui_error "Failed to copy dir content from '$1' to '$2'" 98
}

delete()
{
  rm -f "$@" || ui_error "Failed to delete files" 99
}

delete_recursive()
{
  rm -rf "$@" || ui_error "Failed to delete files/folders" 99
}

# Input related functions
check_key()
{
  case "$1" in
  42)  # Vol +
    return 3;;
  21)  # Vol -
    return 2;;
  143)  # Nothing selected
    return 1;;
  *)
    return 0;;
  esac
}

choose_timeout()
{
  timeout -t "$1" keycheck
  check_key "$?"
  return "$?"
}

choose()
{
  local result=1
  ui_msg "QUESTION: $1"
  ui_msg "$2"
  ui_msg "$3"
  while true; do
    timeout -t 1 keycheck; result="$?"
    if [ "$result" -ne 143 ]; then check_key "$result"; return "$?"; fi
    sleep 0.03
  done
}

# Other
remove_ext()
{
  local str="$1"
  echo "${str%.*}"
}

# Test
find_test()  # This is useful to test 'find' - if every file/folder, even the ones with spaces, is displayed in a single line then your version is good
{
  find "$1" -type d -exec echo FOLDER: '{}' ';' -o -type f -exec echo FILE: '{}' ';' | while read x; do echo "$x"; done
}
