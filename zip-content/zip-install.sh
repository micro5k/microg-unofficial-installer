#!/system/bin/sh
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

test -n "${1:-}" || { printf 'ERROR: %s\n' 'You must specify the ZIP file to install'; exit 1; }
ZIPFILE="$(realpath -- "${1:?}")" || ZIPFILE="$(readlink -f -- "${1:?}")" || exit 2
# shellcheck disable=SC3028
SCRIPT_NAME="./update-binary-${RANDOM:?}.sh" || exit 3
unzip -pq "${ZIPFILE:?}" 'META-INF/com/google/android/update-binary' 1> "${SCRIPT_NAME:?}" || { printf 'ERROR: %s\n' 'Failed to extract update-binary'; exit 4; }
sh -- "${SCRIPT_NAME:?}" 3 1 "${ZIPFILE:?}" || { printf 'ERROR: %s\n' 'ZIP installation failed'; exit 5; }
rm -f -- "${SCRIPT_NAME:?}" || true
