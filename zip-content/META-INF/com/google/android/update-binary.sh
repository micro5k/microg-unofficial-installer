#!/sbin/sh
# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined #

echo 'PRE-LOADER' || :

### INIT OPTIONS ###

umask 022 || :
set -u 2> /dev/null || :

# Unsupported set options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue
{
  # shellcheck disable=all
  (set -o pipefail 1> /dev/null 2>&1) && set -o pipefail || :
}

### GLOBAL VARIABLES ###

export ASH_STANDALONE='1'
export OUTFD="${2:?}"
export ZIPFILE="${3:?}"
unset RANDOM_IS_SEEDED

### PREVENTIVE CHECKS ###

command 1> /dev/null -v 'echo' || {
  echo || :
  exit 100
}

command 1> /dev/null -v 'test' || {
  echo 1>&2 'ERROR: Missing => test'
  exit 100
}

case "$(:)" in '') ;; *)
  echo 1>&2 'ERROR: Command substitution NOT supported by your shell'
  exit 100
  ;;
esac

_redirect_command()
{
  eval " ${1:?}() { busybox '${1:?}' \"\${@}\"; } " || {
    echo 1>&2 "ERROR: Replacing ${1?} failed"
    exit 100
  }
}

command 1> /dev/null -v 'printf' || {
  if command 1> /dev/null -v busybox; then
    _redirect_command 'printf'
  else
    {
      printf()
      {
        if test "${1:-}" = '%s\n\n'; then _printf_newline='true'; fi
        if test "${#}" -gt 1; then shift; fi
        echo "${@}"

        test "${_printf_newline:-false}" = 'false' || echo ''
        unset _printf_newline
      }
    }
  fi
}

command 1> /dev/null -v uname || {
  if command 1> /dev/null -v busybox; then
    _redirect_command 'uname'
  elif command 1> /dev/null -v getprop; then
    {
      uname()
      {
        if test "${1:-}" != '-m'; then ui_error 'Unsupported parameters for uname'; fi

        _uname_val="$(getprop 'ro.product.cpu.abi')"
        case "${_uname_val?}" in
          'armeabi-v7a') _uname_val='armv7l' ;;
          'armeabi') _uname_val='armv6l' ;;
          *) ;;
        esac

        printf '%s\n' "${_uname_val?}"
        unset _uname_val
      }
    }
  fi
}

command 1> /dev/null -v 'dirname' || {
  dirname()
  {
    printf '%s\n' "${1%/*}"
  }
}

command 1> /dev/null -v 'unzip' || {
  if command 1> /dev/null -v busybox; then
    _redirect_command 'unzip'
  else
    printf 1>&2 '\033[1;31m%s\033[0m\n' 'ERROR: Missing => unzip'
    exit 100
  fi
}

command 1> /dev/null -v 'grep' || {
  if command 1> /dev/null -v busybox; then _redirect_command 'grep'; fi
}

### FUNCTIONS AND CODE ###

# Detect whether we are in boot mode
_ub_detect_bootmode()
{
  if test -n "${BOOTMODE:-}"; then return; fi
  BOOTMODE=false
  # shellcheck disable=SC2009
  if pgrep -f -x 'zygote' 1> /dev/null 2>&1 || pgrep -f -x 'zygote64' 1> /dev/null 2>&1 || ps | grep 'zygote' | grep -v 'grep' 1> /dev/null || ps -A 2> /dev/null | grep 'zygote' | grep -v 'grep' 1> /dev/null; then
    BOOTMODE=true
  fi
  readonly BOOTMODE
  export BOOTMODE
}

_send_text_to_recovery()
{
  if test "${BOOTMODE:?}" = 'true'; then
    printf '%s\n' "${1?}"
    return
  elif test -e "/proc/self/fd/${OUTFD:?}"; then
    printf 'ui_print %s\nui_print\n' "${1?}" >> "/proc/self/fd/${OUTFD:?}"
  else
    printf 'ui_print %s\nui_print\n' "${1?}" 1>&"${OUTFD:?}"
  fi
}

ui_error()
{
  ERROR_CODE=79
  if test -n "${2:-}"; then ERROR_CODE="${2:?}"; fi
  _send_text_to_recovery "ERROR ${ERROR_CODE:?}: ${1:?}"
  printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR ${ERROR_CODE:?}: ${1:?}"
  abort '' 2> /dev/null || exit "${ERROR_CODE:?}"
}

set_perm()
{
  local uid="${1:?}"
  local gid="${2:?}"
  local mod="${3:?}"
  shift 3
  test -n "${*}" || ui_error "Missing parameter on set_perm: $*"
  chown "${uid:?}:${gid:?}" "${@}" || chown "${uid:?}.${gid:?}" "${@}" || ui_error "chown failed on: $*"
  chmod "${mod:?}" "${@}" || ui_error "chmod failed on: $*"
}

package_extract_file()
{
  unzip -opq "${ZIPFILE:?}" "${1:?}" 1> "${2:?}" || ui_error "Failed to extract the file '${1}' from this archive"
  if ! test -e "${2:?}"; then ui_error "Failed to extract the file '${1}' from this archive"; fi
}

generate_awk_random_seed()
{
  local _seed _pid

  # IMPORTANT: On old versions of awk the maximum value of seed is 4294967295 (2^32 − 1); if you exceed the maximum then awk always returns the same random number (which is no longer random)

  if _seed="$(LC_ALL=C date 2> /dev/null -u -- '+%N')" && test -n "${_seed?}" && test "${_seed:?}" != 'N'; then
    echo "${_seed:?}"
  elif command 1> /dev/null -v tail && _pid="$(echo "${$:?}" | tail -c 5)" && LC_ALL=C date 2> /dev/null -u -- "+%-I%M%S${_pid:?}"; then # tail -c 5 => Last 4 bytes + '\n'
    echo 1>&2 'Seed: using unsafe seed'
  else
    return 1
  fi
}

