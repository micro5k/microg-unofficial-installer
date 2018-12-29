#!/sbin/sh

<<LICENSE
  Copyright (C) 2016-2018  ale5000
  This file was created by ale5000 (ale5000-git on GitHub).

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version, w/ zip exception.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
LICENSE

### GLOBAL VARIABLES ###

export INSTALLER=1
TMP_PATH="$2"

CPU=false
CPU64=false
LEGACY_ARM=false
LEGACY_ANDROID=false
OLD_ANDROID=false
FAKE_SIGN=false
SYS_ROOT_IMAGE=''
SYS_PATH='/system'
MARKET_FILENAME=''
INSTALLATION_SETTINGS_FILE='ug.prop'


### FUNCTIONS ###

. "$TMP_PATH/inc/common.sh"


### CODE ###

if ! is_mounted '/system'; then
  mount '/system'
  if ! is_mounted '/system'; then ui_error '/system cannot be mounted'; fi
fi

SYS_ROOT_IMAGE=$(getprop 'build.system_root_image')
if [[ -z "$SYS_ROOT_IMAGE" ]]; then
  SYS_ROOT_IMAGE=false;
elif [[ $SYS_ROOT_IMAGE == true && -e '/system/system' ]]; then
  SYS_PATH='/system/system';
fi

test -f "${SYS_PATH}/build.prop" || ui_error 'The ROM cannot be found'
cp -pf "${SYS_PATH}/build.prop" "$TMP_PATH/build.prop"  # Cache the file for faster access

PRIVAPP_PATH="${SYS_PATH}/app"
if [[ -d "${SYS_PATH}/priv-app" ]]; then PRIVAPP_PATH="${SYS_PATH}/priv-app"; fi  # Detect the position of the privileged apps folder

API=$(build_getprop 'build\.version\.sdk')
if [[ $API -ge 21 ]]; then
  :  ### New Android versions
elif [[ $API -ge 19 ]]; then
  OLD_ANDROID=true
elif [[ $API -ge 9 ]]; then
  LEGACY_ANDROID=true
  OLD_ANDROID=true
elif [[ $API -ge 1 ]]; then
  ui_error 'Your Android version is too old'
else
  ui_error 'Invalid API level'
fi

ABI_LIST=','$(build_getprop 'product\.cpu\.abi')','$(build_getprop 'product\.cpu\.abi2')','$(build_getprop 'product\.cpu\.abilist')','
if is_substring ',x86,' "$ABI_LIST"; then
  CPU='x86'
elif is_substring ',armeabi-v7a,' "$ABI_LIST"; then
  CPU='armeabi-v7a'
elif is_substring ',armeabi,' "$ABI_LIST"; then
  CPU='armeabi'
fi

if is_substring ',x86_64,' "$ABI_LIST"; then
  CPU64='x86_64'
elif is_substring ',arm64-v8a,' "$ABI_LIST"; then
  CPU64='arm64-v8a'
fi

if is_substring ',armeabi,' "$ABI_LIST" && ! is_substring ',armeabi-v7a,' "$ABI_LIST"; then LEGACY_ARM=true; fi

if [[ "$LIVE_SETUP" -eq 1 ]]; then
  choose 'What market app do you want to install?' '+) Google Play Store' '-) FakeStore'
  if [[ "$?" -eq 3 ]]; then export MARKET='PlayStore'; else export MARKET='FakeStore'; fi
fi

if [[ $MARKET == 'PlayStore' ]]; then
  if [[ $PLAYSTORE_VERSION == 'auto' ]]; then
    if [[ $OLD_ANDROID != true ]]; then
      MARKET_FILENAME="${MARKET}-recent.apk"
    else
      MARKET_FILENAME="${MARKET}-legacy.apk"
    fi
  else
    MARKET_FILENAME="${MARKET}-${PLAYSTORE_VERSION}.apk"
  fi
else
  MARKET_FILENAME="${MARKET}.apk"
fi

# Info
ui_msg ''
ui_msg '---------------------------'
ui_msg 'microG unofficial installer'
ui_msg 'v1.0.33-beta'
ui_msg '(by ale5000)'
ui_msg '---------------------------'
ui_msg ''
ui_msg "API: ${API}"
ui_msg "Detected CPU arch: ${CPU}"
ui_msg "Detected 64-bit CPU arch: ${CPU64}"
ui_msg "System root image: ${SYS_ROOT_IMAGE}"
ui_msg "System path: ${SYS_PATH}"
ui_msg "Privileged apps: ${PRIVAPP_PATH}"

