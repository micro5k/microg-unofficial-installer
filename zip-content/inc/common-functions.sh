#!/sbin/sh
# @file common-functions.sh
# @brief A library with common functions used during flashable ZIP installation.

# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck enable=all
# shellcheck disable=SC3043 # SC3043: In POSIX sh, local is undefined

export TZ=UTC
export LANG=en_US

unset LANGUAGE
unset LC_ALL
unset UNZIP
unset UNZIPOPT
unset UNZIP_OPTS
unset CDPATH

### INIT OPTIONS ###

export DRY_RUN="${DRY_RUN:-0}"
export KEY_TEST_ONLY="${KEY_TEST_ONLY:-0}"

readonly ROLLBACK_TEST='false'

# shellcheck disable=SC3040,SC2015
{
  # Unsupported set options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue
  (set -o posix 2> /dev/null) && set -o posix || true
  (set -o pipefail) && set -o pipefail || true
}

### PREVENTIVE CHECKS ###

if test -z "${ZIPFILE:-}" || test -z "${TMP_PATH:-}" || test "${RECOVERY_PIPE-unset}" = 'unset' || test -z "${OUTFD:-}" || test -z "${INPUT_FROM_TERMINAL:-}" || test -z "${DEBUG_LOG_ENABLED:-}"; then
  echo 'Some variables are NOT set.'
  exit 90
fi

mkdir -p "${TMP_PATH:?}/func-tmp" || {
  echo 'Failed to create the functions temp folder'
  exit 90
}

readonly NL='
'

### FUNCTIONS ###

# Message related functions
_send_text_to_recovery()
{
  if test "${RECOVERY_OUTPUT:?}" != 'true'; then return; fi # Nothing to do here

  if test -n "${RECOVERY_PIPE?}"; then
    printf 'ui_print %s\nui_print\n' "${1?}" 1>> "${RECOVERY_PIPE:?}"
  else
    printf 'ui_print %s\nui_print\n' "${1?}" 1>&"${OUTFD:?}"
  fi

  if test "${DEBUG_LOG_ENABLED:?}" = '1'; then printf 1>&2 '%s\n' "${1?}"; fi
}

_print_text()
{
  if test -n "${NO_COLOR-}"; then
    printf '%s\n' "${2?}"
  else
    # shellcheck disable=SC2059
    printf "${1:?}\n" "${2?}"
  fi

  if test "${DEBUG_LOG_ENABLED:?}" = '1' && test -n "${ORIGINAL_STDERR_FD_PATH?}"; then printf '%s\n' "${2?}" 1>> "${ORIGINAL_STDERR_FD_PATH:?}"; fi
}

ui_error()
{
  local _error_code
  _error_code=91
  test -z "${2-}" || _error_code="${2:?}"

  if test "${RECOVERY_OUTPUT:?}" = 'true'; then
    _send_text_to_recovery "ERROR ${_error_code:?}: ${1:?}"
  else
    _print_text 1>&2 '\033[1;31m%s\033[0m' "ERROR ${_error_code:?}: ${1:?}"
  fi

  exit "${_error_code:?}"
}

ui_recovered_error()
{
  if test "${RECOVERY_OUTPUT:?}" = 'true'; then
    _send_text_to_recovery "RECOVERED ERROR: ${1:?}"
  else
    _print_text 1>&2 '\033[1;31;103m%s\033[0m' "RECOVERED ERROR: ${1:?}"
  fi
}

ui_warning()
{
  if test "${RECOVERY_OUTPUT:?}" = 'true'; then
    _send_text_to_recovery "WARNING: ${1:?}"
  else
    _print_text 1>&2 '\033[0;33m%s\033[0m' "WARNING: ${1:?}"
  fi
}

ui_msg_empty_line()
{
  if test "${RECOVERY_OUTPUT:?}" = 'true'; then
    _send_text_to_recovery ' '
  else
    _print_text '%s' ''
  fi
}

ui_msg()
{
  if test "${RECOVERY_OUTPUT:?}" = 'true'; then
    _send_text_to_recovery "${1:?}"
  else
    _print_text '%s' "${1:?}"
  fi
}

ui_msg_sameline_start()
{
  if test "${RECOVERY_OUTPUT:?}" = 'false'; then
    printf '%s ' "${1:?}"
    return
  elif test -n "${RECOVERY_PIPE?}"; then
    printf 'ui_print %s' "${1:?}" >> "${RECOVERY_PIPE:?}"
  else
    printf 'ui_print %s' "${1:?}" 1>&"${OUTFD:?}"
  fi

  if test "${DEBUG_LOG_ENABLED:?}" = '1'; then printf 1>&2 '%s\n' "${1:?}"; fi
}

ui_msg_sameline_end()
{
  if test "${RECOVERY_OUTPUT:?}" = 'false'; then
    printf '%s\n' "${1:?}"
    return
  elif test -n "${RECOVERY_PIPE?}"; then
    printf '%s\nui_print\n' "${1:?}" >> "${RECOVERY_PIPE:?}"
  else
    printf '%s\nui_print\n' "${1:?}" 1>&"${OUTFD:?}"
  fi

  if test "${DEBUG_LOG_ENABLED:?}" = '1'; then printf 1>&2 '%s\n' "${1:?}"; fi
}

ui_debug()
{
  _print_text 1>&2 '%s' "${1?}"
}

# Other

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

_detect_recovery_name()
{
  local _val

  test "${BOOTMODE:?}" != 'true' || return 2

  if test -n "${DEVICE_TWRP?}" && _val="$("${DEVICE_TWRP:?}" --version | head -n 1)" && _val="${_val#*"openrecoveryscript command line tool, "}" && test -n "${_val?}"; then
    :
  elif _val="$(simple_getprop 'ro.twrp.version')" && _val="TWRP v${_val:?}"; then
    :
  elif _val="$(simple_getprop 'ro.build.date')"; then
    :
  else
    return 1
  fi

  printf '%s\n' "${_val:?}"
}

_parse_kernel_cmdline()
{
  local _var
  if test ! -e '/proc/cmdline'; then return 2; fi

  if _var="$(grep -o -m 1 -e "androidboot\.${1:?}=[^ ]*" -- '/proc/cmdline' | cut -d '=' -f '2-' -s)"; then
    printf '%s\n' "${_var?}"
    return 0
  fi

  return 1
}

parse_boot_value()
{
  if _parse_kernel_cmdline "${1:?}"; then # Value from kernel command-line
    :
  elif simple_getprop "ro.boot.${1:?}"; then # Value from getprop
    :
  else
    return 1
  fi
}

_detect_slot_suffix()
{
  local _val

  if _val="$(_parse_kernel_cmdline 'slot_suffix')" && test -n "${_val?}"; then # Value from kernel command-line
    :
  elif _val="$(_parse_kernel_cmdline 'slot')" && test -n "${_val?}" && _val="_${_val:?}"; then # Value from kernel command-line
    :
  elif _val="$(simple_getprop 'ro.boot.slot_suffix')" && is_valid_prop "${_val:?}"; then # Value from getprop
    :
  elif _val="$(simple_getprop 'ro.boot.slot')" && is_valid_prop "${_val:?}" && _val="_${_val:?}"; then # Value from getprop
    :
  else
    return 1
  fi

  printf '%s\n' "${_val:?}"
}

_detect_verity_state()
{
  if parse_boot_value 'veritymode'; then
    :
  elif list_props | grep -q -m 1 -e '^\[ro\.boot\.veritymode\]'; then # If the value exist, even if empty, it is supported
    printf '%s\n' 'unknown'
  else
    printf '%s\n' 'unsupported'
  fi
}

_detect_encryption_options()
{
  local _val

  if simple_getprop 'ro.crypto.volume.options'; then
    :
  elif _val="$(simple_getprop 'ro.crypto.volume.contents_mode')"; then
    printf '%s\n' "${_val:?}:$(simple_getprop 'ro.crypto.volume.filenames_mode' || :)"
  else
    return 1
  fi
}

is_device_locked()
{
  case "${DEVICE_STATE?}" in
    'locked') return 0 ;; # Device locked
    *) ;;                 # Device unlocked: 'unlocked' or 'unknown'
  esac

  return 1
}

is_bootloader_locked()
{
  case "${VERIFIED_BOOT_STATE?}" in
    'green' | 'yellow' | 'red') return 0 ;; # Boot loader locked
    *) ;;                                   # Boot loader unlocked: 'orange' or 'unknown'
  esac

  return 1
}

is_verity_enabled()
{
  case "${VERITY_MODE?}" in
    'unsupported' | 'unknown' | 'disabled' | 'logging' | '') return 1 ;; # Verity NOT enabled
    *) ;;                                                                # Verity enabled: 'enforcing', 'eio' or 'panicking'
  esac

  return 0
}

_detect_battery_level()
{
  local _val

  # Check also batt_soc, fg_psoc, uevent
  if test -r '/sys/class/power_supply/battery/capacity' && _val="$(cat '/sys/class/power_supply/battery/capacity')" && test -n "${_val?}"; then
    :
  elif test -n "${DEVICE_DUMPSYS?}" && _val="$("${DEVICE_DUMPSYS:?}" 2> /dev/null battery | grep -m 1 -F -e 'level:' | cut -d ':' -f '2-' -s)" && _val="${_val# }" && test -n "${_val?}"; then
    :
  else
    _val=''
  fi

  case "${_val?}" in
    '') return 1 ;;
    *[!0-9]*)
      ui_warning "Invalid battery level. Current value: ${_val?}"
      return 2
      ;;
    *) ;;
  esac

  if test "${_val:?}" -eq 0 || test "${_val:?}" -gt 100; then
    ui_warning "Invalid battery level. Current value: ${_val?}"
    return 3
  fi

  printf '%s\n' "${_val:?}"
}

_mount_helper()
{
  {
    test -n "${DEVICE_MOUNT-}" && PATH="${PREVIOUS_PATH:?}" "${DEVICE_MOUNT:?}" 2> /dev/null "${@}"
  } ||
    mount "${@}" || return "${?}"

  return 0
}

_verify_system_partition()
{
  local _backup_ifs _path
  _backup_ifs="${IFS:-}"
  IFS="${NL:?}"

  for _path in ${1?}; do
    test -n "${_path?}" || continue
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
        ui_error "Found system path at '${SYS_PATH:-}' but failed to find the mountpoint"
      fi

      IFS="${_backup_ifs:-}"
      return 0
    fi
  done

  IFS="${_backup_ifs:-}"
  return 1
}

