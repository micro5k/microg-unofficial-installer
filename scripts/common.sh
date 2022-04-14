#!/usr/bin/env bash
# shellcheck disable=SC3043

# SC3043: In POSIX sh, local is undefined

# SPDX-FileCopyrightText: (c) 2016-2019, 2021 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

export A5K_FUNCTIONS_INCLUDED=true
readonly A5K_FUNCTIONS_INCLUDED
export TZ=UTC
export LC_ALL=C
export LANG=C

unset LANGUAGE
unset LC_MESSAGES
unset UNZIP
unset UNZIP_OPTS
unset UNZIPOPT
unset JAVA_TOOL_OPTIONS
unset CDPATH

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

simple_get_prop()
{
  grep -F -w "${1}" "${2}" | cut -d '=' -f 2
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
  rm -f "$1" || echo 'Failed to remove the corrupted file.'
  ui_error "The file '$1' is corrupted."
}

WGET_CMD='wget'
dl_file()
{
  if [[ -e "${SCRIPT_DIR}/cache/$1/$2" ]]; then verify_sha1 "${SCRIPT_DIR}/cache/$1/$2" "$3" || rm -f "${SCRIPT_DIR:?}/cache/$1/$2"; fi  # Preventive check to silently remove corrupted/invalid files

  if [[ ! -e "${SCRIPT_DIR}/cache/$1/$2" ]]; then
    mkdir -p "${SCRIPT_DIR}/cache/$1"
    "${WGET_CMD}" -c -O "${SCRIPT_DIR}/cache/$1/$2" -U 'Mozilla/5.0 (X11; Linux x86_64; rv:92.0) Gecko/20100101 Firefox/92.0' "$4" || ( if ! test -z "$5"; then dl_file "$1" "$2" "$3" "$5"; else ui_error "Failed to download the file => 'cache/$1/$2'."; fi )
    echo ''
  fi
  verify_sha1 "${SCRIPT_DIR}/cache/$1/$2" "$3" || corrupted_file "${SCRIPT_DIR}/cache/$1/$2"
}

# Detect OS and set OS specific info
SEP='/'
PATHSEP=':'
if compare_start_uname 'Linux'; then
  PLATFORM='linux'
elif compare_start_uname 'Windows_NT' || compare_start_uname 'MINGW32_NT-' || compare_start_uname 'MINGW64_NT-'; then
  PLATFORM='win'
  if [[ $(uname -o) == 'Msys' ]]; then
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
INIT_DIR=$(pwd)
export INIT_DIR
PS1='\[\033[1;32m\]\u\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$'  # Escape the colors with \[ \] => https://mywiki.wooledge.org/BashFAQ/053
PROMPT_COMMAND=

TOOLS_DIR="${SCRIPT_DIR}${SEP}tools${SEP}${PLATFORM}"
PATH="${TOOLS_DIR}${PATHSEP}${PATH}"
