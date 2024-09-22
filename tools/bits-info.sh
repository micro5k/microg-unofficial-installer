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
  # More info: https://www.netmeister.org/blog/epoch.html

  case "${1?}" in
    '32767') printf '%s\n' "16-bit" ;;                                                             # Standard 16-bit limit
    '2147480047') printf '%s\n' "32-bit - 3600" ;;                                                 # Standard 32-bit limit - 3600 for timezone diff. on 'date'
    '2147483647') printf '%s\n' "32-bit" ;;                                                        # Standard 32-bit limit
    '32535215999') printf '%s\n' "64-bit (with limit: ${1:?})" ;;                                  # 64-bit 'date' limited by the OS (likely under Windows)
    '32535244799') printf '%s\n' "64-bit (limited by Windows localtime function)" ;;               # 64-bit 'date' limited by the OS (likely on BusyBox under Windows)
    '67767976233529199') printf '%s\n' "64-bit (limited by tzcode bug - 3600)" ;;                  # 64-bit 'date' limited by the OS - 3600 for timezone diff. (likely on Bash under Windows)
    '67767976233532799') printf '%s\n' "64-bit (limited by tzcode bug)" ;;                         # 64-bit 'date' limited by the OS (likely on Bash under Windows)
    '67768036191673199') printf '%s\n' "64-bit (limited by 32-bit tm_year of struct tm - 3600)" ;; # 64-bit 'date' limited by the OS - 3600 for timezone diff. (likely under Linux)
    '67768036191676799') printf '%s\n' "64-bit (limited by 32-bit tm_year of struct tm)" ;;        # 64-bit 'date' limited by the OS (likely under Linux)
    '9223372036854775807') printf '%s\n' "64-bit" ;;                                               # Standard 64-bit limit
    *)
      printf '%s\n' 'unknown'
      return 1
      ;;
  esac

  return 0
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

  return 0
}

permissively_comparison()
{
  local _compare_list _comp_num 2> /dev/null

  case "${2?}" in
    '9223372036854775807') _compare_list="${2:?} 9223372036854775808" ;;
    '18446744073709551615') _compare_list="${2:?} 1.84467e+19" ;;

    '') return 1 ;;

    *) _compare_list="${2:?}" ;;
  esac

  for _comp_num in ${_compare_list:?}; do
    if test "${1?}" = "${_comp_num:?}"; then
      return 0
    fi
  done

  return 1
}

get_shell_info()
{
  local _shell_exe _shell_basename _shell_version 2> /dev/null

  if _shell_exe="$(readlink 2> /dev/null "/proc/${$}/exe")" && test -n "${_shell_exe?}"; then
    :
  elif _shell_exe="${SHELL-}" && test -n "${_shell_exe?}"; then
    :
  else
    printf '%s\n' 'not-found'
    return 1
  fi

  _shell_basename="$(basename "${_shell_exe:?}")" || _shell_basename=''
  _shell_version=''

  case "${_shell_basename?}" in
    *'ksh'*) # For new ksh (ksh93 does NOT show the version in the help)
      _shell_version="${KSH_VERSION-}" ;;
    *) ;;
  esac

  if test -n "${_shell_version?}"; then # Already set, do nothing
    :
  else
    # NOTE: "sh --help" of BusyBox may return failure but still print the correct output although it may be printed to STDERR
    _shell_version="$("${_shell_exe:?}" 2>&1 --help || true)"

    case "${_shell_version?}" in
      '' | *'invalid option'* | *'unrecognized option'* | *'unknown option'* | *[Ii]'llegal option'* | *'not an option'*)
        if test "${_shell_basename?}" = 'dash' && test -n "${DASH_VERSION-}" && _shell_version="${DASH_VERSION:?}"; then # For dash
          :
        elif test "${_shell_basename?}" = 'dash' && command 1> /dev/null -v dpkg; then # For dash
          _shell_version="$(dpkg -l | grep -m 1 -F -e ' dash ' | awk '{ print $3 }')"
        elif test -n "${ZSH_VERSION-}" && _shell_version="${ZSH_VERSION:?}"; then
          :
        elif test -n "${YASH_VERSION-}" && _shell_version="${YASH_VERSION:?}"; then
          :
        elif test -n "${POSH_VERSION-}" && _shell_version="${POSH_VERSION:?}"; then
          :
        elif _shell_version="$(eval 2> /dev/null ' echo "${.sh.version}" ')" && test -n "${_shell_version?}"; then # For old ksh
          :
        elif test -n "${version-}" && _shell_version="${version:?}"; then # For tcsh and fish
          :
        else
          printf '%s\n' 'unknown'
          return 2
        fi
        ;;
      *)
        _shell_version="$(printf '%s\n' "${_shell_version:?}" | head -n 1)" || return "${?}"
        ;;
    esac
  fi

  _shell_version="${_shell_version#Version }"
  case "${_shell_version?}" in
    'BusyBox'*) test "${_shell_basename?}" != 'sh' || _shell_basename='busybox' ;;
    *) ;;
  esac

  printf '%s %s\n' "${_shell_basename:-unknown}" "${_shell_version:?}"
}

