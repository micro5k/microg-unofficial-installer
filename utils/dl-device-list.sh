#!/usr/bin/env sh
# SPDX-FileCopyrightText: 2023 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later WITH LicenseRef-Archive-packaging-exception

# @name Certified Android devices list downloader
# @brief Download and re-encode the certified devices CSV.
# @description Fetches the official certified devices CSV, converts it from
# UTF-16LE to UTF-8 (or Windows-1252 for legacy compatibility), replaces
# non-ASCII quotation marks, and saves the result as data/device-list.csv.
# @author ale5000

# Get the latest version from here: https://github.com/micro5k/microg-unofficial-installer/tree/main/utils

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

# @section GLOBAL CONSTANTS ----
#region
readonly SCRIPT_NAME='Certified Android devices list downloader'
readonly SCRIPT_SHORTNAME='CertDevDl'
readonly SCRIPT_VERSION='0.1.6'
readonly SCRIPT_AUTHOR='ale5000'
readonly SCRIPT_YEAR='2023'

readonly EX_USAGE=64
readonly EX_UNAVAILABLE=69
readonly EX_TEMPFAIL=75
readonly EX_CONFIG=78

readonly WGET_CMD='wget'
readonly DL_UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0'
readonly DL_ACCEPT_HEADER='Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
readonly DL_ACCEPT_LANG_HEADER='Accept-Language: en-US,en;q=0.5'
#endregion

set -u 2> /dev/null || :
# shellcheck disable=SC3040 # IGNORE: In POSIX sh, set option pipefail is undefined
case "$(set -o 2> /dev/null || set || :)" in *'pipefail'*) set -o pipefail || echo 1>&2 'ERROR: pipefail failed' ;; *) echo 1>&2 'WARNING: pipefail not supported' ;; esac
# shellcheck disable=SC3040 # IGNORE: In POSIX sh, set option 'foo' is undefined
if test -f '/usr/bin/cygpath'; then
  # IMPORTANT: Double-clicking a script file on Windows opens Bash as an interactive shell and enables 'monitor', 'history' and 'histexpand' contrary to any logic
  set +o monitor || :
  (set +o history 2> /dev/null) && set +o history || :
  (set +o histexpand 2> /dev/null) && set +o histexpand || :
fi

# @section TERMINAL SETUP & LOGGING FUNCTIONS ----
#region
fix_posix_emulation_if_needed()
{
  # Workarounds for shells using Windows-POSIX emulation layers (e.g., Git Bash under Windows)
  if test -f '/usr/bin/cygpath'; then
    # Prioritize POSIX-emulated binaries over Windows natives to prevent hangs and obscure errors
    if test "${USR_BIN_FIXED:-0}" = '0'; then
      case "${PATH-}" in '/usr/bin:'*) ;; *) PATH="/usr/bin:${PATH:-/bin}" ;; esac
    fi

    # Resolve an issue where dragging and dropping a file onto the script inexplicably resets the
    #  working directory to 'C:\WINDOWS\system32'
    # shellcheck disable=SC3028 # IGNORE: In POSIX sh, BASH_SOURCE is undefined
    if test "$(/usr/bin/cygpath -m -- "${PWD:?}" || :)" = "$(/usr/bin/cygpath -m -S || :)" && test -n "${BASH_SOURCE-}"; then
      cd "${BASH_SOURCE:?}/.." || printf 1>&2 '%s\n' 'ERROR: Failed to set the correct working directory'
    fi
  fi
}

set_utf8_codepage()
{
  if command -v 'chcp.com' 1> /dev/null 2>&1 && PREVIOUS_CODEPAGE="$(chcp.com 2> /dev/null | cut -d ':' -f '2' -s | tr -d ' \r')" && test "${PREVIOUS_CODEPAGE}" -ne 65001; then
    'chcp.com' 1> /dev/null 65001 || return "${?}"
  else
    PREVIOUS_CODEPAGE=''
  fi
}

restore_codepage()
{
  if test -n "${PREVIOUS_CODEPAGE-}"; then
    'chcp.com' 1> /dev/null "${PREVIOUS_CODEPAGE:?}" || :
    PREVIOUS_CODEPAGE=''
  fi
}

color_init()
{
  CLR_RESET=''
  CLR_RED=''
  CLR_GREEN=''
  CLR_YELLOW_PLAIN=''
  CLR_YELLOW=''
  CLR_CYAN=''
  CLR_LINE=''

  # shellcheck disable=SC2034 # IGNORE: 'foo' appears unused
  if test -z "${NO_COLOR-}" && test -t 2; then
    CLR_RESET='\033[0m'
    CLR_RED='\033[1;31m'
    CLR_GREEN='\033[1;32m'
    CLR_YELLOW_PLAIN='\033[0;33m'
    CLR_YELLOW='\033[1;33m'
    CLR_CYAN='\033[1;36m'
    CLR_LINE='\r        \r'
  fi
}

