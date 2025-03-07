#!/usr/bin/env sh
# SPDX-FileCopyrightText: (c) 2025 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

export SCRIPT_NAME='Get signature'
export SCRIPT_VERSION='0.0.1'

"${APKSIGNER_PATH:-apksigner}" verify --min-sdk-version 24  -- "${1:?}" | grep -m 1 -F -e 'certificate SHA-256 digest' | cut -d ':' -f '2-' -s | tr -d -- ' ' | tr -- '[:lower:]' '[:upper:]' | sed -e 's/../&:/g;s/:$//'
