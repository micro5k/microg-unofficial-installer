#!/usr/bin/env sh

# SPDX-FileCopyrightText: (c) 2024 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

set -u 2> /dev/null || :
setopt SH_WORD_SPLIT 2> /dev/null || :
export POSIXLY_CORRECT='y'

# shellcheck disable=all
$(set 1> /dev/null 2>&1 -o pipefail) && set -o pipefail || :

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

file_getprop()
{
  grep -m 1 -F -e "${1:?}=" -- "${2:?}" | cut -d '=' -f '2-' -s
}

dump_hex()
{
  if test "${4:?}" = 'hexdump'; then
    hexdump -v -e '/1 "%02x"' -s "${3:?}" -n "${2:?}" -- "${1:?}" || return "${?}"
    printf '\n'
  elif test "${4:?}" = 'xxd'; then
    xxd -p -s "${3:?}" -l "${2:?}" -- "${1:?}"
  else
    return 1
  fi
}

switch_endianness_2()
{
  local _hex_bytes _se_cur_line 2> /dev/null

  test "${#1}" -eq 4 || return 1
  _hex_bytes="$(printf '%s\n' "${1:?}" | grep -o -e '..')" || return 2

  for _se_cur_line in 2 1; do
    printf '%s\n' "${_hex_bytes:?}" | head -n "${_se_cur_line:?}" | tail -n "+${_se_cur_line:?}" | tr -d '\n' || return "${?}"
  done || return "${?}"
  printf '\n'
}

switch_endianness()
{
  local _hex_bytes _se_cur_line 2> /dev/null

  test "${#1}" -eq 8 || return 1
  _hex_bytes="$(printf '%s\n' "${1:?}" | grep -o -e '..')" || return 2

  for _se_cur_line in 4 3 2 1; do
    printf '%s\n' "${_hex_bytes:?}" | head -n "${_se_cur_line:?}" | tail -n "+${_se_cur_line:?}" | tr -d '\n' || return "${?}"
  done || return "${?}"
  printf '\n'
}

# Params:
#  $1 Input bytes (hex)
#  $2 (int)
#  $3 Need bytes swap (bool)
hex_bytes_to_int()
{
  local _hbti_num 2> /dev/null

  test -n "${1?}" || return 1

  if test "${3:?}" = 'true'; then
    if test "${2:?}" -eq 2; then
      _hbti_num="$(switch_endianness_2 "${1:?}")" || return "${?}"
    elif test "${2:?}" -eq 4; then
      _hbti_num="$(switch_endianness "${1:?}")" || return "${?}"
    else
      return 2
    fi
  else
    _hbti_num="${1:?}" || return "${?}"
  fi

  printf '%u\n' "$((0x${_hbti_num:?}))"
}

# Params:
#  $1 Input bytes (hex)
#  $2 Bytes to skip (int)
#  $3 Length (int)
extract_bytes()
{
  test "${3:?}" -gt 0 || return 1
  printf '%s\n' "${1?}" | cut -b "$((${2:?} * 2 + 1))-$(((${2:?} + ${3:?}) * 2))"
}

