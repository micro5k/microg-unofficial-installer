#!/usr/bin/env sh
# SPDX-FileCopyrightText: NONE
# SPDX-License-Identifier: CC0-1.0

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

config_var()
{
  printf '%s' "Configuring ${1:?}: "

  if test -n "${3-}" && test "${3:?}" != 0; then
    printf '%s\n' 'Missing'
    return 44
  fi

  if HOME="${USER_HOME:-${HOME:?}}" git config set --local "${1:?}" "${2:?}"; then
    printf '%s\n' 'OK'
  else
    _status="${?}"
    printf '%s\n' 'Error'
    return "${_status:?}"
  fi
}

import_gpg_keys()
{
  printf '%s' "Importing ${1:?} public keys: "

  if test -n "${3-}" && test "${3:?}" != 0; then
    printf '%s\n' 'Missing'
    return 44
  fi

  if HOME="${USER_HOME:-${HOME:?}}" gpg 2> /dev/null --import -- "${2:?}"; then
    printf '%s\n' 'OK'
  else
    _status="${?}"
    printf '%s\n' 'Error'
    return "${_status:?}"
  fi
}

setup_gpg()
{
  command 1> /dev/null -v 'gpg' || {
    printf '%s\n' 'WARNING: gpg is missing'
    return 255
  }

  # GitHub => https://github.com/web-flow.gpg
  test -f "${PWD:?}/.public-keys/github.gpg"
  import_gpg_keys 'GitHub' "${PWD:?}/.public-keys/github.gpg" "${?}" || return "${?}"
  printf '%s\n' '968479A1AFF927E37D1A566BB5690EEEBB952194:6:' | HOME="${USER_HOME:-${HOME:?}}" gpg --import-ownertrust || return "${?}"
}

STATUS=0

printf '%s\n' "Repo dir: ${PWD?}" || STATUS="${?}"

test -f "${PWD:?}/allowed_signers"
config_var gpg.ssh.allowedSignersFile 'allowed_signers' "${?}" || STATUS="${?}"

setup_gpg || STATUS="${?}"

test -d "${PWD:?}/.git-hooks"
config_var core.hooksPath '.git-hooks' "${?}" || STATUS="${?}"

config_var format.signOff "true" || STATUS="${?}"
config_var alias.cm 'commit -s' || STATUS="${?}"

test "${STATUS:?}" = 0 || printf '%s\n' "Error code: ${STATUS:?}"

pause_if_needed "${STATUS:?}"
exit "${?}"
