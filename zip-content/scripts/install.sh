#!/sbin/sh
# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

### INIT ENV ###
export TZ=UTC
export LANG=en_US

unset LANGUAGE
unset LC_ALL
unset UNZIP
unset UNZIPOPT
unset UNZIP_OPTS
unset CDPATH

# shellcheck disable=SC3040,SC2015
{
  # Unsupported set -o options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue and also handle the set -e case
  (set -o posix 2> /dev/null) && set -o posix || true
  (set -o pipefail) && set -o pipefail || true
}

### GLOBAL VARIABLES ###

export INSTALLER=1
TMP_PATH="$2"

CPU=false
CPU64=false
LEGACY_ARM=false
FAKE_SIGN=false
SYS_PATH=''

### FUNCTIONS ###

# shellcheck source=SCRIPTDIR/../inc/common-functions.sh
. "${TMP_PATH}/inc/common-functions.sh"

### CODE ###

# Make sure that the commands are still overridden here (most shells don't have the ability to export functions)
if test "${TEST_INSTALL:-false}" != 'false' && test -f "${RS_OVERRIDE_SCRIPT:?}"; then
  # shellcheck source=SCRIPTDIR/../../recovery-simulator/inc/configure-overrides.sh
  . "${RS_OVERRIDE_SCRIPT:?}" || exit "${?}"
fi

# Live setup
live_setup_enabled=false
if test "${LIVE_SETUP_POSSIBLE:?}" = 'true'; then
  if test "${LIVE_SETUP_DEFAULT:?}" != '0'; then
    live_setup_enabled=true
  elif test "${LIVE_SETUP_TIMEOUT:?}" -gt 0; then
    ui_msg '---------------------------------------------------'
    ui_msg 'INFO: Select the VOLUME + key to enable live setup.'
    ui_msg "Waiting input for ${LIVE_SETUP_TIMEOUT} seconds..."
    if "${KEYCHECK_ENABLED}"; then
      choose_keycheck_with_timeout "${LIVE_SETUP_TIMEOUT}"
    else
      choose_read_with_timeout "${LIVE_SETUP_TIMEOUT}"
    fi
    if test "${?}" = '3'; then live_setup_enabled=true; fi
  fi
fi

if test "${live_setup_enabled:?}" = 'true'; then
  ui_msg 'LIVE SETUP ENABLED!'
  if test "${DEBUG_LOG}" = '0'; then
    choose 'Do you want to enable the debug log?' '+) Yes' '-) No'
    if test "${?}" = '3'; then
      export DEBUG_LOG=1
      enable_debug_log
    fi
  fi
fi

SYS_INIT_STATUS=0

if test -f "${ANDROID_ROOT:-/system_root/system}/build.prop"; then
  SYS_PATH="${ANDROID_ROOT:-/system_root/system}"
elif test -f '/system_root/system/build.prop'; then
  SYS_PATH='/system_root/system'
elif test -f '/mnt/system/system/build.prop'; then
  SYS_PATH='/mnt/system/system'
elif test -f '/system/system/build.prop'; then
  SYS_PATH='/system/system'
elif test -f '/system/build.prop'; then
  SYS_PATH='/system'
else
  SYS_INIT_STATUS=1

  if test -n "${ANDROID_ROOT:-}" && test "${ANDROID_ROOT:-}" != '/system_root' && test "${ANDROID_ROOT:-}" != '/system' && mount_partition "${ANDROID_ROOT:-}" && test -f "${ANDROID_ROOT:-}/build.prop"; then
    SYS_PATH="${ANDROID_ROOT:-}"
  elif test -e '/system_root' && mount_partition '/system_root' && test -f '/system_root/system/build.prop'; then
    SYS_PATH='/system_root/system'
  elif test -e '/mnt/system' && mount_partition '/mnt/system' && test -f '/mnt/system/system/build.prop'; then
    SYS_PATH='/mnt/system/system'
  elif test -e '/system' && mount_partition '/system' && test -f '/system/system/build.prop'; then
    SYS_PATH='/system/system'
  elif test -f '/system/build.prop'; then
    SYS_PATH='/system'
  else
    ui_error 'The ROM cannot be found'
  fi
fi

if test "${SYS_PATH:?}" = '/system' && is_mounted_read_only "${SYS_PATH:?}"; then
  ui_warning "The '${SYS_PATH:-}' partition is read-only, it will be remounted"
  remount_read_write "${SYS_PATH:?}"
  is_mounted_read_only "${SYS_PATH:?}" && ui_error "The remounting of '${SYS_PATH:?}' has failed"