_set_system_path_from_mountpoint()
{
  if test -e "${1:?}/system/build.prop"; then
    SYS_PATH="${1:?}/system"
    return 0
  elif test -e "${1:?}/build.prop"; then
    SYS_PATH="${1:?}"
    return 0
  fi

  ui_warning "System path not found from '${1?}' mountpoint"
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

_remount_read_write_helper()
{
  test "${DRY_RUN:?}" -lt 2 || return 2

  {
    test -n "${DEVICE_MOUNT-}" && PATH="${PREVIOUS_PATH:?}" "${DEVICE_MOUNT:?}" 2> /dev/null -o 'remount,rw' "${1:?}"
  } ||
    {
      test -n "${DEVICE_MOUNT-}" && PATH="${PREVIOUS_PATH:?}" "${DEVICE_MOUNT:?}" 2> /dev/null -o 'remount,rw' "${1:?}" "${1:?}"
    } ||
    mount -o 'remount,rw' "${1:?}" || return "${?}"

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

_prepare_mountpoint()
{
  case "${1:?}" in
    "${TMP_PATH:?}"/*)
      if test ! -e "${1:?}"; then
        ui_debug "Creating mountpoint '${1?}'..."
        if mkdir -p "${1:?}" && set_perm 0 0 0755 "${1:?}"; then
          return 0
        fi
        ui_warning "Unable to prepare mountpoint '${1?}'"
        return 1
      fi
      ;;
    *) ;;
  esac

  return 0
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
      test -n "${_path?}" || continue
      if test -e "/dev/block/mapper/${_path:?}"; then
        _block="$(_canonicalize "/dev/block/mapper/${_path:?}")"
        ui_msg "Found 'mapper/${_path?}' block at: ${_block?}"
        _found='true'
        break
      fi
    done
  fi

  if test "${_found:?}" = 'false' && test -e '/dev/block/by-name'; then
    for _path in ${1?}; do
      test -n "${_path?}" || continue
      if test -e "/dev/block/by-name/${_path:?}"; then
        _block="$(_canonicalize "/dev/block/by-name/${_path:?}")"
        ui_msg "Found 'by-name/${_path?}' block at: ${_block?}"
        _found='true'
        break
      fi
    done
  fi

  if test "${_found:?}" = 'false' && test -e '/sys/dev/block'; then
    for _path in ${1?}; do
      test -n "${_path?}" || continue
      if _block="$(_find_block "${_path:?}")"; then
        ui_msg "Found '${_path?}' block at: ${_block?}"
        _found='true'
        break
      fi
    done
  fi

  if test "${_found:?}" != 'false'; then
    for _path in ${2?}; do
      test -n "${_path?}" || continue
      if test "${RECOVERY_FAKE_SYSTEM:?}" = 'true' && test "${_path:?}" = '/system'; then continue; fi
      _prepare_mountpoint "${_path:?}" || continue

      if _mount_helper "${_block:?}" "${_path:?}"; then
        IFS="${_backup_ifs:-}"
        LAST_MOUNTPOINT="${_path:?}"
        return 0
      fi
    done
  else
    ui_debug "Block not found for: $(printf '%s' "${1?}" | tr -- '\n' ' ' || :)"
  fi

  IFS="${_backup_ifs:-}"
  return 1
}

_find_and_mount_system()
{
  local _sys_mountpoint_list _additional_system_mountpoint

  _additional_system_mountpoint=''
  if test -n "${ANDROID_ROOT-}" && test "${ANDROID_ROOT:?}" != '/system_root' && test "${ANDROID_ROOT:?}" != '/system'; then
    _additional_system_mountpoint="${ANDROID_ROOT:?}"
  fi

  _sys_mountpoint_list="$(generate_mountpoint_list 'system' "${_additional_system_mountpoint?}" '/system_root' || :)${NL:?}${TMP_PATH:?}/system_mountpoint"
  ui_debug 'System mountpoint list:'
  ui_debug "${_sys_mountpoint_list?}"
  ui_debug ''

  if _verify_system_partition "${_sys_mountpoint_list?}"; then
    ui_debug 'Checking system...'
    ui_debug "Already mounted: ${SYS_MOUNTPOINT?}" # Found (it was already mounted)
  else

    if
      mount_partition_if_possible 'system' "${SLOT_SUFFIX:+system}${SLOT_SUFFIX-}${NL:?}system${NL:?}FACTORYFS${NL:?}" "${_sys_mountpoint_list?}" &&
        test -n "${LAST_MOUNTPOINT?}" && _set_system_path_from_mountpoint "${LAST_MOUNTPOINT:?}"
    then
      # SYS_PATH already set
      SYS_MOUNTPOINT="${LAST_MOUNTPOINT:?}"
      UNMOUNT_SYSTEM="${LAST_PARTITION_MUST_BE_UNMOUNTED:?}"
    else
      deinitialize

      ui_msg_empty_line
      ui_msg "Current slot: ${SLOT?}"
      ui_msg "Device locked state: ${DEVICE_STATE?}"
      ui_msg "Verified boot state: ${VERIFIED_BOOT_STATE?}"
      ui_msg "Verity mode: ${VERITY_MODE?} (detection is unreliable)"
      ui_msg "Dynamic partitions: ${DYNAMIC_PARTITIONS?}"
      ui_msg "Recovery fake system: ${RECOVERY_FAKE_SYSTEM?}"
      ui_msg_empty_line

      ui_error "The ROM cannot be found!!!" 123
    fi
  fi

  readonly SYS_MOUNTPOINT SYS_PATH
}

generate_mountpoint_list()
{
  local _mp_list _mp

  _mp_list=''
  for _mp in "${2-}" "/mnt/${1:?}" "${3-}" "/${1:?}"; do
    test -n "${_mp?}" || continue

    if test -L "${_mp:?}"; then
      # It detect the case where there is NO real partition but only a symbolic link to a folder under /system (example: /product -> '/system/product').
      # It works when inside Android but when inside recovery the symbolic link is missing, so the other case is handled directly inside mount_partition_if_possible()
      ui_debug "INFO: ${_mp?} is a symlink to $(readlink "${_mp?}" || :)"
    elif test -r "${_mp:?}"; then
      _mp="$(_canonicalize "${_mp:?}")"
      _mp_list="${_mp_list?}${_mp:?}${NL:?}"
    fi
  done
  test -n "${_mp_list?}" || return 1 # Empty list

  printf '%s' "${_mp_list:?}"
  return 0
}

mount_partition_if_possible()
{
  local _backup_ifs _partition_name _block_search_list _mp_list _mp _skip_warnings
  unset LAST_MOUNTPOINT
  LAST_PARTITION_MUST_BE_UNMOUNTED=0

  _partition_name="${1:?}"
  _block_search_list="${2:?}"
  _mp_list="${3-auto}"
  _skip_warnings='false'

  if test "${_mp_list?}" = 'auto'; then
    _mp_list="$(generate_mountpoint_list "${_partition_name:?}" || :)"
  fi
  test -n "${_mp_list?}" || return 1 # No usable mountpoint found

  _backup_ifs="${IFS-}"
  IFS="${NL:?}"

  set -f || :
  # shellcheck disable=SC2086 # Word splitting is intended
  set -- ${_mp_list:?} || ui_error "Failed expanding \${_mp_list} inside mount_partition_if_possible()"
  set +f || :

  IFS="${_backup_ifs?}"

  ui_debug "Checking ${_partition_name?}..."

  for _mp in "${@}"; do
    if is_mounted "${_mp:?}"; then
      LAST_MOUNTPOINT="${_mp:?}"
      ui_debug "Already mounted: ${LAST_MOUNTPOINT?}"
      return 0 # Already mounted
    fi
  done

  if _manual_partition_mount "${_block_search_list:?}" "${_mp_list:?}" && test -n "${LAST_MOUNTPOINT?}"; then
    LAST_PARTITION_MUST_BE_UNMOUNTED=1
    ui_debug "Mounted: ${LAST_MOUNTPOINT?}"
    return 0 # Successfully mounted
  fi

  for _mp in "${@}"; do
    case "${_mp:?}" in
      '/mnt'/* | "${TMP_PATH:?}"/*) continue ;; # NOTE: These paths can only be mounted manually (example: /mnt/system)
      *) ;;
    esac

    if _mount_helper 2> /dev/null "${_mp:?}"; then
      LAST_MOUNTPOINT="${_mp:?}"
      LAST_PARTITION_MUST_BE_UNMOUNTED=1
      ui_debug "Mounted (2): ${LAST_MOUNTPOINT?}"
      return 0 # Successfully mounted
    fi
  done

  # In some cases there is no real partition but it is just a folder inside the system partition.
  # In these cases no warnings are shown when the partition is not found.
  if test "${_partition_name:?}" != 'system' && test "${_partition_name:?}" != 'data'; then
    if test -n "${SYS_PATH-}" && test ! -L "${SYS_PATH:?}/${_partition_name:?}" && test -d "${SYS_PATH:?}/${_partition_name:?}"; then # Example: /system_root/system/product
      _skip_warnings='true'
      ui_debug "Found ${_partition_name?} folder: ${SYS_PATH?}/${_partition_name?}"
    elif test -n "${SYS_MOUNTPOINT-}" && test ! -L "${SYS_MOUNTPOINT:?}/${_partition_name:?}" && test -d "${SYS_MOUNTPOINT:?}/${_partition_name:?}"; then # Example: /system_root/odm
      _skip_warnings='true'
      ui_debug "Found ${_partition_name?} folder: ${SYS_MOUNTPOINT?}/${_partition_name?}"
    fi
  fi

  if test "${_skip_warnings:?}" = 'false'; then
    ui_warning "Mounting of ${_partition_name?} failed"
  fi
  return 2
}

_get_local_settings()
{
  if test "${LOCAL_SETTINGS_READ:-false}" = 'true'; then return; fi

  ui_debug 'Parsing local settings...'
  ui_debug ''
  LOCAL_SETTINGS="$(list_props | grep -e "^\[zip\.${MODULE_ID:?}\.")" || LOCAL_SETTINGS=''
  LOCAL_SETTINGS_READ='true'

  readonly LOCAL_SETTINGS LOCAL_SETTINGS_READ
  export LOCAL_SETTINGS LOCAL_SETTINGS_READ
}

parse_setting()
{
  local _var _use_last_choice

  _use_last_choice="${3:-true}"
  _get_local_settings

  _var="$(printf '%s\n' "${LOCAL_SETTINGS?}" | grep -m 1 -F -e "[zip.${MODULE_ID:?}.${1:?}]" | cut -d ':' -f '2-' -s)" || _var=''
  _var="${_var# }"
  if test "${#_var}" -gt 2; then
    printf '%s\n' "${_var?}" | cut -c "2-$((${#_var} - 1))"
    return
  fi

  # Fallback to the last choice
  if test "${_use_last_choice:?}" = 'true' && _var="$(simple_file_getprop "${1:?}" "${SYS_PATH:?}/etc/zips/${MODULE_ID:?}.prop")" && test -n "${_var?}"; then
    printf '%s\n' "${_var:?}"
    return
  elif test "${_use_last_choice:?}" = 'custom' && _var="$(simple_file_getprop "${4:?}" "${SYS_PATH:?}/etc/zips/${MODULE_ID:?}.prop")" && test -n "${_var?}"; then
    case "${_var:?}" in
      "${5:?}") printf '1\n' ;;
      *) printf '0\n' ;;
    esac
    return
  fi

  # Fallback to the default value
  printf '%s\n' "${2?}"
}

remount_read_write()
{
  if is_mounted_read_only "${1:?}"; then
    test "${DRY_RUN:?}" -lt 2 || {
      ui_msg "INFO: The '${1?}' mountpoint is read-only"
      return 0
    }

    ui_msg "INFO: The '${1?}' mountpoint is read-only, it will be remounted"
    _remount_read_write_helper "${1:?}" || {
      return 1
    }
  fi

  return 0
}

remount_read_write_if_possible()
{
  local _required
  _required="${2:-true}"

  if is_mounted_read_only "${1:?}"; then
    test "${DRY_RUN:?}" -lt 2 || {
      ui_msg "INFO: The '${1?}' mountpoint is read-only"
      case "${_required:?}" in
        'true') return 0 ;;
        *) return 2 ;;
      esac
    }

    ui_msg "INFO: The '${1?}' mountpoint is read-only, it will be remounted"
    _remount_read_write_helper "${1:?}" || {
      if test "${_required:?}" = 'true'; then
        ui_error "Remounting of '${1?}' failed"
      else
        ui_warning "Remounting of '${1?}' failed"
        ui_msg_empty_line
        return 1
      fi
    }
  fi

  return 0
}

is_string_starting_with()
{
  case "${2?}" in
    "${1:?}"*) return 0 ;; # Found
    *) ;;
  esac
  return 1 # NOT found
}

verify_keycheck_compatibility()
{
  if test "${BUILD_MANUFACTURER?}" = 'OnePlus' && test "${BUILD_DEVICE?}" = 'OnePlus6'; then
    : # OnePlus 6
  elif test "${BUILD_MANUFACTURER?}" = 'Google' && test "${BUILD_DEVICE?}" = 'blueline'; then
    : # Google Pixel 3
  else
    return # OK
  fi

  # It doesn't work properly on these devices
  export KEYCHECK_ENABLED='false'
}

_write_test()
{
  if test ! -d "${1:?}"; then
    mkdir -p "${1:?}" || return 1
    set_perm 0 0 0755 "${1:?}"
  fi

  touch 2> /dev/null "${1:?}/write-test-file.dat" || return 1

  if test "${FIRST_INSTALLATION:?}" = 'true'; then
    printf '%5120s' '' 1> "${1:?}/write-test-file.dat" || return 1
  fi

  test -e "${1:?}/write-test-file.dat" || return 1

  return 0
}

_detect_architectures()
{
  # Info:
  # - https://android.googlesource.com/platform/cts/+/main/tests/tests/os/src/android/os/cts/BuildTest.java#68
  # - https://android.googlesource.com/platform/cts/+/refs/tags/android-13.0.0_r74/tests/tests/os/src/android/os/cts/BuildTest.java#62
  # - https://android.googlesource.com/toolchain/prebuilts/ndk-darwin/r23/+/refs/heads/main/build/core/setup-app.mk#63

  ARCH_X64='false'
  ARCH_ARM64='false'
  ARCH_MIPS64='false'
  ARCH_RISCV64='false'

  ARCH_X86='false'
  ARCH_ARM='false'
  ARCH_LEGACY_ARM='false'
  ARCH_MIPS='false'

  if is_substring ',x86_64,' "${1:?}"; then
    ARCH_X64='true'
  fi
  if is_substring ',arm64-v8a,' "${1:?}"; then
    ARCH_ARM64='true'
  fi
  if is_substring ',mips64,' "${1:?}"; then
    ARCH_MIPS64='true'
  fi
  if is_substring ',riscv64,' "${1:?}"; then
    ARCH_RISCV64='true'
  fi

  if is_substring ',x86,' "${1:?}"; then
    ARCH_X86='true'
  fi
  if is_substring ',armeabi-v7a,' "${1:?}"; then
    ARCH_ARM='true'
  fi
  if is_substring ',armeabi,' "${1:?}"; then
    ARCH_LEGACY_ARM='true'
  fi
  if is_substring ',mips,' "${1:?}"; then
    ARCH_MIPS='true'
  fi

  readonly ARCH_X64 ARCH_ARM64 ARCH_MIPS64 ARCH_RISCV64 ARCH_X86 ARCH_ARM ARCH_LEGACY_ARM ARCH_MIPS
  export ARCH_X64 ARCH_ARM64 ARCH_MIPS64 ARCH_RISCV64 ARCH_X86 ARCH_ARM ARCH_LEGACY_ARM ARCH_MIPS
}

_detect_main_architectures()
{
  CPU64='false'
  CPU='false'

  if test "${ARCH_X64:?}" = 'true'; then
    CPU64='x86_64'
  elif test "${ARCH_ARM64:?}" = 'true'; then
    CPU64='arm64-v8a'
  elif test "${ARCH_MIPS64:?}" = 'true'; then
    CPU64='mips64'
  fi

  if test "${ARCH_X86:?}" = 'true'; then
    CPU='x86'
  elif test "${ARCH_ARM:?}" = 'true'; then
    CPU='armeabi-v7a'
  elif test "${ARCH_LEGACY_ARM:?}" = 'true'; then
    CPU='armeabi'
  elif test "${ARCH_MIPS:?}" = 'true'; then
    CPU='mips'
  fi

  if test "${CPU64:?}" != 'false'; then
    MAIN_ABI="${CPU64:?}"
  else
    MAIN_ABI="${CPU:?}"
  fi

  readonly CPU64 CPU MAIN_ABI
  export CPU64 CPU MAIN_ABI
}

_generate_architectures_list()
{
  ARCH_LIST=''

  if test "${ARCH_X64:?}" = 'true'; then
    ARCH_LIST="${ARCH_LIST?}x86_64,"
  fi
  if test "${ARCH_X86:?}" = 'true'; then
    ARCH_LIST="${ARCH_LIST?}x86,"
  fi
  if test "${ARCH_ARM64:?}" = 'true'; then
    ARCH_LIST="${ARCH_LIST?}arm64-v8a,"
  fi
  if test "${ARCH_ARM:?}" = 'true'; then
    ARCH_LIST="${ARCH_LIST?}armeabi-v7a,"
  fi
  if test "${ARCH_LEGACY_ARM:?}" = 'true'; then
    ARCH_LIST="${ARCH_LIST?}armeabi,"
  fi
  if test "${ARCH_MIPS64:?}" = 'true'; then
    ARCH_LIST="${ARCH_LIST?}mips64,"
  fi
  if test "${ARCH_MIPS:?}" = 'true'; then
    ARCH_LIST="${ARCH_LIST?}mips,"
  fi
  if test "${ARCH_RISCV64:?}" = 'true'; then
    ARCH_LIST="${ARCH_LIST?}riscv64,"
  fi
  ARCH_LIST="${ARCH_LIST%,}"

  readonly ARCH_LIST
  export ARCH_LIST
}

display_basic_info()
{
  ui_msg "$(write_separator_line "${#MODULE_NAME}" '-' || :)"
  ui_msg "${MODULE_NAME:?}"
  ui_msg "${MODULE_VERSION:?}"
  ui_msg "${BUILD_TYPE:?}"
  ui_msg "(by ${MODULE_AUTHOR:?})"
  ui_msg "$(write_separator_line "${#MODULE_NAME}" '-' || :)"
}

display_info()
{
  ui_msg "Brand: ${BUILD_BRAND?}"
  ui_msg "Manufacturer: ${BUILD_MANUFACTURER?}"
  ui_msg "Model: ${BUILD_MODEL?}"
  ui_msg "Device: ${BUILD_DEVICE?}"
  ui_msg "Product: ${BUILD_PRODUCT?}"
  ui_msg "Emulator: ${IS_EMU:?}"
  ui_msg "Fake signature permission: ${FAKE_SIGN_PERMISSION?}"
  ui_msg_empty_line
  ui_msg "Recovery: ${RECOVERY_NAME?}"
  ui_msg "Recovery API version: ${RECOVERY_API_VER-}"
  ui_msg_empty_line
  ui_msg "First installation: ${FIRST_INSTALLATION:?}"
  ui_msg "Boot mode: ${BOOTMODE:?}"
  ui_msg "Sideload: ${SIDELOAD:?}"
  if test -n "${ZIPINSTALL_VERSION?}"; then
    ui_msg "Zip install: ${ZIP_INSTALL?} (${ZIPINSTALL_VERSION?})"
  else
    ui_msg "Zip install: ${ZIP_INSTALL?}"
  fi
  ui_msg "Battery level: ${BATTERY_LEVEL:?}"
  ui_msg_empty_line
  ui_msg "Android API: ${API:?}"
  if test -n "${CPU-}" && test -n "${CPU64-}"; then
    ui_msg "64-bit CPU arch: ${CPU64:?}"
    ui_msg "32-bit CPU arch: ${CPU:?}"
  fi
  if test -n "${ARCH_LIST-}"; then
    ui_msg "ABI list: ${ARCH_LIST?}"
  fi
  ui_msg_empty_line
  ui_msg "Boot reason: ${BOOT_REASON?}"
  ui_msg "Current slot: ${SLOT?}$(test "${VIRTUAL_AB?}" != 'true' || printf '%s\n' ' (Virtual A/B)' || :)"
  ui_msg "Device locked state: ${DEVICE_STATE?}"
  ui_msg "Verified boot state: ${VERIFIED_BOOT_STATE?}"
  ui_msg "Verity mode: ${VERITY_MODE?} (detection is unreliable)"
  ui_msg "Dynamic partitions: ${DYNAMIC_PARTITIONS?}"
  ui_msg "Recovery fake system: ${RECOVERY_FAKE_SYSTEM?}"
  ui_msg_empty_line
  ui_msg "Encryption state: ${ENCRYPTION_STATE?}"
  ui_msg "Encryption type: ${ENCRYPTION_TYPE?}"
  ui_msg "Encryption options: ${ENCRYPTION_OPTIONS?}"
  ui_msg_empty_line
  ui_msg "System mountpoint: ${SYS_MOUNTPOINT?}"
  ui_msg "System path: ${SYS_PATH?}"
  ui_msg "Priv-app dir name: ${PRIVAPP_DIRNAME?}"
  #ui_msg "Android root ENV: ${ANDROID_ROOT-}"
  ui_msg "$(write_separator_line "${#MODULE_NAME}" '-' || :)"
}

initialize()
{
  local _raw_arch_list _additional_data_mountpoint

  UNMOUNT_SYSTEM=0
  UNMOUNT_PRODUCT=0
  UNMOUNT_VENDOR=0
  UNMOUNT_SYS_EXT=0
  UNMOUNT_ODM=0
  UNMOUNT_DATA=0

  # Make sure that the commands are still overridden here (most shells don't have the ability to export functions)
  if test "${TEST_INSTALL:-false}" != 'false' && test -f "${RS_OVERRIDE_SCRIPT:?}"; then
    # shellcheck source=SCRIPTDIR/../../recovery-simulator/inc/configure-overrides.sh
    . "${RS_OVERRIDE_SCRIPT:?}" || exit "${?}"
  fi

  PRODUCT_PATH=''
  VENDOR_PATH=''
  SYS_EXT_PATH=''
  ODM_PATH=''
  DATA_PATH='/data'

  PRODUCT_USABLE='false'
  VENDOR_USABLE='false'
  SYS_EXT_USABLE='false'

  BASE_SYSCONFIG_XML=''

  package_extract_file 'module.prop' "${TMP_PATH:?}/module.prop"
  MODULE_ID="$(simple_file_getprop 'id' "${TMP_PATH:?}/module.prop")" || ui_error 'Failed to parse id'
  MODULE_NAME="$(simple_file_getprop 'name' "${TMP_PATH:?}/module.prop")" || ui_error 'Failed to parse name'
  MODULE_VERSION="$(simple_file_getprop 'version' "${TMP_PATH:?}/module.prop")" || ui_error 'Failed to parse version'
  MODULE_VERCODE="$(simple_file_getprop 'versionCode' "${TMP_PATH:?}/module.prop")" || ui_error 'Failed to parse version code'
  MODULE_AUTHOR="$(simple_file_getprop 'author' "${TMP_PATH:?}/module.prop")" || ui_error 'Failed to parse author'
  readonly MODULE_ID MODULE_NAME MODULE_VERSION MODULE_VERCODE MODULE_AUTHOR
  export MODULE_ID MODULE_NAME MODULE_VERSION MODULE_VERCODE MODULE_AUTHOR

  package_extract_file 'info.prop' "${TMP_PATH:?}/info.prop"
  BUILD_TYPE="$(simple_file_getprop 'buildType' "${TMP_PATH:?}/info.prop")" || ui_error 'Failed to parse build type'
  readonly BUILD_TYPE
  export BUILD_TYPE

  _get_local_settings

  DRY_RUN="$(parse_setting 'DRY_RUN' "${DRY_RUN:?}" 'false')"
  KEY_TEST_ONLY="$(parse_setting 'KEY_TEST_ONLY' "${KEY_TEST_ONLY:?}" 'false')"

  LIVE_SETUP_DEFAULT="$(parse_setting 'LIVE_SETUP_DEFAULT' "${LIVE_SETUP_DEFAULT:?}" 'false')"
  LIVE_SETUP_TIMEOUT="$(parse_setting 'LIVE_SETUP_TIMEOUT' "${LIVE_SETUP_TIMEOUT:?}" 'false')"

  case "${KEY_TEST_ONLY?}" in '' | *[!0-1]*) KEY_TEST_ONLY=1 ;; *) ;; esac
  if test "${KEY_TEST_ONLY:?}" -eq 1; then DRY_RUN=2; fi
  readonly KEY_TEST_ONLY
  export KEY_TEST_ONLY

  case "${DRY_RUN?}" in '' | *[!0-2]*) DRY_RUN=2 ;; *) ;; esac
  readonly DRY_RUN
  export DRY_RUN

  if test "${DRY_RUN:?}" -gt 0; then
    ui_warning "DRY RUN mode ${DRY_RUN?} enabled. No files on your device will be modified!!!"
    ui_debug ''
  fi

  # Some recoveries have a "system" folder under "/" when "/system" is NOT mounted with just bin, etc and lib / lib64 or, in some rare cases, just bin and usr.
  # Usable binaries are under the fake /system/bin so the /system mountpoint mustn't be used while in this recovery.
  if
    test "${BOOTMODE:?}" != 'true' &&
      test -e '/system/bin/sh' &&
      test ! -e '/system/app' &&
      test ! -e '/system/build.prop' &&
      test ! -e '/system/system/build.prop'
  then
    RECOVERY_FAKE_SYSTEM='true'
  else
    RECOVERY_FAKE_SYSTEM='false'
  fi
  readonly RECOVERY_FAKE_SYSTEM
  export RECOVERY_FAKE_SYSTEM

  RECOVERY_NAME="$(_detect_recovery_name)" || RECOVERY_NAME='unknown'
  BATTERY_LEVEL="$(_detect_battery_level)" || BATTERY_LEVEL='unknown'
  readonly RECOVERY_NAME BATTERY_LEVEL
  export RECOVERY_NAME BATTERY_LEVEL

  SLOT_SUFFIX="$(_detect_slot_suffix)" || SLOT_SUFFIX=''
  if test -n "${SLOT_SUFFIX?}"; then
    SLOT="${SLOT_SUFFIX#"_"}"
  else
    SLOT='no slot'
  fi
  VIRTUAL_AB="$(simple_getprop 'ro.virtual_ab.enabled')" || VIRTUAL_AB='false'
  is_valid_prop "${VIRTUAL_AB:?}" || VIRTUAL_AB='false'
  readonly SLOT_SUFFIX SLOT VIRTUAL_AB
  export SLOT_SUFFIX SLOT VIRTUAL_AB

  BOOT_REASON="$(parse_boot_value 'bootreason')" || BOOT_REASON='unknown'
  DEVICE_STATE="$(parse_boot_value 'vbmeta.device_state')" || DEVICE_STATE='unknown'
  VERIFIED_BOOT_STATE="$(parse_boot_value 'verifiedbootstate')" || VERIFIED_BOOT_STATE='unknown'
  VERITY_MODE="$(_detect_verity_state)"
  if test -e '/dev/block/mapper'; then DYNAMIC_PARTITIONS='true'; else DYNAMIC_PARTITIONS='false'; fi
  readonly BOOT_REASON DEVICE_STATE VERIFIED_BOOT_STATE VERITY_MODE DYNAMIC_PARTITIONS
  export BOOT_REASON DEVICE_STATE VERIFIED_BOOT_STATE VERITY_MODE DYNAMIC_PARTITIONS

  ENCRYPTION_STATE="$(simple_getprop 'ro.crypto.state')" || ENCRYPTION_STATE='unknown'
  ENCRYPTION_TYPE="$(simple_getprop 'ro.crypto.type')" || ENCRYPTION_TYPE='unknown'
  ENCRYPTION_OPTIONS="$(_detect_encryption_options)" || ENCRYPTION_OPTIONS='unknown'
  readonly ENCRYPTION_STATE ENCRYPTION_TYPE ENCRYPTION_OPTIONS
  export ENCRYPTION_STATE ENCRYPTION_TYPE ENCRYPTION_OPTIONS

  if test "${BATTERY_LEVEL:?}" != 'unknown' && test "${BATTERY_LEVEL:?}" -lt 15; then
    ui_error "The battery is too low. Current level: ${BATTERY_LEVEL?}%" 108
  fi

  if is_device_locked; then
    ui_error 'The device is locked!!!' 37
  fi

  if is_bootloader_locked; then
    ui_error "The boot loader is locked!!! Verified boot state: ${VERIFIED_BOOT_STATE?}" 37
  fi

  _find_and_mount_system
  _timeout_check
  cp -pf "${SYS_PATH:?}/build.prop" "${TMP_PATH:?}/build.prop" # Cache the file for faster access

  PREV_INSTALL_FAILED='false'
  if test -f "${SYS_PATH:?}/etc/zips/${MODULE_ID:?}.failed"; then
    PREV_INSTALL_FAILED='true'
    ui_warning 'The previous installation has failed!!!'
    ui_msg_empty_line
  fi
  readonly PREV_INSTALL_FAILED
  export PREV_INSTALL_FAILED

  # Previously installed version code (0 if not already installed or broken)
  PREV_MODULE_VERCODE="$(simple_file_getprop 'install.version.code' "${SYS_PATH:?}/etc/zips/${MODULE_ID:?}.prop")" || PREV_MODULE_VERCODE=''
  case "${PREV_MODULE_VERCODE?}" in
    '') PREV_MODULE_VERCODE='0' ;; # Empty (not installed)
    *[!0-9]*)                      # Broken data
      PREV_MODULE_VERCODE='0'
      ui_warning 'Previously installed version code is NOT valid!!!'
      ui_msg_empty_line
      ;;
    *) ;; # Valid
  esac
  FIRST_INSTALLATION='true'
  test "${PREV_MODULE_VERCODE:?}" -eq 0 || FIRST_INSTALLATION='false'
  readonly FIRST_INSTALLATION PREV_MODULE_VERCODE
  export FIRST_INSTALLATION PREV_MODULE_VERCODE

  BUILD_BRAND="$(sys_getprop 'ro.product.brand')"
  BUILD_MANUFACTURER="$(sys_getprop 'ro.product.manufacturer')" || BUILD_MANUFACTURER="$(sys_getprop 'ro.product.brand')"
  BUILD_MODEL="$(sys_getprop 'ro.product.model')"
  BUILD_DEVICE="$(sys_getprop 'ro.product.device')" || BUILD_DEVICE="$(sys_getprop 'ro.build.product')"
  BUILD_PRODUCT="$(sys_getprop 'ro.product.name')"
  readonly BUILD_BRAND BUILD_MANUFACTURER BUILD_MODEL BUILD_DEVICE BUILD_PRODUCT
  export BUILD_BRAND BUILD_MANUFACTURER BUILD_MODEL BUILD_DEVICE BUILD_PRODUCT

  IS_EMU='false'
  case "${BUILD_DEVICE?}" in
    'windows_x86_64' | 'emu64'*) IS_EMU='true' ;;
    *) ;;
  esac
  if is_string_starting_with 'sdk_google_phone_' "${BUILD_PRODUCT?}" || is_valid_prop "$(simple_getprop 'ro.leapdroid.version' || printf '%s\n' 'unknown' || :)"; then
    IS_EMU='true'
  fi
  readonly IS_EMU
  export IS_EMU

  FAKE_SIGN_PERMISSION='false'
  zip_extract_file "${SYS_PATH:?}/framework/framework-res.apk" 'AndroidManifest.xml' "${TMP_PATH:?}/framework-res"
  XML_MANIFEST="${TMP_PATH:?}/framework-res/AndroidManifest.xml"
  # Detect the presence of the fake signature permission
  # NOTE: It won't detect it if signature spoofing doesn't require a permission, but it is still fine for our case
  if search_ascii_string_as_utf16_in_file 'android.permission.FAKE_PACKAGE_SIGNATURE' "${XML_MANIFEST}"; then
    FAKE_SIGN_PERMISSION='true'
  fi

  API="$(sys_getprop 'ro.build.version.sdk')" || API=0
  readonly API
  export API

  if test "${API:?}" -ge 19; then # KitKat or higher
    PRIVAPP_DIRNAME='priv-app'
  else
    PRIVAPP_DIRNAME='app'
  fi
  readonly PRIVAPP_DIRNAME
  export PRIVAPP_DIRNAME

  live_setup_choice

  test "${MODULE_VERCODE:?}" -gt 0 || ui_error 'Invalid version code'

  if test "${MODULE_VERCODE:?}" -lt "${PREV_MODULE_VERCODE:?}"; then
    ui_error 'Downgrade not allowed!!!' 95
  fi

  IS_INSTALLATION='true'
  if
    test "${LIVE_SETUP_ENABLED:?}" = 'true' && {
      test "${MODULE_VERCODE:?}" -eq "${PREV_MODULE_VERCODE:?}" || test "${PREV_INSTALL_FAILED:?}" = 'true'
    }
  then
    choose 'What do you want to do?' '+) Reinstall' '-) Uninstall'
    if test "${?}" != '3'; then
      IS_INSTALLATION='false'
    fi
  fi
  readonly IS_INSTALLATION
  export IS_INSTALLATION

  remount_read_write "${SYS_MOUNTPOINT:?}" || {
    deinitialize

    ui_msg_empty_line
    ui_msg "Device: ${BUILD_DEVICE?}"
    ui_msg_empty_line
    ui_msg "Current slot: ${SLOT?}"
    ui_msg "Device locked state: ${DEVICE_STATE?}"
    ui_msg "Verified boot state: ${VERIFIED_BOOT_STATE?}"
    ui_msg "Verity mode: ${VERITY_MODE?} (detection is unreliable)"
    ui_msg "Dynamic partitions: ${DYNAMIC_PARTITIONS?}"
    ui_msg "Recovery fake system: ${RECOVERY_FAKE_SYSTEM?}"
    ui_msg_empty_line

    if is_verity_enabled; then
      ui_error "Remounting '${SYS_MOUNTPOINT?}' failed, it is possible that Verity is enabled. If this is the case you should DISABLE it!!!" 30
    else
      ui_error "Remounting '${SYS_MOUNTPOINT?}' failed!!!" 30
    fi
  }

  if mount_partition_if_possible 'product' "${SLOT_SUFFIX:+product}${SLOT_SUFFIX-}${NL:?}product${NL:?}"; then
    PRODUCT_PATH="${LAST_MOUNTPOINT:?}"
    UNMOUNT_PRODUCT="${LAST_PARTITION_MUST_BE_UNMOUNTED:?}"
    remount_read_write_if_possible "${LAST_MOUNTPOINT:?}" false && PRODUCT_USABLE='true'
  fi
  if mount_partition_if_possible 'vendor' "${SLOT_SUFFIX:+vendor}${SLOT_SUFFIX-}${NL:?}vendor${NL:?}"; then
    VENDOR_PATH="${LAST_MOUNTPOINT:?}"
    UNMOUNT_VENDOR="${LAST_PARTITION_MUST_BE_UNMOUNTED:?}"
    remount_read_write_if_possible "${LAST_MOUNTPOINT:?}" false && VENDOR_USABLE='true'
  fi
  if mount_partition_if_possible 'system_ext' "${SLOT_SUFFIX:+system_ext}${SLOT_SUFFIX-}${NL:?}system_ext${NL:?}"; then
    SYS_EXT_PATH="${LAST_MOUNTPOINT:?}"
    UNMOUNT_SYS_EXT="${LAST_PARTITION_MUST_BE_UNMOUNTED:?}"
    remount_read_write_if_possible "${LAST_MOUNTPOINT:?}" false && SYS_EXT_USABLE='true'
  fi
  if mount_partition_if_possible 'odm' "${SLOT_SUFFIX:+odm}${SLOT_SUFFIX-}${NL:?}odm${NL:?}"; then
    ODM_PATH="${LAST_MOUNTPOINT:?}"
    UNMOUNT_ODM="${LAST_PARTITION_MUST_BE_UNMOUNTED:?}"
    remount_read_write_if_possible "${LAST_MOUNTPOINT:?}" false
  fi
  readonly PRODUCT_PATH VENDOR_PATH SYS_EXT_PATH ODM_PATH
  export PRODUCT_PATH VENDOR_PATH SYS_EXT_PATH ODM_PATH
  readonly PRODUCT_USABLE VENDOR_USABLE SYS_EXT_USABLE
  export PRODUCT_USABLE VENDOR_USABLE SYS_EXT_USABLE

  _additional_data_mountpoint=''
  if test -n "${ANDROID_DATA-}" && test "${ANDROID_DATA:?}" != '/data'; then _additional_data_mountpoint="${ANDROID_DATA:?}"; fi

  if mount_partition_if_possible 'data' "userdata${NL:?}DATAFS${NL:?}" "$(generate_mountpoint_list 'data' "${_additional_data_mountpoint?}" || :)"; then
    DATA_PATH="${LAST_MOUNTPOINT:?}"
    UNMOUNT_DATA="${LAST_PARTITION_MUST_BE_UNMOUNTED:?}"
    remount_read_write_if_possible "${LAST_MOUNTPOINT:?}"
  else
    ui_warning "The data partition cannot be mounted, so updates of installed / removed apps cannot be automatically deleted and their Dalvik cache cannot be automatically cleaned. I suggest to manually do a factory reset after flashing this ZIP."
  fi
  readonly DATA_PATH
  export DATA_PATH

  # Display header
  display_basic_info

  DEST_PATH="${SYS_PATH:?}"
  readonly DEST_PATH

  if test "${API:?}" -lt 1; then
    ui_error 'Invalid API level'
  fi

  if test ! -w "${SYS_PATH:?}"; then
    ui_error "The '${SYS_PATH?}' folder is NOT writable"
  fi

  if test "${DEST_PATH:?}" != "${SYS_PATH:?}" && test ! -w "${DEST_PATH:?}"; then
    ui_error "The '${DEST_PATH?}' folder is NOT writable"
  fi

  ###

  # shellcheck disable=SC2312
  _raw_arch_list=','"$(sys_getprop 'ro.product.cpu.abi')"','"$(sys_getprop 'ro.product.cpu.abi2')"','"$(sys_getprop 'ro.product.cpu.upgradeabi')"','"$(sys_getprop 'ro.product.cpu.abilist')"','

  _detect_architectures "${_raw_arch_list:?}"
  _detect_main_architectures
  _generate_architectures_list

  MAIN_64BIT_ABI="${CPU64:?}" # ToDO: fully rename
  MAIN_32BIT_ABI="${CPU:?}"   # ToDO: fully rename
  readonly MAIN_64BIT_ABI MAIN_32BIT_ABI
  export MAIN_64BIT_ABI MAIN_32BIT_ABI

  if test "${CPU64:?}" = 'false' && test "${CPU:?}" = 'false'; then
    ui_error "Unsupported CPU, ABI list => $(printf '%s\n' "${_raw_arch_list?}" | LC_ALL=C tr -s -- ',' || true)"
  fi

  unset LAST_MOUNTPOINT
  unset LAST_PARTITION_MUST_BE_UNMOUNTED
  unset CURRENTLY_ROLLBACKING
}

deinitialize()
{
  if test "${UNMOUNT_DATA:?}" = '1' && test -n "${DATA_PATH?}"; then unmount_partition "${DATA_PATH:?}"; fi

  if test "${UNMOUNT_ODM:?}" = '1' && test -n "${ODM_PATH?}"; then unmount_partition "${ODM_PATH:?}"; fi
  if test "${UNMOUNT_SYS_EXT:?}" = '1' && test -n "${SYS_EXT_PATH?}"; then unmount_partition "${SYS_EXT_PATH:?}"; fi
  if test "${UNMOUNT_VENDOR:?}" = '1' && test -n "${VENDOR_PATH?}"; then unmount_partition "${VENDOR_PATH:?}"; fi
  if test "${UNMOUNT_PRODUCT:?}" = '1' && test -n "${PRODUCT_PATH?}"; then unmount_partition "${PRODUCT_PATH:?}"; fi

  if test "${UNMOUNT_SYSTEM:?}" = '1' && test -n "${SYS_MOUNTPOINT-}"; then unmount_partition "${SYS_MOUNTPOINT:?}"; fi

  if test -e "${TMP_PATH:?}/system_mountpoint"; then
    rmdir -- "${TMP_PATH:?}/system_mountpoint" || ui_error 'Failed to delete the temp system mountpoint'
  fi
}

clean_previous_installations()
{
  local _initial_free_space

  test "${DRY_RUN:?}" -eq 0 || return

  if _write_test "${SYS_PATH:?}/etc"; then
    : # Really writable
  else
    ui_error "Something is wrong because '${SYS_PATH?}' is NOT really writable!!!" 30
  fi

  _initial_free_space="$(get_free_disk_space_of_partition "${SYS_PATH:?}")" || _initial_free_space='-1'

  rm -f -- "${SYS_PATH:?}/etc/write-test-file.dat" || ui_error 'Failed to delete the test file'

  readonly IS_INCLUDED='true'
  export IS_INCLUDED
  # shellcheck source=SCRIPTDIR/../scripts/uninstall.sh
  . "${TMP_PATH:?}/uninstall.sh"

  delete "${SYS_PATH:?}/etc/zips/${MODULE_ID:?}.prop"

  ui_debug ''
  _wait_free_space_changes 5 "${_initial_free_space:?}" # Reclaiming free space may take some time
  ui_debug ''
}

_move_app_into_subfolder()
{
  local _path_without_ext
  _path_without_ext="$(remove_ext "${1:?}")"

  test ! -e "${_path_without_ext:?}" || ui_error "Folder already exists => '${_path_without_ext?}'"
  mkdir -p -- "${_path_without_ext:?}" || ui_error "Failed to create the folder '${_path_without_ext?}'"
  mv -f -- "${1:?}" "${_path_without_ext:?}/" || ui_error "Failed to move the file '${1?}' to folder '${_path_without_ext?}/'"
}

replace_permission_placeholders()
{
  if test -e "${TMP_PATH:?}/files/etc/${1:?}"; then
    {
      grep -l -r -F -e "${2:?}" -- "${TMP_PATH:?}/files/etc/${1:?}" || true
    } | while IFS='' read -r file_name; do
      ui_debug "    ${file_name#"${TMP_PATH}/files/"}"
      replace_line_in_file "${file_name:?}" "${2:?}" "${3:?}"
    done || ui_warning "Failed to replace '${2?}' in 'files/etc/${1?}'"
  fi
}

prepare_installation()
{
  local _backup_ifs _need_newline

  ui_msg 'Preparing installation...'
  _need_newline='false'
  sleep 2> /dev/null '0.05' || : # Wait some time otherwise ui_debug may appear before the previous ui_msg

  if test "${API:?}" -ge 29; then # Android 10+
    ui_debug '  Processing ACCESS_BACKGROUND_LOCATION...'
    replace_permission_placeholders 'default-permissions' '%ACCESS_BACKGROUND_LOCATION%' '        <permission name="android.permission.ACCESS_BACKGROUND_LOCATION" fixed="false" whitelisted="true" />'
    ui_debug '  Done'
    _need_newline='true'
  fi

  if test "${FAKE_SIGN_PERMISSION:?}" = 'true'; then
    ui_debug '  Processing FAKE_PACKAGE_SIGNATURE...'
    replace_permission_placeholders 'permissions' '%FAKE_PACKAGE_SIGNATURE%' '        <permission name="android.permission.FAKE_PACKAGE_SIGNATURE" />'
    replace_permission_placeholders 'default-permissions' '%FAKE_PACKAGE_SIGNATURE%' '        <permission name="android.permission.FAKE_PACKAGE_SIGNATURE" fixed="false" />'
    ui_debug '  Done'
    _need_newline='true'
  fi

  test "${_need_newline:?}" = 'false' || ui_debug ''

  if test "${PRIVAPP_DIRNAME:?}" != 'priv-app' && test -e "${TMP_PATH:?}/files/priv-app"; then
    ui_debug "  Merging priv-app folder with ${PRIVAPP_DIRNAME?} folder..."
    mkdir -p -- "${TMP_PATH:?}/files/${PRIVAPP_DIRNAME:?}" || ui_error "Failed to create the dir '${TMP_PATH?}/files/${PRIVAPP_DIRNAME?}'"
    copy_dir_content "${TMP_PATH:?}/files/priv-app" "${TMP_PATH:?}/files/${PRIVAPP_DIRNAME:?}"
    delete_temp "files/priv-app"
  fi

  if test "${API:?}" -ge 21; then
    _backup_ifs="${IFS:-}"
    IFS=''

    # Move apps into subfolders
    ui_debug '  Moving apps into subfolders...'
    if test -e "${TMP_PATH:?}/files/priv-app"; then
      for entry in "${TMP_PATH:?}/files/priv-app"/*; do
        if test ! -f "${entry:?}"; then continue; fi
        _move_app_into_subfolder "${entry:?}"
      done
    fi
    if test -e "${TMP_PATH:?}/files/app"; then
      for entry in "${TMP_PATH:?}/files/app"/*; do
        if test ! -f "${entry:?}"; then continue; fi
        _move_app_into_subfolder "${entry:?}"
      done
    fi

    IFS="${_backup_ifs:-}"
  fi

  delete_temp "files/etc/zips"
  create_dir "${TMP_PATH:?}/files/etc/zips"
  {
    echo '# SPDX-FileCopyrightText: none'
    echo '# SPDX-License-Identifier: CC0-1.0'
    echo ''
    echo 'install.type=system'
    echo "install.build.type=${BUILD_TYPE:?}"
    echo "install.version.code=${MODULE_VERCODE:?}"
    echo "install.version=${MODULE_VERSION:?}"
  } 1> "${TMP_PATH:?}/files/etc/zips/${MODULE_ID:?}.prop" || ui_error 'Failed to generate the prop file of this zip'

  if test -f "${TMP_PATH:?}/saved-choices.dat"; then
    cat "${TMP_PATH:?}/saved-choices.dat" 1>> "${TMP_PATH:?}/files/etc/zips/${MODULE_ID:?}.prop" || ui_error 'Failed to update the prop file of this zip'
  fi

  set_std_perm_recursive "${TMP_PATH:?}/files"

  if test -d "${TMP_PATH:?}/files/bin"; then
    for entry in "${TMP_PATH:?}/files/bin"/*; do
      if test ! -f "${entry:?}"; then continue; fi
      set_perm 0 2000 0755 "${entry:?}"
    done
  fi

  if test -d "${TMP_PATH:?}/addon.d"; then
    set_std_perm_recursive "${TMP_PATH:?}/addon.d"
    find "${TMP_PATH:?}/addon.d" -type f -name '*.sh' -exec chmod 0755 '{}' '+' || ui_error 'Failed to chmod addon.d scripts'
  fi
}

_something_exists()
{
  for filename in "${@}"; do
    if test -e "${filename:?}"; then return 0; fi
  done
  return 1
}

_get_free_disk_space_of_partition_using_df()
{
  local _skip_first='true'

  df -B1 -P -- "${1:?}" | while IFS=' ' read -r _ _ _ available_space _; do
    if test "${_skip_first?}" = 'true'; then
      _skip_first='false'
      continue
    fi

    if test -n "${available_space?}" && test "${available_space:?}" -ge 0 && printf '%s\n' "${available_space:?}"; then
      return 4
    fi
  done
  if test "${?}" -eq 4; then return 0; fi # Found

  return 1 # NOT found
}

_wait_free_space_changes()
{
  local _max_attempts

  _max_attempts='15'
  if test -n "${1?}"; then _max_attempts="${1:?}"; fi

  printf 'Waiting..'

  while test "${_max_attempts:?}" -gt 0 && _max_attempts="$((_max_attempts - 1))"; do
    printf '.'
    if test "$(get_free_disk_space_of_partition "${SYS_PATH:?}" || :)" != "${2:?}"; then
      break
    fi
    sleep 1
  done
  printf '\n'
}

_custom_rollback()
{
  if test "${ROLLBACK_TEST:?}" = 'false'; then
    return 0
  elif test "${1:?}" = 'priv-app' || test "${1:?}" = 'app'; then
    return 1
  fi

  return 0
}

_do_rollback_last_app_internal()
{
  local _backup_ifs _skip_first _initial_free_space _vanity_name _installed_file_list
  if test ! -s "${TMP_PATH:?}/processed-${1:?}s.log"; then return 1; fi

  _initial_free_space="$(get_free_disk_space_of_partition "${SYS_PATH:?}")" || return 2
  _installed_file_list="$(tail -n '1' -- "${TMP_PATH:?}/processed-${1:?}s.log")" || ui_error "Failed to read processed-${1?}s.log"
  test -n "${_installed_file_list?}" || return 3

  _vanity_name="$(printf '%s\n' "${_installed_file_list:?}" | cut -d '|' -f '1' -s)"
  ui_warning "Rolling back '${_vanity_name?}'..."

  _backup_ifs="${IFS:-}"
  IFS='|'
  _skip_first='true'
  for elem in ${_installed_file_list:?}; do
    if test "${_skip_first?}" = 'true'; then
      _skip_first='false'
      continue
    fi

    if test -n "${elem?}"; then
      delete "${SYS_PATH:?}/${elem:?}"
      delete_temp "files/${elem:?}"
    fi
  done
  IFS="${_backup_ifs:-}"

  fstrim 2> /dev/null -- "${SYS_MOUNTPOINT:?}" || :

  ui_debug ''
  _wait_free_space_changes '' "${_initial_free_space:?}" # Reclaiming free space may take some time
  ui_debug ''

  sed -ie '$ d' "${TMP_PATH:?}/processed-${1:?}s.log" || ui_error "Failed to remove the last line from processed-${1?}s.log"

  if command 1> /dev/null -v 'rollback_complete_callback'; then
    export CURRENTLY_ROLLBACKING='true'
    rollback_complete_callback "${_vanity_name:?}"
    unset CURRENTLY_ROLLBACKING
  else
    ui_warning "The function 'rollback_complete_callback' is missing"
  fi

  return 0
}

_do_rollback_last_app()
{
  if test "${1:?}" = 'priv-app'; then
    _do_rollback_last_app_internal 'priv-app'
    return "${?}"
  elif test "${1:?}" = 'app'; then
    _do_rollback_last_app_internal 'app' || _do_rollback_last_app_internal 'priv-app'
    return "${?}"
  fi

  return 1
}

_is_free_space_error()
{
  if test "${ROLLBACK_TEST:?}" != 'false'; then return 0; fi

  case "${1?}" in
    *'space left'*) return 0 ;; # Found
    *) ;;                       # NOT found
  esac
  return 1 # NOT found
}

get_size_of_file()
{
  local _stat_result

  if _stat_result="$(stat 2> /dev/null -c '%s' -- "${1:?}")"; then
    : # OK
  elif test -n "${DEVICE_STAT?}" && _stat_result="$(PATH="${PREVIOUS_PATH:?}" "${DEVICE_STAT:?}" -c '%s' -- "${1:?}")"; then
    : # OK
  else
    _stat_result=''
  fi

  if test -n "${_stat_result?}" && printf '%s\n' "${_stat_result:?}"; then
    return 0
  fi

  return 1
}

get_free_disk_space_of_partition()
{
  local _stat_result

  if _stat_result="$(stat 2> /dev/null -f -c '%a * %S' -- "${1:?}")"; then
    : # OK
  elif test -n "${DEVICE_STAT?}" && _stat_result="$(PATH="${PREVIOUS_PATH:?}" "${DEVICE_STAT:?}" -f -c '%a * %S' -- "${1:?}")"; then
    : # OK
  else
    _stat_result=''
  fi

  if test -n "${_stat_result?}" && printf '%s\n' "$((_stat_result))"; then
    return 0
  fi

  printf '%s\n' '-1'
  return 1
}

display_free_space()
{
  local _free_space_mb _free_space_auto

  if test -n "${2?}" && test "${2:?}" -ge 0; then
    _free_space_mb="$(convert_bytes_to_mb "${2:?}")"
    _free_space_auto="$(convert_bytes_to_human_readable_format "${2:?}")"

    if test "${_free_space_auto?}" != "${_free_space_mb?} MB"; then
      ui_msg "Free space on ${1?}: ${_free_space_mb?} MB (${_free_space_auto?}) - usable: ${3?}"
    else
      ui_msg "Free space on ${1?}: ${_free_space_mb?} MB - usable: ${3?}"
    fi
    return 0
  fi

  ui_warning "Unable to get free disk space, output for '${1?}' => $(stat 2>&1 -f -c '%a * %S' -- "${1:?}" || :)"
  return 1
}

get_disk_space_usage_of_file_or_folder()
{
  local _result

  if _result="$(du 2> /dev/null -s -B1 -- "${1:?}" | cut -f 1 -s)" && test -n "${_result?}"; then
    printf '%s\n' "${_result:?}"
  elif _result="$(du -s -k -- "${1:?}" | cut -f 1 -s)" && test -n "${_result?}"; then
    printf '%s\n' "$((_result * 1024))"
  else
    printf '%s\n' '-1'
    return 1
  fi
}

convert_bytes_to_mb()
{
  awk -v n="${1:?}" -- 'BEGIN{printf "%.2f\n", n/1048576.0}'
}

convert_bytes_to_human_readable_format()
{
  local _skip_tb='false'
  local _fallback_to_gb='false'

  case "${1:?}" in
    *[!0-9]*)
      printf '%s\n' 'invalid number'
      return 1
      ;;
    *) ;;
  esac

  # In old shells the number 1099511627776 will overflow, so we check if it has overflowed before doing the real check
  if ! test 2> /dev/null 1099511627776 -gt 0; then
    _skip_tb='true'
    if awk -v n="${1:?}" -- 'BEGIN { if ( n < 1073741824 ) exit 1 }'; then _fallback_to_gb='true'; fi
  fi

  if test "${_skip_tb:?}" = 'false' && test "${1:?}" -ge 1099511627776; then
    awk -v n="${1:?}" -- 'BEGIN{printf "%.2f TB\n", n/1099511627776.0}'
  elif test "${_fallback_to_gb:?}" = 'true' || test "${1:?}" -ge 1073741824; then
    awk -v n="${1:?}" -- 'BEGIN{printf "%.2f GB\n", n/1073741824.0}'
  elif test "${1:?}" -ge 1048576; then
    awk -v n="${1:?}" -- 'BEGIN{printf "%.2f MB\n", n/1048576.0}'
  elif test "${1:?}" -ge 1024; then
    awk -v n="${1:?}" -- 'BEGIN{printf "%.2f KB\n", n/1024.0}'
  elif test "${1:?}" -eq 1; then
    printf '%u byte\n' "${1:?}"
  elif test "${1:?}" -ge 0; then
    printf '%u bytes\n' "${1:?}"
  else
    printf '%s\n' 'invalid number'
    return 1
  fi
}

verify_disk_space()
{
  local _needed_space_bytes _free_space_bytes

  if _needed_space_bytes="$(get_disk_space_usage_of_file_or_folder "${TMP_PATH:?}/files")" && test -n "${_needed_space_bytes?}"; then
    ui_msg "Disk space required: $(convert_bytes_to_mb "${_needed_space_bytes:?}" || :) MB"
  else
    _needed_space_bytes='-1'
  fi

  _free_space_bytes="$(get_free_disk_space_of_partition "${1:?}")" || _free_space_bytes='-1'
  display_free_space "${1:?}" "${_free_space_bytes?}" 'true'

  if test -n "${PRODUCT_PATH?}"; then display_free_space "${PRODUCT_PATH:?}" "$(get_free_disk_space_of_partition "${PRODUCT_PATH:?}" || :)" "${PRODUCT_USABLE:?}"; fi
  if test -n "${VENDOR_PATH?}"; then display_free_space "${VENDOR_PATH:?}" "$(get_free_disk_space_of_partition "${VENDOR_PATH:?}" || :)" "${VENDOR_USABLE:?}"; fi
  if test -n "${SYS_EXT_PATH?}"; then display_free_space "${SYS_EXT_PATH:?}" "$(get_free_disk_space_of_partition "${SYS_EXT_PATH:?}" || :)" "${SYS_EXT_USABLE:?}"; fi
  if test -n "${ODM_PATH?}"; then display_free_space "${ODM_PATH:?}" "$(get_free_disk_space_of_partition "${ODM_PATH:?}" || :)" 'false'; fi

  if test "${_needed_space_bytes:?}" -ge 0 && test "${_free_space_bytes:?}" -ge 0; then
    : # OK
  else
    ui_msg_empty_line
    ui_warning 'Unable to verify needed space, continuing anyway'
    return 0
  fi

  if test "${_free_space_bytes:?}" -gt "${_needed_space_bytes:?}"; then return 0; fi

  return 1
}

perform_secure_copy_to_device()
{
  if test ! -d "${TMP_PATH:?}/files/${1:?}"; then return 0; fi
  local _error_text

  ui_debug "  Copying the '${1?}' folder to the device..."
  create_dir "${DEST_PATH:?}/${1:?}"
  _error_text=''

  if
    {
      cp 2> /dev/null -r -p -f -- "${TMP_PATH:?}/files/${1:?}"/* "${DEST_PATH:?}/${1:?}/" ||
        _error_text="$(cp 2>&1 -r -p -f -- "${TMP_PATH:?}/files/${1:?}"/* "${DEST_PATH:?}/${1:?}/")"
    } && _custom_rollback "${1:?}"
  then
    return 0
  elif _is_free_space_error "${_error_text?}"; then
    while _do_rollback_last_app "${1:?}"; do
      if ! _something_exists "${TMP_PATH:?}/files/${1:?}"/* || cp 2> /dev/null -r -p -f -- "${TMP_PATH:?}/files/${1:?}"/* "${DEST_PATH:?}/${1:?}/"; then
        if test -n "${_error_text?}"; then
          ui_recovered_error "$(printf '%s\n' "${_error_text:?}" | head -n 1 || true)"
        else
          ui_recovered_error 'Unknown'
        fi
        return 0
      fi
    done
  fi

  touch 2> /dev/null "${SYS_PATH:?}/etc/zips/${MODULE_ID:?}.failed" || :

  ui_debug ''
  df 2> /dev/null -B1 -P -- "${SYS_MOUNTPOINT:?}" || :
  ui_debug ''
  df 2> /dev/null -h -T -- "${SYS_MOUNTPOINT:?}" || df -h -- "${SYS_MOUNTPOINT:?}" || :
  ui_debug ''

  display_free_space "${DEST_PATH:?}" "$(get_free_disk_space_of_partition "${DEST_PATH:?}" || :)" 'true'

  local _ret_code
  _ret_code=5
  ! _is_free_space_error "${_error_text?}" || _ret_code=122

  if test -n "${_error_text?}"; then
    ui_error "Failed to copy '${1?}' to the device due to => $(printf '%s\n' "${_error_text?}" | head -n 1 || :)" "${_ret_code?}"
  fi
  ui_error "Failed to copy '${1?}' to the device" "${_ret_code?}"
}

perform_installation()
{
  ui_msg_empty_line

  if ! verify_disk_space "${DEST_PATH:?}"; then
    ui_msg_empty_line
    ui_warning "There is NOT enough free space available, but let's try anyway"
  fi

  ui_msg_empty_line

  test "${DRY_RUN:?}" -eq 0 || return

  ui_msg 'Installing...'

  if test ! -d "${SYS_PATH:?}/etc/zips"; then
    mkdir -p "${SYS_PATH:?}/etc/zips" || ui_error "Failed to create the dir '${SYS_PATH:?}/etc/zips'"
    set_perm 0 0 0750 "${SYS_PATH:?}/etc/zips"
  fi

  set_perm 0 0 0640 "${TMP_PATH:?}/files/etc/zips/${MODULE_ID:?}.prop"
  perform_secure_copy_to_device 'etc/zips'
  perform_secure_copy_to_device 'etc/permissions'

  local _entry

  ui_debug "  Copying the 'etc' folder to the device..."
  for _entry in "${TMP_PATH:?}/files/etc"/*; do
    if test -f "${_entry:?}"; then copy_file "${_entry:?}" "${DEST_PATH:?}/etc"; fi
  done

  for _entry in "${TMP_PATH:?}/files/etc"/*; do
    if test -d "${_entry:?}"; then
      case "${_entry:?}" in
        */'etc/zips' | */'etc/permissions') ;;
        *) perform_secure_copy_to_device "${_entry#"${TMP_PATH:?}/files/"}" ;;
      esac
    fi
  done

  if test "${API:?}" -lt 21; then
    if test "${CPU64}" != false; then
      perform_secure_copy_to_device 'lib64'
    fi
    if test "${CPU}" != false; then
      perform_secure_copy_to_device 'lib'
    fi
  fi

  perform_secure_copy_to_device 'framework'
  if test "${PRIVAPP_DIRNAME:?}" != 'app'; then perform_secure_copy_to_device "${PRIVAPP_DIRNAME:?}"; fi
  perform_secure_copy_to_device 'app'

  if test -d "${TMP_PATH:?}/files/bin"; then
    ui_msg 'Installing utilities...'
    perform_secure_copy_to_device 'bin'
  fi
}