log_scope_init()
{
  LOG_LEVEL=0
}

# shellcheck disable=SC2329 # NOTE: Standard boilerplate function; may not be executed in this specific script
log_scope_begin()
{
  LOG_LEVEL="$((LOG_LEVEL + 2))"
}

# shellcheck disable=SC2329 # NOTE: Standard boilerplate function; may not be executed in this specific script
log_scope_end()
{
  test "${LOG_LEVEL}" -lt 2 || LOG_LEVEL="$((LOG_LEVEL - 2))"
}

log_empty_line()
{
  printf '\n'
}

log_output()
{
  printf '%*s%s\n' "${LOG_LEVEL}" '' "${1}"
}

log_status()
{
  printf 1>&2 '%b%s%b\n' "${CLR_GREEN}" "${1}" "${CLR_RESET}"
}

log_warn()
{
  printf 1>&2 '%b%*s%s%b\n' "${CLR_YELLOW_PLAIN}" "${LOG_LEVEL}" '' "WARNING: ${1}" "${CLR_RESET}"
}

log_err()
{
  printf 1>&2 '\n%b%s%b\n' "${CLR_RED}" "ERROR: ${1}" "${CLR_RESET}"
}

init()
{
  fix_posix_emulation_if_needed
  color_init
  log_scope_init
}

pause_if_needed()
{
  # shellcheck disable=SC3028 # IGNORE: In POSIX sh, SHLVL is undefined
  if test "${no_pause:-0}" = '0' && test "${NO_PAUSE:-0}" = '0' && test "${SHLVL:-1}" = '1' && test -t 0 && test -t 1 && test -t 2 && test "${CI:-false}" = 'false' && test "${TERM_PROGRAM:-none}" != 'vscode'; then
    case "$-" in *s*) return "${1:-0}" ;; *) ;; esac
    printf 1>&2 '\n%b%s' "${CLR_GREEN-}${CLR_LINE-}" 'Press any key to exit... ' || :
    # shellcheck disable=SC3045 # IGNORE: In POSIX sh, read -s / -n is undefined
    IFS='' read 2> /dev/null 1>&2 -r -s -n1 _ || IFS='' read 1>&2 -r _ || :
    printf 1>&2 '\n%b' "${CLR_RESET-}${CLR_LINE-}" || :
  fi
  return "${1:-0}"
}
#endregion

# @section STORAGE & DIRECTORY FUNCTIONS ----
#region
resolve_data_dir()
{
  local __fn_path=''

  # shellcheck disable=SC3028,SC2128 # IGNORE: In POSIX sh, BASH_SOURCE is undefined / Expanding an array without an index only gives the first element
  if test -n "${UTILS_DATA_DIR-}" && __fn_path="${UTILS_DATA_DIR}"; then
    :
  elif test -n "${BASH_SOURCE-}" && test -f "${BASH_SOURCE}" && __fn_path="$(dirname "${BASH_SOURCE}")/data"; then
    : # NOTE: Index omitted intentionally; we explicitly want the first element only
  elif test -n "${0-}" && test -f "${0}" && __fn_path="$(dirname "${0}")/data"; then
    :
  elif __fn_path='./data'; then
    :
  else
    return 1
  fi

  __fn_path="$(realpath 2> /dev/null "${__fn_path:?}" || readlink -f "${__fn_path:?}")" || return 3
  printf '%s\n' "${__fn_path:?}"
}
#endregion

# @section CORE FUNCTIONS ----
#region
contains()
{
  case "${2?}" in
    *"${1:?}"*) return 0 ;; # Found
    *) ;;
  esac
  return 1 # NOT found
}

iconv_compat()
{
  local _input_file _output_file _status

  _input_file="${1:?}"
  _output_file="${2:?}"
  shift 2

  if contains 'GNU libiconv' "$(iconv --version 2> /dev/null | head -n 1 -q || true)"; then
    # Limited version, -o is NOT available
    if test "${_output_file:?}" = "${_input_file:?}"; then
      iconv "${@}" -- "${_input_file:?}" 1> "${_output_file:?}.compat-temp" || return "${?}"
      mv -f -T -- "${_output_file:?}.compat-temp" "${_output_file:?}" || return "${?}"
    else
      iconv "${@}" -- "${_input_file:?}" 1> "${_output_file:?}" || return "${?}"
    fi
  else
    # -o is available
    iconv -o "${_output_file:?}" "${@}" -- "${_input_file:?}" || return "${?}"
  fi
}

dl()
{
  "${WGET_CMD:?}" -q -t 1 -O "${2:?}" -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" --no-cache -- "${1:?}" || return "${?}"
}

