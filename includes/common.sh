#!/usr/bin/env sh

# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

if test "${A5K_FUNCTIONS_INCLUDED:-false}" = 'false'; then readonly A5K_FUNCTIONS_INCLUDED='true'; fi

export LANG='en_US.UTF-8'
export TZ='UTC'

unset LANGUAGE
unset LC_CTYPE
unset LC_MESSAGES
unset UNZIP
unset UNZIPOPT
unset UNZIP_OPTS
unset ZIP
unset ZIPOPT
unset ZIP_OPTS
unset ZIPINFO
unset ZIPINFOOPT
unset ZIPINFO_OPTS
unset JAVA_OPTS
unset JAVA_TOOL_OPTIONS
unset _JAVA_OPTIONS
unset CDPATH

readonly NL='
'

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

beep()
{
  if test "${CI:-false}" = 'false' && test "${TERM_PROGRAM-}" != 'vscode' && test "${APP_BASE_NAME-}" != 'gradlew' && test -t 2; then
    printf 1>&2 '%b' '\007' || true
  fi
}

ui_error()
{
  echo 1>&2 "ERROR: $1"
  pause_if_needed 0
  restore_saved_title_if_exist
  test -n "${2-}" && exit "$2"
  exit 1
}

ui_error_msg()
{
  printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR: ${1?}"
}

ui_warning()
{
  printf 1>&2 '\033[0;33m%s\033[0m\n' "WARNING: ${1:?}"
}

ui_debug()
{
  printf 1>&2 '%s\n' "${1?}"
}

export DL_DEBUG="${DL_DEBUG:-false}"
export http_proxy="${http_proxy-}"
export ftp_proxy="${ftp_proxy-}"

if test "${CI:-false}" != 'false' && test "${CI_DEBUG_TRACE:-${RUNNER_DEBUG:-false}}" != 'false'; then DL_DEBUG='true'; fi # GitLab / GitHub

# shellcheck disable=SC2034
{
  readonly WGET_CMD='wget'
  readonly DL_UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0'
  readonly DL_ACCEPT_HEADER='Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
  readonly DL_ACCEPT_ALL_HEADER='Accept: */*'
  readonly DL_ACCEPT_LANG_HEADER='Accept-Language: en-US,en;q=0.5'
  readonly DL_DNT_HEADER='DNT: 1'
  readonly DL_PROT='https://'
}

get_shell_exe()
{
  local _gse_shell_exe _gse_tmp_var

  if _gse_shell_exe="$(readlink 2> /dev/null "/proc/${$}/exe")" && test -n "${_gse_shell_exe}"; then
    # On Linux / Android / Windows (on Windows only some shells support it)
    printf '%s\n' "${_gse_shell_exe}"
    return 0
  elif _gse_tmp_var="$(ps 2> /dev/null -p "${$}" -o 'comm=')" && test -n "${_gse_tmp_var}" && _gse_tmp_var="$(command 2> /dev/null -v "${_gse_tmp_var}")"; then
    # On Linux / macOS
    # shellcheck disable=SC2230 # Ignore: 'which' is non-standard
    case "${_gse_tmp_var}" in *'/'* | *"\\"*) ;; *) _gse_tmp_var="$(which 2> /dev/null "${_gse_tmp_var}")" || return 3 ;; esac # We may not get the full path with "command -v" on some old versions of Oils
  elif _gse_tmp_var="${BASH:-${SHELL-}}" && test -n "${_gse_tmp_var}"; then
    if test "${_gse_tmp_var}" = '/bin/sh' && test "$(uname 2> /dev/null || :)" = 'Windows_NT'; then _gse_tmp_var="$(command 2> /dev/null -v 'busybox')" || return 2; fi
    if test ! -x "${_gse_tmp_var}" && test -x "${_gse_tmp_var}.exe"; then _gse_tmp_var="${_gse_tmp_var}.exe"; fi # Special fix for broken versions of Bash under Windows
  else
    return 1
  fi

  _gse_shell_exe="$(readlink 2> /dev/null -f "${_gse_tmp_var}" || realpath 2> /dev/null "${_gse_tmp_var}")" || _gse_shell_exe="${_gse_tmp_var}"
  printf '%s\n' "${_gse_shell_exe}"
  return 0
}

detect_os_and_other_things()
{
  if test -n "${PLATFORM-}" && test -n "${IS_BUSYBOX-}" && test -n "${PATHSEP-}"; then
    readonly PLATFORM IS_BUSYBOX PATHSEP CYGPATH SHELL_EXE SHELL_APPLET
    return 0
  fi

  PLATFORM="$(uname | tr -- '[:upper:]' '[:lower:]' || :)"
  IS_BUSYBOX='false'
  PATHSEP=':'
  CYGPATH=''
  SHELL_EXE=''
  SHELL_APPLET=''

  case "${PLATFORM?}" in
    'linux') ;;   # Returned by both Linux and Android, Android will be identified later in the function
    'android') ;; # Currently never returned by Android
    'windows_nt') # BusyBox-w32 on Windows => Windows_NT
      PLATFORM='win'
      IS_BUSYBOX='true'
      ;;
    'msys_'* | 'cygwin_'* | 'mingw32_'* | 'mingw64_'*) PLATFORM='win' ;;
    'windows'*) PLATFORM='win' ;; # Unknown shell on Windows
    'darwin') PLATFORM='macos' ;;
    'freebsd') ;;
    '') PLATFORM='unknown' ;;

    *)
      # Output of uname -o:
      # - MinGW => Msys
      # - MSYS => Msys
      # - Cygwin => Cygwin
      # - BusyBox-w32 => MS/Windows
      case "$(uname 2> /dev/null -o | tr -- '[:upper:]' '[:lower:]')" in
        'ms/windows')
          PLATFORM='win'
          IS_BUSYBOX='true'
          ;;
        'msys' | 'cygwin') PLATFORM='win' ;;
        *) PLATFORM="$(printf '%s\n' "${PLATFORM:?}" | tr -d ':;\\/')" || ui_error 'Failed to find platform' ;;
      esac
      ;;
  esac

  if test "${PLATFORM?}" = 'linux'; then
    # Android identify itself as Linux
    case "$(uname 2> /dev/null -a | tr -- '[:upper:]' '[:lower:]')" in
      *' android'* | *'-lineage-'* | *'-leapdroid-'*) PLATFORM='android' ;;
      *) ;;
    esac
  fi

  if test -n "${__SHELL_EXE-}" && test "${__SHELL_EXE:?}" != 'bash' && SHELL_EXE="${__SHELL_EXE:?}"; then
    :
  elif SHELL_EXE="$(get_shell_exe)" && test -n "${SHELL_EXE?}"; then
    :
  else
    ui_error 'Shell not found'
  fi
  unset __SHELL_EXE

  if test "${PLATFORM:?}" = 'win'; then
    if test "${IS_BUSYBOX:?}" = 'true'; then
      PATHSEP=';'
      SHELL_APPLET="${0:-ash}"
    else
      if CYGPATH="$(PATH="/usr/bin${PATHSEP:?}${PATH-}" command -v cygpath)"; then
        SHELL_EXE="$("${CYGPATH:?}" -m -a -l -- "${SHELL_EXE:?}")" || ui_error 'Unable to convert the path of the shell'
      else
        CYGPATH=''
      fi
    fi
  fi

  if test "${SHELL_EXE:?}" = 'bash'; then ui_error 'Shell executable must have the full path'; fi

  readonly PLATFORM IS_BUSYBOX PATHSEP CYGPATH SHELL_EXE SHELL_APPLET
}

set_title()
{
  test "${NO_TITLE:-0}" = '0' || return 0
  test "${CI:-false}" = 'false' || return 0
  test -t 2 || return 0

  A5K_TITLE_IS_DEFAULT='false'
  A5K_LAST_TITLE="${1:?}"
  printf 1>&2 '\033]0;%s - %s\007\r' "${1:?}" "${MODULE_NAME:?}" && printf 1>&2 '    %*s   %*s \r' "${#1}" '' "${#MODULE_NAME}" ''
}