finalize_correctly()
{
  test "${DRY_RUN:?}" -ne 0 || rm -f -- "${SYS_PATH:?}/etc/zips/${MODULE_ID:?}.failed" || :
  deinitialize
  touch "${TMP_PATH:?}/installed"

  if test "${IS_INSTALLATION:?}" = 'true'; then
    ui_msg 'Installation finished.'
  else
    ui_msg 'Uninstallation finished.'
  fi
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
unmount_partition()
{
  umount "${1:?}" || {
    ui_warning "Failed to unmount '${1:?}'"
    return 1
  }

  return 0
}

# Getprop related functions
build_getprop()
{
  grep "^ro\.$1=" "${TMP_PATH}/build.prop" | head -n1 | cut -d '=' -f 2
}

list_props()
{
  if test -n "${DEVICE_GETPROP?}" && PATH="${PREVIOUS_PATH:?}" "${DEVICE_GETPROP:?}"; then
    :
  elif command 1> /dev/null -v 'getprop' && getprop; then
    :
  else
    return 2
  fi
}

simple_getprop()
{
  local _val

  if test -n "${DEVICE_GETPROP?}" && _val="$(PATH="${PREVIOUS_PATH:?}" "${DEVICE_GETPROP:?}" "${@}")"; then
    :
  elif command 1> /dev/null -v 'getprop' && _val="$(getprop "${@}")"; then
    :
  else
    return 2
  fi

  test -n "${_val?}" || return 1
  printf '%s\n' "${_val:?}"
}

simple_file_getprop()
{
  if test ! -e "${2:?}"; then return 1; fi
  grep -m 1 -F -e "${1:?}=" -- "${2:?}" | cut -d '=' -f '2-' -s
}

is_valid_prop()
{
  test "${1?}" != 'unknown' || return 1
  return 0
}

sys_getprop()
{
  local _val

  if _val="$(simple_file_getprop "${1:?}" "${TMP_PATH:?}/build.prop")" && test -n "${_val?}" && is_valid_prop "${_val:?}"; then
    :
  elif _val="$(simple_getprop "${1:?}")" && is_valid_prop "${_val:?}"; then
    :
  else
    return 1
  fi

  printf '%s\n' "${_val:?}"
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
  printf '%s' "${1:?}" | sed -e "s@${2:?}@${3:?}@g" || return "${?}" # NOTE: pattern and replacement cannot contain @
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
  find "${1:?}" -type d -exec chmod 0755 '{}' '+' -o -type f -exec chmod 0644 '{}' '+'
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
  mkdir -p "${2:?}" || ui_error "Failed to create the dir '${2}' for extraction"
  set_perm 0 0 0755 "${2:?}"
  unzip -oq "${ZIPFILE:?}" "${1:?}/*" -d "${2:?}" || ui_error "Failed to extract the dir '${1}' from this archive"
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
  test "${DRY_RUN:?}" -eq 0 || return

  if test -n "${DATA_PATH?}" && test -e "${DATA_PATH:?}/data"; then
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
  cp -p -f -- "$1" "$2"/ || ui_error "Failed to copy the file '$1' to '$2'" 99
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
      ui_debug "Deleting '${filename?}'..."
      rm -rf -- "${filename:?}" || ui_error 'Failed to delete files/folders' 103
    fi
  done
}

delete_recursive()
{
  for filename in "${@}"; do
    if test -e "${filename?}"; then
      ui_debug "Deleting '${filename?}'..."
      rm -rf -- "${filename:?}" || ui_error 'Failed to delete files/folders' 103
    fi
  done
}

delete_recursive_wildcard()
{
  for filename in "${@}"; do
    if test -e "${filename?}"; then
      ui_debug "Deleting '${filename?}'..."
      rm -rf -- "${filename:?}" || ui_error 'Failed to delete files/folders' 103
    fi
  done
}

delete_temp()
{
  for filename in "${@}"; do
    if test -e "${TMP_PATH:?}/${filename?}"; then
      #ui_debug "Deleting '${TMP_PATH?}/${filename?}'..."
      rm -rf -- "${TMP_PATH:?}/${filename:?}" || ui_error 'Failed to delete temp files/folders' 103
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

select_lib()
{
  local _dest_arch_name

  if test -e "${TMP_PATH:?}/libs/lib/${1:?}"; then
    case "${1:?}" in
      'arm64-v8a')
        _dest_arch_name='arm64'
        ;;
      'armeabi-v7a' | 'armeabi' | 'armeabi-v7a-hard')
        _dest_arch_name='arm'
        ;;
      *)
        _dest_arch_name="${1:?}"
        ;;
    esac
    ui_debug "  Selecting libraries => ${1:?}"

    move_rename_dir "${TMP_PATH:?}/libs/lib/${1:?}" "${TMP_PATH:?}/selected-libs/${_dest_arch_name:?}"
  else
    ui_warning "Missing libraries => ${1:-}"
    return 1
  fi
}

