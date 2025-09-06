#!/sbin/sh
# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

### GLOBAL VARIABLES ###

TMP_PATH="${2:?}"

### FUNCTIONS ###

# shellcheck source=SCRIPTDIR/../inc/common-functions.sh
command . "${TMP_PATH:?}/inc/common-functions.sh" || exit "${?}"

setup_fakestore()
{
  if test "${USE_MICROG_BY_ALE5000:?}" = 0 && setup_app 1 '' 'microG Companion' 'FakeStore' 'priv-app' true false; then
    :
  elif setup_app 1 '' 'microG Companion - signed by ale5000' 'FakeStoreA5K' 'priv-app' true false; then
    :
  elif setup_app 1 '' 'microG Companion Legacy' 'FakeStoreLegacy' 'priv-app' true false; then
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

USE_MICROG_BY_ALE5000="$(parse_setting 'general' 'USE_MICROG_BY_ALE5000' "${USE_MICROG_BY_ALE5000:?}")"

APP_DEJAVUBACKEND="$(parse_setting 'app' 'DEJAVUBACKEND' "${APP_DEJAVUBACKEND:?}")"
APP_NOMINATIMBACKEND="$(parse_setting 'app' 'NOMINATIMBACKEND' "${APP_NOMINATIMBACKEND:?}")"

APP_FDROIDPRIVEXT="$(parse_setting 'app' 'FDROIDPRIVEXT' "${APP_FDROIDPRIVEXT:?}")"
APP_AURORASERVICES="$(parse_setting 'app' 'AURORASERVICES' "${APP_AURORASERVICES:?}")"
APP_NEWPIPE="$(parse_setting 'app' 'NEWPIPE' "${APP_NEWPIPE:?}")"
APP_MYLOCATION="$(parse_setting 'app' 'MYLOCATION' "${APP_MYLOCATION:?}")"

APP_PLAYSTORE="$(parse_setting 'app' 'PLAYSTORE' "${APP_PLAYSTORE-}" 'custom' 'SELECTED_MARKET' 'PlayStore')"
APP_GMAIL_FOR_ANDROID_5_TO_7="$(parse_setting 'app' 'GMAIL_FOR_ANDROID_5_TO_7' "${APP_GMAIL_FOR_ANDROID_5_TO_7-}")"
APP_ANDROIDAUTO="$(parse_setting 'app' 'ANDROIDAUTO' "${APP_ANDROIDAUTO-}")"

if test "${SETUP_TYPE:?}" = 'install'; then
  ui_msg 'Extracting...'
  custom_package_extract_dir 'origin' "${TMP_PATH:?}"
  custom_package_extract_dir 'files' "${TMP_PATH:?}"
  create_dir "${TMP_PATH:?}/files/etc"

  ui_msg 'Configuring...'
  ui_msg_empty_line

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
    USE_MICROG_BY_ALE5000=1
  elif setup_app 1 '' 'microG Services (vtm)' 'GmsCoreVtm' 'priv-app' false false; then
    install_backends='true'
  elif setup_app 1 '' 'microG Services (vtm-legacy)' 'GmsCoreVtmLegacy' 'priv-app' false false; then
    install_backends='true'
  fi

  setup_app 1 '' 'microG Services Framework Proxy' 'GsfProxyA5K' 'priv-app' false false

  if setup_app 1 '' 'UnifiedNlp (legacy)' 'LegacyNetworkLocation' 'app' false false; then
    install_backends='true'
  fi

  if test "${install_backends:?}" = 'true'; then
    setup_app "${APP_DEJAVUBACKEND:?}" 'APP_DEJAVUBACKEND' 'Déjà Vu Location Service' 'DejaVuBackend' 'app'
    setup_app "${APP_NOMINATIMBACKEND:?}" 'APP_NOMINATIMBACKEND' 'Nominatim Geocoder Backend' 'NominatimGeocoderBackend' 'app'
  fi

  # Store selection
  SELECTED_MARKET='FakeStore'
  if test "${MAIN_ABI:?}" = 'arm64-v8a' && setup_app "${APP_PLAYSTORE?}" '' 'Google Play Store' 'PlayStoreARM64' 'priv-app' true; then
    SELECTED_MARKET='PlayStore'
  elif test "${MAIN_ABI:?}" != 'arm64-v8a' && test "${MAIN_ABI:?}" != 'armeabi' && setup_app "${APP_PLAYSTORE?}" '' 'Google Play Store' 'PlayStore' 'priv-app' true; then
    SELECTED_MARKET='PlayStore'
  elif setup_app "${APP_PLAYSTORE?}" '' 'Google Play Store (legacy)' 'PlayStoreLegacy' 'priv-app' true; then
    SELECTED_MARKET='PlayStore'
  else
    # Fallback to FakeStore
    setup_fakestore
  fi

  if test "${SELECTED_MARKET:?}" = 'FakeStore'; then
    move_rename_file "${TMP_PATH:?}/origin/etc/microg-base.xml" "${TMP_PATH:?}/files/etc/microg.xml"
  else
    move_rename_file "${TMP_PATH:?}/origin/etc/microg-PlayStore.xml" "${TMP_PATH:?}/files/etc/microg.xml"
  fi

  setup_app "${APP_FDROIDPRIVEXT:?}" 'APP_FDROIDPRIVEXT' 'F-Droid Privileged Extension' 'FDroidPrivilegedExtension' 'priv-app'
  setup_app "${APP_AURORASERVICES:?}" 'APP_AURORASERVICES' 'Aurora Services' 'AuroraServices' 'priv-app'

  setup_app "${APP_NEWPIPE:?}" 'APP_NEWPIPE' 'NewPipe' 'NewPipe' 'app' true ||
    setup_app "${APP_NEWPIPE:?}" 'APP_NEWPIPE' 'NewPipe Legacy Revo' 'NewPipeLegacyRevo' 'app' true

  setup_app "${APP_MYLOCATION:?}" 'APP_MYLOCATION' 'My Location' 'MyLocation' 'app'

  setup_app "${APP_GMAIL_FOR_ANDROID_5_TO_7?}" 'APP_GMAIL_FOR_ANDROID_5_TO_7' 'Gmail' 'Gmail' 'app' true
  setup_app "${APP_ANDROIDAUTO?}" 'APP_ANDROIDAUTO' 'Android Auto stub' 'AndroidAuto' 'priv-app' true

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
fi

if test "${SETUP_TYPE:?}" = 'install'; then
  test "${FIRST_INSTALLATION:?}" != 'true' || kill_app 'com.android.vending'
  kill_app 'com.google.android.gsf.login'
  disable_app 'com.android.vending'
  disable_app 'com.google.android.gsf'
  test "${FIRST_INSTALLATION:?}" != 'true' || disable_app 'com.google.android.gms'
fi

# Clean previous installations
clean_previous_installations

if test "${SETUP_TYPE:?}" = 'uninstall'; then
  clear_app 'com.android.vending'
  clear_app 'com.google.android.gsf.login'
  clear_app 'com.google.android.gsf'
  clear_app 'com.google.android.gms'
  reset_gms_data_of_all_apps

  finalize_correctly
  exit 0
fi

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

# Resetting Android runtime permissions
reset_runtime_permissions_if_needed

# Resetting App Ops
reset_appops_if_needed

# Install survival script
install_survival_script '00-1-microg'

#if test "${DRY_RUN:?}" -eq 0; then
#  if test "${BOOTMODE:?}" = 'true' && test -n "${DEVICE_AM?}"; then
#    PATH="${PREVIOUS_PATH?}" "${DEVICE_AM:?}" 2> /dev/null broadcast -a 'org.microg.gms.gcm.FORCE_TRY_RECONNECT' -n 'com.google.android.gms/org.microg.gms.gcm.TriggerReceiver' || :
#  fi
#fi

# Reset GMS data of all apps
if test "${RESET_GMS_DATA_OF_ALL_APPS:?}" != '0'; then
  reset_gms_data_of_all_apps
fi

finalize_correctly
