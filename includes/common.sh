#!/usr/bin/env bash
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
  # shellcheck disable=SC3028 # In POSIX sh, SHLVL is undefined
  if test "${CI:-false}" = 'false' && test "${TERM_PROGRAM-}" != 'vscode' && test "${APP_BASE_NAME-}" != 'gradlew' && test "${SHLVL:-1}" = '1' && test -t 0 && test -t 2; then
    printf 1>&2 '\n\033[1;32m%s\033[0m' 'Press any key to exit...' || true
    # shellcheck disable=SC3045
    IFS='' read 1>&2 -r -s -n 1 _ || true
    printf 1>&2 '\n' || true
  fi
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
  pause_if_needed
  restore_saved_title_if_exist
  test -n "$2" && exit "$2"
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
# shellcheck disable=SC2034
{
  readonly WGET_CMD='wget'
  readonly DL_UA='Mozilla/5.0 (Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0'
  readonly DL_ACCEPT_HEADER='Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8'
  readonly DL_ACCEPT_ALL_HEADER='Accept: */*'
  readonly DL_ACCEPT_LANG_HEADER='Accept-Language: en-US,en;q=0.5'
  readonly DL_DNT_HEADER='DNT: 1'
  readonly DL_PROT='https://'
}

_uname_saved="$(uname)"
compare_start_uname()
{
  case "${_uname_saved}" in
    "$1"*) return 0 ;; # Found
    *) ;;              # NOT found
  esac
  return 1 # NOT found
}

detect_os_and_other_things()
{
  if test -n "${PLATFORM-}"; then return; fi

  PLATFORM="$(uname | tr -- '[:upper:]' '[:lower:]')"
  IS_BUSYBOX='false'
  PATHSEP=':'
  CYGPATH=''

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
        *) PLATFORM="$(printf '%s\n' "${PLATFORM:?}" | tr -d ':\\/')" || ui_error 'Failed to get uname' ;;
      esac
      ;;
  esac

  # Android identify itself as Linux
  if test "${PLATFORM?}" = 'linux'; then
    case "$(uname 2> /dev/null -a | tr -- '[:upper:]' '[:lower:]')" in
      *' android'* | *'-lineage-'* | *'-leapdroid-'*) PLATFORM='android' ;;
      *) ;;
    esac
  fi

  if test "${PLATFORM:?}" = 'win' && test "${IS_BUSYBOX:?}" = 'true'; then
    PATHSEP=';'
  fi

  if test "${PLATFORM:?}" = 'win' && test "${IS_BUSYBOX:?}" = 'false' && PATH="/usr/bin${PATHSEP:?}${PATH-}" command 1> /dev/null -v 'cygpath'; then
    CYGPATH="$(PATH="/usr/bin${PATHSEP:?}${PATH-}" command -v cygpath)" || ui_error 'Unable to find the path of cygpath'
  fi

  readonly PLATFORM IS_BUSYBOX PATHSEP CYGPATH
}

change_title()
{
  test "${CI:-false}" = 'false' || return 0
  A5K_TITLE_IS_DEFAULT='false'
  A5K_LAST_TITLE="${1:?}"
  printf '\033]0;%s - %s\007\r' "${1:?}" "${MODULE_NAME:?}" && printf '       %*s   %*s    \r' "${#1}" '' "${#MODULE_NAME}" ''
}

set_default_title()
{
  change_title "Command-line: ${CURRENT_SHELL:-${0-}}"
  A5K_TITLE_IS_DEFAULT='true'
}

save_last_title()
{
  A5K_SAVED_TITLE="${A5K_LAST_TITLE-}"
}

restore_saved_title_if_exist()
{
  if test -n "${A5K_SAVED_TITLE-}"; then
    change_title "${A5K_SAVED_TITLE:?}"
    A5K_SAVED_TITLE=''
  fi
}

