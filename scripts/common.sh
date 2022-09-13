#!/usr/bin/env bash
# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# shellcheck disable=SC3043
# SC3043: In POSIX sh, local is undefined

if test "${A5K_FUNCTIONS_INCLUDED:-false}" = 'false'; then readonly A5K_FUNCTIONS_INCLUDED=true; fi

# shellcheck disable=SC3040
set -o pipefail

export TZ=UTC
export LC_ALL=C
export LANG=C

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

if test -n "${HOME:-}"; then HOME="$(realpath "${HOME:?}")" || return 1 2>&- || exit 1; fi
SCRIPT_DIR="$(realpath "${SCRIPT_DIR:?}")" || return 1 2>&- || exit 1

ui_error()
{
  >&2 echo "ERROR: $1"
  test -n "$2" && exit "$2"
  exit 1
}

readonly WGET_CMD='wget'
readonly DL_UA='Mozilla/5.0 (Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0'
readonly DL_ACCEPT_HEADER='Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8'
readonly DL_ACCEPT_LANG_HEADER='Accept-Language: en-US,en;q=0.5'
readonly DL_PROTOCOL='https'
readonly DL_WEB_PREFIX='www.'

_uname_saved="$(uname)"
compare_start_uname()
{
  case "${_uname_saved}" in
    "$1"*) return 0;;  # Found
    *)                 # NOT found
  esac
  return 1  # NOT found
}

change_title()
{
  if test "${CI:-false}" = 'false'; then printf '\033]0;%s\007\r' "${1:?}" && printf '%*s     \r' "${#1}" ''; fi
}

simple_get_prop()
{
  grep -F "${1}=" "${2}" | head -n1 | cut -d '=' -f 2
}

get_domain_from_url()
{
  echo "${1:?}" | cut -d '/' -f 3 || return "${?}"
}

get_base_url()
{
  echo "${1:?}" | cut -d '/' -f 1,2,3 || return "${?}"
}

verify_sha1()
{
  local file_name="$1"
  local hash="$2"
  local file_hash

  if test ! -f "${file_name}"; then return 1; fi  # Failed
  file_hash="$(sha1sum "${file_name}" | cut -d ' ' -f 1)"
  if test -z "${file_hash}" || test "${hash}" != "${file_hash}"; then return 1; fi  # Failed
  return 0  # Success
}

corrupted_file()
{
  rm -f -- "$1" || echo 'Failed to remove the corrupted file.'
  ui_error "The file '$1' is corrupted."
}

# 1 => URL; 2 => Referrer; 3 => Output
dl_generic()
{
  "${WGET_CMD:?}" -c -O "${3:?}" -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" --header "Referer: ${2:?}" --no-cache -- "${1:?}" || return "${?}"
}

# 1 => URL; 2 => Referrer; 3 => Pattern
get_link_from_html()
{
  "${WGET_CMD:?}" -q -O- -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" --header "Referer: ${2:?}" -- "${1:?}" | grep -Eo -e "${3:?}" | grep -Eo -e '\"[^"]+\"$' | tr -d '"' || return "${?}"
}

# 1 => URL; 2 => Name to find; 3 => Referrer
get_JSON_value_from_webpage_with_referrer()
{
  "${WGET_CMD:?}" -q -O- -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" --header "Referer: ${3:?}" -- "${1:?}" | grep -Eom 1 -e "\"${2:?}\""'\s*:\s*"([^"]+)' | grep -Eom 1 -e ':\s*"([^"]+)' | grep -Eom 1 -e '"([^"]+)' | cut -c '2-' || return "${?}"
}

# 1 => URL; 2 => Name to find
get_JSON_value_from_webpage()
{
  "${WGET_CMD:?}" -q -O- -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" -- "${1:?}" | grep -Eom 1 -e "\"${2:?}\""'\s*:\s*"([^"]+)' | grep -Eom 1 -e ':\s*"([^"]+)' | grep -Eom 1 -e '"([^"]+)' | cut -c '2-' || return "${?}"
}

# 1 => URL; 2 => Referrer
get_cookies_from_html()
{
  mkdir -p "${TEMP_DIR:?}/dl-temp" || return "${?}"
  "${WGET_CMD:?}" -qS -O "${TEMP_DIR:?}/dl-temp/dummy" -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" --header "Referer: ${2:?}" --keep-session-cookies --save-cookies "${TEMP_DIR:?}/dl-temp/cc.dat" -- "${1:?}" || return "${?}"
}

# 1 => URL; 2 => Cookie; 3 => Output
dl_generic_with_cookie()
{
  "${WGET_CMD:?}" -q -O "${3:?}" -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" --header "Cookie: ${2:?}" -- "${1:?}" || return "${?}"
}

# 1 => URL; 2 => Referrer; 3 => Output
dl_generic_with_cookies()
{
  "${WGET_CMD:?}" -q -O "${3:?}" -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" --header "Referer: ${2:?}" --load-cookies "${TEMP_DIR:?}/dl-temp/cc.dat" -- "${1:?}" || return "${?}"
}

