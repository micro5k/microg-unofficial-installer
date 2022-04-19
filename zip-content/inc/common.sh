#!/sbin/sh
# shellcheck disable=SC3043,SC3037,SC3010,SC3060

# SC3043: In POSIX sh, local is undefined
# SC3037: In POSIX sh, echo flags are undefined
# SC3010: In POSIX sh, [[ ]] is undefined
# SC3060: In POSIX sh, string replacement is undefined

# SPDX-FileCopyrightText: (c) 2016-2019, 2021 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

### GLOBAL VARIABLES ###

if [[ -z "${RECOVERY_PIPE}" || -z "${ZIP_FILE}" || -z "${TMP_PATH}" ]]; then
  echo 'Some variables are NOT set.'
  exit 90
fi


### FUNCTIONS ###

# Message related functions
_show_text_on_recovery()
{
  echo -e "ui_print $1\nui_print" >> "${RECOVERY_PIPE}"
}

ui_error()
{
  ERROR_CODE=91
  if test -n "$2"; then ERROR_CODE="$2"; fi
  >&2 echo "ERROR ${ERROR_CODE}: $1"
  _show_text_on_recovery "ERROR: $1"
  exit "${ERROR_CODE}"
}

ui_warning()
{
  >&2 echo "WARNING: $1"
  _show_text_on_recovery "WARNING: $1"
}

ui_msg()
{
  if [ "${DEBUG_LOG}" -ne 0 ]; then echo "$1"; fi
  if test -e "${RECOVERY_PIPE}"; then
    printf "ui_print %s\nui_print \n" "${1}" >> "${RECOVERY_PIPE}"
  else
    printf "ui_print %s\nui_print \n" "${1}" 1>&"${OUTFD}"
  fi
}

ui_msg_sameline_start()
{
  if [ "${DEBUG_LOG}" -ne 0 ]; then echo -n "$1"; fi
  if test -e "${RECOVERY_PIPE}"; then
    printf "ui_print %s" "${1}" >> "${RECOVERY_PIPE}"
  else
    printf "ui_print %s" "${1}" 1>&"${OUTFD}"
  fi
}

ui_msg_sameline_end()
{
  if [ "${DEBUG_LOG}" -ne 0 ]; then echo "$1"; fi
  if test -e "${RECOVERY_PIPE}"; then
    printf " %s\nui_print \n" "${1}" >> "${RECOVERY_PIPE}"
  else
    printf " %s\nui_print \n" "${1}" 1>&"${OUTFD}"
  fi
}

ui_debug()
{
  echo "$1"
}

# Error checking functions
validate_return_code()
{
  if [[ "$1" != 0 ]]; then ui_error "ERROR: $2"; fi
}

# Mounting related functions
is_mounted()
{
  case $(mount) in
    *[[:blank:]]"$1"[[:blank:]]*) return 0;;  # Mounted
    *)                                        # NOT mounted
  esac
  return 1  # NOT mounted
}

ensure_system_is_mounted()
{
  if ! is_mounted '/system'; then
    mount '/system'
    if ! is_mounted '/system'; then ui_error '/system cannot be mounted'; fi
  fi
  return 0;  # OK
}

is_mounted_read_write()
{
  mount | grep " $1 " | head -n1 | grep -qi -e "[(\s,]rw[\s,)]"
}

get_mount_status()
{
  local mount_line
  mount_line=$(mount | grep " $1 " | head -n1)
  if [[ -z "${mount_line}" ]]; then return 1; fi  # NOT mounted
  if echo "${mount_line}" | grep -qi -e "[(\s,]rw[\s,)]"; then return 0; fi  # Mounted read-write (RW)
  return 2  # Mounted read-only (RO)
}

remount_read_write()
{
  mount -o remount,rw "$1" "$1"
}

remount_read_only()
{
  mount -o remount,ro "$1" "$1"
}

unmount()
{
  umount "$1" || ui_msg "WARNING: Failed to unmount '$1'"
}

# Getprop related functions
getprop()
{
  (test -e '/sbin/getprop' && /sbin/getprop "ro.$1") || (grep "^ro\.$1=" '/default.prop' | head -n1 | cut -d '=' -f 2)
}

build_getprop()
{
  grep "^ro\.$1=" "${TMP_PATH}/build.prop" | head -n1 | cut -d '=' -f 2
}

