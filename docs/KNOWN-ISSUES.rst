############
Known issues
############

..
   SPDX-FileCopyrightText: 2026 ale5000
   SPDX-License-Identifier: GPL-3.0-or-later WITH LicenseRef-Archive-packaging-exception
   SPDX-FileType: DOCUMENTATION

This document lists the currently identified bugs, limitations, and performance
issues within the project. We are actively working on fixes; please check here
before reporting a new issue.

.. contents:: Contents:
   :local:
   :depth: 2
   :backlinks: none


Errors
======

.. _no-space-left-on-device:

No space left on device
-----------------------

Many devices do not have enough free space on the system partition to flash the
ZIP.

.. admonition:: Workaround
   :class: hint

   |  Enable the ``LOW_FREE_SPACE`` option before flashing.
   |  This installs an older (smaller) version of microG that fits on
      space-constrained devices.

   Enable it with:

   .. code:: sh

      adb shell "setprop zip.microg-unofficial-installer.LOW_FREE_SPACE 1"

   Then flash the ZIP as usual.

.. note::

   -  This option is currently only available in **nightly builds**, you can
      download the latest nightly from the `download section
      <./INSTRUCTIONS.rst#download>`_.

   -  **microG** can be updated to a newer version manually afterwards using
      **F-Droid**.

.. _the-device-is-locked:

The device is locked!!!
-----------------------

.. _the-boot-loader-is-locked:

The boot loader is locked!!!
----------------------------

These errors are raised when the installer detects that the device or its boot
loader is locked, which would prevent a successful installation.

The detection relies on system properties and works correctly when the device is
booted into **recovery mode**. However, when the device is running the **normal
system**, certain ROMs or Magisk modules
may spoof a locked state even on an actually-unlocked device. In that specific
case the detection may report a false positive.

.. admonition:: Workaround
   :class: hint

   If you are certain that your device is unlocked and the error is a false
   positive caused by ROM or Magisk spoofing, you can bypass the check by
   setting ``BYPASS_LOCK_CHECK=1`` when installing via ``zip-install.sh``:

   .. code:: sh

      BYPASS_LOCK_CHECK=1 sh ./zip-install.sh ./microg-unofficial-installer-*.zip

.. warning::

   Only use this bypass when you are sure the device is genuinely unlocked.
   Installing on a truly locked device will fail and may leave the device in an
   inconsistent state.
