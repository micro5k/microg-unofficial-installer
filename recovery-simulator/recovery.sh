#!/usr/bin/env bash
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

# NOTE: This script simulate a real recovery but it relies on the flashable zip to use the suggested paths.
# REALLY IMPORTANT: A misbehaving flashable zip can damage your real system.

# shellcheck enable=all
# shellcheck disable=SC2310 # This function is invoked in an XXX condition so set -e will be disabled. Invoke separately if failures should cause the script to exit

set -e
# shellcheck disable=SC3040,SC3041,SC2015
{
  # Unsupported set options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue
  (set -o posix 2> /dev/null) && set -o posix || true
  (set +H 2> /dev/null) && set +H || true
  (set -o pipefail) && set -o pipefail || true
}

# shellcheck disable=SC3028
case ":${SHELLOPTS-}:" in
  *':xtrace:'*) # Auto-enable `set -x` for shells that do NOT support SHELLOPTS
    set -x
    export COVERAGE='true'
    ;;
  *) ;;
esac

fail_with_msg()
{
  echo "${1:?}"
  exit 1
}

show_cmdline()
{
  printf "'%s'" "${0-}"
  if test "${#}" -gt 0; then printf " '%s'" "${@}"; fi
  printf '\n'
}

detect_os_and_other_things()
{
  if test -n "${PLATFORM-}"; then return; fi

  PLATFORM="$(uname | tr -- '[:upper:]' '[:lower:]')"
  IS_BUSYBOX='false'
  PATHSEP=':'
  CYGPATH=''

  case "${PLATFORM?}" in
    'linux') ;;   # Returned by both Linux and Android, Android will be identified later in the function
    'android') ;; # Currently never returned by Android
    'windows_nt') # BusyBox-w32 on Windows => Windows_NT
      PLATFORM='win'
      IS_BUSYBOX='true'
      ;;
    'msys_'* | 'cygwin_'* | 'mingw32_'* | 'mingw64_'*) PLATFORM='win' ;;
    'windows'*) PLATFORM='win' ;; # Unknown shell on Windows
    'darwin') PLATFORM='macos' ;;
    'freebsd') ;;
    '') PLATFORM='unknown' ;;

    *)
      # Output of uname -o:
      # - MinGW => Msys
      # - MSYS => Msys
      # - Cygwin => Cygwin
      # - BusyBox-w32 => MS/Windows
      case "$(uname 2> /dev/null -o | tr -- '[:upper:]' '[:lower:]')" in
        'ms/windows')
          PLATFORM='win'
          IS_BUSYBOX='true'
          ;;
        'msys' | 'cygwin') PLATFORM='win' ;;
        *) PLATFORM="$(printf '%s\n' "${PLATFORM:?}" | tr -d '/')" || fail_with_msg 'Failed to get uname' ;;
      esac
      ;;
  esac

  # Android identify itself as Linux
  if test "${PLATFORM?}" = 'linux'; then
    case "$(uname 2> /dev/null -a | tr -- '[:upper:]' '[:lower:]')" in
      *' android'* | *'-lineage-'* | *'-leapdroid-'*) PLATFORM='android' ;;
      *) ;;
    esac
  fi

  if test "${PLATFORM:?}" = 'win' && test "${IS_BUSYBOX:?}" = 'true'; then
    PATHSEP=';'
  fi

  if test "${PLATFORM:?}" = 'win' && test "${IS_BUSYBOX:?}" = 'false' && PATH="/usr/bin${PATHSEP:?}${PATH-}" command 1> /dev/null -v 'cygpath'; then
    CYGPATH="$(PATH="/usr/bin${PATHSEP:?}${PATH-}" command -v cygpath)" || fail_with_msg 'Unable to find the path of cygpath'
  fi

  readonly PLATFORM IS_BUSYBOX PATHSEP CYGPATH
}

is_in_path_env()
{
  case "${PATHSEP:?}${PATH-}${PATHSEP:?}" in
    *"${PATHSEP:?}${1:?}${PATHSEP:?}"*) return 0 ;; # Found
    *) ;;
  esac
  return 1 # NOT found
}

