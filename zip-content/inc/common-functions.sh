#!/sbin/sh
# @file common-functions.sh
# @brief A library with common functions used during flashable ZIP installation.

# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# shellcheck disable=SC3043
# SC3043: In POSIX sh, local is undefined

### PREVENTIVE CHECKS ###

if test -z "${ZIPFILE:-}" || test -z "${TMP_PATH:-}" || test -z "${RECOVERY_PIPE:-}" || test -z "${OUTFD:-}" || test -z "${INPUT_FROM_TERMINAL:-}" || test -z "${DEBUG_LOG_ENABLED:-}"; then
  echo 'Some variables are NOT set.'
  exit 90
fi

mkdir -p "${TMP_PATH:?}/func-tmp" || ui_error 'Failed to create the functions temp folder'

NL='
'
readonly NL

### FUNCTIONS ###

_canonicalize()
{
  if test ! -e "${1:?}"; then
    printf '%s' "${1:?}"
    return 0
  fi

  local _path
  _path="$(readlink -f "${1:?}")" || _path="$(realpath "${1:?}")" || {
    ui_warning "Failed to canonicalize '${1:-}'"
    _path="${1:?}"
  }
  printf '%s' "${_path:?}"
  return 0
}

_detect_slot()
{
  if test ! -e '/proc/cmdline'; then return 1; fi

  local _slot
  if _slot="$(grep -o -e 'androidboot.slot_suffix=[_[:alpha:]]*' '/proc/cmdline' | cut -d '=' -f 2)" && test -n "${_slot:-}"; then
    printf '%s' "${_slot:?}"
    return 0
  fi

  return 1
}

_mount_helper()
{
  mount "${@}" 2> /dev/null || {
    test -n "${DEVICE_MOUNT:-}" && "${DEVICE_MOUNT:?}" -t 'auto' "${@}"
  } || return "${?}"
  return 0
}

_verify_system_partition()
{
  local _backup_ifs _path
  _backup_ifs="${IFS:-}"
  IFS="${NL:?}"

  for _path in ${1?}; do
    if test -z "${_path:-}"; then continue; fi
    _path="$(_canonicalize "${_path:?}")"

    if test -e "${_path:?}/system/build.prop"; then
      SYS_PATH="${_path:?}/system"
      SYS_MOUNTPOINT="${_path:?}"

      IFS="${_backup_ifs:-}"
      return 0
    fi

    if test -e "${_path:?}/build.prop"; then
      SYS_PATH="${_path:?}"
      if is_mounted "${_path:?}"; then
        SYS_MOUNTPOINT="${_path:?}"
      elif _path="$(_canonicalize "${_path:?}/../")" && is_mounted "${_path:?}"; then
        SYS_MOUNTPOINT="${_path:?}"
      else
        IFS="${_backup_ifs:-}"
        ui_error "Found system path at '${SYS_PATH:-}' but failed to find the mount point"
      fi

      IFS="${_backup_ifs:-}"
      return 0
    fi
  done

  IFS="${_backup_ifs:-}"
  return 1
}

_mount_and_verify_system_partition()
{
  local _backup_ifs _path
  _backup_ifs="${IFS:-}"
  IFS="${NL:?}"

  for _path in ${1?}; do
    if test -z "${_path:-}" || test "${_path:?}" = '/mnt/system'; then continue; fi # Note: '/mnt/system' can only be manually mounted
    _path="$(_canonicalize "${_path:?}")"
    _mount_helper '-o' 'rw' "${_path:?}" || true

    if test -e "${_path:?}/system/build.prop"; then
      SYS_PATH="${_path:?}/system"
      SYS_MOUNTPOINT="${_path:?}"

      IFS="${_backup_ifs:-}"
      ui_debug "Mounted: ${SYS_MOUNTPOINT:-}"
      return 0
    fi

    if test -e "${_path:?}/build.prop"; then
      SYS_PATH="${_path:?}"
      SYS_MOUNTPOINT="${_path:?}"

      IFS="${_backup_ifs:-}"
      ui_debug "Mounted: ${SYS_MOUNTPOINT:-}"
      return 0
    fi
  done

  IFS="${_backup_ifs:-}"
  return 1
}

_get_mount_info()
{
  if test ! -e "${1:?}"; then return 2; fi

  if test "${TEST_INSTALL:-false}" = 'false' && test -e '/proc/mounts'; then
    grep -m 1 -e '[[:blank:]]'"${1:?}"'[[:blank:]]' '/proc/mounts' 2> /dev/null || return 1
    return 0
  fi

  local _mount_result
  if _mount_result="$(mount 2> /dev/null)" || {
    test -n "${DEVICE_MOUNT:-}" && _mount_result="$("${DEVICE_MOUNT:?}")"
  }; then
    if printf '%s' "${_mount_result:?}" | grep -m 1 -e '[[:blank:]]'"${1:?}"'[[:blank:]]'; then return 0; fi
    return 1
  fi

  ui_warning "_get_mount_info has failed"
  return 3
}

mount_partition()
{
  local _path
  _path="$(_canonicalize "${1:?}")"

  _mount_helper '-o' 'rw' "${_path:?}" || ui_warning "Failed to mount '${_path:-}'"
  return 0 # Never fail
}

is_mounted()
{
  if test "${TEST_INSTALL:-false}" = 'false' && command -v mountpoint 1> /dev/null; then
    if mountpoint "${1:?}" 1> /dev/null 2>&1; then return 0; fi # Mounted
    return 1                                                    # NOT mounted
  fi

  if _get_mount_info "${1:?}" 1> /dev/null; then return 0; fi # Mounted
  return 1                                                    # NOT mounted
}

is_mounted_read_only()
{
  local _mount_info
  _mount_info="$(_get_mount_info "${1:?}")" || ui_error "is_mounted_read_only has failed for '${1:-}'"

  if printf '%s' "${_mount_info:?}" | grep -q -e '[(,[:blank:]]ro[[:blank:],)]'; then
    return 0
  fi

  return 1
}

remount_read_write()
{
  if test -n "${DEVICE_MOUNT:-}"; then
    "${DEVICE_MOUNT:?}" -o 'remount,rw' "${1:?}" || "${DEVICE_MOUNT:?}" 2> /dev/null -o 'remount,rw' "${1:?}" "${1:?}" || return 1
  else
    mount -o 'remount,rw' "${1:?}" || return 1
  fi

  if is_mounted_read_only "${1:?}"; then return 1; fi

  return 0
}

_upperize()
{
  printf '%s' "${1:?}" | LC_ALL=C tr '[:lower:]' '[:upper:]' || ui_error "_upperize has failed for '${1:-}'"
}