fi

cp -pf "${SYS_PATH}/build.prop" "${TMP_PATH}/build.prop" # Cache the file for faster access
package_extract_file 'module.prop' "${TMP_PATH}/module.prop"
install_id="$(simple_get_prop 'id' "${TMP_PATH}/module.prop")" || ui_error 'Failed to parse id string'
install_version="$(simple_get_prop 'version' "${TMP_PATH}/module.prop")" || ui_error 'Failed to parse version string'
install_version_code="$(simple_get_prop 'versionCode' "${TMP_PATH}/module.prop")" || ui_error 'Failed to parse version code'

INSTALLATION_SETTINGS_FILE="${install_id}.prop"
API="$(build_getprop 'build\.version\.sdk')"
readonly API

if test "${API:?}" -ge 19; then # KitKat or higher
  PRIVAPP_FOLDER='priv-app'
else
  PRIVAPP_FOLDER='app'
fi
PRIVAPP_PATH="${SYS_PATH:?}/${PRIVAPP_FOLDER:?}"
readonly PRIVAPP_FOLDER PRIVAPP_PATH
if test ! -e "${PRIVAPP_PATH:?}"; then ui_error 'The priv-app folder does NOT exist'; fi

if test "${API:?}" -ge 8; then
  : ### Supported Android versions
elif test "${API:?}" -ge 1; then
  ui_error 'Your Android version is too old'
else
  ui_error 'Invalid API level'
fi

# shellcheck disable=SC2312
ABI_LIST=','$(build_getprop 'product\.cpu\.abi')','$(build_getprop 'product\.cpu\.abi2')','$(build_getprop 'product\.cpu\.abilist')','
if is_substring ',x86,' "${ABI_LIST}"; then
  CPU='x86'
elif is_substring ',armeabi-v7a,' "${ABI_LIST}"; then
  CPU='armeabi-v7a'
elif is_substring ',armeabi,' "${ABI_LIST}"; then
  CPU='armeabi'
fi

if is_substring ',x86_64,' "${ABI_LIST}"; then
  CPU64='x86_64'
elif is_substring ',arm64-v8a,' "${ABI_LIST}"; then
  CPU64='arm64-v8a'
fi

# Info
ui_msg_empty_line
ui_msg '---------------------------'
ui_msg 'microG unofficial installer'
ui_msg "${install_version}"
ui_msg '(by ale5000)'
ui_msg '---------------------------'
ui_msg "Boot mode: ${BOOTMODE:?}"
ui_msg "Recovery API ver: ${RECOVERY_API_VER:-}"
ui_msg_empty_line
ui_msg "Android API: ${API:?}"
ui_msg "Main 64-bit CPU arch: ${CPU64:?}"
ui_msg "Main 32-bit CPU arch: ${CPU:?}"
ui_msg "System path: ${SYS_PATH:?}"
ui_msg "Priv-app path: ${PRIVAPP_PATH:?}"

if test ! -e "${SYS_PATH:?}/framework/framework-res.apk"; then ui_error "The file '${SYS_PATH:?}/framework/framework-res.apk' does NOT exist"; fi
zip_extract_file "${SYS_PATH}/framework/framework-res.apk" 'AndroidManifest.xml' "${TMP_PATH}/framework-res"
XML_MANIFEST="${TMP_PATH}/framework-res/AndroidManifest.xml"
# Detect the presence of the fake signature permission
# Note: It won't detect it if signature spoofing doesn't require a permission, but it is still fine for our case
if search_ascii_string_as_utf16_in_file 'android.permission.FAKE_PACKAGE_SIGNATURE' "${XML_MANIFEST}"; then
  FAKE_SIGN=true
fi
ui_msg "Fake signature: ${FAKE_SIGN}"
ui_msg_empty_line

if is_substring ',armeabi,' "${ABI_LIST}" && ! is_substring ',armeabi-v7a,' "${ABI_LIST}"; then LEGACY_ARM=true; fi

if test "${CPU}" = false && test "${CPU64}" = false; then
  ui_error "Unsupported CPU, ABI list: ${ABI_LIST}"
fi

# Extracting
ui_msg 'Extracting...'
custom_package_extract_dir 'origin' "${TMP_PATH:?}"
custom_package_extract_dir 'files' "${TMP_PATH:?}"
custom_package_extract_dir 'addon.d' "${TMP_PATH:?}"

