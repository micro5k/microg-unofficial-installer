#!/sbin/sh
# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# shellcheck disable=SC3010 # In POSIX sh, [[ ]] is undefined

list_app_data_to_remove()
{
  cat << 'EOF'
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
  cat << 'EOF'
ChromeHomePage|com.android.partnerbrowsercustomizations.tmobile
ConfigUpdater|com.google.android.configupdater
GmsCore|com.google.android.gms
GoogleFeedback|com.google.android.feedback
BetaFeedback|com.google.android.apps.betterbug
GoogleLoginService|com.google.android.gsf.login
GoogleOneTimeInitializer|com.google.android.onetimeinitializer
GoogleServicesFramework|com.google.android.gsf
|com.mgoogle.android.gms
PlayGames|com.google.android.play.games
Velvet|com.google.android.googlequicksearchbox|true

GmsCore_update|
GmsCoreSetupPrebuilt|
GoogleQuickSearchBox|
GsfProxy|
PrebuiltGmsCore|
PrebuiltGmsCorePi|
PrebuiltGmsCorePix|
PrebuiltGmsCoreSc|
MicroGGMSCore|

MarketUpdater|com.android.vending.updater
Phonesky|com.android.vending
Vending|

BlankStore|
FakeStore|
PlayStore|

DroidGuard|org.microg.gms.droidguard
GmsDroidGuard|

FDroidPrivilegedExtension|org.fdroid.fdroid.privileged
F-DroidPrivilegedExtension|
FDroidPrivileged|
FDroidPriv|

NewPipe|org.schabi.newpipe
NewPipeLegacy|org.schabi.newpipelegacy
YouTube|com.google.android.youtube
YouTubeMusicPrebuilt|com.google.android.apps.youtube.music

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

VollaNlpRRO|com.volla.overlay.nlp
VollaNlp|com.volla.nlp
VollaGSMNlp|com.volla.gsmnlp

AndroidAuto|com.google.android.projection.gearhead
AndroidAutoPrebuiltStub|
AndroidAutoStubPrebuilt|
AndroidAutoFullPrebuilt|
|com.google.android.gms.car

WhisperPush|org.whispersystems.whisperpush

PrebuiltGoogleTelemetryTvp|com.google.mainline.telemetry
HwAps|com.huawei.android.hwaps
HwPowerGenieEngine3|com.huawei.powergenie
EOF
}
# Note: Do not remove GooglePartnerSetup (com.google.android.partnersetup) since some ROMs may need it.

framework_uninstall_list()
{
  cat << 'EOF'
com.google.android.maps|
com.qti.location.sdk|
izat.xt.srv|
EOF
}

if test "${INSTALLER:-false}" = 'false'; then
  ui_error()
  {
    printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR: ${1?}"
    exit 1
  }

  ui_debug()
  {
    printf '%s\n' "${1?}"
  }

  delete()
  {
    for filename in "${@?}"; do
      if test -e "${filename?}"; then
        ui_debug "Deleting '${filename?}'...."
        rm -rf -- "${filename:?}" || ui_debug 'Failed to delete files/folders'
      fi
    done
  }

  ui_debug 'Uninstalling...'

  SYS_PATH="${ANDROID_ROOT:-/system}"
  PRIVAPP_PATH="${SYS_PATH}/app"
  if test -e "${SYS_PATH}/priv-app"; then PRIVAPP_PATH="${SYS_PATH}/priv-app"; fi
  DATA_PATH="${ANDROID_DATA:-/data}"
fi

track_init()
{
  REALLY_DELETED='false'
}

track_really_deleted()
{
  if test "${REALLY_DELETED:?}" = 'true'; then
    return 0
  fi
  return 1
}

delete_tracked()
{
  for filename in "${@?}"; do
    if test -e "${filename?}"; then
      REALLY_DELETED='true'
      ui_debug "Deleting '${filename?}'...."
      rm -rf -- "${filename:?}" || ui_error 'Failed to delete files/folders'
    fi
  done
}

INTERNAL_MEMORY_PATH='/sdcard0'
if [[ -e '/mnt/sdcard' ]]; then INTERNAL_MEMORY_PATH='/mnt/sdcard'; fi

