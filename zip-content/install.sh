#!/sbin/sh

<<LICENSE
  Copyright (C) 2016-2017  ale5000
  This file is part of microG unofficial installer by @ale5000.

  microG unofficial installer is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version, w/microG unofficial installer zip exception.

  microG unofficial installer is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with microG unofficial installer.  If not, see <http://www.gnu.org/licenses/>.
LICENSE

### GLOBAL VARIABLES ###

export INSTALLER=1
TMP_PATH="$2"

CPU=false
CPU64=false
LEGACY_ARM=false
LEGACY_ANDROID=false
OLD_ANDROID=false
SYS_ROOT_IMAGE=''
SYS_PATH='/system'
MARKET_FILENAME=''


### FUNCTIONS ###

. "$TMP_PATH/inc/common.sh"


### CODE ###

if ! is_mounted '/system'; then
  mount '/system'
  if ! is_mounted '/system'; then ui_error 'ERROR: /system cannot be mounted'; fi
fi

SYS_ROOT_IMAGE=$(getprop 'build.system_root_image')
if [[ -z "$SYS_ROOT_IMAGE" ]]; then
  SYS_ROOT_IMAGE=false;
elif [[ $SYS_ROOT_IMAGE == true && -e '/system/system' ]]; then
  SYS_PATH='/system/system';
fi

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
  ui_error 'ERROR: Your Android version is too old'
else
  ui_error 'ERROR: Invalid API level'
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
ui_msg 'v1.0.27-beta'
ui_msg '(by ale5000)'
ui_msg '---------------------------'
ui_msg ''
ui_msg "API: ${API}"
ui_msg "Detected CPU arch: ${CPU}"
ui_msg "Detected 64-bit CPU arch: ${CPU64}"
ui_msg "System root image: ${SYS_ROOT_IMAGE}"
ui_msg "System path: ${SYS_PATH}"
ui_msg "Privileged apps: ${PRIVAPP_PATH}"
ui_msg ''

if [[ $CPU == false && $CPU64 == false ]]; then
  ui_error 'ERROR: Unsupported CPU'
fi

# Check the existance of the vendor libraries folders
if [[ $OLD_ANDROID == true ]]; then
  if [[ ! -d "${SYS_PATH}/vendor" ]]; then
    ui_error 'ERROR: Missing vendor folder'
  fi

  if [[ $CPU != false && ! -d "${SYS_PATH}/vendor/lib" ]]; then create_dir "${SYS_PATH}/vendor/lib"; fi
  if [[ $CPU64 != false && ! -d "${SYS_PATH}/vendor/lib64" ]]; then create_dir "${SYS_PATH}/vendor/lib64"; fi
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

# Verifying
ui_msg_sameline_start 'Verifying... '
if verify_sha1 "$TMP_PATH/files/priv-app/GmsCore.apk" 'c65b108846a40c6493d94117ba130f1401a73fa2' &&
   verify_sha1 "$TMP_PATH/files/priv-app-kk/GmsCore.apk" '52890ef5d04abd563fa220725708fd2bc48e894e' &&  # ToDO: Remove when bug #379 is fixed
   verify_sha1 "$TMP_PATH/files/priv-app/GoogleServicesFramework.apk" 'f9907df2e2c8fd20cd2e928821641fa01fca09ce' &&
   verify_sha1 "$TMP_PATH/files/priv-app/DroidGuard.apk" 'fa6267bee3f73d248d1110be53d66736aa4fece0' &&
   verify_sha1 "$TMP_PATH/files/app/NewPipe.apk" '182aa4c505615592bc872430d0cbdbadac41ba3a' &&
   verify_sha1 "$TMP_PATH/files/app/DejaVuBackend.apk" 'a9691a8e0b1ff98c2f39a364f9da0e19cea5dc75' &&
   verify_sha1 "$TMP_PATH/files/app/IchnaeaNlpBackend.apk" '9be5de681ebb1184fc5e00933f1fd18c080f7ee8' &&
   verify_sha1 "$TMP_PATH/files/app/NominatimGeocoderBackend.apk" '40b0917e9805cdab5abc53925f8732bff9ba8d84' &&
   ###verify_sha1 "$TMP_PATH/files/app/PlayGames.apk" 'c99c27053bf518dd3d08449e9478b43de0da50ed' &&
   verify_sha1 "$TMP_PATH/files/priv-app/FDroidPrivilegedExtension.apk" '08588e36b1e605401047766c8708c33622f1c4b9' &&
   verify_sha1 "$TMP_PATH/files/framework/com.google.android.maps.jar" '14ce63b333e3c53c793e5eabfd7d554f5e7b56c7' &&
   verify_sha1 "$TMP_PATH/files/etc/permissions/com.google.android.maps.xml" '05b2b8685380f86df0776a844b16f12137f06583' &&
   verify_sha1 "$TMP_PATH/files/etc/permissions/features.xml" '1eb8c90eeed31d6124710662e815aedc1b213c25' &&
   verify_sha1 "$TMP_PATH/files/app-legacy/LegacyNetworkLocation.apk" '8121295640985fad6c5b98890a156aafd18c2053' &&
   verify_sha1 "$TMP_PATH/files/variants/PlayStore-recent.apk" '6c60fa863dd7befef49082c0dcf6278947a09333' &&
   verify_sha1 "$TMP_PATH/files/variants/PlayStore-legacy.apk" 'd78b377db43a2bc0570f37b2dd0efa4ec0b95746' &&
   verify_sha1 "$TMP_PATH/files/variants/FakeStore.apk" '1028f11133ec0a9a41fcd6615837124b61abd251'