# String related functions
is_substring()
{
  case "$2" in
    *"$1"*) return 0;;  # Found
    *)                  # NOT found
  esac
  return 1  # NOT found
}

replace_string()
{
  echo "${1//$2/$3}"
}

replace_slash_with_at()
{
  local result
  result="$(echo "$@" | sed -e 's/\//@/g')"
  echo "${result}"
}

replace_line_in_file()  # $1 => File to process  $2 => Line to replace  $3 => File to read for replacement text
{
  sed -i "/$2/r $3" "$1" || ui_error "Failed to replace (1) a line in the file => '$1'" 92
  sed -i "/$2/d" "$1" || ui_error "Failed to replace (2) a line in the file => '$1'" 92
}

search_string_in_file()
{
  grep -qF "$1" "$2" && return 0  # Found
  return 1  # NOT found
}

search_ascii_string_in_file()
{
  LC_ALL=C grep -qF "$1" "$2" && return 0  # Found
  return 1  # NOT found
}

search_ascii_string_as_utf16_in_file()
{
  local SEARCH_STRING
  SEARCH_STRING=$(echo -n "$1" | od -A n -t x1 | LC_ALL=C tr -d '\n' | LC_ALL=C sed -e 's/^ //g;s/ /00/g')
  od -A n -t x1 "$2" | LC_ALL=C tr -d ' \n' | LC_ALL=C grep -qF "${SEARCH_STRING}" && return 0  # Found
  return 1  # NOT found
}

# Permission related functions
set_perm()
{
  local uid="$1"; local gid="$2"; local mod="$3"
  shift 3
  # Quote: Previous versions of the chown utility used the dot (.) character to distinguish the group name; this has been changed to be a colon (:) character, so that user and group names may contain the dot character
  chown "${uid}:${gid}" "$@" || chown "${uid}.${gid}" "$@" || ui_error "chown failed on: $*" 81
  chmod "${mod}" "$@" || ui_error "chmod failed on: $*" 81
}

set_std_perm_recursive()  # Use it only if you know your version of 'find' handle spaces correctly
{
  find "$1" -type d -exec chmod 0755 '{}' + -o -type f -exec chmod 0644 '{}' +
  validate_return_code "$?" 'Failed to set permissions recursively'
}

# Extraction related functions
package_extract_file()
{
  local dir
  dir=$(dirname "$2")
  mkdir -p "${dir}" || ui_error "Failed to create the dir '${dir}' for extraction" 94
  set_perm 0 0 0755 "${dir}"
  unzip -opq "${ZIP_FILE}" "$1" > "$2" || ui_error "Failed to extract the file '$1' from this archive" 94
}

custom_package_extract_dir()
{
  mkdir -p "$2" || ui_error "Failed to create the dir '$2' for extraction" 95
  set_perm 0 0 0755 "$2"
  unzip -oq "${ZIP_FILE}" "$1/*" -d "$2" || ui_error "Failed to extract the dir '$1' from this archive" 95
}

zip_extract_file()
{
  mkdir -p "$3" || ui_error "Failed to create the dir '$3' for extraction" 96
  set_perm 0 0 0755 "$3"
  unzip -oq "$1" "$2" -d "$3" || ui_error "Failed to extract the file '$2' from the archive '$1'" 96
}

zip_extract_dir()
{
  mkdir -p "$3" || ui_error "Failed to create the dir '$3' for extraction" 96
  set_perm 0 0 0755 "$3"
  unzip -oq "$1" "$2/*" -d "$3" || ui_error "Failed to extract the dir '$2' from the archive '$1'" 96
}