zip_extract_file "${SYS_PATH}/framework/framework-res.apk" 'AndroidManifest.xml' "$TMP_PATH/framework-res"
XML_MANIFEST="$TMP_PATH/framework-res/AndroidManifest.xml"
# Detect the presence of the fake signature permission
# Note: It won't detect it if signature spoofing doesn't require a permission, but it is still fine for our case
if search_ansi_string_in_utf16_file 'android.permission.FAKE_PACKAGE_SIGNATURE' "$XML_MANIFEST" || search_string_in_file 'android.permission.FAKE_PACKAGE_SIGNATURE' "$XML_MANIFEST"; then
  FAKE_SIGN=true
fi
ui_msg "Fake signature: ${FAKE_SIGN}"

ui_msg ''

if [[ $CPU == false && $CPU64 == false ]]; then
  ui_error "Unsupported CPU, ABI list: ${ABI_LIST}"
fi

# Check the existance of the libraries folders
if [[ $OLD_ANDROID == true ]]; then
  if [[ $CPU != false && ! -d "${SYS_PATH}/lib" ]]; then create_dir "${SYS_PATH}/lib"; fi
  if [[ $CPU64 != false && ! -d "${SYS_PATH}/lib64" ]]; then create_dir "${SYS_PATH}/lib64"; fi
fi

# Extracting
ui_msg 'Extracting...'
custom_package_extract_dir 'files' "$TMP_PATH"
custom_package_extract_dir 'addon.d' "$TMP_PATH"

# Setting up permissions
ui_debug 'Setting up permissions...'
set_std_perm_recursive "$TMP_PATH/files"
set_std_perm_recursive "$TMP_PATH/addon.d"
set_perm 0 0 0755 "$TMP_PATH/addon.d/00-1-microg.sh"

# Fallback to FakeStore if the selected market is missing
if ! test -f "$TMP_PATH/files/variants/${MARKET_FILENAME}"; then MARKET_FILENAME='FakeStore.apk'; fi
ui_msg "Selected market app: ${MARKET_FILENAME}"

# Verifying
ui_msg_sameline_start 'Verifying... '
if verify_sha1 "$TMP_PATH/files/priv-app/GmsCore.apk" 'da538490beadc760a7a8519ec5ed367f19ae8d7b' &&
   verify_sha1 "$TMP_PATH/files/priv-app-kk/GmsCore.apk" '52890ef5d04abd563fa220725708fd2bc48e894e' &&  # ToDO: Remove when bug #379 is fixed
   verify_sha1 "$TMP_PATH/files/priv-app/GoogleServicesFramework.apk" 'f9907df2e2c8fd20cd2e928821641fa01fca09ce' &&
   verify_sha1 "$TMP_PATH/files/priv-app/DroidGuard.apk" '71603d196245565fe384a18bd9f4637bca136b06' &&
   verify_sha1 "$TMP_PATH/files/app/NewPipe.apk" 'b2ce8526126472fdf96b7b2a67c65347424fa31c' &&
   verify_sha1 "$TMP_PATH/files/app/DejaVuBackend.apk" '3d3f650c9b9a3ed3765cffb3307de76d2bd4a149' &&
   verify_sha1 "$TMP_PATH/files/app/IchnaeaNlpBackend.apk" 'ef9fad611ab2cf2e68cdc7d05af4496998e8d3b5' &&
   verify_sha1 "$TMP_PATH/files/app/NominatimGeocoderBackend.apk" '40b0917e9805cdab5abc53925f8732bff9ba8d84' &&
   ###verify_sha1 "$TMP_PATH/files/app/PlayGames.apk" 'c99c27053bf518dd3d08449e9478b43de0da50ed' &&
   verify_sha1 "$TMP_PATH/files/framework/com.google.android.maps.jar" '14ce63b333e3c53c793e5eabfd7d554f5e7b56c7' &&
   verify_sha1 "$TMP_PATH/files/etc/permissions/com.google.android.maps.xml" 'f4d7d0ff10e96a6e0856223354f06e2f6b6efa54' &&
   verify_sha1 "$TMP_PATH/files/etc/permissions/features.xml" '16839289f4c763a21a2e24af9f8aa3f38435358f' &&
   verify_sha1 "$TMP_PATH/files/app-legacy/LegacyNetworkLocation.apk" '8121295640985fad6c5b98890a156aafd18c2053' &&
   verify_sha1 "$TMP_PATH/files/variants/PlayStore-recent.apk" '6c60fa863dd7befef49082c0dcf6278947a09333' &&
   verify_sha1 "$TMP_PATH/files/variants/PlayStore-legacy.apk" 'd78b377db43a2bc0570f37b2dd0efa4ec0b95746' &&
   verify_sha1 "$TMP_PATH/files/variants/FakeStore.apk" '1028f11133ec0a9a41fcd6615837124b61abd251'
