#!/sbin/sh
# shellcheck disable=SC3043,SC3037

# SC3043: In POSIX sh, local is undefined
# SC3037: In POSIX sh, echo flags are undefined

# SPDX-FileCopyrightText: Copyright (C) 2016-2019, 2021 ale5000
# SPDX-License-Identifer: GPL-3.0-or-later
# SPDX-FileType: SOURCE

### GLOBAL VARIABLES ###

export DEBUG_LOG=0
export RECOVERY_API_VER="$1"
export RECOVERY_PIPE="/proc/self/fd/$2"
export ZIP_FILE="$3"
ZIP_PATH=$(dirname "$ZIP_FILE")
export ZIP_PATH
BASE_TMP_PATH='/tmp'
TMP_PATH='/tmp/custom-setup-a5k'

MANUAL_TMP_MOUNT=0
GENER_ERROR=0
STATUS=1

KEYCHECK_ENABLED=false
export BOOTMODE=false


### FUNCTIONS ###

DEBUG_LOG_ENABLED=0
enable_debug_log()
{
  if [ "$DEBUG_LOG_ENABLED" -eq 1 ]; then return; fi
  exec 3>&1 4>&2  # Backup stdout and stderr
  exec 1>>"$ZIP_PATH/debug-a5k.log" 2>&1
  DEBUG_LOG_ENABLED=1
}

disable_debug_log()
{
  if [ "$DEBUG_LOG_ENABLED" -eq 0 ]; then return; fi
  exec 1>&3 2>&4  # Restore stdout and stderr
  DEBUG_LOG_ENABLED=0
}

_show_text_on_recovery()
{
  echo -e "ui_print $1\nui_print" >> "$RECOVERY_PIPE"
}

ui_error()
{
  ERROR_CODE=79
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
  echo -e "ui_print $1\nui_print" >> "$RECOVERY_PIPE"
  if [ "$DEBUG_LOG" -ne 0 ]; then echo "$1"; fi
}

ui_debug()
{
  echo "$1"
}

is_mounted()
{
  case $(mount) in
    *" $1 "*) return 0;;  # Mounted
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

parse_file()
{
  local tmp
  tmp=$(grep -F "${2}=" "$1" | head -n1 | cut -d '=' -f 2) && echo "$tmp"
  if test -n "$tmp"; then return 0; fi  # Found
  return 1  # NOT found
}

rec_getprop()
{
  local prop=''
  (test -e '/sbin/getprop' && prop=$(/sbin/getprop "ro.$1") && test -n "$prop" && echo "$prop") || (prop=$(parse_file '/default.prop' "ro.$1") && echo "$prop") || (ensure_system_is_mounted && test -e '/system/build.prop' && prop=$(parse_file '/system/build.prop' "ro.$1") && echo "$prop")
}

get_rec_abilist()
{
  local abilist
  abilist=$(rec_getprop 'product.cpu.abilist')
  if test -n "$abilist"; then echo "$abilist"; return 0; fi  # Found

  local abi1
  abi1=$(rec_getprop 'product.cpu.abi')
  local abi2
  abi2=$(rec_getprop 'product.cpu.abi2')
  if test -n "$abi1" || test -n "$abi2"; then echo "$abi1,$abi2"; return 0; fi  # Found

  return 1  # NOT found
}

is_substring()
{
  case "$2" in 
    *"$1"*) return 0;;  # Found
  esac;
  return 1  # NOT found
}

set_perm()
{
  local uid="$1"; local gid="$2"; local mod="$3"
  shift 3
  chown "$uid:$gid" "$@" || chown "$uid.$gid" "$@" || ui_error "chown failed on: $*" 81
  chmod "$mod" "$@" || ui_error "chmod failed on: $*" 81
}

set_perm_safe()
{
  local uid="$1"; local gid="$2"; local mod="$3"
  shift 3
  "$BASE_TMP_PATH/busybox" chown "$uid:$gid" "$@" || "$BASE_TMP_PATH/busybox" chown "$uid.$gid" "$@" || ui_error "chown failed on: $*" 81
  "$BASE_TMP_PATH/busybox" chmod "$mod" "$@" || ui_error "chmod failed on: $*" 81
}

