#####################
Hook system for build
#####################

..
   SPDX-FileCopyrightText: 2026 ale5000
   SPDX-License-Identifier: GPL-3.0-or-later WITH LicenseRef-Archive-packaging-exception
   SPDX-FileType: DOCUMENTATION

This directory contains optional hooks to customize the build process. Each hook
must be a shell script named following the pattern: ``<hook_name>.hook.sh``.


How it works
============

If a hook script exists in this folder, the build script will source (include)
it at specific stages. Hooks run in the same shell environment as the main
script, so they have access to all variables (like ``${TEMP_DIR:?}``,
``${MODULE_VER:?}``, etc.).


Available hooks
===============

#. **pre_init** Triggered after core libraries are loaded and command-line
   parameters are parsed, but before loading configuration files. *Use case:*
   Override logic based on the selected ``${BUILD_TYPE:?}`` or modify early
   script flags before configurations are applied.

#. **post_init** Triggered after metadata extraction (ID, Version, Author) but
   before dependency checks. *Use case:* Dynamically modify the module version
   or add system requirements.

#. **pre_temp_create** Triggered before the temporary working directory is
   created.

#. **post_temp_create** Triggered once the temp directory is ready and cleared.

#. **pre_download** Triggered before starting any external file downloads (e.g.,
   via wget). *Use case:* Setup proxies, auth tokens, or custom download
   mirrors.

#. **pre_package** The last stage before compression. All files are ready in
   ``${TEMP_DIR:?}/zip-content``. *Use case:* Patching files, minifying assets,
   or injecting dynamic data.

#. **post_package** Triggered after the unsigned ZIP is created, but before the
   signing process. *Use case:* Run custom integrity checks on the raw archive.

#. **post_sign** Triggered after the ZIP has been signed and zipaligned. *Use
   case:* Generate extra checksums.

#. **on_finish** Triggered after cleanup and hash calculation, just before the
   script exits. *Use case:* Send notifications (Telegram/Discord) or upload to
   a remote server.


Guidelines
==========

-  **Extensions:** Files must end in ``.hook.sh``.
-  **Exit codes:** If a hook returns a non-zero exit code, the build process
   will be aborted immediately.
-  **Portability:** Write hooks in POSIX-compliant shell for maximum
   compatibility.


Example (pre_package.hook.sh)
=============================

.. code:: sh

   #!/usr/bin/env sh
   echo 'Adding custom timestamp to info.prop...'
   date '+%s' 1>> "${TEMP_DIR:?}/zip-content/info.prop"
