#!/sbin/sh

### GLOBAL VARIABLES ###

RECOVERY_API_VER="$2"
RECOVERY_PIPE="$3"
ZIP_FILE="$4"
TMP_PATH="$5"
#DEBUG_LOG="$6"

INSTALLER=1
CPU=false
CPU64=false
LEGACY_ARM=false
LEGACY_ANDROID=false
OLD_ANDROID=false
SYS_ROOT_IMAGE=''
SYS_PATH='/system'
ZIP_PATH=false

mkdir "${TMP_PATH}/bin"
/tmp/busybox --install -s "${TMP_PATH}/bin"
# Clean search path so BusyBox will use only internal applets
PATH="${TMP_PATH}/bin"


### FUNCTIONS ###

. "${TMP_PATH}/inc/common.sh"


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

cp -pf "${SYS_PATH}/build.prop" "${TMP_PATH}/build.prop"  # Cache the file for faster access

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

ZIP_PATH=$(dirname "$ZIP_FILE")

# Info
ui_msg '---------------------------'
ui_msg 'microG unofficial installer'
ui_msg 'v1.0.20-alpha'
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

ui_msg 'Extracting files...'
custom_package_extract_dir 'files' "${TMP_PATH}"

ui_debug 'Setting permissions...'
set_std_perm_recursive "${TMP_PATH}/files"

ui_msg_sameline_start 'Verifying files...'
if verify_sha1 "${TMP_PATH}/files/priv-app/GmsCore.apk" 'f8c69c7a7f036cb2115563a39b8e6f85fe25eb2c' &&
   verify_sha1 "${TMP_PATH}/files/priv-app-kk/GmsCore.apk" '52890ef5d04abd563fa220725708fd2bc48e894e' &&  # ToDO: Remove when bug #379 is fixed
   verify_sha1 "${TMP_PATH}/files/priv-app/GoogleServicesFramework.apk" 'f9907df2e2c8fd20cd2e928821641fa01fca09ce' &&
   verify_sha1 "${TMP_PATH}/files/priv-app/DroidGuard.apk" 'fa6267bee3f73d248d1110be53d66736aa4fece0' &&
   verify_sha1 "${TMP_PATH}/files/priv-app/Phonesky.apk" 'd78b377db43a2bc0570f37b2dd0efa4ec0b95746' &&
   verify_sha1 "${TMP_PATH}/files/app/IchnaeaNlpBackend.apk" '19b286a12a4902b7627c04cb54bdda63af494696' &&
   verify_sha1 "${TMP_PATH}/files/app/NominatimGeocoderBackend.apk" '40b0917e9805cdab5abc53925f8732bff9ba8d84' &&
   ###verify_sha1 "${TMP_PATH}/files/app/PlayGames.apk" 'c99c27053bf518dd3d08449e9478b43de0da50ed' &&
   verify_sha1 "${TMP_PATH}/files/priv-app/FDroidPrivilegedExtension.apk" '075a81cd2b1449bb8e3db883c64778e44f3ce342' &&
   verify_sha1 "${TMP_PATH}/files/framework/com.google.android.maps.jar" '14ce63b333e3c53c793e5eabfd7d554f5e7b56c7' &&
   verify_sha1 "${TMP_PATH}/files/etc/permissions/com.google.android.maps.xml" '05b2b8685380f86df0776a844b16f12137f06583' &&
   verify_sha1 "${TMP_PATH}/files/etc/permissions/features.xml" '1eb8c90eeed31d6124710662e815aedc1b213c25' &&
   verify_sha1 "${TMP_PATH}/files/app-legacy/LegacyNetworkLocation.apk" '8121295640985fad6c5b98890a156aafd18c2053'
then
  ui_msg_sameline_end 'OK'
else
  ui_msg_sameline_end 'ERROR'
  ui_error 'ERROR: Verification failed'
fi

# Clean some Google Apps and previous installations
. "${TMP_PATH}/uninstall.sh"

# Setup default Android permissions
ui_debug 'Setup default Android permissions...'
if [[ ! -e "${SYS_PATH}/etc/default-permissions" ]]; then
  ui_msg 'Creating the default permissions folder...'
  create_dir "${SYS_PATH}/etc/default-permissions"
fi
copy_dir_content "${TMP_PATH}/files/etc/default-permissions" "${SYS_PATH}/etc/default-permissions"

# Resetting Android runtime permissions
if ! is_mounted '/data'; then
  mount '/data'
  if ! is_mounted '/data'; then ui_error 'ERROR: /data cannot be mounted'; fi
