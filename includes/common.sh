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
  if test "${CI:-false}" = 'false' && test "${APP_BASE_NAME:-false}" != 'gradlew' && test "${SHLVL:-1}" = '1' && test -t 0 && test -t 2; then
    printf 1>&2 '\n\033[1;32m%s\033[0m' 'Press any key to exit...' || true
    # shellcheck disable=SC3045
    IFS='' read 1>&2 -r -s -n 1 _ || true
    printf 1>&2 '\n' || true
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

readonly DL_DEBUG='false'
readonly WGET_CMD='wget'
readonly DL_UA='Mozilla/5.0 (Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0'
readonly DL_ACCEPT_HEADER='Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8'
readonly DL_ACCEPT_LANG_HEADER='Accept-Language: en-US,en;q=0.5'
readonly DL_AJAX_ACCEPT_HEADER='Accept: */*'
readonly DL_DNT='DNT: 1'
readonly DL_PROT='https://'

_uname_saved="$(uname)"
compare_start_uname()
{
  case "${_uname_saved}" in
    "$1"*) return 0 ;; # Found
    *) ;;              # NOT found
  esac
  return 1 # NOT found
}

detect_os()
{
  local _os
  _os="$(uname | LC_ALL=C tr '[:upper:]' '[:lower:]' || true)"

  case "${_os?}" in
    'linux') # Returned by both Linux and Android, it will be identified later in the code
      _os='linux'
      ;;
    'android') # Currently never returned, but may be in the future
      _os='android'
      ;;
    'windows'*) # BusyBox-w32 on Windows => Windows_NT (other Windows cases will be detected in the default case)
      _os='win'
      ;;
    'darwin')
      _os='macos'
      ;;
    'freebsd')
      _os='freebsd'
      ;;
    '')
      _os='unknown'
      ;;

    *)
      case "$(uname 2> /dev/null -o | LC_ALL=C tr '[:upper:]' '[:lower:]' || true)" in
        # Output of uname -o:
        # - MinGW => Msys
        # - MSYS => Msys
        # - Cygwin => Cygwin
        # - BusyBox-w32 => MS/Windows
        'msys' | 'cygwin' | 'ms/windows')
          _os='win'
          ;;
        *)
          printf '%s\n' "${_os:?}" | LC_ALL=C tr -d '/' || ui_error 'Failed to get uname'
          return 0
          ;;
      esac
      ;;
  esac

  # Android identify itself as Linux
  if test "${_os?}" = 'linux'; then
    case "$(uname 2> /dev/null -a | LC_ALL=C tr '[:upper:]' '[:lower:]' || true)" in
      *' android'* | *'-lineage-'* | *'-leapdroid-'*)
        _os='android'
        ;;
      *) ;;
    esac
  fi

  printf '%s\n' "${_os:?}"
}

change_title()
{
  if test "${CI:-false}" = 'false'; then printf '\033]0;%s - %s\007\r' "${1:?}" "${MODULE_NAME:?}" && printf '       %*s   %*s    \r' "${#1}" '' "${#MODULE_NAME}" ''; fi
  A5K_LAST_TITLE="${1:?}"
  export A5K_LAST_TITLE
}

save_last_title()
{
  A5K_SAVED_TITLE="${A5K_LAST_TITLE:-}"
  export A5K_SAVED_TITLE
}

restore_saved_title_if_exist()
{
  if test -n "${A5K_SAVED_TITLE:-}"; then
    change_title "${A5K_SAVED_TITLE:?}"
  fi
}

simple_get_prop()
{
  grep -m 1 -F -e "${1:?}=" "${2:?}" | cut -d '=' -f 2
}

get_domain_from_url()
{
  echo "${1:?}" | cut -d '/' -f '3' -s || return "${?}"
}

get_base_url()
{
  echo "${1:?}" | cut -d '/' -f '1,2,3' || return "${?}"
}

_clear_cookies()
{
  rm -f -r "${SCRIPT_DIR:?}/cache/temp/cookies" || return "${?}"
  mkdir -p "${SCRIPT_DIR:?}/cache/temp/cookies" || return "${?}"
}

_parse_and_store_cookie()
{
  local IFS _line_no _cookie_file _elem

  if test "${DL_DEBUG:?}" = 'true'; then
    printf '%s\n' "Set-Cookie: ${2:?}" >> "${SCRIPT_DIR:?}/cache/temp/cookies/${1:?}.dat.debug"
  fi

  _cookie_file="${SCRIPT_DIR:?}/cache/temp/cookies/${1:?}.dat"

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
    printf '\n' >> "${SCRIPT_DIR:?}/cache/temp/cookies/${1:?}.dat.debug"
  fi
}

