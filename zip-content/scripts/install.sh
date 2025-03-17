#!/sbin/sh
# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

### GLOBAL VARIABLES ###

TMP_PATH="${2:?}"

### FUNCTIONS ###

# shellcheck source=SCRIPTDIR/../inc/common-functions.sh
. "${TMP_PATH:?}/inc/common-functions.sh" || exit "${?}"

setup_fakestore()
{
  if test "${USE_MICROG_BY_ALE5000:?}" = 0 && setup_app 1 '' 'microG Companion (FakeStore)' 'FakeStore' 'priv-app' true false; then
    :
  elif setup_app 1 '' 'microG Companion (FakeStore) - signed by ale5000' 'FakeStoreA5K' 'priv-app' true false; then
    :
  elif setup_app 1 '' 'microG Companion Legacy (FakeStore)' 'FakeStoreLegacy' 'priv-app' true false; then
    :
  fi
}

rollback_complete_callback()
{
  case "${1:?}" in
    'Google Play Store' | 'Google Play Store (legacy)')
      # Fallback to FakeStore
      setup_fakestore
      ;;

    *) ;;
  esac
}

### CODE ###

if test "${API:?}" -ge 8; then
  : # Supported Android version
else
  ui_error "Your Android version is too old, API: ${API?}"
fi

USE_MICROG_BY_ALE5000="$(parse_setting 'USE_MICROG_BY_ALE5000' "${USE_MICROG_BY_ALE5000:?}")"
INSTALL_FDROIDPRIVEXT="$(parse_setting 'INSTALL_FDROIDPRIVEXT' "${INSTALL_FDROIDPRIVEXT:?}")"
INSTALL_AURORASERVICES="$(parse_setting 'INSTALL_AURORASERVICES' "${INSTALL_AURORASERVICES:?}")"
INSTALL_NEWPIPE="$(parse_setting 'INSTALL_NEWPIPE' "${INSTALL_NEWPIPE:?}")"
INSTALL_MYLOCATION="$(parse_setting 'INSTALL_MYLOCATION' "${INSTALL_MYLOCATION:?}")"

INSTALL_PLAYSTORE="$(parse_setting 'INSTALL_PLAYSTORE' "${INSTALL_PLAYSTORE-}" 'custom' 'SELECTED_MARKET' 'PlayStore')"
INSTALL_GMAIL_FOR_ANDROID_5_TO_7="$(parse_setting 'INSTALL_GMAIL_FOR_ANDROID_5_TO_7' "${INSTALL_GMAIL_FOR_ANDROID_5_TO_7-}")"
INSTALL_ANDROIDAUTO="$(parse_setting 'INSTALL_ANDROIDAUTO' "${INSTALL_ANDROIDAUTO-}")"

# Display info
display_info
ui_msg_empty_line

if test "${SETUP_TYPE:?}" = 'install'; then
  ui_msg 'Starting installation...'
  ui_msg_empty_line

  # Extracting
  ui_msg 'Extracting...'
  custom_package_extract_dir 'origin' "${TMP_PATH:?}"
  custom_package_extract_dir 'files' "${TMP_PATH:?}"
  custom_package_extract_dir 'addon.d' "${TMP_PATH:?}"
  create_dir "${TMP_PATH:?}/files/etc"

  # Configuring
  ui_msg 'Configuring...'

  set_filename_of_base_sysconfig_xml 'google.xml'

  setup_lib 1 '' 'microG Maps v1 API' 'com.google.android.maps' false

  profile_filename="$(printf '%s\n' "${BUILD_MANUFACTURER?}-${BUILD_MODEL?}.xml" | tr -- '[:upper:]' '[:lower:]')"
  if test -e "${TMP_PATH:?}/origin/profiles/${profile_filename:?}"; then
    move_rename_file "${TMP_PATH:?}/origin/profiles/${profile_filename:?}" "${TMP_PATH:?}/files/etc/microg_device_profile.xml"
  elif test "${IS_EMU:?}" = 'true'; then
    move_rename_file "${TMP_PATH:?}/origin/profiles/lenovo_yoga_tab_3_pro_10_inches_23.xml" "${TMP_PATH:?}/files/etc/microg_device_profile.xml"
  fi

  install_backends='false'
  if test "${USE_MICROG_BY_ALE5000:?}" = 0 && test "${MAIN_ABI:?}" != 'armeabi' && setup_app 1 '' 'microG Services' 'GmsCore' 'priv-app' true false; then
    :
  elif test "${MAIN_ABI:?}" != 'armeabi' && setup_app 1 '' 'microG Services - signed by ale5000' 'GmsCoreA5K' 'priv-app' true false; then
    :
  elif setup_app 1 '' 'microG Services (vtm)' 'GmsCoreVtm' 'priv-app' false false; then
    install_backends='true'
  elif setup_app 1 '' 'microG Services (vtm-legacy)' 'GmsCoreVtmLegacy' 'priv-app' false false; then
    install_backends='true'
  fi

  setup_app 1 '' 'microG Services Framework Proxy' 'GsfProxyA5K' 'priv-app' false false

  if test "${install_backends:?}" = 'true'; then
    setup_app "${INSTALL_DEJAVUBACKEND:?}" '' 'Déjà Vu Location Service' 'DejaVuBackend' 'app'
    setup_app "${INSTALL_NOMINATIMGEOBACKEND:?}" '' 'Nominatim Geocoder Backend' 'NominatimGeocoderBackend' 'app'
  fi

  # Store selection
  SELECTED_MARKET='FakeStore'
  if setup_app "${INSTALL_PLAYSTORE?}" '' 'Google Play Store' 'PlayStore' 'priv-app' true; then
    SELECTED_MARKET='PlayStore'
  elif setup_app "${INSTALL_PLAYSTORE?}" '' 'Google Play Store (legacy)' 'PlayStoreLegacy' 'priv-app' true; then
    SELECTED_MARKET='PlayStore'
  else
    # Fallback to FakeStore
    setup_fakestore
  fi

  if test "${SELECTED_MARKET:?}" = 'FakeStore'; then
    move_rename_file "${TMP_PATH:?}/origin/etc/microg.xml" "${TMP_PATH:?}/files/etc/microg.xml"
  else
    move_rename_file "${TMP_PATH:?}/origin/etc/microg-gcm.xml" "${TMP_PATH:?}/files/etc/microg.xml"
  fi

  setup_app 1 '' 'UnifiedNlp (legacy)' 'LegacyNetworkLocation' 'app' false false

  setup_app "${INSTALL_FDROIDPRIVEXT:?}" 'INSTALL_FDROIDPRIVEXT' 'F-Droid Privileged Extension' 'FDroidPrivilegedExtension' 'priv-app'
  setup_app "${INSTALL_AURORASERVICES:?}" 'INSTALL_AURORASERVICES' 'Aurora Services' 'AuroraServices' 'priv-app'

  setup_app "${INSTALL_NEWPIPE:?}" 'INSTALL_NEWPIPE' 'NewPipe' 'NewPipe' 'app' true ||
    setup_app "${INSTALL_NEWPIPE:?}" 'INSTALL_NEWPIPE' 'NewPipe Legacy Revo' 'NewPipeLegacyRevo' 'app' true

  setup_app "${INSTALL_MYLOCATION:?}" 'INSTALL_MYLOCATION' 'My Location' 'MyLocation' 'app'

  setup_app "${INSTALL_GMAIL_FOR_ANDROID_5_TO_7?}" 'INSTALL_GMAIL_FOR_ANDROID_5_TO_7' 'Gmail' 'Gmail' 'app' true
  setup_app "${INSTALL_ANDROIDAUTO?}" 'INSTALL_ANDROIDAUTO' 'Android Auto stub' 'AndroidAuto' 'priv-app' true

  if test "${API:?}" -ge 19; then
    setup_util 'minutil' 'MinUtil'
  fi

  if test "${LIVE_SETUP_ENABLED:?}" = 'true'; then
    choose 'Do you want to reset GMS data of all apps?' '+) Yes' '-) No'
    if test "$?" -eq 3; then
      RESET_GMS_DATA_OF_ALL_APPS='1'
    else
      RESET_GMS_DATA_OF_ALL_APPS='0'
    fi
  fi