check_bitness_of_file()
{
  local _hex_cmd _cbf_first_8_bytes _cbf_pos _header _cbf_tmp_var 2> /dev/null

  if command 1> /dev/null 2>&1 -v 'xxd'; then
    _hex_cmd='xxd'
  elif command 1> /dev/null 2>&1 -v 'hexdump'; then
    _hex_cmd='hexdump'
  else
    printf '%s\n' 'unknown'
    return 1
  fi

  if test ! -e "${1:?}" || ! _cbf_first_8_bytes="$(dump_hex "${1:?}" '8' '0' "${_hex_cmd:?}")"; then
    printf '%s\n' 'failed'
    return 1
  fi

  if test "$(extract_bytes "${_cbf_first_8_bytes?}" '0' '4' || :)" = '7f454c46'; then
    # Binaries for Linux / Android
    # ELF header => 0x7F + ELF (0x45 0x4C 0x46) + 0x01 for 32-bit or 0x02 for 64-bit

    _header="$(extract_bytes "${_cbf_first_8_bytes?}" '4' '1')" || _header=''
    case "${_header?}" in
      '02') printf '%s\n' '64-bit ELF' ;;
      '01') printf '%s\n' '32-bit ELF' ;;
      *)
        printf '%s\n' 'unknown-elf-file'
        return 3
        ;;
    esac
    return 0
  fi

  if _cbf_pos="$(dump_hex "${1:?}" '4' '0x3C' "${_hex_cmd:?}")" && _cbf_pos="$(switch_endianness "${_cbf_pos?}")" &&
    test -n "${_cbf_pos?}" && _header="$(dump_hex "${1:?}" '6' "0x${_cbf_pos:?}" "${_hex_cmd:?}")" &&
    printf '%s\n' "${_header?}" | grep -m 1 -q -e '^50450000'; then
    # Binaries executables for Windows (*.exe)
    # PE header => PE (0x50 0x45) + 0x00 0x00 + Machine field
    # More info: https://learn.microsoft.com/en-us/windows/win32/debug/pe-format

    case "${_header?}" in
      *'6486') printf '%s\n' '64-bit PE (x86-64)' ;; # x86-64 (0x64 0x86) - also called AMD64
      *'64aa') printf '%s\n' '64-bit PE (ARM64)' ;;  # ARM64  (0x64 0xAA)
      *'0002') printf '%s\n' '64-bit PE (IA-64)' ;;  # IA-64  (0x00 0x02)
      *'4c01') printf '%s\n' '32-bit PE (x86)' ;;    # x86    (0x4C 0x01)
      *'c001') printf '%s\n' '64-bit PE (ARM)' ;;    # ARM    (0xC0 0x01)
      *'0000') printf '%s\n' '16-bit PE' ;;          # Any    (0x00 0x00)
      *)
        printf '%s\n' 'unknown-pe-file'
        return 4
        ;;
    esac
    return 0
  fi

  if test "$(extract_bytes "${_cbf_first_8_bytes?}" '0' '2' || :)" = '4d5a'; then
    # Binaries executables for DOS (*.exe)
    # MZ (0x4D 0x5A)

    _cbf_needs_bytes_swap='true'
    if _cbf_tmp_var="$(dump_hex "${1:?}" '2' '0x18' "${_hex_cmd:?}")" &&
      _cbf_tmp_var="$(hex_bytes_to_int "${_cbf_tmp_var?}" '2' "${_cbf_needs_bytes_swap:?}")" && test "${_cbf_tmp_var:?}" -lt 64; then

      printf '%s\n' '16-bit MZ'
      return 0
    fi
    # ToO: Check special variants / hexdump -v -C -s "0x3C" -n "4" -- "${1:?}"

    printf '%s\n' 'unknown-mz-file'
    return 5
  fi

  if test "$(extract_bytes "${_cbf_first_8_bytes?}" '0' '2' || :)" = '2321'; then
    # Scripts
    # Start with: #! (0x23 0x21)

    printf '%s\n' 'Universal script'
    return 0
  fi

  local _cbf_is_mach_o _cbf_is_fat_bin _cbf_needs_bytes_swap _cbf_arch_count _cbf_has64 _cbf_has32 2> /dev/null

  if _header="$(extract_bytes "${_cbf_first_8_bytes?}" '0' '4')"; then
    _cbf_is_mach_o='true'
    _cbf_is_fat_bin='false'
    _cbf_needs_bytes_swap='false'

    case "${_header?}" in
      'feedface') # MH_MAGIC
        ;;
      'cefaedfe') # MH_CIGAM
        _cbf_needs_bytes_swap='true'
        ;;
      'feedfacf') # MH_MAGIC_64
        ;;
      'cffaedfe') # MH_CIGAM_64
        _cbf_needs_bytes_swap='true' ;;
      'cafebabe') # FAT_MAGIC
        _cbf_is_fat_bin='true' ;;
      'bebafeca') # FAT_CIGAM
        _cbf_is_fat_bin='true'
        _cbf_needs_bytes_swap='true'
        ;;
      'cafebabf') # FAT_MAGIC_64
        #_cbf_is_fat_bin='true'
        ;;
      'bfbafeca') # FAT_CIGAM_64
        #_cbf_is_fat_bin='true'
        _cbf_needs_bytes_swap='true'
        ;;
      *)
        _cbf_is_mach_o='false'
        ;;
    esac

    if test "${_cbf_is_mach_o:?}" = 'true'; then
      if test "${_cbf_is_fat_bin:?}" = 'true' && _cbf_arch_count="$(extract_bytes "${_cbf_first_8_bytes?}" '4' '4')" &&
        _cbf_arch_count="$(hex_bytes_to_int "${_cbf_arch_count?}" '4' "${_cbf_needs_bytes_swap:?}")" &&
        test "${_cbf_arch_count:?}" -gt 0 && test "${_cbf_arch_count:?}" -lt 256; then

        _cbf_has64='false'
        _cbf_has32='false'
        _cbf_pos='8'
        for _ in $(seq "${_cbf_arch_count:?}"); do
          _cbf_tmp_var="$(dump_hex "${1:?}" '4' "${_cbf_pos:?}" "${_hex_cmd:?}")" || _cbf_tmp_var=''
          if test "${_cbf_needs_bytes_swap:?}" = 'true'; then
            _cbf_tmp_var="$(switch_endianness "${_cbf_tmp_var?}")" || _cbf_tmp_var=''
          fi
          _cbf_pos="$((${_cbf_pos:?} + 20))" || _cbf_tmp_var='' # Should be pos + 32 on FAT_MAGIC_64 (need test)

          case "${_cbf_tmp_var?}" in
            '01'*) _cbf_has64='true' ;;
            '00'*) _cbf_has32='true' ;;
            *)
              _cbf_has64='false'
              _cbf_has32='false'
              break
              ;;
          esac
        done

        if test "${_cbf_has64:?}" = 'true' && test "${_cbf_has32:?}" = 'true'; then
          printf '%s\n' '32/64-bit FAT Mach-O'
        elif test "${_cbf_has64:?}" = 'true' && test "${_cbf_has32:?}" != 'true'; then
          printf '%s\n' '64-bit FAT Mach-O'
        elif test "${_cbf_has64:?}" != 'true' && test "${_cbf_has32:?}" = 'true'; then
          printf '%s\n' '32-bit FAT Mach-O'
        else
          printf '%s\n' 'unknown-fat-mach-file'
          return 6
        fi

        return 0
      else
        printf '%s\n' 'unknown-mach-file'
        return 7
      fi
    fi
  fi

  if _cbf_tmp_var="$(extract_bytes "${_cbf_first_8_bytes?}" '0' '1')" &&
    {
      test "${_cbf_tmp_var?}" = 'e9' || test "${_cbf_tmp_var?}" = 'eb' ||
        test "$(extract_bytes "${_cbf_first_8_bytes?}" '0' '2' || :)" = '81fc'
    } &&
    test "$(stat -c '%s' -- "${1:?}" || printf '99999\n' || :)" -le 65280; then
    # Binaries executables for DOS (*.com)

    # To detect COM programs we can check if the first byte of the file could be a valid jump or call opcode (most common: 0xE9 or 0xEB).
    # This is also common: 0x81 + 0xFC.
    # This isn't a safe way to determine wether a file is a COM file or not, but most COM files start with a jump.
    # A COM program can only have a size of less than one segment (64K).
    # The maximum size of the file is 65280 bytes.

    printf '%s\n' '8/16-bit COM'
    return 0
  fi

  printf '%s\n' 'unknown-file-type'
  return 2
}

