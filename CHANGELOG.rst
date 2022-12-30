..
   SPDX-FileCopyrightText: (c) 2016 ale5000
   SPDX-License-Identifier: GPL-3.0-or-later
   SPDX-FileType: DOCUMENTATION

=========
Changelog
=========

All notable changes to this project will be documented in this file.


`Unreleased`_
-------------
- Click above to see all the changes.

1.2.0-beta
----------
- Update Mozilla UnifiedNlp Backend to 1.5.0
- Grant the ACCESS_BACKGROUND_LOCATION permission to Mozilla UnifiedNlp Backend by default
- Improve temp folder handling
- Improve priv-app folder detection
- Add Android Auto 1.2.512930-stub (disabled by default, not tested)
- Improve GApps cleaning
- Auto mount / unmount extra partitions
- Install MinUtil script on the device (can be used from terminal if rooted or via ADB)
- Added function to reinstall packages as if they were installed from Play Store in the MinUtil script
- Added function to remove all accounts of the device in the MinUtil script
- Update NewPipe to 0.23.3
- Refactor some code, now most apps can be enabled/disabled directly in the Live setup
- Improve installation performance by verifying only the files that are really installed
- Preset microG settings
- Update FakeStore to 0.1.0
- Add back the F-Droid Privileged Extension
- Enable installation under API 8 although only F-Droid Privileged Extension is installed there
- Add NewPipe 0.24.0 for Android 5+ devices
- Update Android Auto stub to 1.2.520120-stub
- Improved uninstaller
- Vastly improve compatibility with legacy devices
- Add function to rescan media in the MinUtil script
- Update microG Service Core to 0.2.26.223616
- Update NewPipe to 0.24.1 for Android 5+ devices
- Add helper script (zip-install.sh) for the manual installation of the flashable zip via terminal or via ADB
- Add function to force GCM reconnection in the MinUtil script
- Remount /system to read-write if needed
- Add support for addon.d also on legacy Android versions

`1.1.0-beta`_ - 2022-04-28
--------------------------
- Improve Dalvik cache cleaning
- Fix the detection of system partition on some devices
- Rewritten architecture detection to improve compatibility
- Update NewPipe Legacy to 0.20.8
- Switch NewPipe from the F-Droid version to the official version
- Improved compatibility with various apps
- Remove microG DroidGuard Helper as it is no longer needed
- Update Déjà Vu Location Service to 1.1.12
- Update XML files for newer Android versions
- Update microG Service Core (VTM) to 0.2.13.203915-vtm
- Update microG Service Core (Mapbox) to 0.2.24.214816
- Remove apps that break GCM
- Improve location updates
- Insert the android.permission.ACCESS_BACKGROUND_LOCATION in XML files only if needed
- Zip builds are now reproducible (with Java 11 or later)
- Made some changes for future Magisk support
- You can now test the zip installation on PC using "gradlew installTest" (tested on Linux and Windows)
- Mount / unmount partitions only if they weren't already mounted
- Update NewPipe to 0.22.2
- Improve system partition mounting / unmounting
- Added support for Android up to 13

`1.0.34-beta`_ - 2019-07-07
---------------------------
- Rewritten the uninstaller
- Improved microG / GApps removal
- Only insert the fake signature permission in priv-app permissions whitelist if the ROM support it
- Added Play Store permissions to priv-app permissions whitelist
- Added option to reset GMS data of all apps
- Include the option to reset GMS data of all apps in live setup
- Improved sysconfig
- Properly uninstall Maps APIv1 on odexed ROMs
- Update microG Service Core for legacy devices to 0.2.6.13280
- Update microG Service Core to 0.2.8.17785-2-vtm-8a0010a
- Add the Mapbox version of microG GmsCore and make it default on supported devices
- Update Déjà Vu Location Service to 1.1.11
- Update NewPipe to 0.16.2
- Add NewPipe Legacy for legacy devices

`1.0.33-beta`_ - 2018-12-04
---------------------------
- Fixed architecture detection error on some recoveries
- Fixed empty ABI list on some recoveries
- Allow building through Gradle
- Added the possibility to build a zip with only open-source components
- Test the integrity of the generated zip after build