_update_title()
{
  test "${A5K_TITLE_IS_DEFAULT-}" = 'true' || return 0
  test -t 2 || return 0
  printf 1>&2 '\033]0;%s\007\r' "Command-line: ${1?} - ${MODULE_NAME?}" && printf 1>&2 '    %*s                 %*s \r' "${#1}" '' "${#MODULE_NAME}" ''
}

simple_get_prop()
{
  grep -m 1 -F -e "${1:?}=" "${2:?}" | cut -d '=' -f 2
}

get_domain_from_url()
{
  printf '%s\n' "${1:?}" | cut -d '/' -f '3' -s
}

get_second_level_domain_from_url()
{
  printf '%s\n' "${1:?}" | cut -d '/' -f '3' -s | rev | cut -d '.' -f '-2' -s | rev
}

get_base_url()
{
  echo "${1:?}" | cut -d '/' -f '1,2,3' || return "${?}"
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
  local IFS _line_no _cookie_file _elem

  if test ! -e "${MAIN_DIR:?}/cache/temp/cookies"; then mkdir -p "${MAIN_DIR:?}/cache/temp/cookies" || return "${?}"; fi

  if test "${DL_DEBUG:?}" = 'true'; then
    printf '%s\n' "Set-Cookie: ${2:?}" >> "${MAIN_DIR:?}/cache/temp/cookies/${1:?}.dat.debug"
  fi

  _cookie_file="${MAIN_DIR:?}/cache/temp/cookies/${1:?}.dat"

  IFS=';'
  for _elem in ${2:?}; do
    _elem="${_elem# }"
    IFS='=' read -r name val 0< <(printf '%s\n' "${_elem?}") || return "${?}"
    if test -n "${name?}"; then
      if test -e "${_cookie_file:?}" && _line_no="$(grep -n -F -m 1 -e "${name:?}=" -- "${_cookie_file:?}")" && _line_no="$(printf '%s\n' "${_line_no?}" | cut -d ':' -f '1' -s)" && test -n "${_line_no?}"; then
        sed -i -e "${_line_no:?}d" -- "${_cookie_file:?}" || return "${?}"
      fi
      printf '%s\n' "${name:?}=${val?}" >> "${_cookie_file:?}" || return "${?}"
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
    if test -e "${MAIN_DIR:?}/cache/temp/cookies"; then printf '\n' >> "${MAIN_DIR:?}/cache/temp/cookies/${1:?}.dat.debug"; fi
  fi
}

