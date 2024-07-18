#!/usr/bin/env bash
# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck enable=all

set -u
# shellcheck disable=SC3040,SC3041,SC2015 # Ignore: In POSIX sh, set option xxx is undefined. / In POSIX sh, set flag -X is undefined. / C may run when A is true.
{
  # Unsupported set options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue
  (set 2> /dev/null -o posix) && set -o posix || true
  (set 2> /dev/null +H) && set +H || true
  (set 2> /dev/null -o pipefail) && set -o pipefail || true
}

if test "${A5K_FUNCTIONS_INCLUDED:-false}" = 'false'; then
  unset STARTED_FROM_BATCH_FILE
  unset IS_PATH_INITIALIZED
  unset TERM_PROGRAM

  if test -z "${SCRIPT_DIR-}"; then
    # shellcheck disable=SC3028 # Ignore: In POSIX sh, BASH_SOURCE is undefined.
    if test -n "${BASH_SOURCE-}" && SCRIPT_DIR="$(dirname "${BASH_SOURCE:?}")" && SCRIPT_DIR="$(realpath "${SCRIPT_DIR:?}")"; then
      export SCRIPT_DIR
    else
      unset SCRIPT_DIR
    fi
  fi

  if test -n "${SCRIPT_DIR-}"; then
    export HOME="${SCRIPT_DIR:?}"

    DO_INIT_CMDLINE=1 bash --init-file "${SCRIPT_DIR:?}/includes/common.sh"
  else
    DO_INIT_CMDLINE=1 bash --init-file './includes/common.sh'
  fi
fi
