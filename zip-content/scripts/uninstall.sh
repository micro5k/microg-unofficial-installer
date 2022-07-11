#!/sbin/sh
# shellcheck disable=SC3010

# SC3010: In POSIX sh, [[ ]] is undefined

# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

list_app_filenames()
{
cat <<'EOF'
EOF
}

list_app_data_to_remove()
{
cat <<'EOF'
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
cat <<'EOF'
ChromeHomePage|com.android.partnerbrowsercustomizations.tmobile
ConfigUpdater|com.google.android.configupdater
GmsCore|com.google.android.gms
GoogleFeedback|com.google.android.feedback
GoogleLoginService|com.google.android.gsf.login
GoogleOneTimeInitializer|com.google.android.onetimeinitializer
GoogleServicesFramework|com.google.android.gsf
|com.mgoogle.android.gms
PlayGames|com.google.android.play.games
Velvet|com.google.android.googlequicksearchbox

GmsCore_update|
GmsCoreSetupPrebuilt|
GoogleQuickSearchBox|
GsfProxy|
PrebuiltGmsCore|
PrebuiltGmsCorePi|
PrebuiltGmsCorePix|
MicroGGMSCore|

MarketUpdater|com.android.vending.updater
Phonesky|com.android.vending
Vending|

BlankStore|
FakeStore|
PlayStore|

DroidGuard|org.microg.gms.droidguard
GmsDroidGuard|

NewPipe|org.schabi.newpipe
NewPipeLegacy|org.schabi.newpipelegacy
YouTube|com.google.android.youtube

|com.qualcomm.location
AMAPNetworkLocation|com.amap.android.location
BaiduNetworkLocation|com.baidu.location
Baidu_Location|com.baidu.map.location
OfflineNetworkLocation_Baidu|
LegacyNetworkLocation|
MediaTekLocationProvider|com.mediatek.android.location
NetworkLocation|com.google.android.location
UnifiedNlp|org.microg.nlp
|org.microg.unifiednlp

DejaVuBackend|org.fitchfamily.android.dejavu
DejaVuNlpBackend|
IchnaeaNlpBackend|org.microg.nlp.backend.ichnaea
MozillaNlpBackend|
NominatimGeocoderBackend|org.microg.nlp.backend.nominatim
NominatimNlpBackend|

AndroidAutoStubPrebuilt|com.google.android.projection.gearhead
AndroidAuto|
|com.google.android.gms.car

WhisperPush|org.whispersystems.whisperpush

HwAps|com.huawei.android.hwaps
HwPowerGenieEngine3|com.huawei.powergenie
EOF
}
# Note: Do not remove GooglePartnerSetup (com.google.android.partnersetup) since some ROMs may need it.

framework_uninstall_list()
{
cat <<'EOF'
com.google.android.maps|
EOF
}

