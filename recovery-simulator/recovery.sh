#!/usr/bin/env bash
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# NOTE: This script simulate a real recovery but it relies on the flashable zip to use the suggested paths.
# REALLY IMPORTANT: A misbehaving flashable zip can damage your real system.

# shellcheck disable=SC3040
set -eo pipefail

fail_with_msg()
{
  echo "${1}"
  exit 1
}

link_folder()
{
  ln -sf "${2}" "${1}" || mkdir -p "${1}" || fail_with_msg "Failed to link dir '${1}'"
}

recovery_flash_start()
{
  echo "I:Set page: 'install'"
  echo "I:Set page: 'flash_confirm'"
  echo "I:Set page: 'flash_zip'"
  echo "I:operation_start: 'Flashing'"
  echo "Installing zip file '${1}'"
  #echo "Checking for MD5 file..."
  #echo "MD5 matched for '${1}'."
  echo "I:Update binary zip"
}

recovery_flash_end()
{
  if test "${1}" -eq 0; then
    echo "I:Updater process ended with RC=0"
  else
    echo "Updater process ended with ERROR: ${1}"
    echo "Error installing zip file '${2}'"
  fi
  echo "Updating partition details..."
  echo "...done"
  echo "I:Set page: 'flash_done'"
  if test "${1}" -eq 0; then
    echo "I:operation_end - status=0"
  else
    echo "I:operation_end - status=1"
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
unset LC_TIME
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
FLASHABLE_ZIP_PATH="$(realpath "${1}" 2>/dev/null)" || fail_with_msg 'Failed to get the flashable ZIP'
OVERRIDE_DIR="${THIS_SCRIPT_DIR}/override"
BASE_SIMULATION_PATH="${OUR_TEMP_DIR}/root"; mkdir -p "${BASE_SIMULATION_PATH}"  # Internal var
INIT_DIR="$(pwd)"

# Simulate the environment variables (part 1)
EXTERNAL_STORAGE="${BASE_SIMULATION_PATH}/sdcard0"
SECONDARY_STORAGE="${BASE_SIMULATION_PATH}/sdcard1"
LD_LIBRARY_PATH=".:${BASE_SIMULATION_PATH}/sbin"
ANDROID_DATA="${BASE_SIMULATION_PATH}/data"
ANDROID_ROOT="${BASE_SIMULATION_PATH}/system"
ANDROID_PROPERTY_WORKSPACE='21,32768'
TZ='CET-1CEST,M3.5.0,M10.5.0'
TMPDIR="${BASE_SIMULATION_PATH}/tmp"

# Simulate the Android environment inside the temp folder
cd "${BASE_SIMULATION_PATH}" || fail_with_msg 'Failed to change dir to the base simulation path'
mkdir -p "${ANDROID_ROOT}"
mkdir -p "${BASE_SIMULATION_PATH}/system/addon.d"
mkdir -p "${BASE_SIMULATION_PATH}/system/priv-app"
mkdir -p "${BASE_SIMULATION_PATH}/system/app"
mkdir -p "${ANDROID_ROOT}/bin"
mkdir -p "${ANDROID_DATA}"
mkdir -p "${EXTERNAL_STORAGE}"
mkdir -p "${SECONDARY_STORAGE}"
link_folder "${BASE_SIMULATION_PATH}/sbin" "${BASE_SIMULATION_PATH}/system/bin"
link_folder "${BASE_SIMULATION_PATH}/sdcard" "${EXTERNAL_STORAGE}"
cp -pf -- "${_our_busybox:?}" "${BASE_SIMULATION_PATH:?}/system/bin/busybox" || fail_with_msg 'Failed to copy BusyBox'

{
  echo 'ro.build.version.sdk=25'
  echo 'ro.product.cpu.abi=x86_64'
  echo 'ro.product.cpu.abi2=armeabi-v7a'
  echo 'ro.product.cpu.abilist=x86_64,x86,arm64-v8a,armeabi-v7a,armeabi'
  echo 'ro.product.cpu.abilist32=x86,armeabi-v7a,armeabi'
  echo 'ro.product.cpu.abilist64=x86_64,arm64-v8a'
} > "${ANDROID_ROOT}/build.prop"

touch "${BASE_SIMULATION_PATH}/AndroidManifest.xml"
printf 'a\0n\0d\0r\0o\0i\0d\0.\0p\0e\0r\0m\0i\0s\0s\0i\0o\0n\0.\0F\0A\0K\0E\0_\0P\0A\0C\0K\0A\0G\0E\0_\0S\0I\0G\0N\0A\0T\0U\0R\0E\0' > "${BASE_SIMULATION_PATH}/AndroidManifest.xml"
mkdir -p "${ANDROID_ROOT}/framework"
zip -D -9 -X -UN=n -nw -q "${ANDROID_ROOT}/framework/framework-res.apk" 'AndroidManifest.xml' || fail_with_msg 'Failed compressing framework-res.apk'
rm -f "${BASE_SIMULATION_PATH}/AndroidManifest.xml"

mkdir -p "${TMPDIR}"
cp -pf -- "${THIS_SCRIPT_DIR}/updater.sh" "${TMPDIR}/updater" || fail_with_msg 'Failed to copy the updater script'
chmod +x "${TMPDIR}/updater" || fail_with_msg "chmod failed on '${TMPDIR}/updater'"

# Setup recovery output
recovery_fd=99
recovery_logs_dir="${THIS_SCRIPT_DIR}/output"
if test -e "/proc/self/fd/${recovery_fd}"; then fail_with_msg 'Recovery FD already exist'; fi
mkdir -p "${recovery_logs_dir}"
touch "${recovery_logs_dir}/recovery-raw.log" "${recovery_logs_dir}/recovery-output-raw.log" "${recovery_logs_dir}/recovery-stdout.log" "${recovery_logs_dir}/recovery-stderr.log"
if test "${uname_o_saved}" != 'MS/Windows'; then
  sudo chattr +aAd "${recovery_logs_dir}/recovery-raw.log" || fail_with_msg "chattr failed on 'recovery-raw.log'"
  sudo chattr +aAd "${recovery_logs_dir}/recovery-output-raw.log" || fail_with_msg "chattr failed on 'recovery-output-raw.log'"
  sudo chattr +aAd "${recovery_logs_dir}/recovery-stdout.log" || fail_with_msg "chattr failed on 'recovery-stdout.log'"
  sudo chattr +aAd "${recovery_logs_dir}/recovery-stderr.log" || fail_with_msg "chattr failed on 'recovery-stderr.log'"
fi
# shellcheck disable=SC3023
exec 99> >(tee -a "${recovery_logs_dir}/recovery-raw.log" "${recovery_logs_dir}/recovery-output-raw.log" || true)

# Simulate the environment variables (part 2)
PATH="${OVERRIDE_DIR}:${BASE_SIMULATION_PATH}/sbin:${ANDROID_ROOT}/bin:${PATH}"  # We have to keep the original folders inside PATH otherwise everything stop working
export EXTERNAL_STORAGE
export LD_LIBRARY_PATH
export ANDROID_DATA
export PATH
export ANDROID_ROOT
export ANDROID_PROPERTY_WORKSPACE
export TZ
export TMPDIR
export CUSTOM_BUSYBOX="${BASE_SIMULATION_PATH:?}/system/bin/busybox"
"${CUSTOM_BUSYBOX:?}" --install "${BASE_SIMULATION_PATH:?}/system/bin" || fail_with_msg 'Failed to install BusyBox'
rm -f "${BASE_SIMULATION_PATH:?}/system/bin/su" "${BASE_SIMULATION_PATH:?}/system/bin/mount" "${BASE_SIMULATION_PATH:?}/system/bin/umount" "${BASE_SIMULATION_PATH:?}/system/bin/chown" || fail_with_msg 'Failed to remove potentially unsafe commands'

# Prepare before execution
export OVERRIDE_DIR
FLASHABLE_ZIP_NAME="$("${CUSTOM_BUSYBOX}" basename "${FLASHABLE_ZIP_PATH}")" || fail_with_msg 'Failed to get the filename of the flashable ZIP'
"${CUSTOM_BUSYBOX}" cp -rf "${FLASHABLE_ZIP_PATH}" "${SECONDARY_STORAGE}/${FLASHABLE_ZIP_NAME}" || fail_with_msg 'Failed to copy the flashable ZIP'
"${CUSTOM_BUSYBOX}" unzip -opq "${SECONDARY_STORAGE}/${FLASHABLE_ZIP_NAME}" 'META-INF/com/google/android/update-binary' > "${TMPDIR}/update-binary" || fail_with_msg 'Failed to extract the update-binary'
chmod +x "${TMPDIR}/update-binary" || fail_with_msg "chmod failed on '${TMPDIR}/update-binary'"

# Execute the script that will run the flashable zip
echo "custom_flash_start ${SECONDARY_STORAGE}/${FLASHABLE_ZIP_NAME}" 1>&"${recovery_fd}"
set +e
"${CUSTOM_BUSYBOX}" sh "${TMPDIR}/updater" 3 "${recovery_fd}" "${SECONDARY_STORAGE}/${FLASHABLE_ZIP_NAME}" 1> >(tee -a "${recovery_logs_dir}/recovery-raw.log" "${recovery_logs_dir}/recovery-stdout.log" || true) 2> >(tee -a "${recovery_logs_dir}/recovery-raw.log" "${recovery_logs_dir}/recovery-stderr.log" 1>&2 || true); STATUS="${?}"
set -e
echo "custom_flash_end ${STATUS}" 1>&"${recovery_fd}"

# Close recovery output
# shellcheck disable=SC3023
exec 99>&-
if test "${uname_o_saved}" != 'MS/Windows'; then
  sudo chattr -a "${recovery_logs_dir}/recovery-raw.log" || fail_with_msg "chattr failed on 'recovery-raw.log'"
  sudo chattr -a "${recovery_logs_dir}/recovery-output-raw.log" || fail_with_msg "chattr failed on 'recovery-output-raw.log'"
  sudo chattr -a "${recovery_logs_dir}/recovery-stdout.log" || fail_with_msg "chattr failed on 'recovery-stdout.log'"
  sudo chattr -a "${recovery_logs_dir}/recovery-stderr.log" || fail_with_msg "chattr failed on 'recovery-stderr.log'"
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
      recovery_flash_start "${_last_zip_name}"
    elif test "${ui_command}" = 'custom_flash_end'; then
      _last_msg_printed=false
      recovery_flash_end "${text}" "${_last_zip_name}"
    else
      _last_msg_printed=false
      echo "> ${ui_command} ${text}"
    fi
  done < "${2}" > "${3}"
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