extract_libs()
{
  local _lib_selected _curr_arch _backup_ifs

  ui_msg "Extracting libs from ${1:?}/${2:?}.apk..."
  create_dir "${TMP_PATH:?}/libs"
  zip_extract_dir "${TMP_PATH:?}/files/${1:?}/${2:?}.apk" 'lib' "${TMP_PATH:?}/libs"

  if test "${API:?}" -ge 21; then
    create_dir "${TMP_PATH:?}/selected-libs"

    _lib_selected='false'

    _backup_ifs="${IFS-}"
    IFS=','
    for _curr_arch in ${ARCH_LIST?}; do
      if test -n "${_curr_arch?}" && select_lib "${_curr_arch:?}"; then
        _lib_selected='true'
        break
      fi
    done
    IFS="${_backup_ifs?}"

    # armeabi-v7a-hard is not a real ABI. No devices are built with this. The "hard float" variant only changes the function call ABI.
    # More info: https://android.googlesource.com/platform/ndk/+/master/docs/HardFloatAbi.md
    # Use the deprecated Hard Float ABI only as fallback
    if test "${_lib_selected:?}" = 'false' && test "${ARCH_ARM:?}" = 'true' && select_lib 'armeabi-v7a-hard'; then
      _lib_selected='true'
    fi

    if test "${_lib_selected:?}" = 'true'; then
      move_rename_dir "${TMP_PATH:?}/selected-libs" "${TMP_PATH:?}/files/${1:?}/lib"
    elif test "${MAIN_ABI:?}" = 'arm64-v8a' || test "${MAIN_ABI:?}" = 'mips64' || test "${MAIN_ABI:?}" = 'mips'; then
      : # Tolerate missing libraries
    else
      ui_error "Failed to select library"
    fi

    delete_temp "selected-libs"
  else
    if test "${CPU64}" != false; then
      create_dir "${TMP_PATH:?}/files/lib64"
      move_dir_content "${TMP_PATH:?}/libs/lib/${CPU64}" "${TMP_PATH:?}/files/lib64"
    fi
    if test "${CPU}" != false; then
      create_dir "${TMP_PATH:?}/files/lib"
      move_dir_content "${TMP_PATH:?}/libs/lib/${CPU}" "${TMP_PATH:?}/files/lib"
    fi
  fi

  delete_temp "libs"
}

