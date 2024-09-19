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
    '2147483648') printf '%s\n' "32-bit (with BusyBox limit bug)" ;; # Bugged unsigned 'printf' of awk (likely on BusyBox under Windows / Android)
    '4294967295') printf '%s\n' "32-bit" ;;
    '18446744073709551615') printf '%s\n' "64-bit" ;;
    *)
      printf '%s\n' 'unknown'
      return 1
      ;;
  esac
}

main()
{
  local _limits _limits_date _limits_u _max _n
  local _cpu_bit _os_bit _shell_bit _shell_test_bit _shell_arithmetic_bit _shell_printf_bit _awk_printf_bit _awk_printf_signed_bit _awk_printf_unsigned_bit _date_bit _date_u_bit

  _limits='32767 2147483647 9223372036854775807'
  _limits_date='32767 2147480047 2147483647 32535215999 32535244799 67767976233529199 67767976233532799 67768036191673199 67768036191676799 9223372036854775807'
  _limits_u='65535 2147483648 4294967295 18446744073709551615'

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
    if test "$(awk -v n="${_n:?}" -- 'BEGIN { printf "%d\n", n }' || true)" != "${_n:?}"; then break; fi
    _max="${_n:?}"
  done
  _awk_printf_signed_bit="$(convert_max_signed_int_to_bit "${_max:?}")" || _awk_printf_signed_bit='unknown'

  _max='-1'
  for _n in ${_limits_u:?}; do
    if test "$(awk -v n="${_n:?}" -- 'BEGIN { printf "%u\n", n }' || true)" != "${_n:?}"; then break; fi
    _max="${_n:?}"
  done
  _awk_printf_unsigned_bit="$(convert_max_unsigned_int_to_bit "${_max:?}")" || _awk_printf_unsigned_bit='unknown'

  _max='-1'
  for _n in ${_limits_date:?}; do
    if test "$(TZ='CET-1' date 2> /dev/null -d "@${_n:?}" -- '+%s' || true)" != "${_n:?}"; then break; fi
    _max="${_n:?}"
  done
  _date_bit="$(convert_max_signed_int_to_bit "${_max:?}")" || _date_bit='unknown'

  _max='-1'
  for _n in ${_limits_date:?}; do
    if test "$(TZ='CET-1' date 2> /dev/null -u -d "@${_n:?}" -- '+%s' || true)" != "${_n:?}"; then break; fi
    _max="${_n:?}"
  done
  _date_u_bit="$(convert_max_signed_int_to_bit "${_max:?}")" || _date_u_bit='unknown'

  printf '%s\n' "Bits of CPU: ${_cpu_bit:?}"
  printf '%s\n' "Bits of OS: ${_os_bit:?}"
  printf '%s\n\n' "Bits of shell: ${_shell_bit:?}"

  printf '%s\n' "Bits of shell 'test' integer comparison: ${_shell_test_bit:?}"
  printf '%s\n' "Bits of shell arithmetic: ${_shell_arithmetic_bit:?}"
  printf '%s\n' "Bits of shell 'printf': ${_shell_printf_bit:?}"
  printf '%s\n' "Bits of awk 'printf': ${_awk_printf_bit:?}"
  printf '%s\n' "Bits of awk 'printf' - signed: ${_awk_printf_signed_bit:?}"
  printf '%s\n' "Bits of awk 'printf' - unsigned: ${_awk_printf_unsigned_bit:?}"
  printf '%s\n' "Bits of 'date' (CET-1) timestamp: ${_date_bit:?}"
  printf '%s\n' "Bits of 'date -u' timestamp: ${_date_u_bit:?}"
}

main
