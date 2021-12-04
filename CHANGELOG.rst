..
   SPDX-FileCopyrightText: Copyright (C) 2016-2019, 2021 ale5000
   SPDX-License-Identifer: GPL-3.0-or-later
   SPDX-FileType: DOCUMENTATION

=========
Changelog
=========

All notable changes to this project will be documented in this file.


`Dev`_ (Unreleased)
-------------------
- Click above to see all the changes.

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
- Switched signing tool to zipsigner (thanks @topjohnwu)
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


.. _Dev: https://github.com/micro5k/microg-unofficial-installer/compare/v1.0.32-beta...HEAD
.. _1.0.32: https://github.com/micro5k/microg-unofficial-installer/compare/v1.0.31-beta...v1.0.32-beta
.. _1.0.31: https://github.com/micro5k/microg-unofficial-installer/compare/fd8c10cf26d51a2cbdfa48f9cc17d8f69a3af8e6...v1.0.31-beta
.. _1.0.30: https://github.com/micro5k/microg-unofficial-installer/compare/v1.0.29-beta...fd8c10cf26d51a2cbdfa48f9cc17d8f69a3af8e6