_load_cookies()
{
  if test ! -e "${SCRIPT_DIR:?}/cache/temp/cookies/${1:?}.dat"; then return 0; fi

  while IFS='=' read -r name val; do
    if test -z "${name?}"; then continue; fi
    printf '%s; ' "${name:?}=${val?}"
  done 0< "${SCRIPT_DIR:?}/cache/temp/cookies/${1:?}.dat" || return "${?}"
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

_parse_webpage_and_get_url()
{
  local _url _referrer _search_pattern
  local _domain _cookies _parsed_code _parsed_url _status

  _url="${1:?}"
  _referrer="${2?}"
  _search_pattern="${3:?}"

  _domain="$(get_domain_from_url "${_url:?}")" || return "${?}"
  _cookies="$(_load_cookies "${_domain:?}")" || return "${?}"
  _cookies="${_cookies%; }" || return "${?}"
  _parsed_code=''
  _parsed_url=''
  _status=0

  set -- -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" --header "${DL_DNT:?}" || return "${?}"
  if test -n "${_referrer?}"; then
    set -- "${@}" --header "Referer: ${_referrer:?}" || return "${?}"
  fi
  if test -n "${_cookies?}"; then
    set -- "${@}" --header "Cookie: ${_cookies:?}" || return "${?}"
  fi

  if test "${DL_DEBUG:?}" = 'true'; then
    ui_debug ''
    ui_debug "URL: ${_url?}"
    ui_debug "User-Agent: ${DL_UA?}"
    ui_debug "${DL_ACCEPT_HEADER?}"
    ui_debug "${DL_ACCEPT_LANG_HEADER?}"
    ui_debug "${DL_DNT?}"
    ui_debug "Referer: ${_referrer?}"
    ui_debug "Cookie: ${_cookies?}"
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
  ui_debug ''
  ui_debug '--------'
  ui_debug "URL: ${1:?}"
  ui_debug 'REQUEST:'
  ui_debug ''
  ui_debug "${2:?} /$(printf '%s\n' "${1:?}" | cut -d '/' -f '4-' -s || true) HTTP/1.1"
  shift 2

  while test "${#}" -gt 0; do
    case "${1?}" in
      -U)
        if test "${#}" -ge 2; then
          shift
          ui_debug "User-Agent: ${1?}"
        fi
        ;;

      --header)
        if test "${#}" -ge 2; then
          shift
          ui_debug "${1?}"
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

  ui_debug '--------'
}

do_AJAX_get_request_and_output_response_to_stdout()
{
  local _url _origin _referrer _authorization
  _url="${1:?}"
  _origin="${2:?}"
  _referrer="${3-}"      # Optional
  _authorization="${4-}" # Optional

  set -- -U "${DL_UA:?}" --header "${DL_AJAX_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" || return "${?}"
  if test -n "${_referrer?}"; then set -- "${@}" --header "Referer: ${_referrer:?}" || return "${?}"; fi
  if test -n "${_authorization?}"; then set -- "${@}" --header "Authorization: ${_authorization:?}" || return "${?}"; fi
  set -- "${@}" --header "Origin: ${_origin:?}" || return "${?}"

  if test "${DL_DEBUG:?}" = 'true'; then dl_debug "${_url:?}" 'GET' "${@}"; fi
  "${WGET_CMD:?}" -q -O '-' "${@}" -- "${_url:?}"
}

do_AJAX_post_request_and_output_response_to_stdout()
{
  local _url _origin _post_data _referrer _authorization
  _url="${1:?}"
  _origin="${2:?}"
  _post_data="${3?}"
  _referrer="${4-}"      # Optional
  _authorization="${5-}" # Optional

  set -- -U "${DL_UA:?}" --header "${DL_AJAX_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" || return "${?}"
  if test -n "${_referrer?}"; then set -- "${@}" --header "Referer: ${_referrer:?}" || return "${?}"; fi
  if test -n "${_authorization?}"; then set -- "${@}" --header "Authorization: ${_authorization:?}" || return "${?}"; fi
  set -- "${@}" --header "Origin: ${_origin:?}" || return "${?}"

  if test "${DL_DEBUG:?}" = 'true'; then dl_debug "${_url:?}" 'POST' "${@}"; fi
  "${WGET_CMD:?}" -q -O '-' "${@}" --post-data "${_post_data?}" -- "${_url:?}"
}

