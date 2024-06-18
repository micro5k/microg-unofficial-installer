#!/usr/bin/env bash
# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

if test "${A5K_FUNCTIONS_INCLUDED:-false}" = 'false'; then readonly A5K_FUNCTIONS_INCLUDED='true'; fi

# shellcheck disable=SC3040
set -o pipefail || true

export TZ=UTC
export LC_ALL=C
export LANG=C.UTF-8
export LC_CTYPE=UTF-8

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

ui_debug()
{
  printf 1>&2 '%s\n' "${1?}"
}

readonly DL_DEBUG='false'
readonly WGET_CMD='wget'
readonly DL_UA='Mozilla/5.0 (Linux x86_64; rv:115.0) Gecko/20100101 Firefox/115.0'
readonly DL_ACCEPT_HEADER='Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8'
readonly DL_ACCEPT_LANG_HEADER='Accept-Language: en-US,en;q=0.5'
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

# 1 => URL; 2 => Origin header; 3 => Name to find
get_JSON_value_from_ajax_request()
{
  "${WGET_CMD:?}" -qO '-' -U "${DL_UA:?}" --header 'Accept: */*' --header "${DL_ACCEPT_LANG_HEADER:?}" --header "Origin: ${2:?}" --header 'DNT: 1' -- "${1:?}" | grep -Eom 1 -e "\"${3:?}\""'\s*:\s*"([^"]+)' | grep -Eom 1 -e ':\s*"([^"]+)' | grep -Eom 1 -e '"([^"]+)' | cut -c '2-' || return "${?}"
}

# 1 => URL
get_location_header_from_http_request()
{
  {
    "${WGET_CMD:?}" 2>&1 --spider -qSO '-' -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" --header 'DNT: 1' -- "${1:?}" || true
  } | grep -aom 1 -e 'Location:[[:space:]]*[^[:cntrl:]]*$' | head -n '1' || return "${?}"
}

# 1 => URL; # 2 => Origin header
send_empty_ajax_request()
{
  "${WGET_CMD:?}" --spider -qO '-' -U "${DL_UA:?}" --header 'Accept: */*' --header "${DL_ACCEPT_LANG_HEADER:?}" --header "Origin: ${2:?}" --header 'DNT: 1' -- "${1:?}" || return "${?}"
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
  local _loc_code _other_code

  _url="${1:?}" || return "${?}"
  _output="${2:?}" || return "${?}"

  _domain="$(get_domain_from_url "${_url:?}")" || report_failure 2 "${?}" || return "${?}"
  _base_dm="$(printf '%s\n' "${_domain:?}" | cut -d '.' -f '2-' -s)" || report_failure 2 "${?}" || return "${?}"

  _loc_code="$(get_location_header_from_http_request "${_url:?}" | cut -d '/' -f '5-' -s)" ||
    report_failure 2 "${?}" 'get location' || return "${?}"

  sleep 0.2
  _other_code="$(get_JSON_value_from_ajax_request "${DL_PROT:?}api.${_base_dm:?}/createAccount" "${DL_PROT:?}${_base_dm:?}" 'token')" ||
    report_failure 2 "${?}" 'get JSON' || return "${?}"

  sleep 0.2
  send_empty_ajax_request "${DL_PROT:?}api.${_base_dm:?}/getContent?contentId=${_loc_code:?}&token=${_other_code:?}"'&website''Token=''7fd9''4ds1''2fds4' "${DL_PROT:?}${_base_dm:?}" ||
    report_failure 2 "${?}" 'get content' || return "${?}"

  sleep 0.3
  _parse_and_store_cookie "${_domain:?}" 'account''Token='"${_other_code:?}" ||
    report_failure 2 "${?}" 'set cookie' || return "${?}"
  _direct_download "${_url:?}" '' "${_output:?}" ||
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

  # shellcheck disable=SC3040
  set 2> /dev/null +o posix || true

  for _current_line in ${1?}; do
    IFS='|' read -r local_filename local_path _ _ _ _ dl_hash dl_url dl_mirror _ 0< <(printf '%s\n' "${_current_line:?}") || return "${?}"
    dl_file "${local_path:?}" "${local_filename:?}.apk" "${dl_hash:?}" "${dl_url:?}" "${dl_mirror?}" || return "${?}"
  done || return "${?}"

  # shellcheck disable=SC3040
  set 2> /dev/null -o posix || true

  IFS="${_backup_ifs:-}"
}

