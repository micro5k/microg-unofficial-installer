#!/usr/bin/env bash
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# NOTE: This script simulate a real recovery but it relies on the flashable zip to use the suggested paths.
# REALLY IMPORTANT: A misbehaving flashable zip can damage your real system.

set -e
# shellcheck disable=SC3040
set -o pipefail || true

fail_with_msg()
{
  echo "${1:?}"
  exit 1
}

create_junction()
{
  if test "${uname_o_saved}" != 'MS/Windows'; then return 1; fi
  return 1
  # cmd.exe /C mklink /J "${1:?}" "${2:?}"
}

link_folder()
{
  # shellcheck disable=SC2310
  ln -sf "${2:?}" "${1:?}" 2>/dev/null || create_junction "${1:?}" "${2:?}" || mkdir -p "${1:?}" || fail_with_msg "Failed to link dir '${1:?}' to '${2:?}'"
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
    echo "Copied recovery log to /sdcard1/recovery.log"
  fi

  echo ''
}

if test -z "${1}"; then fail_with_msg 'You must pass the filename of the flashable ZIP as parameter'; fi

# Reset environment
if ! "${ENV_RESETTED:-false}"; then
  THIS_SCRIPT="$(realpath "${0}" 2>&-)" || fail_with_msg 'Failed to get script filename'
  # Create the temp dir (must be done before resetting environment)
  OUR_TEMP_DIR="$(mktemp -d -t ANDR-RECOV-XXXXXX)" || fail_with_msg 'Failed to create our temp dir'
  exec env -i ENV_RESETTED=true THIS_SCRIPT="${THIS_SCRIPT}" OUR_TEMP_DIR="${OUR_TEMP_DIR}" PATH="${PATH}" bash "${THIS_SCRIPT}" "$@" || fail_with_msg 'failed: exec'
  exit 127
fi
unset ENV_RESETTED
_backup_path="${PATH}"
uname_o_saved="$(uname -o)" || fail_with_msg 'Failed to get uname -o'

# Check dependencies
_our_busybox="$(which busybox)" || fail_with_msg 'BusyBox is missing'

# Get dir of this script
THIS_SCRIPT_DIR="$(dirname "${THIS_SCRIPT}")" || fail_with_msg 'Failed to get script dir'
unset THIS_SCRIPT

newline='
'
for _current_file in "$@"
do
  FILES="${FILES}$(realpath "${_current_file}")${newline}" || fail_with_msg "Invalid filename: ${_current_file}"
done

