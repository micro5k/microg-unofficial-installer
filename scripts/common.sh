#!/usr/bin/env bash

export TZ=UTC
export LANG=en_US

unset LANGUAGE
unset LC_ALL
unset UNZIP
unset UNZIP_OPTS
unset UNZIPOPT
unset CDPATH

ui_error()
{
  >&2 echo "ERROR: $1"
  test -n "$2" && exit "$2"
  exit 1
}

UNAME=$(uname)
compare_start_uname()
{
  case "$UNAME" in
    "$1"*) return 0;;  # Found
  esac
  return 1  # NOT found
}

verify_sha1()
{
  local file_name="$1"
  local hash="$2"
  local file_hash=$(sha1sum "$file_name" | cut -d ' ' -f 1)

  if [[ $hash != "$file_hash" ]]; then return 1; fi  # Failed
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
  if [[ ! -e "$SCRIPT_DIR/cache/$1/$2" ]]; then
    mkdir -p "$SCRIPT_DIR/cache/$1"
    "$WGET_CMD" -O "$SCRIPT_DIR/cache/$1/$2" -U 'Mozilla/5.0 (X11; Linux x86_64; rv:63.0) Gecko/20100101 Firefox/63.0' "$4" || ui_error "Failed to download the file => 'cache/$1/$2'."
    echo ''
  fi
  verify_sha1 "$SCRIPT_DIR/cache/$1/$2" "$3" || corrupted_file "$SCRIPT_DIR/cache/$1/$2"
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
export INIT_DIR=$(pwd)
PS1='\[\033[1;32m\]\u\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$'  # Escape the colors with \[ \] => https://mywiki.wooledge.org/BashFAQ/053
PROMPT_COMMAND=

TOOLS_DIR="${SCRIPT_DIR}${SEP}tools${SEP}${PLATFORM}"
PATH="${TOOLS_DIR}${PATHSEP}${PATH}"