_find_block()
{
  local _backup_ifs _uevent _block
  _backup_ifs="${IFS:-}"
  IFS=''

  for _uevent in /sys/dev/block/*/uevent; do
    if grep -q -i -F -e "PARTNAME=${1:?}" "${_uevent:?}"; then
      if _block="$(grep -m 1 -o -e 'DEVNAME=.*' "${_uevent:?}" | cut -d '=' -f 2)"; then
        if test -e "/dev/block/${_block:?}"; then
          IFS="${_backup_ifs:-}"
          _canonicalize "/dev/block/${_block:?}"
          return 0
        fi
      fi
    fi
  done

  IFS="${_backup_ifs:-}"
  return 1
}

_manual_partition_mount()
{
  local _backup_ifs _path _block _found
  unset LAST_MOUNTPOINT
  _backup_ifs="${IFS:-}"
  IFS="${NL:?}"

  _found='false'
  if test -e '/dev/block/mapper'; then
    for _path in ${1?}; do
      if test -e "/dev/block/mapper/${_path:?}"; then
        _block="$(_canonicalize "/dev/block/mapper/${_path:?}")"
        ui_msg "Found 'mapper/${_path:-}' block at: ${_block:-}"
        _found='true'
        break
      fi
    done
  fi

  if test "${_found:?}" = 'false' && test -e '/sys/dev/block'; then
    for _path in ${1?}; do
      if _block="$(_find_block "${_path:?}")"; then
        ui_msg "Found '${_path:-}' block at: ${_block:-}"
        _found='true'
        break
      fi
    done
  fi

  if test "${_found:?}" != 'false'; then
    for _path in ${2?}; do
      if test -z "${_path:-}"; then continue; fi
      _path="$(_canonicalize "${_path:?}")"

      umount "${_path:?}" 2> /dev/null || true
      if _mount_helper '-o' 'rw' "${_block:?}" "${_path:?}"; then
        IFS="${_backup_ifs:-}"
        LAST_MOUNTPOINT="${_path:?}"
        ui_debug "Mounted: ${_path:-}"
        return 0
      fi
    done
  fi

  IFS="${_backup_ifs:-}"
  return 1
}

_find_and_mount_system()
{
  local _sys_mountpoint_list='' # This is a list of paths separated by newlines

  if test "${TEST_INSTALL:-false}" != 'false' && test -n "${ANDROID_ROOT:-}" && test -e "${ANDROID_ROOT:?}"; then
    _sys_mountpoint_list="${ANDROID_ROOT:?}${NL:?}"
  else
    if test -e '/mnt/system'; then
      _sys_mountpoint_list="${_sys_mountpoint_list?}/mnt/system${NL:?}"
    fi
    if test -n "${ANDROID_ROOT:-}" &&
      test "${ANDROID_ROOT:?}" != '/system_root' &&
      test "${ANDROID_ROOT:?}" != '/system' &&
      test -e "${ANDROID_ROOT:?}"; then
      _sys_mountpoint_list="${_sys_mountpoint_list?}${ANDROID_ROOT:?}${NL:?}"
    fi
    if test -e '/system_root'; then
      _sys_mountpoint_list="${_sys_mountpoint_list?}/system_root${NL:?}"
    fi
    if test "${RECOVERY_FAKE_SYSTEM:?}" = 'false' && test -e '/system'; then
      _sys_mountpoint_list="${_sys_mountpoint_list?}/system${NL:?}"
    fi
  fi
  ui_debug 'System mountpoint list:'
  ui_debug "${_sys_mountpoint_list:-}"

  if _verify_system_partition "${_sys_mountpoint_list?}"; then
    : # Found
  else
    SYS_INIT_STATUS=1
    ui_debug "Mounting system..."

    if _mount_and_verify_system_partition "${_sys_mountpoint_list?}"; then
      : # Mounted and found
    elif _manual_partition_mount "system${SLOT:-}${NL:?}system${NL:?}FACTORYFS${NL:?}" "${_sys_mountpoint_list?}" && _verify_system_partition "${_sys_mountpoint_list?}"; then
      : # Mounted and found
    else
      deinitialize

      ui_msg_empty_line
      ui_msg "Verity mode: ${VERITY_MODE:-disabled}"
      ui_msg "Dynamic partitions: ${DYNAMIC_PARTITIONS:?}"
      ui_msg "Current slot: ${SLOT:-no slot}"
      ui_msg "Recov. fake system: ${RECOVERY_FAKE_SYSTEM:?}"
      ui_msg_empty_line
      ui_msg "Android root ENV: ${ANDROID_ROOT:-}"
      ui_msg_empty_line

      ui_error "The ROM cannot be found!"
    fi
  fi

  readonly SYS_MOUNTPOINT SYS_PATH
}

_get_local_settings()
{
  if test "${LOCAL_SETTINGS_READ:-false}" = 'true'; then return; fi

  LOCAL_SETTINGS=''
  if test -n "${DEVICE_GETPROP?}"; then
    ui_debug 'Parsing local settings...'
    LOCAL_SETTINGS="$("${DEVICE_GETPROP:?}" | grep -e "^\[zip\.${MODULE_ID:?}\.")" || LOCAL_SETTINGS=''
  elif command -v getprop 1> /dev/null; then
    ui_debug 'Parsing local settings (2)...'
    LOCAL_SETTINGS="$(getprop | grep -e "^\[zip\.${MODULE_ID:?}\.")" || LOCAL_SETTINGS=''
  fi
  LOCAL_SETTINGS_READ='true'

  readonly LOCAL_SETTINGS LOCAL_SETTINGS_READ
  export LOCAL_SETTINGS LOCAL_SETTINGS_READ
}

parse_setting()
{
  local _var

  _get_local_settings

  _var="$(printf '%s\n' "${LOCAL_SETTINGS?}" | grep -m 1 -F -e "[zip.${MODULE_ID:?}.${1:?}]" | cut -d ':' -f '2-' -s)" || _var=''
  _var="${_var# }"
  if test "${#_var}" -gt 2; then
    printf '%s\n' "${_var?}" | cut -c "2-$((${#_var} - 1))"
    return
  fi

  # Fallback to the default value
  printf '%s\n' "${2?}"
}

remount_read_write_if_needed()
{
  local _mountpoint _required
  _mountpoint="$(_canonicalize "${1:?}")"
  _required="${2:-true}"

  if is_mounted "${_mountpoint:?}" && is_mounted_read_only "${_mountpoint:?}"; then
    ui_msg "INFO: The '${_mountpoint:-}' mount point is read-only, it will be remounted"
    ui_msg_empty_line
    remount_read_write "${_mountpoint:?}" || {
      if test "${_required:?}" = 'true'; then
        ui_error "Remounting of '${_mountpoint:-}' failed"
      else
        ui_warning "Remounting of '${_mountpoint:-}' failed"
        ui_msg_empty_line
        return 1
      fi
    }
  fi
}

initialize()
{
  SYS_INIT_STATUS=0
  DATA_INIT_STATUS=0

  # Make sure that the commands are still overridden here (most shells don't have the ability to export functions)
  if test "${TEST_INSTALL:-false}" != 'false' && test -f "${RS_OVERRIDE_SCRIPT:?}"; then
    # shellcheck source=SCRIPTDIR/../../recovery-simulator/inc/configure-overrides.sh
    . "${RS_OVERRIDE_SCRIPT:?}" || exit "${?}"
  fi

  package_extract_file 'module.prop' "${TMP_PATH:?}/module.prop"
  MODULE_ID="$(simple_file_getprop 'id' "${TMP_PATH:?}/module.prop")" || ui_error 'Failed to parse id'
  readonly MODULE_ID
  export MODULE_ID

  _get_local_settings

  if test "${INPUT_FROM_TERMINAL:?}" = 'true' && test "${LIVE_SETUP_TIMEOUT:?}" -gt 0; then LIVE_SETUP_TIMEOUT="$((LIVE_SETUP_TIMEOUT + 3))"; fi
  LIVE_SETUP_DEFAULT="$(parse_setting 'LIVE_SETUP_DEFAULT' "${LIVE_SETUP_DEFAULT:?}")"
  LIVE_SETUP_TIMEOUT="$(parse_setting 'LIVE_SETUP_TIMEOUT' "${LIVE_SETUP_TIMEOUT:?}")"

  ui_debug ''

  # Some recoveries have a fake system folder when nothing is mounted with just bin, etc and lib / lib64.
  # Usable binaries are under the fake /system/bin so the /system mountpoint mustn't be used while in this recovery.
  if test "${BOOTMODE:?}" != 'true' &&
    test -e '/system/bin/sh' &&
    test ! -e '/system/build.prop' &&
    test ! -e '/system/system/build.prop'; then
    readonly RECOVERY_FAKE_SYSTEM='true'
  else
    readonly RECOVERY_FAKE_SYSTEM='false'
  fi
  export RECOVERY_FAKE_SYSTEM

  if test -e '/dev/block/mapper'; then readonly DYNAMIC_PARTITIONS='true'; else readonly DYNAMIC_PARTITIONS='false'; fi
  export DYNAMIC_PARTITIONS

  SLOT="$(_detect_slot)" || SLOT=''
  readonly SLOT
  export SLOT

  VERITY_MODE="$(simple_getprop 'ro.boot.veritymode')" || VERITY_MODE=''
  readonly VERITY_MODE
  export VERITY_MODE

  _find_and_mount_system
  cp -pf "${SYS_PATH:?}/build.prop" "${TMP_PATH:?}/build.prop" # Cache the file for faster access

  if BUILD_MANUFACTURER="$(simple_getprop 'ro.product.manufacturer')" && is_valid_prop "${BUILD_MANUFACTURER?}"; then
    :
  else
    BUILD_MANUFACTURER=''
  fi
  readonly BUILD_MANUFACTURER
  export BUILD_MANUFACTURER

  if BUILD_DEVICE="$(simple_getprop 'ro.product.device')" && is_valid_prop "${BUILD_DEVICE?}"; then
    :
  elif BUILD_DEVICE="$(simple_getprop 'ro.build.product')" && is_valid_prop "${BUILD_DEVICE?}"; then
    :
  elif BUILD_DEVICE="$(simple_file_getprop 'ro.product.device' "${TMP_PATH:?}/build.prop")" && is_valid_prop "${BUILD_DEVICE?}"; then
    :
  else
    BUILD_DEVICE=''
  fi
  readonly BUILD_DEVICE
  export BUILD_DEVICE

  if test "${BUILD_MANUFACTURER?}" = 'OnePlus' && test "${BUILD_DEVICE?}" = 'OnePlus6'; then
    export KEYCHECK_ENABLED='false' # It doesn't work properly on this device
  fi

  _timeout_check
  live_setup_choice

  IS_EMU='false'
  case "${BUILD_DEVICE?}" in
    'windows_x86_64' | 'emu64x')
      IS_EMU='true'
      ;;
    *)
      if is_valid_prop "$(simple_getprop 'ro.leapdroid.version' || true)"; then IS_EMU='true'; fi
      ;;
  esac
  readonly IS_EMU
  export IS_EMU

  MODULE_NAME="$(simple_file_getprop 'name' "${TMP_PATH:?}/module.prop")" || ui_error 'Failed to parse name'
  MODULE_VERSION="$(simple_file_getprop 'version' "${TMP_PATH:?}/module.prop")" || ui_error 'Failed to parse version'
  MODULE_VERCODE="$(simple_file_getprop 'versionCode' "${TMP_PATH:?}/module.prop")" || ui_error 'Failed to parse version code'
  MODULE_AUTHOR="$(simple_file_getprop 'author' "${TMP_PATH:?}/module.prop")" || ui_error 'Failed to parse author'
  readonly MODULE_NAME MODULE_VERSION MODULE_VERCODE MODULE_AUTHOR
  export MODULE_NAME MODULE_VERSION MODULE_VERCODE MODULE_AUTHOR

  # Previously installed module version code (0 if wasn't installed)
  PREV_MODULE_VERCODE="$(simple_file_getprop 'install.version.code' "${SYS_PATH:?}/etc/zips/${MODULE_ID:?}.prop")" || PREV_MODULE_VERCODE=''
  case "${PREV_MODULE_VERCODE:-}" in
    '' | *[!0-9]*) PREV_MODULE_VERCODE='0' ;; # Not installed (empty) or invalid data
    *) ;;                                     # OK
  esac
  readonly PREV_MODULE_VERCODE
  export PREV_MODULE_VERCODE

  IS_INSTALLATION='true'
  if test "${LIVE_SETUP_ENABLED:?}" = 'true' && test "${PREV_MODULE_VERCODE:?}" -ge 3; then
    choose 'What do you want to do?' '+) Update / reinstall' '-) Uninstall'
    if test "${?}" != '3'; then
      IS_INSTALLATION='false'
    fi
  fi
  readonly IS_INSTALLATION
  export IS_INSTALLATION

  if is_mounted_read_only "${SYS_MOUNTPOINT:?}"; then
    ui_msg "INFO: The '${SYS_MOUNTPOINT:-}' mount point is read-only, it will be remounted"
    ui_msg_empty_line
    remount_read_write "${SYS_MOUNTPOINT:?}" || {
      deinitialize

      ui_msg_empty_line
      ui_msg "Device: ${BUILD_DEVICE?}"
      ui_msg_empty_line
      ui_msg "Verity mode: ${VERITY_MODE:-disabled}"
      ui_msg "Dynamic partitions: ${DYNAMIC_PARTITIONS:?}"
      ui_msg "Current slot: ${SLOT:-no slot}"
      ui_msg "Recov. fake system: ${RECOVERY_FAKE_SYSTEM:?}"
      ui_msg_empty_line
      ui_msg "Android root ENV: ${ANDROID_ROOT:-}"
      ui_msg_empty_line

      if test "${VERITY_MODE?}" = 'enforcing'; then
        ui_error "Remounting of '${SYS_MOUNTPOINT:-}' failed, you should DISABLE dm-verity!!!"
      else
        ui_error "Remounting of '${SYS_MOUNTPOINT:-}' failed!!!"
      fi
    }
  fi

  if test ! -w "${SYS_PATH:?}"; then
    ui_error "The '${SYS_PATH:-}' partition is NOT writable"
  fi

  if test "${ANDROID_DATA:-}" = '/data'; then ANDROID_DATA=''; fi # Avoid double checks

  DATA_PATH="$(_canonicalize "${ANDROID_DATA:-/data}")"
  if test ! -e "${DATA_PATH:?}/data" && ! is_mounted "${DATA_PATH:?}"; then
    ui_debug "Mounting data..."
    unset LAST_MOUNTPOINT
    _mount_helper '-o' 'rw' "${DATA_PATH:?}" || _manual_partition_mount "userdata${NL:?}DATAFS${NL:?}" "${ANDROID_DATA:-}${NL:?}/data${NL:?}" || true
    if test -n "${LAST_MOUNTPOINT:-}"; then DATA_PATH="${LAST_MOUNTPOINT:?}"; fi

    if is_mounted "${DATA_PATH:?}"; then
      DATA_INIT_STATUS=1
      ui_debug "Mounted: ${DATA_PATH:-}"
    else
      ui_warning "The data partition cannot be mounted, so updates of installed / removed apps cannot be deleted and their Dalvik cache cannot be cleaned, but it doesn't matter if you do a factory reset"
    fi
  fi
  readonly DATA_PATH

  mount_extra_partitions_silent
  if test -e '/product'; then remount_read_write_if_needed '/product' false; fi
  if test -e '/vendor'; then remount_read_write_if_needed '/vendor' false; fi
  if test -e '/system_ext'; then remount_read_write_if_needed '/system_ext' false; fi

  unset LAST_MOUNTPOINT
}

deinitialize()
{
  if test "${SYS_INIT_STATUS:?}" = '1' && test -n "${SYS_MOUNTPOINT:-}"; then unmount "${SYS_MOUNTPOINT:?}"; fi
  if test "${DATA_INIT_STATUS:?}" = '1' && test -n "${DATA_PATH:-}"; then unmount "${DATA_PATH:?}"; fi
}

# Message related functions
_show_text_on_recovery()
{
  if test "${RECOVERY_OUTPUT:?}" != 'true'; then return; fi # Nothing to do here

  if test -e "${RECOVERY_PIPE:?}"; then
    printf 'ui_print %s\nui_print\n' "${1?}" >> "${RECOVERY_PIPE:?}"
  else
    printf 'ui_print %s\nui_print\n' "${1?}" 1>&"${OUTFD:?}"
  fi

  if test "${DEBUG_LOG_ENABLED:?}" -eq 1; then printf 1>&2 '%s\n' "${1?}"; fi
}

ui_error()
{
  ERROR_CODE=91
  if test -n "${2:-}"; then ERROR_CODE="${2:?}"; fi

  if test "${RECOVERY_OUTPUT:?}" = 'true'; then
    _show_text_on_recovery "ERROR ${ERROR_CODE:?}: ${1:?}"
  else
    printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR ${ERROR_CODE:?}: ${1:?}"
  fi

  exit "${ERROR_CODE:?}"
}

ui_warning()
{
  if test "${RECOVERY_OUTPUT:?}" = 'true'; then
    _show_text_on_recovery "WARNING: ${1:?}"
  else
    printf 1>&2 '\033[0;33m%s\033[0m\n' "WARNING: ${1:?}"
  fi
}

ui_msg_empty_line()
{
  if test "${RECOVERY_OUTPUT:?}" = 'true'; then
    _show_text_on_recovery ' '
  else
    printf '\n'
  fi
}

ui_msg()
{
  if test "${RECOVERY_OUTPUT:?}" = 'true'; then
    _show_text_on_recovery "${1:?}"
  else
    printf '%s\n' "${1:?}"
  fi
}

ui_msg_sameline_start()
{
  if test "${RECOVERY_OUTPUT:?}" = 'false'; then
    printf '%s ' "${1:?}"
    return
  elif test -e "${RECOVERY_PIPE:?}"; then
    printf 'ui_print %s' "${1:?}" >> "${RECOVERY_PIPE:?}"
  else
    printf 'ui_print %s' "${1:?}" 1>&"${OUTFD:?}"
  fi

  if test "${DEBUG_LOG_ENABLED:?}" -eq 1; then printf 1>&2 '%s\n' "${1:?}"; fi
}

ui_msg_sameline_end()
{
  if test "${RECOVERY_OUTPUT:?}" = 'false'; then
    printf '%s\n' "${1:?}"
    return
  elif test -e "${RECOVERY_PIPE:?}"; then
    printf '%s\nui_print\n' "${1:?}" >> "${RECOVERY_PIPE:?}"
  else
    printf '%s\nui_print\n' "${1:?}" 1>&"${OUTFD:?}"
  fi

  if test "${DEBUG_LOG_ENABLED:?}" -eq 1; then printf 1>&2 '%s\n' "${1:?}"; fi
}

ui_debug()
{
  printf 1>&2 '%s\n' "${1?}"
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
mount_partition_silent()
{
  local partition
  partition="$(_canonicalize "${1:?}")"

  mount -o 'rw' "${partition:?}" 2> /dev/null || true
  return 0 # Never fail
}

unmount()
{
  local partition
  partition="$(_canonicalize "${1:?}")"

  umount "${partition:?}" || ui_warning "Failed to unmount '${partition}'"
  return 0 # Never fail
}

_mount_if_needed_silent()
{
  if is_mounted "${1:?}"; then return 1; fi

  mount_partition_silent "${1:?}"
  is_mounted "${1:?}"
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

# Getprop related functions
build_getprop()
{
  grep "^ro\.$1=" "${TMP_PATH}/build.prop" | head -n1 | cut -d '=' -f 2
}

simple_getprop()
{
  if test -n "${DEVICE_GETPROP?}"; then
    "${DEVICE_GETPROP:?}" "${1:?}" || return "${?}"
  elif command -v getprop 1> /dev/null; then
    getprop "${1:?}" || return "${?}"
  else
    return 1
  fi
}

simple_file_getprop()
{
  if test ! -e "${2:?}"; then return 1; fi
  grep -m 1 -F -e "${1:?}=" -- "${2:?}" | cut -d '=' -f '2-' -s
}

is_valid_prop()
{
  if test -z "${1?}" || test "${1?}" = 'unknown'; then return 1; fi
  return 0 # Valid
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

replace_string_global()
{
  printf '%s' "${1:?}" | sed -e "s@${2:?}@${3:?}@g" || return "${?}" # Note: pattern and replacement cannot contain @
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
  test -e "${1:?}" || ui_error "Missing archive for extraction: '${1:?}'" 96
  mkdir -p "$3" || ui_error "Failed to create the dir '$3' for extraction" 96
  set_perm 0 0 0755 "$3"
  unzip -oq "$1" "$2" -d "$3" || ui_error "Failed to extract the file '$2' from the archive '$1'" 96
}

zip_extract_dir()
{
  test -e "${1:?}" || ui_error "Missing archive for extraction: '${1:?}'" 96
  mkdir -p "$3" || ui_error "Failed to create the dir '$3' for extraction" 96
  set_perm 0 0 0755 "$3"
  unzip -oq "$1" "$2/*" -d "$3" || ui_error "Failed to extract the dir '$2' from the archive '$1'" 96
}

# Data reset functions
reset_gms_data_of_all_apps()
{
  if test -e "${DATA_PATH:?}/data"; then
    ui_debug 'Resetting GMS data of all apps...'
    find "${DATA_PATH:?}"/data/*/shared_prefs -name 'com.google.android.gms.*.xml' -delete
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
  for filename in "${@}"; do
    if test -e "${filename?}"; then
      ui_debug "Deleting '${filename?}'...."
      rm -rf -- "${filename:?}" || ui_error 'Failed to delete files/folders' 103
    fi
  done
}

