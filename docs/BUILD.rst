###########################
Build the flashable OTA zip
###########################
..
   SPDX-FileCopyrightText: (c) 2026 ale5000
   SPDX-License-Identifier: GPL-3.0-or-later
   SPDX-FileType: DOCUMENTATION

.. contents:: Build methods:
   :local:
   :depth: 1
   :backlinks: none


make / pdpmake
==============

Full flavour
------------

Includes all components (proprietary and open-source):

.. code-block:: sh

   make buildota

Open-source flavour
-------------------

Includes only open-source components:

.. code-block:: sh

   make buildotaoss

Test the build
--------------

Emulates an Android recovery on the PC and runs the produced zip inside it:

.. code-block:: sh

   make test

.. note::
   Run ``buildota`` or ``buildotaoss`` first so that the zip exists in the ``output/`` folder.


`Gradle wrapper <https://docs.gradle.org/current/userguide/gradle_wrapper.html>`_
=================================================================================

Full flavour
------------

Includes all components (proprietary and open-source):

.. code-block:: sh

   ./gradlew buildOta

Open-source flavour
-------------------

Includes only open-source components:

.. code-block:: sh

   ./gradlew buildOtaOSS

Test the build
--------------

Emulates an Android recovery on the PC and runs the produced zip inside it:

.. code-block:: sh

   ./gradlew installTest

.. note::
   Run ``buildOta`` or ``buildOtaOSS`` first so that the zip exists in the ``output/`` folder.


`VS Code <https://code.visualstudio.com/>`_
===========================================

Full flavour
------------

Includes all components (proprietary and open-source):

Open the project in VS Code and run the ``buildOta`` task.

Open-source flavour
-------------------

Includes only open-source components:

Open the project in VS Code and run the ``buildOtaOSS`` task.

Test the build
--------------

Emulates an Android recovery on the PC and runs the produced zip inside it:

Open the project in VS Code and run the ``installTest`` task.

.. note::
   Run ``buildOta`` or ``buildOtaOSS`` first so that the zip exists in the ``output/`` folder.