get_awk_version()
{
  local _awk_version 2> /dev/null

  if ! command 1> /dev/null -v awk; then
    printf '%s\n' 'missing'
    return 1
  fi

  # NOTE: "awk --help" of BusyBox may return failure but still print the correct output although it may be printed to STDERR
  _awk_version="$(awk 2> /dev/null -Wversion || awk 2> /dev/null --version || awk 2>&1 --help || true)"

  case "${_awk_version?}" in
    '' | *'invalid option'* | *'unrecognized option'* | *'unknown option'* | *[Ii]'llegal option'* | *'not an option'*)
      printf '%s\n' 'unknown'
      return 2
      ;;
    *) ;;
  esac

  printf '%s\n' "${_awk_version:?}" | head -n 1
}

get_date_version()
{
  local _date_version 2> /dev/null

  if ! command 1> /dev/null -v date; then
    printf '%s\n' 'missing'
    return 1
  fi

  # NOTE: "date --help" of BusyBox may return failure but still print the correct output although it may be printed to STDERR
  _date_version="$(date 2> /dev/null --version || date 2>&1 --help || true)"

  case "${_date_version?}" in
    '' | *'invalid option'* | *'unrecognized option'* | *'unknown option'* | *[Ii]'llegal option'* | *'not an option'*)
      printf '%s\n' 'unknown'
      return 2
      ;;
    *) ;;
  esac

  printf '%s\n' "${_date_version:?}" | head -n 1
}

file_getprop()
{
  grep -m 1 -F -e "${1:?}=" -- "${2:?}" | cut -d '=' -f '2-' -s
}