_load_cookies()
{
  local _domain _cookie_file

  _domain="$(get_domain_from_url "${1:?}")" || return "${?}"
  _cookie_file="${MAIN_DIR:?}/cache/temp/cookies/${_domain:?}.dat"

  if test ! -e "${_cookie_file:?}"; then
    _domain="$(get_second_level_domain_from_url "${1:?}")" || return "${?}"
    _cookie_file="${MAIN_DIR:?}/cache/temp/cookies/${_domain:?}.dat"
    if test ! -e "${_cookie_file:?}"; then return 0; fi
  fi

  while IFS='=' read -r name val; do
    if test -z "${name?}"; then continue; fi
    printf '%s; ' "${name:?}=${val?}"
  done 0< "${_cookie_file:?}" || return "${?}"
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

_parse_webpage_and_get_url()
{
  local _url _referrer _search_pattern
  local _domain _cookies _parsed_code _parsed_url _status

  _url="${1:?}"
  _referrer="${2?}"
  _search_pattern="${3:?}"
  PREVIOUS_URL="${_url:?}"

  _domain="$(get_domain_from_url "${_url:?}")" || return "${?}"
  if _cookies="$(_load_cookies "${_url:?}")"; then _cookies="${_cookies%; }"; else return "${?}"; fi
  _parsed_code=''
  _parsed_url=''
  _status=0

  set -- -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" || return "${?}"
  if test -n "${_referrer?}"; then
    set -- "${@}" --header "Referer: ${_referrer:?}" || return "${?}"
  fi
  if test -n "${_cookies?}"; then
    set -- "${@}" --header "Cookie: ${_cookies:?}" || return "${?}"
  fi

  if test "${DL_DEBUG:?}" = 'true'; then
    ui_debug ''
    ui_debug "URL: ${_url?}"
    ui_debug "  User-Agent: ${DL_UA?}"
    ui_debug "  ${DL_ACCEPT_HEADER?}"
    ui_debug "  ${DL_ACCEPT_LANG_HEADER?}"
    ui_debug "  Referer: ${_referrer?}"
    if test -n "${_cookies?}"; then ui_debug "  Cookie: ${_cookies?}"; fi
    ui_debug ''
  fi

  # shellcheck disable=SC2312
  {
    _parsed_code="$(grep -o -m 1 -e "${_search_pattern:?}")" || _status="${?}"
    if test "${_status:?}" -eq 0; then
      _parsed_url="$(printf '%s\n' "${_parsed_code?}" | grep -o -m 1 -e 'href=".*' | cut -d '"' -f '2' | sed 's/\&amp;/\&/g')" || _status="${?}"
      if test "${DL_DEBUG:?}" = 'true'; then
        ui_debug "Parsed url: ${_parsed_url?}"
        ui_debug "Status: ${_status?}"
      fi
    fi

    if test "${_status:?}" -ne 0 || test -z "${_parsed_url?}"; then
      if test "${DL_DEBUG:?}" = 'true'; then
        ui_error_msg "Webpage parsing failed, error code => ${_status?}"
      fi
      return 1
    fi
  } 0< <("${WGET_CMD:?}" -q -S -O '-' "${@}" -- "${_url:?}" 2> >(_parse_and_store_all_cookies "${_domain:?}" || {
    ui_error_msg "Header parsing failed, error code => ${?}"
    return 2
  }))

  printf '%s\n' "${_parsed_url?}"
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
    set -- "${@}" --header 'Content-Type: text/plain;charset=UTF-8' --header "Content-Length: ${_body_data_length:?}" || return "${?}"
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
  printf '%s\n' "${1?}" | head -n 1 | grep -o -m 1 -e 'HTTP/.*' | cut -d ' ' -f '2' -s
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

  _url="${1:?}"
  _output="${2:?}"
  _method="${3:-GET}"    # Optional (only GET and POST are supported, GET is default)
  _referrer="${4-}"      # Optional
  _origin="${5-}"        # Optional (empty or unset for normal requests but not empty for AJAX requests)
  _authorization="${6-}" # Optional
  _accept="${7-}"        # Optional
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
  "${WGET_CMD:?}" -q -O "${_output:?}" "${@}" -- "${_url:?}"
}

report_failure()
{
  printf 1>&2 '%s - ' "DL type ${1?} failed at '${3:-}' with ret. code ${2?}"
  if test -n "${4:-}"; then printf 1>&2 '\n%s\n' "${4:?}"; fi

  return "${2:?}"
}

report_failure_one()
{
  readonly DL_TYPE_1_FAILED='true'

  #printf '%s - ' "Failed at '${2}' with ret. code ${1:?}"
  if test -n "${3:-}"; then printf '%s\n' "${3:?}"; fi

  return "${1:?}"
}

dl_type_zero()
{
  local _url _output

  clear_previous_url

  _url="${1:?}"
  _output="${2:?}"

  _direct_download "${_url:?}" "${_output:?}" 'GET' ||
    report_failure 0 "${?}" 'dl' || return "${?}"
}

dl_type_one()
{
  if test "${DL_TYPE_1_FAILED:-false}" != 'false'; then return 128; fi
  local _url _base_url _referrer _result

  clear_previous_url

  _base_url="$(get_base_url "${2:?}")" || report_failure_one "${?}" || return "${?}"

  {
    _referrer="${2:?}"
    _url="${1:?}"
  }
  _result="$(_parse_webpage_and_get_url "${_url:?}" "${_referrer:?}" 'downloadButton[^"]*\"\s*href=\"[^"]*\"')" || {
    report_failure_one "${?}" 'get link 1' "${_result:-}" || return "${?}"
  }

  sleep 0.2
  {
    _referrer="${_url:?}"
    _url="${_base_url:?}${_result:?}"
  }
  _result="$(_parse_webpage_and_get_url "${_url:?}" "${_referrer:?}" 'Your\sdownload\swill\sstart\s.*href=\"[^"]*\"')" || {
    report_failure_one "${?}" 'get link 2' "${_result:-}" || return "${?}"
  }

  sleep 0.3
  {
    _referrer="${_url:?}"
    _url="${_base_url:?}${_result:?}"
  }
  _direct_download "${_url:?}" "${3:?}" 'GET' "${_referrer:?}" || {
    report_failure_one "${?}" 'dl' || return "${?}"
  }
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
        report_failure 2 "77" "get location url ${_count:?}" 'THE FILE HAS BEEN DELETED ON THE SERVER!!!'
        return "${?}"
        ;;
      *)
        report_failure 2 "78" "get location url ${_count:?}" "UNSUPPORTED HTTP STATUS CODE: ${_status_code?}"
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
  # DEBUG => echo "${_loc_code:?}"

  sleep 0.2
  _json_response="$(send_web_request_and_output_response "${_base_api_url:?}/accounts" 'POST' "${_base_referrer:?}" "${_base_origin:?}" '' '' '{}')" ||
    report_failure 2 "${?}" 'do AJAX post req' || return "${?}"
  if test "${DL_DEBUG:?}" = 'true'; then printf '%s\n' "${_json_response?}"; fi

  _id_code="$(parse_json_and_retrieve_first_value_by_key "${_json_response:?}" 'id')" ||
    report_failure 2 "${?}" 'parse JSON 1' || return "${?}"
  _token_code="$(parse_json_and_retrieve_first_value_by_key "${_json_response:?}" 'token')" ||
    report_failure 2 "${?}" 'parse JSON 2' || return "${?}"

  sleep 0.2
  _json_response="$(send_web_request_and_output_response "${_base_api_url:?}/accounts/${_id_code:?}" 'GET' "${_base_referrer:?}" "${_base_origin:?}" "Bearer ${_token_code:?}")" ||
    report_failure 2 "${?}" 'do AJAX get req 1' || return "${?}"
  if test "${DL_DEBUG:?}" = 'true'; then printf '%s\n' "${_json_response?}"; fi

  _parse_and_store_cookie "${_second_level_domain:?}" 'account''Token='"${_token_code:?}" ||
    report_failure 2 "${?}" 'set cookie' || return "${?}"

  ### NOTE: This is not required ###
  #sleep 0.2
  #send_web_request_and_no_output "${DL_PROT:?}${_second_level_domain:?}/contents/files.html" 'GET' "${_base_referrer:?}" '' '' 'all' ||
  #  report_failure 2 "${?}" 'do req files.html' || return "${?}"

  sleep 0.2
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

  sleep 0.3
  _direct_download "${_parsed_link:?}" "${_output:?}" 'GET' "${_base_referrer:?}" ||
    report_failure 2 "${?}" 'dl' || return "${?}"
}

