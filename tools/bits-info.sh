#!/usr/bin/env sh

# SPDX-FileCopyrightText: (c) 2024 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

set -u || true
setopt 2> /dev/null SH_WORD_SPLIT || true

convert_max_signed_int_to_bit()
{
  # More info: https://www.netmeister.org/blog/epoch.html

  case "${1?}" in
    '32767') printf '%s\n' "16-bit" ;;                                                      # Standard 16-bit limit
    '2147480047') printf '%s\n' "32-bit - 3600" ;;                                          # Standard 32-bit limit - 3600 for timezone diff. on 'date'
    '2147483647') printf '%s\n' "32-bit" ;;                                                 # Standard 32-bit limit
    '32535215999') printf '%s\n' "64-bit (with limit: ${1:?})" ;;                           # 64-bit 'date' limited by the OS (likely under Windows)
    '32535244799') printf '%s\n' "64-bit (limited by Windows localtime function)" ;;        # 64-bit 'date' limited by the OS (likely on BusyBox under Windows)
    '67767976233529199') printf '%s\n' "64-bit (limited by tzcode bug - 3600)" ;;           # 64-bit 'date' limited by the OS - 3600 for timezone diff. (likely on Bash under Windows)
    '67767976233532799') printf '%s\n' "64-bit (limited by tzcode bug)" ;;                  # 64-bit 'date' limited by the OS (likely on Bash under Windows)
    '67768036191673199') printf '%s\n' "64-bit (limited by 32-bit tm_year of tm - 3600)" ;; # 64-bit 'date' limited by the OS - 3600 for timezone diff. (likely under Linux)
    '67768036191676799') printf '%s\n' "64-bit (limited by 32-bit tm_year of tm)" ;;        # 64-bit 'date' limited by the OS (likely under Linux)
    '9223372036854775807') printf '%s\n' "64-bit" ;;                                        # Standard 64-bit limit
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
  local _comp_list _comp_num 2> /dev/null

  case "${2?}" in
    '') return 1 ;;
    '9223372036854775807') _comp_list="${2:?} 9223372036854775808" ;;
    '18446744073709551615') _comp_list="${2:?} 1.84467e+19" ;;
    *) _comp_list="${2:?}" ;;
  esac

  for _comp_num in ${_comp_list:?}; do
    if test "${1?}" = "${_comp_num:?}"; then
      return 0
    fi
  done

  return 1
}