set_default_title()
{
  if is_root; then
    set_title "[root] Command-line: ${__TITLE_CMD_PREFIX-}${__TITLE_CMD_0-}${__TITLE_CMD_PARAMS-}"
  else
    set_title "Command-line: ${__TITLE_CMD_PREFIX-}${__TITLE_CMD_0-}${__TITLE_CMD_PARAMS-}"
  fi
  A5K_TITLE_IS_DEFAULT='true'
}

save_last_title()
{
  if test "${A5K_TITLE_IS_DEFAULT-}" = 'true'; then
    A5K_SAVED_TITLE='default'
  else
    A5K_SAVED_TITLE="${A5K_LAST_TITLE-}"
  fi
}

restore_saved_title_if_exist()
{
  if test "${A5K_SAVED_TITLE-}" = 'default'; then
    set_default_title
  elif test -n "${A5K_SAVED_TITLE-}"; then
    set_title "${A5K_SAVED_TITLE:?}"
  fi
  A5K_SAVED_TITLE=''
}

__update_title_and_ps1()
{
  local _title
  # shellcheck disable=SC3028 # Ignore: In POSIX sh, SHLVL is undefined
  _title="Command-line: ${__TITLE_CMD_PREFIX-}$(basename 2> /dev/null "${0:--}" || printf '%s' "${0:--}" || :)$(test "${#}" -eq 0 || printf ' "%s"' "${@}" || :) (${SHLVL-}) - ${MODULE_NAME-}"
  PS1="${__DEFAULT_PS1-}"

  if is_root; then
    _title="[root] ${_title}"
    test -z "${__DEFAULT_PS1_AS_ROOT-}" || PS1="${__DEFAULT_PS1_AS_ROOT-}"
  fi

  test "${NO_TITLE:-0}" = '0' || return 0
  test "${A5K_TITLE_IS_DEFAULT-}" = 'true' || return 0
  test -t 2 || return 0
  printf 1>&2 '\033]0;%s\007\r' "${_title}" && printf 1>&2 '    %*s \r' "${#_title}" ''
}

simple_get_prop()
{
  grep -m 1 -F -e "${1:?}=" "${2:?}" | cut -d '=' -f 2
}

get_base_url()
{
  printf '%s\n' "${1:?}" | cut -d '/' -f '-3' -s
}

get_domain_from_url()
{
  printf '%s\n' "${1:?}" | cut -d '/' -f '3' -s
}

get_second_level_domain_from_url()
{
  printf '%s\n' "${1:?}" | cut -d '/' -f '3' -s | rev | cut -d '.' -f '-2' -s | rev
}

clear_dl_temp_dir()
{
  rm -f -r "${MAIN_DIR:?}/cache/temp"
}

_clear_cookies()
{
  rm -f -r "${MAIN_DIR:?}/cache/temp/cookies"
}

_parse_and_store_cookie()
{
  local IFS _line_no _cookie_file _elem _psc_cookie_name _psc_cookie_val

  test -d "${MAIN_DIR:?}/cache/temp/cookies" || mkdir -p "${MAIN_DIR:?}/cache/temp/cookies" || return "${?}"

  if test "${DL_DEBUG:?}" = 'true'; then
    printf '%s\n' "Set-Cookie: ${2:?}" 1>> "${MAIN_DIR:?}/cache/temp/cookies/${1:?}.dat.debug"
  fi

  _cookie_file="${MAIN_DIR:?}/cache/temp/cookies/${1:?}.dat"

  IFS=';'
  for _elem in ${2:?}; do
    _elem="${_elem# }"
    _psc_cookie_name="${_elem%%=*}"
    case "${_elem}" in
      *'='*) _psc_cookie_val="${_elem#*=}" ;;
      *) _psc_cookie_val='' ;;
    esac

    if test -n "${_psc_cookie_name?}"; then
      if test -e "${_cookie_file:?}" && _line_no="$(grep -n -F -m 1 -e "${_psc_cookie_name:?}=" -- "${_cookie_file:?}")" && _line_no="$(printf '%s\n' "${_line_no?}" | cut -d ':' -f '1' -s)" && test -n "${_line_no?}"; then
        sed -i -e "${_line_no:?}d" -- "${_cookie_file:?}" || return "${?}"
      fi
      printf '%s\n' "${_psc_cookie_name:?}=${_psc_cookie_val?}" 1>> "${_cookie_file:?}" || return "${?}"
    fi
    break
  done || return "${?}"
}

_parse_and_store_all_cookies()
{
  grep -e '^\s*Set-Cookie:' | cut -d ':' -f '2-' -s | while IFS='' read -r cookie_line; do
    if test -z "${cookie_line?}"; then continue; fi
    _parse_and_store_cookie "${1:?}" "${cookie_line:?}" || return "${?}"
  done

  if test "${DL_DEBUG:?}" = 'true'; then
    if test -d "${MAIN_DIR:?}/cache/temp/cookies"; then printf '\n' 1>> "${MAIN_DIR:?}/cache/temp/cookies/${1:?}.dat.debug"; fi
  fi
}

_load_cookies()
{
  local _domain _cookie_file

  _domain="$(get_domain_from_url "${1:?}")" || return 1
  _cookie_file="${MAIN_DIR:?}/cache/temp/cookies/${_domain:?}.dat"

  if test -f "${_cookie_file:?}"; then
    : # OK
  else
    _domain="$(get_second_level_domain_from_url "${1:?}")" || return 2
    _cookie_file="${MAIN_DIR:?}/cache/temp/cookies/${_domain:?}.dat"
    test -f "${_cookie_file:?}" || return 0
  fi

  while IFS='=' read -r name val; do
    test -n "${name?}" || continue
    printf '%s; ' "${name:?}=${val?}"
  done 0< "${_cookie_file:?}" || return 3

  return 0
}

verify_sha1()
{
  local file_name="$1"
  local hash="$2"
  local file_hash

  if test ! -f "${file_name}"; then return 1; fi # Failed
  file_hash="$(sha1sum "${file_name}" | cut -d ' ' -f 1)"
  if test -z "${file_hash}" || test "${hash}" != "${file_hash}"; then return 1; fi # Failed
  return 0                                                                         # Success
}

corrupted_file()
{
  rm -f -- "$1" || echo 'Failed to remove the corrupted file.'
  ui_error "The file '$1' is corrupted."
}

_get_byte_length()
{
  local LC_ALL
  export LC_ALL=C
  printf '%s\n' "${#1}"
}

_dl_validate_exit_code()
{
  test "${DL_DEBUG:?}" = 'false' || ui_debug "${1?} exit code: ${2?}"
  test "${2:?}" -lt 10 || return 10
  return "${2:?}"
}

_dl_validate_status_code_from_header_file()
{
  local _status_code

  _status_code="$(head -n 1 -- "${1:?}" | grep -o -e 'HTTP/[0-9].*' | cut -d ' ' -f '2' -s)" || _status_code=0
  test "${DL_DEBUG:?}" != 'true' || ui_debug "Status code: ${_status_code?}"

  case "${_status_code?}" in
    2*) return 0 ;;    # Successful responses like "200 OK" => good
    3*) return 30 ;;   # Various types of redirects => follow them
    404) return 144 ;; # 404 Not Found (the file was deleted) => skip only current file
    403) return 43 ;;  # 403 Forbidden (the server is refusing us) => do NOT try to use the same server again
    5*) return 50 ;;   # Various types of server errors => do NOT try to use the same server again
    *) ;;
  esac

  return 99 # Unknown errors => do NOT try to use the same server again
}

