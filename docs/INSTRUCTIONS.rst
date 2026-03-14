############
Instructions
############
..
   SPDX-FileCopyrightText: (c) 2016 ale5000
   SPDX-License-Identifier: GPL-3.0-or-later
   SPDX-FileType: DOCUMENTATION

This package comes in 2 flavours:

- One is complete (Full).
- One include only open-source components (OSS).

You can `build it yourself <./BUILD.rst>`_ or download the prebuilt version.

.. contents:: Contents:
   :local:
   :depth: 2
   :backlinks: none


Prerequisites
=============

- An Android device or emulator running **Android 2.2 or later**.
- A custom recovery (see `Supported recoveries`_ below) or root access.
- At least **100 MB** of free space on the system partition (actual requirements vary by device and selected options).

Supported recoveries
--------------------

The following custom recoveries are supported:

- `TWRP <https://twrp.me/>`_ (Team Win Recovery Project)
- `OrangeFox Recovery <https://orangefox.download/>`_
- `PitchBlack Recovery Project (PBRP) <https://pitchblackrecovery.com/>`_
- `SKYHAWK Recovery Project (SHRP) <https://skyhawkrecovery.github.io/>`_
- `LineageOS Recovery <https://github.com/LineageOS/android_bootable_recovery>`_
- `ClockworkMod Recovery (CWM) <https://en.wikipedia.org/wiki/ClockworkMod>`_
- `PhilZ Touch Recovery <https://xdaforums.com/t/2015-10-09-cwm-6-0-5-1-philz-touch-6-59-0-libtouch_gui-1-42.2201860/>`_
- `Omni Recovery <https://github.com/omnirom/android_bootable_recovery>`_


.. _download:

Download
========

You can find the stable releases here:

- `Stable - Full flavour <https://xdaforums.com/t/3432360/>`_
- `Stable - OSS flavour <https://github.com/micro5k/microg-unofficial-installer/releases/latest>`_

Instead if you want to try the nightly builds you can find them here:

- `Nightly - Full flavour <https://gitlab.com/micro5k/microg-unofficial-installer/-/jobs/artifacts/main/browse/output?job=build-job>`_
- `Nightly - OSS flavour <https://github.com/micro5k/microg-unofficial-installer/releases/tag/nightly>`_

.. note::
   If you get the error "No space left on device", you can find a workaround in `Known issues <./KNOWN-ISSUES.rst#no-space-left-on-device>`_.

Verifying the download
----------------------

Each release ships with a ``.sha256`` file alongside the zip.
To verify the integrity of the downloaded file, run:

.. code-block:: sh

   sha256sum -c ./microg-unofficial-installer-*.zip.sha256

An ``OK`` result confirms the file is intact and unmodified.
The expected SHA-256 hash is also listed in the release notes for quick manual comparison.


Configure
=========

You can pre-configure options before flashing by setting system properties on the device.

All available options and their accepted values are listed in the ``setprop-settings-list.csv``
file bundled inside the zip.
Extract it and open it in any spreadsheet app or text editor to see everything that can be tuned.
*(There are more knobs than you'd expect. We're not sorry.)*

For example, to set a longer live setup timeout:

.. code-block:: sh

   adb shell "setprop zip.microg-unofficial-installer.LIVE_SETUP_TIMEOUT 8"

.. warning::
   Properties set via ``adb shell setprop`` are **temporary** and are lost on every reboot.
   If you set them and then reboot the device (e.g., to enter recovery), they will be gone
   before the installer ever reads them — making your configuration useless.
   Always set the properties **after** the device has booted into the state from which you
   will flash, and flash **immediately** afterwards without rebooting.


Installation
============

The methods below are **mutually exclusive**, choose **one** that matches your setup and follow only those steps.

Via custom recovery
-------------------

1. Transfer the flashable zip to your device's internal storage or microSD card.
2. Reboot into recovery (hold **Power + Volume Down** — exact key combination depends on your device).
3. In TWRP, tap **Install**, navigate to the zip file and select it.
4. Swipe to confirm the flash.
5. Follow the on-screen prompts for the live setup (e.g., choose which optional apps to install).
6. Once the flashing is complete, tap **Reboot** → **System**.

Via ADB sideload
----------------

1. Reboot into recovery.
2. In TWRP, tap **Advanced** → **ADB Sideload**, then swipe to start.
3. On your PC, run:

   .. code-block:: sh

      adb sideload microg-unofficial-installer-*.zip

4. Follow the on-screen prompts for the live setup (e.g., choose which optional apps to install).
5. Once the flashing is complete, reboot the device.

Via ``zip-install.sh`` (ADB or terminal, root required, no recovery needed)
---------------------------------------------------------------------------

This method installs the zip from a running Android system using ``zip-install.sh``.

1. Connect your device via USB with USB debugging enabled *(ADB only — skip if using a terminal app on the device)*.
2. Open a shell: run ``adb shell`` on the PC or open a **terminal app** directly on the device.
3. Transfer the flashable zip to your device's internal storage or microSD card.
4. Run:

   .. code-block:: sh

      cd <path/to/my_folder/>
      unzip ./microg-unofficial-installer-*.zip zip-install.sh
      sh ./zip-install.sh ./microg-unofficial-installer-*.zip

   The script will flash the zip directly on the running system, without using the recovery.

5. Follow the on-screen prompts for the live setup (e.g., choose which optional apps to install).
6. Once the flashing is complete, reboot the device.


Uninstallation
==============

To uninstall re-flash the zip, enable live setup and select **Uninstall**.