dl_file()
{
  if test -e "${MAIN_DIR:?}/cache/$1/$2"; then verify_sha1 "${MAIN_DIR:?}/cache/$1/$2" "$3" || rm -f "${MAIN_DIR:?}/cache/$1/$2"; fi # Preventive check to silently remove corrupted/invalid files

  printf '%s ' "Checking ${2?}..."
  local _status _url _domain
  _status=0
  _url="${DL_PROT:?}${4:?}" || return "${?}"
  _domain="$(get_domain_from_url "${_url:?}")" || return "${?}"

  _clear_cookies || return "${?}"

  if ! test -e "${MAIN_DIR:?}/cache/${1:?}/${2:?}"; then
    mkdir -p "${MAIN_DIR:?}/cache/${1:?}"

    if test "${CI:-false}" = 'false'; then sleep 0.5; else sleep 3; fi
    case "${_domain:?}" in
      *\.'go''file''.io')
        printf '\n %s: ' 'DL type 2'
        dl_type_two "${_url:?}" "${MAIN_DIR:?}/cache/${1:?}/${2:?}" || _status="${?}"
        ;;
      *\.'apk''mirror''.com')
        printf '\n %s: ' 'DL type 1'
        dl_type_one "${_url:?}" "${DL_PROT:?}${_domain:?}/" "${MAIN_DIR:?}/cache/${1:?}/${2:?}" || _status="${?}"
        ;;
      ????*)
        printf '\n %s: ' 'DL type 0'
        dl_type_zero "${_url:?}" "${MAIN_DIR:?}/cache/${1:?}/${2:?}" || _status="${?}"
        ;;
      *)
        ui_error "Invalid download URL => '${_url?}'"
        ;;
    esac

    _clear_cookies || return "${?}"

    if test "${_status:?}" -ne 0; then
      if test -n "${5:-}"; then
        if test "${_status:?}" -eq 128; then
          printf '%s\n' 'Download skipped, trying a mirror...'
        else
          printf '%s\n' 'Download failed, trying a mirror...'
        fi
        dl_file "${1:?}" "${2:?}" "${3:?}" "${5:?}"
        return "${?}"
      else
        printf '%s\n' 'Download failed'
        ui_error "Failed to download the file => 'cache/${1?}/${2?}'"
      fi
    fi
  fi

  verify_sha1 "${MAIN_DIR:?}/cache/$1/$2" "$3" || corrupted_file "${MAIN_DIR:?}/cache/$1/$2"
  printf '%s\n' 'OK'
}