dl_with_retry()
{
  local __fn_attempts_left="${MAX_ATTEMPTS:?}"

  while true; do
    rm -f -- "${2:?}" || return "${?}"
    if dl "${@}"; then return 0; fi

    __fn_attempts_left="$((__fn_attempts_left - 1))" || return "${?}"
    test "${__fn_attempts_left}" -gt 0 || break

    log_warn "Failed to download. Retrying in ${RETRY_DELAY?} seconds (attempts left: ${__fn_attempts_left?})..."
    sleep "${RETRY_DELAY:?}" || return "${?}"
  done

  rm -f -- "${2:?}" || :
  return 1
}

dl_and_convert_device_list()
{
  local _file

  _file="${DATA_DIR?}/device-list.csv"

  dl_with_retry 'https://storage.googleapis.com/play_public/supported_devices.csv' "${_file:?}-temp" || {
    log_err "Failed to download"
    return "${EX_TEMPFAIL?}"
  }

  iconv_compat "${_file:?}-temp" "${_file:?}-temp" -f 'UTF-16LE' -t 'UTF-8' || return "${?}"
  sed -i "s|\\\\'|'|g" "${_file:?}-temp" || return "${?}"

  if test "${ENABLE_UTF8}" = 'true'; then
    mv -f -T -- "${_file:?}-temp" "${_file:?}" || return "${?}"
  else
    iconv_compat "${_file:?}-temp" "${_file:?}" -c -f 'UTF-8' -t 'WINDOWS-1252//IGNORE' || return "${?}"
    rm -f -- "${_file:?}-temp" || return "${?}"
  fi
}
#endregion

# @section MAIN FUNCTION ----
#region
main()
{
  local status=0

  # BEGIN: Global config (overridable via env)
  export ENABLE_UTF8="${ENABLE_UTF8:-true}"
  export RETRY_DELAY="${RETRY_DELAY-}"     # Delay to wait after a failed request before a retry
  export MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}" # Maximum number of total attempts allowed (per download)
  # END: Global config

  if test -z "${RETRY_DELAY?}"; then
    if test "${CI:-false}" = 'false'; then RETRY_DELAY='5'; else RETRY_DELAY='15'; fi
  fi

  case "${RETRY_DELAY?}" in
    0 | *[!0-9]*)
      log_err "RETRY_DELAY must be a strictly positive integer, got: '${RETRY_DELAY?}'"
      return "${EX_USAGE?}"
      ;;
    *) ;;
  esac

  if test "${ENABLE_UTF8?}" = 'true'; then
    export LANG='C.UTF-8'
    set_utf8_codepage
  else
    export LANG='C'
  fi

  command -v "${WGET_CMD:?}" 1> /dev/null 2>&1 || {
    log_err 'wget is required'
    return "${EX_UNAVAILABLE?}"
  }

  if DATA_DIR="$(resolve_data_dir)" && mkdir -p -- "${DATA_DIR}"; then
    :
  else
    log_err 'Unable to create the required data directory'
    return "${EX_CONFIG?}"
  fi

  log_empty_line
  log_output 'Downloading...'
  log_scope_begin
  rm -f -- "${DATA_DIR:?}/device-list.csv" || return 20

  dl_and_convert_device_list || {
    status="${?}"
    return "${status?}"
  }

  log_scope_end
  log_output 'Done.'
}
#endregion

# @section CLI ARGUMENTS PARSING ----
#region
execute_script='true'
no_pause=0
STATUS=0

while test "$#" -gt 0; do
  case "${1?}" in
    -V | --version)
      execute_script='false'
      no_pause=1
      # REUSE-IgnoreStart
      printf '%s\n' "${SCRIPT_NAME:?}, version ${SCRIPT_VERSION:?}"
      printf '%s\n' "Copyright (C) ${SCRIPT_YEAR:?} ${SCRIPT_AUTHOR:?}"
      printf '%s\n\n' 'License GPLv3+ with APE.'
      printf '%s\n' 'There is NO WARRANTY, to the extent permitted by law.'
      # REUSE-IgnoreEnd
      ;;

    --no-pause)
      no_pause=1
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
      no_pause=1
      STATUS=2
      printf 1>&2 '%s\n' "${SCRIPT_SHORTNAME?}: unrecognized option '${1}'"
      ;;
    -*)
      execute_script='false'
      no_pause=1
      STATUS=2
      printf 1>&2 '%s\n' "${SCRIPT_SHORTNAME?}: invalid option -- '${1#-}'"
      ;;
    *) break ;;
  esac

  shift
done
#endregion

# @section EXECUTION ENTRY POINT ----
#region
if test "${execute_script:?}" = 'true'; then
  init
  log_status "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?} by ${SCRIPT_AUTHOR:?}"

  test "$#" -ne 0 || set -- ''
  main "${@}" || STATUS="${?}"
  restore_codepage
fi

pause_if_needed "${STATUS:?}"
exit "${?}"
#endregion
