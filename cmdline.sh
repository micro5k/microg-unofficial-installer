#!/usr/bin/env bash

# SPDX-FileCopyrightText: (c) 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck enable=all

if test "${A5K_FUNCTIONS_INCLUDED:-false}" = 'false'; then
  main()
  {
    local _main_dir _is_busybox _newline

    _newline='
'

    # Execute only if the first initialization has not already been done
    if test -z "${MAIN_DIR-}" || test -z "${USER_HOME-}"; then

      # Avoid picturesque bugs on Bash under Windows
      if test -e '/usr/bin/uname' && test "$(/usr/bin/uname 2> /dev/null -o || :)" = 'Msys'; then PATH="/usr/bin:${PATH:-/usr/bin}"; fi

      if test -z "${MAIN_DIR-}"; then
        # shellcheck disable=SC3028,SC2128 # Intended: In POSIX sh, BASH_SOURCE is undefined / Expanding an array without an index only gives the first element
        if MAIN_DIR="${BASH_SOURCE-}" && test -n "${MAIN_DIR}"; then
          :
        elif printf '%s\n' "${0-}" | grep -q -m 1 -- 'cmdline.sh$' && MAIN_DIR="${0}"; then
          :
        else MAIN_DIR=''; fi

        if test -n "${MAIN_DIR}" && MAIN_DIR="$(dirname "${MAIN_DIR}")" && MAIN_DIR="$(realpath "${MAIN_DIR}")"; then
          export MAIN_DIR
        else unset MAIN_DIR; fi
      fi

      if test -n "${MAIN_DIR-}" && test -z "${USER_HOME-}"; then
        if test "${TERM_PROGRAM-}" = 'mintty'; then unset TERM_PROGRAM; fi
        export USER_HOME="${HOME-}"
        export HOME="${MAIN_DIR}"
      fi

    fi

    get_shell_exe()
    {
      local _gse_shell_exe _gse_tmp_var

      if _gse_shell_exe="$(readlink 2> /dev/null "/proc/${$}/exe")" && test -n "${_gse_shell_exe}"; then
        # On Linux / Android / Windows (on Windows only some shells support it)
        printf '%s\n' "${_gse_shell_exe}"
        return 0
      elif _gse_tmp_var="$(ps 2> /dev/null -p "${$}" -o 'comm=')" && test -n "${_gse_tmp_var}" && _gse_tmp_var="$(command 2> /dev/null -v "${_gse_tmp_var}")"; then
        # On Linux / macOS
        # shellcheck disable=SC2230 # Ignore: 'which' is non-standard
        test "${_gse_tmp_var}" != 'osh' || _gse_tmp_var="$(which 2> /dev/null "${_gse_tmp_var}")" || return 3 # We may not get the full path with "command -v" on osh
      elif _gse_tmp_var="${BASH:-${SHELL-}}" && test -n "${_gse_tmp_var}"; then
        if test "${_gse_tmp_var}" = '/bin/sh' && test "$(uname 2> /dev/null || :)" = 'Windows_NT'; then _gse_tmp_var="$(command 2> /dev/null -v 'busybox')" || return 2; fi
        if test ! -e "${_gse_tmp_var}" && test -e "${_gse_tmp_var}.exe"; then _gse_tmp_var="${_gse_tmp_var}.exe"; fi # Special fix for broken versions of Bash under Windows
      else
        return 1
      fi

      _gse_shell_exe="$(readlink 2> /dev/null -f "${_gse_tmp_var}" || realpath 2> /dev/null "${_gse_tmp_var}")" || _gse_shell_exe="${_gse_tmp_var}"
      printf '%s\n' "${_gse_shell_exe}"
      return 0
    }

    __SHELL_EXE="$(get_shell_exe)" || __SHELL_EXE='bash'
    export __SHELL_EXE

    _is_busybox='false'
    case "${__SHELL_EXE}" in
      *'/busybox'* | *'/osh' | *'/oil.ovm' | *'/oils-for-unix') _is_busybox='true' ;; # ToDO: Rename '_is_busybox'
      *) ;;
    esac

    export DO_INIT_CMDLINE=1
    unset STARTED_FROM_BATCH_FILE
    unset IS_PATH_INITIALIZED
    unset __QUOTED_PARAMS

    if test -n "${MAIN_DIR-}"; then _main_dir="${MAIN_DIR}"; else _main_dir='.'; fi

    if test "${ONLY_FOR_TESTING-}" = 'true'; then
      printf '%s\n' "${__SHELL_EXE}"
      printf '%s\n' "${_main_dir}"
      if test "${_is_busybox}" = 'true'; then
        "${__SHELL_EXE}" 'sh' "${_main_dir}/includes/common.sh"
      else
        "${__SHELL_EXE}" "${_main_dir}/includes/common.sh"
      fi
    elif test "${_is_busybox}" = 'true'; then
      exec ash -s -c ". '${_main_dir}/includes/common.sh' || exit \${?}" 'ash' "${@}"
    else
      if test "${#}" -gt 0; then
        case "${*}" in
          *"${_newline}"*)
            printf 'WARNING: Newline character found, parameters dropped\n'
            ;;
          *)
            __QUOTED_PARAMS="$(printf '%s\n' "${@}")"
            export __QUOTED_PARAMS
            ;;
        esac
      fi

      exec "${__SHELL_EXE}" --init-file "${_main_dir}/includes/common.sh"
    fi
  }

  if test "${#}" -gt 0; then
    main "${@}"
  else
    main
  fi
fi