dl_type_one()
{
  local _url _base_url _referrer _result
  _base_url="$(get_base_url "${2:?}")" || return "${?}"

  _referrer="${2:?}"; _url="${1:?}"
  _result="$(get_link_from_html "${_url:?}" "${_referrer:?}" 'downloadButton.*\"\shref=\"[^"]+\"')" || return "${?}"
  sleep 0.2
  _referrer="${_url:?}"; _url="${_base_url:?}${_result:?}"
  _result="$(get_link_from_html "${_url:?}" "${_referrer:?}" 'Your\sdownload\swill\sstart\s.+href=\"[^"]+\"')" || return "${?}"
  sleep 0.2
  _referrer="${_url:?}"; _url="${_base_url:?}${_result:?}"
  dl_generic "${_url:?}" "${_referrer:?}" "${3:?}" || return "${?}"
  sleep 0.2
}

dl_type_two()
{
  local _url _domain

  _url="${1:?}" || return "${?}"
  _domain="$(get_domain_from_url "${_url:?}")" || return "${?}"

  _token="$(get_JSON_value_from_webpage "${DL_PROTOCOL:?}://${_domain:?}/createAccount" 'token')" || return "${?}"
  sleep 0.2
  dl_generic_with_cookie "${_url:?}" 'account''Token='"${_token:?}" "${3:?}" || return "${?}"
  sleep 0.2
}

dl_file()
{
  if test -e "${SCRIPT_DIR:?}/cache/$1/$2"; then verify_sha1 "${SCRIPT_DIR:?}/cache/$1/$2" "$3" || rm -f "${SCRIPT_DIR:?}/cache/$1/$2"; fi  # Preventive check to silently remove corrupted/invalid files

  printf '%s\n' "Downloading ${2:?}..."
  local _status _url _domain
  _status=0
  _url="${DL_PROTOCOL:?}://${4:?}" || return "${?}"
  _domain="$(get_domain_from_url "${_url:?}")" || return "${?}"

  if ! test -e "${SCRIPT_DIR:?}/cache/${1:?}/${2:?}"; then
    mkdir -p "${SCRIPT_DIR:?}/cache/${1:?}"

    case "${_domain:?}" in
      *\.'go''file''.io')
        echo 'DL type 2'
        dl_type_two "${_url:?}" "${DL_PROTOCOL:?}://${_domain:?}/" "${SCRIPT_DIR:?}/cache/${1:?}/${2:?}" || _status="${?}";;
      "${DL_WEB_PREFIX:?}"'apk''mirror''.com')
        echo 'DL type 1'
        dl_type_one "${_url:?}" "${DL_PROTOCOL:?}://${_domain:?}/" "${SCRIPT_DIR:?}/cache/${1:?}/${2:?}" || _status="${?}";;
      ????*)
        echo 'DL type 0'
        dl_generic "${_url:?}" "${DL_PROTOCOL:?}://${_domain:?}/" "${SCRIPT_DIR:?}/cache/${1:?}/${2:?}" || _status="${?}";;
      *)
        ui_error "Invalid download URL => '${_url?}'";;
    esac

    if test "${_status:?}" != 0; then
      if test -n "${5:-}"; then
        printf '%s ' 'Main download failed, trying the mirror...'
        dl_file "${1:?}" "${2:?}" "${3:?}" "${5:?}"
      else
        ui_error "Failed to download the file => 'cache/${1?}/${2?}'"
      fi
    fi
    echo ''
  fi

  verify_sha1 "${SCRIPT_DIR:?}/cache/$1/$2" "$3" || corrupted_file "${SCRIPT_DIR:?}/cache/$1/$2"
}

# Detect OS and set OS specific info
SEP='/'
PATHSEP=':'
_uname_o_saved="$(uname -o)" || ui_error 'Failed to get uname -o'
if compare_start_uname 'Linux'; then
  PLATFORM='linux'
elif compare_start_uname 'Windows_NT' || compare_start_uname 'MINGW32_NT-' || compare_start_uname 'MINGW64_NT-'; then
  PLATFORM='win'
  if test "${_uname_o_saved}" = 'Msys'; then
    :            # MSYS under Windows
  else
    PATHSEP=';'  # BusyBox under Windows
  fi
elif compare_start_uname 'Darwin'; then
  PLATFORM='macos'
#elif compare_start_uname 'FreeBSD'; then
  #PLATFORM='freebsd'
else
  ui_error 'Unsupported OS'
fi

# Set some environment variables
PS1='\[\033[1;32m\]\u\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$'  # Escape the colors with \[ \] => https://mywiki.wooledge.org/BashFAQ/053
PROMPT_COMMAND=

TOOLS_DIR="${SCRIPT_DIR:?}${SEP}tools${SEP}${PLATFORM}"
PATH="${TOOLS_DIR}${PATHSEP}${PATH}"
