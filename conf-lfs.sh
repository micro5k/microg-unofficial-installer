#!/usr/bin/env sh
# SPDX-FileCopyrightText: NONE
# SPDX-License-Identifier: CC0-1.0

get_mirror_by_sha1()
{
  case "${1?}" in
    '809707bac1ffbfd3f05861cde8f4bc718687c470') printf '%s\n' 'github.com/microg/GmsCore/releases/download/v0.3.13.250932/com.google.android.gms-250932026.apk' ;;
    *) ui_error "Unknown hash => ${1?}" ;;
  esac
}