get_shell_exe()
{
  local _gse_shell_exe _gse_tmp_var 2> /dev/null

  if _gse_shell_exe="$(readlink 2> /dev/null "/proc/${$}/exe")" && test -n "${_gse_shell_exe?}"; then
    # On Linux / Android / Windows (on Windows only some shells support it)
    :
  elif _gse_tmp_var="$(ps 2> /dev/null -p "${$}" -o 'comm=')" && test -n "${_gse_tmp_var?}" && _gse_tmp_var="$(command 2> /dev/null -v "${_gse_tmp_var:?}")"; then
    # On Linux / macOS
    _gse_shell_exe="$(readlink 2> /dev/null -f "${_gse_tmp_var:?}" || realpath 2> /dev/null "${_gse_tmp_var:?}")" || _gse_shell_exe="${_gse_tmp_var:?}"
  elif _gse_tmp_var="${BASH:-${SHELL-}}" && test -n "${_gse_tmp_var?}"; then
    if test ! -e "${_gse_tmp_var:?}" && test -e "${_gse_tmp_var:?}.exe"; then _gse_tmp_var="${_gse_tmp_var:?}.exe"; fi # Special fix for broken versions of Bash under Windows
    _gse_shell_exe="$(readlink 2> /dev/null -f "${_gse_tmp_var:?}" || realpath 2> /dev/null "${_gse_tmp_var:?}")" || _gse_shell_exe="${_gse_tmp_var:?}"
  else
    return 1
  fi

  printf '%s\n' "${_gse_shell_exe:?}"
}