uninstall_list | while IFS='|' read -r FILENAME INTERNAL_NAME DEL_SYS_APPS_ONLY _; do
  track_init

  if test -n "${INTERNAL_NAME}"; then
    delete "${SYS_PATH}/etc/permissions/${INTERNAL_NAME}.xml"
    delete "${SYS_PATH}/etc/sysconfig/sysconfig-${INTERNAL_NAME}.xml"
    delete_tracked "${PRIVAPP_PATH}/${INTERNAL_NAME}"
    delete_tracked "${PRIVAPP_PATH}/${INTERNAL_NAME}.apk"
    delete_tracked "${SYS_PATH}/app/${INTERNAL_NAME}"
    delete_tracked "${SYS_PATH}/app/${INTERNAL_NAME}.apk"

    # Legacy xml paths
    delete "${SYS_PATH}/etc/default-permissions/${INTERNAL_NAME:?}-permissions.xml"
    # Other installers
    delete "${SYS_PATH}/etc/permissions/${INTERNAL_NAME:?}.xml"
    delete "${SYS_PATH}/etc/permissions/privapp-permissions-${INTERNAL_NAME:?}.xml"
    delete "${SYS_PATH}/etc/default-permissions/default-permissions-${INTERNAL_NAME:?}.xml"

    # App libs
    delete /data/app-lib/"${INTERNAL_NAME:?}"-*

    # Dalvik cache
    delete /data/dalvik-cache/*/data@app@"${INTERNAL_NAME:?}"-*@classes*
    delete /data/dalvik-cache/data@app@"${INTERNAL_NAME:?}"-*@classes*
  fi

  if test -n "${FILENAME}"; then
    delete_tracked "${PRIVAPP_PATH}/${FILENAME}"
    delete_tracked "${PRIVAPP_PATH}/${FILENAME}.apk"
    delete_tracked "${PRIVAPP_PATH}/${FILENAME}.odex"
    delete_tracked "${SYS_PATH}/app/${FILENAME}"
    delete_tracked "${SYS_PATH}/app/${FILENAME}.apk"
    delete_tracked "${SYS_PATH}/app/${FILENAME}.odex"

    delete_tracked "${SYS_PATH}/system_ext/priv-app/${FILENAME}"
    delete_tracked "${SYS_PATH}/system_ext/app/${FILENAME}"
    delete_tracked "/system_ext/priv-app/${FILENAME}"
    delete_tracked "/system_ext/app/${FILENAME}"

    delete_tracked "${SYS_PATH}/product/priv-app/${FILENAME}"
    delete_tracked "${SYS_PATH}/product/app/${FILENAME}"
    delete_tracked "/product/priv-app/${FILENAME}"
    delete_tracked "/product/app/${FILENAME}"

    delete_tracked "${SYS_PATH}/vendor/priv-app/${FILENAME}"
    delete_tracked "${SYS_PATH}/vendor/app/${FILENAME}"
    delete_tracked "/vendor/priv-app/${FILENAME}"
    delete_tracked "/vendor/app/${FILENAME}"

    # Current xml paths
    delete "${SYS_PATH}/etc/permissions/privapp-permissions-${FILENAME:?}.xml"
    delete "${SYS_PATH}/etc/default-permissions/default-permissions-${FILENAME:?}.xml"
    # Legacy xml paths
    delete "${SYS_PATH}/etc/default-permissions/${FILENAME:?}-permissions.xml"

    # Dalvik cache
    delete /data/dalvik-cache/*/system@priv-app@"${FILENAME}"[@\.]*@classes*
    delete /data/dalvik-cache/*/system@app@"${FILENAME}"[@\.]*@classes*
    delete /data/dalvik-cache/system@priv-app@"${FILENAME}"[@\.]*@classes*
    delete /data/dalvik-cache/system@app@"${FILENAME}"[@\.]*@classes*
  fi

  if test -n "${INTERNAL_NAME}"; then
    if test "${DEL_SYS_APPS_ONLY:-false}" = false || track_really_deleted; then
      delete "/data/app/${INTERNAL_NAME}"
      delete "/data/app/${INTERNAL_NAME}.apk"
      delete "/data/app/${INTERNAL_NAME}"-*
      delete "/mnt/asec/${INTERNAL_NAME}"
      delete "/mnt/asec/${INTERNAL_NAME}.apk"
      delete "/mnt/asec/${INTERNAL_NAME}"-*
    fi
    # Check also /data/app-private /data/app-asec /data/preload
  fi
done
STATUS="$?"
if test "${STATUS}" -ne 0; then exit "${STATUS}"; fi

framework_uninstall_list | while IFS='|' read -r INTERNAL_NAME _; do
  if test -n "${INTERNAL_NAME}"; then
    delete "${SYS_PATH:?}/etc/permissions/${INTERNAL_NAME:?}.xml"
    delete "${SYS_PATH:?}/framework/${INTERNAL_NAME:?}.jar"
    delete "${SYS_PATH:?}/framework/${INTERNAL_NAME:?}.odex"
    delete "${SYS_PATH:?}"/framework/oat/*/"${INTERNAL_NAME:?}.odex"

    # Dalvik cache
    delete /data/dalvik-cache/*/system@framework@"${INTERNAL_NAME:?}".jar@classes*
    delete /data/dalvik-cache/*/system@framework@"${INTERNAL_NAME:?}".odex@classes*
    delete /data/dalvik-cache/system@framework@"${INTERNAL_NAME:?}".jar@classes*
    delete /data/dalvik-cache/system@framework@"${INTERNAL_NAME:?}".odex@classes*
  fi
