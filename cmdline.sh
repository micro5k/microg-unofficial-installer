#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2016 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later WITH LicenseRef-Archive-packaging-exception
# shellcheck enable=all

# Workaround for shells without support for local (example: ksh pbosh obosh)
command 1> /dev/null 2>&1 -v 'local' || {
  eval ' local() { :; } ' || :
  # On some variants of ksh this really works, but leave the function as dummy fallback
  if command 1> /dev/null 2>&1 -v 'typeset'; then alias 'local'='typeset'; fi
}

if test "${A5K_FUNCTIONS_INCLUDED:-false}" = 'false'; then
  main()
  {
    local _main_dir _run_strategy _shell_name _applet

    # Prioritize POSIX-emulated binaries over Windows natives to prevent hangs and obscure errors
    if test -f '/usr/bin/cygpath' && test "${USR_BIN_FIXED:-0}" = '0'; then
      case "${PATH-}" in '/usr/bin:'*) ;; *) PATH="/usr/bin:${PATH:-%empty}" ;; esac
    fi

    # Execute only if the first initialization has not already been done
    if test -z "${MAIN_DIR-}" || test -z "${USER_HOME-}"; then

      if test -z "${MAIN_DIR-}"; then
        # shellcheck disable=SC3028,SC2128 # Intended: In POSIX sh, BASH_SOURCE is undefined / Expanding an array without an index only gives the first element
        if MAIN_DIR="${BASH_SOURCE-}" && test -n "${MAIN_DIR}"; then :; else MAIN_DIR="${1}"; fi
        case "${MAIN_DIR}" in *'cmdline.sh') ;; *) MAIN_DIR='' ;; esac

        if test -n "${MAIN_DIR}" && MAIN_DIR="$(dirname "${MAIN_DIR}")" && MAIN_DIR="$(realpath "${MAIN_DIR}")"; then export MAIN_DIR; else unset MAIN_DIR; fi
      fi

      if test -n "${MAIN_DIR-}" && test -z "${USER_HOME-}"; then
        if test "${TERM_PROGRAM-}" = 'mintty'; then TERM_PROGRAM='mintty-'; fi
        export USER_HOME="${HOME-}"
        export HOME="${MAIN_DIR}"
      fi

    fi

    shift

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
        case "${_gse_tmp_var}" in *'/'* | *"\\"*) ;; *) _gse_tmp_var="$(which 2> /dev/null "${_gse_tmp_var}")" || return 3 ;; esac # We may not get the full path with "command -v" on some old versions of Oils
      elif _gse_tmp_var="${BASH:-${SHELL-}}" && test -n "${_gse_tmp_var}"; then
        if test "${_gse_tmp_var}" = '/bin/sh' && test "$(uname 2> /dev/null || :)" = 'Windows_NT'; then _gse_tmp_var="$(command 2> /dev/null -v 'busybox')" || return 2; fi
        if test ! -x "${_gse_tmp_var}" && test -x "${_gse_tmp_var}.exe"; then _gse_tmp_var="${_gse_tmp_var}.exe"; fi # Special fix for broken versions of Bash under Windows
      else
        return 1
      fi

      _gse_shell_exe="$(readlink 2> /dev/null -f "${_gse_tmp_var}" || realpath 2> /dev/null "${_gse_tmp_var}")" || _gse_shell_exe="${_gse_tmp_var}"
      printf '%s\n' "${_gse_shell_exe}"
      return 0
    }

    __SHELL_EXE="$(get_shell_exe)" || __SHELL_EXE='unknown'
    export __SHELL_EXE
    unset _gse_shell_exe _gse_tmp_var

    _shell_name="${__SHELL_EXE##*"/"}"
    _shell_name="${_shell_name%".exe"}"
    _applet=''

    case "${_shell_name}" in
      'bash') # Bash
        _run_strategy='init-file'
        ;;
      'busybox') # BusyBox
        _run_strategy='s-option'
        _applet="${CUSTOM_APPLET:-ash}"
        ;;
      'zsh') # Zsh
        _run_strategy='s-option'
        ;;
      'oil.ovm' | 'oils-for-unix') # Oils
        _run_strategy='source'
        _applet="${CUSTOM_APPLET:-osh}"
        ;;
      'osh') # Oils
        _run_strategy='source'
        ;;
      'unknown' | 'fish')
        _run_strategy=''
        printf '%s\n' 'ERROR: Unsupported shell'
        exit 1
        ;;
      *)
        _run_strategy='source'
        printf '%s\n' 'WARNING: Unknown shell'
        ;;
    esac

    if test -n "${MAIN_DIR-}"; then _main_dir="${MAIN_DIR}"; else _main_dir='.'; fi

    if test "${ONLY_FOR_TESTING:-false}" != 'false'; then
      printf '%s\n' "${_shell_name}"
      printf '%s\n' "${__SHELL_EXE}"
      printf '%s\n' "${_main_dir}"
      _run_strategy='source'
    fi

    unset KILL_PPID
    unset STARTED_FROM_BATCH_FILE
    unset IS_PATH_INITIALIZED

    unset PROMPT_COMMAND PS1
    export DO_INIT_CMDLINE=1
    export USING_LIB='main.lib.sh'

    if test "${_run_strategy}" = 'init-file'; then
      # shellcheck disable=SC2086 # IGNORE: Double quote to prevent globbing and word splitting
      exec "${__SHELL_EXE}" --rcfile "${_main_dir}/lib/${USING_LIB}" -i -s -- "${@}"
    elif test "${_run_strategy}" = 's-option'; then
      # shellcheck disable=SC2086 # IGNORE: Double quote to prevent globbing and word splitting
      exec "${__SHELL_EXE}" ${_applet} -i -s -c ". '${_main_dir}/lib/${USING_LIB}' || exit \${?}" "${_applet:-${_shell_name:-unknown}}" "${@}"
    else
      # shellcheck source=SCRIPTDIR/lib/main.lib.sh
      . "${_main_dir}/lib/${USING_LIB}" "${@}" || return "${?}"
    fi
  }

  if test "${#}" -gt 0; then main "${0-}" "${@}"; else main "${0-}"; fi
fi