delete_recursive()
{
  for filename in "${@}"; do
    if test -e "${filename?}"; then
      ui_debug "Deleting '${filename?}'...."
      rm -rf -- "${filename:?}" || ui_error 'Failed to delete files/folders' 103
    fi
  done
}

delete_recursive_wildcard()
{
  for filename in "${@}"; do
    if test -e "${filename?}"; then
      ui_debug "Deleting '${filename?}'...."
      rm -rf -- "${filename:?}" || ui_error 'Failed to delete files/folders' 103
    fi
  done
}

delete_dir_if_empty()
{
  if test -d "$1"; then
    ui_debug "Deleting '$1' folder (if empty)..."
    rmdir --ignore-fail-on-non-empty -- "$1" || ui_error "Failed to delete the '$1' folder" 104
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
  if test "${6:-true}" = 'true' && test ! -f "${TMP_PATH}/origin/${4:?}/${3:?}.apk"; then return 1; fi
  _install="${1:-0}"
  _app_conf="$(file_get_first_line_that_start_with "${4:?}/${3:?}|" "${TMP_PATH}/origin/file-list.dat")" || ui_error "Failed to get app config for '${2}'"
  _min_api="$(string_split "${_app_conf:?}" 2)" || ui_error "Failed to get min API for '${2}'"
  _max_api="$(string_split "${_app_conf:?}" 3)" || ui_error "Failed to get max API for '${2}'"
  _output_name="$(string_split "${_app_conf:?}" 4)" || ui_error "Failed to get output name for '${2}'"
  _internal_name="$(string_split "${_app_conf:?}" 5)" || ui_error "Failed to get internal name for '${2}'"
  _file_hash="$(string_split "${_app_conf:?}" 6)" || ui_error "Failed to get the hash of '${2}'"
  _url_handling="${5:-false}"
  _optional="${6:-true}"

  if test "${API:?}" -ge "${_min_api:?}" && test "${API:?}" -le "${_max_api:-99}"; then
    if test "${_optional:?}" = 'true' && test "${LIVE_SETUP_ENABLED:?}" = 'true'; then
      choose "Do you want to install ${2:?}?" '+) Yes' '-) No'
      if test "${?}" -eq 3; then _install='1'; else _install='0'; fi
    fi

    if test "${_install:?}" -ne 0 || test "${_optional:?}" != 'true'; then
      ui_msg "Enabling: ${2?}"

      ui_msg_sameline_start 'Verifying... '
      ui_debug ''
      verify_sha1 "${TMP_PATH}/origin/${4:?}/${3:?}.apk" "${_file_hash:?}" || ui_error "Failed hash verification of '${2}'"
      ui_msg_sameline_end 'OK'

      if test "${4:?}" = 'priv-app' && test "${API:?}" -ge 26 && test -f "${TMP_PATH}/origin/etc/permissions/privapp-permissions-${3:?}.xml"; then
        create_dir "${TMP_PATH}/files/etc/permissions" || ui_error "Failed to create the permissions folder for '${2}'"
        move_rename_file "${TMP_PATH}/origin/etc/permissions/privapp-permissions-${3:?}.xml" "${TMP_PATH}/files/etc/permissions/privapp-permissions-${_output_name:?}.xml" || ui_error "Failed to setup the priv-app xml of '${2}'"
      fi
      if test "${API:?}" -ge 23 && test -f "${TMP_PATH}/origin/etc/default-permissions/default-permissions-${3:?}.xml"; then
        create_dir "${TMP_PATH}/files/etc/default-permissions" || ui_error "Failed to create the default permissions folder for '${2}'"
        move_rename_file "${TMP_PATH}/origin/etc/default-permissions/default-permissions-${3:?}.xml" "${TMP_PATH}/files/etc/default-permissions/default-permissions-${_output_name:?}.xml" || ui_error "Failed to setup the default permissions xml of '${2}'"
      fi
      if test "${_url_handling:?}" != 'false'; then
        add_line_in_file_after_string "${TMP_PATH}/files/etc/sysconfig/google.xml" '<!-- %CUSTOM_APP_LINKS-START% -->' "    <app-link package=\"${_internal_name:?}\" />" || ui_error "Failed to auto-enable URL handling for '${2}'"
      fi
      create_dir "${TMP_PATH}/files/${4:?}" || ui_error "Failed to create the folder for '${2}'"
      move_rename_file "${TMP_PATH}/origin/${4:?}/${3:?}.apk" "${TMP_PATH}/files/${4:?}/${_output_name:?}.apk" || ui_error "Failed to setup the app => '${2}'"
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
_find_input_device()
{
  local _last_device_name=''

  if test ! -e '/proc/bus/input/devices'; then return 1; fi # NOT found

  # shellcheck disable=SC2002
  cat '/proc/bus/input/devices' | while IFS=': ' read -r line_type full_line; do
    if test "${line_type?}" = 'N'; then
      _last_device_name="${full_line?}"
    elif test "${line_type?}" = 'H' && test "${_last_device_name?}" = "Name=\"${1:?}\""; then

      local _found=0
      printf '%s' "${full_line?}" | cut -d '=' -f 2 | while IFS='' read -r my_line; do
        IFS=' '
        for elem in ${my_line:?}; do
          printf '%s' "${elem:?}" | grep -e '^event' && {
            _found=4
            break
          }
        done
        return "${_found:?}"
      done
      return "${?}"

    fi
  done
  if test "${?}" -eq 4; then return 0; fi # Found
  return 1                                # NOT found
}

_find_hardware_keys()
{
  if test "${1:?}" = "${INPUT_DEVICE_NAME:-}" && test -n "${INPUT_DEVICE_PATH:-}"; then return 0; fi

  INPUT_DEVICE_PATH=''
  INPUT_DEVICE_NAME="${1:?}"

  local _input_device_event
  if _input_device_event="$(_find_input_device "${INPUT_DEVICE_NAME:?}")" && test -r "/dev/input/${_input_device_event:?}"; then
    INPUT_DEVICE_PATH="/dev/input/${_input_device_event:?}"
    if test "${DEBUG_LOG_ENABLED:?}" -eq 1 || test "${RECOVERY_OUTPUT:?}" = 'true'; then ui_debug "Found ${INPUT_DEVICE_NAME:-} device at: ${INPUT_DEVICE_PATH:-}"; fi

    # Set the default values, useful when the parsing fails
    INPUT_CODE_VOLUME_UP='115'
    INPUT_CODE_VOLUME_DOWN='114'
    INPUT_CODE_POWER='116'
    #INPUT_CODE_HOME='102'

    if test -e "${SYS_PATH:?}/usr/keylayout/${INPUT_DEVICE_NAME:?}.kl"; then
      while IFS=' ' read -r key_type key_code key_name _; do
        if test "${key_type:-}" != 'key'; then continue; fi

        if test -z "${key_name:-}" || test -z "${key_code:-}"; then
          ui_warning "Missing key code, debug info: '${key_type:-}' '${key_code:-}' '${key_name:-}'"
          continue
        fi

        case "${key_name:?}" in
          'VOLUME_UP') INPUT_CODE_VOLUME_UP="${key_code:?}" ;;
          'VOLUME_DOWN') INPUT_CODE_VOLUME_DOWN="${key_code:?}" ;;
          'POWER') INPUT_CODE_POWER="${key_code:?}" ;;
          'HOME') ;; #INPUT_CODE_HOME="${key_code:?}" ;;
          *) ui_debug "Unknown key: ${key_name:-}" ;;
        esac
      done 0< "${SYS_PATH:?}/usr/keylayout/${INPUT_DEVICE_NAME:?}.kl" || ui_warning "Failed parsing '${SYS_PATH:-}/usr/keylayout/${INPUT_DEVICE_NAME:-}.kl'"
    else
      ui_debug "Missing keylayout: '${SYS_PATH:-}/usr/keylayout/${INPUT_DEVICE_NAME:-}.kl'"
    fi

    return 0
  fi

  return 2
}

