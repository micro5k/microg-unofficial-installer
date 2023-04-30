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
  # Unsupported set options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue
  (set -o posix 2> /dev/null) && set -o posix || true
  (set -o pipefail) && set -o pipefail || true
}

### GLOBAL VARIABLES ###

TMP_PATH="${2:?}"

CPU=false
CPU64=false
LEGACY_ARM=false
FAKE_SIGN=false

### FUNCTIONS ###

# shellcheck source=SCRIPTDIR/../inc/common-functions.sh
. "${TMP_PATH:?}/inc/common-functions.sh" || exit "${?}"

### CODE ###

initialize

INSTALL_FDROIDPRIVEXT="$(parse_setting 'INSTALL_FDROIDPRIVEXT' "${INSTALL_FDROIDPRIVEXT:?}")"
INSTALL_AURORASERVICES="$(parse_setting 'INSTALL_AURORASERVICES' "${INSTALL_AURORASERVICES:?}")"
INSTALL_NEWPIPE="$(parse_setting 'INSTALL_NEWPIPE' "${INSTALL_NEWPIPE:?}")"
INSTALL_PLAYSTORE="$(parse_setting 'INSTALL_PLAYSTORE' "${INSTALL_PLAYSTORE:-}")"
INSTALL_ANDROIDAUTO="$(parse_setting 'INSTALL_ANDROIDAUTO' "${INSTALL_ANDROIDAUTO:-}")"

