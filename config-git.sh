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

  if git config set --local "${1:?}" "${2:?}"; then
    printf '%s\n' 'OK'
  else
    _status="${?}"
    printf '%s\n' 'Error'
    return "${_status:?}"
  fi
}

STATUS=0

printf '%s\n' "Repo dir: ${PWD?}" || STATUS="${?}"

# shellcheck disable=SC2319
config_var gpg.ssh.allowedSignersFile 'allowed_signers' "$(test -f "${PWD:?}/allowed_signers"; printf '%s\n' "${?}")" || STATUS="${?}"
config_var core.hooksPath '.git-hooks' "$(test -d "${PWD:?}/.git-hooks"; printf '%s\n' "${?}")" || STATUS="${?}"
config_var format.signOff "true" || STATUS="${?}"
config_var alias.cm 'commit -s' || STATUS="${?}"

test "${STATUS:?}" = 0 || printf '%s\n' "Error code: ${STATUS:?}"

pause_if_needed "${STATUS:?}"
exit "${?}"