file_get_first_line_that_start_with()
{
  grep -m 1 -e "^${1:?}" -- "${2:?}" || return "${?}"
}

string_split()
{
  printf '%s' "${1:?}" | cut -d '|' -sf "${2:?}" || return "${?}"
}

set_filename_of_base_sysconfig_xml()
{
  BASE_SYSCONFIG_XML="etc/sysconfig/${1:?}"
  test -e "${TMP_PATH:?}/files/${BASE_SYSCONFIG_XML:?}" || ui_error "You have set the wrong filename for the base sysconfig XML => ${BASE_SYSCONFIG_XML?}"
}

# @description Configure an app for later installation.
# (it automatically handle the API compatibility)
#
# @arg $1 integer Default installation setting (default 0)
# @arg $2 string Name of the chosen option to be stored (default empty string)
# @arg $3 string Vanity name of the app
# @arg $4 string Filename of the app
# @arg $5 string Folder of the app
# @arg $6 boolean Auto-enable URL handling (default false)
# @arg $7 boolean Is the installation of this app optional? (default true)
#
# @exitcode 0 If installed.
# @exitcode 1 If NOT installed.
setup_app()
{
  local _install _chosen_option_name _vanity_name _filename _dir _url_handling _optional
  local _app_conf _min_api _max_api _output_name _extract_libs _internal_name _file_hash _output_dir _installed_file_list

  _install="${1:-0}"
  _chosen_option_name="${2-}"
  _vanity_name="${3:?}"
  _filename="${4:?}"
  _dir="${5:?}"
  _url_handling="${6:-false}"
  _optional="${7:-true}"
  if test "${_optional:?}" = 'true' && test ! -f "${TMP_PATH:?}/origin/${_dir:?}/${_filename:?}.apk"; then return 1; fi

  _app_conf="$(file_get_first_line_that_start_with "${_dir:?}/${_filename:?}|" "${TMP_PATH:?}/origin/file-list.dat")" || ui_error "Failed to get app config for '${_vanity_name?}'"
  _min_api="$(string_split "${_app_conf:?}" 2)" || ui_error "Failed to get min API for '${_vanity_name?}'"
  _max_api="$(string_split "${_app_conf:?}" 3)" || ui_error "Failed to get max API for '${_vanity_name?}'"
  _output_name="$(string_split "${_app_conf:?}" 4)" || ui_error "Failed to get output name for '${_vanity_name?}'"
  _extract_libs="$(string_split "${_app_conf:?}" 5)" || ui_error "Failed to get the value of extract libs for '${_vanity_name?}'"
  _internal_name="$(string_split "${_app_conf:?}" 6)" || ui_error "Failed to get internal name for '${_vanity_name?}'"
  _file_hash="$(string_split "${_app_conf:?}" 7)" || ui_error "Failed to get the hash of '${_vanity_name?}'"

  _output_dir=''
  _installed_file_list=''

  ui_debug ''

  if test "${API:?}" -ge "${_min_api:?}" && test "${API:?}" -le "${_max_api:-999}"; then
    if test "${_optional:?}" = 'true' && test "${LIVE_SETUP_ENABLED:?}" = 'true'; then
      choose "Do you want to install ${_vanity_name:?}?" '+) Yes' '-) No'
      if test "${?}" -eq 3; then _install='1'; else _install='0'; fi
    fi

    if test -n "${_chosen_option_name?}" && test "${CURRENTLY_ROLLBACKING:-false}" != 'true' && test "${_optional:?}" = 'true'; then
      printf '%s\n' "${_chosen_option_name:?}=${_install:?}" 1>> "${TMP_PATH:?}/saved-choices.dat" || ui_error 'Failed to update saved-choices.dat'
    fi

    if test "${_install:?}" -ne 0 || test "${_optional:?}" != 'true'; then
      ui_msg "Enabling: ${_vanity_name:?}"

      ui_msg_sameline_start 'Verifying... '
      ui_debug ''
      verify_sha1 "${TMP_PATH:?}/origin/${_dir:?}/${_filename:?}.apk" "${_file_hash:?}" || ui_error "Failed hash verification of '${_vanity_name?}'"
      ui_msg_sameline_end 'OK'

      if test "${API:?}" -ge 21; then
        _output_dir="${_dir:?}/${_output_name:?}"
      else
        _output_dir="${_dir:?}"
      fi
      mkdir -p "${TMP_PATH:?}/files/${_output_dir:?}" || ui_error "Failed to create the folder for '${_vanity_name?}'"

      if test "${_dir:?}" = 'priv-app' && test "${API:?}" -ge 26 && test -f "${TMP_PATH:?}/origin/etc/permissions/privapp-permissions-${_filename:?}.xml"; then
        create_dir "${TMP_PATH:?}/files/etc/permissions" || ui_error "Failed to create the permissions folder for '${_vanity_name?}'"
        move_rename_file "${TMP_PATH:?}/origin/etc/permissions/privapp-permissions-${_filename:?}.xml" "${TMP_PATH:?}/files/etc/permissions/privapp-permissions-${_output_name:?}.xml" || ui_error "Failed to setup the priv-app xml of '${_vanity_name?}'"
        _installed_file_list="${_installed_file_list?}|etc/permissions/privapp-permissions-${_output_name:?}.xml"
      fi
      if test "${API:?}" -ge 23 && test -f "${TMP_PATH:?}/origin/etc/default-permissions/default-permissions-${_filename:?}.xml"; then
        create_dir "${TMP_PATH:?}/files/etc/default-permissions" || ui_error "Failed to create the default permissions folder for '${_vanity_name?}'"
        move_rename_file "${TMP_PATH:?}/origin/etc/default-permissions/default-permissions-${_filename:?}.xml" "${TMP_PATH:?}/files/etc/default-permissions/default-permissions-${_output_name:?}.xml" || ui_error "Failed to setup the default permissions xml of '${_vanity_name?}'"
        _installed_file_list="${_installed_file_list?}|etc/default-permissions/default-permissions-${_output_name:?}.xml"
      fi
      if test "${_url_handling:?}" != 'false' && test "${CURRENTLY_ROLLBACKING:-false}" != 'true'; then
        test -n "${BASE_SYSCONFIG_XML?}" || ui_error 'You have NOT set the filename of the base sysconfig XML'
        add_line_in_file_after_string "${TMP_PATH:?}/files/${BASE_SYSCONFIG_XML:?}" '<!-- %CUSTOM_APP_LINKS-START% -->' "    <app-link package=\"${_internal_name:?}\" />" || ui_error "Failed to auto-enable URL handling for '${_vanity_name?}'"
      fi
      move_rename_file "${TMP_PATH:?}/origin/${_dir:?}/${_filename:?}.apk" "${TMP_PATH:?}/files/${_output_dir:?}/${_output_name:?}.apk" || ui_error "Failed to setup the app => '${_vanity_name?}'"

      if test "${CURRENTLY_ROLLBACKING:-false}" != 'true' && test "${_optional:?}" = 'true' && test "$(get_size_of_file "${TMP_PATH:?}/files/${_output_dir:?}/${_output_name:?}.apk" || printf '0' || :)" -gt 102400; then
        _installed_file_list="${_installed_file_list#|}"
        printf '%s\n' "${_vanity_name:?}|${_output_dir:?}/${_output_name:?}.apk|${_installed_file_list?}" 1>> "${TMP_PATH:?}/processed-${_dir:?}s.log" || ui_error "Failed to update processed-${_dir?}s.log"
      fi

      case "${_extract_libs?}" in
        'libs') extract_libs "${_output_dir:?}" "${_output_name:?}" ;;
        '') ;;
        *) ui_error "Invalid value of extract libs => ${_extract_libs?}" ;;
      esac

      return 0
    else
      ui_debug "Disabling: ${_vanity_name:?}"
    fi
  else
    ui_debug "Skipping: ${_vanity_name:?}"
  fi

  return 1
}