`1.0.32-beta`_ - 2018-11-01
---------------------------
- Updated microG Service Core to 0.2.6.13280
- Updated Déjà Vu Location Service to 1.1.9
- Switched to a custom build of microG DroidGuard Helper to fix SafetyNet Attestation
- Preset F-Droid repositories
- Updated NewPipe to 0.14.2
- Install default permissions xml files only if needed
- Install priv-app permissions whitelist on Android 8 and higher

`1.0.31-beta`_ - 2018-08-28
---------------------------
- Initial work regarding reproducible builds of the installer zip file
- Updated BusyBox for Android to 1.29.1-YDS-201807291348
- Added an option to skip the installation of NewPipe, ref #8
- Switched to using a 64-bit BusyBox on a 64-bit devices
- Switched to a more error proof method for creating the file list, ref: #9
- Check also armeabi-v7a in the CPU detection for BusyBox
- Switched from vendor/lib to system/lib for lib installation on old devices so it is easier to setup
- Updated microG Service Core to 0.2.5.12879

`1.0.30-alpha`_ - Unreleased
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

1.0.29-beta - 2018-04-11
------------------------
- Switched signing tool to zipsigner (thanks to `@topjohnwu <https://github.com/topjohnwu>`_)
- Highly improved debug logging
- Improved compatibility of the build script
- Check the presence of the ROM before installing
- Fixed error logging from the subshell
- Updated BusyBox for Android to 1.28.3-YDS-201804091805
- Updated BusyBox for Windows to 1.29.0-FRP-2121-ga316078ad (2018-04-09)
- Always grant network access to microG GmsCore
- Removed F-Droid Privileged Extension, it will be in a separate package in the future

1.0.28-alpha - Unreleased
-------------------------
- Improved debug logging
- Updated BusyBox for Android to 1.28.0-YDS-201801031253
- Updated BusyBox for Windows to 1.29.0-FRP-2001-gd9c5d3c61 (2018-03-27)
- Improved GApps / microG removal
- Added dalvik-cache cleaning
- Updated microG Service Core to 0.2.4-111
- Updated Déjà Vu Location Service to 1.1.5
- Updated NewPipe to 0.11.6

1.0.27-beta
-----------
- Updated microG Service Core to 0.2.4-108
- Updated Déjà Vu Location Service to 1.0.7
- Updated NewPipe to 0.11.4
- Updated permissions list
- Added removal of Baidu location service
- Improved removal of AMAP location service
- Improved GApps / microG removal
- Automatically create folders on the device if missing

1.0.26-alpha
------------
- Added NewPipe 0.11.1 (as replacement for YouTube)
- Automatically disable battery optimizations for microG GmsCore
- Updated Mozilla UnifiedNlp Backend to 1.3.3
- Updated Déjà Vu Location Service to 1.0.4
- Install Déjà Vu Location Service only on supported Android versions
- Almost fully rewritten the GApps / microG uninstaller
- Now it also clean app updates

1.0.24-alpha
------------
- Updated microG Service Core to 0.2.4-107

1.0.23-alpha
------------
- Added Déjà Vu Location Service 1.0.2
- Now the list of files to backup for the survival script are generated dynamically so all files are preserved in all cases
- Refactored code

1.0.22-beta
-----------
- Updated microG Service Core to 0.2.4-105
- Updated F-Droid Privileged Extension to 0.2.7
- Install recent market app on Android 5+
- Improved debug logging
- Allow to configure the live setup timeout
- Allow to configure the version of the market app to install

1.0.21-beta
-----------
- Added FakeStore 0.0.2
- Added support for live setup (currently limited to ARM phones)
- Added selection of the market app to install in the live setup
- Improved robustness

1.0.20-alpha
------------
- Added default permissions
- Reset permissions on dirty installations
- Remove conflicting location providers

1.0.19-alpha
------------
- Released sources on GitHub
- Changed signing process to fix a problem with Dingdong Recovery and maybe other old recoveries
- More consistency checks and improved error handling

1.0.18-alpha
------------
- Updated microG Service Core to 0.2.4-103
- Updated Nominatim Geocoder Backend to 1.2.2
- Switched BusyBox binaries to the `ones <https://forum.xda-developers.com/showthread.php?t=3348543>`_ compiled by @YashdSaraf (BusyBox is used only during the installation, nothing on the device is altered)
- Completely removed the disabler code for Play Store self update since it wasn't a clean method
- Improved the internal GApps remover
- GApps remover now also remove MIUI specific files

