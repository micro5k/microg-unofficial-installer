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

list_app_filenames()
{
cat <<EOF
GmsCore
GoogleFeedback
GoogleLoginService
GoogleOneTimeInitializer
GoogleServicesFramework
GsfProxy
MarketUpdater
Phonesky
PlayGames
Velvet

DroidGuard
GmsDroidGuard

NewPipe
YouTube

GmsCore_update
GmsCoreSetupPrebuilt
PrebuiltGmsCore
WhisperPush

BlankStore
FakeStore
FDroidPriv
FDroidPrivileged
PlayStore
Vending

AMAPNetworkLocation
BaiduNetworkLocation
LegacyNetworkLocation
NetworkLocation
UnifiedNlp

DejaVuBackend
DejaVuNlpBackend
IchnaeaNlpBackend
MozillaNlpBackend
NominatimGeocoderBackend
NominatimNlpBackend
EOF
}
# Note: Do not remove GooglePartnerSetup since some ROMs may need it.

list_app_internal_filenames()
{
cat <<EOF
com.mgoogle.android.gms
com.google.android.gms
com.google.android.feedback
com.google.android.gsf.login
com.google.android.gsf
com.android.vending

org.microg.gms.droidguard

org.schabi.newpipe
com.google.android.youtube

com.qualcomm.location
com.amap.android.location
com.baidu.location
com.google.android.location
org.microg.nlp
org.microg.unifiednlp
com.google.android.maps

org.fitchfamily.android.dejavu
org.microg.nlp.backend.ichnaea
org.microg.nlp.backend.nominatim
EOF
}

list_app_data_to_remove()
{
cat <<EOF
com.mgoogle.android.gms
com.google.android.feedback
com.google.android.gsf.login
com.google.android.gsf
com.android.vending

com.google.android.youtube

com.qualcomm.location
com.amap.android.location
com.baidu.location
com.google.android.location
org.microg.nlp
org.microg.unifiednlp
EOF
}

if [[ -z "$INSTALLER" ]]; then
  ui_debug()
  {
    echo "$1"
  }

  delete_recursive()
  {
    if test -e "$1"; then
      ui_debug "Deleting '$1'..."
      rm -rf "$1" || ui_debug "Failed to delete files/folders"
    fi
  }

  delete_recursive_wildcard()
  {
    for filename in "$@"; do
      if test -e "$filename"; then
        ui_debug "Deleting '$filename'...."
        rm -rf "$filename" || ui_debug "Failed to delete files/folders"
      fi
    done
  }

  ui_debug 'Uninstalling...'

  SYS_PATH='/system'
  PRIVAPP_PATH="${SYS_PATH}/app"
  if [[ -d "${SYS_PATH}/priv-app" ]]; then PRIVAPP_PATH="${SYS_PATH}/priv-app"; fi
fi

INTERNAL_MEMORY_PATH='/sdcard0'
if [[ -e '/mnt/sdcard' ]]; then INTERNAL_MEMORY_PATH='/mnt/sdcard'; fi

delete_file_or_folder_if_exist()
{
  delete_recursive "$1"
}

list_app_filenames | while read FILENAME; do
  if [[ -z "$FILENAME" ]]; then continue; fi
  delete_file_or_folder_if_exist "${PRIVAPP_PATH}/$FILENAME"
  delete_file_or_folder_if_exist "${PRIVAPP_PATH}/$FILENAME.apk"
  delete_file_or_folder_if_exist "${PRIVAPP_PATH}/$FILENAME.odex"
  delete_file_or_folder_if_exist "${SYS_PATH}/app/$FILENAME"
  delete_file_or_folder_if_exist "${SYS_PATH}/app/$FILENAME.apk"
  delete_file_or_folder_if_exist "${SYS_PATH}/app/$FILENAME.odex"
done

list_app_internal_filenames | while read FILENAME; do
  if [[ -z "$FILENAME" ]]; then continue; fi
  delete_file_or_folder_if_exist "${SYS_PATH}/etc/permissions/$FILENAME.xml"
  delete_file_or_folder_if_exist "${PRIVAPP_PATH}/$FILENAME"
  delete_file_or_folder_if_exist "${PRIVAPP_PATH}/$FILENAME.apk"
  delete_file_or_folder_if_exist "${PRIVAPP_PATH}/$FILENAME.odex"
  delete_file_or_folder_if_exist "${SYS_PATH}/app/$FILENAME"
  delete_file_or_folder_if_exist "${SYS_PATH}/app/$FILENAME.apk"
  delete_file_or_folder_if_exist "${SYS_PATH}/app/$FILENAME.odex"
  delete_recursive_wildcard "/data/app/${FILENAME}"-*
  delete_recursive_wildcard "/mnt/asec/${FILENAME}"-*
done

list_app_filenames | while read FILENAME; do
  if [[ -z "$FILENAME" ]]; then continue; fi
  delete_recursive_wildcard /data/dalvik-cache/*/system"@priv-app@${FILENAME}"[@\.]*@classes.*
  delete_recursive_wildcard /data/dalvik-cache/*/system"@app@${FILENAME}"[@\.]*@classes.*
done

list_app_data_to_remove | while read FILENAME; do
  if [[ -z "$FILENAME" ]]; then continue; fi
  delete_file_or_folder_if_exist "/data/data/$FILENAME"
  delete_recursive_wildcard '/data/user'/*/"${FILENAME}"
  delete_recursive_wildcard '/data/user_de'/*/"${FILENAME}"
  delete_file_or_folder_if_exist "${INTERNAL_MEMORY_PATH}/Android/data/${FILENAME}"
done

DELETE_LIST="
${SYS_PATH}/addon.d/00-1-microg.sh
${SYS_PATH}/addon.d/00-1-microg-k.sh
${SYS_PATH}/addon.d/1-microg.sh
${SYS_PATH}/addon.d/10-mapsapi.sh
${SYS_PATH}/addon.d/70-microg.sh
${SYS_PATH}/addon.d/70-gapps.sh

${SYS_PATH}/addon.d/05-microg.sh
${SYS_PATH}/addon.d/05-microg-playstore.sh
${SYS_PATH}/addon.d/05-microg-playstore-patched.sh
${SYS_PATH}/addon.d/05-unifiednlp.sh

${SYS_PATH}/etc/default-permissions/opengapps-permissions.xml
${SYS_PATH}/etc/default-permissions/microg-permissions.xml
${SYS_PATH}/etc/default-permissions/microg-playstore-permissions.xml
${SYS_PATH}/etc/default-permissions/microg-playstore-patched-permissions.xml
${SYS_PATH}/etc/default-permissions/unifiednlp-permissions.xml

${SYS_PATH}/etc/sysconfig/google.xml
${SYS_PATH}/etc/sysconfig/google_build.xml
${SYS_PATH}/etc/sysconfig/microg.xml
${SYS_PATH}/etc/sysconfig/microg-playstore.xml
${SYS_PATH}/etc/sysconfig/microg-playstore-patched.xml

${SYS_PATH}/etc/preferred-apps/google.xml
"
rm -rf ${DELETE_LIST}  # Filenames cannot contain spaces

if [[ -z "$INSTALLER" ]]; then
  ui_debug 'Done.'
fi