# 1 => JSON response; 2 => Field to get
parse_JSON_response()
{
  printf '%s\n' "${1:?}" | grep -o -m 1 -E -e "\"${2:?}\""'\s*:\s*"[^"]+' | cut -d ':' -f '2-' -s | grep -o -e '".*' | cut -c '2-'
}

retrieve_location_header_from_web_request()
{
  local _url
  _url="${1:?}"

  set -- -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" || return "${?}"

  if test "${DL_DEBUG:?}" = 'true'; then dl_debug "${_url:?}" 'GET' "${@}"; fi
  {
    "${WGET_CMD:?}" 2>&1 --spider -q -S -O '-' "${@}" -- "${_url:?}" || true
  } | grep -o -m 1 -e 'Location:[[:space:]][^[:cntrl:]]*$' | cut -d ':' -f '2-' -s | cut -c '2-'
}

send_empty_web_get_request()
{
  local _url _accept_all _referrer _authorization
  local _accept _domain _cookies

  _url="${1:?}"
  _accept_all="${2-}"    # Optional
  _referrer="${3-}"      # Optional
  _authorization="${4-}" # Optional

  if test "${_accept_all?}" = 'yes'; then _accept="${DL_AJAX_ACCEPT_HEADER:?}"; else _accept="${DL_ACCEPT_HEADER:?}"; fi
  _domain="$(get_domain_from_url "${_url:?}")" || return "${?}"
  _cookies="$(_load_cookies "${_domain:?}")" || return "${?}"
  _cookies="${_cookies%; }" || return "${?}"

  set -- -U "${DL_UA:?}" --header "${_accept:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" || return "${?}"
  if test -n "${_referrer?}"; then set -- "${@}" --header "Referer: ${_referrer:?}" || return "${?}"; fi
  if test -n "${_authorization?}"; then set -- "${@}" --header "Authorization: ${_authorization:?}" || return "${?}"; fi
  if test -n "${_cookies?}"; then set -- "${@}" --header "Cookie: ${_cookies:?}" || return "${?}"; fi

  if test "${DL_DEBUG:?}" = 'true'; then dl_debug "${_url:?}" 'GET' "${@}"; fi
  "${WGET_CMD:?}" --spider -q -O '-' "${@}" -- "${_url:?}"
}

_direct_download()
{
  local _url _referrer _output
  local _domain _cookies _status

  _url="${1:?}"
  _referrer="${2?}"
  _output="${3:?}"

  _domain="$(get_domain_from_url "${_url:?}")" || return "${?}"
  _cookies="$(_load_cookies "${_domain:?}")" || return "${?}"
  _cookies="${_cookies%; }" || return "${?}"
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
    ui_debug "User-Agent: ${DL_UA?}"
    ui_debug "${DL_ACCEPT_HEADER?}"
    ui_debug "${DL_ACCEPT_LANG_HEADER?}"
    ui_debug "Referer: ${_referrer?}"
    ui_debug "Cookie: ${_cookies?}"
    ui_debug ''
  fi

  "${WGET_CMD:?}" -q -O "${_output:?}" "${@}" -- "${_url:?}" || return "${?}"
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
  local _url _referrer _output
  _url="${1:?}" || return "${?}"
  _referrer="${2?}" || return "${?}"
  _output="${3:?}" || return "${?}"

  _direct_download "${_url:?}" "${_referrer?}" "${_output:?}" || report_failure 0 "${?}" 'dl' || return "${?}"
}

dl_type_one()
{
  if test "${DL_TYPE_1_FAILED:-false}" != 'false'; then return 128; fi
  local _url _base_url _referrer _result

  _base_url="$(get_base_url "${2:?}")" || {
    report_failure_one "${?}" || return "${?}"
  }

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
  _direct_download "${_url:?}" "${_referrer:?}" "${3:?}" || {
    report_failure_one "${?}" 'dl' || return "${?}"
  }
}