done
STATUS="$?"
if test "${STATUS}" -ne 0; then exit "${STATUS}"; fi

list_app_data_to_remove | while IFS='|' read -r FILENAME; do
  if [[ -z "${FILENAME}" ]]; then continue; fi
  delete "/data/data/${FILENAME}"
  delete '/data/user'/*/"${FILENAME}"
  delete '/data/user_de'/*/"${FILENAME}"
  delete "${INTERNAL_MEMORY_PATH}/Android/data/${FILENAME}"
done

delete "${SYS_PATH}"/addon.d/*-microg.sh
delete "${SYS_PATH}"/addon.d/*-microg-*.sh
delete "${SYS_PATH}"/addon.d/*-unifiednlp.sh
delete "${SYS_PATH}"/addon.d/*-mapsapi.sh
delete "${SYS_PATH}"/addon.d/*-gapps.sh
delete "${SYS_PATH}"/addon.d/80-fdroid.sh

delete "${SYS_PATH}"/etc/default-permissions/google-permissions.xml
delete "${SYS_PATH}"/etc/default-permissions/phonesky-permissions.xml
delete "${SYS_PATH}"/etc/default-permissions/contacts-calendar-sync.xml
delete "${SYS_PATH}"/etc/default-permissions/opengapps-permissions.xml
delete "${SYS_PATH}"/etc/default-permissions/unifiednlp-permissions.xml
delete "${SYS_PATH}"/etc/default-permissions/microg-permissions.xml
delete "${SYS_PATH}"/etc/default-permissions/permissions-com.google.android.gms.xml
delete "${SYS_PATH}"/etc/default-permissions/microg-*-permissions.xml

delete "${SYS_PATH}"/etc/permissions/features.xml
delete "${SYS_PATH}"/etc/permissions/privapp-permissions-google.xml
delete "${SYS_PATH}"/etc/permissions/privapp-permissions-google-p.xml
#delete "${SYS_PATH}"/etc/permissions/privapp-permissions-google-se.xml
delete "${SYS_PATH}"/etc/permissions/privapp-permissions-org.microG.xml
delete "${SYS_PATH}"/etc/permissions/privapp-permissions-microg.xml
delete "${SYS_PATH}"/etc/permissions/permissions_org.fdroid.fdroid.privileged.xml

delete "${SYS_PATH}"/etc/sysconfig/features.xml
delete "${SYS_PATH}"/etc/sysconfig/google.xml
delete "${SYS_PATH}"/etc/sysconfig/google_build.xml
delete "${SYS_PATH}"/etc/sysconfig/org.microG.xml
delete "${SYS_PATH}"/etc/sysconfig/microg.xml
delete "${SYS_PATH}"/etc/sysconfig/microg-*.xml

delete "${SYS_PATH}"/etc/preferred-apps/google.xml

delete "${SYS_PATH}/etc/org.fdroid.fdroid/additional_repos.xml"
delete "${SYS_PATH}/etc/microg.xml"

# Legacy file
delete "${SYS_PATH:?}/etc/zips/ug.prop"

if test -e "${SYS_PATH:?}/etc/org.fdroid.fdroid"; then rmdir --ignore-fail-on-non-empty -- "${SYS_PATH:?}/etc/org.fdroid.fdroid" || true; fi
if test -e "${SYS_PATH:?}/etc/zips"; then rmdir --ignore-fail-on-non-empty -- "${SYS_PATH:?}/etc/zips" || true; fi

if [[ -z "${INSTALLER}" ]]; then
  ui_debug 'Done.'
fi