kill_pid_from_file()
{
  local _pid

  if test -e "${1:?}" && _pid="$(cat "${1:?}")" && test -n "${_pid?}"; then
    if test "${DEBUG_LOG_ENABLED:?}" -eq 1 || test "${RECOVERY_OUTPUT:?}" = 'true'; then ui_debug "Killing: ${_pid:-}"; fi
    kill -s 'KILL' "${_pid:?}" || true
  fi

  delete "${1:?}"
}

_get_input_event()
{
  local _var _status

  INPUT_EVENT_CURRENT=''

  _status=0
  if test -n "${1:-}"; then
    _var="$({
      cat -u "${INPUT_DEVICE_PATH:?}" &
      printf '%s' "${!}" > "${TMP_PATH:?}/pid-to-kill.dat"
    } | _timeout_compat "${1:?}" hexdump -d -n 32)" || _status="${?}"
  else
    _var="$({
      cat "${INPUT_DEVICE_PATH:?}" &
      printf '%s' "${!}" > "${TMP_PATH:?}/pid-to-kill.dat"
    } | hexdump -d -n 32)" || _status="${?}"
  fi
  kill_pid_from_file "${TMP_PATH:?}/pid-to-kill.dat"

  case "${_status:?}" in
    0) ;;                       # OK
    124) return 124 ;;          # Timed out
    *) return "${_status:?}" ;; # Failure
  esac
  if test -z "${_var?}"; then return 1; fi

  INPUT_EVENT_CURRENT="${_var?}"
  return 0
}

