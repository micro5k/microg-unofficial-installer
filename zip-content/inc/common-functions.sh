#!/sbin/sh
# @file common-functions.sh
# @brief A library with common functions used during flashable ZIP installation.

# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# shellcheck disable=SC3043
# SC3043: In POSIX sh, local is undefined

### PREVENTIVE CHECKS ###

if test -z "${RECOVERY_PIPE:-}" || test -z "${OUTFD:-}" || test -z "${ZIPFILE:-}" || test -z "${TMP_PATH:-}" || test -z "${DEBUG_LOG:-}"; then
  echo 'Some variables are NOT set.'
  exit 90
fi

mkdir -p "${TMP_PATH:?}/func-tmp" || ui_error 'Failed to create the functions temp folder'

### FUNCTIONS ###

# Message related functions
_show_text_on_recovery()
{
  if test "${BOOTMODE:?}" = 'true'; then
    printf '%s\n' "${1?}"
    return
  elif test -e "${RECOVERY_PIPE:?}"; then
    printf 'ui_print %s\nui_print\n' "${1?}" >> "${RECOVERY_PIPE:?}"
  else
    printf 'ui_print %s\nui_print\n' "${1?}" 1>&"${OUTFD:?}"
  fi

  if test "${DEBUG_LOG:?}" -ne 0; then printf '%s\n' "${1?}"; fi
}

ui_error()
{
  ERROR_CODE=91
  if test -n "${2:-}"; then ERROR_CODE="${2:?}"; fi
  _show_text_on_recovery "ERROR: ${1:?}"
  1>&2 printf '\033[1;31m%s\033[0m\n' "ERROR ${ERROR_CODE:?}: ${1:?}"
  abort '' 2> /dev/null || exit "${ERROR_CODE:?}"
}

ui_warning()
{
  _show_text_on_recovery "WARNING: ${1:?}"
  1>&2 printf '\033[0;33m%s\033[0m\n' "WARNING: ${1:?}"
}

ui_msg_empty_line()
{
  _show_text_on_recovery ' '
}

ui_msg()
{
  _show_text_on_recovery "${1:?}"
}

ui_msg_sameline_start()
{
  if test -e "${RECOVERY_PIPE}"; then
    printf 'ui_print %s' "${1:?}" >> "${RECOVERY_PIPE:?}"
  else
    printf 'ui_print %s' "${1:?}" 1>&"${OUTFD:?}"
  fi
  if test "${DEBUG_LOG}" -ne 0; then printf '%s\n' "${1:?}"; fi
}

ui_msg_sameline_end()
{
  if test -e "${RECOVERY_PIPE}"; then
    printf '%s\nui_print\n' "${1:?}" >> "${RECOVERY_PIPE:?}"
  else
    printf '%s\nui_print\n' "${1:?}" 1>&"${OUTFD:?}"
  fi
  if test "${DEBUG_LOG}" -ne 0; then printf '%s\n' "${1:?}"; fi
}

ui_debug()
{
  printf '%s\n' "${1?}"
}

# Error checking functions
validate_return_code()
{
  if test "${1}" -ne 0; then ui_error "${2}"; fi
}

validate_return_code_warning()
{
  if test "${1}" -ne 0; then ui_warning "${2}"; fi
}

# Mounting related functions
mount_partition()
{
  local partition
  partition="$(readlink -f "${1:?}")" || {
    partition="${1:?}"
    ui_warning "Failed to canonicalize '${1}'"
  }

  mount "${partition:?}" || ui_warning "Failed to mount '${partition}'"
  return 0 # Never fail
}

mount_partition_silent()
{
  local partition
  partition="$(readlink -f "${1:?}")" || {
    partition="${1:?}"
  }

  mount "${partition:?}" 2> /dev/null || true
  return 0 # Never fail
}

unmount()
{
  local partition
  partition="$(readlink -f "${1:?}")" || {
    partition="${1:?}"
    ui_warning "Failed to canonicalize '${1}'"
  }

  umount "${partition:?}" || ui_warning "Failed to unmount '${partition}'"
  return 0 # Never fail
}