dl_type_two()
{
  local _url _output
  local _domain _base_dm
  local _base_api_url _base_origin _base_referrer
  local _json_response _location_header _loc_code _id_code _token_code

  _url="${1:?}" || return "${?}"
  _output="${2:?}" || return "${?}"

  _domain="$(get_domain_from_url "${_url:?}")" || report_failure 2 "${?}" || return "${?}"
  _base_dm="$(printf '%s\n' "${_domain:?}" | cut -d '.' -f '2-' -s)" || report_failure 2 "${?}" || return "${?}"

  _base_api_url="${DL_PROT:?}api.${_base_dm:?}"
  _base_origin="${DL_PROT:?}${_base_dm:?}"
  _base_referrer="${_base_origin:?}/"

  _location_header="$(retrieve_location_header_from_web_request "${_url:?}")" ||
    report_failure 2 "${?}" 'get location header 1' 'THE FILE HAS PROBABLY BEEN DELETED ON THE SERVER!!!' || return "${?}"
  # DEBUG => echo "${_location_header:?}"

  if ! printf '%s\n' "${_location_header:?}" | grep -q -m 1 -F -e "${_base_referrer:?}d/"; then
    _location_header="$(retrieve_location_header_from_web_request "${_location_header:?}")" ||
      report_failure 2 "${?}" 'get location header 2' 'THE FILE HAS PROBABLY BEEN DELETED ON THE SERVER!!!' || return "${?}"
    # DEBUG => echo "${_location_header:?}"

    if ! printf '%s\n' "${_location_header:?}" | grep -q -m 1 -F -e "${_base_referrer:?}d/"; then
      _location_header="$(retrieve_location_header_from_web_request "${_location_header:?}")" ||
        report_failure 2 "${?}" 'get location header 3' 'THE FILE HAS PROBABLY BEEN DELETED ON THE SERVER!!!' || return "${?}"
      # DEBUG => echo "${_location_header:?}"

      if ! printf '%s\n' "${_location_header:?}" | grep -q -m 1 -F -e "${_base_referrer:?}d/"; then
        report_failure 2 "77" 'get location header 4' 'THE FILE HAS PROBABLY BEEN DELETED ON THE SERVER!!!' || return "${?}"
      fi
    fi
  fi

  _loc_code="$(printf '%s\n' "${_location_header:?}" | cut -d '/' -f '5-' -s)" ||
    report_failure 2 "${?}" 'get location code' || return "${?}"
  # DEBUG => echo "${_loc_code:?}"

  sleep 0.2
  _json_response="$(do_AJAX_post_request_and_output_response_to_stdout "${_base_api_url:?}/accounts" "${_base_origin:?}" '' "${_base_referrer:?}")" ||
    report_failure 2 "${?}" 'do AJAX post req' || return "${?}"
  # DEBUG => echo "${_json_response:?}"

  _id_code="$(parse_JSON_response "${_json_response:?}" 'id')" ||
    report_failure 2 "${?}" 'parse JSON 1' || return "${?}"
  _token_code="$(parse_JSON_response "${_json_response:?}" 'token')" ||
    report_failure 2 "${?}" 'parse JSON 2' || return "${?}"

  sleep 0.2
  _json_response="$(do_AJAX_get_request_and_output_response_to_stdout "${_base_api_url:?}/accounts/${_id_code:?}" "${_base_origin:?}" "${_base_referrer:?}" "Bearer ${_token_code:?}")" ||
    report_failure 2 "${?}" 'do AJAX get req 1' || return "${?}"
  # DEBUG => echo "${_json_response:?}"

  _parse_and_store_cookie "${_domain:?}" 'account''Token='"${_token_code:?}" ||
    report_failure 2 "${?}" 'set cookie' || return "${?}"

  sleep 0.2
  send_empty_web_get_request "${DL_PROT:?}${_base_dm:?}/contents/files.html" 'yes' "${_base_referrer:?}" ||
    report_failure 2 "${?}" 'do web get req' || return "${?}"

  sleep 0.2
  _json_response="$(do_AJAX_get_request_and_output_response_to_stdout "${_base_api_url:?}/contents/${_loc_code:?}?"'wt''=''4fd6''sg89''d7s6' "${_base_origin:?}" "${_base_referrer:?}" "Bearer ${_token_code:?}")" ||
    report_failure 2 "${?}" 'do AJAX get req 2' || return "${?}"
  # DEBUG => echo "${_json_response:?}"

  sleep 0.3
  _direct_download "${_url:?}" "${_base_referrer:?}" "${_output:?}" ||
    report_failure 2 "${?}" 'dl' || return "${?}"
}