add_to_path_env()
{
  if test -n "${CYGPATH?}"; then
    # Only on Bash under Windows
    local _path
    _path="$("${CYGPATH:?}" -u -a -- "${1:?}")" || fail_with_msg 'Unable to convert a path in add_to_path_env()'
    set -- "${_path:?}"
  fi

  if is_in_path_env "${1:?}" || test ! -e "${1:?}"; then return; fi

  if test -z "${PATH-}"; then
    PATH="${1:?}"
  else
    PATH="${1:?}${PATHSEP:?}${PATH:?}"
  fi
}

move_to_begin_of_path_env()
{
  local _path
  if test ! -e "${1:?}"; then return; fi

  if test -z "${PATH-}"; then
    PATH="${1:?}"
  elif _path="$(printf '%s\n' "${PATH:?}" | tr -- "${PATHSEP:?}" '\n' | grep -v -x -F -e "${1:?}" | tr -- '\n' "${PATHSEP:?}")" && _path="${_path%"${PATHSEP:?}"}" && test -n "${_path?}"; then
    PATH="${1:?}${PATHSEP:?}${_path:?}"
  fi
}

init_path()
{
  test "${IS_PATH_INITIALIZED:-false}" = 'false' || return
  readonly IS_PATH_INITIALIZED='true'

  if test -n "${PATH-}"; then PATH="${PATH%"${PATHSEP:?}"}"; fi
  # On Bash under Windows (for example the one included inside Git for Windows) we need to move '/usr/bin'
  # before 'C:/Windows/System32' otherwise it will use the find/sort/etc. of Windows instead of the Unix compatible ones.
  if test "${PLATFORM:?}" = 'win' && test "${IS_BUSYBOX:?}" = 'false'; then move_to_begin_of_path_env '/usr/bin'; fi

  add_to_path_env "$(realpath "${THIS_SCRIPT_DIR:?}/../tools/${PLATFORM:?}" || true)" || fail_with_msg 'Unable to add the tools dir to the PATH env'
}

create_junction()
{
  if test "${PLATFORM:?}" != 'win' || test "${IS_BUSYBOX:?}" = 'false'; then return 1; fi
  jn -- "${1:?}" "${2:?}"
}

link_folder()
{
  ln -sf "${2:?}" "${1:?}" 2> /dev/null || create_junction "${2:?}" "${1:?}" || mkdir -p "${1:?}" || fail_with_msg "Failed to link dir '${1}' to '${2}'"
}

remove_folder_link()
{
  if test -h "${1:?}"; then
    rm -f -- "${1:?}"
  else
    rmdir -- "${1:?}"
  fi
}

recovery_flash_start()
{
  if test "${1:?}" = 'false'; then
    echo "I:Set page: 'install'"
    echo "I:Set page: 'flash_confirm'"
    echo "I:Set page: 'flash_zip'"
    echo "I:operation_start: 'Flashing'"
  fi

  echo "Installing zip file '${2:?}'"
  echo "Checking for MD5 file..."
  echo "Skipping MD5 check: no MD5 file found"
  #echo "MD5 matched for '${2:?}'."

  if test "${1:?}" = 'false'; then
    echo "I:Update binary zip"
  fi
}

recovery_flash_end()
{
  if test "${2:?}" -ne 0; then
    echo "Updater process ended with ERROR: ${2:?}"
    if test "${1:?}" = 'false'; then
      echo "I:Install took ... second(s)."
    fi
    echo "Error installing zip file '${3:?}'"
  elif test "${1:?}" = 'false'; then
    echo "I:Updater process ended with RC=0"
    echo "I:Install took ... second(s)."
  fi

  echo "Updating partition details..."
  echo "...done"

  if test "${1:?}" = 'false'; then
    echo "I:Set page: 'flash_done'"
    if test "${2:?}" -eq 0; then
      echo "I:operation_end - status=0"
    else
      echo "I:operation_end - status=1"
    fi
    echo "I:Set page: 'clear_vars'"

    echo "I:Set page: 'copylog'"
    echo "I:Set page: 'action_page'"
    echo "I:operation_start: 'Copy Log'"
    echo "I:Copying file /tmp/recovery.log to /sdcard1/recovery.log"
  else
    echo "Copied recovery log to /sdcard1/recovery.log."
  fi

  echo ''
}