_parse_input_event()
{
  printf "%s\n" "${1?}" | while IFS=' ' read -r _ _ _ _ _ _ cur_button key_down _; do
    if test -z "${cur_button?}" || test "${cur_button:?}" -eq 0; then continue; fi
    if test "${key_down:-9}" -ne 0 && test "${key_down:-9}" -ne 1; then return 125; fi

    printf '%.0f' "${cur_button:?}" || return 125

    if test "${key_down:?}" -eq 1; then
      return 3
    else
      return 4
    fi
  done || return "${?}"

  return 127
}

_timeout_exit_code_remapper()
{
  case "${1:?}" in
    124) # Timed out
      return 124
      ;;
    125) # The timeout command itself fails
      ;;
    126) # COMMAND is found but cannot be invoked (126) - Example: missing execute permission
      ;;
    127) # COMMAND cannot be found (127) - Note: this return value may even be used when timeout is unable to execute the COMMAND
      ui_msg_empty_line
      ui_warning 'timeout returned cmd NOT found (127)'
      return 127
      ;;
    132) # SIGILL signal (128+4) - Example: illegal instruction
      ui_msg_empty_line
      ui_warning 'timeout returned SIGILL (128+4)'
      return 132
      ;;
    137) # SIGKILL signal (128+9) - Timed out but SIGTERM failed
      ui_msg_empty_line
      ui_warning 'timeout returned SIGKILL (128+9)'
      return 1
      ;;
    141) # SIGPIPE signal (128+13) - Broken pipe
      return 141
      ;;
    143) # SIGTERM signal (128+15) - Timed out
      return 124
      ;;
    *) ### All other keys
      if test "${1:?}" -lt 124; then
        return "${1:?}" # Return code of the COMMAND
      fi
      ;;
  esac
  # https://en.wikipedia.org/wiki/Signal_(IPC)#Default_action

  ui_msg_empty_line
  ui_warning "timeout returned: ${1:?}"
  return 1
}

