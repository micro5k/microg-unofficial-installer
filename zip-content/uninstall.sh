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
GsfProxy
MarketUpdater
PlayGames

GmsDroidGuard

GmsCore_update
WhisperPush

BlankStore
FakeStore
PlayStore
Vending
EOF
}
# Note: Do not remove GooglePartnerSetup (com.google.android.partnersetup) since some ROMs may need it.

list_app_internal_filenames()
{
cat <<EOF
com.mgoogle.android.gms
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

uninstall_list()
{
cat <<EOF
ChromeHomePage|com.android.partnerbrowsercustomizations.tmobile
ConfigUpdater|com.google.android.configupdater
GmsCore|com.google.android.gms
GoogleFeedback|com.google.android.feedback
GoogleLoginService|com.google.android.gsf.login
GoogleOneTimeInitializer|com.google.android.onetimeinitializer
GoogleServicesFramework|com.google.android.gsf
Velvet|com.google.android.googlequicksearchbox

GmsCoreSetupPrebuilt|
GoogleQuickSearchBox|
PrebuiltGmsCore|
PrebuiltGmsCorePi|
PrebuiltGmsCorePix|

Phonesky|com.android.vending
MarketUpdater|com.android.vending.updater

DroidGuard|org.microg.gms.droidguard

NewPipe|org.schabi.newpipe
YouTube|com.google.android.youtube

|com.qualcomm.location
AMAPNetworkLocation|com.amap.android.location
BaiduNetworkLocation|com.baidu.location
LegacyNetworkLocation|
MediaTekLocationProvider|com.mediatek.android.location
NetworkLocation|com.google.android.location
UnifiedNlp|org.microg.nlp
|org.microg.unifiednlp

|com.google.android.maps

DejaVuBackend|org.fitchfamily.android.dejavu
DejaVuNlpBackend|
IchnaeaNlpBackend|org.microg.nlp.backend.ichnaea
MozillaNlpBackend|
NominatimGeocoderBackend|org.microg.nlp.backend.nominatim
NominatimNlpBackend|
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

uninstall_list | while IFS='|' read FILENAME INTERNAL_NAME OTHER; do
  if test -n "${FILENAME}"; then
    delete_recursive "${PRIVAPP_PATH}/${FILENAME}"
    delete_recursive "${PRIVAPP_PATH}/${FILENAME}.apk"
    delete_recursive "${PRIVAPP_PATH}/${FILENAME}.odex"
    delete_recursive "${SYS_PATH}/app/${FILENAME}"
    delete_recursive "${SYS_PATH}/app/${FILENAME}.apk"
    delete_recursive "${SYS_PATH}/app/${FILENAME}.odex"

    delete_recursive_wildcard /data/dalvik-cache/*/system"@priv-app@${FILENAME}"[@\.]*@classes.*
    delete_recursive_wildcard /data/dalvik-cache/*/system"@app@${FILENAME}"[@\.]*@classes.*
  fi
  if test -n "${INTERNAL_NAME}"; then
    delete_recursive "${SYS_PATH}/etc/permissions/${INTERNAL_NAME}.xml"
    delete_recursive "${PRIVAPP_PATH}/${INTERNAL_NAME}"
    delete_recursive "${PRIVAPP_PATH}/${INTERNAL_NAME}.apk"
    delete_recursive "${SYS_PATH}/app/${INTERNAL_NAME}"
    delete_recursive "${SYS_PATH}/app/${INTERNAL_NAME}.apk"
    delete_recursive_wildcard "/data/app/${INTERNAL_NAME}"-*
    delete_recursive_wildcard "/mnt/asec/${INTERNAL_NAME}"-*
  fi
done
STATUS="$?"; if test "$STATUS" -ne 0; then exit "$STATUS"; fi

list_app_filenames | while read FILENAME; do
  if [[ -z "$FILENAME" ]]; then continue; fi
  delete_recursive "${PRIVAPP_PATH}/$FILENAME"
  delete_recursive "${PRIVAPP_PATH}/$FILENAME.apk"
  delete_recursive "${PRIVAPP_PATH}/$FILENAME.odex"
  delete_recursive "${SYS_PATH}/app/$FILENAME"
  delete_recursive "${SYS_PATH}/app/$FILENAME.apk"
  delete_recursive "${SYS_PATH}/app/$FILENAME.odex"
done

list_app_internal_filenames | while read FILENAME; do
  if [[ -z "$FILENAME" ]]; then continue; fi
  delete_recursive "${SYS_PATH}/etc/permissions/$FILENAME.xml"
  delete_recursive "${PRIVAPP_PATH}/$FILENAME"
  delete_recursive "${PRIVAPP_PATH}/$FILENAME.apk"
  delete_recursive "${PRIVAPP_PATH}/$FILENAME.odex"
  delete_recursive "${SYS_PATH}/app/$FILENAME"
  delete_recursive "${SYS_PATH}/app/$FILENAME.apk"
  delete_recursive "${SYS_PATH}/app/$FILENAME.odex"
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
  delete_recursive "/data/data/$FILENAME"
  delete_recursive_wildcard '/data/user'/*/"${FILENAME}"
  delete_recursive_wildcard '/data/user_de'/*/"${FILENAME}"
  delete_recursive "${INTERNAL_MEMORY_PATH}/Android/data/${FILENAME}"
done

delete_recursive_wildcard "${SYS_PATH}"/addon.d/*-microg.sh
delete_recursive_wildcard "${SYS_PATH}"/addon.d/*-microg-*.sh
delete_recursive_wildcard "${SYS_PATH}"/addon.d/*-unifiednlp.sh
delete_recursive_wildcard "${SYS_PATH}"/addon.d/*-mapsapi.sh
delete_recursive_wildcard "${SYS_PATH}"/addon.d/*-gapps.sh

delete_recursive "${SYS_PATH}"/etc/default-permissions/google-permissions.xml
delete_recursive "${SYS_PATH}"/etc/default-permissions/opengapps-permissions.xml
delete_recursive "${SYS_PATH}"/etc/default-permissions/unifiednlp-permissions.xml
delete_recursive "${SYS_PATH}"/etc/default-permissions/microg-permissions.xml
delete_recursive_wildcard "${SYS_PATH}"/etc/default-permissions/microg-*-permissions.xml

delete_recursive "${SYS_PATH}"/etc/permissions/privapp-permissions-google.xml
delete_recursive "${SYS_PATH}"/etc/permissions/privapp-permissions-microg.xml
delete_recursive "${SYS_PATH}"/etc/permissions/features.xml

delete_recursive "${SYS_PATH}"/etc/sysconfig/google.xml
delete_recursive "${SYS_PATH}"/etc/sysconfig/microg.xml
delete_recursive_wildcard "${SYS_PATH}"/etc/sysconfig/microg-*.xml

DELETE_LIST="
${SYS_PATH}/etc/sysconfig/google_build.xml
${SYS_PATH}/etc/preferred-apps/google.xml
"
rm -rf ${DELETE_LIST}  # Filenames cannot contain spaces

if [[ -z "$INSTALLER" ]]; then
  ui_debug 'Done.'
fi