is_mounted()
{
  local _partition _mount_result _silent
  _silent="${2:-false}"
  _partition="$(readlink -f "${1:?}")" || {
    _partition="${1:?}"
    if test "${_silent:?}" = false; then ui_warning "Failed to canonicalize '${1}'"; fi
  }

  { test "${TEST_INSTALL:-false}" = 'false' && test -e '/proc/mounts' && _mount_result="$(cat /proc/mounts)"; } || _mount_result="$(mount 2> /dev/null)" || { test -n "${DEVICE_MOUNT:-}" && _mount_result="$("${DEVICE_MOUNT:?}")"; } || ui_error 'is_mounted has failed'

  case "${_mount_result:?}" in
    *[[:blank:]]"${_partition:?}"[[:blank:]]*) return 0 ;; # Mounted
    *) ;;                                                  # NOT mounted
  esac
  return 1 # NOT mounted
}

_mount_if_needed_silent()
{
  if is_mounted "${1:?}" true; then return 1; fi

  mount_partition_silent "${1:?}"
  is_mounted "${1:?}" true
  return "${?}"
}

UNMOUNT_SYS_EXT=0
UNMOUNT_PRODUCT=0
UNMOUNT_VENDOR=0
mount_extra_partitions_silent()
{
  ! _mount_if_needed_silent '/system_ext'
  UNMOUNT_SYS_EXT="${?}"
  ! _mount_if_needed_silent '/product'
  UNMOUNT_PRODUCT="${?}"
  ! _mount_if_needed_silent '/vendor'
  UNMOUNT_VENDOR="${?}"

  return 0 # Never fail
}

unmount_extra_partitions()
{
  if test "${UNMOUNT_SYS_EXT:?}" = '1'; then
    unmount '/system_ext'
  fi
  if test "${UNMOUNT_PRODUCT:?}" = '1'; then
    unmount '/product'
  fi
  if test "${UNMOUNT_VENDOR:?}" = '1'; then
    unmount '/vendor'
  fi

  return 0 # Never fail
}

ensure_system_is_mounted()
{
  if ! is_mounted '/system'; then
    mount '/system'
    if ! is_mounted '/system'; then ui_error '/system cannot be mounted'; fi
  fi
  return 0 # OK
}

is_mounted_read_write()
{
  mount | grep " $1 " | head -n1 | grep -qi -e "[(\s,]rw[\s,)]"
}

get_mount_status()
{
  local mount_line
  mount_line="$(mount | grep " $1 " | head -n1)"
  if test -z "${mount_line}"; then return 1; fi                             # NOT mounted
  if echo "${mount_line}" | grep -qi -e "[(\s,]rw[\s,)]"; then return 0; fi # Mounted read-write (RW)
  return 2                                                                  # Mounted read-only (RO)
}

remount_read_write()
{
  mount -o remount,rw "$1" "$1"
}

remount_read_only()
{
  mount -o remount,ro "$1" "$1"
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

simple_get_prop()
{
  grep -F "${1}=" "${2}" | head -n1 | cut -d '=' -f 2
}

# String related functions
is_substring()
{
  case "$2" in
    *"$1"*) return 0 ;; # Found
    *) ;;               # NOT found
  esac
  return 1 # NOT found
}

replace_string()
{
  # shellcheck disable=SC3060
  echo "${1//$2/$3}"
}

replace_slash_with_at()
{
  local result
  result="$(echo "$@" | sed -e 's/\//@/g')"
  echo "${result}"
}

replace_line_in_file()
{ # $1 => File to process  $2 => Line to replace  $3 => Replacement text
  rm -f -- "${TMP_PATH:?}/func-tmp/replacement-string.dat"
  echo "${3:?}" > "${TMP_PATH:?}/func-tmp/replacement-string.dat" || ui_error "Failed to replace (1) a line in the file => '${1}'" 92
  sed -i -e "/${2:?}/r ${TMP_PATH:?}/func-tmp/replacement-string.dat" -- "${1:?}" || ui_error "Failed to replace (2) a line in the file => '${1}'" 92
  sed -i -e "/${2:?}/d" -- "${1:?}" || ui_error "Failed to replace (3) a line in the file => '${1}'" 92
  rm -f -- "${TMP_PATH:?}/func-tmp/replacement-string.dat"
}

add_line_in_file_after_string()
{ # $1 => File to process  $2 => String to find  $3 => Text to add
  rm -f -- "${TMP_PATH:?}/func-tmp/replacement-string.dat"
  printf '%s' "${3:?}" > "${TMP_PATH:?}/func-tmp/replacement-string.dat" || ui_error "Failed to replace (1) a line in the file => '${1}'" 92
  sed -i -e "/${2:?}/r ${TMP_PATH:?}/func-tmp/replacement-string.dat" -- "${1:?}" || ui_error "Failed to replace (2) a line in the file => '${1}'" 92
  rm -f -- "${TMP_PATH:?}/func-tmp/replacement-string.dat"
}