# Reset environment
if test "${ENV_RESETTED:-false}" = 'false'; then
  printf '%s\n' 'FULL COMMAND LINE:'
  show_cmdline "${@}"
  printf '\n'

  if test "${#}" -eq 0; then fail_with_msg 'You must pass the filename of the flashable ZIP as parameter'; fi

  THIS_SCRIPT="$(realpath "${0:?}" 2> /dev/null)" || fail_with_msg 'Failed to get script filename'

  reset_env_and_rerun_myself()
  {
    if test "${COVERAGE:-false}" = 'false'; then
      exec env -i -- ENV_RESETTED=true PATH="${PATH:?}" BB_GLOBBING='0' THIS_SCRIPT="${THIS_SCRIPT:?}" TMPDIR="${TMPDIR:-${RUNNER_TEMP:-${TMP:-${TEMP:-/tmp}}}}" DEBUG_LOG="${DEBUG_LOG-}" LIVE_SETUP_ALLOWED="${LIVE_SETUP_ALLOWED-}" FORCE_HW_BUTTONS="${FORCE_HW_BUTTONS-}" CI="${CI-}" bash -- "${THIS_SCRIPT:?}" "${@}"
    else
      exec env -i -- ENV_RESETTED=true PATH="${PATH:?}" BB_GLOBBING='0' THIS_SCRIPT="${THIS_SCRIPT:?}" TMPDIR="${TMPDIR:-${RUNNER_TEMP:-${TMP:-${TEMP:-/tmp}}}}" DEBUG_LOG="${DEBUG_LOG-}" LIVE_SETUP_ALLOWED="${LIVE_SETUP_ALLOWED-}" FORCE_HW_BUTTONS="${FORCE_HW_BUTTONS-}" CI="${CI-}" BASH_XTRACEFD="${BASH_XTRACEFD-}" BASH_ENV="${BASH_ENV-}" OLDPWD="${OLDPWD-}" SHELLOPTS="${SHELLOPTS-}" PS4="${PS4-}" bash -x -- "${THIS_SCRIPT:?}" "${@}"
    fi
  }

  reset_env_and_rerun_myself "${@}" || fail_with_msg 'failed: exec'
  exit 127
fi
unset ENV_RESETTED
if test -z "${DEBUG_LOG-}"; then unset DEBUG_LOG; fi
if test -z "${LIVE_SETUP_ALLOWED-}"; then unset LIVE_SETUP_ALLOWED; fi
if test -z "${FORCE_HW_BUTTONS-}"; then unset FORCE_HW_BUTTONS; fi

if test -z "${CI-}"; then unset CI; fi
if test -z "${SHELLOPTS-}"; then unset SHELLOPTS; fi

detect_os_and_other_things

if test -n "${CYGPATH?}" && test "${TMPDIR?}" = '/tmp'; then
  # Workaround for issues with Bash under Windows (for example the one included inside Git for Windows)
  TMPDIR="$("${CYGPATH:?}" -m -a -l -- '/tmp')" || fail_with_msg 'Unable to convert the temp directory'
fi

# Create our temp dir (must be done with a valid TMPDIR env var)
export TMPDIR
OUR_TEMP_DIR="$(mktemp -d -t ANDR-RECOV-XXXXXX)" || fail_with_msg 'Failed to create our temp dir'
readonly OUR_TEMP_DIR

# Get dir of this script
THIS_SCRIPT_DIR="$(dirname "${THIS_SCRIPT:?}")" || fail_with_msg 'Failed to get script dir'
unset THIS_SCRIPT

init_path