dl_file()
{
  if test -e "${SCRIPT_DIR:?}/cache/$1/$2"; then verify_sha1 "${SCRIPT_DIR:?}/cache/$1/$2" "$3" || rm -f "${SCRIPT_DIR:?}/cache/$1/$2"; fi # Preventive check to silently remove corrupted/invalid files

  printf '%s ' "Checking ${2?}..."
  local _status _url _domain
  _status=0
  _url="${DL_PROT:?}${4:?}" || return "${?}"
  _domain="$(get_domain_from_url "${_url:?}")" || return "${?}"

  _clear_cookies || return "${?}"

  if ! test -e "${SCRIPT_DIR:?}/cache/${1:?}/${2:?}"; then
    mkdir -p "${SCRIPT_DIR:?}/cache/${1:?}"

    if test "${CI:-false}" = 'false'; then sleep 0.5; else sleep 3; fi
    case "${_domain:?}" in
      *\.'go''file''.io')
        printf '\n %s: ' 'DL type 2'
        dl_type_two "${_url:?}" "${SCRIPT_DIR:?}/cache/${1:?}/${2:?}" || _status="${?}"
        ;;
      *\.'apk''mirror''.com')
        printf '\n %s: ' 'DL type 1'
        dl_type_one "${_url:?}" "${DL_PROT:?}${_domain:?}/" "${SCRIPT_DIR:?}/cache/${1:?}/${2:?}" || _status="${?}"
        ;;
      ????*)
        printf '\n %s: ' 'DL type 0'
        dl_type_zero "${_url:?}" "${DL_PROT:?}${_domain:?}/" "${SCRIPT_DIR:?}/cache/${1:?}/${2:?}" || _status="${?}"
        ;;
      *)
        ui_error "Invalid download URL => '${_url?}'"
        ;;
    esac

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

  verify_sha1 "${SCRIPT_DIR:?}/cache/$1/$2" "$3" || corrupted_file "${SCRIPT_DIR:?}/cache/$1/$2"
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

is_in_path()
{
  case "${PATHSEP:?}${PATH-}${PATHSEP:?}" in
    *"${PATHSEP:?}${1:?}${PATHSEP:?}"*) return 0 ;; # Found
    *) ;;
  esac
  return 1 # NOT found
}