get_shell_info()
{
  local _shell_use_ver_opt _shell_exe _shell_name _shell_version 2> /dev/null

  _shell_use_ver_opt='false'
  _shell_version=''

  if _shell_exe="$(readlink 2> /dev/null "/proc/${$}/exe")" && test -n "${_shell_exe?}"; then
    :
  elif _shell_exe="${BASH:-${SHELL-}}" && test -n "${_shell_exe?}"; then
    :
  else
    printf '%s\n' 'not-found unknown'
    return 1
  fi

  _shell_name="$(basename "${_shell_exe:?}")" || _shell_name=''

  # NOTE: Fish is intentionally not POSIX-compatible so this function may not work on it

  case "${_shell_exe:?}" in
    *'/bosh/'*) _shell_name='bosh' ;;
    *) ;;
  esac

  case "${_shell_name?}" in
    *'ksh'*) _shell_version="${KSH_VERSION-}" ;;     # For new ksh (do NOT show the version in the help)
    *'zsh'* | *'yash'*) _shell_use_ver_opt='true' ;; # For zsh and yash (do NOT show the version in the help)
    *'\bash.exe') _shell_name='bash' ;;              # Fix for a basename bug on old Bash under Windows
    *) ;;
  esac

  if test -n "${_shell_version?}"; then
    : # Already set, do nothing
  else
    # Many shells doesn't support '--version' and in addition some bugged versions of BusyBox open an interactive shell when the --version option is used,
    # so use it only when really needed
    if test "${_shell_use_ver_opt:?}" = 'true' && _shell_version="$("${_shell_exe:?}" 2>&1 --version)" && test -n "${_shell_version?}"; then
      :
    else
      # NOTE: "sh --help" of BusyBox may return failure but still print the correct output although it may be printed to STDERR
      _shell_version="$("${_shell_exe:?}" 2>&1 --help || true)"
    fi

    case "${_shell_version?}" in
      '' | *'invalid option'* | *'unrecognized option'* | *'unknown option'* | *[Ii]'llegal option'* | *'not an option'* | *'bad option'* | *'command not found'* | *'No such file or directory'*)
        if test "${_shell_name?}" = 'dash' && command 1> /dev/null 2>&1 -v 'dpkg' && _shell_version="$(dpkg -s 'dash' | grep -m 1 -F -e 'Version:' | cut -d ':' -f '2-' -s)"; then
          : # For dash
        elif test "${_shell_name?}" = 'dash' && test -n "${DASH_VERSION-}" && _shell_version="${DASH_VERSION:?}"; then
          : # For dash (possibly supported in the future)
        elif test "${_shell_name?}" = 'dash' && command 1> /dev/null 2>&1 -v 'apt-cache' && _shell_version="$(apt-cache policy 'dash' | grep -m 1 -F -e 'Installed:' | cut -d ':' -f '2-' -s)"; then
          : # For dash (it is slow)
        elif test "${_shell_name?}" = 'posh' && test -n "${POSH_VERSION-}" && _shell_version="${POSH_VERSION:?}"; then
          : # For posh (need test)
        elif _shell_version="$(eval 2> /dev/null ' echo "${.sh.version}" ')" && test -n "${_shell_version?}"; then
          : # For ksh and bosh
        elif test -n "${version-}" && _shell_version="${version:?}"; then
          : # For tcsh and fish (need test)
        else
          _shell_version=''
        fi
        ;;
      *)
        _shell_version="$(printf '%s\n' "${_shell_version:?}" | head -n 1)" || return "${?}"
        ;;
    esac
  fi

  _shell_version="${_shell_version#[Vv]ersion }"
  case "${_shell_version?}" in
    'BusyBox'*)
      if test -z "${_shell_name?}" || test "${_shell_name:?}" = 'sh'; then _shell_name='busybox'; fi
      _shell_version="${_shell_version#BusyBox}"
      ;;
    *)
      test -z "${_shell_name?}" || _shell_version="${_shell_version#"${_shell_name:?}"}"
      ;;
  esac
  _shell_version="${_shell_version# }"

  printf '%s %s\n' "${_shell_name:-unknown}" "${_shell_version:-unknown}"
}

get_applet_name()
{
  local _shell_cmdline _current_applet 2> /dev/null

  case "${1?}" in
    *'busybox'*)
      if _shell_cmdline="$(tr 2> /dev/null -- '\0' ' ' 0< "/proc/${$}/cmdline")" && test -n "${_shell_cmdline?}"; then
        for _current_applet in ash hush msh lash bash sh; do
          if printf '%s\n' "${_shell_cmdline:?}" | grep -m 1 -q -w -e "${_current_applet:?}"; then
            printf '%s\n' "${_current_applet:?}"
            return 0
          fi
        done
      fi
      ;;
    *)
      printf '%s\n' 'not-busybox'
      return 1
      ;;
  esac

  printf '%s\n' 'unknown'
  return 2
}

get_os_info()
{
  local _os_name _os_version 2> /dev/null

  # Bugged versions of uname may return errors on STDOUT when used with unsupported options
  _os_name="$(uname 2> /dev/null -o)" || _os_name="$(uname 2> /dev/null)" || _os_name=''
  _os_version=''

  case "${_os_name?}" in
    'MS/Windows')
      _os_version="$(uname -r -v | tr -- ' ' '.' || true)"
      ;;
    'Msys')
      _os_name='MS/Windows'
      _os_version="$(uname | cut -d '-' -f '2-' -s | tr -- '-' '.' || true)"
      ;;
    'Windows_NT') # Bugged versions of uname: it doesn't support uname -o and it is unable to retrieve the version of Windows
      _os_name='MS/Windows'
      ;;
    'GNU/Linux')
      if _os_version="$(getprop 2> /dev/null 'ro.build.version.release')" && test -n "${_os_version?}"; then
        _os_name='Android'
      else
        _os_version="$(uname 2> /dev/null -r || true)"
      fi
      ;;
    *)
      _os_version="$(uname 2> /dev/null -r)" || _os_version=''
      ;;
  esac

  printf '%s %s\n' "${_os_name:-unknown}" "${_os_version:-unknown}"
}

