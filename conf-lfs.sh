#!/usr/bin/env sh
# SPDX-FileCopyrightText: NONE
# SPDX-License-Identifier: CC0-1.0

get_mirror_by_sha256()
{
  case "${1?}" in
    '32eb051bee23caeff9dff9ea2f0c2e2de5dbc260daea7e9496a9cd1d7dd7ad77') printf '%s\n' 'github.com/microg/GmsCore/releases/download/v0.3.13.250932/com.google.android.gms-250932026.apk' ;;
    *) ui_error "Unknown hash => ${1?}" ;;
  esac
}
