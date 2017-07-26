#!/sbin/sh

if [[ -z "$INSTALLER" ]]; then
  ui_msg()
  {
    echo "$1"
  }

  ui_msg 'Uninstalling...'

  SYS_PATH='/system'
  PRIVAPP_PATH="${SYS_PATH}/app"
  if [[ -d "${SYS_PATH}/priv-app" ]]; then PRIVAPP_PATH="${SYS_PATH}/priv-app"; fi
fi

DELETE_LIST="
${PRIVAPP_PATH}/GmsCore/
${PRIVAPP_PATH}/GoogleLoginService/
${PRIVAPP_PATH}/GooglePartnerSetup/
${PRIVAPP_PATH}/GoogleServicesFramework/
${PRIVAPP_PATH}/GoogleFeedback/
${PRIVAPP_PATH}/Phonesky/
${PRIVAPP_PATH}/Vending/
${PRIVAPP_PATH}/NetworkLocation/

${PRIVAPP_PATH}/GmsCore.apk
${PRIVAPP_PATH}/GoogleLoginService.apk
${PRIVAPP_PATH}/GooglePartnerSetup.apk
${PRIVAPP_PATH}/GoogleServicesFramework.apk
${PRIVAPP_PATH}/GoogleFeedback.apk
${PRIVAPP_PATH}/Phonesky.apk
${PRIVAPP_PATH}/Vending.apk
${PRIVAPP_PATH}/NetworkLocation.apk

${SYS_PATH}/app/GsfProxy/
${SYS_PATH}/app/PlayGames/
${SYS_PATH}/app/YouTube/
${SYS_PATH}/app/LegacyNetworkLocation/

${SYS_PATH}/app/GsfProxy.apk
${SYS_PATH}/app/PlayGames.apk
${SYS_PATH}/app/YouTube.apk
${SYS_PATH}/app/LegacyNetworkLocation.apk

${SYS_PATH}/app/IchnaeaNlpBackend/
${SYS_PATH}/app/IchnaeaNlpBackend.apk

${SYS_PATH}/app/NominatimGeocoderBackend/
${SYS_PATH}/app/NominatimGeocoderBackend.apk
"

REMNANTS_LIST="
${PRIVAPP_PATH}/GoogleOneTimeInitializer/
${PRIVAPP_PATH}/GoogleOneTimeInitializer.apk
${PRIVAPP_PATH}/GsfProxy/
${PRIVAPP_PATH}/GsfProxy.apk
${PRIVAPP_PATH}/GmsCore_update/
${PRIVAPP_PATH}/GmsCore_update.apk
${PRIVAPP_PATH}/PrebuiltGmsCore/
${PRIVAPP_PATH}/PrebuiltGmsCore.apk
${PRIVAPP_PATH}/GmsCoreSetupPrebuilt/
${PRIVAPP_PATH}/GmsCoreSetupPrebuilt.apk
${PRIVAPP_PATH}/UnifiedNlp/
${PRIVAPP_PATH}/UnifiedNlp.apk
${PRIVAPP_PATH}/com.qualcomm.location/
${PRIVAPP_PATH}/com.qualcomm.location.apk
${PRIVAPP_PATH}/AMAPNetworkLocation/
${PRIVAPP_PATH}/AMAPNetworkLocation.apk
${PRIVAPP_PATH}/com.google.android.gms/
${PRIVAPP_PATH}/com.google.android.gms.apk
${PRIVAPP_PATH}/PlayStore/
${PRIVAPP_PATH}/PlayStore.apk
${PRIVAPP_PATH}/BlankStore/
${PRIVAPP_PATH}/BlankStore.apk
${PRIVAPP_PATH}/FakeStore/
${PRIVAPP_PATH}/FakeStore.apk
${PRIVAPP_PATH}/FDroidPrivileged/
${PRIVAPP_PATH}/FDroidPrivileged.apk
${PRIVAPP_PATH}/FDroidPriv/
${PRIVAPP_PATH}/FDroidPriv.apk
${PRIVAPP_PATH}/Velvet/
${PRIVAPP_PATH}/Velvet.apk

${SYS_PATH}/app/GoogleOneTimeInitializer/
${SYS_PATH}/app/GoogleOneTimeInitializer.apk
${SYS_PATH}/app/GsfProxy/
${SYS_PATH}/app/GsfProxy.apk
${SYS_PATH}/app/GmsCore_update/
${SYS_PATH}/app/GmsCore_update.apk
${SYS_PATH}/app/PrebuiltGmsCore/
${SYS_PATH}/app/PrebuiltGmsCore.apk
${SYS_PATH}/app/GmsCoreSetupPrebuilt/
${SYS_PATH}/app/GmsCoreSetupPrebuilt.apk
${SYS_PATH}/app/UnifiedNlp/
${SYS_PATH}/app/UnifiedNlp.apk
${SYS_PATH}/app/com.qualcomm.location/
${SYS_PATH}/app/com.qualcomm.location.apk
${SYS_PATH}/app/AMAPNetworkLocation/
${SYS_PATH}/app/AMAPNetworkLocation.apk
${SYS_PATH}/app/MarketUpdater.apk

${SYS_PATH}/etc/permissions/com.qualcomm.location.xml

${SYS_PATH}/addon.d/00-1-microg.sh
${SYS_PATH}/addon.d/1-microg.sh
${SYS_PATH}/addon.d/10-mapsapi.sh

${SYS_PATH}/app/WhisperPush.apk
"

rm -rf ${DELETE_LIST}  # Filenames cannot contain spaces
rm -rf ${REMNANTS_LIST}  # Filenames cannot contain spaces

if [[ -z "$INSTALLER" ]]; then
  ui_msg 'Done.'
fi