add_to_path_env()
{
  if test "${PLATFORM:?}" = 'win' && test "${PATHSEP:?}" = ':' && command 1> /dev/null -v 'cygpath'; then
    # Only on Bash under Windows
    local _path
    _path="$(cygpath -u -a -- "${1:?}")" || ui_error 'Unable to convert a path in add_to_path_env()'
    set -- "${_path:?}"
  fi

  if is_in_path "${1:?}" || test ! -e "${1:?}"; then return; fi

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

  if test "${PLATFORM:?}" = 'win' && test "${PATHSEP:?}" = ':' && command 1> /dev/null -v 'cygpath'; then
    # Only on Bash under Windows
    local _single_path
    _single_path="$(cygpath -u -- "${1:?}")" || ui_error 'Unable to convert a path in remove_from_path_env()'
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

init_vars()
{
  local _main_dir

  # shellcheck disable=SC3028 # Ignore: In POSIX sh, BASH_SOURCE is undefined
  if test -z "${SCRIPT_DIR-}" && test -n "${BASH_SOURCE-}" && _main_dir="$(dirname "${BASH_SOURCE:?}")" && _main_dir="$(realpath "${_main_dir:?}/..")"; then
    SCRIPT_DIR="${_main_dir:?}"
  elif test "${STARTED_FROM_BATCH_FILE:-0}" != '0' && test -n "${SCRIPT_DIR-}"; then
    SCRIPT_DIR="$(realpath "${SCRIPT_DIR:?}")" || ui_error 'Unable to resolve the main script dir'
  fi

  if test "${PLATFORM:?}" = 'win' && test "${PATHSEP:?}" = ':' && command 1> /dev/null -v 'cygpath' && test -n "${SCRIPT_DIR-}"; then
    # Only on Bash under Windows
    SCRIPT_DIR="$(cygpath -m -l -- "${SCRIPT_DIR:?}")" || ui_error 'Unable to convert the main script dir'
  fi

  test -n "${SCRIPT_DIR-}" || ui_error 'SCRIPT_DIR env var is empty'
  TOOLS_DIR="${SCRIPT_DIR:?}/tools/${PLATFORM:?}"
  MODULE_NAME="$(simple_get_prop 'name' "${SCRIPT_DIR:?}/zip-content/module.prop")" || ui_error 'Failed to parse the module name string'
  readonly SCRIPT_DIR TOOLS_DIR MODULE_NAME
  export SCRIPT_DIR TOOLS_DIR MODULE_NAME
}

init_path()
{
  test "${IS_PATH_INITIALIZED:-false}" = 'false' || return
  readonly IS_PATH_INITIALIZED='true'
  if is_in_path "${TOOLS_DIR:?}"; then return; fi

  if test -n "${PATH-}"; then PATH="${PATH%"${PATHSEP:?}"}"; fi

  # On Bash under Windows (for example the one included inside Git for Windows) we need to move '/usr/bin'
  # before 'C:/Windows/System32' otherwise it will use the find/sort/etc. of Windows instead of the Unix compatible ones.
  if test "${PLATFORM:?}" = 'win' && test "${PATHSEP:?}" = ':'; then move_to_begin_of_path_env '/usr/bin'; fi

  remove_duplicates_from_path_env
  add_to_path_env "${TOOLS_DIR:?}"
}

init_cmdline()
{
  change_title 'Command-line'

  if test "${STARTED_FROM_BATCH_FILE:-0}" != '0' && test -n "${HOME-}"; then
    HOME="$(realpath "${HOME:?}")" || ui_error 'Unable to resolve the home dir'
  fi
  if test "${PLATFORM:?}" = 'win' && test "${PATHSEP:?}" = ':' && command 1> /dev/null -v 'cygpath' && test -n "${HOME-}"; then
    # Only on Bash under Windows
    HOME="$(cygpath -u -- "${HOME:?}")" || ui_error 'Unable to convert the home dir'
  fi

  # Set some shell variables
  unset PROMPT_COMMAND
  unset PS1
  PS1='\[\033[1;32m\]\u\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$' # Escape the colors with \[ \] => https://mywiki.wooledge.org/BashFAQ/053
  if test "${PLATFORM:?}" = 'win'; then unset JAVA_HOME; fi

  # Clean useless directories from the $PATH env
  if test "${PLATFORM?}" = 'win'; then
    remove_from_path_env "${SYSTEMDRIVE-}/Windows/System32/Wbem"
    remove_from_path_env "${LOCALAPPDATA-}/Microsoft/WindowsApps"
  fi

  # Set environment variables
  UTILS_DIR="${SCRIPT_DIR:?}/utils"
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
    if test "${PLATFORM:?}" = 'win' && test "${PATHSEP:?}" = ':' && command 1> /dev/null -v 'cygpath'; then
      # Only on Bash under Windows
      ANDROID_SDK_ROOT="$(cygpath -m -l -a -- "${ANDROID_SDK_ROOT:?}")" || ui_error 'Unable to convert the Android SDK dir'
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
  add_to_path_env "${SCRIPT_DIR:?}"

  alias 'dir'='ls'
  alias 'cd..'='cd ..'
  alias 'cd.'='cd .'
  alias 'cls'='reset'

  if test -f "${SCRIPT_DIR:?}/includes/custom-aliases.sh"; then
    # shellcheck source=/dev/null
    . "${SCRIPT_DIR:?}/includes/custom-aliases.sh" || ui_error 'Unable to source includes/custom-aliases.sh'
  fi

  alias build='build.sh'

  if test "${PLATFORM:?}" = 'win'; then
    export BB_FIX_BACKSLASH=1
    export PATHEXT="${PATHEXT:-.BAT};.SH"
  fi

  export PATH_SEPARATOR="${PATHSEP:?}"
  export DIRECTORY_SEPARATOR='/'
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
PLATFORM="$(detect_os)"
PATHSEP=':'
if test "${PLATFORM?}" = 'win' && test "$(uname -o 2> /dev/null | LC_ALL=C tr '[:upper:]' '[:lower:]' || true)" = 'ms/windows'; then
  PATHSEP=';' # BusyBox-w32
fi
readonly PLATFORM PATHSEP
export PLATFORM PATHSEP

init_vars
init_path

if test "${DO_INIT_CMDLINE:-0}" != '0'; then
  unset DO_INIT_CMDLINE
  init_cmdline
fi

export PATH

if test -n "${ANDROID_SDK_ROOT:-}" && test -e "${ANDROID_SDK_ROOT:?}/emulator/emulator.exe"; then
  # shellcheck disable=SC2139
  {
    alias 'emu'="'${ANDROID_SDK_ROOT:?}/emulator/emulator.exe'"
    alias 'emu-w'="'${ANDROID_SDK_ROOT:?}/emulator/emulator.exe' -writable-system"
  }
fi