then
  ui_msg_sameline_end 'OK'
else
  ui_msg_sameline_end 'ERROR'
  ui_error 'Verification failed'
fi

# Temporary workaround
if [[ $OLD_ANDROID == true ]]; then
  copy_file "$TMP_PATH/files/priv-app-kk/GmsCore.apk" "$TMP_PATH/files/priv-app"  # ToDO: Remove when bug #379 is fixed
fi
delete_recursive "$TMP_PATH/files/priv-app-kk"

# Extracting libs
ui_msg 'Extracting libs...'
create_dir "$TMP_PATH/libs"
zip_extract_dir "$TMP_PATH/files/priv-app/GmsCore.apk" 'lib' "$TMP_PATH/libs"

# Setting up libs permissions
ui_debug 'Setting up libs permissions...'
set_std_perm_recursive "$TMP_PATH/libs"

# MOUNT /data PARTITION
if ! is_mounted '/data'; then
  mount '/data'
  if ! is_mounted '/data'; then ui_error '/data cannot be mounted'; fi
fi

# Resetting Android runtime permissions
if test "$API" -ge 23; then
  if [[ -e '/data/system/users/0/runtime-permissions.xml' ]]; then
    if ! grep -q 'com.google.android.gms' /data/system/users/*/runtime-permissions.xml; then
      # Purge the runtime permissions to prevent issues when the user flash this on a dirty install
      ui_msg "Resetting Android runtime permissions..."
      delete /data/system/users/*/runtime-permissions.xml
    fi
  fi
fi

# Clean some Google Apps, microG and previous installations
. "$TMP_PATH/uninstall.sh"

# Configuring default Android permissions
if test "$API" -ge 23; then
  ui_debug 'Configuring default Android permissions...'
  if [[ ! -e "${SYS_PATH}/etc/default-permissions" ]]; then
    ui_msg 'Creating the default permissions folder...'
    create_dir "${SYS_PATH}/etc/default-permissions"
  fi

  if test $FAKE_SIGN == true; then
    echo '        <permission name="android.permission.FAKE_PACKAGE_SIGNATURE" fixed="true"/>' > "$TMP_PATH/fake-sign-perm.dat"
    replace_line_in_file "$TMP_PATH/files/etc/default-permissions/google-permissions.xml" '<!-- %FAKE_PACKAGE_SIGNATURE% -->' "$TMP_PATH/fake-sign-perm.dat"
  fi
  copy_dir_content "$TMP_PATH/files/etc/default-permissions" "${SYS_PATH}/etc/default-permissions"
else
  delete_recursive "$TMP_PATH/files/etc/default-permissions"
fi

# UNMOUNT /data PARTITION
unmount '/data'

# Preparing
ui_msg 'Preparing...'

if [[ $LEGACY_ANDROID == true ]]; then
  move_dir_content "$TMP_PATH/files/app-legacy" "$TMP_PATH/files/app"
fi
delete_recursive "$TMP_PATH/files/app-legacy"

if test "$API" -lt 21; then delete "$TMP_PATH/files/etc/sysconfig/google.xml"; fi
if test "$API" -lt 18; then delete "$TMP_PATH/files/app/DejaVuBackend.apk"; fi
if [ "$INSTALL_NEWPIPE" -eq 0 ] || [ "$API" -lt 15 ]; then delete "$TMP_PATH/files/app/NewPipe.apk"; fi

move_rename_file "$TMP_PATH/files/variants/${MARKET_FILENAME}" "$TMP_PATH/files/priv-app/Phonesky.apk"
delete_recursive "$TMP_PATH/files/variants"