get_awk_version()
{
  local _awk_version 2> /dev/null

  if ! command 1> /dev/null 2>&1 -v awk; then
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

  if ! command 1> /dev/null 2>&1 -v date; then
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
  local date_timezone_bug _limits _limits_date _limits_u _max _n tmp_var 2> /dev/null
  local shell_info shell_name shell_applet shell_bit os_bit cpu_bit _shell_test_bit _shell_arithmetic_bit _shell_printf_bit _awk_printf_bit _awk_printf_signed_bit _awk_printf_unsigned_bit _date_bit _date_u_bit 2> /dev/null

  date_timezone_bug='false'
  _limits='32767 2147483647 9223372036854775807'
  _limits_date='32767 2147480047 2147483647 32535215999 32535244799 67767976233529199 67767976233532799 67768036191673199 67768036191676799 9223372036854775807'
  _limits_u='65535 2147483647 2147483648 4294967295 18446744073709551615'

  shell_info="$(get_shell_info || true)"
  shell_name="$(printf '%s\n' "${shell_info:?}" | cut -d ' ' -f '1')" || shell_name='unknown'

  case "$(uname -m || true)" in
    x64 | x86_64 | aarch64 | ia64) shell_bit='64-bit' ;;
    x86 | i686 | i586 | i486 | i386) shell_bit='32-bit' ;;
    *) shell_bit='unknown' ;;
  esac

  if test "${OS-}" = 'Windows_NT' && os_bit="${PROCESSOR_ARCHITEW6432:-${PROCESSOR_ARCHITECTURE-}}" && test -n "${os_bit?}"; then
    # On Windows 2000+ / ReactOS
    case "${os_bit:?}" in
      AMD64 | ARM64 | IA64) os_bit='64-bit' ;;
      x86) os_bit='32-bit' ;;
      *) os_bit='unknown' ;;
    esac
  elif command 1> /dev/null 2>&1 -v 'getconf' && os_bit="$(getconf 'LONG_BIT')" && test -n "${os_bit?}"; then
    os_bit="${os_bit:?}-bit"
  elif test -e '/system/build.prop'; then
    # On Android
    case "$(file_getprop 'ro.product.cpu.abi' '/system/build.prop' || true)" in
      'x86_64' | 'arm64-v8a' | 'mips64' | 'riscv64') os_bit='64-bit' ;;
      'x86' | 'armeabi-v7a' | 'armeabi' | 'mips') os_bit='32-bit' ;;
      *) os_bit='unknown' ;;
    esac
  else
    os_bit='unknown'
  fi

  if test -e '/proc/cpuinfo' && tmp_var="$(grep -e '^flags[[:space:]]*:' -- '/proc/cpuinfo' | cut -d ':' -f '2-' -s)" && test -n "${tmp_var?}"; then
    if printf '%s\n' "${tmp_var:?}" | grep -m 1 -q -w -e '[[:lower:]]\{1,\}_lm'; then
      cpu_bit='64-bit'
    else
      cpu_bit='32-bit'
    fi
  elif command 1> /dev/null 2>&1 -v 'wmic.exe' && cpu_bit="$(MSYS_NO_PATHCONV=1 wmic.exe 2> /dev/null cpu get DataWidth /VALUE | cut -d '=' -f '2-' -s | tr -d '\r')" && test -n "${cpu_bit?}"; then
    # On Windows / ReactOS (if WMIC is present)
    case "${cpu_bit?}" in
      '64' | '32') cpu_bit="${cpu_bit:?}-bit" ;;
      *) cpu_bit='unknown' ;;
    esac
  elif command 1> /dev/null 2>&1 -v 'powershell.exe' && cpu_bit="$(powershell.exe -c 'gwmi Win32_Processor | select -ExpandProperty DataWidth')"; then
    # On Windows (if PowerShell is installed - it is slow)
    case "${cpu_bit?}" in
      '64' | '32') cpu_bit="${cpu_bit:?}-bit" ;;
      *) cpu_bit='unknown' ;;
    esac
  else
    cpu_bit='unknown'
  fi

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
    if ! tmp_var="$(awk -v n="${_n:?}" -- 'BEGIN { printf "%d\n", n }')" || ! permissively_comparison "${tmp_var?}" "${_n:?}"; then break; fi
    _max="${_n:?}"
  done
  _awk_printf_signed_bit="$(convert_max_signed_int_to_bit "${_max:?}")" || _awk_printf_signed_bit='unknown'

  # IMPORTANT: For very big integer numbers GNU Awk may return the exponential notation or an imprecise number
  _max='-1'
  for _n in ${_limits_u:?}; do
    if ! tmp_var="$(awk -v n="${_n:?}" -- 'BEGIN { printf "%u\n", n }')" || ! permissively_comparison "${tmp_var?}" "${_n:?}"; then break; fi
    _max="${_n:?}"
  done
  _awk_printf_unsigned_bit="$(convert_max_unsigned_int_to_bit "${_max:?}")" || _awk_printf_unsigned_bit='unknown'

  _max='-1'
  for _n in ${_limits_date:?}; do
    if ! tmp_var="$(TZ='CET-1' date 2> /dev/null -d "@${_n:?}" -- '+%s')"; then break; fi
    if test "${tmp_var?}" != "${_n:?}"; then
      if test "${tmp_var?}" = "$((${_n:?} - 14400))"; then
        date_timezone_bug='true'
      else
        break
      fi
    fi
    _max="${_n:?}"
  done
  _date_bit="$(convert_max_signed_int_to_bit "${_max:?}")" || _date_bit='unknown'

  _max='-1'
  for _n in ${_limits_date:?}; do
    if ! tmp_var="$(TZ='CET-1' date 2> /dev/null -u -d "@${_n:?}" -- '+%s')" || test "${tmp_var?}" != "${_n:?}"; then break; fi
    _max="${_n:?}"
  done
  _date_u_bit="$(convert_max_signed_int_to_bit "${_max:?}")" || _date_u_bit='unknown'

  printf '%s %s\n' "Shell:" "${shell_name:?}"
  if shell_applet="$(get_applet_name "${shell_name:?}")"; then
    printf '%s %s\n' "Shell applet:" "${shell_applet:?}"
  fi
  printf '%s %s\n' "Shell version:" "$(printf '%s\n' "${shell_info:?}" | cut -d ' ' -f '2-' -s || true)"
  printf '%s %s\n\n' "OS:" "$(get_os_info || true)"

  printf '%s\n' "Bits of shell: ${shell_bit:?}"
  printf '%s\n' "Bits of OS: ${os_bit:?}"
  printf '%s\n\n' "Bits of CPU: ${cpu_bit:?}"

  printf '%s\n' "Bits of shell 'test' int comparison: ${_shell_test_bit:?}"
  printf '%s\n' "Bits of shell arithmetic: ${_shell_arithmetic_bit:?}"
  printf '%s\n\n' "Bits of shell 'printf': ${_shell_printf_bit:?}"

  printf '%s %s\n' "Version of awk:" "$(get_awk_version || true)"
  printf '%s\n' "Bits of awk 'printf': ${_awk_printf_bit:?}"
  printf '%s\n' "Bits of awk 'printf' - signed: ${_awk_printf_signed_bit:?}"
  printf '%s\n\n' "Bits of awk 'printf' - unsigned: ${_awk_printf_unsigned_bit:?}"

  printf '%s %s\n' "Version of date:" "$(get_date_version || true)"
  printf '%s%s\n' "Bits of CET-1 'date' timestamp: ${_date_bit:?}" "$(test "${date_timezone_bug:?}" = 'false' || printf ' %s\n' '(with time zone bug)' || true)"
  printf '%s\n' "Bits of 'date -u' timestamp: ${_date_u_bit:?}"
}

main
