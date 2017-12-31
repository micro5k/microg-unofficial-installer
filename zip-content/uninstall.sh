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

list_app_filenames()
{
cat <<EOF
GmsCore
GoogleFeedback
GoogleLoginService
GoogleOneTimeInitializer
GooglePartnerSetup
GoogleServicesFramework
GsfProxy
MarketUpdater
Phonesky
PlayGames
Velvet
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

list_app_internal_filenames()
{
cat <<EOF
com.mgoogle.android.gms
com.google.android.gms
com.google.android.gsf
com.android.vending

com.google.android.location
com.qualcomm.location
org.microg.nlp

org.fitchfamily.android.dejavu
org.microg.nlp.backend.ichnaea
org.microg.nlp.backend.nominatim
EOF
}

list_app_data_to_remove()
{
cat <<EOF
com.mgoogle.android.gms
com.android.vending

com.google.android.location
com.qualcomm.location
org.microg.nlp
EOF
}

if [[ -z "$INSTALLER" ]]; then
  ui_debug()
  {
    echo "$1"
  }

  delete_recursive()
  {
   rm -rf "$1" || ui_debug "Failed to delete '$1'"
  }

  ui_debug 'Uninstalling...'

  SYS_PATH='/system'
  PRIVAPP_PATH="${SYS_PATH}/app"
  if [[ -d "${SYS_PATH}/priv-app" ]]; then PRIVAPP_PATH="${SYS_PATH}/priv-app"; fi
fi

INTERNAL_MEMORY_PATH='/sdcard0'
if [[ -e '/mnt/sdcard' ]]; then INTERNAL_MEMORY_PATH='/mnt/sdcard'; fi

remove_file_if_exist()
{
  if [[ -e "$1" ]]; then
    ui_debug "Deleting '$1'..."
    delete_recursive "$1"
  fi
}

list_app_filenames | while read FILE; do
  if [[ -z "$FILE" ]]; then continue; fi
  remove_file_if_exist "${PRIVAPP_PATH}/$FILE"
  remove_file_if_exist "${PRIVAPP_PATH}/$FILE.apk"
  remove_file_if_exist "${PRIVAPP_PATH}/$FILE.odex"
  remove_file_if_exist "${SYS_PATH}/app/$FILE"
  remove_file_if_exist "${SYS_PATH}/app/$FILE.apk"
  remove_file_if_exist "${SYS_PATH}/app/$FILE.odex"
done

list_app_internal_filenames | while read FILE; do
  if [[ -z "$FILE" ]]; then continue; fi
  remove_file_if_exist "${PRIVAPP_PATH}/$FILE.apk"
  remove_file_if_exist "${SYS_PATH}/app/$FILE.apk"
  remove_file_if_exist "/data/app/$FILE"-*
  remove_file_if_exist "/mnt/asec/$FILE"-*
done

list_app_data_to_remove | while read FILE; do
  if [[ -z "$FILE" ]]; then continue; fi
  remove_file_if_exist "/data/data/$FILE"
  remove_file_if_exist "${INTERNAL_MEMORY_PATH}/Android/data/$FILE"
done

DELETE_LIST="
${SYS_PATH}/etc/permissions/com.qualcomm.location.xml

${SYS_PATH}/addon.d/00-1-microg.sh
${SYS_PATH}/addon.d/1-microg.sh
${SYS_PATH}/addon.d/10-mapsapi.sh
${SYS_PATH}/addon.d/70-microg.sh

${SYS_PATH}/addon.d/05-microg.sh
${SYS_PATH}/addon.d/05-microg-playstore.sh
${SYS_PATH}/addon.d/05-microg-playstore-patched.sh
${SYS_PATH}/addon.d/05-unifiednlp.sh

${SYS_PATH}/etc/default-permissions/microg-permissions.xml
${SYS_PATH}/etc/default-permissions/microg-playstore-permissions.xml
${SYS_PATH}/etc/default-permissions/microg-playstore-patched-permissions.xml
${SYS_PATH}/etc/default-permissions/unifiednlp-permissions.xml

${SYS_PATH}/etc/sysconfig/microg.xml
${SYS_PATH}/etc/sysconfig/microg-playstore.xml
${SYS_PATH}/etc/sysconfig/microg-playstore-patched.xml
"
rm -rf ${DELETE_LIST}  # Filenames cannot contain spaces

if [[ -z "$INSTALLER" ]]; then
  ui_debug 'Done.'
fi
