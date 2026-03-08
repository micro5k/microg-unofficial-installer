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

Prerequisites
=============

- An Android device or emulator running Android **2.2 or later**.
- A custom recovery (e.g., `TWRP <https://twrp.me/>`_) **or** root access.
- At least **100 MB** of free space on the system partition (actual requirements vary by device and selected options).

Download
========

You can find the stable releases here:

- `Stable - Full flavour <https://xdaforums.com/t/3432360/>`_
- `Stable - OSS flavour <https://github.com/micro5k/microg-unofficial-installer/releases/latest>`_

Instead if you want to try the nightly builds you can find them here:

- `Nightly - Full flavour <https://gitlab.com/micro5k/microg-unofficial-installer/-/jobs/artifacts/main/browse/output?job=build-job>`_
- `Nightly - OSS flavour <https://github.com/micro5k/microg-unofficial-installer/releases/tag/nightly>`_

**NOTE:** If you get the error "No space left on device", you can find a workaround here: `#138 <https://github.com/micro5k/microg-unofficial-installer/issues/138>`_

Installation
============

.. note::
   The methods below are **mutually exclusive** — choose **one** that matches your setup and follow only those steps.

.. tip::
   Regardless of which installation method you choose, you can pre-configure options before flashing by setting system properties on the device.
   For example, to enable a longer live setup timeout:

   .. code-block:: sh

      adb shell "setprop zip.microg-unofficial-installer.LIVE_SETUP_TIMEOUT 8"

Via custom recovery (e.g., TWRP)
--------------------------------

1. Transfer the flashable zip to your device's internal storage or microSD card.
2. Reboot into recovery (hold **Power + Volume Down** — exact key combination depends on your device).
3. In TWRP, tap **Install**, navigate to the zip file and select it.
4. Swipe to confirm the flash.
5. Follow the on-screen prompts for the live setup (e.g., choose which optional apps to install).
6. Once the flashing is complete, tap **Reboot → **System**.

Via ADB sideload
----------------

1. Reboot into recovery.
2. In TWRP, tap **Advanced** → **ADB Sideload**, then swipe to start.
3. On your PC, run:

   .. code-block:: sh

      adb sideload microg-unofficial-installer-*.zip

4. Once complete, reboot the device.

Via ``zip-install.sh`` (ADB or terminal, root required, no recovery needed)
---------------------------------------------------------------------------

This method installs the zip from a running Android system using ``zip-install.sh``.

1. Connect your device via USB with USB debugging enabled *(ADB only — skip if using a terminal app on the device)*.
2. Open a shell: run ``adb shell`` on the PC or open a **terminal app** directly on the device.
3. Transfer the flashable zip to your device's internal storage or microSD card.
4. Run:

   .. code-block:: sh

      cd /path/to/my_folder/
      unzip ./microg-unofficial-installer-*.zip zip-install.sh
      sh ./zip-install.sh ./microg-unofficial-installer-*.zip

   The script will flash the zip directly on the running system, without using the recovery.

5. Follow the on-screen prompts for the live setup (e.g., choose which optional apps to install).
6. Once complete, reboot the device.