setup_lib()
{
  local _install _chosen_option_name _vanity_name _filename _dir _optional
  local _app_conf _min_api _max_api _output_name _extract_libs _internal_name _file_hash _output_dir

  _install="${1:-0}"
  _chosen_option_name="${2-}"
  _vanity_name="${3:?}"
  _filename="${4:?}"
  _optional="${5:-true}"
  _dir='framework'
  if test "${_optional:?}" = 'true' && test ! -f "${TMP_PATH:?}/origin/${_dir:?}/${_filename:?}.jar"; then return 1; fi

  _app_conf="$(file_get_first_line_that_start_with "${_dir:?}/${_filename:?}|" "${TMP_PATH:?}/origin/file-list.dat")" || ui_error "Failed to get app config for '${_vanity_name?}'"
  _min_api="$(string_split "${_app_conf:?}" 2)" || ui_error "Failed to get min API for '${_vanity_name?}'"
  _max_api="$(string_split "${_app_conf:?}" 3)" || ui_error "Failed to get max API for '${_vanity_name?}'"
  _output_name="$(string_split "${_app_conf:?}" 4)" || ui_error "Failed to get output name for '${_vanity_name?}'"
  _extract_libs=''
  _internal_name=''
  _file_hash="$(string_split "${_app_conf:?}" 7)" || ui_error "Failed to get the hash of '${_vanity_name?}'"

  _output_dir="${_dir:?}"

  ui_debug ''

  if test "${API:?}" -ge "${_min_api:?}" && test "${API:?}" -le "${_max_api:-999}"; then
    if test "${_optional:?}" = 'true' && test "${LIVE_SETUP_ENABLED:?}" = 'true'; then
      choose "Do you want to install ${_vanity_name:?}?" '+) Yes' '-) No'
      if test "${?}" -eq 3; then _install='1'; else _install='0'; fi
    fi

    if test -n "${_chosen_option_name?}" && test "${CURRENTLY_ROLLBACKING:-false}" != 'true' && test "${_optional:?}" = 'true'; then
      printf '%s\n' "${_chosen_option_name:?}=${_install:?}" 1>> "${TMP_PATH:?}/saved-choices.dat" || ui_error 'Failed to update saved-choices.dat'
    fi

    if test "${_install:?}" -ne 0 || test "${_optional:?}" != 'true'; then
      ui_msg "Enabling: ${_vanity_name:?}"

      ui_msg_sameline_start 'Verifying... '
      ui_debug ''
      verify_sha1 "${TMP_PATH:?}/origin/${_dir:?}/${_filename:?}.jar" "${_file_hash:?}" || ui_error "Failed hash verification of '${_vanity_name?}'"
      ui_msg_sameline_end 'OK'

      mkdir -p "${TMP_PATH:?}/files/${_output_dir:?}" || ui_error "Failed to create the folder for '${_vanity_name?}'"

      if test -f "${TMP_PATH:?}/origin/etc/permissions/${_filename:?}.xml"; then
        create_dir "${TMP_PATH:?}/files/etc/permissions" || ui_error "Failed to create the permissions folder for '${_vanity_name?}'"
        move_rename_file "${TMP_PATH:?}/origin/etc/permissions/${_filename:?}.xml" "${TMP_PATH:?}/files/etc/permissions/${_output_name:?}.xml" || ui_error "Failed to setup the xml of '${_vanity_name?}'"
      else
        ui_error "Missing permission xml file for '${_vanity_name?}'"
      fi
      move_rename_file "${TMP_PATH:?}/origin/${_dir:?}/${_filename:?}.jar" "${TMP_PATH:?}/files/${_output_dir:?}/${_output_name:?}.jar" || ui_error "Failed to setup the app => '${_vanity_name?}'"

      return 0
    else
      ui_debug "Disabling: ${_vanity_name:?}"
    fi
  else
    ui_debug "Skipping: ${_vanity_name:?}"
  fi

  return 1
}

