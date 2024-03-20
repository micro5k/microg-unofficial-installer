#!/sbin/sh
# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

### GLOBAL VARIABLES ###

TMP_PATH="${2:?}"

### FUNCTIONS ###

# shellcheck source=SCRIPTDIR/../inc/common-functions.sh
. "${TMP_PATH:?}/inc/common-functions.sh" || exit "${?}"

rollback_complete_callback()
{
  case "${1:?}" in
    'Google Play Store' | 'Google Play Store (legacy)')
      # Fallback to FakeStore
      setup_app 1 '' 'microG Companion (FakeStore)' 'FakeStore' 'priv-app' false false
      ;;

    *) ;;
  esac
}

### CODE ###

USE_MICROG_BY_ALE5000="$(parse_setting 'USE_MICROG_BY_ALE5000' "${USE_MICROG_BY_ALE5000:?}")"
INSTALL_FDROIDPRIVEXT="$(parse_setting 'INSTALL_FDROIDPRIVEXT' "${INSTALL_FDROIDPRIVEXT:?}")"
INSTALL_AURORASERVICES="$(parse_setting 'INSTALL_AURORASERVICES' "${INSTALL_AURORASERVICES:?}")"
INSTALL_NEWPIPE="$(parse_setting 'INSTALL_NEWPIPE' "${INSTALL_NEWPIPE:?}")"

INSTALL_PLAYSTORE="$(parse_setting 'INSTALL_PLAYSTORE' "${INSTALL_PLAYSTORE:-}" 'custom' 'SELECTED_MARKET' 'PlayStore')"
INSTALL_GMAIL_FOR_ANDROID_5_TO_7="$(parse_setting 'INSTALL_GMAIL_FOR_ANDROID_5_TO_7' "${INSTALL_GMAIL_FOR_ANDROID_5_TO_7:-}")"
INSTALL_ANDROIDAUTO="$(parse_setting 'INSTALL_ANDROIDAUTO' "${INSTALL_ANDROIDAUTO:-}")"

if test "${API:?}" -ge 8; then
  : ### Supported Android versions
else
  ui_error "Your Android version is too old, API: ${API:-}"
fi

# Display info
display_info
ui_msg_empty_line