else
  ui_msg 'Starting uninstallation...'
  ui_msg_empty_line
fi

if test "${SETUP_TYPE:?}" = 'install'; then
  disable_app 'com.android.vending'
  disable_app 'com.google.android.gsf'
  kill_app 'com.google.android.gsf.login'
  if test "${FIRST_INSTALLATION:?}" = 'true'; then
    disable_app 'com.google.android.gms'
  fi
fi

# Clean previous installations
clean_previous_installations

if test "${SETUP_TYPE:?}" = 'uninstall'; then
  clear_app 'com.android.vending'
  clear_app 'com.google.android.gsf'
  clear_app 'com.google.android.gsf.login'
  clear_app 'com.google.android.gms'
  reset_gms_data_of_all_apps

  finalize_correctly
  exit 0
fi

# Preparing remaining files
if test "${API}" -lt 23; then
  delete_recursive "${TMP_PATH}/files/etc/default-permissions"
fi
if test "${API:?}" -lt 21; then
  delete_recursive "${TMP_PATH:?}/files/etc/sysconfig"
fi
ui_debug ''

# Prepare installation
prepare_installation
printf '%s\n' "USE_MICROG_BY_ALE5000=${USE_MICROG_BY_ALE5000:?}" 1>> "${TMP_PATH:?}/files/etc/zips/${MODULE_ID:?}.prop"
printf '%s\n' "SELECTED_MARKET=${SELECTED_MARKET:?}" 1>> "${TMP_PATH:?}/files/etc/zips/${MODULE_ID:?}.prop"

# Install
perform_installation
reset_authenticator_and_sync_adapter_caches

if test "${FIRST_INSTALLATION:?}" = 'true'; then
  clear_and_enable_app 'com.google.android.gms'
fi
clear_and_enable_app 'com.google.android.gsf'
clear_and_enable_app 'com.android.vending'

if test "${DRY_RUN:?}" -eq 0; then
  # Resetting Android runtime permissions
  if test "${API:?}" -ge 23; then
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

  #if test "${BOOTMODE:?}" = 'true' && test -n "${DEVICE_AM?}"; then
  #  PATH="${PREVIOUS_PATH?}" "${DEVICE_AM:?}" 2> /dev/null broadcast -a 'org.microg.gms.gcm.FORCE_TRY_RECONNECT' -n 'com.google.android.gms/org.microg.gms.gcm.TriggerReceiver' || true
  #fi

  # Install survival script
  if test -e "${SYS_PATH:?}/addon.d"; then
    ui_msg 'Installing survival script...'
    write_file_list "${TMP_PATH}/files" "${TMP_PATH}/files/" "${TMP_PATH}/backup-filelist.lst"
    replace_line_in_file_with_file "${TMP_PATH}/addon.d/00-1-microg.sh" '%PLACEHOLDER-1%' "${TMP_PATH}/backup-filelist.lst"
    copy_file "${TMP_PATH}/addon.d/00-1-microg.sh" "${SYS_PATH}/addon.d"
  fi
fi

# Reset GMS data of all apps
if test "${RESET_GMS_DATA_OF_ALL_APPS:?}" != '0'; then
  reset_gms_data_of_all_apps
fi

finalize_correctly
