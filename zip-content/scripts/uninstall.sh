#!/sbin/sh
# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

list_app_data_to_remove()
{
  cat << 'EOF'
com.google.android.feedback
com.google.android.gsf.login
com.google.android.gsf
com.android.vending

com.google.android.youtube

com.mgoogle.android.gms

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
GmsCore|com.google.android.gms
GoogleServicesFramework|com.google.android.gsf
GoogleLoginService|com.google.android.gsf.login

PrebuiltGmsCore|
PrebuiltGmsCorePi|
PrebuiltGmsCorePix|
PrebuiltGmsCoreSc|
GmsCoreSetupPrebuilt|
GmsCore_update|
gmscore_debug|
MicroGGMSCore|
MicroGGSFProxy|
GsfProxy|
|com.mgoogle.android.gms

PartnerSetupPrebuilt|com.google.android.partnersetup
GooglePartnerSetup|
PartnerBookmarksProvider|com.android.providers.partnerbookmarks
ChromeHomePage|com.android.partnerbrowsercustomizations.tmobile
GoogleFeedback|com.google.android.feedback
BetaFeedback|com.google.android.apps.betterbug

PlayAutoInstallConfig|android.autoinstalls.config.google.nexus
|android.autoinstalls.config.sony.xperia

Velvet|com.google.android.googlequicksearchbox
GoogleQuickSearchBox|
PrebuiltGmail|com.google.android.gm
PlayGames|com.google.android.play.games

Phonesky|com.android.vending
Vending|
LicenseChecker|
MarketUpdater|com.android.vending.updater

BlankStore|
FakeStore|
PlayStore|

DroidGuard|org.microg.gms.droidguard
GmsDroidGuard|

FDroidPrivilegedExtension|org.fdroid.fdroid.privileged
F-DroidPrivilegedExtension|
FDroidPrivileged|
FDroidPriv|
AuroraServices|com.aurora.services
auroraservices|

NewPipe|org.schabi.newpipe
NewPipeLegacy|org.schabi.newpipelegacy
NewPipeLegacyRevo|org.schabi.newpipelegacy.Revo
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
mozillaNLPBackend|
mozillaNLPBacken|
NominatimGeocoderBackend|org.microg.nlp.backend.nominatim
NominatimNlpBackend|

VollaNlpRRO|com.volla.overlay.nlp
VollaNlp|com.volla.nlp
VollaGSMNlp|com.volla.gsmnlp

AndroidAutoStubPrebuilt|com.google.android.projection.gearhead
AndroidAutoPrebuiltStub|
AndroidAutoFullPrebuilt|
AndroidAuto|
|com.google.android.gms.car

WhisperPush|org.whispersystems.whisperpush
Hangouts|com.google.android.talk

HwAps|com.huawei.android.hwaps
HwPowerGenieEngine3|com.huawei.powergenie
EOF
}

framework_uninstall_list()
{
  cat << 'EOF'
com.google.android.maps|
com.qti.location.sdk|
izat.xt.srv|
EOF
}

if test "${IS_INCLUDED:-false}" = 'false'; then
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
    for filename in "${@}"; do
      if test -e "${filename?}"; then
        ui_debug "Deleting '${filename?}'...."
        rm -rf -- "${filename:?}" || ui_debug 'Failed to delete files/folders'
      fi
    done
  }

  ui_debug 'Uninstalling...'

  # shellcheck disable=SC2034
  {
    IS_INSTALLATION='false'
    FIRST_INSTALLATION='true'
    API=999
    SYS_PATH="${ANDROID_ROOT:-/system}"
    PRIVAPP_PATH="${SYS_PATH:?}/app"
    if test -e "${SYS_PATH:?}/priv-app"; then PRIVAPP_PATH="${SYS_PATH:?}/priv-app"; fi
    DATA_PATH="${ANDROID_DATA:-/data}"
  }
fi

delete_symlinks()
{
  for filename in "${@}"; do
    if test -h "${filename?}"; then
      ui_debug "Deleting symlink '${filename?}'...."
      rm -f -- "${filename:?}" || ui_debug 'Failed to delete symlink'
    fi
  done
}

delete_folder_content_silent()
{
  if test -e "${1:?}"; then
    find "${1:?}" -mindepth 1 -delete
  fi
}

INTERNAL_MEMORY_PATH='/sdcard0'
if test -e '/mnt/sdcard'; then INTERNAL_MEMORY_PATH='/mnt/sdcard'; fi