replace_line_in_file_with_file()
{ # $1 => File to process  $2 => Line to replace  $3 => File to read for replacement text
  sed -i -e "/${2:?}/r ${3:?}" -- "${1:?}" || ui_error "Failed to replace (1) a line in the file => '$1'" 92
  sed -i -e "/${2:?}/d" -- "${1:?}" || ui_error "Failed to replace (2) a line in the file => '$1'" 92
}

search_string_in_file()
{
  grep -qF "$1" "$2" && return 0 # Found
  return 1                       # NOT found
}

search_ascii_string_in_file()
{
  LC_ALL=C grep -qF "$1" "$2" && return 0 # Found
  return 1                                # NOT found
}

search_ascii_string_as_utf16_in_file()
{
  local SEARCH_STRING
  SEARCH_STRING="$(printf '%s' "${1}" | od -A n -t x1 | LC_ALL=C tr -d '\n' | LC_ALL=C sed -e 's/^ //g;s/ /00/g')"
  od -A n -t x1 "$2" | LC_ALL=C tr -d ' \n' | LC_ALL=C grep -qF "${SEARCH_STRING}" && return 0 # Found
  return 1                                                                                     # NOT found
}

# Permission related functions
set_perm()
{
  local uid="$1"
  local gid="$2"
  local mod="$3"
  shift 3
  # Quote: Previous versions of the chown utility used the dot (.) character to distinguish the group name; this has been changed to be a colon (:) character, so that user and group names may contain the dot character
  chown "${uid}:${gid}" "$@" || chown "${uid}.${gid}" "$@" || ui_error "chown failed on: $*" 81
  chmod "${mod}" "$@" || ui_error "chmod failed on: $*" 81
}

set_std_perm_recursive()
{ # Use it only if you know your version of 'find' handle spaces correctly
  find "$1" -type d -exec chmod 0755 '{}' + -o -type f -exec chmod 0644 '{}' +
  validate_return_code "$?" 'Failed to set permissions recursively'
}

# Extraction related functions
package_extract_file()
{
  local dir
  dir="$(dirname "${2:?}")"
  mkdir -p "${dir:?}" || ui_error "Failed to create the dir '${dir}' for extraction" 94
  set_perm 0 0 0755 "${dir:?}"
  unzip -opq "${ZIPFILE:?}" "${1:?}" 1> "${2:?}" || ui_error "Failed to extract the file '${1}' from this archive" 94
}