get_shell_info()
{
  local _shell_use_ver_opt _shell_exe _shell_name _shell_version _tmp_var 2> /dev/null

  # NOTE: Fish is intentionally not POSIX-compatible so this function may not work on it

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

  _shell_name="$(basename "${_shell_exe:?}")" || _shell_name="${_shell_exe:?}"

  case "${_shell_exe:?}" in
    *'/bosh/'*) _shell_name='bosh' ;;
    *) ;;
  esac

  if _tmp_var="$(printf '%s\n' "${_shell_name?}" | grep -m 1 -o -e 'ksh\|zsh\|yash\|\\bash\.exe$')"; then
    if test "${_tmp_var?}" = 'ksh'; then # For new ksh (it does NOT show the version in the help)
      _shell_version="${KSH_VERSION-}"
    elif test "${_tmp_var?}" = 'zsh' || test "${_tmp_var?}" = 'yash'; then # For zsh and yash (they do NOT show the version in the help)
      _shell_use_ver_opt='true'
    elif test "${_tmp_var?}" = '\bash.exe'; then # Fix for a basename bug on old Bash under Windows
      _shell_name='bash'
    fi
  fi

  # Many shells doesn't support '--version' and in addition some bugged versions of BusyBox open
  # an interactive shell when the '--version' option is used, so use it only when really needed

  if test -n "${_shell_version?}"; then
    : # Already found, do nothing
  else
    if test "${_shell_use_ver_opt:?}" = 'true' && _shell_version="$("${_shell_exe:?}" 2>&1 --version)" && test -n "${_shell_version?}"; then
      :
    else
      # NOTE: "sh --help" of BusyBox may return failure but still print the correct output although it may be printed to STDERR
      _shell_version="$("${_shell_exe:?}" 2> /dev/null -Wversion || "${_shell_exe:?}" 2>&1 --help || :)"
    fi

    case "${_shell_version?}" in
      '' | *'invalid option'* | *'unrecognized option'* | *'unknown option'* | *[Ii]'llegal option'* | *'not an option'* | *'bad option'* | *'command not found'* | *'No such file or directory'*)
        if test "${_shell_name?}" = 'dash' && command 1> /dev/null 2>&1 -v 'dpkg' && _shell_version="$(dpkg -s 'dash' | grep -m 1 -F -e 'Version:' | cut -d ':' -f '2-' -s)" && test -n "${_shell_version?}"; then
          : # For dash
        elif test "${_shell_name?}" = 'dash' && test -n "${DASH_VERSION-}" && _shell_version="${DASH_VERSION:?}"; then
          : # For dash (possibly supported in the future)
        elif test "${_shell_name?}" = 'dash' && command 1> /dev/null 2>&1 -v 'apt-cache' && _shell_version="$(apt-cache policy 'dash' | grep -m 1 -F -e 'Installed:' | cut -d ':' -f '2-' -s)" && test -n "${_shell_version?}"; then
          : # For dash (it is slow)
        elif test "${_shell_name?}" = 'posh' && test -n "${POSH_VERSION-}" && _shell_version="${POSH_VERSION:?}"; then
          : # For posh (need test)
        elif _shell_version="$(\eval 2> /dev/null ' \echo "${.sh.version-}" ' || true)" && test -n "${_shell_version?}"; then
          : # For ksh and bosh
        elif test -n "${version-}" && _shell_version="${version:?}"; then
          : # For tcsh and fish
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
        for _current_applet in bash ash hush msh lash sh; do
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
    'Windows_NT') # Bugged versions of uname: it doesn't support uname -o and it is unable to retrieve the correct version of Windows
      _os_name='MS/Windows'
      ;;
    'GNU/Linux')
      if _os_version="$(getprop 2> /dev/null 'ro.build.version.release')" && test -n "${_os_version?}"; then
        _os_name='Android'
      else
        _os_version="$(uname 2> /dev/null -r)" || _os_version=''
      fi
      ;;
    *)
      _os_version="$(uname 2> /dev/null -r)" || _os_version=''
      ;;
  esac

  printf '%s %s\n' "${_os_name:-unknown}" "${_os_version:-unknown}"
}

get_version()
{
  local _version 2> /dev/null

  if ! command 1> /dev/null 2>&1 -v "${1:?}"; then
    printf '%s\n' 'missing'
    return 1
  fi

  # NOTE: "date --help" and "awk --help" of BusyBox may return failure but still print the correct output although it may be printed to STDERR
  _version="$("${1:?}" 2> /dev/null -Wversion || "${1:?}" 2> /dev/null --version || "${1:?}" 2>&1 --help || true)"
  _version="$(printf '%s\n' "${_version?}" | head -n 1)" || _version=''

  case "${_version?}" in
    '' | *'invalid option'* | *'unrecognized option'* | *'unknown option'* | *[Ii]'llegal option'* | *'not an option'* | *'bad option'*)
      printf '%s\n' 'unknown'
      return 2
      ;;
    *) ;;
  esac

  printf '%s\n' "${_version:?}"
}

