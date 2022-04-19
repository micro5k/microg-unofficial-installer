#!/usr/bin/env bash

# SPDX-FileCopyrightText: (c) 2016-2019, 2021 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# NOTE: This script simulate a real recovery but it relies on the zip to use the suggested paths.
# IMPORTANT: A misbehaving zip can damage your real system.

fail_with_msg()
{
  echo "${1}"
  exit 1
}

# Reset environment
if ! "${ENV_RESETTED:-false}"; then
  THIS_SCRIPT="$(realpath "${0}" 2>&-)" || fail_with_msg 'Failed to get script filename'
  # Create the temp dir (must be done before resetting environment)
  OUR_TEMP_DIR="$(mktemp -d -t ANDR-RECOV-XXXXXX)" || fail_with_msg 'Failed to create our temp dir'
  exec env -i ENV_RESETTED=true THIS_SCRIPT="${THIS_SCRIPT}" OUR_TEMP_DIR="${OUR_TEMP_DIR}" PATH="${PATH}" bash "${THIS_SCRIPT}" "${1}"
fi
unset ENV_RESETTED

# Check dependencies
UNZIP_CMD="$(command -v unzip)" || fail_with_msg 'Unzip is missing'
CUSTOM_BUSYBOX="$(command -v busybox)" || fail_with_msg 'BusyBox is missing'

# Get dir of this script
THIS_SCRIPT_DIR="$(dirname "${THIS_SCRIPT}")" || fail_with_msg 'Failed to get script dir'
unset THIS_SCRIPT

# Ensure we have a path the the temp dir and empty it (should be already empty, but we must be sure)
if test -z "${OUR_TEMP_DIR}"; then fail_with_msg 'Failed to create our temp dir'; fi
rm -rf "${OUR_TEMP_DIR:?}"/* || fail_with_msg 'Failed to empty our temp dir'

# Simulate the environment variables (part 1)
BASE_SIMULATION_PATH="${OUR_TEMP_DIR}/root"  # Internal var
EXTERNAL_STORAGE="${BASE_SIMULATION_PATH}/sdcard0"
SECONDARY_STORAGE="${BASE_SIMULATION_PATH}/sdcard1"
LD_LIBRARY_PATH=".:${BASE_SIMULATION_PATH}/sbin"
ANDROID_DATA="${BASE_SIMULATION_PATH}/data"
ANDROID_ROOT="${BASE_SIMULATION_PATH}/system"
ANDROID_PROPERTY_WORKSPACE='21,32768'
TZ='CET-1CEST,M3.5.0,M10.5.0'
TMPDIR="${BASE_SIMULATION_PATH}/tmp"

# Simulate the recovery environment inside the temp folder
mkdir -p "${ANDROID_ROOT}"
mkdir -p "${ANDROID_ROOT}/bin"
mkdir -p "${ANDROID_DATA}"
mkdir -p "${EXTERNAL_STORAGE}"
mkdir -p "${SECONDARY_STORAGE}"
ln -s "${BASE_SIMULATION_PATH}/system/bin" "${BASE_SIMULATION_PATH}/sbin" || mkdir -p "${BASE_SIMULATION_PATH}/sbin"
ln -s "${EXTERNAL_STORAGE}" "${BASE_SIMULATION_PATH}/sdcard" || mkdir -p "${BASE_SIMULATION_PATH}/sdcard"

{
  echo 'ro.build.version.sdk=25'
  echo 'ro.product.cpu.abi=x86_64'
  echo 'ro.product.cpu.abi2=armeabi-v7a'
  echo 'ro.product.cpu.abilist=x86_64,x86,arm64-v8a,armeabi-v7a,armeabi'
  echo 'ro.product.cpu.abilist32=x86,armeabi-v7a,armeabi'
  echo 'ro.product.cpu.abilist64=x86_64,arm64-v8a'
} > "${ANDROID_ROOT}/build.prop"

mkdir -p "${TMPDIR}"
cp -rf "${THIS_SCRIPT_DIR}/updater.sh" "${TMPDIR}/updater" || fail_with_msg 'Failed to copy the updater script'
chmod +x "${TMPDIR}/updater" || fail_with_msg "chmod failed on '${TMPDIR}/updater'"

mkdir -p "${THIS_SCRIPT_DIR}/output"
touch "${THIS_SCRIPT_DIR}/output/recovery_output"
exec 99>> "${THIS_SCRIPT_DIR}/output/recovery_output"
RECOVERY_FD=99

# Simulate the environment variables (part 2)
PATH="${THIS_SCRIPT_DIR}/override:${BASE_SIMULATION_PATH}/sbin:${ANDROID_ROOT}/bin:${PATH}"  # We have to keep the original folders inside PATH otherwise everything stop working
export EXTERNAL_STORAGE
export LD_LIBRARY_PATH
export ANDROID_DATA
export PATH
export ANDROID_ROOT
export ANDROID_PROPERTY_WORKSPACE
export TZ
export TMPDIR
export CUSTOM_BUSYBOX

# Prepare before execution
FLASHABLE_ZIP_PATH="${1}"
FLASHABLE_ZIP="$("${CUSTOM_BUSYBOX}" basename "${FLASHABLE_ZIP_PATH}")" || fail_with_msg 'Failed to get the dir of the flashable ZIP'
"${CUSTOM_BUSYBOX}" cp -rf "${FLASHABLE_ZIP_PATH}" "${SECONDARY_STORAGE}/${FLASHABLE_ZIP}" || fail_with_msg 'Failed to copy the flashable ZIP'
"${UNZIP_CMD}" -opq "${SECONDARY_STORAGE}/${FLASHABLE_ZIP}" 'META-INF/com/google/android/update-binary' > "${TMPDIR}/update-binary" || fail_with_msg 'Failed to extract the update-binary'

# Execute the script that will run the flashable zip
cd "${BASE_SIMULATION_PATH}" || fail_with_msg 'Failed to change dir to the base simulation path'
"${CUSTOM_BUSYBOX}" sh "${TMPDIR}/updater" 3 "${RECOVERY_FD}" "${SECONDARY_STORAGE}/${FLASHABLE_ZIP}"; STATUS="$?"
rm -r "${TMPDIR}/update-binary"

unset TMPDIR
rm -rf "${OUR_TEMP_DIR:?}" &
if test "${STATUS}" -ne 0; then fail_with_msg "Installation failed with error ${STATUS}"; fi
