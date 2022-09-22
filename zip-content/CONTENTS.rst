..
   SPDX-FileCopyrightText: (c) 2016 ale5000
   SPDX-License-Identifier: GPL-3.0-or-later
   SPDX-FileType: DOCUMENTATION

========
CONTENTS
========
.. |star| replace:: ⭐️
.. |fire| replace:: 🔥
.. |boom| replace:: 💥

Apps
----

+------------------------------------------------------------------------------------------------------------------+----------------------+---------------------------+
|                                                                                                                  |    Updatable with    |         Signed by         |
|                                                Application                                                       +---------+------------+---------+-----------------+
|                                                                                                                  | F-Droid | Play Store | F-Droid | Original author |
+==================================================================================================================+=========+============+=========+=================+
| `FakeStore 0.1.0 <files/system-apps/priv-app/FakeStore.apk>`_                                                    | |star|  |            |         |     |fire|      |
+------------------------------------------------------------------------------------------------------------------+---------+------------+---------+-----------------+
| [#]_ Google Play Store 7.1.25.I-all (137772785) - nodpi (Android >= 5)                                           |         |   |star|   |         |     |fire|      |
+------------------------------------------------------------------------------------------------------------------+---------+------------+---------+-----------------+
| [#]_ Google Play Store 5.1.11 (80310011) - nodpi (Android < 5)                                                   |         |   |star|   |         |     |fire|      |
+------------------------------------------------------------------------------------------------------------------+---------+------------+---------+-----------------+
| `microG Service Core 0.2.24.223315-36 (304c352) <files/system-apps/priv-app/GmsCore-mapbox.apk>`_ (Android >= 4) | |star|  |            |         |     |fire|      |
+------------------------------------------------------------------------------------------------------------------+---------+------------+---------+-----------------+
| `microG Service Core 0.2.13.203915-vtm <files/system-apps/priv-app/GmsCore-vtm.apk>`_ (Android >= 4)             | |star|  |            |         |     |fire|      |
+------------------------------------------------------------------------------------------------------------------+---------+------------+---------+-----------------+
| `microG Service Core 0.2.6.13280-vtm <files/system-apps/priv-app/GmsCore-vtm-legacy.apk>`_ (Android < 4)         |         |            |         |     |fire|      |
+------------------------------------------------------------------------------------------------------------------+---------+------------+---------+-----------------+
| `NewPipe 0.23.3 <files/system-apps/app/NewPipe.apk>`_ (Android >= 4.4)                                           | |star|  |            |         |     |fire|      |
+------------------------------------------------------------------------------------------------------------------+---------+------------+---------+-----------------+
| `NewPipe Legacy 0.20.8 <files/system-apps/app/NewPipeLegacy.apk>`_ (Android < 4.4)                               | |star|  |            | |fire|  |                 |
+------------------------------------------------------------------------------------------------------------------+---------+------------+---------+-----------------+
| [#]_ Android Auto 1.2.512930-stub (12512930) (Android >= 6)                                                      |         |   |star|   |         |     |fire|      |
+------------------------------------------------------------------------------------------------------------------+---------+------------+---------+-----------------+

.. [#] <files/system-apps/priv-app/PlayStore.apk>
.. [#] <files/system-apps/priv-app/PlayStoreLegacy.apk>
.. [#] <files/system-apps/priv-app/AndroidAuto.apk>


Common
------
- **files/priv-app/GoogleServicesFramework.apk** => microG Services Framework Proxy 0.1.0 |star| |fire|

- **files/app/DejaVuBackend.apk** => Déjà Vu Location Service 1.1.12 |star| |fire|
- **files/app/IchnaeaNlpBackend.apk** => Mozilla UnifiedNlp Backend 1.5.0 |star| |fire|
- **files/app/NominatimGeocoderBackend.apk** => Nominatim Geocoder Backend 1.2.2 |star| |fire|

- **files/framework/com.google.android.maps.jar** => microG Maps API v1 0.1.0 |fire|


Android < 4.4
-------------
- **files/app-legacy/LegacyNetworkLocation.apk** => UnifiedNlp (legacy) 1.6.8 |star| |fire|


Scripts
-------------
- microG / GApps removal script


Components used only during setup (not installed)
-------------------------------------------------
- BusyBox for Android (available `here <https://forum.xda-developers.com/showthread.php?t=3348543>`_) - See `here <misc/README.rst>`_ for more info

|

|star| *Can be updated through F-Droid*.

|fire| *Original version*.