setup_util()
{
  ui_debug ''
  ui_msg "Enabling utility: ${2?}"

  mkdir -p "${TMP_PATH:?}/files/bin" || ui_error "Failed to create the folder for '${2?}'"
  move_rename_file "${TMP_PATH:?}/origin/bin/${1:?}.sh" "${TMP_PATH:?}/files/bin/${1:?}" || ui_error "Failed to setup the util => '${2?}'"
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

  if test ! -r '/proc/bus/input/devices'; then return 1; fi # NOT found

  # shellcheck disable=SC2002
  cat '/proc/bus/input/devices' | while IFS=': ' read -r line_type full_line; do
    if test "${line_type?}" = 'N'; then
      _last_device_name="${full_line?}"
    elif test "${line_type?}" = 'H' && test "${_last_device_name?}" = "Name=\"${1:?}\""; then

      local _found=0
      printf '%s' "${full_line?}" | cut -d '=' -f '2-' -s | while IFS='' read -r my_line; do
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

inputevent_initialize()
{
  local _device _path

  INPUT_CODE_VOLUMEUP=''
  INPUT_CODE_VOLUMEDOWN=''
  INPUT_CODE_POWER=''
  INPUT_CODE_BACK=''
  INPUT_CODE_HOME=''
  INPUT_CODE_MENU=''
  INPUT_CODE_APP_SWITCH=''

  INPUT_DEVICE_LIST=''

  for _device in 'gpio-keys' 'qpnp_pon' 'sec_key' 'sec_touchkey' 'qwerty' 'qwerty2'; do
    if test "${IS_EMU:?}" != 'true'; then
      case "${_device:?}" in 'qwerty' | 'qwerty2') continue ;; *) ;; esac
    fi

    if _path="$(_find_input_device "${_device:?}")" && _path="/dev/input/${_path:?}" && test -r "${_path:?}"; then
      if test "${DEBUG_LOG_ENABLED:?}" -eq 1 || test "${KEY_TEST_ONLY:?}" -eq 1 || test "${RECOVERY_OUTPUT:?}" = 'true'; then ui_debug "Found '${_device?}' device at: ${_path?}"; fi
      INPUT_DEVICE_LIST="${INPUT_DEVICE_LIST?}${_path:?}${NL:?}"
    fi

    _parse_keylayout "${_device:?}"
  done
}

input_device_listener_start()
{
  local _backup_ifs _device_path
  test -n "${INPUT_DEVICE_LIST?}" || return 1

  INPUT_EVENT_START_OFFSET='0'
  if test -e "${TMP_PATH:?}/working-files/input"; then
    ui_warning "Previous input device listener NOT cleaned correctly"
    delete_temp 'working-files/input'
  fi

  _backup_ifs="${IFS-}"
  IFS="${NL:?}"
  set -f
  # shellcheck disable=SC2086 # Word splitting is intended
  set -- ${INPUT_DEVICE_LIST:?} || ui_error "Failed expanding \$INPUT_DEVICE_LIST inside input_device_listener_start()"
  set +f
  IFS="${_backup_ifs?}"

  mkdir -p "${TMP_PATH:?}/working-files/input/input-events" || ui_error 'Failed to create the folder for input events'
  for _device_path in "${@}"; do
    cat 1>> "${TMP_PATH:?}/working-files/input/input-events/0" -u -- "${_device_path:?}" &
    printf '%s\n' "${!}" 1>> "${TMP_PATH:?}/working-files/input/pids-to-kill.dat"
  done
}

input_device_listener_stop()
{
  kill_pids_from_file 'working-files/input/pids-to-kill.dat'
  delete_temp 'working-files/input'
  unset INPUT_EVENT_START_OFFSET
}

_parse_keylayout()
{
  local _kl_file
  _kl_file="${SYS_PATH:?}/usr/keylayout/${1:?}.kl"

  # Example file:
  ## key 115 VOLUME_UP
  ## key 114 VOLUME_DOWN
  ## key 116 POWER
  ## key 102 HOME
  ## key 217 ASSIST
  ## key 528 FOCUS
  ## key 766 CAMERA
  ## key 689 AI

  if test -f "${_kl_file:?}"; then
    ui_debug "Parsing keylayout: ${_kl_file?}"

    # The default IFS of space, tab and newline is fine
    while read -r key_type key_code key_name _; do
      if test "${key_type?}" != 'key'; then continue; fi
      if test -z "${key_name?}" || test -z "${key_code?}"; then
        ui_warning "Missing key name or key code, debug info: '${key_type?}' '${key_code?}' '${key_name?}'"
        continue
      fi
      if test "${key_code:?}" -le 1; then continue; fi

      case "${key_name:?}" in
        'VOLUME_UP')
          test -z "${INPUT_CODE_VOLUMEUP?}" || continue
          INPUT_CODE_VOLUMEUP="${key_code:?}"
          ;;
        'VOLUME_DOWN')
          test -z "${INPUT_CODE_VOLUMEDOWN?}" || continue
          INPUT_CODE_VOLUMEDOWN="${key_code:?}"
          ;;
        'POWER')
          test -z "${INPUT_CODE_POWER?}" || continue
          INPUT_CODE_POWER="${key_code:?}"
          ;;
        'BACK')
          test -z "${INPUT_CODE_BACK?}" || continue
          INPUT_CODE_BACK="${key_code:?}"
          ;;
        'HOME')
          test -z "${INPUT_CODE_HOME?}" || continue
          INPUT_CODE_HOME="${key_code:?}"
          ;;
        'MENU')
          test -z "${INPUT_CODE_MENU?}" || continue
          test "${1?}" != 'qwerty' || continue # Since there are multiple MENU values in 'qwerty', skip it
          INPUT_CODE_MENU="${key_code:?}"
          ;;

        'ASSIST' | 'FOCUS' | 'CAMERA' | 'AI' | 'APP_SWITCH') ;;                                       # ToDO: Check later
        'ENDCALL' | 'DPAD_LEFT' | 'DPAD_RIGHT' | 'DPAD_UP' | 'DPAD_DOWN' | 'DPAD_CENTER') continue ;; # Always ignore
        *)
          case "${1?}" in 'qwerty') ;; *) ui_debug "Unknown key: ${key_name?}" ;; esac
          continue
          ;;
      esac
      if test "${DEBUG_LOG_ENABLED:?}" -eq 1 || test "${KEY_TEST_ONLY:?}" -eq 1; then ui_debug "KEY_${key_name?} found at: ${key_code?}"; fi
    done 0< "${_kl_file:?}" || ui_warning "Failed parsing keylayout '${_kl_file?}'"
  fi
}

kill_pids_from_file()
{
  local _found

  test -e "${TMP_PATH:?}/${1:?}" || {
    ui_warning "File with PIDs to kill is missing => ${1?}"
    return
  }

  _found='false'
  while IFS='' read -r _pid; do
    if test -z "${_pid?}" || test "${_pid:?}" -le 2; then
      ui_warning "Invalid PID: ${_pid?}"
      continue
    fi
    if test "${KEY_TEST_ONLY:?}" -eq 1; then ui_debug "Killing: ${_pid?}"; fi
    kill "${_pid:?}" || ui_warning "Failed to kill PID => ${_pid?}"
    _found='true'
  done 0< "${TMP_PATH:?}/${1:?}"

  if test "${_found:?}" = 'false'; then
    ui_warning "Unable to read PIDs from => ${1?}"
  fi

  delete_temp "${1:?}"
}

hex_to_dec()
{
  printf '%d' "0x${1:-0}"
}

_prepare_hexdump_output()
{
  tr -s -- ' ' | cut -d ' ' -f '2-' -s | tr -- '\n' ' ' && printf '\n'
}

_get_input_event()
{
  local _size _file_size _expected_file_size _max_cycles _val

  INPUT_EVENT_CURRENT=''

  _size="${INPUT_EVENT_SIZE:-24}"
  _expected_file_size="$((INPUT_EVENT_START_OFFSET + _size))"
  _max_cycles=''
  if test -n "${1-}"; then
    test "${1:?}" -gt 0 || return 124 # Timed out
    _max_cycles="$((${1:?} * 10))" || return 120
  fi

  while true; do
    _file_size="$(get_size_of_file 2> /dev/null "${TMP_PATH:?}/working-files/input/input-events/0")" || return 121

    if test "${_file_size:?}" -ge "${_expected_file_size:?}"; then
      _val="$(hexdump -x -v -s "${INPUT_EVENT_START_OFFSET:?}" -n "${_size:?}" -- "${TMP_PATH:?}/working-files/input/input-events/0" | _prepare_hexdump_output)" || return "${?}"
      break
    fi

    if test -n "${_max_cycles?}" && test "$((_max_cycles = _max_cycles - 1))" -le 0; then return 124; fi # Timed out
    sleep '0.1'
  done

  INPUT_EVENT_START_OFFSET="$((INPUT_EVENT_START_OFFSET + _size))"
  INPUT_EVENT_CURRENT="${_val:?}"

  return 0
}

# 64-bit input event:
#   struct timeval time = 16 bytes (time at which the event occurs)
#   unsigned short type =  2 bytes (event type: 1 is the one that we need)
#   unsigned short code =  2 bytes (key code)
#   int value           =  4 bytes (key action: 1=pressed, 0=released, 2=held) # NOTE: The "held" action never occurs, need testing
#
#   Total size          = 24 bytes

# 32-bit input event:
#   struct timeval time =  8 bytes (time at which the event occurs)
#   unsigned short type =  2 bytes (event type: 1 is the one that we need)
#   unsigned short code =  2 bytes (key code)
#   int value           =  4 bytes (key action: 1=pressed, 0=released, 2=held) # NOTE: The "held" action never occurs, need testing
#
#   Total size          = 16 bytes

_detect_input_event_size()
{
  printf "%s\n" "${1?}" | while IFS=' ' read -r _ _ _ _ part5 _ _ part8 part9 _ _ part12 _; do
    if test -n "${part9?}" && test "$(hex_to_dec "${part9:?}" || :)" -eq 1 && test -n "${part12?}" && test "$(hex_to_dec "${part12:?}" || printf '%s' '9' || :)" -eq 0; then
      test "${DEBUG_LOG_ENABLED:?}" != 1 || ui_debug 'Input event is 64-bit'
      printf '%s\n' 24
      return 4
    elif test -n "${part5?}" && test "$(hex_to_dec "${part5:?}" || :)" -eq 1 && test -n "${part8?}" && test "$(hex_to_dec "${part8:?}" || printf '%s' '9' || :)" -eq 0; then
      test "${DEBUG_LOG_ENABLED:?}" != 1 || ui_debug 'Input event is 32-bit'
      printf '%s\n' 16
      return 4
    else
      ui_warning "Unknown input event, type: ${part5:-''} ${part9:-''}"
    fi
  done

  if test "${?}" -eq 4; then
    test "${KEY_TEST_ONLY:?}" -eq 0 || ui_debug ''
    return 0 # OK
  fi

  return 127 # Fail
}