if test "${IS_INSTALLATION:?}" = 'true'; then
  ui_msg 'Starting installation...'
  ui_msg_empty_line

  # Extracting
  ui_msg 'Extracting...'
  custom_package_extract_dir 'origin' "${TMP_PATH:?}"
  custom_package_extract_dir 'files' "${TMP_PATH:?}"
  custom_package_extract_dir 'addon.d' "${TMP_PATH:?}"
  create_dir "${TMP_PATH:?}/files/etc"

  # Verifying
  ui_msg_sameline_start 'Verifying... '
  ui_debug ''
  if verify_sha1 "${TMP_PATH}/files/framework/com.google.android.maps.jar" '14ce63b333e3c53c793e5eabfd7d554f5e7b56c7'; then
    ui_msg_sameline_end 'OK'
  else
    ui_msg_sameline_end 'ERROR'
    ui_error 'Verification failed'
    sleep 1
  fi

  # Configuring
  ui_msg 'Configuring...'

  setup_app 1 '' 'UnifiedNlp (legacy)' 'LegacyNetworkLocation' 'app' false false

  if test "${IS_EMU:?}" = 'true'; then
    move_rename_file "${TMP_PATH:?}/origin/profiles/lenovo_yoga_tab_3_pro_10_inches_23.xml" "${TMP_PATH:?}/files/etc/microg_device_profile.xml"
  fi

  microg_gmscore_vanity_name='microG Services'
  microg_gmscore_filename='GmsCore'
  if test "${USE_MICROG_BY_ALE5000:?}" != 0; then
    microg_gmscore_vanity_name='microG Services - signed by ale5000'
    microg_gmscore_filename='GmsCore-ale5000'
  fi

  install_backends='false'
  if test "${MAIN_ABI:?}" != 'armeabi' && setup_app 1 '' "${microg_gmscore_vanity_name:?}" "${microg_gmscore_filename:?}" 'priv-app' true false; then
    :
  elif test "${MAIN_ABI:?}" = 'armeabi' && setup_app 1 '' 'microG Services (vtm)' 'GmsCoreVtm' 'priv-app' true false; then
    install_backends='true'
  elif setup_app 1 '' 'microG Services (vtm-legacy)' 'GmsCoreVtmLegacy' 'priv-app' true false; then
    install_backends='true'
  fi

  setup_app 1 '' 'microG Services Framework Proxy' 'GsfProxy' 'priv-app' false false

  if test "${install_backends:?}" = 'true'; then
    setup_app "${INSTALL_MOZILLABACKEND:?}" '' 'Mozilla UnifiedNlp Backend' 'IchnaeaNlpBackend' 'app'
    setup_app "${INSTALL_DEJAVUBACKEND:?}" '' 'Déjà Vu Location Service' 'DejaVuBackend' 'app'
    setup_app "${INSTALL_NOMINATIMGEOBACKEND:?}" '' 'Nominatim Geocoder Backend' 'NominatimGeocoderBackend' 'app'
  fi

  # Store selection
  SELECTED_MARKET='FakeStore'
  if setup_app "${INSTALL_PLAYSTORE:-}" '' 'Google Play Store' 'PlayStore' 'priv-app' true; then
    SELECTED_MARKET='PlayStore'
  elif setup_app "${INSTALL_PLAYSTORE:-}" '' 'Google Play Store (legacy)' 'PlayStoreLegacy' 'priv-app' true; then
    SELECTED_MARKET='PlayStore'
  else
    # Fallback to FakeStore
    if test "${USE_MICROG_BY_ALE5000:?}" = 0 && setup_app 1 '' 'microG Companion (FakeStore)' 'FakeStore' 'priv-app' false false; then
      :
    elif setup_app 1 '' 'microG Companion (FakeStore) - signed by ale5000' 'FakeStore-ale5000' 'priv-app' false false; then
      :
    elif setup_app 1 '' 'microG Companion Legacy (FakeStore)' 'FakeStoreLegacy' 'priv-app' false false; then
      :
    fi
  fi

  if test "${SELECTED_MARKET:?}" = 'FakeStore'; then
    move_rename_file "${TMP_PATH:?}/origin/etc/microg.xml" "${TMP_PATH:?}/files/etc/microg.xml"
  else
    move_rename_file "${TMP_PATH:?}/origin/etc/microg-gcm.xml" "${TMP_PATH:?}/files/etc/microg.xml"
  fi

  setup_app "${INSTALL_FDROIDPRIVEXT:?}" 'INSTALL_FDROIDPRIVEXT' 'F-Droid Privileged Extension' 'FDroidPrivilegedExtension' 'priv-app'
  setup_app "${INSTALL_AURORASERVICES:?}" 'INSTALL_AURORASERVICES' 'Aurora Services' 'AuroraServices' 'priv-app'

  setup_app "${INSTALL_NEWPIPE:?}" 'INSTALL_NEWPIPE' 'NewPipe' 'NewPipe' 'app' true ||
    setup_app "${INSTALL_NEWPIPE:?}" 'INSTALL_NEWPIPE' 'NewPipe (old)' 'NewPipeOld' 'app' true ||
    setup_app "${INSTALL_NEWPIPE:?}" 'INSTALL_NEWPIPE' 'NewPipe Legacy' 'NewPipeLegacy' 'app' true

  setup_app "${INSTALL_GMAIL_FOR_ANDROID_5_TO_7:-}" 'INSTALL_GMAIL_FOR_ANDROID_5_TO_7' 'Gmail' 'Gmail' 'app' true
  setup_app "${INSTALL_ANDROIDAUTO:-}" 'INSTALL_ANDROIDAUTO' 'Android Auto stub' 'AndroidAuto' 'priv-app' true

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