generate_random()
{
  local _seed

  if test "${RANDOM_IS_SEEDED:-false}" = 'false'; then
    # Seed the RANDOM variable
    RANDOM="${$:?}"
    readonly RANDOM_IS_SEEDED='true'
  fi

  # shellcheck disable=SC3028
  LAST_RANDOM="${RANDOM-}"

  if test -n "${LAST_RANDOM?}" && test "${LAST_RANDOM:?}" != "${$:?}"; then
    : # OK
  elif command 1> /dev/null -v shuf && LAST_RANDOM="$(shuf -n '1' -i '0-99999')"; then
    : # OK
  elif command 1> /dev/null -v hexdump && test -e '/dev/urandom' && LAST_RANDOM="$(hexdump -v -n '2' -e '1/2 "%u"' -- '/dev/urandom')"; then
    echo 'Random: using hexdump' # OK
  elif command 1> /dev/null -v awk && command 1> /dev/null -v date && _seed="$(generate_awk_random_seed)" && test -n "${_seed?}" && LAST_RANDOM="$(awk -v seed="${_seed:?}" -- 'BEGIN { srand(seed); print int( rand()*(99999+1) ) }')"; then
    echo 'Random: using awk' # OK
  elif test -e '/dev/urandom' && command 1> /dev/null -v tr && command 1> /dev/null -v head && LAST_RANDOM="$(tr 0< '/dev/urandom' -d -c '[:digit:]' | head -c 5 || true)" 2> /dev/null && test -n "${LAST_RANDOM?}"; then
    echo 'Random: using tr/head' # OK
  else
    LAST_RANDOM=''
    ui_error 'Unable to generate a random number'
  fi
}

_ub_detect_bootmode
DELETE_TMP=0
UNMOUNT_TMP=0

__is_mounted()
{
  local _mount_result
  {
    test -f '/proc/mounts' && _mount_result="$(cat /proc/mounts)"
  } || _mount_result="$(mount 2> /dev/null)" || ui_error '__is_mounted has failed'

  # IMPORTANT: Some limited shells does NOT support character classes like [[:blank:]], so avoid using them in "case"
  case "${_mount_result:?}" in
    *\ "${1:?}"\ *) return 0 ;; # Mounted
    *) ;;                       # NOT mounted
  esac
  return 1 # NOT mounted
}

# Workaround: Manually set a temp folder if there isn't one ready already

if test -n "${TMPDIR-}" && test "${TMPDIR:?}" != '/data/local' && test -d "${TMPDIR:?}" && test -w "${TMPDIR:?}"; then
  : # Already ready
elif test -d '/tmp'; then
  TMPDIR='/tmp'
elif test -d '/dev' && __is_mounted '/dev'; then
  mkdir -p '/dev/tmp' || ui_error 'Failed to create the temp folder => /dev/tmp'
  set_perm 0 2000 01775 '/dev/tmp'

  TMPDIR='/dev/tmp'
else
  _send_text_to_recovery 'WARNING: Creating the temp folder...'
  printf 1>&2 '\033[0;33m%s\033[0m\n' 'WARNING: Creating the temp folder...'
  mkdir -p '/tmp' || ui_error 'Failed to create the temp folder => /tmp'
  DELETE_TMP=1
  set_perm 0 0 0755 '/tmp'

  TMPDIR='/tmp'
fi

if test "${TMPDIR:?}" = '/tmp'; then
  __is_mounted '/tmp' || {
    _send_text_to_recovery 'WARNING: Mounting the temp folder...'
    printf 1>&2 '\033[0;33m%s\033[0m\n' 'WARNING: Mounting the temp folder...'

    mount -t 'tmpfs' -o 'rw' tmpfs '/tmp' || ui_error 'Failed to mount the temp folder => /tmp'
    UNMOUNT_TMP=1
    __is_mounted '/tmp' || ui_error 'The temp folder CANNOT be mounted => /tmp'
    set_perm 0 2000 01775 '/tmp'
  }
fi

test -w "${TMPDIR:?}" || ui_error "The temp folder is NOT writable => ${TMPDIR?}"
export TMPDIR

generate_random
_ub_our_main_script="${TMPDIR:?}/${LAST_RANDOM:?}-customize.sh"

STATUS=1
UNKNOWN_ERROR=1

package_extract_file 'customize.sh' "${_ub_our_main_script:?}"

echo "Loading ${LAST_RANDOM:?}-customize.sh..."
# shellcheck source=SCRIPTDIR/../../../../customize.sh
command . "${_ub_our_main_script:?}" || ui_error "Failed to source '${_ub_our_main_script?}'"

if test -f "${_ub_our_main_script:?}"; then
  rm "${_ub_our_main_script:?}" || ui_error "Failed to delete '${_ub_our_main_script?}'"
fi
unset _ub_our_main_script

if test -d '/tmp'; then
  if test "${UNMOUNT_TMP:?}" = '1'; then umount '/tmp' || ui_error 'Failed to unmount the temp folder => /tmp'; fi
  # NOTE: Legacy versions of rmdir don't accept any parameter (not even --)
  if test "${DELETE_TMP:?}" = '1'; then rmdir '/tmp' || ui_error 'Failed to delete the temp folder => /tmp'; fi
fi

case "${STATUS?}" in
  '0') # Success
    test "${UNKNOWN_ERROR:?}" -eq 0 || ui_error 'Installation failed with an unknown error' ;;
  '250') # TEST mode
    ui_msg 'TEST mode completed!' ;;
  *) # Failure
    ui_error "Installation script failed" "${STATUS:?}" ;;
esac