_timeout_check()
{
  if test "${TIMEOUT_CMD_IS_LEGACY_BUSYBOX:-empty}" != 'empty'; then return; fi

  local _timeout_ver
  TIMEOUT_CMD_IS_LEGACY_BUSYBOX='false'

  # timeout may return failure when displaying "--help" so be sure to ignore it
  _timeout_ver="$({
    timeout 2>&1 --help || true
  } | parse_busybox_version)" || _timeout_ver=''
  shift

  if test -n "${_timeout_ver?}" && test "$(numerically_comparable_version "${_timeout_ver:?}" || true)" -lt "$(numerically_comparable_version '1.30.0' || true)"; then
    TIMEOUT_CMD_IS_LEGACY_BUSYBOX='true'
  fi
  readonly TIMEOUT_CMD_IS_LEGACY_BUSYBOX
  export TIMEOUT_CMD_IS_LEGACY_BUSYBOX

  if test "${DEBUG_LOG_ENABLED:?}" -eq 1 || test "${RECOVERY_OUTPUT:?}" = 'true'; then ui_debug "Timeout is legacy BusyBox: ${TIMEOUT_CMD_IS_LEGACY_BUSYBOX:-}"; fi
}

_timeout_compat()
{
  local _status _timeout_secs

  _timeout_check
  _timeout_secs="${1:?}" || ui_error 'Missing "secs" parameter for _timeout_compat'
  shift

  if test "${TIMEOUT_CMD_IS_LEGACY_BUSYBOX:?}" = 'true'; then
    {
      timeout -t "${_timeout_secs:?}" -- "${@}"
      _status="${?}"
    } 2> /dev/null
  else
    timeout -- "${_timeout_secs:?}" "${@}"
    _status="${?}"
  fi

  _timeout_exit_code_remapper "${_status:?}"
  return "${?}"
}