package_extract_file()
{
  unzip -opq "$ZIP_FILE" "$1" > "$2" || ui_error "Failed to extract the file '$1' from this archive" 82
}

package_extract_file_safe()
{
  "$BASE_TMP_PATH/busybox" unzip -opq "$ZIP_FILE" "$1" > "$2" || ui_error "Failed to extract the file '$1' from this archive" 83
}

create_dir()
{
  mkdir -p "$1" || ui_error "Failed to create the dir: $1" 84
  set_perm 0 0 0755 "$1"
}

create_dir_safe()
{
  "$BASE_TMP_PATH/busybox" mkdir -p "$1" || ui_error "Failed to create the dir: $1" 84
  set_perm_safe 0 0 0755 "$1"
}

delete_safe()
{
  "$BASE_TMP_PATH/busybox" rm -f "$@" || ui_error "Failed to delete files" 85
}

delete_recursive_safe()
{
  "$BASE_TMP_PATH/busybox" rm -rf "$@" || ui_error "Failed to delete files/folders" 86
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
  if test "$key_code" -eq 143; then
    ui_msg 'Key code: No key pressed'
    return 0
  elif test "$key_code" -eq 127 || test "$key_code" -eq 132; then
    ui_msg 'WARNING: Key detection failed'
    return 1
  fi

  ui_msg "Key code: $key_code"
  check_key "$key_code"
  return "$?"
}

choose()
{
  local key_code=1
  ui_msg "QUESTION: $1"
  ui_msg "$2"
  ui_msg "$3"
  keycheck; key_code="$?"
  ui_msg "Key code: $key_code"
  check_key "$key_code"
  return "$?"
}


### CODE ###

test "$DEBUG_LOG" -eq 1 && enable_debug_log  # Enable file logging if needed

ui_debug 'PRELOADER'
if ! is_mounted '/tmp'; then
  # Workaround: create and mount /tmp if it isn't already mounted
  MANUAL_TMP_MOUNT=1
  ui_msg 'WARNING: Creating missing /tmp...'
  if [ ! -e '/tmp' ]; then create_dir '/tmp'; fi
  mount -t tmpfs -o rw tmpfs /tmp
  set_perm 0 2000 0775 '/tmp'

  if ! is_mounted '/tmp'; then ui_error '/tmp is NOT mounted'; fi
fi

ABI_LIST=",$(get_rec_abilist)," || ui_error "Empty ABI list"

if is_substring ',x86_64,' "$ABI_LIST"; then
  ui_debug 'Extracting 64-bit x86 BusyBox...'
  package_extract_file 'misc/busybox/busybox-x86_64.bin' "$BASE_TMP_PATH/busybox"
elif is_substring ',x86,' "$ABI_LIST"; then
  ui_debug 'Extracting x86 BusyBox...'
  package_extract_file 'misc/busybox/busybox-x86.bin' "$BASE_TMP_PATH/busybox"
elif is_substring ',arm64-v8a,' "$ABI_LIST"; then
  ui_debug 'Extracting 64-bit ARM BusyBox...'
  package_extract_file 'misc/busybox/busybox-arm64.bin' "$BASE_TMP_PATH/busybox"
  package_extract_file 'misc/keycheck/keycheck-arm' "$BASE_TMP_PATH/keycheck"
elif is_substring ',armeabi,' "$ABI_LIST" || is_substring ',armeabi-v7a,' "$ABI_LIST"; then
  ui_debug 'Extracting ARM BusyBox...'
  package_extract_file 'misc/busybox/busybox-arm.bin' "$BASE_TMP_PATH/busybox"
  package_extract_file 'misc/keycheck/keycheck-arm' "$BASE_TMP_PATH/keycheck"
else
  ui_error "Unsupported CPU, ABI list: ${ABI_LIST}"
fi
# Give execution rights
chmod +x "$BASE_TMP_PATH/busybox" || ui_error "chmod failed on '$BASE_TMP_PATH/busybox'" 81  # Needed to make working the "safe" functions
set_perm_safe 0 0 0755 "$BASE_TMP_PATH/busybox"

# Delete previous traces
delete_recursive_safe "$TMP_PATH"
create_dir_safe "$TMP_PATH"
create_dir_safe "$TMP_PATH/bin"

