#!/sbin/sh
# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

### GLOBAL VARIABLES ###

TMP_PATH="${2:?}"

### FUNCTIONS ###

# shellcheck source=SCRIPTDIR/../inc/common-functions.sh
. "${TMP_PATH:?}/inc/common-functions.sh" || exit "${?}"

### CODE ###

INSTALL_FDROIDPRIVEXT="$(parse_setting 'INSTALL_FDROIDPRIVEXT' "${INSTALL_FDROIDPRIVEXT:?}")"
INSTALL_AURORASERVICES="$(parse_setting 'INSTALL_AURORASERVICES' "${INSTALL_AURORASERVICES:?}")"
INSTALL_NEWPIPE="$(parse_setting 'INSTALL_NEWPIPE' "${INSTALL_NEWPIPE:?}")"
INSTALL_PLAYSTORE="$(parse_setting 'INSTALL_PLAYSTORE' "${INSTALL_PLAYSTORE:-}")"
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

  setup_app 1 'UnifiedNlp (legacy)' 'LegacyNetworkLocation' 'app' false false

  if test "${IS_EMU:?}" = 'true'; then
    move_rename_file "${TMP_PATH:?}/origin/profiles/lenovo_yoga_tab_3_pro_10_inches_23.xml" "${TMP_PATH:?}/files/etc/microg_device_profile.xml"
  fi

  install_backends='false'
  if test "${MAIN_ABI:?}" = 'armeabi' && setup_app 1 'microG Services (vtm)' 'GmsCoreVtm' 'priv-app' false false; then
    install_backends='true'
  elif test "${MAIN_ABI:?}" != 'armeabi' && setup_app 1 'microG Services' 'GmsCore' 'priv-app' false false; then
    :
  elif setup_app 1 'microG Services (vtm-legacy)' 'GmsCoreVtmLegacy' 'priv-app' false false; then
    install_backends='true'
  fi

  setup_app 1 'microG Services Framework Proxy' 'GsfProxy' 'priv-app' false false

  if test "${install_backends:?}" = 'true'; then
    setup_app "${INSTALL_MOZILLABACKEND:?}" 'Mozilla UnifiedNlp Backend' 'IchnaeaNlpBackend' 'app'
    setup_app "${INSTALL_DEJAVUBACKEND:?}" 'Déjà Vu Location Service' 'DejaVuBackend' 'app'
    setup_app "${INSTALL_NOMINATIMGEOBACKEND:?}" 'Nominatim Geocoder Backend' 'NominatimGeocoderBackend' 'app'
  fi

  # Store selection
  market_is_fakestore='false'
  if setup_app "${INSTALL_PLAYSTORE:-}" 'Google Play Store' 'PlayStore' 'priv-app' true; then
    :
  elif setup_app "${INSTALL_PLAYSTORE:-}" 'Google Play Store (legacy)' 'PlayStoreLegacy' 'priv-app' true; then
    :
  else
    # Fallback to FakeStore
    market_is_fakestore='true'
    setup_app 1 'microG Companion (FakeStore)' 'FakeStore' 'priv-app' false false
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

  if test "${LIVE_SETUP_ENABLED:?}" = 'true'; then
    choose 'Do you want to reset GMS data of all apps?' '+) Yes' '-) No'
    if test "$?" -eq 3; then
      RESET_GMS_DATA_OF_ALL_APPS='1'
    else
      RESET_GMS_DATA_OF_ALL_APPS='0'
    fi
  fi

  delete "${TMP_PATH:?}/origin"
else
  ui_msg 'Starting uninstallation...'
  ui_msg_empty_line
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
{
  ui_debug ''
  _initial_free_space="$(_get_free_space)" || _initial_free_space='-1'

  readonly IS_INCLUDED='true'
  export IS_INCLUDED
  # shellcheck source=SCRIPTDIR/uninstall.sh
  . "${TMP_PATH:?}/uninstall.sh"

  delete "${SYS_PATH:?}/etc/zips/${MODULE_ID:?}.prop"

  # Reclaiming free space may take some time
  _wait_free_space_changes 5 "${_initial_free_space:?}"
  unset _initial_free_space
}

if test "${IS_INSTALLATION:?}" != 'true'; then
  clear_app com.android.vending
  clear_app com.google.android.gsf.login
  clear_app com.google.android.gsf
  clear_app com.google.android.gms

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
printf '%s\n' "fakestore=${market_is_fakestore:?}" 1>> "${TMP_PATH:?}/files/etc/zips/${MODULE_ID:?}.prop"

if test -e "${TMP_PATH:?}/files/bin/minutil"; then
  set_perm 0 2000 0755 "${TMP_PATH:?}/files/bin/minutil"
fi

# Install
if test -f "${TMP_PATH:?}/files/etc/microg.xml"; then copy_file "${TMP_PATH:?}/files/etc/microg.xml" "${SYS_PATH:?}/etc"; fi
if test -f "${TMP_PATH:?}/files/etc/microg_device_profile.xml"; then copy_file "${TMP_PATH:?}/files/etc/microg_device_profile.xml" "${SYS_PATH:?}/etc"; fi
perform_installation

enable_app com.google.android.gms
enable_app com.google.android.gsf
enable_app com.android.vending

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

# Install utilities
if test -e "${TMP_PATH:?}/files/bin"; then
  ui_msg 'Installing utilities...'
  perform_secure_copy_to_device 'bin'
fi

# Reset GMS data of all apps
if test "${RESET_GMS_DATA_OF_ALL_APPS:?}" != '0'; then
  reset_gms_data_of_all_apps
fi

# Install survival script
if test -e "${SYS_PATH:?}/addon.d"; then
  ui_msg 'Installing survival script...'
  write_file_list "${TMP_PATH}/files" "${TMP_PATH}/files/" "${TMP_PATH}/backup-filelist.lst"
  replace_line_in_file_with_file "${TMP_PATH}/addon.d/00-1-microg.sh" '%PLACEHOLDER-1%' "${TMP_PATH}/backup-filelist.lst"
  copy_file "${TMP_PATH}/addon.d/00-1-microg.sh" "${SYS_PATH}/addon.d"
fi

finalize_and_report_success
