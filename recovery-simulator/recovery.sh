#!/usr/bin/env bash
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

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
case ":${SHELLOPTS:-}:" in
  *':xtrace:'*) # Auto-enable `set -x` for shells that do NOT support SHELLOPTS
    set -x
    COVERAGE='true'
    ;;
  *) ;;
esac

show_cmdline()
{
  printf "'%s'" "${0-}"
  if test "${#}" -gt 0; then printf " '%s'" "${@}"; fi
  printf '\n'
}

detect_os()
{
  if test -n "${PLATFORM-}"; then return; fi

  PLATFORM="$(uname | tr -- '[:upper:]' '[:lower:]')"
  IS_BUSYBOX='false'

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
        *) PLATFORM="$(printf '%s\n' "${PLATFORM:?}" | tr -d '/')" || ui_error 'Failed to get uname' ;;
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

  readonly PLATFORM IS_BUSYBOX
  export PLATFORM IS_BUSYBOX
}

detect_path_sep()
{
  if test "${PLATFORM:?}" = 'win' && test "${IS_BUSYBOX:?}" = 'true'; then
    printf ';\n'
  else
    printf ':\n'
  fi
}

fail_with_msg()
{
  echo "${1:?}"
  exit 1
}

create_junction()
{
  if test "${uname_o_saved}" != 'MS/Windows'; then return 1; fi
  jn -- "${1:?}" "${2:?}"
}