_parse_webpage_and_get_url()
{
  local _desc _url _referrer _search_pattern
  local _domain _cookies _parsed_code _parsed_url _status
  local _headers_file
  local _server_status_code

  _desc="${1?}"
  _url="${2:?}"
  _referrer="${3?}"
  _search_pattern="${4:?}"

  _domain="$(get_domain_from_url "${_url:?}")" || return 9
  _parsed_code=''
  _parsed_url=''
  _status=0

  if _cookies="$(_load_cookies "${_url:?}")"; then _cookies="${_cookies%"; "}"; else return "${?}"; fi

  set -- -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" || return 10
  test -z "${_referrer?}" || set -- "${@}" --header "Referer: ${_referrer:?}" || return 11
  test -z "${_cookies?}" || set -- "${@}" --header "Cookie: ${_cookies:?}" || return 12
  set -- -S "${@}" || return 13

  _headers_file="${MAIN_DIR:?}/cache/temp/headers/${_domain:?}.dat"
  test -d "${MAIN_DIR:?}/cache/temp/headers" || mkdir -p "${MAIN_DIR:?}/cache/temp/headers" || return 14

  if test "${DL_DEBUG:?}" = 'true'; then
    dl_debug "${_url:?}" "GET" "${@}"
  fi

  _parsed_code="$("${WGET_CMD:?}" -q -O '-' "${@}" -- "${_url:?}" 2> "${_headers_file:?}")" || _status="${?}"
  test "${DL_DEBUG:?}" != 'true' || cat 1>&2 "${_headers_file:?}"
  _dl_validate_status_code_from_header_file "${_headers_file:?}" || {
    _server_status_code="${?}"
    ui_debug "Failed at ${_desc?}"
    return "${_server_status_code:?}"
  }
  _dl_validate_exit_code 'wget' "${_status:?}" || return 16
  test -n "${_parsed_code?}" || return 17

  # shellcheck disable=SC3040 # Ignore: In POSIX sh, set option pipefail is undefined
  {
    # IMPORTANT: We have to avoid "printf: write error: Broken pipe" when a string is piped to "grep -q" or "grep -m1"
    test "${USING_PIPEFAIL:-false}" = 'false' || set +o pipefail
    _parsed_code="$(printf 2> /dev/null '%s\n' "${_parsed_code:?}" | grep -o -m 1 -e "${_search_pattern:?}")" || _status="${?}"
    test "${USING_PIPEFAIL:-false}" = 'false' || set -o pipefail
  }
  _dl_validate_exit_code 'grep' "${_status:?}" || return 18
  test -n "${_parsed_code?}" || return 19

  _parsed_url="$(printf '%s\n' "${_parsed_code:?}" | grep -o -e 'href=".*' | cut -d '"' -f '2' -s | sed -e 's|&amp;|\&|g')" || _status="${?}"
  _dl_validate_exit_code 'final parsing' "${_status:?}" || return 20
  test "${DL_DEBUG:?}" = 'false' || ui_debug "Parsed url: ${_parsed_url?}"
  test -n "${_parsed_url?}" || return 21

  _parse_and_store_all_cookies "${_domain:?}" 0< "${_headers_file:?}" || {
    ui_error_msg "Header parsing failed, error code => ${?}"
    return 22
  }
  rm -f "${_headers_file:?}" || return 23

  printf '%s\n' "${_parsed_url:?}" || return 24
}

dl_debug()
{
  local _show_response='false'

  ui_debug ''
  ui_debug '--------'
  ui_debug "URL: ${1:?}"
  ui_debug 'REQUEST:'
  ui_debug "  ${2:?} /$(printf '%s\n' "${1:?}" | cut -d '/' -f '4-' -s || true) HTTP/1.1"
  ui_debug "  Host: $(get_domain_from_url "${1:?}" || true)"
  shift 2

  while test "${#}" -gt 0; do
    case "${1?}" in
      -U)
        if test "${#}" -ge 2; then
          shift
          ui_debug "  User-Agent: ${1?}"
        fi
        ;;

      --header)
        if test "${#}" -ge 2; then
          shift
          ui_debug "  ${1?}"
        fi
        ;;

      -S)
        _show_response='true'
        ;;

      --post-data)
        if test "${#}" -ge 2; then
          shift
        fi
        ;;

      --)
        break
        ;;

      *)
        ui_debug "Invalid parameter: ${1?}"
        break
        ;;
    esac

    shift
  done

  if test "${_show_response:?}" = 'true'; then
    ui_debug 'RESPONSE:'
  else
    ui_debug '--------'
  fi
}

clear_previous_url()
{
  PREVIOUS_URL=''
}

get_previous_url()
{
  printf '%s\n' "${PREVIOUS_URL-}"
}

send_web_request_and_output_response()
{
  local _url _method _referrer _origin _authorization _accept _body_data _body_data_length
  local _is_ajax='false'
  local _cookies=''

  _url="${1:?}"
  _method="${2:-GET}"    # Optional (only GET and POST are supported, GET is default)
  _referrer="${3-}"      # Optional
  _origin="${4-}"        # Optional (empty or unset for normal requests but not empty for AJAX requests)
  _authorization="${5-}" # Optional
  _accept="${6-}"        # Optional
  _body_data="${7-}"     # Optional
  if test -n "${_origin?}"; then _is_ajax='true'; fi
  PREVIOUS_URL="${_url:?}"

  if test "${_is_ajax:?}" = 'true' || test "${_accept?}" = 'all'; then
    set -- -U "${DL_UA:?}" --header "${DL_ACCEPT_ALL_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" || return "${?}"
  else
    set -- -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" || return "${?}"
  fi

  if test "${_is_ajax:?}" != 'true'; then
    if _cookies="$(_load_cookies "${_url:?}")"; then _cookies="${_cookies%; }"; else return "${?}"; fi
  fi

  if test -n "${_referrer?}"; then set -- "${@}" --header "Referer: ${_referrer:?}" || return "${?}"; fi
  if test -n "${_authorization?}"; then set -- "${@}" --header "Authorization: ${_authorization:?}" || return "${?}"; fi
  if test "${_method:?}" = 'POST'; then
    _body_data_length="$(_get_byte_length "${_body_data?}")" || return "${?}"
    if test "${_body_data_length:?}" -gt 0; then
      set -- "${@}" --header 'Content-Type: text/plain;charset=UTF-8' --header "Content-Length: ${_body_data_length:?}" || return "${?}"
    fi
  fi
  if test -n "${_origin?}"; then set -- "${@}" --header "Origin: ${_origin:?}" || return "${?}"; fi
  if test -n "${_cookies?}"; then set -- "${@}" --header "Cookie: ${_cookies:?}" || return "${?}"; fi
  if test "${_method:?}" = 'POST'; then set -- "${@}" --post-data "${_body_data?}" || return "${?}"; fi

  if test "${DL_DEBUG:?}" = 'true'; then
    set -- -S "${@}" || return "${?}"
    dl_debug "${_url:?}" "${_method:?}" "${@}"
  fi
  "${WGET_CMD:?}" -q -O '-' "${@}" -- "${_url:?}"
}

# 1 => JSON string; 2 => Key to search
parse_json_and_retrieve_first_value_by_key()
{
  printf '%s\n' "${1:?}" | grep -o -m 1 -E -e "\"${2:?}\""'\s*:\s*"[^"]+' | head -n 1 | cut -d ':' -f '2-' -s | grep -o -e '".*' | cut -c '2-'
}

# 1 => JSON string; 2 => Object to search
# NOTE: The object cannot contains other objects
parse_json_and_retrieve_object()
{
  printf '%s\n' "${1:?}" | grep -o -m 1 -e "\"${2:?}\""'\s*:\s*{[^}]*}' | head -n 1 | cut -d ':' -f '2-' -s
}

send_web_request_and_output_headers()
{
  local _url _method _referrer _origin _authorization _accept
  local _is_ajax='false'
  local _cookies=''

  _url="${1:?}"
  _method="${2:-GET}"    # Optional (only GET and POST are supported, GET is default)
  _referrer="${3-}"      # Optional
  _origin="${4-}"        # Optional (empty or unset for normal requests but not empty for AJAX requests)
  _authorization="${5-}" # Optional
  _accept="${6-}"        # Optional
  if test -n "${_origin?}"; then _is_ajax='true'; fi
  PREVIOUS_URL="${_url:?}"

  if test "${_is_ajax:?}" = 'true' || test "${_accept?}" = 'all'; then
    set -- -U "${DL_UA:?}" --header "${DL_ACCEPT_ALL_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" || return "${?}"
  else
    set -- -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" || return "${?}"
  fi

  if test "${_is_ajax:?}" != 'true'; then
    if _cookies="$(_load_cookies "${_url:?}")"; then _cookies="${_cookies%; }"; else return "${?}"; fi
  fi

  if test -n "${_referrer?}"; then set -- "${@}" --header "Referer: ${_referrer:?}" || return "${?}"; fi
  if test -n "${_authorization?}"; then set -- "${@}" --header "Authorization: ${_authorization:?}" || return "${?}"; fi
  if test -n "${_origin?}"; then set -- "${@}" --header "Origin: ${_origin:?}" || return "${?}"; fi
  if test -n "${_cookies?}"; then set -- "${@}" --header "Cookie: ${_cookies:?}" || return "${?}"; fi
  if test "${_method:?}" = 'POST'; then set -- "${@}" --post-data '' || return "${?}"; fi

  if test "${DL_DEBUG:?}" = 'true'; then dl_debug "${_url:?}" "${_method:?}" "${@}"; fi
  "${WGET_CMD:?}" 2>&1 --spider -q -S -O '-' "${@}" -- "${_url:?}" || true
}