if [[ -z "${INSTALLER}" ]]; then
  ui_debug()
  {
    echo "$1"
  }

  delete_recursive()
  {
    if test -e "$1"; then
      ui_debug "Deleting '$1'..."
      rm -rf -- "$1" || ui_debug "Failed to delete files/folders"
    fi
  }

  delete_recursive_wildcard()
  {
    for filename in "$@"; do
      if test -e "${filename}"; then
        ui_debug "Deleting '${filename}'...."
        rm -rf -- "${filename:?}" || ui_debug "Failed to delete files/folders"
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

uninstall_list | while IFS='|' read -r FILENAME INTERNAL_NAME _; do
  if test -n "${FILENAME}"; then
    delete_recursive "${PRIVAPP_PATH}/${FILENAME}"
    delete_recursive "${PRIVAPP_PATH}/${FILENAME}.apk"
    delete_recursive "${PRIVAPP_PATH}/${FILENAME}.odex"
    delete_recursive "${SYS_PATH}/app/${FILENAME}"
    delete_recursive "${SYS_PATH}/app/${FILENAME}.apk"
    delete_recursive "${SYS_PATH}/app/${FILENAME}.odex"

    delete_recursive_wildcard /data/dalvik-cache/*/system@priv-app@"${FILENAME}"[@\.]*@classes*
    delete_recursive_wildcard /data/dalvik-cache/*/system@app@"${FILENAME}"[@\.]*@classes*
    delete_recursive_wildcard /data/dalvik-cache/system@app@"${FILENAME}"[@\.]*@classes*
  fi
  if test -n "${INTERNAL_NAME}"; then
    delete_recursive "${SYS_PATH}/etc/permissions/privapp-permissions-${INTERNAL_NAME}.xml"
    delete_recursive "${SYS_PATH}/etc/permissions/${INTERNAL_NAME}.xml"
    delete_recursive "${PRIVAPP_PATH}/${INTERNAL_NAME}"
    delete_recursive "${PRIVAPP_PATH}/${INTERNAL_NAME}.apk"
    delete_recursive "${SYS_PATH}/app/${INTERNAL_NAME}"
    delete_recursive "${SYS_PATH}/app/${INTERNAL_NAME}.apk"
    delete_recursive_wildcard "/data/app/${INTERNAL_NAME}"-*
    delete_recursive_wildcard "/mnt/asec/${INTERNAL_NAME}"-*
  fi
done
STATUS="$?"; if test "${STATUS}" -ne 0; then exit "${STATUS}"; fi

framework_uninstall_list | while IFS='|' read -r INTERNAL_NAME _; do
  if test -n "${INTERNAL_NAME}"; then
    delete_recursive "${SYS_PATH}/etc/permissions/${INTERNAL_NAME}.xml"
    delete_recursive "${SYS_PATH}/framework/${INTERNAL_NAME}.jar"
    delete_recursive "${SYS_PATH}/framework/${INTERNAL_NAME}.odex"
    delete_recursive_wildcard "${SYS_PATH}/framework/oat"/*/"${INTERNAL_NAME}.odex"
  fi
done
STATUS="$?"; if test "${STATUS}" -ne 0; then exit "${STATUS}"; fi

list_app_filenames | while read -r FILENAME; do
  if [[ -z "${FILENAME}" ]]; then continue; fi
  delete_recursive "${PRIVAPP_PATH}/${FILENAME}"
  delete_recursive "${PRIVAPP_PATH}/${FILENAME}.apk"
  delete_recursive "${PRIVAPP_PATH}/${FILENAME}.odex"
  delete_recursive "${SYS_PATH}/app/${FILENAME}"
  delete_recursive "${SYS_PATH}/app/${FILENAME}.apk"
  delete_recursive "${SYS_PATH}/app/${FILENAME}.odex"
done

list_app_filenames | while read -r FILENAME; do
  if [[ -z "${FILENAME}" ]]; then continue; fi
  delete_recursive_wildcard /data/dalvik-cache/system@app@"${FILENAME}"[@\.]*@classes*
  delete_recursive_wildcard /data/dalvik-cache/*/system@priv-app@"${FILENAME}"[@\.]*@classes*
  delete_recursive_wildcard /data/dalvik-cache/*/system@app@"${FILENAME}"[@\.]*@classes*
done

list_app_data_to_remove | while read -r FILENAME; do
  if [[ -z "${FILENAME}" ]]; then continue; fi
  delete_recursive "/data/data/${FILENAME}"
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
delete_recursive "${SYS_PATH}"/etc/default-permissions/phonesky-permissions.xml
delete_recursive "${SYS_PATH}"/etc/default-permissions/contacts-calendar-sync.xml
delete_recursive "${SYS_PATH}"/etc/default-permissions/opengapps-permissions.xml
delete_recursive "${SYS_PATH}"/etc/default-permissions/unifiednlp-permissions.xml
delete_recursive "${SYS_PATH}"/etc/default-permissions/microg-permissions.xml
delete_recursive_wildcard "${SYS_PATH}"/etc/default-permissions/microg-*-permissions.xml

delete_recursive "${SYS_PATH}"/etc/permissions/features.xml
delete_recursive "${SYS_PATH}"/etc/permissions/privapp-permissions-google.xml
delete_recursive "${SYS_PATH}"/etc/permissions/privapp-permissions-microg.xml

delete_recursive "${SYS_PATH}"/etc/sysconfig/features.xml
delete_recursive "${SYS_PATH}"/etc/sysconfig/google.xml
delete_recursive "${SYS_PATH}"/etc/sysconfig/google_build.xml
delete_recursive "${SYS_PATH}"/etc/sysconfig/microg.xml
delete_recursive_wildcard "${SYS_PATH}"/etc/sysconfig/microg-*.xml

delete_recursive "${SYS_PATH}"/etc/preferred-apps/google.xml

delete_recursive "${SYS_PATH}"/etc/org.fdroid.fdroid/additional_repos.xml

if test -e "${SYS_PATH}/etc/zips"; then rmdir --ignore-fail-on-non-empty -- "${SYS_PATH}/etc/zips"; fi

if [[ -z "${INSTALLER}" ]]; then
  ui_debug 'Done.'
fi