custom_package_extract_dir()
{
  mkdir -p "${2:?}" || ui_error "Failed to create the dir '${2}' for extraction" 95
  set_perm 0 0 0755 "${2:?}"
  unzip -oq "${ZIPFILE:?}" "${1:?}/*" -d "${2:?}" || ui_error "Failed to extract the dir '${1}' from this archive" 95
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
  if test -e '/data/data/'; then
    ui_debug 'Resetting GMS data of all apps...'
    find /data/data/*/shared_prefs -name 'com.google.android.gms.*.xml' -delete
    validate_return_code_warning "$?" 'Failed to reset GMS data of all apps'
  fi
}

# Hash related functions
verify_sha1()
{
  if ! test -e "$1"; then
    ui_debug "The file to verify is missing => '$1'"
    return 1 # Failed
  fi
  ui_debug "$1"

  local file_name="$1"
  local hash="$2"
  local file_hash

  file_hash="$(sha1sum "${file_name}" | cut -d ' ' -f 1)"
  if test -z "${file_hash}" || test "${hash}" != "${file_hash}"; then return 1; fi # Failed
  return 0                                                                         # Success
}

# File / folder related functions
create_dir()
{ # Ensure dir exists
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
  create_dir "$2"
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
  rm -f -- "$@" || ui_error "Failed to delete files" 103
}

delete_recursive()
{
  if test -e "$1"; then
    ui_debug "Deleting '$1'..."
    rm -rf -- "$1" || ui_error "Failed to delete files/folders" 104
  fi
}

delete_recursive_wildcard()
{
  for filename in "$@"; do
    if test -e "${filename}"; then
      ui_debug "Deleting '${filename}'...."
      rm -rf -- "${filename:?}" || ui_error "Failed to delete files/folders" 105
    fi
  done
}

delete_dir_if_empty()
{
  if test -d "$1"; then
    ui_debug "Deleting '$1' folder (if empty)..."
    rmdir --ignore-fail-on-non-empty -- "$1" || ui_error "Failed to delete the '$1' folder" 103
  fi
}

file_get_first_line_that_start_with()
{
  grep -m 1 -e "^${1:?}" -- "${2:?}" || return "${?}"
}

string_split()
{
  printf '%s' "${1:?}" | cut -d '|' -sf "${2:?}" || return "${?}"
}

# @description Setup an app for later installation.
# (it automatically handle the API compatibility)
#
# @arg $1 integer Default installation setting (default 0)
# @arg $2 string Vanity name of the app
# @arg $3 string Filename of the app
# @arg $4 string Folder of the app
# @arg $5 boolean Auto-enable URL handling (default false)
# @arg $6 boolean Is the installation of this app optional? (default true)
#
# @exitcode 0 If installed.
# @exitcode 1 If NOT installed.
setup_app()
{
  local _install _app_conf _min_api _max_api _output_name _internal_name _file_hash _url_handling _optional
  if test "${6:-true}" = 'true' && test ! -f "${TMP_PATH}/files/system-apps/${4:?}/${3:?}.apk"; then return 1; fi
  _install="${1:-0}"
  _app_conf="$(file_get_first_line_that_start_with "${4:?}/${3:?}|" "${TMP_PATH}/files/system-apps/file-list.dat")" || ui_error "Failed to get app config for '${2}'"
  _min_api="$(string_split "${_app_conf:?}" 2)" || ui_error "Failed to get min API for '${2}'"
  _max_api="$(string_split "${_app_conf:?}" 3)" || ui_error "Failed to get max API for '${2}'"
  _output_name="$(string_split "${_app_conf:?}" 4)" || ui_error "Failed to get output name for '${2}'"
  _internal_name="$(string_split "${_app_conf:?}" 5)" || ui_error "Failed to get internal name for '${2}'"
  _file_hash="$(string_split "${_app_conf:?}" 6)" || ui_error "Failed to get the hash of '${2}'"
  _url_handling="${5:-false}"
  _optional="${6:-true}"

  if test "${API:?}" -ge "${_min_api:?}" && test "${API:?}" -le "${_max_api:-99}"; then
    if test "${_optional:?}" = 'true' && test "${live_setup_enabled:?}" = 'true'; then
      choose "Do you want to install ${2:?}?" '+) Yes' '-) No'
      if test "${?}" -eq 3; then _install='1'; else _install='0'; fi
    fi

    if test "${_install:?}" -ne 0 || test "${_optional:?}" != 'true'; then
      ui_msg "Enabling: ${2?}"

      ui_msg_sameline_start 'Verifying... '
      ui_debug ''
      verify_sha1 "${TMP_PATH}/files/system-apps/${4:?}/${3:?}.apk" "${_file_hash:?}" || ui_error "Failed hash verification of '${2}'"
      ui_msg_sameline_end 'OK'

      if test "${4:?}" = 'priv-app' && test "${API:?}" -ge 26 && test -f "${TMP_PATH}/files/system-apps/etc/permissions/privapp-permissions-${3:?}.xml"; then
        create_dir "${TMP_PATH}/files/etc/permissions" || ui_error "Failed to create the permissions folder for '${2}'"
        move_rename_file "${TMP_PATH}/files/system-apps/etc/permissions/privapp-permissions-${3:?}.xml" "${TMP_PATH}/files/etc/permissions/privapp-permissions-${_output_name:?}.xml" || ui_error "Failed to setup the priv-app xml of '${2}'"
      fi
      if test "${API:?}" -ge 23 && test -f "${TMP_PATH}/files/system-apps/etc/default-permissions/default-permissions-${3:?}.xml"; then
        create_dir "${TMP_PATH}/files/etc/default-permissions" || ui_error "Failed to create the default permissions folder for '${2}'"
        move_rename_file "${TMP_PATH}/files/system-apps/etc/default-permissions/default-permissions-${3:?}.xml" "${TMP_PATH}/files/etc/default-permissions/default-permissions-${_output_name:?}.xml" || ui_error "Failed to setup the default permissions xml of '${2}'"
      fi
      if test "${_url_handling:?}" != 'false'; then
        add_line_in_file_after_string "${TMP_PATH}/files/etc/sysconfig/google.xml" '<!-- %CUSTOM_APP_LINKS-START% -->' "    <app-link package=\"${_internal_name:?}\" />" || ui_error "Failed to auto-enable URL handling for '${2}'"
      fi
      create_dir "${TMP_PATH}/files/${4:?}" || ui_error "Failed to create the folder for '${2}'"
      move_rename_file "${TMP_PATH}/files/system-apps/${4:?}/${3:?}.apk" "${TMP_PATH}/files/${4:?}/${_output_name:?}.apk" || ui_error "Failed to setup the app => '${2}'"
      return 0
    else
      ui_debug "Disabling: ${2?}"
    fi
  else
    ui_debug "Skipping: ${2?}"
  fi

  return 1
}

list_files()
{ # $1 => Folder to scan  $2 => Prefix to remove
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

append_file_list()
{ # $1 => Folder to scan  $2 => Prefix to remove  $3 => Output filename
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

write_file_list()
{ # $1 => Folder to scan  $2 => Prefix to remove  $3 => Output filename
  delete "$3"
  append_file_list "$@"
}

# Input related functions
_find_hardware_keys()
{
  if ! test -e '/proc/bus/input/devices'; then return 1; fi
  local _last_device_name=''
  while IFS=': ' read -r line_type full_line; do
    if test "${line_type?}" = 'N'; then
      _last_device_name="${full_line:?}"
    elif test "${line_type?}" = 'H' && test "${_last_device_name?}" = 'Name="gpio-keys"'; then
      local _not_found=1
      echo "${full_line:?}" | cut -d '=' -f 2 | while IFS='' read -r my_line; do
        for elem in ${my_line:?}; do
          echo "${elem:?}" | grep -e '^event' && {
            _not_found=0
            break
          }
        done
        return "${_not_found:?}"
      done
      return "${?}"
    fi
  done < '/proc/bus/input/devices'
  return 1
}

_parse_input_event()
{
  if ! test -e "/dev/input/${1:?}"; then return 1; fi
  hexdump -n 14 -d 0< "/dev/input/${1:?}" | while IFS=' ' read -r _ _ _ _ _ _ cur_button key_down _; do
    if test "${key_down:?}" -ne 1; then return 2; fi
    echo "${cur_button:?}" | awk '{$0=int($0)}1' || return 1
    break
  done
}

_timeout_exit_code_remapper()
{
  case "${1:?}" in
    124) # Timed out
      return 124
      ;;
    125) # The timeout command itself fails
      ;;
    126) # COMMAND is found but cannot be invoked
      ;;
    127) # COMMAND cannot be found
      ;;
    132) # SIGILL signal (128+4) - Example: illegal instruction
      ui_warning 'timeout returned SIGILL signal (128+4)'
      return 1
      ;;
    137) # SIGKILL signal (128+9) - Timed out but SIGTERM failed
      ui_warning 'timeout returned SIGKILL signal (128+9)'
      return 1
      ;;
    143) # SIGTERM signal (128+15) - Timed out
      return 124
      ;;
    *)   # All other keys
      if test "${1:?}" -lt 128; then
        return "${1:?}" # Return code of the COMMAND
      fi
      ;;
  esac

  ui_warning "timeout returned: ${1:?}"
  return 1
}

_timeout_compat()
{
  local _timeout_ver _timeout_secs

  _timeout_ver="$(timeout --help 2>&1 | parse_busybox_version)" || _timeout_ver=''
  _timeout_secs="${1:?}" || ui_error 'Missing "secs" parameter for _timeout_compat'
  shift
  if test -z "${_timeout_ver?}" || test "$(numerically_comparable_version "${_timeout_ver:?}" || true)" -ge "$(numerically_comparable_version '1.30.0' || true)"; then
    timeout -- "${_timeout_secs:?}" "${@:?}"
  else
    timeout -t "${_timeout_secs:?}" -- "${@:?}" 2> /dev/null
  fi
  _timeout_exit_code_remapper "${?}"
  return "${?}"
}

_esc_keycode="$(printf '\033')"
_choose_remapper()
{
  local _key
  _key="${1?}" || ui_error 'Missing parameter for _choose_remapper'
  if test -z "${_key?}"; then _key='Enter'; elif test "${_key:?}" = "${_esc_keycode:?}"; then _key='ESC'; fi
  ui_msg_empty_line
  ui_msg "Key press: ${_key:?}"
  ui_msg_empty_line

  case "${_key:?}" in
    '+')   # +
      return 3
      ;;
    '-')   # -
      return 2
      ;;
    'Enter')
      return 0
      ;;
    'ESC') # ESC or other special keys
      ui_error 'Installation forcefully terminated' 143
      ;;
    *)     # All other keys
      return 123
      ;;
  esac
}

_keycheck_map_keycode_to_key()
{
  case "${1:?}" in
    42) # Vol +
      printf '+'
      ;;
    21) # Vol -
      printf '-'
      ;;
    *)
      return 1
      ;;
  esac
}

choose_keycheck_with_timeout()
{
  local _key _status
  _timeout_compat "${1:?}" keycheck
  _status="${?}"

  if test "${_status:?}" = '124'; then
    ui_msg 'Key: No key pressed'
    return 0
  fi
  _key="$(_keycheck_map_keycode_to_key "${_status:?}")" || {
    ui_warning 'Key detection failed'
    return 1
  }

  _choose_remapper "${_key:?}"
  return "${?}"
}

choose_keycheck()
{
  local _key _status
  keycheck
  _status="${?}"

  _key="$(_keycheck_map_keycode_to_key "${_status:?}")" || {
    ui_warning 'Key detection failed'
    return 1
  }

  _choose_remapper "${_key:?}"
  return "${?}"
}

choose_read_with_timeout()
{
  local _key _status
  _status='0'

  # shellcheck disable=SC3045
  IFS='' read -rsn 1 -t "${1:?}" -- _key || _status="${?}"

  case "${_status:?}" in
    0) # Command terminated successfully
      ;;
    1 | 142) # 1 => Command timed out on BusyBox / Toybox; 142 => Command timed out on Bash
      ui_msg 'Key: No key pressed'
      return 0
      ;;
    *)
      ui_warning 'Key detection failed'
      return 1
      ;;
  esac

  _choose_remapper "${_key?}"
  return "${?}"
}

choose_read()
{
  local _key
  # shellcheck disable=SC3045
  IFS='' read -rsn 1 -- _key || {
    ui_warning 'Key detection failed'
    return 1
  }

  clear
  _choose_remapper "${_key?}"
  return "${?}"
}

choose_inputevent()
{
  local _key _hard_keys_event
  _hard_keys_event="$(_find_hardware_keys)" || {
    ui_warning 'Key detection failed'
    return 1
  }
  _key="$(_parse_input_event "${_hard_keys_event:?}")" || {
    ui_warning 'Key detection failed'
    return 1
  }

  ui_msg "Key code: ${_key:?}"
  # 102 Menu
  # 114 Vol -
  # 115 Vol +
  # 116 Power
  #_choose_inputevent_remapper "${_key:?}"
  #return "${?}"
}

choose()
{
  local _last_status=0
  while true; do
    ui_msg "QUESTION: ${1:?}"
    ui_msg "${2:?}"
    ui_msg "${3:?}"
    if "${KEYCHECK_ENABLED:?}"; then
      choose_keycheck "${@}"
    else
      choose_read "${@}"
    fi
    _last_status="${?}"
    if test "${_last_status:?}" -eq 123; then
      ui_msg 'Invalid choice!!!'
    else
      break
    fi
  done
  return "${_last_status:?}"
}

# Other
parse_busybox_version()
{
  head -n1 | grep -oE 'BusyBox v[0-9]+\.[0-9]+\.[0-9]+' | cut -d 'v' -f 2
}

numerically_comparable_version()
{
  echo "${@:?}" | awk -F. '{ printf("%d%03d%03d%03d\n", $1, $2, $3, $4); }'
}

remove_ext()
{
  local str="$1"
  echo "${str%.*}"
}

enable_debug_log()
{
  if test "${DEBUG_LOG_ENABLED}" -eq 1; then return; fi
  DEBUG_LOG_ENABLED=1
  exec 3>&1 4>&2 # Backup stdout and stderr
  exec 1>> "${ZIP_PATH:?}/debug-a5k.log" 2>&1
}

disable_debug_log()
{
  if test "${DEBUG_LOG_ENABLED}" -eq 0; then return; fi
  DEBUG_LOG_ENABLED=0
  exec 1>&3 2>&4 # Restore stdout and stderr
}

# Find test: this is useful to test 'find' - if every file/folder, even the ones with spaces, is displayed in a single line then your version is good
find_test()
{
  find "$1" -type d -exec echo 'FOLDER:' '{}' ';' -o -type f -exec echo 'FILE:' '{}' ';' | while read -r x; do echo "${x}"; done
}
