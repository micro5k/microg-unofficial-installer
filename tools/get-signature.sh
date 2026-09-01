#!/usr/bin/env sh
# SPDX-FileCopyrightText: 2025 ale5000
# SPDX-License-Identifier: Apache-2.0 OR GPL-3.0-or-later WITH LicenseRef-Archive-packaging-exception

# @name Android app signing certificate extractor
# @brief Extract and print the SHA-256 fingerprint of the signing certificate of an Android APK file.
# @description Given an APK file path, uses apksigner (preferred) or keytool
# as a fallback to retrieve the signing certificate's SHA-256 fingerprint
# and prints it in the form sha256-cert-digest="<value>".
# @author ale5000

# Get the latest version from here: https://github.com/micro5k/microg-unofficial-installer/tree/main/tools

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

# @section GLOBAL CONSTANTS ----
#region
readonly SCRIPT_NAME='Android app signing certificate extractor'
readonly SCRIPT_SHORTNAME='AppSignExt'
readonly SCRIPT_VERSION='0.1.7'
readonly SCRIPT_AUTHOR='ale5000'
readonly SCRIPT_YEAR='2025'
#endregion

set -u 2> /dev/null || :
# shellcheck disable=SC3040 # IGNORE: In POSIX sh, set option pipefail is undefined
case "$(set -o 2> /dev/null || set || :)" in *'pipefail'*) set -o pipefail || echo 1>&2 'ERROR: pipefail failed' ;; *) ;; esac

# @section UTILITY & UI FUNCTIONS ----
#region
show_status()
{
  printf 1>&2 '\033[1;32m%s\033[0m\n' "${1?}"
}

show_error()
{
  printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR: ${1?}"
}

fix_posix_emulation_if_needed()
{
  # Workarounds for shells using Windows-POSIX emulation layers (e.g., Git Bash under Windows)
  if test -f '/usr/bin/cygpath'; then
    # Prioritize POSIX-emulated binaries over Windows natives to prevent hangs and obscure errors
    if test "${USR_BIN_FIXED:-0}" = '0'; then
      case "${PATH-}" in '/usr/bin:'*) ;; *) PATH="/usr/bin:${PATH:-%empty}" ;; esac
    fi

    # Resolve an issue where dragging and dropping a file onto the script inexplicably resets the
    #  working directory to 'C:\WINDOWS\system32'
    # shellcheck disable=SC3028 # IGNORE: In POSIX sh, BASH_SOURCE is undefined
    if test "$(/usr/bin/cygpath -m -- "${PWD:?}" || :)" = "$(/usr/bin/cygpath -m -S || :)" && test -n "${BASH_SOURCE-}"; then
      cd "${BASH_SOURCE:?}/.." || printf '%s\n' 'ERROR: Failed to restore the correct working directory'
    fi
  fi
}

pause_if_needed()
{
  # shellcheck disable=SC3028 # Ignore: In POSIX sh, SHLVL is undefined
  if test "${NO_PAUSE:-0}" = '0' && test "${no_pause:-0}" = '0' && test "${CI:-false}" = 'false' && test "${TERM_PROGRAM:-none}" != 'vscode' && test "${SHLVL:-1}" = '1' && test -t 0 && test -t 1 && test -t 2; then
    if test -n "${NO_COLOR-}"; then
      printf 1>&2 '\n%s' 'Press any key to exit... ' || :
    else
      printf 1>&2 '\n\033[1;32m\r%s' 'Press any key to exit... ' || :
    fi
    # shellcheck disable=SC3045 # Ignore: In POSIX sh, read -s / -n is undefined
    IFS='' read 2> /dev/null 1>&2 -r -s -n1 _ || IFS='' read 1>&2 -r _ || :
    if test -n "${NO_COLOR-}"; then printf 1>&2 '\n' || :; else printf 1>&2 '\n\033[0m\r    \r' || :; fi
  fi
  unset no_pause
  return "${1:-0}"
}
#endregion

# @section CORE LOGIC & ANDROID SDK FUNCTIONS ----
#region
set_android_sdk_path_if_unset()
{
  test -z "${ANDROID_HOME-}" || return

  # Set the path of Android SDK if not already set
  if test -n "${LOCALAPPDATA-}" && test -d "${LOCALAPPDATA?}/Android/Sdk"; then
    ANDROID_HOME="${LOCALAPPDATA?}/Android/Sdk" # Windows
  elif test -n "${HOME-}" && test -d "${HOME?}/Library/Android/sdk"; then
    ANDROID_HOME="${HOME?}/Library/Android/sdk" # macOS
  elif test -n "${HOME-}" && test -d "${HOME?}/.local/share/android/sdk"; then
    ANDROID_HOME="${HOME?}/.local/share/android/sdk" # Linux (XDG)
  elif test -n "${HOME-}" && test -d "${HOME?}/Android/Sdk"; then
    ANDROID_HOME="${HOME?}/Android/Sdk" # Linux (Standard)
  elif test -d '/usr/lib/android-sdk'; then
    ANDROID_HOME='/usr/lib/android-sdk' # Linux (APT)
  fi
}