uninstall_list | while IFS='|' read -r FILENAME INTERNAL_NAME _; do
  if test -n "${INTERNAL_NAME}"; then
    delete "${PRIVAPP_PATH}/${INTERNAL_NAME}"
    delete "${PRIVAPP_PATH}/${INTERNAL_NAME}.apk"
    delete "${SYS_PATH}/app/${INTERNAL_NAME}"
    delete "${SYS_PATH}/app/${INTERNAL_NAME}.apk"
  fi

  if test -n "${FILENAME}"; then
    delete "${PRIVAPP_PATH}/${FILENAME}"
    delete "${PRIVAPP_PATH}/${FILENAME}.apk"
    delete "${PRIVAPP_PATH}/${FILENAME}.odex"
    delete "${SYS_PATH}/app/${FILENAME}"
    delete "${SYS_PATH}/app/${FILENAME}.apk"
    delete "${SYS_PATH}/app/${FILENAME}.odex"

    delete "${SYS_PATH}/system_ext/priv-app/${FILENAME}"
    delete "${SYS_PATH}/system_ext/app/${FILENAME}"
    delete "/system_ext/priv-app/${FILENAME}"
    delete "/system_ext/app/${FILENAME}"

    delete "${SYS_PATH}/product/priv-app/${FILENAME}"
    delete "${SYS_PATH}/product/app/${FILENAME}"
    delete "/product/priv-app/${FILENAME}"
    delete "/product/app/${FILENAME}"

    delete "${SYS_PATH}/vendor/priv-app/${FILENAME}"
    delete "${SYS_PATH}/vendor/app/${FILENAME}"
    delete "/vendor/priv-app/${FILENAME}"
    delete "/vendor/app/${FILENAME}"

    # Dalvik cache
    delete "${DATA_PATH:?}"/dalvik-cache/system@priv-app@"${FILENAME}"[@\.]*@classes*
    delete "${DATA_PATH:?}"/dalvik-cache/system@app@"${FILENAME}"[@\.]*@classes*
    delete "${DATA_PATH:?}"/dalvik-cache/*/system@priv-app@"${FILENAME}"[@\.]*@classes*
    delete "${DATA_PATH:?}"/dalvik-cache/*/system@app@"${FILENAME}"[@\.]*@classes*

    # Delete legacy libs (very unlikely to be present but possible)
    delete "${SYS_PATH:?}/lib64/${FILENAME:?}"
    delete "${SYS_PATH:?}/lib/${FILENAME:?}"
    delete "/vendor/lib64/${FILENAME:?}"
    delete "/vendor/lib/${FILENAME:?}"
    delete "${SYS_PATH:?}/vendor/lib64/${FILENAME:?}"
    delete "${SYS_PATH:?}/vendor/lib/${FILENAME:?}"

    # Current xml paths
    delete "${SYS_PATH}/etc/permissions/privapp-permissions-${FILENAME:?}.xml"
    delete "${SYS_PATH}/etc/default-permissions/default-permissions-${FILENAME:?}.xml"
    # Legacy xml paths
    delete "${SYS_PATH}/etc/default-permissions/${FILENAME:?}-permissions.xml"
  fi

  if test -n "${INTERNAL_NAME}"; then
    # Only delete app updates during uninstallation or first-time installation
    if test "${IS_INSTALLATION:?}" != 'true' || test "${FIRST_INSTALLATION:?}" = 'true'; then
      delete "${DATA_PATH:?}/app/${INTERNAL_NAME}"
      delete "${DATA_PATH:?}/app/${INTERNAL_NAME}.apk"
      delete "${DATA_PATH:?}/app/${INTERNAL_NAME}"-*
      delete "/mnt/asec/${INTERNAL_NAME}"
      delete "/mnt/asec/${INTERNAL_NAME}.apk"
      delete "/mnt/asec/${INTERNAL_NAME}"-*
      # ToDO => Check also /data/app-private /data/app-asec /data/preload

      # App libs
      delete "${DATA_PATH:?}/app-lib/${INTERNAL_NAME:?}"
      delete "${DATA_PATH:?}/app-lib/${INTERNAL_NAME:?}"-*
      delete_symlinks "${DATA_PATH:?}/data/${INTERNAL_NAME:?}/lib"
    fi

    # Dalvik caches
    delete "${DATA_PATH:?}"/dalvik-cache/data@app@"${INTERNAL_NAME:?}"-*@classes*
    delete "${DATA_PATH:?}"/dalvik-cache/*/data@app@"${INTERNAL_NAME:?}"-*@classes*
    delete "${DATA_PATH:?}"/dalvik-cache/profiles/"${INTERNAL_NAME:?}"

    # Caches
    delete_folder_content_silent "${DATA_PATH:?}/data/${INTERNAL_NAME:?}/code_cache"
    delete_folder_content_silent "${DATA_PATH:?}/data/${INTERNAL_NAME:?}/cache"
    delete_folder_content_silent "${DATA_PATH:?}/data/${INTERNAL_NAME:?}/app_webview/Cache"
    delete_folder_content_silent "${DATA_PATH:?}/data/${INTERNAL_NAME:?}/app_cache_dg"

    # Legacy xml paths
    delete "${SYS_PATH}/etc/default-permissions/${INTERNAL_NAME:?}-permissions.xml"
    # Other installers
    delete "${SYS_PATH}/etc/permissions/privapp-permissions-${INTERNAL_NAME:?}.xml"
    delete "${SYS_PATH}/etc/permissions/permissions_${INTERNAL_NAME:?}.xml"
    delete "${SYS_PATH}/etc/permissions/${INTERNAL_NAME:?}.xml"
    delete "${SYS_PATH}/etc/default-permissions/default-permissions-${INTERNAL_NAME:?}.xml"

    delete "${SYS_PATH}/etc/sysconfig/sysconfig-${INTERNAL_NAME:?}.xml"
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
    delete "${DATA_PATH:?}"/dalvik-cache/*/system@framework@"${INTERNAL_NAME:?}".jar@classes*
    delete "${DATA_PATH:?}"/dalvik-cache/*/system@framework@"${INTERNAL_NAME:?}".odex@classes*
    delete "${DATA_PATH:?}"/dalvik-cache/system@framework@"${INTERNAL_NAME:?}".jar@classes*
    delete "${DATA_PATH:?}"/dalvik-cache/system@framework@"${INTERNAL_NAME:?}".odex@classes*
  fi
done
STATUS="$?"
if test "${STATUS}" -ne 0; then exit "${STATUS}"; fi

if test "${API:?}" -lt 21; then
  delete "${SYS_PATH:?}/lib64/libmapbox-gl.so"
  delete "${SYS_PATH:?}/lib64/libvtm-jni.so"
  delete "${SYS_PATH:?}/lib64/libconscrypt_gmscore_jni.so"
  delete "${SYS_PATH:?}/lib64/libcronet".*."so"
  delete "${SYS_PATH:?}/lib64/libgmscore.so"

  delete "${SYS_PATH:?}/lib/libmapbox-gl.so"
  delete "${SYS_PATH:?}/lib/libvtm-jni.so"
  delete "${SYS_PATH:?}/lib/libconscrypt_gmscore_jni.so"
  delete "${SYS_PATH:?}/lib/libcronet".*."so"
  delete "${SYS_PATH:?}/lib/libgmscore.so"
fi

list_app_data_to_remove | while IFS='|' read -r FILENAME; do
  if test -z "${FILENAME}"; then continue; fi
  delete "${DATA_PATH:?}/data/${FILENAME}"
  delete "${DATA_PATH:?}"/user/*/"${FILENAME}"
  delete "${DATA_PATH:?}"/user_de/*/"${FILENAME}"
  delete "${INTERNAL_MEMORY_PATH}/Android/data/${FILENAME}"
done

delete "${DATA_PATH:?}"/backup/com.google.android.gms.backup.BackupTransportService

delete "${SYS_PATH}"/addon.d/*-microg.sh
delete "${SYS_PATH}"/addon.d/*-microg-*.sh
delete "${SYS_PATH}"/addon.d/*-unifiednlp.sh
delete "${SYS_PATH}"/addon.d/*-mapsapi.sh
delete "${SYS_PATH}"/addon.d/*-gapps.sh
delete "${SYS_PATH}"/addon.d/80-fdroid.sh
delete "${SYS_PATH}"/addon.d/69-AuroraServices.sh

delete "${SYS_PATH}"/etc/default-permissions/google-permissions.xml
delete "${SYS_PATH}"/etc/default-permissions/phonesky-permissions.xml
delete "${SYS_PATH}"/etc/default-permissions/contacts-calendar-sync.xml
delete "${SYS_PATH}"/etc/default-permissions/opengapps-permissions.xml
delete "${SYS_PATH}"/etc/default-permissions/unifiednlp-permissions.xml
delete "${SYS_PATH}"/etc/default-permissions/microg-permissions.xml
delete "${SYS_PATH}"/etc/default-permissions/permissions-com.google.android.gms.xml
delete "${SYS_PATH}"/etc/default-permissions/microg-*-permissions.xml

# Note: Since we don't delete all Google apps, deleting these xml files will likely cause a bootloop, so don't delete them
# ToDO: In the future, simply remove the parts related to the removed apps
#delete "${SYS_PATH}"/etc/permissions/privapp-permissions-google.xml
#delete "${SYS_PATH}"/etc/permissions/privapp-permissions-google-p.xml
#delete "${SYS_PATH}"/etc/permissions/privapp-permissions-google-se.xml

delete "${SYS_PATH}"/etc/permissions/features.xml
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
delete "${SYS_PATH}/etc/microg_device_profile.xml"

if test -e "${SYS_PATH:?}/etc/org.fdroid.fdroid"; then rmdir --ignore-fail-on-non-empty -- "${SYS_PATH:?}/etc/org.fdroid.fdroid" || true; fi

# Legacy file
delete "${SYS_PATH:?}/etc/zips/ug.prop"

if test -z "${IS_INCLUDED:?}"; then
  ui_debug 'Done.'
fi