# Setting up permissions
ui_debug 'Setting up permissions...'
set_std_perm_recursive "${TMP_PATH:?}/origin"
set_std_perm_recursive "${TMP_PATH:?}/files"
if test -e "${TMP_PATH:?}/addon.d"; then set_std_perm_recursive "${TMP_PATH:?}/addon.d"; fi
set_perm 0 0 0755 "${TMP_PATH:?}/addon.d/00-1-microg.sh"

# Verifying
ui_msg_sameline_start 'Verifying... '
ui_debug ''
if verify_sha1 "${TMP_PATH}/files/app/DejaVuBackend.apk" '9a6ffed69c510a06a719a2d52c3fd49218f71806' &&
  verify_sha1 "${TMP_PATH}/files/app/IchnaeaNlpBackend.apk" 'b853c1b177b611310219cc6571576bd455fa3e9e' &&
  verify_sha1 "${TMP_PATH}/files/app/NominatimGeocoderBackend.apk" '40b0917e9805cdab5abc53925f8732bff9ba8d84' &&
  verify_sha1 "${TMP_PATH}/files/framework/com.google.android.maps.jar" '14ce63b333e3c53c793e5eabfd7d554f5e7b56c7'; then
  ui_msg_sameline_end 'OK'
else
  ui_msg_sameline_end 'ERROR'
  ui_error 'Verification failed'
  sleep 1
fi

# Preparing
ui_msg 'Preparing...'

# Check the existance of the libraries folders
if test "${API:?}" -ge 9 && test "${API:?}" -lt 21; then
  if test "${CPU}" != false && test ! -e "${SYS_PATH:?}/lib"; then create_dir "${SYS_PATH:?}/lib"; fi
  if test "${CPU64}" != false && test ! -e "${SYS_PATH:?}/lib64"; then create_dir "${SYS_PATH:?}/lib64"; fi
fi

setup_app 1 'UnifiedNlp (legacy)' 'LegacyNetworkLocation' 'app' false false

setup_app 1 'microG Services Core (vtm-legacy)' 'GmsCoreVtmLegacy' 'priv-app' false false
if test "${GMSCORE_VERSION:?}" = 'auto' && test "${CPU}" != 'armeabi'; then
  setup_app 1 'microG Services Core' 'GmsCore' 'priv-app' false false
else
  setup_app 1 'microG Services Core (vtm)' 'GmsCoreVtm' 'priv-app' false false
fi

setup_app 1 'microG Services Framework Proxy' 'GoogleServicesFramework' 'priv-app' false false

setup_app "${INSTALL_PLAYSTORE:-}" 'Google Play Store (legacy)' 'PlayStoreLegacy' 'priv-app' true
app_1_is_installed="${?}"
setup_app "${INSTALL_PLAYSTORE:-}" 'Google Play Store' 'PlayStore' 'priv-app' true
app_2_is_installed="${?}"

# Fallback to FakeStore if the selected market is missing
market_is_fakestore='false'
if {
  test "${app_1_is_installed:?}" -ne 0 && test "${app_2_is_installed:?}" -ne 0
} || test ! -f "${TMP_PATH}/files/priv-app/Phonesky.apk"; then
  market_is_fakestore='true'
  setup_app 1 'FakeStore' 'FakeStore' 'priv-app' false false
fi
unset app_1_is_installed app_2_is_installed

if test "${market_is_fakestore:?}" = 'true'; then
  move_rename_file "${TMP_PATH:?}/origin/etc/microg.xml" "${TMP_PATH:?}/files/etc/microg.xml"
else
  move_rename_file "${TMP_PATH:?}/origin/etc/microg-gcm.xml" "${TMP_PATH:?}/files/etc/microg.xml"
fi

setup_app "${INSTALL_FDROIDPRIVEXT:?}" 'F-Droid Privileged Extension' 'FDroidPrivilegedExtension' 'priv-app'

setup_app "${INSTALL_NEWPIPE:?}" 'NewPipe Legacy' 'NewPipeLegacy' 'app' true
setup_app "${INSTALL_NEWPIPE:?}" 'NewPipe (old)' 'NewPipeOld' 'app' true
setup_app "${INSTALL_NEWPIPE:?}" 'NewPipe' 'NewPipe' 'app' true

setup_app "${INSTALL_ANDROIDAUTO:-}" 'Android Auto stub' 'AndroidAuto' 'priv-app' true