# Backup original variables
_backup_path="${PATH?}"
_backup_tmpdir="${TMPDIR:?}"
readonly _backup_path _backup_tmpdir

# Check dependencies
_our_busybox="$(env -- which -- busybox)" || fail_with_msg 'BusyBox is missing'
_tee_cmd="$(command -v tee)" || fail_with_msg 'tee is missing'
readonly _our_busybox _tee_cmd

if test "${COVERAGE:-false}" != 'false'; then
  _bash_cmd="$(command -v bash)" || fail_with_msg 'bash is missing'
  readonly _bash_cmd
fi

case "${*}" in
  *'*.zip') fail_with_msg 'The flashable ZIP is missing, you have to build it before being able to test it' ;;
  *) ;;
esac

for param in "${@}"; do
  shift
  if ! test -f "${param:?Empty value passed}"; then fail_with_msg "Missing file: ${param}"; fi
  param="$(realpath "${param:?}")" || fail_with_msg "Invalid filename: ${param}"
  set -- "${@}" "${param:?}"
done
unset param

# Ensure we have a path for the temp dir and empty it (should be already empty, but we must be sure)
test -n "${OUR_TEMP_DIR-}" || fail_with_msg 'Failed to get a temp dir'
mkdir -p -- "${OUR_TEMP_DIR:?}" || fail_with_msg 'Failed to create our temp dir'
rm -rf -- "${OUR_TEMP_DIR:?}"/* || fail_with_msg 'Failed to empty our temp dir'

# Setup the needed variables
_base_simulation_path="${OUR_TEMP_DIR:?}/root-dir"
_our_overrider_dir="${THIS_SCRIPT_DIR:?}/override"
_our_overrider_script="${THIS_SCRIPT_DIR:?}/inc/configure-overrides.sh"
_init_dir="$(pwd)" || fail_with_msg 'Failed to read the current dir'

readonly _base_simulation_path _our_overrider_dir _our_overrider_script _init_dir

# Configure the Android recovery environment variables (they will be used later)
_android_ext_stor="${_base_simulation_path:?}/sdcard0"
_android_sec_stor="${_base_simulation_path:?}/sdcard1"
_android_lib_path=".:${_base_simulation_path:?}/sbin"
_android_data="${_base_simulation_path:?}/data"
_android_sys="${_base_simulation_path:?}/system"
_android_path="${_our_overrider_dir:?}:${_android_sys:?}/bin"
_android_tmp="${_base_simulation_path:?}/tmp"

_android_busybox="${_android_sys:?}/bin/busybox"

readonly _android_ext_stor _android_sec_stor _android_lib_path _android_data _android_sys _android_path _android_tmp _android_busybox

# Simulate the Android recovery environment inside the temp folder
mkdir -p "${_base_simulation_path:?}"
cd "${_base_simulation_path:?}" || fail_with_msg 'Failed to change dir to the base simulation path'
mkdir -p "${_android_tmp:?}"
mkdir -p "${_android_sys:?}"
mkdir -p "${_android_sys:?}/addon.d"
mkdir -p "${_android_sys:?}/etc"
mkdir -p "${_android_sys:?}/priv-app"
mkdir -p "${_android_sys:?}/app"
mkdir -p "${_android_sys:?}/bin"
mkdir -p "${_android_data:?}"
mkdir -p "${_android_ext_stor:?}"
mkdir -p "${_android_sec_stor:?}"
touch "${_android_tmp:?}/recovery.log"
link_folder "${_base_simulation_path:?}/sbin" "${_android_sys:?}/bin"
link_folder "${_base_simulation_path:?}/sdcard" "${_android_ext_stor:?}"

{
  echo 'ro.build.characteristics=phone,emulator'
  echo 'ro.build.version.sdk=26'
  echo 'ro.product.brand=Android'
  echo 'ro.product.cpu.abi2=x86'
  echo 'ro.product.cpu.abi=x86_64'
  echo 'ro.product.cpu.abilist32=x86,armeabi-v7a,armeabi'
  echo 'ro.product.cpu.abilist64=x86_64,arm64-v8a'
  echo 'ro.product.cpu.abilist=x86_64,x86,arm64-v8a,armeabi-v7a,armeabi'
  echo 'ro.product.device=emu64x'
  echo 'ro.product.manufacturer=ale5000'
} 1> "${_android_sys:?}/build.prop"

touch "${_base_simulation_path:?}/AndroidManifest.xml"
printf 'a\0n\0d\0r\0o\0i\0d\0.\0p\0e\0r\0m\0i\0s\0s\0i\0o\0n\0.\0F\0A\0K\0E\0_\0P\0A\0C\0K\0A\0G\0E\0_\0S\0I\0G\0N\0A\0T\0U\0R\0E\0' 1> "${_base_simulation_path:?}/AndroidManifest.xml"
mkdir -p "${_android_sys:?}/framework"
zip -D -9 -X -UN=n -nw -q "${_android_sys:?}/framework/framework-res.apk" 'AndroidManifest.xml' || fail_with_msg 'Failed compressing framework-res.apk'
rm -f -- "${_base_simulation_path:?}/AndroidManifest.xml"

cp -pf -- "${THIS_SCRIPT_DIR:?}/updater.sh" "${_android_tmp:?}/updater" || fail_with_msg 'Failed to copy the updater script'
chmod +x "${_android_tmp:?}/updater" || fail_with_msg "chmod failed on '${_android_tmp?}/updater'"

if test "${COVERAGE:-false}" != 'false'; then
  cd "${_init_dir:?}" || fail_with_msg 'Failed to change back the folder'
fi

# Detect whether "export -f" is supported (0 means supported)
_is_export_f_supported=0
{
  test_export_f()
  {
    # shellcheck disable=SC2216,SC3045
    : | export -f -- test_export_f 2> /dev/null
    return "${?}"
  }
  test_export_f || _is_export_f_supported="${?}"
  unset -f test_export_f
}

override_command()
{
  if test ! -e "${_our_overrider_dir:?}/${1:?}"; then return 1; fi

  rm -f -- "${_android_sys:?}/bin/${1:?}" || return "${?}"
  unset -f -- "${1:?}" || return "${?}"

  eval " ${1:?}() { '${_our_overrider_dir:?}/${1:?}' \"\${@}\"; }" || return "${?}" # The folder expands when defined, not when used

  if test "${_is_export_f_supported:?}" -eq 0; then
    # shellcheck disable=SC3045
    export -f -- "${1:?}"
  fi
}

simulate_env()
{
  cp -pf -- "${_our_busybox:?}" "${_android_busybox:?}" || fail_with_msg 'Failed to copy BusyBox'

  if test "${PLATFORM:?}" != 'win'; then
    "${_android_busybox:?}" --install -s "${_android_sys:?}/bin" || fail_with_msg 'Failed to install BusyBox'
  else
    "${_android_busybox:?}" --install "${_android_sys:?}/bin" || fail_with_msg 'Failed to install BusyBox'
  fi

  override_command mount || return 123
  override_command umount || return 123
  override_command chown || return 123
  override_command su || return 123
  override_command sudo || return 123

  export EXTERNAL_STORAGE="${_android_ext_stor:?}"
  export SECONDARY_STORAGE="${_android_sec_stor:?}"
  export LD_LIBRARY_PATH="${_android_lib_path:?}"
  export ANDROID_DATA="${_android_data:?}"
  export PATH="${_android_path:?}"
  export ANDROID_ROOT="${_android_sys:?}"
  export ANDROID_PROPERTY_WORKSPACE='21,32768'
  export TZ='CET-1CEST,M3.5.0,M10.5.0'
  export TMPDIR="${_android_tmp:?}"

  # Our custom variables
  export CUSTOM_BUSYBOX="${_android_busybox:?}"
  export OVERRIDE_DIR="${_our_overrider_dir:?}"
  export RS_OVERRIDE_SCRIPT="${_our_overrider_script:?}"
  export TEST_INSTALL=true
}

restore_env()
{
  local _backup_ifs

  export PATH="${_backup_path?}"
  export TMPDIR="${_backup_tmpdir:?}"

  unset BB_OVERRIDE_APPLETS
  unset CUSTOM_BUSYBOX

  unset -f -- mount umount chown su sudo

  "${_our_busybox:?}" 2> /dev/null --uninstall "${_android_busybox:?}" || true

  # Fallback if --uninstall is NOT supported
  {
    _backup_ifs="${IFS-}"
    IFS=' '
    find "${_android_sys:?}/bin" -type l -exec sh -c 'bb_path="${1:?}"; shift; if test "$(realpath "${*}")" = "${bb_path:?}"; then rm -f -- "${*}"; fi' _ "${_android_busybox:?}" '{}' ';' || true
    IFS="${_backup_ifs-}"

    rm -f -- "${_android_busybox:?}" || true
  }
}

# Setup recovery output
recovery_fd=99
recovery_logs_dir="${THIS_SCRIPT_DIR:?}/output"
if test -e "/proc/self/fd/${recovery_fd:?}"; then fail_with_msg 'Recovery FD already exist'; fi
mkdir -p "${recovery_logs_dir:?}"
touch "${recovery_logs_dir:?}/recovery-raw.log" "${recovery_logs_dir:?}/recovery-output-raw.log" "${recovery_logs_dir:?}/recovery-stdout.log" "${recovery_logs_dir:?}/recovery-stderr.log"

if test "${PLATFORM:?}" != 'win'; then
  sudo chattr +aAd "${recovery_logs_dir:?}/recovery-raw.log" || fail_with_msg "chattr failed on 'recovery-raw.log'"
  sudo chattr +aAd "${recovery_logs_dir:?}/recovery-output-raw.log" || fail_with_msg "chattr failed on 'recovery-output-raw.log'"
  sudo chattr +aAd "${recovery_logs_dir:?}/recovery-stdout.log" || fail_with_msg "chattr failed on 'recovery-stdout.log'"
  sudo chattr +aAd "${recovery_logs_dir:?}/recovery-stderr.log" || fail_with_msg "chattr failed on 'recovery-stderr.log'"
fi

# shellcheck disable=SC3023
exec 99> >("${_tee_cmd:?}" -a "${recovery_logs_dir:?}/recovery-raw.log" "${recovery_logs_dir:?}/recovery-output-raw.log" || true)

flash_zips()
{
  for _current_zip_fullpath in "${@}"; do
    FLASHABLE_ZIP_NAME="$(basename "${_current_zip_fullpath:?}")" || fail_with_msg 'Failed to get the filename of the flashable ZIP'
    cp -f -- "${_current_zip_fullpath:?}" "${_android_sec_stor:?}/${FLASHABLE_ZIP_NAME:?}" || fail_with_msg 'Failed to copy the flashable ZIP'

    # Simulate the environment variables of a real recovery
    simulate_env || return "${?}"

    "${_android_busybox:?}" unzip -opq "${_android_sec_stor:?}/${FLASHABLE_ZIP_NAME:?}" 'META-INF/com/google/android/update-binary' > "${_android_tmp:?}/update-binary" || fail_with_msg 'Failed to extract the update-binary'

    echo "custom_flash_start ${_android_sec_stor:?}/${FLASHABLE_ZIP_NAME:?}" 1>&"${recovery_fd:?}"
    set +e
    # Execute the script that will run the flashable zip
    if test "${COVERAGE:-false}" = 'false'; then
      "${_android_busybox:?}" sh -- "${_android_tmp:?}/updater" 3 "${recovery_fd:?}" "${_android_sec_stor:?}/${FLASHABLE_ZIP_NAME:?}" 1> >("${_tee_cmd:?}" -a "${recovery_logs_dir:?}/recovery-raw.log" "${recovery_logs_dir:?}/recovery-stdout.log" || true) 2> >("${_tee_cmd:?}" -a "${recovery_logs_dir:?}/recovery-raw.log" "${recovery_logs_dir:?}/recovery-stderr.log" 1>&2 || true)
    else
      "${_bash_cmd:?}" -x -- "${THIS_SCRIPT_DIR:?}/updater.sh" 3 "${recovery_fd:?}" "${_android_sec_stor:?}/${FLASHABLE_ZIP_NAME:?}" 1> >("${_tee_cmd:?}" -a "${recovery_logs_dir:?}/recovery-raw.log" "${recovery_logs_dir:?}/recovery-stdout.log" || true) 2> >("${_tee_cmd:?}" -a "${recovery_logs_dir:?}/recovery-raw.log" "${recovery_logs_dir:?}/recovery-stderr.log" 1>&2 || true)
    fi
    STATUS="${?}"
    set -e
    echo "custom_flash_end ${STATUS:?}" 1>&"${recovery_fd:?}"
    echo ''

    restore_env || return "${?}"
    if test "${STATUS:?}" -ne 0; then return "${STATUS:?}"; fi
  done
}
STATUS=0
flash_zips "${@}" || STATUS="${?}"

# Close recovery output
# shellcheck disable=SC3023
exec 99>&-

if test "${PLATFORM:?}" != 'win'; then
  sudo chattr -a "${recovery_logs_dir:?}/recovery-raw.log" || fail_with_msg "chattr failed on 'recovery-raw.log'"
  sudo chattr -a "${recovery_logs_dir:?}/recovery-output-raw.log" || fail_with_msg "chattr failed on 'recovery-output-raw.log'"
  sudo chattr -a "${recovery_logs_dir:?}/recovery-stdout.log" || fail_with_msg "chattr failed on 'recovery-stdout.log'"
  sudo chattr -a "${recovery_logs_dir:?}/recovery-stderr.log" || fail_with_msg "chattr failed on 'recovery-stderr.log'"
fi

parse_recovery_output()
{
  _last_zip_name=''
  while IFS='' read -r full_line; do
    ui_command=''
    for elem in ${full_line?}; do
      ui_command="${elem?}"
      break
    done
    if test "${ui_command?}" = 'ui_print'; then
      if test "${#full_line}" -gt 9; then echo "${full_line#ui_print }"; fi
    elif test "${ui_command?}" = 'custom_flash_start'; then
      _last_zip_name="${full_line#custom_flash_start }"
      recovery_flash_start "${1:?}" "${_last_zip_name:?}"
    elif test "${ui_command?}" = 'custom_flash_end'; then
      recovery_flash_end "${1:?}" "${full_line#custom_flash_end }" "${_last_zip_name:?}"
    else
      echo "> ${full_line?}"
    fi
  done < "${2:?}" 1> "${3:?}"
}

# Parse recovery output
parse_recovery_output true "${recovery_logs_dir:?}/recovery-output-raw.log" "${recovery_logs_dir:?}/recovery-output.log"
parse_recovery_output false "${recovery_logs_dir:?}/recovery-raw.log" "${recovery_logs_dir:?}/recovery.log"

# List installed files
remove_folder_link "${_base_simulation_path:?}/sbin" || true
remove_folder_link "${_base_simulation_path:?}/sdcard" || true
rm -f -- "${_android_sys:?}/build.prop" || true
rm -f -- "${_android_sys:?}/framework/framework-res.apk" || true
cd "${OUR_TEMP_DIR:?}" || fail_with_msg 'Failed to change dir to our temp dir'
TZ=UTC find "${_base_simulation_path:?}" -exec touch -c -h -t '202001010000' -- '{}' '+' || true
TZ=UTC ls -A -R -F -l -n --color='never' -- 'root-dir' 1> "${recovery_logs_dir:?}/installed-files.log" || true

# Final cleanup
cd "${_init_dir:?}" || fail_with_msg 'Failed to change back the folder'
rm -rf -- "${OUR_TEMP_DIR:?}" &
set +e
if test "${STATUS:?}" -ne 0; then exit "${STATUS:?}"; fi
