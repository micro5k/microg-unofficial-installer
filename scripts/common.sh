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

SCRIPT_DIR="$(realpath "${SCRIPT_DIR:?}")" || return 1 2>&- || exit 1

ui_error()
{
  >&2 echo "ERROR: $1"
  test -n "$2" && exit "$2"
  exit 1
}

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

WGET_CMD='wget'

# 1 => URL; 2 => Referer; 3 => Output
dl_generic()
{
  "${WGET_CMD:?}" -c -O "${3:?}" -U 'Mozilla/5.0 (Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0' --header 'Accept: text/html,*/*;q=0.9' --header 'Accept-Language: en-US,en;q=0.8' --header "Referer: ${2:?}" -- "${1:?}" || return "${?}"
}

# 1 => URL; 2 => Referer; 3 => Pattern
get_link_from_html()
{
  "${WGET_CMD:?}" -q -O- -U 'Mozilla/5.0 (Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0' --header 'Accept: text/html,*/*;q=0.9' --header 'Accept-Language: en-US,en;q=0.8' --header "Referer: ${2:?}" -- "${1:?}" | grep -Eo -e "${3:?}" | grep -Eo -e '\"[^"]+\"$' | tr -d '"' || return "${?}"
}

dl_file()
{
  if test -e "${SCRIPT_DIR:?}/cache/$1/$2"; then verify_sha1 "${SCRIPT_DIR:?}/cache/$1/$2" "$3" || rm -f "${SCRIPT_DIR:?}/cache/$1/$2"; fi  # Preventive check to silently remove corrupted/invalid files

  local _status _url _referrer _result
  _status=0
  _url="${5:?}"

  if ! test -e "${SCRIPT_DIR:?}/cache/$1/$2"; then
    mkdir -p "${SCRIPT_DIR:?}/cache/${1:?}"
    if test "${4?}" = '0'; then
      _referrer='https://duckduckgo.com/'
      dl_generic "${_url:?}" "${_referrer:?}" "${SCRIPT_DIR:?}/cache/${1:?}/${2:?}" || _status="${?}"
    elif test "${4?}" = '1'; then
      _referrer='https://www.apkmirror.com/'
      _result="$(get_link_from_html "${_url:?}" "${_referrer:?}" 'downloadButton.*\"\shref=\"[^"]+\"')" || return "${?}"

      _referrer="${_url:?}"; _url="https://www.apkmirror.com${_result:?}"
      _result="$(get_link_from_html "${_url:?}" "${_referrer:?}" 'Your\sdownload\swill\sstart\s.+href=\"[^"]+\"')" || return "${?}"

      _referrer="${_url:?}"; _url="https://www.apkmirror.com${_result:?}"
      dl_generic "${_url:?}" "${_referrer:?}" "${SCRIPT_DIR:?}/cache/${1:?}/${2:?}" || _status="${?}"
    else
      ui_error "Invalid download type => '${4?}'"
    fi

    if test "${_status:?}" != 0; then
      if test -n "${6:-}"; then
        dl_file "${1:?}" "${2:?}" "${3:?}" '0' "${6:?}"
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