1.0.17-beta
-----------
- Downgraded microG Service Core to 0.2.4-81 on Android < 5 (workaround for bug `#379 <https://github.com/microg/GmsCore/issues/379>`_)
- Added a workaround for recoveries without /tmp
- Updated microG DroidGuard Helper to 0.1.0-10
- Updated F-Droid Privileged Extension to 0.2.5

1.0.16-alpha
------------
- Updated microG Service Core to 0.2.4-92
- Validate some return codes and show proper error if needed
- The lib folder is now created automatically if missing

1.0.15-pre-alpha
----------------
- Rewritten the update-binary as shell script to improve compatibility with all devices
- Updated F-Droid Privileged Extension to 0.2.4

1.0.14-alpha
------------
- Updated microG Service Core to 0.2.4-81
- file_getprop is no longer used
- Fixed support for system root image
- Minor changes

1.0.13-alpha
------------
- Added support for devices with system root image (untested)
- Updated F-Droid Privileged Extension to 0.2.2
- Switch the apk name of F-Droid Privileged Extension to the official one
- F-Droid Privileged Extension is now installed on all Android versions
- Minor changes

1.0.12-alpha
------------
- Added microG DroidGuard Helper 0.1.0-4
- Added more components to the survival script, not yet complete (only Android 5+)

1.0.11-alpha
------------
- Added a survival script (not complete)
- Updated microG Service Core to 0.2.4-79
- Updated Nominatim Geocoder Backend to 1.2.1

1.0.10-beta
-----------
- Reverted blocking of Play Store self update on Android 5+ since it is not reliable
- Updated microG Service Core to 0.2.4-64
- Updated Nominatim Geocoder Backend to 1.2.0
- Added F-Droid Privileged Extension 0.2 (only Android < 5)

1.0.9-beta
----------
- Play Store self update is now blocked on all Android versions
- Avoid possible problems that could happen if the Play Store was already updated before flashing the zip

1.0.8-beta
----------
- Play Store self update is now blocked (only Android 5+)

1.0.7-beta
----------
- Downgraded Google Play Store to 5.1.11 (this fix the crash when searching)

1.0.6-beta
----------
- Updated microG Service Core to 0.2.4-50
- Updated UnifiedNlp (legacy) to 1.6.8
- Added support for devices with x86_64 CPU (untested)

1.0.5-beta
----------
- Verify hash of extracted files before installing them
- Fixed installation of 64-bit libraries on old Android versions

1.0.4-alpha
-----------
- Total rewrite of the code for installing libraries
- Added support for 64-bit ARM
- Added UnifiedNlp (legacy) 1.6.7 (only for Android < 4.4)

1.0.3-alpha
-----------
- Major rewrite of the installation script to add support for newer Android versions (big thanks to `@JanJabko <https://forum.xda-developers.com/m/7275198/>`_ for the phone)
- Updated microG Service Core to 0.2.4-39
- Updated Google Play Store to 5.4.12
- Minimum API version back to 9

1.0.2-beta
----------
- Updated microG Service Core to 0.2.4-20
- Minimum API version bumped to 10

1.0.1-beta
----------
- Added support for x86
- Improved CPU detection
- Improved Android version checking
- Improved error reporting

1.0.0-alpha
-----------
- Initial release


.. _Unreleased: https://github.com/micro5k/microg-unofficial-installer/compare/v1.1.0-beta...HEAD
.. _1.1.0-beta: https://github.com/micro5k/microg-unofficial-installer/compare/v1.0.34-beta...v1.1.0-beta
.. _1.0.34-beta: https://github.com/micro5k/microg-unofficial-installer/compare/v1.0.33-beta...v1.0.34-beta
.. _1.0.33-beta: https://github.com/micro5k/microg-unofficial-installer/compare/v1.0.32-beta...v1.0.33-beta
.. _1.0.32-beta: https://github.com/micro5k/microg-unofficial-installer/compare/v1.0.31-beta...v1.0.32-beta
.. _1.0.31-beta: https://github.com/micro5k/microg-unofficial-installer/compare/fd8c10cf26d51a2cbdfa48f9cc17d8f69a3af8e6...v1.0.31-beta
.. _1.0.30-alpha: https://github.com/micro5k/microg-unofficial-installer/compare/v1.0.29-beta...fd8c10cf26d51a2cbdfa48f9cc17d8f69a3af8e6