main()
{
  local _date_timezone_bug _limits _limits_date _limits_u _max _n _tmp 2> /dev/null
  local _shell_info _shell_bit _os_bit _cpu_bit _shell_test_bit _shell_arithmetic_bit _shell_printf_bit _awk_printf_bit _awk_printf_signed_bit _awk_printf_unsigned_bit _date_bit _date_u_bit 2> /dev/null

  _date_timezone_bug='false'
  _limits='32767 2147483647 9223372036854775807'
  _limits_date='32767 2147480047 2147483647 32535215999 32535244799 67767976233529199 67767976233532799 67768036191673199 67768036191676799 9223372036854775807'
  _limits_u='65535 2147483647 2147483648 4294967295 18446744073709551615'

  _shell_info="$(get_shell_info)" || _shell_info='unknown unknown'

  if test -e '/proc/cpuinfo' && _tmp="$(grep -e '^flags[[:space:]]*:' -- '/proc/cpuinfo' | cut -d ':' -f '2-' -s)" && test -n "${_tmp?}"; then
    if printf '%s\n' "${_tmp:?}" | grep -m 1 -q -w -e '[[:lower:]]\{1,\}_lm'; then
      _cpu_bit='64-bit'
    else
      _cpu_bit='32-bit'
    fi
  else
    _cpu_bit='unknown'
  fi

  if test "${OS-}" = 'Windows_NT' && _os_bit="${PROCESSOR_ARCHITEW6432:-${PROCESSOR_ARCHITECTURE-}}" && test -n "${_os_bit?}"; then
    # On Windows 2000+ / ReactOS
    case "${_os_bit:?}" in
      AMD64 | ARM64 | IA64) _os_bit='64-bit' ;;
      x86) _os_bit='32-bit' ;;
      *) _os_bit='unknown' ;;
    esac
  elif test -e '/system/build.prop'; then
    # On Android
    case "$(file_getprop 'ro.product.cpu.abi' '/system/build.prop' || true)" in
      'x86_64' | 'arm64-v8a' | 'mips64' | 'riscv64') _os_bit='64-bit' ;;
      'x86' | 'armeabi-v7a' | 'armeabi' | 'mips') _os_bit='32-bit' ;;
      *) _os_bit='unknown' ;;
    esac
  elif command 1> /dev/null -v 'getconf' && _os_bit="$(getconf 'LONG_BIT')" && test -n "${_os_bit?}"; then
    _os_bit="${_os_bit:?}-bit"
  else
    _os_bit='unknown'
  fi

  case "$(uname -m || true)" in
    x64 | x86_64 | aarch64 | ia64) _shell_bit='64-bit' ;;
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

  # IMPORTANT: For very big integer numbers GNU Awk may return the exponential notation or an imprecise number
  _max='-1'
  for _n in ${_limits:?}; do
    if ! _tmp="$(awk -v n="${_n:?}" -- 'BEGIN { printf "%d\n", n }')" || ! permissively_comparison "${_tmp?}" "${_n:?}"; then break; fi
    _max="${_n:?}"
  done
  _awk_printf_signed_bit="$(convert_max_signed_int_to_bit "${_max:?}")" || _awk_printf_signed_bit='unknown'

  # IMPORTANT: For very big integer numbers GNU Awk may return the exponential notation or an imprecise number
  _max='-1'
  for _n in ${_limits_u:?}; do
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

  printf '%s %s\n' "Shell:" "$(printf '%s\n' "${_shell_info:?}" | cut -d ' ' -f '1' || true)"
  printf '%s %s\n' "Shell version:" "$(printf '%s\n' "${_shell_info:?}" | cut -d ' ' -f '2-' -s || true)"
  printf '%s\n' "Bits of shell: ${_shell_bit:?}"
  printf '%s\n' "Bits of OS: ${_os_bit:?}"
  printf '%s\n\n' "Bits of CPU: ${_cpu_bit:?}"

  printf '%s\n' "Bits of shell 'test' int comparison: ${_shell_test_bit:?}"
  printf '%s\n' "Bits of shell arithmetic: ${_shell_arithmetic_bit:?}"
  printf '%s\n\n' "Bits of shell 'printf': ${_shell_printf_bit:?}"

  printf '%s %s\n' "Version of awk:" "$(get_awk_version || true)"
  printf '%s\n' "Bits of awk 'printf': ${_awk_printf_bit:?}"
  printf '%s\n' "Bits of awk 'printf' - signed: ${_awk_printf_signed_bit:?}"
  printf '%s\n\n' "Bits of awk 'printf' - unsigned: ${_awk_printf_unsigned_bit:?}"

  printf '%s %s\n' "Version of date:" "$(get_date_version || true)"
  printf '%s%s\n' "Bits of 'date' (CET-1) timestamp: ${_date_bit:?}" "$(test "${_date_timezone_bug:?}" = 'false' || printf ' %s\n' '(with time zone bug)' || true)"
  printf '%s\n' "Bits of 'date -u' timestamp: ${_date_u_bit:?}"
}

main
