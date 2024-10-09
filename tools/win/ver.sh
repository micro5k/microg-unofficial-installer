#!/usr/bin/env sh

# SPDX-FileCopyrightText: (c) 2024 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck enable=all

if test "${1-}" = '-h' || test "${1-}" = '--help'; then set -- '/?'; fi
MSYS_NO_PATHCONV=1 "${COMSPEC:-${ComSpec:-cmd.exe}}" /c ver "${@}"