# Extracting libs
if test "${API:?}" -ge 9; then
  ui_msg 'Extracting libs...'
  create_dir "${TMP_PATH:?}/libs"
  zip_extract_dir "${TMP_PATH:?}/files/priv-app/GmsCore.apk" 'lib' "${TMP_PATH:?}/libs"
fi

# Setting up libs permissions
if test "${API:?}" -ge 9; then
  ui_debug 'Setting up libs permissions...'
  set_std_perm_recursive "${TMP_PATH:?}/libs"
fi

delete "${TMP_PATH:?}/origin"

# MOUNT /data PARTITION
DATA_INIT_STATUS=0
if test "${TEST_INSTALL:-false}" = 'false' && ! is_mounted '/data'; then
  DATA_INIT_STATUS=1
  mount '/data'
  if ! is_mounted '/data'; then ui_error '/data cannot be mounted'; fi
fi

# Resetting Android runtime permissions
if test "${API}" -ge 23; then
  if test -e '/data/system/users/0/runtime-permissions.xml'; then
    if ! grep -q 'com.google.android.gms' /data/system/users/*/runtime-permissions.xml; then
      # Purge the runtime permissions to prevent issues when the user flash this on a dirty install
      ui_msg "Resetting legacy Android runtime permissions..."
      delete /data/system/users/*/runtime-permissions.xml
    fi
  fi
  if test -e '/data/misc_de/0/apexdata/com.android.permission/runtime-permissions.xml'; then
    if ! grep -q 'com.google.android.gms' /data/misc_de/*/apexdata/com.android.permission/runtime-permissions.xml; then
      # Purge the runtime permissions to prevent issues when the user flash this on a dirty install
      ui_msg "Resetting Android runtime permissions..."
      delete /data/misc_de/*/apexdata/com.android.permission/runtime-permissions.xml
    fi
  fi
fi

mount_extra_partitions_silent

# Clean previous installations
if test "${API:?}" -ge 9 && test "${API:?}" -lt 21; then
  if test "${CPU}" != false; then
    delete "${SYS_PATH:?}/lib/libvtm-jni.so"
    delete "${SYS_PATH:?}/lib/libmapbox-gl.so"
    delete "${SYS_PATH:?}/lib/libconscrypt_jni.so"
    delete "${SYS_PATH:?}/lib/libconscrypt_gmscore_jni.so"
    delete "${SYS_PATH:?}/lib/libcronet".*."so"
  fi
  if test "${CPU64}" != false; then
    delete "${SYS_PATH:?}/lib64/libvtm-jni.so"
    delete "${SYS_PATH:?}/lib64/libmapbox-gl.so"
    delete "${SYS_PATH:?}/lib64/libconscrypt_jni.so"
    delete "${SYS_PATH:?}/lib64/libconscrypt_gmscore_jni.so"
    delete "${SYS_PATH:?}/lib64/libcronet".*."so"
  fi
fi
delete "${SYS_PATH:?}/etc/zips/${install_id:?}.prop"
# shellcheck source=SCRIPTDIR/uninstall.sh
. "${TMP_PATH:?}/uninstall.sh"

unmount_extra_partitions

# Configuring default Android permissions
if test "${API}" -ge 23; then
  ui_debug 'Configuring default Android permissions...'
  if ! test -e "${SYS_PATH}/etc/default-permissions"; then
    ui_msg 'Creating the default permissions folder...'
    create_dir "${SYS_PATH}/etc/default-permissions"
  fi

  if test "${API}" -ge 29; then # Android 10+
    replace_line_in_file "${TMP_PATH}/files/etc/default-permissions/google-permissions.xml" '<!-- %ACCESS_BACKGROUND_LOCATION% -->' '        <permission name="android.permission.ACCESS_BACKGROUND_LOCATION" fixed="false" whitelisted="true" />'
  fi
  if test "${FAKE_SIGN}" = true; then
    replace_line_in_file "${TMP_PATH}/files/etc/default-permissions/google-permissions.xml" '<!-- %FAKE_PACKAGE_SIGNATURE% -->' '        <permission name="android.permission.FAKE_PACKAGE_SIGNATURE" fixed="false" />'
    if test -e "${TMP_PATH}/files/etc/default-permissions/default-permissions-Phonesky.xml"; then
      replace_line_in_file "${TMP_PATH}/files/etc/default-permissions/default-permissions-Phonesky.xml" '<!-- %FAKE_PACKAGE_SIGNATURE% -->' '        <permission name="android.permission.FAKE_PACKAGE_SIGNATURE" fixed="false" />'
    fi
  fi

  copy_dir_content "${TMP_PATH}/files/etc/default-permissions" "${SYS_PATH}/etc/default-permissions"