link_folder()
{
  ln -sf "${2:?}" "${1:?}" 2> /dev/null || create_junction "${2:?}" "${1:?}" || mkdir -p "${1:?}" || fail_with_msg "Failed to link dir '${1}' to '${2}'"
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
  if is_in_path_env "${1:?}" || test ! -e "${1:?}"; then return; fi

  if test -z "${PATH-}"; then
    PATH="${1:?}"
  else
    PATH="${1:?}${PATHSEP:?}${PATH:?}"
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
  # Create the temp dir (must be done before resetting environment)
  OUR_TEMP_DIR="$(mktemp -d -t ANDR-RECOV-XXXXXX)" || fail_with_msg 'Failed to create our temp dir'

  if test "${APP_BASE_NAME:-false}" = 'gradlew' || test "${APP_BASE_NAME:-false}" = 'gradlew.'; then
    APP_NAME='Gradle'
  fi

  if test "${COVERAGE:-false}" = 'false'; then
    exec env -i -- ENV_RESETTED=true BB_GLOBBING='0' THIS_SCRIPT="${THIS_SCRIPT:?}" OUR_TEMP_DIR="${OUR_TEMP_DIR:?}" DEBUG_LOG="${DEBUG_LOG:-}" LIVE_SETUP_ALLOWED="${LIVE_SETUP_ALLOWED:-}" FORCE_HW_BUTTONS="${FORCE_HW_BUTTONS:-}" CI="${CI:-}" APP_NAME="${APP_NAME:-}" SHELLOPTS="${SHELLOPTS:-}" SHELL="${SHELL:-}" PATH="${PATH:?}" bash -- "${THIS_SCRIPT:?}" "${@}" || fail_with_msg 'failed: exec'
  else
    exec env -i -- ENV_RESETTED=true BB_GLOBBING='0' THIS_SCRIPT="${THIS_SCRIPT:?}" OUR_TEMP_DIR="${OUR_TEMP_DIR:?}" DEBUG_LOG="${DEBUG_LOG:-}" LIVE_SETUP_ALLOWED="${LIVE_SETUP_ALLOWED:-}" FORCE_HW_BUTTONS="${FORCE_HW_BUTTONS:-}" CI="${CI:-}" APP_NAME="${APP_NAME:-}" SHELLOPTS="${SHELLOPTS:-}" SHELL="${SHELL:-}" PATH="${PATH:?}" COVERAGE="true" bashcov -- "${THIS_SCRIPT:?}" "${@}" || fail_with_msg 'failed: exec'
  fi
  exit 127
fi
unset ENV_RESETTED
if test -z "${DEBUG_LOG-}"; then unset DEBUG_LOG; fi
if test -z "${LIVE_SETUP_ALLOWED-}"; then unset LIVE_SETUP_ALLOWED; fi
if test -z "${FORCE_HW_BUTTONS-}"; then unset FORCE_HW_BUTTONS; fi

if test -z "${CI-}"; then unset CI; fi
if test -z "${APP_NAME-}"; then unset APP_NAME; fi
if test -z "${SHELLOPTS-}"; then unset SHELLOPTS; fi
_backup_path="${PATH:?}"
uname_o_saved="$(uname -o)" || fail_with_msg 'Failed to get uname -o'

# Set variables that we need
detect_os
if test -z "${PATHSEP-}"; then PATHSEP="$(detect_path_sep)"; fi
readonly PATHSEP

# Get dir of this script
THIS_SCRIPT_DIR="$(dirname "${THIS_SCRIPT:?}")" || fail_with_msg 'Failed to get script dir'
unset THIS_SCRIPT

add_to_path_env "${THIS_SCRIPT_DIR:?}/../tools/${PLATFORM:?}"

# Check dependencies
_our_busybox="$(env -- which -- busybox)" || fail_with_msg 'BusyBox is missing'
if test "${COVERAGE:-false}" != 'false'; then
  COVERAGE="$(command -v bashcov)" || fail_with_msg 'Bashcov is missing'
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
test -n "${OUR_TEMP_DIR:-}" || fail_with_msg 'Failed to get a temp dir'
mkdir -p -- "${OUR_TEMP_DIR:?}" || fail_with_msg 'Failed to create our temp dir'
rm -rf -- "${OUR_TEMP_DIR:?}"/* || fail_with_msg 'Failed to empty our temp dir'

# Setup the needed variables
BASE_SIMULATION_PATH="${OUR_TEMP_DIR}/root"                           # Internal var
_our_overrider_dir="${THIS_SCRIPT_DIR}/override"                      # Internal var
_our_overrider_script="${THIS_SCRIPT_DIR}/inc/configure-overrides.sh" # Internal var
_init_dir="$(pwd)" || fail_with_msg 'Failed to read the current dir'

# Configure the Android recovery environment variables (they will be used later)
_android_tmp="${BASE_SIMULATION_PATH}/tmp"
_android_sys="${BASE_SIMULATION_PATH}/system"
_android_data="${BASE_SIMULATION_PATH}/data"
_android_ext_stor="${BASE_SIMULATION_PATH}/sdcard0"
_android_sec_stor="${BASE_SIMULATION_PATH}/sdcard1"
_android_path="${_our_overrider_dir}:${BASE_SIMULATION_PATH}/sbin:${_android_sys}/bin"
_android_lib_path=".:${BASE_SIMULATION_PATH}/sbin"

# Simulate the Android recovery environment inside the temp folder
mkdir -p "${BASE_SIMULATION_PATH}"
cd "${BASE_SIMULATION_PATH}" || fail_with_msg 'Failed to change dir to the base simulation path'
mkdir -p "${_android_tmp}"
mkdir -p "${_android_sys}"
mkdir -p "${_android_sys}/addon.d"
mkdir -p "${_android_sys}/etc"
mkdir -p "${_android_sys}/priv-app"
mkdir -p "${_android_sys}/app"
mkdir -p "${_android_sys}/bin"
mkdir -p "${_android_data}"
mkdir -p "${_android_ext_stor}"
mkdir -p "${_android_sec_stor}"
touch "${_android_tmp}/recovery.log"
link_folder "${BASE_SIMULATION_PATH:?}/sbin" "${_android_sys:?}/bin"
link_folder "${BASE_SIMULATION_PATH:?}/sdcard" "${_android_ext_stor:?}"

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

touch "${BASE_SIMULATION_PATH:?}/AndroidManifest.xml"
printf 'a\0n\0d\0r\0o\0i\0d\0.\0p\0e\0r\0m\0i\0s\0s\0i\0o\0n\0.\0F\0A\0K\0E\0_\0P\0A\0C\0K\0A\0G\0E\0_\0S\0I\0G\0N\0A\0T\0U\0R\0E\0' 1> "${BASE_SIMULATION_PATH:?}/AndroidManifest.xml"
mkdir -p "${_android_sys:?}/framework"
zip -D -9 -X -UN=n -nw -q "${_android_sys:?}/framework/framework-res.apk" 'AndroidManifest.xml' || fail_with_msg 'Failed compressing framework-res.apk'
rm -f -- "${BASE_SIMULATION_PATH:?}/AndroidManifest.xml"

cp -pf -- "${THIS_SCRIPT_DIR:?}/updater.sh" "${_android_tmp:?}/updater" || fail_with_msg 'Failed to copy the updater script'
chmod +x "${_android_tmp:?}/updater" || fail_with_msg "chmod failed on '${_android_tmp}/updater'"

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
  if ! test -e "${_our_overrider_dir:?}/${1:?}"; then return 1; fi
  rm -f -- "${_android_sys:?}/bin/${1:?}"

  unset -f -- "${1:?}"
  eval " ${1:?}() { '${_our_overrider_dir:?}/${1:?}' \"\${@}\"; }" || return "${?}" # The folder expands when defined, not when used

  if test "${_is_export_f_supported:?}" -eq 0; then
    # shellcheck disable=SC3045
    export -f -- "${1:?}"
  fi
}

simulate_env()
{
  cp -pf -- "${_our_busybox:?}" "${_android_sys:?}/bin/busybox" || fail_with_msg 'Failed to copy BusyBox'
  if test "${COVERAGE:-false}" != 'false'; then
    cp -pf -- "${COVERAGE:?}" "${_android_sys:?}/bin/bashcov" || fail_with_msg 'Failed to copy Bashcov'
  fi

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
  export CUSTOM_BUSYBOX="${_android_sys:?}/bin/busybox"
  export OVERRIDE_DIR="${_our_overrider_dir:?}"
  export RS_OVERRIDE_SCRIPT="${_our_overrider_script:?}"
  export TEST_INSTALL=true

  if test "${uname_o_saved:?}" != 'MS/Windows' && test "${uname_o_saved:?}" != 'Msys'; then
    "${CUSTOM_BUSYBOX:?}" --install -s "${_android_sys:?}/bin" || fail_with_msg 'Failed to install BusyBox'
  else
    "${CUSTOM_BUSYBOX:?}" --install "${_android_sys:?}/bin" || fail_with_msg 'Failed to install BusyBox'
  fi

  override_command mount || return 123
  override_command umount || return 123
  override_command chown || return 123
  override_command su || return 123
  override_command sudo || return 123
}

restore_env()
{
  local _backup_ifs

  export PATH="${_backup_path}"
  unset BB_OVERRIDE_APPLETS
  unset -f -- mount umount chown su sudo

  "${_our_busybox:?}" 2> /dev/null --uninstall "${CUSTOM_BUSYBOX:?}" || true

  # Fallback if --uninstall is NOT supported
  {
    _backup_ifs="${IFS:-}"
    IFS=' '
    find "${_android_sys:?}/bin" -type l -exec sh -c 'bb_path="${1:?}"; shift; if test "$(realpath "${*}")" = "${bb_path:?}"; then rm -f -- "${*}"; fi' _ "${CUSTOM_BUSYBOX:?}" '{}' ';' || true
    IFS="${_backup_ifs:-}"

    rm -f "${CUSTOM_BUSYBOX:?}" || true
  }
}

# Setup recovery output
recovery_fd=99
recovery_logs_dir="${THIS_SCRIPT_DIR:?}/output"
if test -e "/proc/self/fd/${recovery_fd:?}"; then fail_with_msg 'Recovery FD already exist'; fi
mkdir -p "${recovery_logs_dir:?}"
touch "${recovery_logs_dir:?}/recovery-raw.log" "${recovery_logs_dir:?}/recovery-output-raw.log" "${recovery_logs_dir:?}/recovery-stdout.log" "${recovery_logs_dir:?}/recovery-stderr.log"

if test "${uname_o_saved:?}" != 'MS/Windows' && test "${uname_o_saved:?}" != 'Msys'; then # ToDO: Rewrite this code
  sudo chattr +aAd "${recovery_logs_dir:?}/recovery-raw.log" || fail_with_msg "chattr failed on 'recovery-raw.log'"
  sudo chattr +aAd "${recovery_logs_dir:?}/recovery-output-raw.log" || fail_with_msg "chattr failed on 'recovery-output-raw.log'"
  sudo chattr +aAd "${recovery_logs_dir:?}/recovery-stdout.log" || fail_with_msg "chattr failed on 'recovery-stdout.log'"
  sudo chattr +aAd "${recovery_logs_dir:?}/recovery-stderr.log" || fail_with_msg "chattr failed on 'recovery-stderr.log'"
fi

# shellcheck disable=SC3023
exec 99> >(tee -a "${recovery_logs_dir:?}/recovery-raw.log" "${recovery_logs_dir:?}/recovery-output-raw.log" || true)

flash_zips()
{
  for _current_zip_fullpath in "${@}"; do
    FLASHABLE_ZIP_NAME="$(basename "${_current_zip_fullpath:?}")" || fail_with_msg 'Failed to get the filename of the flashable ZIP'
    cp -f -- "${_current_zip_fullpath:?}" "${_android_sec_stor:?}/${FLASHABLE_ZIP_NAME:?}" || fail_with_msg 'Failed to copy the flashable ZIP'

    # Simulate the environment variables of a real recovery
    simulate_env || return "${?}"

    "${CUSTOM_BUSYBOX:?}" unzip -opq "${_android_sec_stor:?}/${FLASHABLE_ZIP_NAME:?}" 'META-INF/com/google/android/update-binary' > "${_android_tmp:?}/update-binary" || fail_with_msg 'Failed to extract the update-binary'

    echo "custom_flash_start ${_android_sec_stor:?}/${FLASHABLE_ZIP_NAME:?}" 1>&"${recovery_fd:?}"
    set +e
    # Execute the script that will run the flashable zip
    if test "${COVERAGE:-false}" = 'false'; then
      "${CUSTOM_BUSYBOX:?}" sh -- "${_android_tmp:?}/updater" 3 "${recovery_fd:?}" "${_android_sec_stor:?}/${FLASHABLE_ZIP_NAME:?}" 1> >(tee -a "${recovery_logs_dir:?}/recovery-raw.log" "${recovery_logs_dir:?}/recovery-stdout.log" || true) 2> >(tee -a "${recovery_logs_dir:?}/recovery-raw.log" "${recovery_logs_dir:?}/recovery-stderr.log" 1>&2 || true)
    else
      bashcov -- "${THIS_SCRIPT_DIR:?}/updater.sh" 3 "${recovery_fd:?}" "${_android_sec_stor:?}/${FLASHABLE_ZIP_NAME:?}" 1> >(tee -a "${recovery_logs_dir:?}/recovery-raw.log" "${recovery_logs_dir:?}/recovery-stdout.log" || true) 2> >(tee -a "${recovery_logs_dir:?}/recovery-raw.log" "${recovery_logs_dir:?}/recovery-stderr.log" 1>&2 || true)
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

if test "${uname_o_saved:?}" != 'MS/Windows' && test "${uname_o_saved:?}" != 'Msys'; then # ToDO: Rewrite this code
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
rm -f -- "${BASE_SIMULATION_PATH:?}/sbin" || true
rm -f -- "${BASE_SIMULATION_PATH:?}/sdcard" || true
rm -f -- "${_android_sys:?}/build.prop" || true
rm -f -- "${_android_sys:?}/framework/framework-res.apk" || true
cd "${OUR_TEMP_DIR:?}" || fail_with_msg 'Failed to change dir to our temp dir'
TZ=UTC find "${BASE_SIMULATION_PATH}" -exec touch -c -h -t '202001010000' -- '{}' '+' || true
TZ=UTC ls -A -R -F -l -n --color='never' -- 'root' 1> "${recovery_logs_dir:?}/installed-files.log" || true

# Final cleanup
cd "${_init_dir:?}" || fail_with_msg 'Failed to change back the folder'
unset TMPDIR
rm -rf -- "${OUR_TEMP_DIR:?}" &
set +e
if test "${STATUS}" -ne 0; then exit "${STATUS}"; fi