PREVIOUS_PATH="${PATH}"

# Clean search path so only internal BusyBox applets will be used
export PATH="$TMP_PATH/bin"

# Temporarily setup BusyBox
"$BASE_TMP_PATH/busybox" --install -s "$TMP_PATH/bin"

# Temporarily setup Keycheck
if test -e "$BASE_TMP_PATH/keycheck"; then
  "$BASE_TMP_PATH/busybox" mv -f "$BASE_TMP_PATH/keycheck" "$TMP_PATH/bin/keycheck" || ui_error "Failed to move keycheck to the bin folder"
  # Give execution rights
  set_perm_safe 0 0 0755 "$TMP_PATH/bin/keycheck"
  KEYCHECK_ENABLED=true
fi

# Extract scripts
ui_debug 'Extracting scripts...'
create_dir_safe "$TMP_PATH/inc"
package_extract_file_safe 'inc/common.sh' "$TMP_PATH/inc/common.sh"
package_extract_file_safe 'uninstall.sh' "$TMP_PATH/uninstall.sh"
package_extract_file_safe 'install.sh' "$TMP_PATH/install.sh"
# Give execution rights
set_perm_safe 0 0 0755 "$TMP_PATH/inc/common.sh"
set_perm_safe 0 0 0755 "$TMP_PATH/uninstall.sh"
set_perm_safe 0 0 0755 "$TMP_PATH/install.sh"

package_extract_file_safe 'settings.conf' "$TMP_PATH/default-settings.conf"
# shellcheck source=SCRIPTDIR/../../../../settings.conf
. "$TMP_PATH/default-settings.conf"
test "$DEBUG_LOG" -eq 1 && enable_debug_log  # Enable file logging if needed

# If the debug log was enabled at startup (not in the settings or in the live setup) we cannot allow overriding it from the settings
if [ "$DEBUG_LOG_ENABLED" -eq 1 ]; then export DEBUG_LOG=1; fi

# Detect boot mode
(ps | grep zygote | grep -v grep >/dev/null) && BOOTMODE=true
$BOOTMODE || (ps -A 2>/dev/null | grep zygote | grep -v grep >/dev/null && BOOTMODE=true)

# Live setup
if $KEYCHECK_ENABLED && [ "$LIVE_SETUP" -eq 0 ] && [ "${LIVE_SETUP_TIMEOUT}" -ge 1 ]; then
  ui_msg '---------------------------------------------------'
  ui_msg 'INFO: Select the VOLUME + key to enable live setup.'
  ui_msg "Waiting input for ${LIVE_SETUP_TIMEOUT} seconds..."
  choose_timeout "${LIVE_SETUP_TIMEOUT}"
  if test "$?" -eq 3; then export LIVE_SETUP=1; fi
fi

if [ "$LIVE_SETUP" -eq 1 ]; then
  ui_msg 'LIVE SETUP ENABLED!'
  if [ "$DEBUG_LOG" -eq 0 ]; then
    choose 'Do you want to enable the debug log?' '+) Yes' '-) No'; if [ "$?" -ne 2 ]; then export DEBUG_LOG=1; enable_debug_log; fi
  fi
fi

ui_msg ''
ui_debug 'Starting installation script...'
"$BASE_TMP_PATH/busybox" bash -c "'$TMP_PATH/install.sh' Preloader '$TMP_PATH'"; STATUS="$?"

test -f "$TMP_PATH/installed" || GENER_ERROR=1

export PATH="${PREVIOUS_PATH}"
delete_recursive_safe "$TMP_PATH"

#!!! UNSAFE ENVIRONMENT FROM HERE !!!#

test "$DEBUG_LOG" -eq 1 && disable_debug_log  # Disable debug log and restore normal output

test "$MANUAL_TMP_MOUNT" -ne 0 && unmount_safe '/tmp'

if test "$STATUS" -ne 0; then ui_error "Installation script failed with error $STATUS" "$STATUS"; fi
if test "$GENER_ERROR" -ne 0; then ui_error 'Installation failed with an unknown error'; fi

delete_safe "$BASE_TMP_PATH/busybox"