pause_if_needed()
{
  # shellcheck disable=SC3028 # In POSIX sh, SHLVL is undefined
  if test "${NO_PAUSE:-0}" = '0' && test "${CI:-false}" = 'false' && test "${TERM_PROGRAM-}" != 'vscode' && test "${SHLVL:-1}" = '1' && test -t 0 && test -t 1 && test -t 2; then
    printf 1>&2 '\n\033[1;32m%s\033[0m' 'Press any key to exit...' || true
    # shellcheck disable=SC3045
    IFS='' read 1> /dev/null 2>&1 -r -s -n 1 _ || IFS='' read 1>&2 -r _ || true
    printf 1>&2 '\n' || true
  fi
  return 0
}

main()
{
  local date_timezone_bug _limits _limits_date _limits_u _max _n tmp_var 2> /dev/null
  local shell_exe shell_info shell_name shell_applet shell_bit os_bit cpu_bit _shell_test_bit _shell_arithmetic_bit _shell_printf_bit _awk_printf_bit _awk_printf_signed_bit _awk_printf_unsigned_bit _date_bit _date_u_bit 2> /dev/null

  date_timezone_bug='false'
  _limits='32767 2147483647 9223372036854775807'
  _limits_date='32767 2147480047 2147483647 32535215999 32535244799 67767976233529199 67767976233532799 67768036191673199 67768036191676799 9223372036854775807'
  _limits_u='65535 2147483647 2147483648 4294967295 18446744073709551615'

  shell_exe="$(get_shell_exe || :)"
  shell_info="$(get_shell_info || :)"
  shell_name="$(printf '%s\n' "${shell_info:?}" | cut -d ' ' -f '1' || true)"

  if test -n "${shell_exe?}" && shell_bit="$(check_bitness_of_file "${shell_exe:?}")"; then
    :
  elif tmp_var="$(uname 2> /dev/null -m)"; then
    case "${tmp_var?}" in
      x86_64 | ia64 | arm64 | aarch64 | mips64) shell_bit='64-bit' ;;
      x86 | i686 | i586 | i486 | i386 | armv7* | mips) shell_bit='32-bit' ;;
      *) shell_bit='unknown' ;;
    esac
  elif test "${OS-}" = 'Windows_NT'; then
    # On Windows 2000+ / ReactOS
    case "${PROCESSOR_ARCHITECTURE-}" in
      AMD64 | ARM64 | IA64) shell_bit='64-bit' ;;
      x86) shell_bit='32-bit' ;;
      *) shell_bit='unknown' ;;
    esac
  else
    shell_bit='unknown'
  fi

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
  elif command 1> /dev/null 2>&1 -v 'sysctl' && tmp_var="$(sysctl hw.cpu64bit_capable | cut -d ':' -f '2-' -s)" && tmp_var="${tmp_var# }" && test -n "${tmp_var?}"; then
    # On macOS
    case "${tmp_var:?}" in
      '1') cpu_bit='64-bit' ;;
      '0') cpu_bit='32-bit' ;;
      *) cpu_bit='unknown' ;;
    esac
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
  printf '%s %s\n' "OS:" "$(get_os_info || true)"
  printf '%s %s\n\n' "Version of uname:" "$(get_version 'uname' || true)"

  printf '%s\n' "Bits of shell: ${shell_bit:?}"
  printf '%s\n' "Bits of OS: ${os_bit:?}"
  printf '%s\n\n' "Bits of CPU: ${cpu_bit:?}"

  printf '%s\n' "Bits of shell 'test' int comparison: ${_shell_test_bit:?}"
  printf '%s\n' "Bits of shell arithmetic: ${_shell_arithmetic_bit:?}"
  printf '%s\n\n' "Bits of shell 'printf': ${_shell_printf_bit:?}"

  printf '%s %s\n' "Version of awk:" "$(get_version 'awk' || true)"
  printf '%s\n' "Bits of awk 'printf': ${_awk_printf_bit:?}"
  printf '%s\n' "Bits of awk 'printf' - signed: ${_awk_printf_signed_bit:?}"
  printf '%s\n\n' "Bits of awk 'printf' - unsigned: ${_awk_printf_unsigned_bit:?}"

  printf '%s %s\n' "Version of date:" "$(get_version 'date' || true)"
  printf '%s%s\n' "Bits of CET-1 'date' timestamp: ${_date_bit:?}" "$(test "${date_timezone_bug:?}" = 'false' || printf ' %s\n' '(with time zone bug)' || true)"
  printf '%s\n' "Bits of 'date -u' timestamp: ${_date_u_bit:?}"
}

main
pause_if_needed