dl_list()
{
  local local_filename local_path dl_hash dl_url dl_mirror
  local _backup_ifs _current_line

  _backup_ifs="${IFS:-}"
  IFS="${NL:?}"

  # shellcheck disable=SC3040,SC2015 # Ignore: In POSIX sh, set option xxx is undefined. / C may run when A is true.
  (set 2> /dev/null +o posix) && set +o posix || true

  for _current_line in ${1?}; do
    IFS='|' read -r local_filename local_path _ _ _ _ dl_hash dl_url dl_mirror _ 0< <(printf '%s\n' "${_current_line:?}") || return "${?}"
    dl_file "${local_path:?}" "${local_filename:?}.apk" "${dl_hash:?}" "${dl_url:?}" "${dl_mirror?}" || return "${?}"
  done || return "${?}"

  # shellcheck disable=SC3040,SC2015 # Ignore: In POSIX sh, set option xxx is undefined. / C may run when A is true.
  (set 2> /dev/null -o posix) && set -o posix || true

  IFS="${_backup_ifs:-}"
}

is_in_path_env()
{
  case "${PATHSEP:?}${PATH-}${PATHSEP:?}" in
    *"${PATHSEP:?}${1:?}${PATHSEP:?}"*) return 0 ;; # Found
    *) ;;
  esac
  return 1 # NOT found
}

add_to_path_env()
{
  if test -n "${CYGPATH?}"; then
    # Only on Bash under Windows
    local _path
    _path="$("${CYGPATH:?}" -u -a -- "${1:?}")" || ui_error 'Unable to convert a path in add_to_path_env()'
    set -- "${_path:?}"
  fi

  if is_in_path_env "${1:?}" || test ! -e "${1:?}"; then return; fi

  if test -z "${PATH-}"; then
    ui_warning 'PATH env is empty'
    PATH="${1:?}"
  else
    PATH="${1:?}${PATHSEP:?}${PATH:?}"
  fi
}

