..
   SPDX-FileCopyrightText: (c) 2016 ale5000
   SPDX-License-Identifier: GPL-3.0-or-later
   SPDX-FileType: DOCUMENTATION

=========
Changelog
=========

All notable changes to this project will be documented in this file.


`Dev`_ (Unreleased)
-------------------
- Click above to see all the changes.

`1.1.0`_ beta (2022-04-28)
---------------------------
- Added support for Android up to 13
- Improve system partition mounting
- Mount partitions only if they aren't already mounted
- Zip builds are now reproducible (tested on Linux and Windows with Java 17)
- You can now test the zip installation on PC using "gradlew installTest" (tested on Linux and Windows)
Full changelog will appear later

`1.0.34`_ beta (2019-07-07)
---------------------------
Changelog will appear later

`1.0.33`_ beta (2018-12-04)
---------------------------
Changelog will appear later

`1.0.32`_ beta (2018-11-01)
---------------------------
- Added also a Bitcoin address for receiving donations
- Updated microG Service Core to 0.2.6.13280
- Updated Déjà Vu Location Service to 1.1.9
- Switched to a custom build of microG DroidGuard Helper to fix SafetyNet Attestation
- Preset F-Droid repositories
- Updated NewPipe to 0.14.2
- Install default permissions file only if needed
- Updated default permissions
- Install privapp permissions whitelist on Android 8 and higher
- Minor changes

`1.0.31`_ beta (2018-08-28)
---------------------------
- Initial work regarding reproducible builds of the installer zip file (untested)
- Updated BusyBox for Android to 1.29.1-YDS-201807291348
- Added an option to skip the installation of NewPipe, ref #8
- Switched to using a 64-bit BusyBox on a 64-bit device
- Switched to a more error proof method for creating the file list, ref: #9
- Check also armeabi-v7a in the CPU detection for BusyBox
- Switched from vendor/lib to system/lib so it is easier to setup
- Updated microG Service Core to 0.2.5.12879
- Minor changes

`1.0.30`_ alpha (Unreleased)
----------------------------
- Add support for building the installer under macOS (untested)
- Auto-grant signature spoofing permission to microG, thanks to @lazerl0rd
- Auto-grant signature spoofing permission also to FakeStore
- Updated zipsigner to 2.2
- Grant additional rights to microG GmsCore
- Declared support for Addon.d-v2
- Updated BusyBox for Windows to 1.30.0-FRP-2294-gf72845d93 (2018-07-25)
- Updated NewPipe to 0.13.7
- Updated Mozilla UnifiedNlp Backend to 1.4.0
- Updated Déjà Vu Location Service to 1.1.8
- Minor changes

1.0.29 beta (2018-04-11)
------------------------
- Switched signing tool to zipsigner (thanks `@topjohnwu <https://github.com/topjohnwu>`_)
- Highly improved debug logging
- Improved compatibility of the build script
- Check the presence of the ROM before installing
- Fixed error logging from the subshell
- Updated BusyBox for Android to 1.28.3-YDS-201804091805
- Updated BusyBox for Windows to 1.29.0-FRP-2121-ga316078ad (2018-04-09)
- Always grant network access to microG GmsCore
- Removed F-Droid Privileged Extension, it will be in a separate package in the future
- Minor changes and fixes

1.0.28 alpha (Unreleased)
-------------------------
- Improved debug logging
- Updated BusyBox for Android to 1.28.0-YDS-201801031253
- Updated BusyBox for Windows to 1.29.0-FRP-2001-gd9c5d3c61 (2018-03-27)
- Improved GApps / microG removal
- Added dalvik-cache cleaning
- No longer remove GooglePartnerSetup since some ROMs may need it
- Updated microG Service Core to 0.2.4-111
- Updated Déjà Vu Location Service to 1.1.5
- Updated NewPipe to 0.11.6
- Minor changes and fixes

1.0.27 beta
-----------
- Updated microG Service Core to 0.2.4-108
- Updated Déjà Vu Location Service to 1.0.7
- Updated NewPipe to 0.11.4
- Updated permissions list
- Added removal of Baidu location service
- Improved removal of AMAP location service
- Improved GApps / microG removal
- Automatically create folders on the device if missing
- Minor changes

1.0.26 alpha
------------
- Added NewPipe 0.11.1 (YouTube replacement)
- Automatically disable battery optimizations for microG GmsCore
- Updated Mozilla UnifiedNlp Backend to 1.3.3
- Updated Déjà Vu Location Service to 1.0.4
- Install Déjà Vu Location Service only on supported Android versions
- Almost fully rewritten the GApps / microG uninstaller
- Now it also clean app updates

1.0.24 alpha
------------
- Updated microG Service Core to 0.2.4-107

1.0.23 alpha
------------
- Added Déjà Vu Location Service 1.0.2
- Now the list of files to backup for the survival script are generated dynamically so all files are preserved in all cases
- Refactored code
- Many fixes and optimizations

1.0.22 beta
-----------
- Updated microG Service Core to 0.2.4-105
- Updated F-Droid Privileged Extension to 0.2.7
- Added Google Play Store 7.1.25.I-all
- Install recent Play Store on Android 5+
- Improved debug logging
- Allow to configure the live setup timeout
- Allow to configure the Play Store version to install
- Minor changes

1.0.21 beta
-----------
- Added FakeStore 0.0.2
- Added support for live setup (currently limited to ARM phones)
- Added selection of the market app to install in the live setup
- Improved robustness
- Various minor improvements

1.0.20 alpha
------------
- Added default permissions
- Reset permissions on dirty installations
- Remove conflicting location providers
- Other changes

1.0.19 alpha
------------
- Released sources on Github
- Changed signing process to fix a problem with Dingdong Recovery and maybe other old recoveries.
- More consistency checks and improved error handling
- Minor changes


.. _Dev: https://github.com/micro5k/microg-unofficial-installer/compare/v1.1.0-beta...HEAD
.. _1.1.0: https://github.com/micro5k/microg-unofficial-installer/compare/v1.0.34-beta...v1.1.0-beta
.. _1.0.34: https://github.com/micro5k/microg-unofficial-installer/compare/v1.0.33-beta...v1.0.34-beta
.. _1.0.33: https://github.com/micro5k/microg-unofficial-installer/compare/v1.0.32-beta...v1.0.33-beta
.. _1.0.32: https://github.com/micro5k/microg-unofficial-installer/compare/v1.0.31-beta...v1.0.32-beta
.. _1.0.31: https://github.com/micro5k/microg-unofficial-installer/compare/fd8c10cf26d51a2cbdfa48f9cc17d8f69a3af8e6...v1.0.31-beta
.. _1.0.30: https://github.com/micro5k/microg-unofficial-installer/compare/v1.0.29-beta...fd8c10cf26d51a2cbdfa48f9cc17d8f69a3af8e6
