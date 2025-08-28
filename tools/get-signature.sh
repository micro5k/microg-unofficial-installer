#!/usr/bin/env sh
# @name Find app signature
# @brief Find the signature of Android applications
# @author ale5000
# Get the latest version from here: https://github.com/micro5k/microg-unofficial-installer/tree/main/tools

# SPDX-FileCopyrightText: (c) 2025 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

readonly SCRIPT_NAME='Find app signature'
readonly SCRIPT_SHORTNAME='FindAppSign'
readonly SCRIPT_VERSION='0.1.0'
readonly SCRIPT_AUTHOR='ale5000'

pause_if_needed()
{
  # shellcheck disable=SC3028 # Ignore: In POSIX sh, SHLVL is undefined
  if test "${NO_PAUSE:-0}" = '0' && test "${no_pause:-0}" = '0' && test "${CI:-false}" = 'false' && test "${TERM_PROGRAM:-unknown}" != 'vscode' && test "${SHLVL:-1}" = '1' && test -t 0 && test -t 1 && test -t 2; then
    if test -n "${NO_COLOR-}"; then
      printf 1>&2 '\n%s' 'Press any key to exit... ' || :
    else
      printf 1>&2 '\n\033[1;32m\r%s' 'Press any key to exit... ' || :
    fi
    # shellcheck disable=SC3045 # Ignore: In POSIX sh, read -s / -n is undefined
    IFS='' read 2> /dev/null 1>&2 -r -s -n1 _ || IFS='' read 1>&2 -r _ || :
    printf 1>&2 '\n' || :
    test -n "${NO_COLOR-}" || printf 1>&2 '\033[0m\r    \r' || :
  fi
  unset no_pause || :
  return "${1:-0}"
}

show_status()
{
  printf 1>&2 '\033[1;32m%s\033[0m\n' "${1?}"
}

show_error()
{
  printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR: ${1?}"
}

get_cert_sha256()
{
  local _cert_sha256

  test -n "${1-}" || {
    show_error "You must pass the filename of the file to be processed."
    return 3
  }

  if : "${APKSIGNER_PATH:="$(command -v 'apksigner' || command -v 'apksigner.bat' || :)"}" && test -n "${APKSIGNER_PATH?}"; then
    _cert_sha256="$("${APKSIGNER_PATH:?}" verify --min-sdk-version 24 --print-certs -- "${1:?}" | grep -m 1 -F -e 'certificate SHA-256 digest:' | cut -d ':' -f '2-' -s | tr -d -- ' ' | tr -- '[:lower:]' '[:upper:]' | sed -e 's/../&:/g;s/:$//')" || return 4
  elif : "${KEYTOOL_PATH:="$(command -v 'keytool' || :)"}" && test -n "${KEYTOOL_PATH-}"; then
    _cert_sha256="$("${KEYTOOL_PATH:?}" -printcert -jarfile "${1:?}" | grep -m 1 -F -e 'SHA256:' | cut -d ':' -f '2-' -s | tr -d -- ' ')" || return 5
  else
    show_error "Neither apksigner nor keytool were found. You must set either APKSIGNER_PATH or KEYTOOL_PATH"
    return 255
  fi

  if test -n "${_cert_sha256?}"; then
    printf '%s\n' "sha256-cert-digest=\"${_cert_sha256:?}\""
  else
    return 1
  fi
}

main()
{
  get_cert_sha256 "${@}"
}

STATUS=0
execute_script='true'

while test "${#}" -gt 0; do
  case "${1?}" in
    -V | --version)
      printf '%s\n' "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?}"
      printf '%s\n' "Copyright (c) 2025 ${SCRIPT_AUTHOR:?}"
      printf '%s\n' 'License GPLv3+'
      execute_script='false'
      ;;

    --)
      shift
      break
      ;;

    --*)
      printf 1>&2 '%s\n' "${SCRIPT_SHORTNAME?}: unrecognized option '${1}'"
      execute_script='false'
      STATUS=2
      ;;

    -*)
      printf 1>&2 '%s\n' "${SCRIPT_SHORTNAME?}: invalid option -- '${1#-}'"
      execute_script='false'
      STATUS=2
      ;;

    *)
      break
      ;;
  esac

  shift
done

if test "${execute_script:?}" = 'true'; then
  show_status "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?} by ${SCRIPT_AUTHOR:?}"

  if test "${#}" -eq 0; then set -- ''; fi
  main "${@}"
  STATUS="${?}"
fi

pause_if_needed "${STATUS:?}"
exit "${?}"