find_android_build_tool()
{
  local __fn_tool_path

  if __fn_tool_path="$(
    unalias "${1:?}" 2> /dev/null
    command 2> /dev/null -v "${1:?}"
  )" && test -n "${__fn_tool_path?}"; then
    :
  elif test -n "${ANDROID_HOME-}" && test -d "${ANDROID_HOME?}/build-tools" && __fn_tool_path="$(find "${ANDROID_HOME?}/build-tools" -maxdepth 2 -iname "${1:?}*" | sort -V -r | head -n 1)" && test -n "${__fn_tool_path?}"; then
    :
  else
    return 1
  fi

  printf '%s\n' "${__fn_tool_path:?}"
}

get_cert_sha256()
{
  local _cert_sha256

  if test -n "${APKSIGNER_PATH?}"; then
    _cert_sha256="$("${APKSIGNER_PATH?}" verify --min-sdk-version 24 --print-certs -- "${1:?}" | grep -m 1 -o -e 'certificate SHA-256 digest:.*' | cut -d ':' -f '2' -s | tr -d -- ' ' | tr -- '[:lower:]' '[:upper:]' | sed -e 's/../&:/g; s/:$//')" || return 4
  else
    _cert_sha256="$("${KEYTOOL_PATH:?}" -printcert -jarfile "${1:?}" | grep -m 1 -F -e 'SHA256:' | cut -d ':' -f '2-' -s | tr -d -- ' ')" || return 5
  fi

  if test -n "${_cert_sha256?}"; then
    printf '%s\n' "sha256-cert-digest=\"${_cert_sha256:?}\""
  else
    return 6
  fi
}
#endregion

# @section MAIN FUNCTION ----
#region
main()
{
  fix_posix_emulation_if_needed

  # BEGIN: Global config (overridable via env)
  export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  set_android_sdk_path_if_unset
  export APKSIGNER_PATH="${APKSIGNER_PATH:-$(find_android_build_tool 'apksigner' || command 2> /dev/null -v 'apksigner.bat' || :)}"
  export KEYTOOL_PATH="${KEYTOOL_PATH-}"
  # END: Global config

  test -n "${1-}" || {
    show_error 'You must pass the filename of the file to be processed'
    return 3
  }

  if test -n "${APKSIGNER_PATH?}"; then
    :
  elif test -n "${KEYTOOL_PATH?}" || KEYTOOL_PATH="$(command 2> /dev/null -v 'keytool')"; then
    :
  else
    show_error 'Neither apksigner nor keytool were found. You need to set either APKSIGNER_PATH or KEYTOOL_PATH'
    return 255
  fi

  get_cert_sha256 "${@}"
}
#endregion

# @section CLI ARGUMENTS PARSING (ENTRY POINT) ----
#region
execute_script='true'
STATUS=0

while test "$#" -gt 0; do
  case "${1?}" in
    -V | --version)
      execute_script='false'
      # REUSE-IgnoreStart
      printf '%s\n' "${SCRIPT_NAME:?}, version ${SCRIPT_VERSION:?}"
      printf '%s\n' "Copyright (C) ${SCRIPT_YEAR:?} ${SCRIPT_AUTHOR:?}"
      printf '%s\n\n' 'License Apache-2.0 or GPLv3+ with APE.'
      printf '%s\n' 'There is NO WARRANTY, to the extent permitted by law.'
      # REUSE-IgnoreEnd
      ;;

    -) # Read from STDIN (implies end of options)
      break
      ;;
    --) # End of options / Positional arguments follow
      shift
      break
      ;;
    --*)
      execute_script='false'
      STATUS=2
      printf 1>&2 '%s\n' "${SCRIPT_SHORTNAME?}: unrecognized option '${1}'"
      ;;
    -*)
      execute_script='false'
      STATUS=2
      printf 1>&2 '%s\n' "${SCRIPT_SHORTNAME?}: invalid option -- '${1#-}'"
      ;;
    *) break ;;
  esac

  shift
done
#endregion

# @section EXECUTION ----
#region
if test "${execute_script:?}" = 'true'; then
  show_status "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?} by ${SCRIPT_AUTHOR:?}"

  test "$#" -ne 0 || set -- ''
  main "${@}" || STATUS="${?}"
fi
#endregion

pause_if_needed "${STATUS:?}"
exit "${?}"
