..
   SPDX-FileCopyrightText: (c) 2016-2019, 2021 ale5000
   SPDX-License-Identifier: GPL-3.0-or-later
   SPDX-FileType: DOCUMENTATION

========
CONTENTS
========
.. |star| replace:: ⭐️
.. |fire| replace:: 🔥
.. |boom| replace:: 💥

Variants
--------

+------------------------------------------------------------------------------------------------------------+----------------------+---------------------------+
|                                                                                                            |    Updatable with    |         Signed by         |
|                                                Application                                                 +---------+------------+---------+-----------------+
|                                                                                                            | F-Droid | Play Store | F-Droid | Original author |
+============================================================================================================+=========+============+=========+=================+
| `FakeStore 0.0.2 <files/variants/FakeStore.apk>`_                                                          | |star|  |            |         |     |fire|      |
+------------------------------------------------------------------------------------------------------------+---------+------------+---------+-----------------+
| `Google Play Store 7.1.25.I-all <files/variants/PlayStore-recent.apk>`_ (137772785) - nodpi (Android >= 5) |         |   |star|   |         |     |fire|      |
+------------------------------------------------------------------------------------------------------------+---------+------------+---------+-----------------+
| `Google Play Store 5.1.11 <files/variants/PlayStore-legacy.apk>`_ (80310011) - nodpi (Android < 5)         |         |   |star|   |         |     |fire|      |
+------------------------------------------------------------------------------------------------------------+---------+------------+---------+-----------------+
| `microG Service Core 0.2.22.212658 <files/variants/priv-app/GmsCore-mapbox.apk>`_ (Android >= 4)           | |star|  |            |         |     |fire|      |
+------------------------------------------------------------------------------------------------------------+---------+------------+---------+-----------------+
| `microG Service Core 0.2.10.19420-vtm <files/variants/priv-app/GmsCore-vtm.apk>`_ (Android >= 4)           | |star|  |            |         |     |fire|      |
+------------------------------------------------------------------------------------------------------------+---------+------------+---------+-----------------+
| `microG Service Core 0.2.6.13280-vtm <files/variants/priv-app/GmsCore-vtm-legacy.apk>`_ (Android < 4)      | |star|  |            |         |     |fire|      |
+------------------------------------------------------------------------------------------------------------+---------+------------+---------+-----------------+
| `NewPipe 0.21.15 <files/variants/app/NewPipe.apk>`_ (Android >= 4.4)                                       | |star|  |            |         |     |fire|      |
+------------------------------------------------------------------------------------------------------------+---------+------------+---------+-----------------+
| `NewPipe Legacy 0.20.8 <files/variants/app/NewPipeLegacy.apk>`_ (Android < 4.4)                            | |star|  |            | |fire|  |                 |
+------------------------------------------------------------------------------------------------------------+---------+------------+---------+-----------------+


Common
------
- **files/priv-app/GoogleServicesFramework.apk** => microG Services Framework Proxy 0.1.0 |star| |fire|
- **files/priv-app/DroidGuard.apk** => microG DroidGuard Helper 0.1.2-dirty |boom|

- **files/app/DejaVuBackend.apk** => Déjà Vu Location Service 1.1.11 |star| |fire|
- **files/app/IchnaeaNlpBackend.apk** => Mozilla UnifiedNlp Backend 1.4.0 |star| |fire|
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
- BusyBox 1.29.1-YDS-201807291348 (compiled by `@YashdSaraf <https://github.com/yashdsaraf>`_) - Available `here <https://forum.xda-developers.com/showthread.php?t=3348543>`_.

|

|star| *Can be updated through F-Droid*.

|fire| *Original version*.

|boom| *Nanolx's version* (compiled and signed by `@Nanolx <https://github.com/Nanolx>`_).