remove_from_path_env()
{
  local _path

  if test -n "${CYGPATH?}"; then
    # Only on Bash under Windows
    local _single_path
    _single_path="$("${CYGPATH:?}" -u -- "${1:?}")" || ui_error 'Unable to convert a path in remove_from_path_env()'
    set -- "${_single_path:?}"
  fi

  if _path="$(printf '%s\n' "${PATH-}" | tr -- "${PATHSEP:?}" '\n' | grep -v -x -F -e "${1:?}" | tr -- '\n' "${PATHSEP:?}")" && _path="${_path%"${PATHSEP:?}"}"; then
    PATH="${_path?}"
  fi
}

move_to_begin_of_path_env()
{
  local _path
  if test ! -e "${1:?}"; then return; fi

  if test -z "${PATH-}"; then
    ui_warning 'PATH env is empty'
    PATH="${1:?}"
  elif _path="$(printf '%s\n' "${PATH:?}" | tr -- "${PATHSEP:?}" '\n' | grep -v -x -F -e "${1:?}" | tr -- '\n' "${PATHSEP:?}")" && _path="${_path%"${PATHSEP:?}"}" && test -n "${_path?}"; then
    PATH="${1:?}${PATHSEP:?}${_path:?}"
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
  # On Bash under Windows (for example the one included inside Git for Windows) we need to move '/usr/bin'
  # before 'C:/Windows/System32' otherwise it will use the find/sort/etc. of Windows instead of the Unix compatible ones.
  if test "${PLATFORM:?}" = 'win' && test "${IS_BUSYBOX:?}" = 'false'; then move_to_begin_of_path_env '/usr/bin'; fi

  if test "${DO_INIT_CMDLINE:-0}" != '0'; then remove_duplicates_from_path_env; fi
  add_to_path_env "${TOOLS_DIR:?}"
}

init_vars()
{
  MODULE_NAME="$(simple_get_prop 'name' "${MAIN_DIR:?}/zip-content/module.prop")" || ui_error 'Failed to parse the module name string'
  readonly MODULE_NAME
  export MODULE_NAME
}