_esc_keycode="$(printf '\033')"
_choose_remapper()
{
  local _key
  _key="${1?}" || ui_error 'Missing parameter for _choose_remapper'
  ui_msg_empty_line
  if test -n "${2:-}"; then
    ui_msg "Key press: ${_key:-} (${2:-})"
  else
    ui_msg "Key press: ${_key:-}"
  fi
  ui_msg_empty_line

  case "${_key?}" in
    '+') return 3 ;;                                            # + key
    '-') return 2 ;;                                            # - key
    'ESC') ui_error 'Installation forcefully terminated' 143 ;; # ESC or other special keys
    *) return 123 ;;                                            # All other keys
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
      if test "${1:?}" -ne 0; then return "${1:?}"; fi
      return 1
      ;;
  esac

  return 0
}

choose_keycheck_with_timeout()
{
  local _key _status
  _timeout_compat "${1:?}" "${KEYCHECK_PATH:?}"
  _status="${?}"

  if test "${_status:?}" -eq 124; then
    ui_msg_empty_line
    ui_msg 'Key: No key pressed'
    ui_msg_empty_line
    return 0
  elif test "${_status:?}" -eq 127 || test "${_status:?}" -eq 132; then
    export KEYCHECK_ENABLED='false'

    true # This is just to waste some time, otherwise the warning about the "timeout" failure may appear after the following message

    ui_msg 'Fallbacking to manual input parsing, waiting input...'
    choose_inputevent "${@}"
    return "${?}"
  fi

  _key="$(_keycheck_map_keycode_to_key "${_status:?}")" || {
    ui_warning "Key detection failed (keycheck), status code: ${?}"
    return 1
  }

  _choose_remapper "${_key?}" "${_status?}"
  return "${?}"
}

choose_keycheck()
{
  local _key _status
  "${KEYCHECK_PATH:?}"
  _status="${?}"

  _key="$(_keycheck_map_keycode_to_key "${_status:?}")" || {
    ui_warning 'Key detection failed'
    return 1
  }

  _choose_remapper "${_key?}" "${_status?}"
  return "${?}"
}

choose_read_with_timeout()
{
  local _key _status
  if test ! -t 0; then return 1; fi
  if test "${RECOVERY_OUTPUT:?}" = 'true' && test "${TEST_INSTALL:-false}" = 'false'; then return 1; fi

  while true; do
    _key=''
    _status=0
    # shellcheck disable=SC3045
    IFS='' read -r -s -n '1' -t "${1:?}" _key || _status="${?}"
    printf '\r                 \r' # Clean invalid choice message (if printed)

    case "${_status:?}" in
      0) ;;    # Command terminated successfully
      1 | 142) # 1 => Command timed out on BusyBox / Toybox; 142 => Command timed out on Bash
        ui_msg_empty_line
        ui_msg 'Key: No key pressed'
        ui_msg_empty_line
        return 0
        ;;
      *)
        ui_msg_empty_line
        ui_warning 'Key detection failed'
        ui_msg_empty_line
        return 1
        ;;
    esac

    case "${_key?}" in
      '+') ;;                                        # + key (allowed)
      '-') ;;                                        # - key (allowed)
      'c' | 'C' | "${_esc_keycode:?}") _key='ESC' ;; # ESC or C key (allowed)
      '') continue ;;                                # Enter key (ignored)
      *)
        printf 'Invalid choice!!!'
        continue
        ;; # NOT allowed
    esac

    break
  done

  _choose_remapper "${_key?}"
  return "${?}"
}

choose_read()
{
  local _key
  if test ! -t 0; then return 1; fi
  if test "${RECOVERY_OUTPUT:?}" = 'true' && test "${TEST_INSTALL:-false}" = 'false'; then return 1; fi

  while true; do
    _key=''
    # shellcheck disable=SC3045
    IFS='' read -r -s -n '1' _key || {
      ui_msg_empty_line
      ui_warning 'Key detection failed'
      ui_msg_empty_line
      return 1
    }
    printf '\r                 \r' # Clean invalid choice message (if printed)

    case "${_key?}" in
      '+') ;;                                        # + key (allowed)
      '-') ;;                                        # - key (allowed)
      'c' | 'C' | "${_esc_keycode:?}") _key='ESC' ;; # ESC or C key (allowed)
      '') continue ;;                                # Enter key (ignored)
      *)
        printf 'Invalid choice!!!'
        continue
        ;; # NOT allowed
    esac

    break
  done

  _choose_remapper "${_key:?}"
  return "${?}"
}

choose_inputevent()
{
  local _key _status _last_key_pressed

  _find_hardware_keys 'gpio-keys' || {
    _status="${?}"
    ui_msg_empty_line
    ui_warning "Key detection failed (input event), status code: ${_status:-}"
    ui_msg_empty_line
    return 1
  }

  _last_key_pressed=''
  while true; do
    _get_input_event "${1:-}" || {
      _status="${?}"

      if test "${_status:?}" -eq 124; then
        ui_msg_empty_line
        ui_msg 'Key: No key pressed'
        ui_msg_empty_line
        return 0
      fi

      ui_warning "Key detection failed 2 (input event), status code: ${_status:-}"
      return 1
    }

    _status=0
    _key="$(_parse_input_event "${INPUT_EVENT_CURRENT?}")" || _status="${?}"

    case "${_status:?}" in
      3) ;; # Key down event read (allowed)
      4) ;; # Key up event read (allowed)
      *)    # Event read failed
        ui_warning "Key detection failed 3 (input event), status code: ${_status:-}"
        return 1
        ;;
    esac

    if test "${DEBUG_LOG_ENABLED:?}" -eq 1 || test "${RECOVERY_OUTPUT:?}" = 'true'; then ui_debug "Key code: ${_key:-}, Event type: ${_status:-}"; fi

    case "${_key?}" in
      "${INPUT_CODE_VOLUME_UP:?}") ;;   # Vol + key (allowed)
      "${INPUT_CODE_VOLUME_DOWN:?}") ;; # Vol - key (allowed)
      "${INPUT_CODE_POWER:?}")
        _last_key_pressed=''
        continue # Power key (ignored)
        ;;
      *)
        _last_key_pressed=''
        ui_msg "Invalid choice!!! Key code: ${_key:-}"
        continue
        ;;
    esac

    if test "${_status:?}" -eq 3; then
      # Key down
      _last_key_pressed="${_key:?}"
      continue
    else
      # Key up

      if test "${_key:?}" = "${_last_key_pressed?}"; then
        : # OK
      else
        _last_key_pressed=''
        ui_msg 'Key mismatch, ignored!!!' # Key mismatch, current key press ignored
        continue
      fi

    fi

    break
  done

  if test "${_key?}" = "${INPUT_CODE_VOLUME_UP:?}"; then
    ui_msg_empty_line
    ui_msg "Key press: + (${INPUT_CODE_VOLUME_UP:-})"
    ui_msg_empty_line
    return 3
  elif test "${_key?}" = "${INPUT_CODE_VOLUME_DOWN:?}"; then
    ui_msg_empty_line
    ui_msg "Key press: - (${INPUT_CODE_VOLUME_DOWN:-})"
    ui_msg_empty_line
    return 2
  else
    ui_error "choose_inputevent failed, key code: ${_key:-}"
  fi

  #ui_msg "Key code: ${_key:-}"
  #_choose_inputevent_remapper "${_key:?}"
  #return "${?}"
}