parse_headers_and_get_status_code()
{
  printf '%s\n' "${1?}" | head -n 1 | grep -o -e 'HTTP/[0-9].*' | cut -d ' ' -f '2' -s
}

parse_headers_and_get_location_url()
{
  printf '%s\n' "${1?}" | grep -o -m 1 -e 'Location:[[:space:]].*' | cut -d ':' -f '2-' -s | cut -c '2-'
}

send_web_request_and_no_output()
{
  local _url _method _referrer _origin _authorization _accept
  local _is_ajax='false'
  local _cookies=''

  _url="${1:?}"
  _method="${2:-GET}"    # Optional (only GET and POST are supported, GET is default)
  _referrer="${3-}"      # Optional
  _origin="${4-}"        # Optional (empty or unset for normal requests but not empty for AJAX requests)
  _authorization="${5-}" # Optional
  _accept="${6-}"        # Optional
  if test -n "${_origin?}"; then _is_ajax='true'; fi
  PREVIOUS_URL="${_url:?}"

  if test "${_is_ajax:?}" = 'true' || test "${_accept?}" = 'all'; then
    set -- -U "${DL_UA:?}" --header "${DL_ACCEPT_ALL_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" || return "${?}"
  else
    set -- -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" || return "${?}"
  fi

  if test "${_is_ajax:?}" != 'true'; then
    if _cookies="$(_load_cookies "${_url:?}")"; then _cookies="${_cookies%; }"; else return "${?}"; fi
  fi

  if test -n "${_referrer?}"; then set -- "${@}" --header "Referer: ${_referrer:?}" || return "${?}"; fi
  if test -n "${_authorization?}"; then set -- "${@}" --header "Authorization: ${_authorization:?}" || return "${?}"; fi
  if test -n "${_origin?}"; then set -- "${@}" --header "Origin: ${_origin:?}" || return "${?}"; fi
  if test -n "${_cookies?}"; then set -- "${@}" --header "Cookie: ${_cookies:?}" || return "${?}"; fi
  if test "${_method:?}" = 'POST'; then set -- "${@}" --post-data '' || return "${?}"; fi

  if test "${DL_DEBUG:?}" = 'true'; then dl_debug "${_url:?}" "${_method:?}" "${@}"; fi
  "${WGET_CMD:?}" --spider -q -O '-' "${@}" -- "${_url:?}"
}

_direct_download()
{
  local _output
  local _url _method _referrer _origin _authorization _accept
  local _is_ajax='false'
  local _cookies=''
  local _status _domain _headers_file
  local _server_status_code

  _status=0
  _url="${1:?}"
  _output="${2:?}"
  _method="${3:-GET}"    # Optional (only GET and POST are supported, GET is default)
  _referrer="${4-}"      # Optional
  _origin="${5-}"        # Optional (empty or unset for normal requests but not empty for AJAX requests)
  _authorization="${6-}" # Optional
  _accept="${7-}"        # Optional
  if test -n "${_origin?}"; then _is_ajax='true'; fi

  if test "${_is_ajax:?}" = 'true' || test "${_accept?}" = 'all'; then
    set -- -U "${DL_UA:?}" --header "${DL_ACCEPT_ALL_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" || return 11
  else
    set -- -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" || return 12
  fi

  if test "${_is_ajax:?}" != 'true'; then
    if _cookies="$(_load_cookies "${_url:?}")"; then _cookies="${_cookies%; }"; else return 13; fi
  fi

  if test -n "${_referrer?}"; then set -- "${@}" --header "Referer: ${_referrer:?}" || return 14; fi
  if test -n "${_authorization?}"; then set -- "${@}" --header "Authorization: ${_authorization:?}" || return 15; fi
  if test -n "${_origin?}"; then set -- "${@}" --header "Origin: ${_origin:?}" || return 16; fi
  if test -n "${_cookies?}"; then set -- "${@}" --header "Cookie: ${_cookies:?}" || return 17; fi
  if test "${_method:?}" = 'POST'; then set -- "${@}" --post-data '' || return 18; fi

  _domain="$(get_domain_from_url "${_url:?}")" || return 19
  _headers_file="${MAIN_DIR:?}/cache/temp/headers/${_domain:?}.dat"
  test -d "${MAIN_DIR:?}/cache/temp/headers" || mkdir -p "${MAIN_DIR:?}/cache/temp/headers" || return 20

  if test "${DL_DEBUG:?}" = 'true'; then
    dl_debug "${_url:?}" "${_method:?}" "${@}"
  fi

  "${WGET_CMD:?}" -q -S -O "${_output:?}" "${@}" -- "${_url:?}" 2> "${_headers_file:?}" || _status="${?}"
  test "${DL_DEBUG:?}" != 'true' || cat 1>&2 "${_headers_file:?}"
  _dl_validate_status_code_from_header_file "${_headers_file:?}" || {
    _server_status_code="${?}"
    if test "${_server_status_code:?}" -ne 30; then
      #ui_debug "Failed at ${_desc?}"
      return "${_server_status_code:?}"
    fi
  }
  _dl_validate_exit_code 'wget' "${_status:?}" || return "${?}"

  rm -f "${_headers_file:?}" || return 21
  return 0
}

report_failure()
{
  printf 1>&2 '%s - ' "DL type ${1?} failed at '${3:-}' with ret. code ${2?}"
  if test -n "${4:-}"; then printf 1>&2 '\n%s\n' "${4:?}"; fi

  return "${2:?}"
}

report_failure_one()
{
  test "${1:?}" -ge 100 || readonly DL_TYPE_1_FAILED='true'

  #printf '%s - ' "Failed at '${2}' with ret. code ${1:?}"
  test -z "${3-}" || ui_debug "${3:?}"

  return "${1:?}"
}

_init_dl()
{
  _CURRENT_URL=''
  _PREVIOUS_URL=''
  clear_dl_temp_dir
}

_set_url()
{
  _PREVIOUS_URL="${_CURRENT_URL?}"
  _CURRENT_URL="${1:?}"
}

_set_referrer()
{
  _PREVIOUS_URL="${1:?}"
}

_deinit_dl()
{
  unset _CURRENT_URL
  unset _PREVIOUS_URL
  clear_dl_temp_dir
}

dl_type_zero()
{
  _init_dl

  _set_url "${1:?}"
  _direct_download "${_CURRENT_URL:?}" "${2:?}" 'GET' "${_PREVIOUS_URL?}" ||
    report_failure 0 "${?}" 'dl' || return "${?}"

  _deinit_dl
}

dl_type_one()
{
  if test "${DL_TYPE_1_FAILED:-false}" != 'false'; then return 128; fi
  local _base_url _result

  _init_dl
  _base_url="$(get_base_url "${1:?}")" || return 2

  _set_url "${1:?}"
  _set_referrer "${_base_url:?}/"
  _result="$(_parse_webpage_and_get_url 'get link 1' "${_CURRENT_URL:?}" "${_PREVIOUS_URL?}" 'downloadButton[^"]*"\s*href="[^"]*"')" || {
    report_failure_one "${?}" 'get link 1' "${_result?}" || return "${?}"
  }

  sleep '0.2'
  _set_url "${_base_url:?}${_result:?}"
  _result="$(_parse_webpage_and_get_url 'get link 2' "${_CURRENT_URL:?}" "${_PREVIOUS_URL?}" 'Your\sdownload\swill\sstart.*href="[^"]*"')" || {
    report_failure_one "${?}" 'get link 2' "${_result?}" || return "${?}"
  }

  sleep '0.4'
  _set_url "${_base_url:?}${_result:?}"
  _direct_download "${_CURRENT_URL:?}" "${2:?}" 'GET' "${_PREVIOUS_URL?}" || {
    report_failure_one "${?}" 'dl' || return "${?}"
  }

  _deinit_dl
}