else
  delete_recursive "${TMP_PATH}/files/etc/default-permissions"
fi

if test "${live_setup_enabled:?}" = 'true'; then
  choose 'Do you want to reset GMS data of all apps?' '+) Yes' '-) No'
  if test "$?" -eq 3; then reset_gms_data_of_all_apps; fi
elif test "${RESET_GMS_DATA_OF_ALL_APPS:?}" -eq 1; then
  reset_gms_data_of_all_apps
fi

# UNMOUNT /data PARTITION
if test "${DATA_INIT_STATUS}" = '1'; then unmount '/data'; fi

# Preparing 2
ui_msg 'Preparing 2...'

if test "${API:?}" -lt 18; then delete "${TMP_PATH}/files/app/DejaVuBackend.apk"; fi
if test "${API:?}" -lt 10; then delete "${TMP_PATH}/files/app/IchnaeaNlpBackend.apk"; fi
if test "${API:?}" -lt 9; then delete "${TMP_PATH}/files/app/NominatimGeocoderBackend.apk"; fi
if test -e "${TMP_PATH:?}/files/priv-app" && test "${PRIVAPP_FOLDER:?}" != 'priv-app'; then
  copy_dir_content "${TMP_PATH:?}/files/priv-app" "${TMP_PATH:?}/files/${PRIVAPP_FOLDER:?}"
  delete "${TMP_PATH:?}/files/priv-app"
fi
delete_dir_if_empty "${TMP_PATH:?}/files/app"