# Ensure we have a path the the temp dir and empty it (should be already empty, but we must be sure)
if test -z "${OUR_TEMP_DIR}"; then fail_with_msg 'Failed to create our temp dir'; fi
rm -rf "${OUR_TEMP_DIR:?}"/* || fail_with_msg 'Failed to empty our temp dir'

# Setup the needed variables
BASE_SIMULATION_PATH="${OUR_TEMP_DIR}/root"  # Internal var
_our_overrider_dir="${THIS_SCRIPT_DIR}/override"  # Internal var
INIT_DIR="$(pwd)"

# Configure the Android recovery environment variables (they will be used later)
_android_tmp="${BASE_SIMULATION_PATH}/tmp"
_android_sys="${BASE_SIMULATION_PATH}/system"
_android_data="${BASE_SIMULATION_PATH}/data"
_android_ext_stor="${BASE_SIMULATION_PATH}/sdcard0"
_android_sec_stor="${BASE_SIMULATION_PATH}/sdcard1"
_android_path="${_our_overrider_dir}:${BASE_SIMULATION_PATH}/sbin:${_android_sys}/bin:${_backup_path}"
_android_lib_path=".:${BASE_SIMULATION_PATH}/sbin"

# Simulate the Android recovery environment inside the temp folder
mkdir -p "${BASE_SIMULATION_PATH}"
cd "${BASE_SIMULATION_PATH}" || fail_with_msg 'Failed to change dir to the base simulation path'
mkdir -p "${_android_tmp}"
mkdir -p "${_android_sys}"
mkdir -p "${_android_sys}/addon.d"
mkdir -p "${_android_sys}/priv-app"
mkdir -p "${_android_sys}/app"
mkdir -p "${_android_sys}/bin"
mkdir -p "${_android_data}"
mkdir -p "${_android_ext_stor}"
mkdir -p "${_android_sec_stor}"
touch "${_android_tmp}/recovery.log"
link_folder "${BASE_SIMULATION_PATH}/sbin" "${_android_sys}/bin"
link_folder "${BASE_SIMULATION_PATH}/sdcard" "${_android_ext_stor}"
cp -pf -- "${_our_busybox:?}" "${BASE_SIMULATION_PATH:?}/system/bin/busybox" || fail_with_msg 'Failed to copy BusyBox'

{
  echo 'ro.build.version.sdk=25'
  echo 'ro.product.cpu.abi=x86_64'
  echo 'ro.product.cpu.abi2=armeabi-v7a'
  echo 'ro.product.cpu.abilist=x86_64,x86,arm64-v8a,armeabi-v7a,armeabi'
  echo 'ro.product.cpu.abilist32=x86,armeabi-v7a,armeabi'
  echo 'ro.product.cpu.abilist64=x86_64,arm64-v8a'
} > "${_android_sys}/build.prop"

touch "${BASE_SIMULATION_PATH}/AndroidManifest.xml"
printf 'a\0n\0d\0r\0o\0i\0d\0.\0p\0e\0r\0m\0i\0s\0s\0i\0o\0n\0.\0F\0A\0K\0E\0_\0P\0A\0C\0K\0A\0G\0E\0_\0S\0I\0G\0N\0A\0T\0U\0R\0E\0' > "${BASE_SIMULATION_PATH}/AndroidManifest.xml"
mkdir -p "${_android_sys}/framework"
zip -D -9 -X -UN=n -nw -q "${_android_sys}/framework/framework-res.apk" 'AndroidManifest.xml' || fail_with_msg 'Failed compressing framework-res.apk'
rm -f -- "${BASE_SIMULATION_PATH}/AndroidManifest.xml"

cp -pf -- "${THIS_SCRIPT_DIR}/updater.sh" "${_android_tmp}/updater" || fail_with_msg 'Failed to copy the updater script'
chmod +x "${_android_tmp}/updater" || fail_with_msg "chmod failed on '${_android_tmp}/updater'"

override_command()
{
  unset -f -- "${1:?}" || true
  eval "${1:?}() { \"${_our_overrider_dir:?}/${1:?}\"; }" || return "${?}"  # This expands when defined, not when used (it is intended)
  # shellcheck disable=SC3045
  export -f -- "${1:?}" 2>/dev/null || true
  rm -f -- "${_android_sys:?}/bin/${1:?}"
}

simulate_env()
{
  export EXTERNAL_STORAGE="${_android_ext_stor:?}"
  export SECONDARY_STORAGE="${_android_sec_stor:?}"
  export LD_LIBRARY_PATH="${_android_lib_path:?}"
  export ANDROID_DATA="${_android_data:?}"
  export PATH="${_android_path:?}"
  export ANDROID_ROOT="${_android_sys:?}"
  export ANDROID_PROPERTY_WORKSPACE='21,32768'
  export TZ='CET-1CEST,M3.5.0,M10.5.0'
  export TMPDIR="${_android_tmp:?}"
  export CUSTOM_BUSYBOX="${BASE_SIMULATION_PATH:?}/system/bin/busybox"
  export OVERRIDE_DIR="${_our_overrider_dir:?}"

  "${CUSTOM_BUSYBOX:?}" --install "${_android_sys:?}/bin" || fail_with_msg 'Failed to install BusyBox'
  override_command mount || exit 123
  override_command umount || exit 123
  override_command chown || exit 123

  rm -f -- "${_android_sys:?}/bin/su" "${_android_sys:?}/bin/sudo" || fail_with_msg 'Failed to remove potentially unsafe commands'
}

restore_path()
{
  export PATH="${_backup_path}"
}

# Setup recovery output
recovery_fd=99
recovery_logs_dir="${THIS_SCRIPT_DIR:?}/output"
if test -e "/proc/self/fd/${recovery_fd:?}"; then fail_with_msg 'Recovery FD already exist'; fi
mkdir -p "${recovery_logs_dir:?}"
touch "${recovery_logs_dir:?}/recovery-raw.log" "${recovery_logs_dir:?}/recovery-output-raw.log" "${recovery_logs_dir:?}/recovery-stdout.log" "${recovery_logs_dir:?}/recovery-stderr.log"
if test "${uname_o_saved:?}" != 'MS/Windows'; then
  sudo chattr +aAd "${recovery_logs_dir:?}/recovery-raw.log" || fail_with_msg "chattr failed on 'recovery-raw.log'"
  sudo chattr +aAd "${recovery_logs_dir:?}/recovery-output-raw.log" || fail_with_msg "chattr failed on 'recovery-output-raw.log'"
  sudo chattr +aAd "${recovery_logs_dir:?}/recovery-stdout.log" || fail_with_msg "chattr failed on 'recovery-stdout.log'"
  sudo chattr +aAd "${recovery_logs_dir:?}/recovery-stderr.log" || fail_with_msg "chattr failed on 'recovery-stderr.log'"
fi
# shellcheck disable=SC3023
exec 99> >(tee -a "${recovery_logs_dir:?}/recovery-raw.log" "${recovery_logs_dir:?}/recovery-output-raw.log" || true)

flash_zips()
{
  while IFS='' read -r _current_zip_fullpath; do
    if test -z "${_current_zip_fullpath}"; then continue; fi

    # Simulate the environment variables
    simulate_env

    FLASHABLE_ZIP_NAME="$(basename "${_current_zip_fullpath:?}")" || fail_with_msg 'Failed to get the filename of the flashable ZIP'
    cp -f -- "${_current_zip_fullpath:?}" "${_android_sec_stor:?}/${FLASHABLE_ZIP_NAME:?}" || fail_with_msg 'Failed to copy the flashable ZIP'
    "${CUSTOM_BUSYBOX:?}" unzip -opq "${_android_sec_stor:?}/${FLASHABLE_ZIP_NAME:?}" 'META-INF/com/google/android/update-binary' > "${_android_tmp:?}/update-binary" || fail_with_msg 'Failed to extract the update-binary'

    echo "custom_flash_start ${_android_sec_stor:?}/${FLASHABLE_ZIP_NAME:?}" 1>&"${recovery_fd:?}"
    set +e
    # Execute the script that will run the flashable zip
    "${CUSTOM_BUSYBOX:?}" sh "${_android_tmp:?}/updater" 3 "${recovery_fd:?}" "${_android_sec_stor:?}/${FLASHABLE_ZIP_NAME:?}" 1> >(tee -a "${recovery_logs_dir:?}/recovery-raw.log" "${recovery_logs_dir:?}/recovery-stdout.log" || true) 2> >(tee -a "${recovery_logs_dir:?}/recovery-raw.log" "${recovery_logs_dir:?}/recovery-stderr.log" 1>&2 || true); STATUS="${?}"
    set -e
    echo "custom_flash_end ${STATUS:?}" 1>&"${recovery_fd:?}"

    restore_path
    if test "${STATUS:?}" -ne 0; then return "${STATUS:?}"; fi
  done
}
STATUS=0
# shellcheck disable=SC2310
echo "${FILES:?}" | flash_zips || STATUS="${?}"

# Close recovery output
# shellcheck disable=SC3023
exec 99>&-
if test "${uname_o_saved:?}" != 'MS/Windows'; then
  sudo chattr -a "${recovery_logs_dir:?}/recovery-raw.log" || fail_with_msg "chattr failed on 'recovery-raw.log'"
  sudo chattr -a "${recovery_logs_dir:?}/recovery-output-raw.log" || fail_with_msg "chattr failed on 'recovery-output-raw.log'"
  sudo chattr -a "${recovery_logs_dir:?}/recovery-stdout.log" || fail_with_msg "chattr failed on 'recovery-stdout.log'"
  sudo chattr -a "${recovery_logs_dir:?}/recovery-stderr.log" || fail_with_msg "chattr failed on 'recovery-stderr.log'"
fi

parse_recovery_output()
{
  _last_msg_printed=false
  _last_zip_name=''
  while IFS=' ' read -r ui_command text; do
    if test "${ui_command}" = 'ui_print'; then
      if test "${_last_msg_printed}" = true && test "${text}" = ''; then
        _last_msg_printed=false
      else
        _last_msg_printed=true
        echo "${text}"
      fi
    elif test "${ui_command}" = 'custom_flash_start'; then
      _last_msg_printed=false
      _last_zip_name="${text}"
      recovery_flash_start "${1:?}" "${_last_zip_name:?}"
    elif test "${ui_command}" = 'custom_flash_end'; then
      _last_msg_printed=false
      recovery_flash_end "${1:?}" "${text:?}" "${_last_zip_name:?}"
    else
      _last_msg_printed=false
      echo "> ${ui_command} ${text}"
    fi
  done < "${2:?}" > "${3:?}"
}

# Parse recovery output
parse_recovery_output true "${recovery_logs_dir}/recovery-output-raw.log" "${recovery_logs_dir}/recovery-output.log"
parse_recovery_output false "${recovery_logs_dir}/recovery-raw.log" "${recovery_logs_dir}/recovery.log"

# Final cleanup
cd "${INIT_DIR}" || fail_with_msg 'Failed to change back the folder'
unset TMPDIR
rm -rf -- "${OUR_TEMP_DIR:?}" &
set +e
if test "${STATUS}" -ne 0; then exit "${STATUS}"; fi
