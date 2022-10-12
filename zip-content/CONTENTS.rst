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
.. |yes| replace:: ✔
.. |no| replace:: ✖
.. |red-no| replace:: ❌
.. |no-upd| replace:: 🙈


Apps
----

+---------------------------------------------------------------------------------------------------+---------------+----------------------+---------------------------+
|                                                                                                   |  Android ver. |    Updatable with    |         Signed by         |
|                                                Application                                        +-------+-------+---------+------------+---------+-----------------+
|                                                                                                   |  Min  |  Max  | F-Droid | Play Store | F-Droid | Original author |
+===================================================================================================+=======+=======+=========+============+=========+=================+
| `microG Service Core 0.2.6.13280-vtm <files/system-apps/priv-app/GmsCoreVtmLegacy.apk>`_          |  2.3  | 3.2.6 |         |    |no|    |         |     |fire|      |
+---------------------------------------------------------------------------------------------------+-------+-------+---------+------------+---------+-----------------+
| `microG Service Core 0.2.13.203915-vtm <files/system-apps/priv-app/GmsCoreVtm.apk>`_              |  4.0  |       |         |    |no|    |         |     |fire|      |
+---------------------------------------------------------------------------------------------------+-------+-------+---------+------------+---------+-----------------+
| `microG Service Core 0.2.24.223616-60 (6d0702f) <files/system-apps/priv-app/GmsCore-mapbox.apk>`_ |  4.0  |       |  |yes|  |    |no|    |         |     |fire|      |
+---------------------------------------------------------------------------------------------------+-------+-------+---------+------------+---------+-----------------+
| `microG Services Framework Proxy 0.1.0 <files/system-apps/priv-app/GoogleServicesFramework.apk>`_ | 2.3.3 |       |  |yes|  |    |no|    |         |     |fire|      |
+---------------------------------------------------------------------------------------------------+-------+-------+---------+------------+---------+-----------------+
| `FakeStore 0.1.0 <files/system-apps/priv-app/FakeStore.apk>`_                                     |  2.3  |       |  |yes|  |    |no|    |         |     |fire|      |
+---------------------------------------------------------------------------------------------------+-------+-------+---------+------------+---------+-----------------+
| `F-Droid Privileged Extension 0.2.13 <files/system-apps/priv-app/FDroidPrivilegedExtension.apk>`_ |  2.2  |       |  |yes|  |    |no|    | |fire|  |     |fire|      |
+---------------------------------------------------------------------------------------------------+-------+-------+---------+------------+---------+-----------------+
| `UnifiedNlp (legacy) 1.6.8 <files/system-apps/app/LegacyNetworkLocation.apk>`_                    |  2.3  | 4.3.1 |  |yes|  |    |no|    | |fire|  |                 |
+---------------------------------------------------------------------------------------------------+-------+-------+---------+------------+---------+-----------------+
| `NewPipe Legacy 0.20.8 <files/system-apps/app/NewPipeLegacy.apk>`_                                |  4.1  | 4.3.1 | |no-upd||    |no|    | |fire|  |                 |
+---------------------------------------------------------------------------------------------------+-------+-------+---------+------------+---------+-----------------+
| `NewPipe (old) 0.23.3 <files/system-apps/app/NewPipeOld.apk>`_                                    |  4.4  | 4.4.4 | |no-upd||    |no|    |  |fire| |                 |
+---------------------------------------------------------------------------------------------------+-------+-------+---------+------------+---------+-----------------+
| `NewPipe 0.24.0 <files/system-apps/app/NewPipe.apk>`_                                             |  5.0  |       |  |yes|  |    |no|    |         |     |fire|      |
+---------------------------------------------------------------------------------------------------+-------+-------+---------+------------+---------+-----------------+
| [#]_ Google Play Store 5.1.11 (80310011) - nodpi                                                  |  2.3  | 5.1.1 |  |no|   |    |yes|   |         |     |fire|      |
+---------------------------------------------------------------------------------------------------+-------+-------+---------+------------+---------+-----------------+
| [#]_ Google Play Store 7.1.25.I-all (137772785) - nodpi                                           |  6.0  |       |  |no|   |    |yes|   |         |     |fire|      |
+---------------------------------------------------------------------------------------------------+-------+-------+---------+------------+---------+-----------------+
| [#]_ Android Auto 1.2.520120-stub (12520120)                                                      |  6.0  |       |  |no|   |    |yes|   |         |     |fire|      |
+---------------------------------------------------------------------------------------------------+-------+-------+---------+------------+---------+-----------------+


Note
----
.. [#] <files/system-apps/priv-app/PlayStoreLegacy.apk>
.. [#] <files/system-apps/priv-app/PlayStore.apk>
.. [#] <files/system-apps/priv-app/AndroidAuto.apk>


Common
------
- **files/app/DejaVuBackend.apk** => Déjà Vu Location Service 1.1.12 |star| |fire|
- **files/app/IchnaeaNlpBackend.apk** => Mozilla UnifiedNlp Backend 1.5.0 |star| |fire|
- **files/app/NominatimGeocoderBackend.apk** => Nominatim Geocoder Backend 1.2.2 |star| |fire|

- **files/framework/com.google.android.maps.jar** => microG Maps API v1 0.1.0 |fire|


Scripts
-------------
- microG / GApps removal script


Components used only during setup (not installed)
-------------------------------------------------
- BusyBox for Android (available `here <https://forum.xda-developers.com/showthread.php?t=3348543>`_) - See `here <misc/README.rst>`_ for more info

|

|star| *Can be updated through F-Droid*.

|fire| *Original version*.