if [[ $OLD_ANDROID != true ]]; then
  # Move apps into subdirs
  for entry in "$TMP_PATH/files/priv-app"/*; do
    path_without_ext=$(remove_ext "$entry")

    create_dir "$path_without_ext"
    mv -f "$entry" "$path_without_ext"/
  done
  for entry in "$TMP_PATH/files/app"/*; do
    path_without_ext=$(remove_ext "$entry")

    create_dir "$path_without_ext"
    mv -f "$entry" "$path_without_ext"/
  done

  # The name of the following architectures remain unchanged: x86, x86_64, mips, mips64
  move_rename_dir "$TMP_PATH/libs/lib/arm64-v8a" "$TMP_PATH/libs/lib/arm64"
  if [[ $LEGACY_ARM != true ]]; then
    move_rename_dir "$TMP_PATH/libs/lib/armeabi-v7a" "$TMP_PATH/libs/lib/arm"
    delete_recursive "$TMP_PATH/libs/lib/armeabi"
  else
    move_rename_dir "$TMP_PATH/libs/lib/armeabi" "$TMP_PATH/libs/lib/arm"
    delete_recursive "$TMP_PATH/libs/lib/armeabi-v7a"
  fi

  create_dir "$TMP_PATH/files/priv-app/GmsCore/lib"
  move_dir_content "$TMP_PATH/libs/lib" "$TMP_PATH/files/priv-app/GmsCore/lib"
fi

# Installing
ui_msg 'Installing...'
copy_dir_content "$TMP_PATH/files/priv-app" "${PRIVAPP_PATH}"
copy_dir_content "$TMP_PATH/files/app" "${SYS_PATH}/app"
copy_dir_content "$TMP_PATH/files/framework" "${SYS_PATH}/framework"
if test "$API" -lt 26; then
  delete "$TMP_PATH/files/etc/permissions/privapp-permissions-google.xml"
else
  if test $FAKE_SIGN == true; then
    echo '        <permission name="android.permission.FAKE_PACKAGE_SIGNATURE"/>' > "$TMP_PATH/fake-sign-perm.dat"
    replace_line_in_file "$TMP_PATH/files/etc/permissions/privapp-permissions-google.xml" '<!-- %FAKE_PACKAGE_SIGNATURE% -->' "$TMP_PATH/fake-sign-perm.dat"
  fi
fi
copy_dir_content "$TMP_PATH/files/etc/permissions" "${SYS_PATH}/etc/permissions"
if test "$API" -ge 21; then
  copy_dir_content "$TMP_PATH/files/etc/sysconfig" "${SYS_PATH}/etc/sysconfig"
fi
copy_dir_content "$TMP_PATH/files/etc/org.fdroid.fdroid" "${SYS_PATH}/etc/org.fdroid.fdroid"

if [[ $OLD_ANDROID == true ]]; then
  if [[ $CPU != false ]]; then
    copy_dir_content "$TMP_PATH/libs/lib/${CPU}" "${SYS_PATH}/lib"
  fi
  if [[ $CPU64 != false ]]; then
    copy_dir_content "$TMP_PATH/libs/lib/${CPU64}" "${SYS_PATH}/lib64"
  fi

  if test -e "${SYS_PATH}/vendor/lib/libvtm-jni.so"; then
    delete "${SYS_PATH}/vendor/lib/libvtm-jni.so"
  fi
  if test -e "${SYS_PATH}/vendor/lib64/libvtm-jni.so"; then
    delete "${SYS_PATH}/vendor/lib64/libvtm-jni.so"
  fi
fi
delete_recursive "$TMP_PATH/libs"

USED_SETTINGS_PATH="$TMP_PATH/files/etc/zips"

create_dir "${USED_SETTINGS_PATH}"
echo 'type="GmsCore"' > "${USED_SETTINGS_PATH}/${INSTALLATION_SETTINGS_FILE}"
set_perm 0 0 0644 "${USED_SETTINGS_PATH}/${INSTALLATION_SETTINGS_FILE}"
create_dir "${SYS_PATH}/etc/zips"
copy_dir_content "${USED_SETTINGS_PATH}" "${SYS_PATH}/etc/zips"

# Install survival script
if [[ -d "${SYS_PATH}/addon.d" ]]; then
  if [[ $LEGACY_ANDROID == true ]]; then
    :  ### Skip it
  elif [[ $OLD_ANDROID == true ]]; then
    :  ### Not ready yet
  else
    ui_msg 'Installing survival script...'
    write_file_list "$TMP_PATH/files" "$TMP_PATH/files/" "$TMP_PATH/backup-filelist.lst"
    replace_line_in_file "$TMP_PATH/addon.d/00-1-microg.sh" '%PLACEHOLDER-1%' "$TMP_PATH/backup-filelist.lst"
    copy_file "$TMP_PATH/addon.d/00-1-microg.sh" "$SYS_PATH/addon.d"
  fi
fi

unmount '/system'

touch "$TMP_PATH/installed"
ui_msg 'Done.'