# Data reset functions
reset_gms_data_of_all_apps()
{
  ui_debug 'Resetting GMS data of all apps...'
  find /data/data/*/shared_prefs -name "com.google.android.gms.*.xml" -delete
  validate_return_code "$?" 'Failed to reset GMS data of all apps'
}

# Hash related functions
verify_sha1()
{
  if ! test -e "$1"; then ui_debug "This file to verify is missing => '$1'"; return 0; fi
  ui_debug "$1"

  local file_name="$1"
  local hash="$2"
  local file_hash

  file_hash="$(sha1sum "${file_name}" | cut -d ' ' -f 1)"
  if test -z "${file_hash}" || test "${hash}" != "${file_hash}"; then return 1; fi  # Failed
  return 0  # Success
}

# File / folder related functions
create_dir() # Ensure dir exists
{
  test -d "$1" && return
  mkdir -p "$1" || ui_error "Failed to create the dir '$1'" 97
  set_perm 0 0 0755 "$1"
}

copy_dir_content()
{
  create_dir "$2"
  cp -rpf "$1"/* "$2"/ || ui_error "Failed to copy dir content from '$1' to '$2'" 98
}

copy_file()
{
  cp -pf "$1" "$2"/ || ui_error "Failed to copy the file '$1' to '$2'" 99
}

move_file()
{
  mv -f "$1" "$2"/ || ui_error "Failed to move the file '$1' to '$2'" 100
}

move_rename_file()
{
  mv -f "$1" "$2" || ui_error "Failed to move/rename the file from '$1' to '$2'" 101
}

move_rename_dir()
{
  mv -f "$1"/ "$2" || ui_error "Failed to move/rename the folder from '$1' to '$2'" 101
}

move_dir_content()
{
  test -d "$1" || ui_error "You can only move the content of a folder" 102
  create_dir "$2"
  mv -f "$1"/* "$2"/ || ui_error "Failed to move dir content from '$1' to '$2'" 102
}

delete()
{
  ui_debug "Deleting '$*'..."
  rm -f "$@" || ui_error "Failed to delete files" 103
}

delete_recursive()
{
  if test -e "$1"; then
    ui_debug "Deleting '$1'..."
    rm -rf "$1" || ui_error "Failed to delete files/folders" 104
  fi
}

delete_recursive_wildcard()
{
  for filename in "$@"; do
    if test -e "${filename}"; then
      ui_debug "Deleting '${filename}'...."
      rm -rf "${filename:?}" || ui_error "Failed to delete files/folders" 105
    fi
  done
}

delete_dir_if_empty()
{
  if test -d "$1"; then
    ui_debug "Deleting '$1' folder (if empty)..."
    rmdir --ignore-fail-on-non-empty "$1" || ui_error "Failed to delete the '$1' folder" 103
  fi
}

list_files()  # $1 => Folder to scan   $2 => Prefix to remove
{
  test -d "$1" || return
  for entry in "$1"/*; do
    if test -d "${entry}"; then
      list_files "${entry}" "$2"
    else
      entry="${entry#"$2"}" || ui_error "Failed to remove prefix, entry => ${entry}, prefix to remove => $2" 106
      printf '%s\\n' "${entry}" || ui_error "File listing failed, entry => ${entry}, folder => $1" 106
    fi
  done
}

append_file_list()  # $1 => Folder to scan  $2 => Prefix to remove  $3 => Output filename
{
  local dir="$1"
  test -d "${dir}" || return

  shift
  # After shift: $1 => Prefix to remove  $2 => Output filename
  for entry in "${dir}"/*; do
    if test -d "${entry}"; then
      append_file_list "${entry}" "$@"
    else
      entry="${entry#"$1"}" || ui_error "Failed to remove prefix from the entry => ${entry}" 106
      echo "${entry}" >> "$2" || ui_error "File listing failed, current entry => ${entry}, folder => ${dir}" 106
    fi
  done
}

write_file_list()  # $1 => Folder to scan  $2 => Prefix to remove  $3 => Output filename
{
  delete "$3"
  append_file_list "$@"
}

# Input related functions
check_key()
{
  case "$1" in
  42)   # Vol +
    return 3;;
  21)   # Vol -
    return 2;;
  132)  # Error (example: Illegal instruction)
    return 1;;
  *)
    return 0;;
  esac
}

choose_timeout()
{
  local key_code=1
  timeout -t "$1" keycheck; key_code="$?"  # Timeout return 127 when it cannot execute the binary
  if test "${key_code}" -eq 143; then
    ui_msg 'Key code: No key pressed'
    return 0
  elif test "${key_code}" -eq 127 || test "${key_code}" -eq 132; then
    ui_msg 'WARNING: Key detection failed'
    return 1
  fi

  ui_msg "Key code: ${key_code}"
  check_key "${key_code}"
  return "$?"
}

choose()
{
  local key_code=1
  ui_msg "QUESTION: $1"
  ui_msg "$2"
  ui_msg "$3"
  keycheck; key_code="$?"
  ui_msg "Key code: ${key_code}"
  check_key "${key_code}"
  return "$?"
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
  find "$1" -type d -exec echo 'FOLDER:' '{}' ';' -o -type f -exec echo 'FILE:' '{}' ';' | while read -r x; do echo "${x}"; done
}