init_cmdline()
{
  unset PROMPT_COMMAND PS1 A5K_SAVED_TITLE CURRENT_SHELL

  CURRENT_SHELL="${0-}"
  test "${IS_BUSYBOX:?}" = 'false' || CURRENT_SHELL="busybox ${CURRENT_SHELL-}"
  test "${#}" -eq 0 || CURRENT_SHELL="${CURRENT_SHELL-}$(printf " \"%s\"" "${@}")"
  readonly CURRENT_SHELL

  A5K_LAST_TITLE="${A5K_LAST_TITLE-}"
  if test "${A5K_TITLE_IS_DEFAULT-}" != 'false'; then set_default_title; fi

  if test "${STARTED_FROM_BATCH_FILE:-0}" != '0' && test -n "${HOME-}"; then
    HOME="$(realpath "${HOME:?}")" || ui_error 'Unable to resolve the home dir'
  fi
  if test -n "${CYGPATH?}" && test -n "${HOME-}"; then
    # Only on Bash under Windows
    HOME="$("${CYGPATH:?}" -u -- "${HOME:?}")" || ui_error 'Unable to convert the home dir'
  fi

  if test "${PLATFORM:?}" = 'win'; then unset JAVA_HOME; fi

  # Clean useless directories from the $PATH env
  if test "${PLATFORM?}" = 'win'; then
    remove_from_path_env "${SYSTEMDRIVE-}/Windows/System32/Wbem"
    remove_from_path_env "${LOCALAPPDATA-}/Microsoft/WindowsApps"
  fi

  # Set environment variables
  UTILS_DIR="${MAIN_DIR:?}/utils"
  UTILS_DATA_DIR="${UTILS_DIR:?}/data"
  readonly UTILS_DIR UTILS_DATA_DIR
  export UTILS_DIR UTILS_DATA_DIR

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
      if AAPT2_PATH="$(find "${ANDROID_SDK_ROOT:?}/build-tools" -iname 'aapt2*' | LC_ALL=C sort -V -r | head -n 1)" && test -n "${AAPT2_PATH?}"; then
        export AAPT2_PATH
        # shellcheck disable=SC2139
        alias 'aapt2'="'${AAPT2_PATH:?}'"
      else
        unset AAPT2_PATH
      fi
    fi
  fi

  add_to_path_env "${UTILS_DIR:?}"
  add_to_path_env "${MAIN_DIR:?}"

  alias 'dir'='ls'
  alias 'cd..'='cd ..'
  alias 'cd.'='cd .'
  alias 'cls'='reset'
  alias 'clear-prev'="printf '\033[A\33[2K\033[A\33[2K\r'"

  if test -f "${MAIN_DIR:?}/includes/custom-aliases.sh"; then
    # shellcheck source=/dev/null
    . "${MAIN_DIR:?}/includes/custom-aliases.sh" || ui_error 'Unable to source includes/custom-aliases.sh'
  fi

  alias build='build.sh'
  if test "${PLATFORM:?}" = 'win' && test "${IS_BUSYBOX:?}" = 'true'; then alias cmdline='cmdline.bat'; else alias cmdline='cmdline.sh'; fi

  if test "${PLATFORM:?}" = 'win'; then
    export BB_FIX_BACKSLASH=1
    export PATHEXT="${PATHEXT:-.BAT};.SH"
  fi

  export A5K_TITLE_IS_DEFAULT
  export A5K_LAST_TITLE

  export PATH_SEPARATOR="${PATHSEP:?}"
  export DIRECTORY_SEPARATOR='/'
  export GRADLE_OPTS="${GRADLE_OPTS:--Dorg.gradle.daemon=false}"

  if test "${CI:-false}" = 'false'; then
    PS1='\[\033[1;32m\]\u\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$' # Escape the colors with \[ \] => https://mywiki.wooledge.org/BashFAQ/053
    PROMPT_COMMAND='_update_title "${CURRENT_SHELL-} (${SHLVL-})"'
  fi
}

if test "${DO_INIT_CMDLINE:-0}" != '0'; then
  # shellcheck disable=SC3040,SC3041,SC2015 # Ignore: In POSIX sh, set option xxx is undefined. / In POSIX sh, set flag -X is undefined. / C may run when A is true.
  {
    # Unsupported set options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue
    (set 2> /dev/null -o posix) && set -o posix || true
    (set 2> /dev/null +H) && set +H || true
    (set 2> /dev/null -o pipefail) && set -o pipefail || true
  }
fi

# Set environment variables
detect_os_and_other_things
export PLATFORM IS_BUSYBOX PATHSEP CYGPATH
init_base
export MAIN_DIR TOOLS_DIR
init_path
init_vars

if test "${DO_INIT_CMDLINE:-0}" != '0'; then
  if test -n "${QUOTED_PARAMS-}" && test "${#}" -eq 0; then eval ' \set' '--' "${QUOTED_PARAMS:?} " || exit 100; fi
  unset DO_INIT_CMDLINE
  unset QUOTED_PARAMS
  if test "${#}" -eq 0; then init_cmdline; else init_cmdline "${@}"; fi
fi

export PATH

if test -n "${ANDROID_SDK_ROOT:-}" && test -e "${ANDROID_SDK_ROOT:?}/emulator/emulator.exe"; then
  # shellcheck disable=SC2139
  {
    alias 'emu'="'${ANDROID_SDK_ROOT:?}/emulator/emulator.exe'"
    alias 'emu-w'="'${ANDROID_SDK_ROOT:?}/emulator/emulator.exe' -writable-system"
  }
fi
