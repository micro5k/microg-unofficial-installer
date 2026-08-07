#!/usr/bin/env sh
# SPDX-FileCopyrightText: NONE
# SPDX-License-Identifier: CC0-1.0

conf_lfs_get_mirror_by_sha256()
{
  case "${1?}" in
    '169a53df557e6577322e7cc8aa3389cb82b3d6408dd162433cc94f1d084a73d4')
      printf '%s\n' 'github.com/microg/GmsCore/releases/download/v0.3.16.252432/com.google.android.gms-252432032.apk'
      ;;
    '52597e77fd25fdd347574d0457ed1936a4b9561cf4c8d34e7ac8dd8191dfd4b9')
      printf '%s\n' 'github.com/microg/GmsCore/releases/download/v0.3.15.250932/com.google.android.gms-250932030.apk'
      ;;
    '740df4ca655fbdaf5fcb126638fe4ceca51f568ca072a5e543c83ebd3c2dc098')
      printf '%s\n' 'github.com/microg/GmsCore/releases/download/v0.3.14.250932/com.google.android.gms-250932028.apk'
      ;;
    '32eb051bee23caeff9dff9ea2f0c2e2de5dbc260daea7e9496a9cd1d7dd7ad77')
      printf '%s\n' 'github.com/microg/GmsCore/releases/download/v0.3.13.250932/com.google.android.gms-250932026.apk'
      ;;
    *)
      ui_nl
      # shellcheck disable=SC3028 # Ignore: In POSIX sh, FUNCNAME is undefined
      ui_error "Unknown hash => ${1?}" "${LINENO-}" "${FUNCNAME-}"
      ;;
  esac

  return 0
}
