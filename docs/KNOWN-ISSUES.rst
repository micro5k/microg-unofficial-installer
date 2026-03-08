############
Known issues
############
..
   SPDX-FileCopyrightText: (c) 2026 ale5000
   SPDX-License-Identifier: GPL-3.0-or-later
   SPDX-FileType: DOCUMENTATION

This document lists the currently identified bugs, limitations, and performance issues within the project.
We are actively working on fixes; please check here before reporting a new issue.

.. contents:: Contents
   :local:
   :depth: 2
   :backlinks: none


Errors
======

No space left on device
-----------------------

Many devices do not have enough free space on the system partition to flash the ZIP.

Workaround
^^^^^^^^^^

Enable the ``LOW_FREE_SPACE`` option before flashing.
This installs an older (smaller) version of microG that fits on space-constrained devices.

.. code-block:: sh

   adb shell "setprop zip.microg-unofficial-installer.LOW_FREE_SPACE 1"

Then flash the ZIP as usual.

.. note::
   - This option is currently only available in **nightly builds**.
     Download the latest nightly from the `Download section <./INSTRUCTIONS.rst>`_.
   - microG can be updated to a newer version manually afterwards using **F-Droid**.