dl_type_two()
{
  local _url _output
  local _domain _second_level_domain
  local _base_api_url _base_origin _base_referrer
  local _http_headers _status_code
  local _loc_code _json_response _id_code _token_code

  clear_previous_url

  _url="${1:?}"
  _output="${2:?}"

  _domain="$(get_domain_from_url "${_url:?}")" || report_failure 2 "${?}" || return "${?}"
  _second_level_domain="$(get_second_level_domain_from_url "${_url:?}")" || report_failure 2 "${?}" || return "${?}"

  _base_api_url="${DL_PROT:?}api.${_second_level_domain:?}"
  _base_origin="${DL_PROT:?}${_second_level_domain:?}"
  _base_referrer="${_base_origin:?}/"

  local _count=1
  local _last_location_url="${_url:?}"
  while true; do
    _http_headers="$(send_web_request_and_output_headers "${_last_location_url:?}" 'GET')"
    _status_code="$(parse_headers_and_get_status_code "${_http_headers?}")"
    if test "${DL_DEBUG:?}" = 'true'; then printf '%s\n' "Status code: ${_status_code?}"; fi

    case "${_status_code?}" in
      2*) # Final location URL found (usually 200)
        break
        ;;
      3*) # Continue until the redirects run out (usually 302)
        _last_location_url="$(parse_headers_and_get_location_url "${_http_headers?}")" ||
          {
            report_failure 2 "${?}" "get location url ${_count:?}"
            return "${?}"
          }
        ;;
      404)
        report_failure 2 "77" "get location url ${_count:?}" 'WARNING: THE FILE HAS BEEN DELETED ON THE SERVER!!!'
        return "${?}"
        ;;
      *)
        report_failure 2 "78" "get location url ${_count:?}" "Unsupported HTTP status code: ${_status_code?}"
        return "${?}"
        ;;
    esac

    if ! _count="$((_count + 1))" || test "${_count:?}" -gt 5; then
      report_failure 2 "79" "get location url ${_count:?}" 'Redirection limit reached!!!'
      return "${?}"
    fi
  done

  _loc_code="$(printf '%s\n' "${_last_location_url:?}" | cut -d '/' -f '5-' -s)" ||
    report_failure 2 "${?}" 'get location code' || return "${?}"
  if test "${DL_DEBUG:?}" = 'true'; then printf '%s\n' "Loc code: ${_loc_code?}"; fi

  sleep '0.2'
  _json_response="$(send_web_request_and_output_response "${_base_api_url:?}/accounts" 'POST' "${_base_referrer:?}" "${_base_origin:?}" '' '' '')" ||
    report_failure 2 "${?}" 'do AJAX post req' || return "${?}"
  if test "${DL_DEBUG:?}" = 'true'; then printf '%s\n' "${_json_response?}"; fi

  _id_code="$(parse_json_and_retrieve_first_value_by_key "${_json_response:?}" 'id')" ||
    report_failure 2 "${?}" 'parse JSON 1' || return "${?}"
  _token_code="$(parse_json_and_retrieve_first_value_by_key "${_json_response:?}" 'token')" ||
    report_failure 2 "${?}" 'parse JSON 2' || return "${?}"

  sleep '0.2'
  _json_response="$(send_web_request_and_output_response "${_base_api_url:?}/accounts/${_id_code:?}" 'GET' "${_base_referrer:?}" "${_base_origin:?}" "Bearer ${_token_code:?}")" ||
    report_failure 2 "${?}" 'do AJAX get req 1' || return "${?}"
  if test "${DL_DEBUG:?}" = 'true'; then printf '%s\n' "${_json_response?}"; fi

  _parse_and_store_cookie "${_second_level_domain:?}" 'account''Token='"${_token_code:?}" ||
    report_failure 2 "${?}" 'set cookie' || return "${?}"

  ### NOTE: This is not required ###
  #sleep 0.2
  #send_web_request_and_no_output "${DL_PROT:?}${_second_level_domain:?}/contents/files.html" 'GET' "${_base_referrer:?}" '' '' 'all' ||
  #  report_failure 2 "${?}" 'do req files.html' || return "${?}"

  sleep '0.2'
  _json_response="$(send_web_request_and_output_response "${_base_api_url:?}/contents/${_loc_code:?}?"'wt''=''4fd6''sg89''d7s6' 'GET' "${_base_referrer:?}" "${_base_origin:?}" "Bearer ${_token_code:?}")" ||
    report_failure 2 "${?}" 'do AJAX get req 2' || return "${?}"
  if test "${DL_DEBUG:?}" = 'true'; then printf '%s\n' "${_json_response?}"; fi

  local _dl_unique_id _json_object _parsed_link

  _dl_unique_id="$(printf '%s\n' "${_url:?}" | rev | cut -d '/' -f '2' -s | rev)" ||
    report_failure 2 "${?}" 'parse DL unique ID' || return "${?}"

  if test "${_dl_unique_id?}" = 'd'; then
    # If it is a folder link then choose the first download
    _parsed_link="$(parse_json_and_retrieve_first_value_by_key "${_json_response:?}" 'link')" ||
      report_failure 2 "${?}" 'parse last JSON' || return "${?}"
  else
    if test "${DL_DEBUG:?}" = 'true'; then printf '\n%s\n' "DL unique ID: ${_dl_unique_id?}"; fi

    _json_object="$(parse_json_and_retrieve_object "${_json_response:?}" "${_dl_unique_id:?}")" ||
      report_failure 2 "${?}" 'parse last JSON 1' || return "${?}"
    _parsed_link="$(parse_json_and_retrieve_first_value_by_key "${_json_object:?}" 'link')" ||
      report_failure 2 "${?}" 'parse last JSON 2' || return "${?}"
  fi
  if test "${DL_DEBUG:?}" = 'true'; then printf '\n%s\n' "Parsed link: ${_parsed_link?}"; fi

  sleep '0.3'
  _direct_download "${_parsed_link:?}" "${_output:?}" 'GET' "${_base_referrer:?}" ||
    report_failure 2 "${?}" 'dl' || return "${?}"
}

dl_file()
{
  if test -e "${BUILD_CACHE_DIR:?}/$1/$2"; then verify_sha1 "${BUILD_CACHE_DIR:?}/$1/$2" "$3" || rm -f "${BUILD_CACHE_DIR:?}/$1/$2"; fi # Preventive check to silently remove corrupted/invalid files

  printf '%s ' "Checking ${2?}..."
  local _status _url _domain
  _status=0
  _url="${DL_PROT:?}${4:?}" || return "${?}"
  _domain="$(get_domain_from_url "${_url:?}")" || return "${?}"

  _clear_cookies || return "${?}"

  if ! test -e "${BUILD_CACHE_DIR:?}/${1:?}/${2:?}"; then
    mkdir -p "${BUILD_CACHE_DIR:?}/${1:?}" || ui_error "Failed to create the ${1?} folder inside the cache dir"

    if test "${CI:-false}" = 'false'; then sleep '0.5'; else sleep 3; fi
    case "${_domain:?}" in
      *\.'go''file''.io' | 'go''file''.io')
        printf '\n %s: ' 'DL type 2'
        dl_type_two "${_url:?}" "${BUILD_CACHE_DIR:?}/${1:?}/${2:?}" || _status="${?}"
        ;;
      *\.'apk''mirror''.com')
        printf '\n %s: ' 'DL type 1'
        dl_type_one "${_url:?}" "${BUILD_CACHE_DIR:?}/${1:?}/${2:?}" || _status="${?}"
        ;;
      ????*)
        printf '\n %s: ' 'DL type 0'
        dl_type_zero "${_url:?}" "${BUILD_CACHE_DIR:?}/${1:?}/${2:?}" || _status="${?}"
        ;;
      *)
        ui_error "Invalid download URL => '${_url?}'"
        ;;
    esac

    _clear_cookies || return "${?}"

    if test "${_status:?}" -ne 0; then
      if test -n "${5-}"; then
        if test "${_status:?}" -eq 128; then
          printf '%s\n' 'Download skipped, trying a mirror...'
        else
          printf '%s\n' "Download failed with error code ${_status?}, trying a mirror..."
        fi
        dl_file "${1:?}" "${2:?}" "${3:?}" "${5:?}"
        return "${?}"
      else
        printf '%s\n' "Download failed with error code ${_status?}"
        ui_error "Failed to download the file => '${1?}/${2?}'"
      fi
    fi
  fi

  verify_sha1 "${BUILD_CACHE_DIR:?}/$1/$2" "$3" || corrupted_file "${BUILD_CACHE_DIR:?}/$1/$2"
  printf '%s\n' 'OK'
}

