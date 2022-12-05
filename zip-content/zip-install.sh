#!/system/bin/sh
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

ZIPFILE="$(realpath ${1:?ERROR: You must specify the ZIP file to install})" || exit 1
SCRIPT_NAME="./update-binary-${RANDOM:?}.sh" || exit 2
unzip -pq "${ZIPFILE:?}" 'META-INF/com/google/android/update-binary' 1> "${SCRIPT_NAME:?}" || { printf 'ERROR: %s\n' 'Failed to extract update-binary'; exit 3; }
sh -- "${SCRIPT_NAME:?}" 3 1 "${ZIPFILE:?}" || { printf 'ERROR: %s\n' 'ZIP installation failed'; exit 4; }
rm -f -- "${SCRIPT_NAME:?}" || true