if test "${IS_INSTALLATION:?}" = 'true'; then
  disable_app 'com.android.vending'
  disable_app 'com.google.android.gsf'
  kill_app 'com.google.android.gsf.login'
  if test "${FIRST_INSTALLATION:?}" = 'true'; then
    disable_app 'com.google.android.gms'
  fi
fi

# Clean previous installations
clean_previous_installations

if test "${IS_INSTALLATION:?}" != 'true'; then
  clear_app 'com.android.vending'
  clear_app 'com.google.android.gsf'
  clear_app 'com.google.android.gsf.login'
  clear_app 'com.google.android.gms'
  reset_gms_data_of_all_apps

  unmount_extra_partitions
  finalize_and_report_success
fi

unmount_extra_partitions

# Preparing remaining files
if test "${API:?}" -ge 19; then
  move_rename_file "${TMP_PATH:?}/files/bin/minutil.sh" "${TMP_PATH:?}/files/bin/minutil"
else
  delete_recursive "${TMP_PATH:?}/files/bin"
fi

if test "${API}" -lt 23; then
  delete_recursive "${TMP_PATH}/files/etc/default-permissions"
fi

if test "${API:?}" -lt 21; then
  delete_recursive "${TMP_PATH:?}/files/etc/sysconfig"
fi

if test "${API:?}" -lt 9; then
  delete "${TMP_PATH:?}/files/framework/com.google.android.maps.jar"
  delete "${TMP_PATH:?}/files/etc/permissions/com.google.android.maps.xml"
fi

delete_dir_if_empty "${TMP_PATH:?}/files/etc/permissions"
delete_dir_if_empty "${TMP_PATH:?}/files/framework"

ui_debug ''

# Prepare installation
prepare_installation
printf '%s\n' "USE_MICROG_BY_ALE5000=${USE_MICROG_BY_ALE5000:?}" 1>> "${TMP_PATH:?}/files/etc/zips/${MODULE_ID:?}.prop"
printf '%s\n' "SELECTED_MARKET=${SELECTED_MARKET:?}" 1>> "${TMP_PATH:?}/files/etc/zips/${MODULE_ID:?}.prop"

if test -e "${TMP_PATH:?}/files/bin/minutil"; then
  set_perm 0 2000 0755 "${TMP_PATH:?}/files/bin/minutil"
fi

# Install
if test -f "${TMP_PATH:?}/files/etc/microg.xml"; then copy_file "${TMP_PATH:?}/files/etc/microg.xml" "${SYS_PATH:?}/etc"; fi
if test -f "${TMP_PATH:?}/files/etc/microg_device_profile.xml"; then copy_file "${TMP_PATH:?}/files/etc/microg_device_profile.xml" "${SYS_PATH:?}/etc"; fi
perform_installation

reset_authenticator_and_sync_adapter_caches

if test "${FIRST_INSTALLATION:?}" = 'true'; then
  clear_and_enable_app 'com.google.android.gms'
fi
clear_and_enable_app 'com.google.android.gsf'
clear_and_enable_app 'com.android.vending'

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

# Install utilities
if test -e "${TMP_PATH:?}/files/bin"; then
  ui_msg 'Installing utilities...'
  perform_secure_copy_to_device 'bin'
fi

# Install survival script
if test -e "${SYS_PATH:?}/addon.d"; then
  ui_msg 'Installing survival script...'
  write_file_list "${TMP_PATH}/files" "${TMP_PATH}/files/" "${TMP_PATH}/backup-filelist.lst"
  replace_line_in_file_with_file "${TMP_PATH}/addon.d/00-1-microg.sh" '%PLACEHOLDER-1%' "${TMP_PATH}/backup-filelist.lst"
  copy_file "${TMP_PATH}/addon.d/00-1-microg.sh" "${SYS_PATH}/addon.d"
fi

# Reset GMS data of all apps
if test "${RESET_GMS_DATA_OF_ALL_APPS:?}" != '0'; then
  reset_gms_data_of_all_apps
fi

finalize_and_report_success