is_in_path()
{
  case "${PATHSEP:?}${PATH?}${PATHSEP:?}" in
    *"${PATHSEP:?}${1:?}${PATHSEP:?}"*) return 0 ;; # Found
    *) ;;
  esac
  return 1 # NOT found
}

add_to_path()
{
  if test -z "${1?}" || is_in_path "${1:?}" || test ! -e "${1:?}"; then return; fi
  PATH="${1:?}${PATHSEP:?}${PATH?}"
}

init_cmdline()
{
  change_title 'Command-line'

  # Set some environment variables
  PS1='\[\033[1;32m\]\u\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$' # Escape the colors with \[ \] => https://mywiki.wooledge.org/BashFAQ/053
  PROMPT_COMMAND=''

  # Set environment variables
  UTILS_DIR="${SCRIPT_DIR:?}/utils"
  UTILS_DATA_DIR="${UTILS_DIR:?}/data"
  readonly UTILS_DIR UTILS_DATA_DIR
  export UTILS_DIR UTILS_DATA_DIR

  add_to_path "${UTILS_DIR:?}"
  add_to_path "${SCRIPT_DIR:?}"

  if test -n "${HOME-}"; then
    HOME="$(realpath "${HOME:?}")" || ui_error 'Failed to set HOME env var'
    export HOME
  fi

  alias 'dir'='ls'
  alias 'cd..'='cd ..'
  alias 'cd.'='cd .'
  alias 'cls'='reset'
  alias 'profgen'='profile-generator.sh'
  unset JAVA_HOME
}

# Set environment variables
PLATFORM="$(detect_os)"
PATHSEP=':'
if test "${PLATFORM?}" = 'win' && test "$(uname -o 2> /dev/null | LC_ALL=C tr '[:upper:]' '[:lower:]' || true)" = 'ms/windows'; then
  PATHSEP=';' # BusyBox-w32
fi
readonly PLATFORM PATHSEP
export PLATFORM PATHSEP

SCRIPT_DIR="$(realpath "${SCRIPT_DIR:?}")" || ui_error 'Failed to set SCRIPT_DIR env var'
TOOLS_DIR="${SCRIPT_DIR:?}/tools/${PLATFORM:?}"
MODULE_NAME="$(simple_get_prop 'name' "${SCRIPT_DIR:?}/zip-content/module.prop")" || ui_error 'Failed to parse the module name string'
readonly SCRIPT_DIR TOOLS_DIR MODULE_NAME
export SCRIPT_DIR TOOLS_DIR MODULE_NAME

PATH="${PATH%"${PATHSEP:?}"}"
add_to_path "${TOOLS_DIR:?}"

if test "${DO_INIT_CMDLINE:-0}" != '0'; then
  unset DO_INIT_CMDLINE
  init_cmdline
fi

export PATH

# Set the path of Android SDK if not already set
if test -z "${ANDROID_SDK_ROOT:-}" && test -n "${LOCALAPPDATA:-}" && test -e "${LOCALAPPDATA:?}/Android/Sdk"; then
  export ANDROID_SDK_ROOT="${LOCALAPPDATA:?}/Android/Sdk"
fi
if test -n "${ANDROID_SDK_ROOT:-}" && test -e "${ANDROID_SDK_ROOT:?}/emulator/emulator.exe"; then
  # shellcheck disable=SC2139
  {
    alias 'emu'="'${ANDROID_SDK_ROOT:?}/emulator/emulator.exe'"
    alias 'emu-w'="'${ANDROID_SDK_ROOT:?}/emulator/emulator.exe' -writable-system"
  }
fi