dl_list()
{
  local local_filename local_path dl_hash dl_url dl_mirror
  local _backup_ifs _current_line

  _backup_ifs="${IFS-}"
  IFS="${NL}"
  # shellcheck disable=SC2086 # Ignore: Double quote to prevent globbing and word splitting
  set -- ${1} || ui_error "Failed expanding DL info list inside dl_list()"
  if test -n "${_backup_ifs}"; then IFS="${_backup_ifs}"; else unset IFS; fi

  for _current_line in "${@}"; do
    _backup_ifs="${IFS-}"
    IFS='|'
    # shellcheck disable=SC2086 # Ignore: Double quote to prevent globbing and word splitting
    set -- ${_current_line} || ui_error "Failed expanding DL info inside dl_list()"
    if test -n "${_backup_ifs}"; then IFS="${_backup_ifs}"; else unset IFS; fi

    local_filename="${1}"
    local_path="${2}"
    dl_hash="${7}"
    dl_url="${8}"
    dl_mirror="${9}"

    dl_file "${local_path:?}" "${local_filename:?}.apk" "${dl_hash:?}" "${dl_url:?}" "${dl_mirror?}" || return "${?}"
  done
}

get_32bit_programfiles()
{
  local _dir

  _dir="${PROGRAMFILES_X86_-}" # On 64-bit Windows (on BusyBox)

  if test -z "${_dir?}"; then
    if test "${IS_BUSYBOX:?}" = 'false'; then
      _dir="$(env | grep -m 1 -i -e '^ProgramFiles(x86)=' | cut -d '=' -f '2-' -s || true)" # On 64-bit Windows (on Bash)
    fi
    if test -z "${_dir?}"; then
      _dir="${PROGRAMFILES-}" # On 32-bit Windows
    fi
  fi

  printf '%s\n' "${_dir?}"
}

_is_in_path_env_internal()
{
  case "${PATHSEP:?}${PATH-}${PATHSEP:?}" in
    *"${PATHSEP:?}${1:?}${PATHSEP:?}"*) return 0 ;; # Found
    *) ;;
  esac
  return 1 # NOT found
}

is_in_path_env()
{
  if test -n "${CYGPATH?}"; then
    # Only on Bash under Windows
    local _path
    _path="$("${CYGPATH:?}" -u -- "${1:?}")" || ui_error 'Unable to convert a path in is_in_path_env()'
    set -- "${_path:?}"
  fi

  _is_in_path_env_internal "${1:?}"
}

add_to_path_env()
{
  if test -n "${CYGPATH?}"; then
    # Only on Bash under Windows
    local _path
    _path="$("${CYGPATH:?}" -u -- "${1:?}")" || ui_error 'Unable to convert a path in add_to_path_env()'
    set -- "${_path:?}"
  fi

  if _is_in_path_env_internal "${1:?}" || test ! -e "${1:?}"; then return 0; fi

  if test -z "${PATH-}"; then
    ui_warning 'PATH env is empty'
    PATH="${1:?}"
  else
    PATH="${1:?}${PATHSEP:?}${PATH:?}"
  fi
}

remove_from_path_env()
{
  local _new_path

  if test -n "${CYGPATH?}"; then
    # Only on Bash under Windows
    local _single_path
    _single_path="$("${CYGPATH:?}" -u -- "${1:?}")" || ui_error 'Unable to convert a path in remove_from_path_env()'
    set -- "${_single_path:?}"
  fi

  if _new_path="$(printf '%s\n' "${PATH-}" | tr -- "${PATHSEP:?}" '\n' | grep -v -x -F -e "${1:?}" | tr -- '\n' "${PATHSEP:?}")" && _new_path="${_new_path%"${PATHSEP:?}"}"; then
    PATH="${_new_path?}"
  fi
}

move_to_begin_of_path_env()
{
  local _new_path
  if test ! -e "${1:?}"; then return 0; fi

  if test -z "${PATH-}"; then
    ui_warning 'PATH env is empty'
    PATH="${1:?}"
  elif _new_path="$(printf '%s\n' "${PATH:?}" | tr -- "${PATHSEP:?}" '\n' | grep -v -x -F -e "${1:?}" | tr -- '\n' "${PATHSEP:?}")" && _new_path="${_new_path%"${PATHSEP:?}"}" && test -n "${_new_path?}"; then
    PATH="${1:?}${PATHSEP:?}${_new_path:?}"
  fi
}

remove_duplicates_from_path_env()
{
  local _path

  if test "${PLATFORM:?}" = 'win' && _path="$(printf '%s\n' "${PATH-}" | tr -- "${PATHSEP:?}" '\n' | awk -- '!x[tolower($0)]++' - | tr -- '\n' "${PATHSEP:?}")" && _path="${_path%"${PATHSEP:?}"}"; then
    :
  elif test "${PLATFORM:?}" != 'win' && _path="$(printf '%s\n' "${PATH-}" | tr -- "${PATHSEP:?}" '\n' | awk -- '!x[$0]++' - | tr -- '\n' "${PATHSEP:?}")" && _path="${_path%"${PATHSEP:?}"}"; then
    :
  else
    ui_warning 'Removing duplicates from PATH env failed'
    return
  fi

  PATH="${_path?}"
}

sume()
{
  local _set_env_vars _fix_pwd
  _set_env_vars=''
  _fix_pwd=''

  if test "${PLATFORM:?}" != 'win'; then
    ui_warning 'sume not supported!!!'
    return 1
  fi
  ! is_root || return 0

  _set_env_vars="export HOME='${HOME-}'; export USER_HOME='${USER_HOME-}'; export MAIN_DIR='${MAIN_DIR:?}';"

  if test "${IS_BUSYBOX:?}" = 'true'; then
    su -c "${_set_env_vars} . '${MAIN_DIR:?}/cmdline.sh' \"\${@}\"" -- root "${0-}" "${@}"
  elif test -n "${BB_CMD?}" && test -n "${SHELL_EXE?}"; then
    _fix_pwd="cd '${PWD:?}';"
    "${BB_CMD:?}" su -s "${SHELL_EXE:?}" -c "${_set_env_vars} ${_fix_pwd} . '${MAIN_DIR:?}/cmdline.sh' \"\${@}\"" -- root "${0-}" "${@}"
  else
    ui_warning 'sume failed!!!'
    return 125
  fi
}

dropme()
{
  if test "${PLATFORM:?}" != 'win'; then
    ui_warning 'dropme not supported!!!'
    return 1
  fi
  is_root || return 0

  if test "${IS_BUSYBOX:?}" = 'true'; then
    # shellcheck disable=SC2016 # Ignore: Expressions don't expand in single quotes
    drop -c ". '${MAIN_DIR:?}/cmdline.sh' \"\${@}\"" -- "${0-}" "${@}"
  elif test -n "${BB_CMD?}" && test -n "${SHELL_EXE?}"; then
    # shellcheck disable=SC2016 # Ignore: Expressions don't expand in single quotes
    "${BB_CMD:?}" drop -s "${SHELL_EXE:?}" -c ". '${MAIN_DIR:?}/cmdline.sh' \"\${@}\"" -- "${0-}" "${@}"
  else
    ui_warning 'dropme failed!!!'
    return 125
  fi
}