if test "${API:?}" -ge 21; then
  # Move apps into subdirs
  if test -e "${TMP_PATH:?}/files/priv-app"; then
    for entry in "${TMP_PATH:?}/files/priv-app"/*; do
      path_without_ext=$(remove_ext "${entry}")

      create_dir "${path_without_ext}"
      mv -f "${entry}" "${path_without_ext}"/
    done
  fi
  if test -e "${TMP_PATH:?}/files/app"; then
    for entry in "${TMP_PATH:?}/files/app"/*; do
      path_without_ext=$(remove_ext "${entry}")

      create_dir "${path_without_ext}"
      mv -f "${entry}" "${path_without_ext}"/
    done
  fi

  # The name of the following architectures remain unchanged: x86, x86_64, mips, mips64
  move_rename_dir "${TMP_PATH}/libs/lib/arm64-v8a" "${TMP_PATH}/libs/lib/arm64"
  if test "${LEGACY_ARM}" != true; then
    move_rename_dir "${TMP_PATH}/libs/lib/armeabi-v7a" "${TMP_PATH}/libs/lib/arm"
    delete_recursive "${TMP_PATH}/libs/lib/armeabi"
  else
    move_rename_dir "${TMP_PATH}/libs/lib/armeabi" "${TMP_PATH}/libs/lib/arm"
    delete_recursive "${TMP_PATH}/libs/lib/armeabi-v7a"
  fi

  create_dir "${TMP_PATH}/files/priv-app/GmsCore/lib"
  move_dir_content "${TMP_PATH}/libs/lib" "${TMP_PATH}/files/priv-app/GmsCore/lib"
fi

if test "${API:?}" -lt 9; then
  delete "${TMP_PATH:?}/files/framework/com.google.android.maps.jar"
  delete "${TMP_PATH:?}/files/etc/permissions/com.google.android.maps.xml"
fi
delete_dir_if_empty "${TMP_PATH:?}/files/framework"

# Installing
ui_msg 'Installing...'
if test -e "${TMP_PATH:?}/files/etc/microg.xml"; then copy_file "${TMP_PATH:?}/files/etc/microg.xml" "${SYS_PATH:?}/etc"; fi
if test -e "${TMP_PATH:?}/files/etc/org.fdroid.fdroid"; then copy_dir_content "${TMP_PATH:?}/files/etc/org.fdroid.fdroid" "${SYS_PATH:?}/etc/org.fdroid.fdroid"; fi
if test -e "${TMP_PATH:?}/files/app"; then copy_dir_content "${TMP_PATH:?}/files/app" "${SYS_PATH:?}/app"; fi
if test -e "${TMP_PATH:?}/files/priv-app"; then copy_dir_content "${TMP_PATH:?}/files/priv-app" "${PRIVAPP_PATH:?}"; fi

if test "${API:?}" -lt 26; then
  delete "${TMP_PATH}/files/etc/permissions/privapp-permissions-google.xml"
else
  if test "${FAKE_SIGN}" = true; then
    replace_line_in_file "${TMP_PATH}/files/etc/permissions/privapp-permissions-google.xml" '<!-- %FAKE_PACKAGE_SIGNATURE% -->' '        <permission name="android.permission.FAKE_PACKAGE_SIGNATURE" />'
  fi
fi
delete_dir_if_empty "${TMP_PATH:?}/files/etc/permissions"
if test -e "${TMP_PATH:?}/files/etc/permissions"; then copy_dir_content "${TMP_PATH:?}/files/etc/permissions" "${SYS_PATH:?}/etc/permissions"; fi
if test -e "${TMP_PATH:?}/files/framework"; then copy_dir_content "${TMP_PATH:?}/files/framework" "${SYS_PATH:?}/framework"; fi

if test "${API:?}" -ge 21; then
  copy_dir_content "${TMP_PATH:?}/files/etc/sysconfig" "${SYS_PATH:?}/etc/sysconfig"
else
  delete_recursive "${TMP_PATH:?}/files/etc/sysconfig"
fi

delete_dir_if_empty "${TMP_PATH:?}/files/etc"

if test "${API:?}" -ge 9 && test "${API:?}" -lt 21; then
  if test "${CPU}" != false; then
    move_rename_dir "${TMP_PATH:?}/libs/lib/${CPU}" "${TMP_PATH:?}/files/lib"
    copy_dir_content "${TMP_PATH:?}/files/lib" "${SYS_PATH:?}/lib"
  fi
  if test "${CPU64}" != false; then
    move_rename_dir "${TMP_PATH:?}/libs/lib/${CPU64}" "${TMP_PATH:?}/files/lib64"
    copy_dir_content "${TMP_PATH:?}/files/lib64" "${SYS_PATH:?}/lib64"
  fi
fi
delete_recursive "${TMP_PATH:?}/libs"

USED_SETTINGS_PATH="${TMP_PATH:?}/files/etc/zips"
create_dir "${USED_SETTINGS_PATH:?}"

{
  echo '# SPDX-FileCopyrightText: none'
  echo '# SPDX-License-Identifier: CC0-1.0'
  echo '# SPDX-FileType: OTHER'
  echo ''
  echo 'install.type=flashable-zip'
  echo "install.version.code=${install_version_code}"
  echo "install.version=${install_version}"
  echo "fakestore=${market_is_fakestore:?}"
} > "${USED_SETTINGS_PATH:?}/${INSTALLATION_SETTINGS_FILE:?}"
set_perm 0 0 0640 "${USED_SETTINGS_PATH:?}/${INSTALLATION_SETTINGS_FILE:?}"

create_dir "${SYS_PATH:?}/etc/zips"
set_perm 0 0 0750 "${SYS_PATH:?}/etc/zips"

copy_dir_content "${USED_SETTINGS_PATH:?}" "${SYS_PATH:?}/etc/zips"

if test "${API:?}" -ge 23; then
  ui_msg 'Installing utilities...'
  set_perm 0 2000 0755 "${TMP_PATH:?}/files/bin/minutil.sh"
  move_rename_file "${TMP_PATH:?}/files/bin/minutil.sh" "${TMP_PATH:?}/files/bin/minutil"
  copy_dir_content "${TMP_PATH:?}/files/bin" "${SYS_PATH:?}/bin"
else
  delete_recursive "${TMP_PATH:?}/files/bin"
fi

# Install survival script
if test -e "${SYS_PATH:?}/addon.d"; then
  ui_msg 'Installing survival script...'
  write_file_list "${TMP_PATH}/files" "${TMP_PATH}/files/" "${TMP_PATH}/backup-filelist.lst"
  replace_line_in_file_with_file "${TMP_PATH}/addon.d/00-1-microg.sh" '%PLACEHOLDER-1%' "${TMP_PATH}/backup-filelist.lst"
  copy_file "${TMP_PATH}/addon.d/00-1-microg.sh" "${SYS_PATH}/addon.d"
fi

if test "${SYS_INIT_STATUS:?}" = '1'; then
  if test -e '/system_root'; then unmount '/system_root'; fi
  if test -e '/mnt/system'; then unmount '/mnt/system'; fi
  if test -e '/system'; then unmount '/system'; fi
fi

touch "${TMP_PATH:?}/installed"
ui_msg 'Installation finished.'