_parse_input_event()
{
  printf "%s\n" "${1?}" | while IFS=' ' read -r _ _ _ _ ev_type32 key_code32 key_action32p2 key_action32p1 ev_type64 key_code64 key_action64p2 key_action64p1 _; do
    if test "${INPUT_EVENT_SIZE:?}" -eq 24; then
      event_type="${ev_type64?}"
      key_code="${key_code64?}"
      key_action="${key_action64p1?}${key_action64p2?}"
    elif test "${INPUT_EVENT_SIZE:?}" -eq 16; then
      event_type="${ev_type32?}"
      key_code="${key_code32?}"
      key_action="${key_action32p1?}${key_action32p2?}"
    else
      ui_warning "Invalid input event size: ${INPUT_EVENT_SIZE?}"
      return 127
    fi

    if test -z "${event_type?}" || test -z "${key_code?}" || test -z "${key_action?}"; then
      ui_warning "Corrupted event data"
      return 122
    fi

    event_type="$(hex_to_dec "${event_type:?}")" || return 123
    key_action="$(hex_to_dec "${key_action:?}")" || return 123

    if test "${event_type:?}" -eq 0; then return 115; fi # Event type 0 (EV_SYN) is useless, ignore it earlier and never report it

    # Only event type 1 (EV_KEY) is supported
    if test "${event_type:?}" -ne 1; then
      if test "${DEBUG_LOG_ENABLED:?}" -eq 1 || test "${KEY_TEST_ONLY:?}" -eq 1; then
        ui_warning "Event type ignored, event type: ${event_type?}"
      fi
      return 115
    fi

    if test "${key_code:?}" = '014a' || test "${key_code:?}" = '0145'; then # BTN_TOUCH => 0x014a (330), BTN_TOOL_FINGER => 0x0145 (325)
      ui_warning "Touch screen event ignored, key: 0x${key_code?}"
      return 115
    fi

    if test "${KEY_TEST_ONLY:?}" -eq 1; then
      ui_msg 1>&2 "EVENT DEBUG: ${INPUT_EVENT_CURRENT?}"
    elif test "${DEBUG_LOG_ENABLED:?}" -eq 1; then
      ui_debug ''
      ui_debug "EVENT DEBUG: ${INPUT_EVENT_CURRENT?}"
    fi

    # Only 0 and 1 are accepted
    if test "${key_action:?}" -lt 0 || test "${key_action:?}" -gt 1; then
      ui_warning "Unsupported action: ${key_action?}"
      return 115
    fi

    hex_to_dec "${key_code:?}" || return 126

    return "$((key_action + 10))"

  done ||
    return "${?}"

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
    127) # COMMAND cannot be found (127) - NOTE: this return value may even be used when timeout is unable to execute the COMMAND
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
        printf '%s' 'Invalid choice!!!'
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
    test "${KEY_TEST_ONLY:?}" -eq 1 || printf '\r                 \r' # Clean invalid choice message (if printed)

    case "${_key?}" in
      '+') ;;                                        # + key (allowed)
      '-') ;;                                        # - key (allowed)
      'c' | 'C' | "${_esc_keycode:?}") _key='ESC' ;; # ESC or C key (allowed)
      '') continue ;;                                # Enter key (ignored)
      *)
        test "${KEY_TEST_ONLY:?}" -eq 1 || {
          printf '%s' 'Invalid choice!!!'
          continue
        }
        ;; # NOT allowed
    esac

    break
  done

  _choose_remapper "${_key:?}"
  return "${?}"
}

_inputevent_keycode_to_key()
{
  case "${1?}" in
    '') return 123 ;;

    "${INPUT_CODE_VOLUMEUP?}") printf '%s\n' '+' ;;
    "${INPUT_CODE_VOLUMEDOWN?}") printf '%s\n' '-' ;;
    "${INPUT_CODE_POWER?}") printf '%s\n' 'POWER' ;;

    "${INPUT_CODE_BACK?}") printf '%s\n' 'BACK' ;;
    "${INPUT_CODE_HOME?}") printf '%s\n' 'HOME' ;;
    "${INPUT_CODE_MENU?}") printf '%s\n' 'MENU' ;;
    "${INPUT_CODE_APP_SWITCH?}") printf '%s\n' 'APP SWITCH' ;; # Recent apps

    *)
      case "${1?}" in
        '115') printf '%s\n' '+' ;;
        '114') printf '%s\n' '-' ;;
        '116') printf '%s\n' 'POWER' ;;

        '158') printf '%s\n' 'BACK' ;;
        '102') printf '%s\n' 'HOME' ;;
        '139') printf '%s\n' 'MENU' ;;
        '221') printf '%s\n' 'APP SWITCH' ;; # Recent apps

        *) return 123 ;; # All other keys
      esac
      ;;

  esac
}

choose_inputevent()
{
  local _key _status _last_key_pressed _key_desc _ret

  test "${#}" -le 1 || ui_error "Key detection failed (input event) - invalid number of arguments"

  input_device_listener_start || {
    ui_msg_empty_line
    ui_warning "Key detection failed (input event)"
    ui_msg_empty_line
    return 1
  }

  _last_key_pressed=''

  while true; do
    _get_input_event "${1-}" || { # It set ${INPUT_EVENT_CURRENT}
      _status="${?}"
      input_device_listener_stop

      if test "${_status:?}" -eq 124; then
        ui_msg_empty_line
        ui_msg 'Key: No key pressed'
        ui_msg_empty_line
        return 0
      fi

      ui_warning "Key detection failed (input event) - get, status code: ${_status?}"
      return 1
    }

    if test -z "${INPUT_EVENT_SIZE-}"; then
      INPUT_EVENT_SIZE="$(_detect_input_event_size "${INPUT_EVENT_CURRENT?}")" || {
        _status="${?}"
        input_device_listener_stop
        ui_error "Key detection failed (input event) - size check, status code: ${_status?}"
      }
      if test "${INPUT_EVENT_SIZE:?}" -ne 24; then INPUT_EVENT_START_OFFSET="$((INPUT_EVENT_START_OFFSET - 24 + INPUT_EVENT_SIZE))"; fi
    fi

    _status=0
    _key="$(_parse_input_event "${INPUT_EVENT_CURRENT?}")" || _status="${?}"

    case "${_status:?}" in
      11) ;;           # Key press event (allowed)
      10) ;;           # Key release event (allowed)
      115) continue ;; # We got an unsupported event type or action (ignored)
      *)               # Event parsing failed (fail)
        input_device_listener_stop
        ui_error "Key detection failed (input event) - parse, status code: ${_status?}"
        ;;
    esac

    if test "${_key?}" = "${INPUT_CODE_POWER:-116}" && test "${KEY_TEST_ONLY:?}" -eq 0; then continue; fi # Power key (ignored completely)

    test "${#}" -eq 0 || shift # Remove timeout after the first successful key press / release event (excluding power key)

    if test "${KEY_TEST_ONLY:?}" -eq 1; then
      ui_msg "Event { Event type: 1, Key code: ${_key?}, Action: $((_status - 10)) }"
    elif test "${DEBUG_LOG_ENABLED:?}" -eq 1; then
      ui_debug ''
      ui_debug "Event { Event type: 1, Key code: ${_key?}, Action: $((_status - 10)) }"
    fi

    if :; then
      if test "${_status:?}" -eq 11; then
        # Key down
        if test "${_last_key_pressed?}" = ''; then
          _last_key_pressed="${_key?}" # One key pressed (waiting release)
        else
          _last_key_pressed=''
          ui_msg 'Key mismatch, ignored!!!' # Two keys pressed simultaneously (ignored)
        fi
        continue
      else
        # Key up
        if test -n "${_last_key_pressed?}" && test "${_key?}" = "${_last_key_pressed:?}"; then
          : # OK
        else
          _last_key_pressed='' # Key mismatch from earlier (ignored)
          continue
        fi
      fi
    fi

    _key_desc="$(_inputevent_keycode_to_key "${_key?}")" || _key_desc='Unknown'
    case "${_key_desc?}" in
      '+' | '-') ;; # Volume keys (allowed)
      'BACK')
        input_device_listener_stop
        ui_error 'Installation forcefully terminated' 143
        ;;
      *)
        _last_key_pressed=''
        test "${KEY_TEST_ONLY:?}" -eq 1 || {
          ui_msg "Invalid choice!!! Key: ${_key_desc?} (${_key?})"
          continue
        }
        ;;
    esac

    break
  done

  input_device_listener_stop

  _ret=1
  case "${_key_desc?}" in
    '+') _ret=3 ;;
    '-') _ret=2 ;;
    *) test "${KEY_TEST_ONLY:?}" -eq 1 || ui_error "Key detection failed (input event) - key, key code: ${_key?}" ;;
  esac

  ui_msg_empty_line
  ui_msg "Key press: ${_key_desc?} (${_key?})"
  ui_msg_empty_line

  return "${_ret:?}"
}

choose()
{
  local _last_status=0

  ui_msg "QUESTION: ${1:?}"
  test -z "${2?}" || ui_msg "${2:?}"
  test -z "${3?}" || ui_msg "${3:?}"
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

_live_setup_initialize()
{
  ui_msg_empty_line
  if test "${INPUT_FROM_TERMINAL:?}" = 'true'; then
    ui_msg 'Using: read'
  elif "${KEYCHECK_ENABLED:?}"; then
    ui_msg 'Using: keycheck'
  else
    ui_msg 'Using: input event'
    inputevent_initialize
  fi
  ui_msg_empty_line
}

_live_setup_key_test()
{
  local _count

  display_basic_info
  display_info

  _live_setup_initialize
  sleep '0.05'

  _count=0
  while test "${_count:?}" -lt 8 && _count="$((_count + 1))"; do
    choose "${_count:?}/8) Press any key" '' ''
  done

  ui_msg 'Many keys have been pressed, now you can rest ;-)'

  deinitialize
  exit 250
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

  if test -n "${1-}"; then
    ui_msg "Waiting input for ${1?} seconds..."
  else
    ui_msg "Waiting input..."
  fi
}

live_setup_choice()
{
  LIVE_SETUP_ENABLED='false'
  verify_keycheck_compatibility
  test "${KEY_TEST_ONLY:?}" -eq 0 || _live_setup_key_test

  if test "${LIVE_SETUP_ALLOWED:?}" = 'true'; then
    if test "${LIVE_SETUP_DEFAULT:?}" -ne 0; then
      LIVE_SETUP_ENABLED='true'
    elif test "${LIVE_SETUP_TIMEOUT:?}" -gt 0; then

      _live_setup_initialize
      _live_setup_choice_msg "${LIVE_SETUP_TIMEOUT}"

      if test "${INPUT_FROM_TERMINAL:?}" = 'true'; then
        choose_read_with_timeout "${LIVE_SETUP_TIMEOUT}"
      elif "${KEYCHECK_ENABLED:?}"; then
        choose_keycheck_with_timeout "${LIVE_SETUP_TIMEOUT}"
      else
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
soft_kill_app()
{
  test "${DRY_RUN:?}" -eq 0 || return

  if test "${BOOTMODE:?}" = 'true' && test -n "${DEVICE_AM?}"; then
    PATH="${PREVIOUS_PATH?}" "${DEVICE_AM:?}" 2> /dev/null kill "${1:?}" || true
  fi
}

kill_app()
{
  test "${DRY_RUN:?}" -eq 0 || return

  if test "${BOOTMODE:?}" = 'true' && test -n "${DEVICE_AM?}"; then
    PATH="${PREVIOUS_PATH?}" "${DEVICE_AM:?}" 2> /dev/null force-stop "${1:?}" || PATH="${PREVIOUS_PATH?}" "${DEVICE_AM:?}" 2> /dev/null kill "${1:?}" || true
  fi
}

disable_app()
{
  test "${DRY_RUN:?}" -eq 0 || return

  if test "${BOOTMODE:?}" = 'true' && test -n "${DEVICE_PM?}"; then
    PATH="${PREVIOUS_PATH?}" "${DEVICE_PM:?}" 2> /dev/null disable "${1:?}" || true
  fi
}

clear_app()
{
  test "${DRY_RUN:?}" -eq 0 || return

  if test "${BOOTMODE:?}" = 'true' && test -n "${DEVICE_PM?}"; then
    PATH="${PREVIOUS_PATH?}" "${DEVICE_PM:?}" 2> /dev/null clear "${1:?}" || true
  fi
}

clear_and_enable_app()
{
  test "${DRY_RUN:?}" -eq 0 || return

  if test "${BOOTMODE:?}" = 'true' && test -n "${DEVICE_PM?}"; then
    PATH="${PREVIOUS_PATH?}" "${DEVICE_PM:?}" 2> /dev/null clear "${1:?}" || true
    PATH="${PREVIOUS_PATH?}" "${DEVICE_PM:?}" 2> /dev/null enable "${1:?}" || true
  fi
}

reset_authenticator_and_sync_adapter_caches()
{
  test "${DRY_RUN:?}" -eq 0 || return

  # Reset to avoid problems with signature changes
  if test -n "${DATA_PATH?}"; then
    delete "${DATA_PATH:?}"/system/registered_services/android.accounts.AccountAuthenticator.xml
    delete "${DATA_PATH:?}"/system/registered_services/android.content.SyncAdapter.xml
    delete "${DATA_PATH:?}"/system/users/*/registered_services/android.accounts.AccountAuthenticator.xml
    delete "${DATA_PATH:?}"/system/users/*/registered_services/android.content.SyncAdapter.xml
    delete "${DATA_PATH:?}"/system/uiderrors.txt
  fi
}

parse_busybox_version()
{
  grep -m 1 -o -e 'BusyBox v[0-9]*\.[0-9]*\.[0-9]*' | cut -d 'v' -f '2-' -s
}

numerically_comparable_version()
{
  echo "${@}" | awk -F. '{ printf("%u%03u%03u%03u\n", $1, $2, $3, $4); }'
}

remove_ext()
{
  local str="${1}"
  printf '%s\n' "${str%.*}"
}

# Find test: this is useful to test 'find' - if every file/folder, even the ones with spaces, is displayed in a single line then your version is good
find_test()
{
  find "$1" -type d -exec echo 'FOLDER:' '{}' ';' -o -type f -exec echo 'FILE:' '{}' ';' | while read -r x; do echo "${x}"; done
}

### INITIALIZATION ###

initialize || exit "${?}"
