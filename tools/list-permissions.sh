#!/usr/bin/env sh
# SPDX-FileCopyrightText: (c) 2025 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck enable=all

export SCRIPT_NAME='List permissions used by apps'
export SCRIPT_VERSION='0.0.1'

# shellcheck disable=SC3040 # Ignore: In POSIX sh, set option pipefail is undefined
case "$(set 2> /dev/null -o || set || :)" in *'pipefail'*) set -o pipefail || echo 1>&2 'Failed: pipefail' ;; *) ;; esac

main()
{
  test -n "${AAPT2_PATH-}" || AAPT2_PATH="$(command -v 'aapt2')" || AAPT2_PATH='' || :

  if test -n "${AAPT2_PATH?}"; then
    "${AAPT2_PATH:?}" dump permissions "${@}" | grep -F -e 'uses-permission: ' | cut -d ':' -f '2-' -s | cut -b '2-' || return "${?}"
  else
    return 255
  fi
}

main "${@}"
