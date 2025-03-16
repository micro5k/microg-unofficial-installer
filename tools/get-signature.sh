#!/usr/bin/env sh
# SPDX-FileCopyrightText: (c) 2025 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

export SCRIPT_NAME='Get signature'
export SCRIPT_VERSION='0.0.2'

get_cert_sha256()
{
  local _cert_sha256

  if test -n "${APKSIGNER_PATH-}" || APKSIGNER_PATH="$(command -v 'apksigner')"; then
    _cert_sha256="$("${APKSIGNER_PATH:?}" verify --min-sdk-version 24 --print-certs -- "${1:?}" | grep -m 1 -F -e 'certificate SHA-256 digest:' | cut -d ':' -f '2-' -s | tr -d -- ' ' | tr -- '[:lower:]' '[:upper:]' | sed -e 's/../&:/g;s/:$//')" || _cert_sha256=''
  elif command 1> /dev/null -v 'keytool'; then
    _cert_sha256="$(keytool -printcert -jarfile "${1:?}" | grep -m 1 -F -e 'SHA256:' | cut -d ':' -f '2-' -s | tr -d -- ' ')" || _cert_sha256=''
  fi

  if test -n "${_cert_sha256?}"; then
    printf '%s\n' "sha256-cert-digest=\"${_cert_sha256:?}\""
  else
    return 1
  fi
}

get_cert_sha256 "${@}"