INSTALLATION_SETTINGS_FILE="${MODULE_ID:?}.prop"
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
ui_msg "$(write_separator_line "${#MODULE_NAME}" '-' || true)"
ui_msg "${MODULE_NAME:?}"
ui_msg "${MODULE_VERSION:?}"
ui_msg "(by ${MODULE_AUTHOR:?})"
ui_msg "$(write_separator_line "${#MODULE_NAME}" '-' || true)"

ui_msg "Device: ${BUILD_DEVICE?}"
ui_msg "Emulator: ${IS_EMU:?}"
ui_msg_empty_line
ui_msg "Boot mode: ${BOOTMODE:?}"
ui_msg "Sideload: ${SIDELOAD:?}"
if test "${ZIP_INSTALL:?}" = 'true'; then
  ui_msg "Zip install: ${ZIP_INSTALL:?} (${ZIPINSTALL_VERSION?})"
else
  ui_msg "Zip install: ${ZIP_INSTALL:?}"
fi
ui_msg "Recovery API ver: ${RECOVERY_API_VER:-}"
ui_msg_empty_line
ui_msg "Android API: ${API:?}"
ui_msg "Main 64-bit CPU arch: ${CPU64:?}"
ui_msg "Main 32-bit CPU arch: ${CPU:?}"
ui_msg_empty_line
ui_msg "Verity mode: ${VERITY_MODE:-disabled}"
ui_msg "Dynamic partitions: ${DYNAMIC_PARTITIONS:?}"
ui_msg "Current slot: ${SLOT:-no slot}"
ui_msg "Recov. fake system: ${RECOVERY_FAKE_SYSTEM:?}"
ui_msg_empty_line
ui_msg "System mount point: ${SYS_MOUNTPOINT:?}"
ui_msg "System path: ${SYS_PATH:?}"
ui_msg "Priv-app path: ${PRIVAPP_PATH:?}"
ui_msg_empty_line
ui_msg "Android root ENV: ${ANDROID_ROOT:-}"

zip_extract_file "${SYS_PATH}/framework/framework-res.apk" 'AndroidManifest.xml' "${TMP_PATH}/framework-res"
XML_MANIFEST="${TMP_PATH}/framework-res/AndroidManifest.xml"
# Detect the presence of the fake signature permission
# Note: It won't detect it if signature spoofing doesn't require a permission, but it is still fine for our case
if search_ascii_string_as_utf16_in_file 'android.permission.FAKE_PACKAGE_SIGNATURE' "${XML_MANIFEST}"; then
  FAKE_SIGN=true
fi
ui_msg "Fake signature: ${FAKE_SIGN}"
ui_msg "$(write_separator_line "${#MODULE_NAME}" '-' || true)"
ui_msg_empty_line

if is_substring ',armeabi,' "${ABI_LIST}" && ! is_substring ',armeabi-v7a,' "${ABI_LIST}"; then LEGACY_ARM=true; fi

if test "${CPU}" = false && test "${CPU64}" = false; then
  ui_error "Unsupported CPU, ABI list: ${ABI_LIST}"
fi

if test "${IS_INSTALLATION:?}" = 'true'; then
  ui_msg 'Starting installation...'
  ui_msg_empty_line

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
  if test "${CPU}" != 'armeabi'; then
    setup_app 1 'microG Services Core' 'GmsCore' 'priv-app' false false
  else
    setup_app 1 'microG Services Core (vtm)' 'GmsCoreVtm' 'priv-app' false false
  fi

  setup_app 1 'microG Services Framework Proxy' 'GoogleServicesFramework' 'priv-app' false false

  if test "${IS_EMU:?}" = 'true'; then
    move_rename_file "${TMP_PATH:?}/origin/profiles/lenovo_yoga_tab_3_pro_10_inches_23.xml" "${TMP_PATH:?}/files/etc/microg_device_profile.xml"
  fi

  # Store selection
  market_is_fakestore='false'
  if setup_app "${INSTALL_PLAYSTORE:-}" 'Google Play Store' 'PlayStore' 'priv-app' true ||
    setup_app "${INSTALL_PLAYSTORE:-}" 'Google Play Store (legacy)' 'PlayStoreLegacy' 'priv-app' true; then
    :
  else
    # Fallback to FakeStore
    market_is_fakestore='true'
    setup_app 1 'FakeStore' 'FakeStore' 'priv-app' false false
  fi

  if test "${market_is_fakestore:?}" = 'true'; then
    move_rename_file "${TMP_PATH:?}/origin/etc/microg.xml" "${TMP_PATH:?}/files/etc/microg.xml"
  else
    move_rename_file "${TMP_PATH:?}/origin/etc/microg-gcm.xml" "${TMP_PATH:?}/files/etc/microg.xml"
  fi

  setup_app "${INSTALL_FDROIDPRIVEXT:?}" 'F-Droid Privileged Extension' 'FDroidPrivilegedExtension' 'priv-app'
  setup_app "${INSTALL_AURORASERVICES:?}" 'Aurora Services' 'AuroraServices' 'priv-app'

  setup_app "${INSTALL_NEWPIPE:?}" 'NewPipe' 'NewPipe' 'app' true ||
    setup_app "${INSTALL_NEWPIPE:?}" 'NewPipe (old)' 'NewPipeOld' 'app' true ||
    setup_app "${INSTALL_NEWPIPE:?}" 'NewPipe Legacy' 'NewPipeLegacy' 'app' true

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
else
  ui_msg 'Starting uninstallation...'
  ui_msg_empty_line
fi

# Resetting Android runtime permissions
if test "${API}" -ge 23; then
  if test -e "${DATA_PATH:?}/system/users/0/runtime-permissions.xml"; then
    if ! grep -q 'com.google.android.gms' "${DATA_PATH:?}"/system/users/*/runtime-permissions.xml; then
      # Purge the runtime permissions to prevent issues when the user flash this on a dirty install
      ui_msg "Resetting legacy Android runtime permissions..."
      delete "${DATA_PATH:?}"/system/users/*/runtime-permissions.xml
    fi
  fi
  if test -e "${DATA_PATH:?}/misc_de/0/apexdata/com.android.permission/runtime-permissions.xml"; then
    if ! grep -q 'com.google.android.gms' "${DATA_PATH:?}"/misc_de/*/apexdata/com.android.permission/runtime-permissions.xml; then
      # Purge the runtime permissions to prevent issues when the user flash this on a dirty install
      ui_msg "Resetting Android runtime permissions..."
      delete "${DATA_PATH:?}"/misc_de/*/apexdata/com.android.permission/runtime-permissions.xml
    fi
  fi
fi

if test "${IS_INSTALLATION:?}" = 'true'; then
  # Kill the apps if they were active and disable them
  kill_and_disable_app com.android.vending
  kill_and_disable_app com.google.android.gsf
  kill_and_disable_app com.google.android.gms

  clear_app com.android.vending
  clear_app com.google.android.gsf

  kill_app com.google.android.gsf.login
  clear_app com.google.android.gsf.login
fi

# Clean previous installations
if test "${API:?}" -ge 9 && test "${API:?}" -lt 21; then
  if test "${CPU}" != false; then
    delete "${SYS_PATH:?}/lib/libmapbox-gl.so"
    delete "${SYS_PATH:?}/lib/libvtm-jni.so"
    delete "${SYS_PATH:?}/lib/libconscrypt_gmscore_jni.so"
    delete "${SYS_PATH:?}/lib/libconscrypt_jni.so"
    delete "${SYS_PATH:?}/lib/libcronet".*."so"
    delete "${SYS_PATH:?}/lib/libgmscore.so"
    delete "${SYS_PATH:?}/lib/"libempty_*.so
    delete "${SYS_PATH:?}/lib/"libmappedcountercacheversionjni.so
    delete "${SYS_PATH:?}/lib/"libphonesky_data_loader.so
  fi
  if test "${CPU64}" != false; then
    delete "${SYS_PATH:?}/lib64/libmapbox-gl.so"
    delete "${SYS_PATH:?}/lib64/libvtm-jni.so"
    delete "${SYS_PATH:?}/lib64/libconscrypt_gmscore_jni.so"
    delete "${SYS_PATH:?}/lib64/libconscrypt_jni.so"
    delete "${SYS_PATH:?}/lib64/libcronet".*."so"
    delete "${SYS_PATH:?}/lib64/libgmscore.so"
    delete "${SYS_PATH:?}/lib64/"libempty_*.so
    delete "${SYS_PATH:?}/lib64/"libmappedcountercacheversionjni.so
    delete "${SYS_PATH:?}/lib64/"libphonesky_data_loader.so
  fi
fi
delete "${SYS_PATH:?}/etc/zips/${MODULE_ID:?}.prop"

readonly INSTALLER='true'
export INSTALLER
# shellcheck source=SCRIPTDIR/uninstall.sh
. "${TMP_PATH:?}/uninstall.sh"

unmount_extra_partitions

if test "${IS_INSTALLATION:?}" != 'true'; then
  reset_gms_data_of_all_apps
  deinitialize

  touch "${TMP_PATH:?}/installed"
  ui_msg 'Uninstallation finished.'

  exit 0
fi

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

if test "${LIVE_SETUP_ENABLED:?}" = 'true'; then
  choose 'Do you want to reset GMS data of all apps?' '+) Yes' '-) No'
  if test "$?" -eq 3; then reset_gms_data_of_all_apps; fi
elif test "${RESET_GMS_DATA_OF_ALL_APPS:?}" -ne 0; then
  reset_gms_data_of_all_apps
fi

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
if test -f "${TMP_PATH:?}/files/etc/microg_device_profile.xml"; then copy_file "${TMP_PATH:?}/files/etc/microg_device_profile.xml" "${SYS_PATH:?}/etc"; fi
if test -f "${TMP_PATH:?}/files/etc/microg.xml"; then copy_file "${TMP_PATH:?}/files/etc/microg.xml" "${SYS_PATH:?}/etc"; fi
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
  echo "install.version.code=${MODULE_VERCODE:?}"
  echo "install.version=${MODULE_VERSION:?}"
  echo "fakestore=${market_is_fakestore:?}"
} > "${USED_SETTINGS_PATH:?}/${INSTALLATION_SETTINGS_FILE:?}"
set_perm 0 0 0640 "${USED_SETTINGS_PATH:?}/${INSTALLATION_SETTINGS_FILE:?}"

create_dir "${SYS_PATH:?}/etc/zips"
set_perm 0 0 0750 "${SYS_PATH:?}/etc/zips"

copy_dir_content "${USED_SETTINGS_PATH:?}" "${SYS_PATH:?}/etc/zips"

# Install utilities
if test "${API:?}" -ge 19; then
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

enable_app com.google.android.gms
enable_app com.google.android.gsf
enable_app com.android.vending

if test "${BOOTMODE:?}" = 'true' && command -v am 1> /dev/null; then
  am broadcast -a 'org.microg.gms.gcm.FORCE_TRY_RECONNECT' -n 'com.google.android.gms/org.microg.gms.gcm.TriggerReceiver' 1> /dev/null 2>&1 || true
fi

deinitialize

touch "${TMP_PATH:?}/installed"
ui_msg 'Installation finished.'