choose()
{
  local _last_status=0

  ui_msg "QUESTION: ${1:?}"
  ui_msg "${2:?}"
  ui_msg "${3:?}"
  shift 3

  if test "${INPUT_FROM_TERMINAL:?}" = 'true'; then
    choose_read "${@}"
  elif "${KEYCHECK_ENABLED:?}"; then
    choose_keycheck "${@}"
  else
    choose_inputevent "${@}"
  fi
  _last_status="${?}"
  if test "${_last_status:?}" -eq 123; then
    ui_msg 'Invalid choice!!!'
  fi

  return "${_last_status:?}"
}

write_separator_line()
{
  if test "${#2}" -ne 1; then
    ui_warning 'Invalid separator character'
    return 1
  fi
  printf '%*s\n' "${1:?}" '' | tr -- ' ' "${2:?}"
}

_live_setup_choice_msg()
{
  local _msg _sep
  if test "${INPUT_FROM_TERMINAL:?}" = 'true'; then
    _msg='INFO: Press the + sign button on your keyboard to enable live setup.'
  else
    _msg='INFO: Press the VOLUME + key to enable live setup.'
  fi
  _sep="$(write_separator_line "${#_msg}" '-')" || _sep='---'

  ui_msg "${_sep:?}"
  ui_msg "${_msg:?}"
  ui_msg "${_sep:?}"

  if test -n "${1:-}"; then
    ui_msg "Waiting input for ${1:?} seconds..."
  else
    ui_msg "Waiting input..."
  fi
}

live_setup_choice()
{
  LIVE_SETUP_ENABLED='false'

  # Currently we don't handle this case properly so return in this case
  if test "${RECOVERY_OUTPUT:?}" != 'true' && test "${DEBUG_LOG_ENABLED}" -eq 1; then
    return
  fi

  if test "${LIVE_SETUP_ALLOWED:?}" = 'true'; then
    if test "${LIVE_SETUP_DEFAULT:?}" -ne 0; then
      LIVE_SETUP_ENABLED='true'
    elif test "${LIVE_SETUP_TIMEOUT:?}" -gt 0; then

      if test "${INPUT_FROM_TERMINAL:?}" = 'true'; then
        if test "${DEBUG_LOG_ENABLED:?}" -eq 1 || test "${RECOVERY_OUTPUT:?}" = 'true'; then ui_debug 'Using: read'; fi
        _live_setup_choice_msg "${LIVE_SETUP_TIMEOUT}"
        choose_read_with_timeout "${LIVE_SETUP_TIMEOUT}"
      elif "${KEYCHECK_ENABLED:?}"; then
        if test "${DEBUG_LOG_ENABLED:?}" -eq 1 || test "${RECOVERY_OUTPUT:?}" = 'true'; then ui_debug 'Using: keycheck'; fi
        _live_setup_choice_msg "${LIVE_SETUP_TIMEOUT}"
        choose_keycheck_with_timeout "${LIVE_SETUP_TIMEOUT}"
      else
        if test "${DEBUG_LOG_ENABLED:?}" -eq 1 || test "${RECOVERY_OUTPUT:?}" = 'true'; then ui_debug 'Using: input event'; fi
        _live_setup_choice_msg "${LIVE_SETUP_TIMEOUT}"
        choose_inputevent "${LIVE_SETUP_TIMEOUT}"
      fi
      if test "${?}" = '3'; then LIVE_SETUP_ENABLED='true'; fi

    fi
  fi
  readonly LIVE_SETUP_ENABLED

  if test "${LIVE_SETUP_ENABLED:?}" = 'true'; then
    ui_msg 'LIVE SETUP ENABLED!'
    ui_msg_empty_line
  fi
}

# Other
clear_app()
{
  if command -v pm 1> /dev/null; then
    pm clear "${1:?}" 2> /dev/null || true
  fi
}

kill_app()
{
  if command -v am 1> /dev/null; then
    am force-stop "${1:?}" 2> /dev/null || am kill "${1:?}" 2> /dev/null || true
  fi
}

kill_and_disable_app()
{
  if command -v am 1> /dev/null; then
    am force-stop "${1:?}" 2> /dev/null || am kill "${1:?}" 2> /dev/null || true
  fi
  if command -v pm 1> /dev/null; then
    pm disable "${1:?}" 2> /dev/null || true
  fi
}

enable_app()
{
  if command -v pm 1> /dev/null; then
    pm enable "${1:?}" 2> /dev/null || true
  fi
}

parse_busybox_version()
{
  grep -m 1 -o -e 'BusyBox v[0-9]*\.[0-9]*\.[0-9]*' | cut -d 'v' -f '2-' -s
}

numerically_comparable_version()
{
  echo "${@}" | awk -F. '{ printf("%d%03d%03d%03d\n", $1, $2, $3, $4); }'
}

remove_ext()
{
  local str="$1"
  echo "${str%.*}"
}

enable_debug_log()
{
  if test "${DEBUG_LOG_ENABLED}" -eq 1; then return; fi
  export DEBUG_LOG_ENABLED=1

  ui_debug "Creating log: ${LOG_PATH:?}"
  touch "${LOG_PATH:?}" || {
    ui_warning "Unable to write the log file at: ${LOG_PATH:-}"
    export DEBUG_LOG_ENABLED=0
    return
  }

  # If they are already in use, then use alternatives
  if {
    command 1>&6 || command 1>&7
  } 2> /dev/null; then
    export ALTERNATIVE_FDS=1
    # shellcheck disable=SC3023
    exec 88>&1 89>&2 # Backup stdout and stderr
  else
    export ALTERNATIVE_FDS=0
    exec 6>&1 7>&2 # Backup stdout and stderr
  fi
  exec 1>> "${LOG_PATH:?}" 2>&1
}

disable_debug_log()
{
  if test "${DEBUG_LOG_ENABLED}" -ne 1; then return; fi
  export DEBUG_LOG_ENABLED=0
  if test "${ALTERNATIVE_FDS:?}" -eq 0; then
    exec 1>&6 2>&7 # Restore stdout and stderr
    exec 6>&- 7>&-
  else
    exec 1>&88 2>&89 # Restore stdout and stderr
    # shellcheck disable=SC3023
    exec 88>&- 89>&-
  fi
}

# Find test: this is useful to test 'find' - if every file/folder, even the ones with spaces, is displayed in a single line then your version is good
find_test()
{
  find "$1" -type d -exec echo 'FOLDER:' '{}' ';' -o -type f -exec echo 'FILE:' '{}' ';' | while read -r x; do echo "${x}"; done
}