create_bb_alias_if_not_applet()
{
  # shellcheck disable=SC2139 # Ignore: This expands when defined, not when used
  if test "$(command -v "${1:?}" || true)" != "${1:?}"; then alias "${1:?}"="busybox '${1:?}'"; fi
}

create_bb_alias_if_missing()
{
  # shellcheck disable=SC2139 # Ignore: This expands when defined, not when used
  if ! command 1> /dev/null -v "${1:?}"; then alias "${1:?}"="busybox '${1:?}'"; fi
}

init_base()
{
  local _main_dir

  if test "${STARTED_FROM_BATCH_FILE:-0}" != '0' && test -n "${MAIN_DIR-}"; then
    MAIN_DIR="$(realpath "${MAIN_DIR:?}")" || ui_error 'Unable to resolve the main dir'
  fi

  # shellcheck disable=SC3028 # Ignore: In POSIX sh, BASH_SOURCE is undefined
  if test -z "${MAIN_DIR-}" && test -n "${BASH_SOURCE-}" && _main_dir="$(dirname "${BASH_SOURCE:?}")" && _main_dir="$(realpath "${_main_dir:?}/..")"; then
    MAIN_DIR="${_main_dir:?}"
  fi

  if test -n "${CYGPATH?}" && test -n "${MAIN_DIR-}"; then
    # Only on Bash under Windows
    MAIN_DIR="$("${CYGPATH:?}" -m -l -- "${MAIN_DIR:?}")" || ui_error 'Unable to convert the main dir'
  fi

  test -n "${MAIN_DIR-}" || ui_error 'MAIN_DIR env var is empty'

  TMPDIR="${TMPDIR:-${RUNNER_TEMP:-${TMP:-${TEMP:-/tmp}}}}"
  export TMPDIR

  if test -n "${CYGPATH?}" && test "${TMPDIR?}" = '/tmp'; then
    # Workaround for issues with Bash under Windows (for example the one included inside Git for Windows)
    TMPDIR="$("${CYGPATH:?}" -m -a -l -- '/tmp')" || ui_error 'Unable to convert the temp directory'
    TMP="${TMPDIR:?}"
    TEMP="${TMPDIR:?}"
  fi

  TOOLS_DIR="${MAIN_DIR:?}/tools/${PLATFORM:?}"

  readonly MAIN_DIR TOOLS_DIR
}

init_path()
{
  test "${IS_PATH_INITIALIZED:-false}" = 'false' || return
  readonly IS_PATH_INITIALIZED='true'
  if is_in_path_env "${TOOLS_DIR:?}"; then return; fi

  if test -n "${PATH-}"; then PATH="${PATH%"${PATHSEP:?}"}"; fi

  if test "${PLATFORM:?}" = 'win'; then
    # On Bash under Windows (for example the one included inside Git for Windows) we need to have '/usr/bin'
    # before 'C:/Windows/System32' otherwise it will use the find/sort/etc. of Windows instead of the Unix compatible ones.
    # ADDITIONAL NOTE: We have to do this even under BusyBox otherwise every external bash/make executed as subshell of BusyBox will be broken.
    if test -z "${PATH-}"; then
      ui_warning 'PATH env is empty'
      PATH='/usr/bin'
    else
      PATH="/usr/bin${PATHSEP:?}${PATH:?}"
    fi

    # Make some GNU tools available
    local _program_dir_32
    _program_dir_32="$(get_32bit_programfiles)"
    if test -n "${_program_dir_32?}"; then
      add_to_path_env "${_program_dir_32:?}/GnuWin32/bin"
    fi
  fi

  if test "${DO_INIT_CMDLINE:-0}" != '0'; then remove_duplicates_from_path_env; fi
  add_to_path_env "${TOOLS_DIR:?}"
}

init_vars()
{
  MODULE_NAME="$(simple_get_prop 'name' "${MAIN_DIR:?}/zip-content/module.prop")" || ui_error 'Failed to parse the module name string'
  readonly MODULE_NAME
  export MODULE_NAME
}

detect_bb_and_id()
{
  BB_CMD=''
  ID_CMD=''

  if test "${PLATFORM:?}" = 'win' && test "${IS_BUSYBOX:?}" = 'true' && test -n "${SHELL_EXE?}"; then
    BB_CMD="${SHELL_EXE:?}"
  else
    BB_CMD="$(command 2> /dev/null -v busybox)" || BB_CMD=''
  fi

  if test "${PLATFORM:?}" = 'win' && test -n "${BB_CMD?}"; then
    ID_CMD='id'
  else
    ID_CMD="$(command -v id)" || ui_error 'Unable to get the path of id'
  fi

  readonly BB_CMD ID_CMD
}

is_root()
{
  local _user_id

  if test "${PLATFORM:?}" = 'win' && test -n "${BB_CMD?}"; then
    # Bash under Windows is unable to detect root so we need to use BusyBox
    _user_id="$("${BB_CMD:?}" id -u)" || ui_error 'Unable to get user ID'
  else
    _user_id="$("${ID_CMD:?}" -u)" || ui_error 'Unable to get user ID'
  fi

  if test "${_user_id:?}" -ne 0; then return 1; fi # Return false
  return 0                                         # Return true
}

shellhelp()
{
  if test "${#}" -gt 0; then
    PATH="%builtin${PATHSEP:?}${PATH-}" \help "${@}"
  else
    # shellcheck disable=SC2016 # It is intended: Expressions don't expand in single quotes
    PATH="%builtin${PATHSEP:?}${PATH-}" \help | sed -e 's/Type `help/Type `shellhelp/g'
  fi
}

