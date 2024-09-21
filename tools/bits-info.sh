#!/usr/bin/env sh

# SPDX-FileCopyrightText: (c) 2024 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

# Unsupported set options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue
{
  # shellcheck disable=SC3040,SC2015 # Ignore: In POSIX sh, set option xxx is undefined / C may run when A is true
  (set 2> /dev/null -o pipefail) && set -o pipefail || true
}

convert_max_signed_int_to_bit()
{
  case "${1?}" in
    '32767') printf '%s\n' "16-bit" ;;                                                     # Standard 16-bit limit
    '2147480047') printf '%s\n' "32-bit - 3600" ;;                                         # Standard 32-bit limit - 3600 for timezone diff. on 'date'
    '2147483647') printf '%s\n' "32-bit" ;;                                                # Standard 32-bit limit
    '32535215999') printf '%s\n' "64-bit (with limit: ${1:?})" ;;                          # 64-bit 'date' limited by the OS (likely under Windows)
    '32535244799') printf '%s\n' "64-bit (with limit: ${1:?})" ;;                          # 64-bit 'date' limited by the OS (likely on BusyBox under Windows)
    '67767976233529199') printf '%s\n' "64-bit (with limit: $((${1:?} + 3600)) - 3600)" ;; # 64-bit 'date' limited by the OS - 3600 for timezone diff. (likely on Bash under Windows)
    '67767976233532799') printf '%s\n' "64-bit (with limit: ${1:?})" ;;                    # 64-bit 'date' limited by the OS (likely on Bash under Windows)
    '67768036191673199') printf '%s\n' "64-bit (with Linux date limit - 3600)" ;;          # 64-bit 'date' limited by the OS - 3600 for timezone diff. (likely under Linux)
    '67768036191676799') printf '%s\n' "64-bit (with Linux date limit)" ;;                 # 64-bit 'date' limited by the OS (likely under Linux)
    '9223372036854775807') printf '%s\n' "64-bit" ;;                                       # Standard 64-bit limit
    *)
      printf '%s\n' 'unknown'
      return 1
      ;;
  esac
}

convert_max_unsigned_int_to_bit()
{
  case "${1?}" in
    '65535') printf '%s\n' "16-bit" ;;
    '2147483647') printf '%s\n' "32-bit (with unsigned limit bug)" ;;         # Bugged unsigned 'printf' of awk (seen on some versions fo Bash)
    '2147483648') printf '%s\n' "32-bit (with BusyBox unsigned limit bug)" ;; # Bugged unsigned 'printf' of awk (likely on BusyBox under Windows / Android)
    '4294967295') printf '%s\n' "32-bit" ;;
    '18446744073709551615') printf '%s\n' "64-bit" ;;
    *)
      printf '%s\n' 'unknown'
      return 1
      ;;
  esac
}

permissively_comparison()
{
  local _compare_list _n

  case "${2?}" in
    '9223372036854775807') _compare_list="${2:?} 9223372036854775808" ;;
    '18446744073709551615') _compare_list="${2:?} 1.84467e+19" ;;

    '') return 1 ;;

    *) _compare_list="${2:?}" ;;
  esac

  for _n in ${_compare_list:?}; do
    if test "${1?}" = "${_n:?}"; then
      return 0
    fi
  done

  return 1
}

get_shell_version()
{
  local _shell_exe _shell_version

  if test -n "${KSH_VERSION-}" && _shell_version="${KSH_VERSION:?}"; then
    :
  elif _shell_version="$(eval 2> /dev/null ' echo "${.sh.version}" ')" && test -n "${_shell_version-}"; then
    :
  else

    if test -e "/proc/${$}/exe" && _shell_exe="$(readlink "/proc/${$}/exe")" && test -n "${_shell_exe?}"; then
      :
    elif _shell_exe="${SHELL-}" && test -n "${_shell_exe?}"; then
      :
    else
      printf '%s\n' 'not-found'
      return 1
    fi

    # NOTE: "sh --help" of BusyBox may return failure but still print the correct output although it may be printed to STDERR
    _shell_version="$("${_shell_exe:?}" 2>&1 --help || true)"

    case "${_shell_version?}" in
      '' | *'invalid option'* | *'unrecognized option'* | *'unknown option'*)
        printf '%s\n' 'unknown'
        return 2
        ;;
      *) ;;
    esac

    _shell_version="$(printf '%s\n' "${_shell_version:?}" | head -n 1)" || return "${?}"
  fi

  printf '%s\n' "${_shell_version:?}"
}

get_date_version()
{
  local _date_version

  if ! command 1> /dev/null -v date; then
    printf '%s\n' 'missing'
    return 1
  fi

  # NOTE: "date --help" of BusyBox may return failure but still print the correct output although it may be printed to STDERR
  _date_version="$(date 2> /dev/null --version || date 2>&1 --help || true)"

  case "${_date_version?}" in
    '' | *'invalid option'* | *'unrecognized option'* | *'unknown option'*)
      printf '%s\n' 'unknown'
      return 2
      ;;
    *) ;;
  esac

  printf '%s\n' "${_date_version:?}" | head -n 1
}