then
  ui_msg_sameline_end 'OK'
else
  ui_msg_sameline_end 'ERROR'
  ui_error 'ERROR: Verification failed'
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
  if ! is_mounted '/data'; then ui_error 'ERROR: /data cannot be mounted'; fi
fi

# Resetting Android runtime permissions
if [[ -e '/data/system/users/0/runtime-permissions.xml' ]]; then
  if [[ ! -e "${SYS_PATH}/etc/default-permissions/microg-permissions.xml" ]] || ! grep -q 'com.google.android.gms' /data/system/users/*/runtime-permissions.xml; then
    # Purge the runtime permissions to prevent issues when the user flash this on a dirty install
    ui_msg "Resetting Android runtime permissions..."
    delete /data/system/users/*/runtime-permissions.xml
  fi
fi

# Clean some Google Apps, microG and previous installations
. "$TMP_PATH/uninstall.sh"

# Configuring default Android permissions
ui_debug 'Configuring default Android permissions...'
if [[ ! -e "${SYS_PATH}/etc/default-permissions" ]]; then
  ui_msg 'Creating the default permissions folder...'
  create_dir "${SYS_PATH}/etc/default-permissions"
fi
copy_dir_content "$TMP_PATH/files/etc/default-permissions" "${SYS_PATH}/etc/default-permissions"

# UNMOUNT /data PARTITION
unmount '/data'

# Preparing
ui_msg 'Preparing...'

if [[ $LEGACY_ANDROID == true ]]; then
  move_dir_content "$TMP_PATH/files/app-legacy" "$TMP_PATH/files/app"
fi
delete_recursive "$TMP_PATH/files/app-legacy"

if test "$API" -lt 23; then delete "$TMP_PATH/files/etc/sysconfig/microg-a5k.xml"; fi
if test "$API" -lt 18; then delete "$TMP_PATH/files/app/DejaVuBackend.apk"; fi
if test "$API" -lt 15; then delete "$TMP_PATH/files/app/NewPipe.apk"; fi

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
copy_dir_content "$TMP_PATH/files/etc/permissions" "${SYS_PATH}/etc/permissions"
if test "$API" -ge 23; then
  copy_dir_content "$TMP_PATH/files/etc/sysconfig" "${SYS_PATH}/etc/sysconfig"
fi

if [[ $OLD_ANDROID == true ]]; then
  if [[ $CPU != false ]]; then
    copy_dir_content "$TMP_PATH/libs/lib/${CPU}" "${SYS_PATH}/vendor/lib"
  fi
  if [[ $CPU64 != false ]]; then
    copy_dir_content "$TMP_PATH/libs/lib/${CPU64}" "${SYS_PATH}/vendor/lib64"
  fi
fi
delete_recursive "$TMP_PATH/libs"

# Install survival script
if [[ -d "${SYS_PATH}/addon.d" ]]; then
  if [[ $LEGACY_ANDROID == true ]]; then
    :  ### Skip it
  elif [[ $OLD_ANDROID == true ]]; then
    :  ### Not ready yet
  else
    ui_msg 'Installing survival script...'
    FILE_LIST=$(list_files "$TMP_PATH/files" "$TMP_PATH/files/")
    custom_replace_string_in_file "$FILE_LIST" "$TMP_PATH/addon.d/00-1-microg.sh"
    copy_file "$TMP_PATH/addon.d/00-1-microg.sh" "$SYS_PATH/addon.d"
  fi
fi

echo 'type="GmsCore"' > "${SYS_PATH}/etc/ug.prop"
touch "${SYS_PATH}/etc/ug.prop"

unmount '/system'

touch "$TMP_PATH/installed"
ui_msg 'Done.'