init_cmdline()
{
  unset PROMPT_COMMAND PS1 PROMPT A5K_SAVED_TITLE
  unset __DEFAULT_PS1 __DEFAULT_PS1_AS_ROOT

  export __TITLE_CMD_PREFIX=''
  export __TITLE_CMD_0=''
  export __TITLE_CMD_PARAMS=''

  test "${IS_BUSYBOX:?}" = 'false' || __TITLE_CMD_PREFIX='busybox '
  __TITLE_CMD_0="$(basename "${0:--}" || printf '%s' "${0:--}")"
  test "${#}" -eq 0 || __TITLE_CMD_PARAMS="$(printf ' "%s"' "${@}")"
  readonly __TITLE_CMD_PREFIX __TITLE_CMD_0 __TITLE_CMD_PARAMS

  A5K_LAST_TITLE="${A5K_LAST_TITLE-}"
  if test "${A5K_TITLE_IS_DEFAULT-}" != 'false'; then set_default_title; fi

  if test "${STARTED_FROM_BATCH_FILE:-0}" != '0' && test -n "${HOME-}"; then
    HOME="$(realpath "${HOME:?}")" || ui_error 'Unable to resolve the home dir'
  fi
  if test -n "${CYGPATH?}" && test -n "${HOME-}"; then
    # Only on Bash under Windows
    HOME="$("${CYGPATH:?}" -u -- "${HOME:?}")" || ui_error 'Unable to convert the home dir'
  fi

  # shellcheck disable=SC3028 # In POSIX sh, SHLVL is undefined
  if test -n "${KILL_PPID-}" && test -z "${NO_KILL-}" && test "${PLATFORM:?}" = 'win' && test "${SHLVL:-1}" = '1' && test -n "${PPID-}" && test "${PPID}" -gt 1; then
    if kill 2> /dev/null "${PPID}" || kill -9 "${PPID}"; then
      PPID='1'
    fi
  fi
  unset KILL_PPID

  if test "${PLATFORM:?}" = 'win'; then unset JAVA_HOME; fi

  # Clean useless directories from the $PATH env
  if test "${PLATFORM?}" = 'win'; then
    remove_from_path_env "${LOCALAPPDATA-}/Microsoft/WindowsApps"
  fi

  # Set environment variables
  readonly UTILS_DIR="${MAIN_DIR:?}/utils"
  readonly UTILS_DATA_DIR="${UTILS_DIR:?}/data"
  export UTILS_DIR UTILS_DATA_DIR

  if test -n "${GIT_SSH:="$(command -v 'TortoiseGitPlink' || :)"}"; then export GIT_SSH; else unset GIT_SSH; fi

  # Set the path of Android SDK if not already set
  if test -z "${ANDROID_SDK_ROOT-}"; then
    if test -n "${USER_HOME-}" && test -e "${USER_HOME:?}/Android/Sdk"; then
      # Linux
      export ANDROID_SDK_ROOT="${USER_HOME:?}/Android/Sdk"
    elif test -n "${LOCALAPPDATA-}" && test -e "${LOCALAPPDATA:?}/Android/Sdk"; then
      # Windows
      export ANDROID_SDK_ROOT="${LOCALAPPDATA:?}/Android/Sdk"
    elif test -n "${USER_HOME-}" && test -e "${USER_HOME:?}/Library/Android/sdk"; then
      # macOS
      export ANDROID_SDK_ROOT="${USER_HOME:?}/Library/Android/sdk"
    fi
  fi

  if test -n "${ANDROID_SDK_ROOT-}"; then
    if test -n "${CYGPATH?}"; then
      # Only on Bash under Windows
      ANDROID_SDK_ROOT="$("${CYGPATH:?}" -m -l -a -- "${ANDROID_SDK_ROOT:?}")" || ui_error 'Unable to convert the Android SDK dir'
    fi

    add_to_path_env "${ANDROID_SDK_ROOT:?}/platform-tools"

    if test -e "${ANDROID_SDK_ROOT:?}/build-tools"; then
      if AAPT2_PATH="$(find "${ANDROID_SDK_ROOT:?}/build-tools" -maxdepth 2 -iname 'aapt2*' | LC_ALL=C sort -V -r | head -n 1)" && test -n "${AAPT2_PATH?}"; then
        export AAPT2_PATH
        if command 1> /dev/null 2>&1 -v 'alias'; then
          # shellcheck disable=SC2139
          alias 'aapt2'="'${AAPT2_PATH:?}'"
        fi
      else
        unset AAPT2_PATH
      fi
      if APKSIGNER_PATH="$(find "${ANDROID_SDK_ROOT:?}/build-tools" -maxdepth 2 -iname 'apksigner*' | LC_ALL=C sort -V -r | head -n 1)" && test -n "${APKSIGNER_PATH?}"; then
        export APKSIGNER_PATH
        if command 1> /dev/null 2>&1 -v 'alias'; then
          # shellcheck disable=SC2139
          alias 'apksigner'="'${APKSIGNER_PATH:?}'"
        fi
      else
        unset APKSIGNER_PATH
      fi
    fi
  fi

  if test "${PLATFORM:?}" = 'win'; then
    export BB_OVERRIDE_APPLETS='; make'
  fi

  if command 1> /dev/null 2>&1 -v 'alias'; then
    alias 'dir'='ls'
    alias 'cd..'='cd ..'
    alias 'cd.'='cd .'
    if test "${IS_BUSYBOX:?}" = 'true'; then
      alias 'cls'='reset'
    else
      alias 'cls'='clear'
    fi
    alias 'clear-prev'="printf '\033[A\33[2K\033[A\33[2K\r'"

    if test -f "${MAIN_DIR:?}/includes/custom-aliases.sh"; then
      # shellcheck source=/dev/null
      . "${MAIN_DIR:?}/includes/custom-aliases.sh" || ui_error 'Unable to source includes/custom-aliases.sh'
    fi

    alias 'build'='build.sh'
    alias 'cmdline'='cmdline.sh'
    if test "${PLATFORM:?}" = 'win'; then
      alias 'gradlew'='gradlew.bat'
      alias 'start'='start.sh'
    fi

    alias 'bits-info'="bits-info.sh"
    alias 'help'='help.sh'
  fi

  add_to_path_env "${UTILS_DIR:?}"
  add_to_path_env "${MAIN_DIR:?}"
  PATH="%builtin${PATHSEP:?}${PATH-}"
  add_to_path_env "${MAIN_DIR:?}/tools"

  if test -n "${BB_CMD?}" && command 1> /dev/null 2>&1 -v 'alias'; then
    create_bb_alias_if_missing 'su'
    create_bb_alias_if_missing 'ts'
    if test "${PLATFORM:?}" = 'win'; then
      create_bb_alias_if_missing 'drop'
      create_bb_alias_if_missing 'make'
      create_bb_alias_if_not_applet 'pdpmake'
    fi
  fi

  export A5K_TITLE_IS_DEFAULT
  export A5K_LAST_TITLE

  if test "${PLATFORM:?}" = 'win'; then
    export PATHEXT="${PATHEXT:-.BAT};.SH"
    export BB_FIX_BACKSLASH=1
    export ac_executable_extensions='.exe'
  fi

  export PATH_SEPARATOR="${PATHSEP:?}"
  export DIRECTORY_SEPARATOR='/'

  export NO_PAUSE=1
  export GRADLE_OPTS="${GRADLE_OPTS:--Dorg.gradle.daemon=false}"

  # Escape the colors with \[ \] => https://mywiki.wooledge.org/BashFAQ/053
  readonly __DEFAULT_PS1='\[\033[1;32m\]\u\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$ '
  if test "${PLATFORM:?}" = 'win' && test "${IS_BUSYBOX:?}" = 'false'; then
    # Only needed on Bash under Windows
    readonly __DEFAULT_PS1_AS_ROOT='\[\033[1;32m\]root\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]# '
  else
    readonly __DEFAULT_PS1_AS_ROOT=''
  fi

  git()
  {
    HOME="${USER_HOME:-${HOME:?}}" command -- git "${@}"
  }

  gpg()
  {
    HOME="${USER_HOME:-${HOME:?}}" command -- gpg "${@}"
  }

  bundle()
  {
    HOME="${USER_HOME:-${HOME:?}}" command -- bundle "${@}"
  }

  if test "${CI:-false}" = 'false'; then
    PS1="${__DEFAULT_PS1:?}"
    PROMPT_COMMAND='__update_title_and_ps1 "${@}" || true'
  fi
}

if test "${DO_INIT_CMDLINE:-0}" != '0'; then
  set -u 2> /dev/null || :

  # shellcheck disable=SC3040 # Ignore: In POSIX sh, set option pipefail is undefined
  case "$(set 2> /dev/null -o || set || :)" in *'pipefail'*) set -o pipefail || echo 1>&2 'Failed: pipefail' ;; *) ;; esac
  # shellcheck disable=SC3041,SC2015 # Ignore: In POSIX sh, set flag -H is undefined
  (set +H 2> /dev/null) && set +H || :
fi

# Set environment variables
detect_os_and_other_things
export PLATFORM IS_BUSYBOX PATHSEP CYGPATH SHELL_EXE SHELL_APPLET
init_base
export MAIN_DIR TOOLS_DIR
init_path
init_vars
detect_bb_and_id

if test "${DO_INIT_CMDLINE:-0}" != '0'; then
  if test -n "${__QUOTED_PARAMS-}" && test "${#}" -eq 0; then
    _newline='
'
    _backup_ifs="${IFS-}"
    IFS="${_newline:?}"
    for _param in ${__QUOTED_PARAMS:?}; do
      set -- "${@}" "${_param?}"
    done
    IFS="${_backup_ifs?}"
    unset _newline _backup_ifs _param
  fi

  unset DO_INIT_CMDLINE
  unset __QUOTED_PARAMS
  if test "${#}" -eq 0; then init_cmdline; else init_cmdline "${@}"; fi
fi

export PATH

if test -n "${ANDROID_SDK_ROOT:-}" && test -e "${ANDROID_SDK_ROOT:?}/emulator/emulator.exe"; then
  # shellcheck disable=SC2139
  {
    alias 'emu'="'${ANDROID_SDK_ROOT:?}/emulator/emulator.exe' -no-boot-anim"
    alias 'emu-w'="'${ANDROID_SDK_ROOT:?}/emulator/emulator.exe' -writable-system -no-snapshot-load -no-boot-anim"
  }
fi