main()
{
  local _limits _limits_date _limits_u _max _tmp _n
  local _cpu_bit _os_bit _shell_bit _shell_test_bit _shell_arithmetic_bit _shell_printf_bit _awk_printf_bit _awk_printf_signed_bit _awk_printf_unsigned_bit _date_bit _date_u_bit
  local _date_timezone_bug

  _date_timezone_bug='false'
  _limits='32767 2147483647 9223372036854775807'
  _limits_date='32767 2147480047 2147483647 32535215999 32535244799 67767976233529199 67767976233532799 67768036191673199 67768036191676799 9223372036854775807'
  _limits_u='65535 2147483647 2147483648 4294967295 18446744073709551615'

  if test -e '/proc/cpuinfo' && grep -m 1 -q -e '^flags' -- '/proc/cpuinfo'; then
    if grep -m 1 -q -e '^flags.*[[:space:]][[:lower:]]*_lm' -- '/proc/cpuinfo'; then
      _cpu_bit='64-bit'
    else
      _cpu_bit='32-bit'
    fi
  else
    _cpu_bit='unknown'
  fi

  if command 1> /dev/null -v 'getconf' && _os_bit="$(getconf 'LONG_BIT')" && test -n "${_os_bit?}"; then
    _os_bit="${_os_bit:?}-bit"
  else
    _os_bit='unknown'
  fi

  case "$(uname -m)" in
    x86_64 | x64) _shell_bit='64-bit' ;;
    x86 | i686 | i586 | i486 | i386) _shell_bit='32-bit' ;;
    *) _shell_bit='unknown' ;;
  esac

  _max='-1'
  for _n in ${_limits:?}; do
    if ! test 2> /dev/null "${_n:?}" -gt 0; then break; fi
    _max="${_n:?}"
  done
  _shell_test_bit="$(convert_max_signed_int_to_bit "${_max:?}")" || _shell_test_bit='unknown'

  _max='-1'
  for _n in ${_limits:?}; do
    if test "$((_n))" != "${_n:?}"; then break; fi
    _max="${_n:?}"
  done
  _shell_arithmetic_bit="$(convert_max_signed_int_to_bit "${_max:?}")" || _shell_arithmetic_bit='unknown'

  _shell_printf_bit="$(convert_max_unsigned_int_to_bit "$(printf '%u\n' '-1' || true)")" || _shell_printf_bit='unknown'

  _awk_printf_bit="$(convert_max_unsigned_int_to_bit "$(awk -- 'BEGIN { printf "%u\n", "-1" }' || true)")" || _awk_printf_bit='unknown'

  _max='-1'
  for _n in ${_limits:?}; do
    # IMPORTANT: For very big integer numbers GNU Awk may return the exponential notation or an imprecise number
    if ! _tmp="$(awk -v n="${_n:?}" -- 'BEGIN { printf "%d\n", n }')" || ! permissively_comparison "${_tmp?}" "${_n:?}"; then break; fi
    _max="${_n:?}"
  done
  _awk_printf_signed_bit="$(convert_max_signed_int_to_bit "${_max:?}")" || _awk_printf_signed_bit='unknown'

  _max='-1'
  for _n in ${_limits_u:?}; do
    # IMPORTANT: For very big integer numbers GNU Awk may return the exponential notation or an imprecise number
    if ! _tmp="$(awk -v n="${_n:?}" -- 'BEGIN { printf "%u\n", n }')" || ! permissively_comparison "${_tmp?}" "${_n:?}"; then break; fi
    _max="${_n:?}"
  done
  _awk_printf_unsigned_bit="$(convert_max_unsigned_int_to_bit "${_max:?}")" || _awk_printf_unsigned_bit='unknown'

  _max='-1'
  for _n in ${_limits_date:?}; do
    if ! _tmp="$(TZ='CET-1' date 2> /dev/null -d "@${_n:?}" -- '+%s')"; then break; fi
    if test "${_tmp?}" != "${_n:?}"; then
      if test "${_tmp?}" = "$((${_n:?} - 14400))"; then
        _date_timezone_bug='true'
      else
        break
      fi
    fi
    _max="${_n:?}"
  done
  _date_bit="$(convert_max_signed_int_to_bit "${_max:?}")" || _date_bit='unknown'

  _max='-1'
  for _n in ${_limits_date:?}; do
    if test "$(TZ='CET-1' date 2> /dev/null -u -d "@${_n:?}" -- '+%s' || true)" != "${_n:?}"; then break; fi
    _max="${_n:?}"
  done
  _date_u_bit="$(convert_max_signed_int_to_bit "${_max:?}")" || _date_u_bit='unknown'

  printf '%s %s\n' "Version of shell:" "$(get_shell_version || true)"
  printf '%s\n' "Bits of shell: ${_shell_bit:?}"
  printf '%s\n' "Bits of OS: ${_os_bit:?}"
  printf '%s\n\n' "Bits of CPU: ${_cpu_bit:?}"

  printf '%s\n' "Bits of shell 'test' integer comparison: ${_shell_test_bit:?}"
  printf '%s\n' "Bits of shell arithmetic: ${_shell_arithmetic_bit:?}"
  printf '%s\n\n' "Bits of shell 'printf': ${_shell_printf_bit:?}"

  printf '%s %s\n' "Version of awk:" "$({
    awk 2> /dev/null -Wversion || awk 2> /dev/null --version || awk 2>&1 --help || true
  } | head -n 1 || true)"
  printf '%s\n' "Bits of awk 'printf': ${_awk_printf_bit:?}"
  printf '%s\n' "Bits of awk 'printf' - signed: ${_awk_printf_signed_bit:?}"
  printf '%s\n\n' "Bits of awk 'printf' - unsigned: ${_awk_printf_unsigned_bit:?}"

  printf '%s %s\n' "Version of date:" "$(get_date_version || true)"
  printf '%s%s\n' "Bits of 'date' (CET-1) timestamp: ${_date_bit:?}" "$(test "${_date_timezone_bug:?}" = 'false' || printf '%s\n' ' - TIMEZONE BUG' || true)"
  printf '%s\n' "Bits of 'date -u' timestamp: ${_date_u_bit:?}"
}

main