fi
if [[ -e '/data/system/users/0/runtime-permissions.xml' ]]; then
  if ! grep -q 'com.google.android.gms' /data/system/users/*/runtime-permissions.xml; then
    # Purge the runtime permissions to prevent issues when the user flash this for the first time on a dirty install
    ui_debug "Resetting Android runtime permissions..."
    delete /data/system/users/*/runtime-permissions.xml
  fi
fi
umount '/data'

# Installing
ui_msg 'Installing...'
if [[ $OLD_ANDROID != true ]]; then
  # Move apps into subdirs
  for entry in "${TMP_PATH}/files/priv-app"/*; do
    path_without_ext=$(remove_ext "$entry")

    create_dir "$path_without_ext"
    mv -f "$entry" "$path_without_ext"/
  done
  for entry in "${TMP_PATH}/files/app"/*; do
    path_without_ext=$(remove_ext "$entry")

    create_dir "$path_without_ext"
    mv -f "$entry" "$path_without_ext"/
  done
else
  cp -rpf "${TMP_PATH}/files/priv-app-kk/GmsCore.apk" "${TMP_PATH}/files/priv-app/GmsCore.apk"  # ToDO: Remove when bug #379 is fixed
fi

copy_dir_content "${TMP_PATH}/files/priv-app" "${PRIVAPP_PATH}"
copy_dir_content "${TMP_PATH}/files/app" "${SYS_PATH}/app"
copy_dir_content "${TMP_PATH}/files/framework" "${SYS_PATH}/framework"
copy_dir_content "${TMP_PATH}/files/etc/permissions" "${SYS_PATH}/etc/permissions"

if [[ $LEGACY_ANDROID == true ]]; then
  copy_dir_content "${TMP_PATH}/files/app-legacy" "${SYS_PATH}/app"
fi

ui_debug 'Extracting libs...'
create_dir "${TMP_PATH}/libs"
if [[ $OLD_ANDROID != true ]]; then
  zip_extract_dir "${TMP_PATH}/files/priv-app/GmsCore/GmsCore.apk" 'lib' "${TMP_PATH}/libs"
else
  zip_extract_dir "${TMP_PATH}/files/priv-app/GmsCore.apk" 'lib' "${TMP_PATH}/libs"
fi

ui_debug 'Setting permissions...'
set_std_perm_recursive "${TMP_PATH}/libs"

# Installing libs
ui_msg 'Installing libs...'
if [[ $OLD_ANDROID != true ]]; then
  # The name of the following architectures remain unchanged: x86, x86_64, mips, mips64
  mv -f "${TMP_PATH}/libs/lib/arm64-v8a/" "${TMP_PATH}/libs/lib/arm64"
  if [[ $LEGACY_ARM != true ]]; then
    mv -f "${TMP_PATH}/libs/lib/armeabi-v7a/" "${TMP_PATH}/libs/lib/arm"
    rm -rf "${TMP_PATH}/libs/lib/armeabi"
  else
    mv -f "${TMP_PATH}/libs/lib/armeabi/" "${TMP_PATH}/libs/lib/arm"
    rm -rf "${TMP_PATH}/libs/lib/armeabi-v7a"
  fi

  create_dir "${PRIVAPP_PATH}/GmsCore/lib"
  copy_dir_content "${TMP_PATH}/libs/lib" "${PRIVAPP_PATH}/GmsCore/lib"
else
  if [[ $CPU != false ]]; then
    copy_dir_content "${TMP_PATH}/libs/lib/${CPU}" "${SYS_PATH}/vendor/lib"
  fi
  if [[ $CPU64 != false ]]; then
    copy_dir_content "${TMP_PATH}/libs/lib/${CPU64}" "${SYS_PATH}/vendor/lib64"
  fi
fi

# Install survival script
if [[ -d "${SYS_PATH}/addon.d" ]]; then
  if [[ $LEGACY_ANDROID == true ]]; then
    :  ### Skip it
  elif [[ $OLD_ANDROID == true ]]; then
    :  ### Not ready yet #cp -rpf "${TMP_PATH}/files/addon.d/00-1-microg-k.sh" "${SYS_PATH}/addon.d/00-1-microg.sh"
  else
    ui_msg 'Installing survival script...'
    cp -rpf "${TMP_PATH}/files/addon.d/00-1-microg.sh" "${SYS_PATH}/addon.d/00-1-microg.sh"
  fi
fi

umount '/system'

touch "${TMP_PATH}/installed"
ui_msg 'Done.'
