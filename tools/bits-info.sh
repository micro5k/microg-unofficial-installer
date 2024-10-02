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

detect_hex_dump_cmd()
{
  if command 1> /dev/null 2>&1 -v 'xxd'; then
    printf '%s\n' 'xxd'
  elif command 1> /dev/null 2>&1 -v 'hexdump'; then
    printf '%s\n' 'hexdump'
  else
    return 1
  fi
  return 0
}

dump_hex()
{
  if test "${HEXDUMP_CMD:=$(detect_hex_dump_cmd || :)}" = 'xxd'; then
    xxd -p -c "${3:?}" -s "${2:?}" -l "${3:?}" -- "${1:?}"
  elif test "${HEXDUMP_CMD?}" = 'hexdump'; then
    hexdump -v -e '/1 "%02x"' -s "${2:?}" -n "${3:?}" -- "${1:?}" && printf '\n'
  else
    return 1
  fi
}

switch_endianness_2()
{
  test "${#1}" = 4 || return 1
  printf '%s' "$1" | cut -b '3-4' | tr -d '\n'
  printf '%s' "$1" | cut -b '1-2'
}

switch_endianness_4()
{
  test "${#1}" = 8 || return 1
  _se4_hex_b="$(printf '%s' "$1" | fold -b -w 2)" || return 2

  for _se4_i in 4 3 2 1; do
    printf '%s' "${_se4_hex_b}" | head -n "${_se4_i:?}" | tail -n "+${_se4_i:?}" | tr -d '\n' || return "${?}"
  done &&
    printf '\n'
}

# Params:
#  $1 Input bytes (hex)
#  $2 Number of bytes (int)
#  $3 Need bytes swap (bool)
hex_bytes_to_int()
{
  test -n "${1?}" || return 1

  if test "${3-}" = 'true'; then
    if test "${2:?}" -eq 2; then
      _hbti_num="$(switch_endianness_2 "$1")" || return "${?}"
    elif test "${2:?}" -eq 4; then
      _hbti_num="$(switch_endianness_4 "$1")" || return "${?}"
    else
      return 9
    fi
  else
    _hbti_num="$1"
  fi

  printf '%u' "0x${_hbti_num:?}"
}

# Params:
#  $1 Input bytes (hex)
#  $2 Bytes to skip (int)
#  $3 Length in bytes (int)
extract_bytes()
{
  test "${3:?}" -gt 0 || return 1
  printf '%s\n' "${1?}" | cut -b "$((${2:?} * 2 + 1))-$(((${2:?} + ${3:?}) * 2))"
}

detect_bitness_of_file()
{
  local _dbf_first_bytes _dbf_size _dbf_do_bytes_swap _dbf_pos _header _dbf_exe_type _dbf_cpu_type _dbf_tmp_var 2> /dev/null

  if test ! -f "${1:?}" || ! _dbf_first_bytes="$(dump_hex "${1:?}" '0' '64')"; then # (0x00 - 0x40)
    printf '%s\n' 'failed'
    return 1
  fi

  if test "$(extract_bytes "${_dbf_first_bytes?}" '0' '2' || :)" = '4d5a'; then
    # MZ - Executable binaries for Windows / DOS (.exe) - Start with: MZ (0x4D 0x5A)
    # More info: https://wiki.osdev.org/MZ

    _dbf_do_bytes_swap='true'
    _dbf_pos=''
    _dbf_exe_type=''

    # APE - Actually Portable Executables - Start with: MZ (0x4D 0x5A) + qFpD (0x71 0x46 0x70 0x44)
    if test "$(extract_bytes "${_dbf_first_bytes?}" '2' '4' || :)" = '71467044'; then
      _dbf_exe_type='APE '
    fi

    # The smallest possible PE file is 97 bytes: http://www.phreedom.org/research/tinype/
    # PE files, to be able to be executed on Windows (it is different under DOS), only need two fields in the MZ header: e_magic (0x00 => 0) and e_lfanew (0x3C => 60)
    if
      _dbf_pos="$(extract_bytes "${_dbf_first_bytes?}" '60' '4')" && _dbf_pos="$(hex_bytes_to_int "${_dbf_pos?}" '4' "${_dbf_do_bytes_swap:?}")" &&
        test "${_dbf_pos:?}" -ge 4 && test "${_dbf_pos:?}" -le 536870912 &&
        _header="$(dump_hex "${1:?}" "${_dbf_pos:?}" '26')"
    then
      :
    else _header=''; fi

    if test -n "${_header?}"; then
      if printf '%s\n' "${_header:?}" | grep -m 1 -q -e '^50450000'; then
        # PE header => PE (0x50 0x45) + 0x00 + 0x00 + Machine field
        # More info: https://www.aldeid.com/wiki/PE-Portable-executable
        # More info: https://learn.microsoft.com/en-us/windows/win32/debug/pe-format
        _dbf_exe_type="${_dbf_exe_type?}PE"

        # PE header pos + 0x14 (decimal: 20) = SizeOfOptionalHeader
        if
          _dbf_tmp_var="$(extract_bytes "${_header?}" '20' '2')" && _dbf_tmp_var="$(hex_bytes_to_int "${_dbf_tmp_var?}" '2' "${_dbf_do_bytes_swap:?}")" &&
            test "${_dbf_tmp_var:?}" -ge 2
        then
          # PE header pos + 0x18 (decimal: 24) = PE type magic
          if _dbf_tmp_var="$(extract_bytes "${_header?}" '24' '2')" && _dbf_tmp_var="$(switch_endianness_2 "${_dbf_tmp_var?}")"; then
            case "${_dbf_tmp_var?}" in
              '010b') _dbf_exe_type="${_dbf_exe_type:?}32" ;;
              '020b') _dbf_exe_type="${_dbf_exe_type:?}32+" ;;
              '0107') _dbf_exe_type="${_dbf_exe_type:?} ROM image" ;;
              *) ;;
            esac
          fi
        fi

        _dbf_cpu_type="$(extract_bytes "${_header:?}" '4' '2')" || _dbf_cpu_type=''
        if test "${_dbf_do_bytes_swap:?}" = 'true'; then
          _dbf_cpu_type="$(switch_endianness_2 "${_dbf_cpu_type}")" || _dbf_cpu_type=''
        fi

        case "${_dbf_cpu_type?}" in
          '8664') printf '%s\n' "64-bit ${_dbf_exe_type:?} (x86-64)" ;; # x86-64 (0x86 0x64) - also known as AMD64
          'aa64') printf '%s\n' "64-bit ${_dbf_exe_type:?} (ARM64)" ;;  # ARM64  (0xAA 0x64)
          '0200') printf '%s\n' "64-bit ${_dbf_exe_type:?} (IA-64)" ;;  # IA-64  (0x02 0x00)
          '014c') printf '%s\n' "32-bit ${_dbf_exe_type:?} (x86)" ;;    # x86    (0x01 0x4C)
          '01c0') printf '%s\n' "32-bit ${_dbf_exe_type:?} (ARM)" ;;    # ARM    (0x01 0xC0)
          '0ebc') printf '%s\n' "${_dbf_exe_type:?} (EFI)" ;;           # EFI    (0x0E 0xBC)
          '0000') printf '%s\n' "16-bit ${_dbf_exe_type:?}" ;;          # Any    (0x00 0x00)
          *)
            printf '%s\n' 'unknown-pe-file'
            return 4
            ;;
        esac
        return 0
      else
        _header="$(extract_bytes "${_header:?}" '0' '2' || :)"
        case "${_header?}" in
          '4e45')
            # NE (New Executable) header => NE (0x4E 0x45)
            printf '%s\n' '16-bit NE'
            return 0
            ;;
          '4c45')
            # LE (Linear Executable) header => LE (0x4C 0x45)
            printf '%s\n' '16/32-bit LE'
            return 0
            ;;
          '4c58')
            # LX (Linear Executable) header => LX (0x4C 0x58)
            printf '%s\n' '32-bit LX'
            return 0
            ;;
          *) ;;
        esac
      fi

      #printf '\n' && hexdump -v -C -s "${_dbf_pos:?}" -n '6' -- "${1:?}" # Debug
    fi

    # The absolute offset to the relocation table is stored at: 0x18 (decimal: 24)
    # The absolute offset to the relocation table of plain MZ files (so not extended ones) must be: > 0x1B (decimal: 27) and < 0x40 (decimal: 64)
    # NOTE: This does NOT apply to PE files as this field is not used on them
    if _dbf_tmp_var="$(extract_bytes "${_dbf_first_bytes?}" '24' '2')" && _dbf_tmp_var="$(hex_bytes_to_int "${_dbf_tmp_var?}" '2' "${_dbf_do_bytes_swap:?}")"; then
      if
        {
          test "${_dbf_tmp_var:?}" -gt 27 && test "${_dbf_tmp_var:?}" -lt 64
        } ||
          {
            test "${_dbf_tmp_var:?}" = 0 && test "$(extract_bytes "${_dbf_first_bytes?}" '6' '2' || :)" = '0000' # Empty relocation table
          }
      then
        printf '%s\n' '16-bit MZ'
        return 0
      fi
    fi

    printf '%s\n' 'unknown-mz-file'
    return 5
  fi

  if test "$(extract_bytes "${_dbf_first_bytes?}" '0' '4' || :)" = '7f454c46'; then
    # ELF - Executable binaries for Linux / Android - Start with: 0x7F + ELF (0x45 0x4C 0x46) + 0x01 for 32-bit or 0x02 for 64-bit

    _header="$(extract_bytes "${_dbf_first_bytes?}" '4' '1')" || _header=''
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

  if test "$(extract_bytes "${_dbf_first_bytes?}" '0' '2' || :)" = '2321'; then
    # Scripts (often shell scripts) - Start with: #! (0x23 0x21)

    printf '%s\n' 'Bit-independent script'
    return 0
  fi

  local _dbf_is_mach_o _dbf_is_fat_bin _dbf_arch_count _dbf_has64 _dbf_has32 2> /dev/null

  if _header="$(extract_bytes "${_dbf_first_bytes?}" '0' '4')"; then
    _dbf_is_mach_o='true'
    _dbf_is_fat_bin='false'
    _dbf_do_bytes_swap='false'

    case "${_header?}" in
      'feedface') # MH_MAGIC
        ;;
      'cefaedfe') # MH_CIGAM
        _dbf_do_bytes_swap='true'
        ;;
      'feedfacf') # MH_MAGIC_64
        ;;
      'cffaedfe') # MH_CIGAM_64
        _dbf_do_bytes_swap='true' ;;
      'cafebabe') # FAT_MAGIC
        if
          _dbf_arch_count="$(extract_bytes "${_dbf_first_bytes?}" '4' '4')" && _dbf_arch_count="$(hex_bytes_to_int "${_dbf_arch_count?}" '4' 'false')" &&
            test "${_dbf_arch_count:?}" -gt 30
        then
          # Both this and Java bytecode have the same magic number (more info: https://opensource.apple.com/source/file/file-80.40.2/file/magic/Magdir/cafebabe.auto.html)
          _dbf_is_mach_o='false'
        else
          _dbf_is_fat_bin='true'
        fi
        ;;
      'bebafeca') # FAT_CIGAM
        _dbf_is_fat_bin='true'
        _dbf_do_bytes_swap='true'
        ;;
      'cafebabf') # FAT_MAGIC_64
        #_dbf_is_fat_bin='true'
        ;;
      'bfbafeca') # FAT_CIGAM_64
        #_dbf_is_fat_bin='true'
        _dbf_do_bytes_swap='true'
        ;;
      *)
        _dbf_is_mach_o='false'
        ;;
    esac

    if test "${_dbf_is_mach_o:?}" = 'true'; then
      if
        test "${_dbf_is_fat_bin:?}" = 'true' && _dbf_arch_count="$(extract_bytes "${_dbf_first_bytes?}" '4' '4')" &&
          _dbf_arch_count="$(hex_bytes_to_int "${_dbf_arch_count?}" '4' "${_dbf_do_bytes_swap:?}")" &&
          test "${_dbf_arch_count:?}" -gt 0 && test "${_dbf_arch_count:?}" -lt 256
      then
        _dbf_has64='false'
        _dbf_has32='false'
        _dbf_pos='8'
        for _ in $(seq "${_dbf_arch_count:?}"); do
          _dbf_tmp_var="$(dump_hex "${1:?}" "${_dbf_pos:?}" '4')" || _dbf_tmp_var=''
          if test "${_dbf_do_bytes_swap:?}" = 'true'; then
            _dbf_tmp_var="$(switch_endianness_4 "${_dbf_tmp_var?}")" || _dbf_tmp_var=''
          fi
          _dbf_pos="$((${_dbf_pos:?} + 20))" || _dbf_tmp_var='' # Should be pos + 32 on FAT_MAGIC_64 (need test)

          case "${_dbf_tmp_var?}" in
            '01'*) _dbf_has64='true' ;;
            '00'*) _dbf_has32='true' ;;
            *)
              _dbf_has64='false'
              _dbf_has32='false'
              break
              ;;
          esac
        done

        if test "${_dbf_has64:?}" = 'true' && test "${_dbf_has32:?}" = 'true'; then
          printf '%s\n' '32/64-bit FAT Mach-O'
        elif test "${_dbf_has64:?}" = 'true' && test "${_dbf_has32:?}" != 'true'; then
          printf '%s\n' '64-bit FAT Mach-O'
        elif test "${_dbf_has64:?}" != 'true' && test "${_dbf_has32:?}" = 'true'; then
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

  _dbf_size="$(stat -c '%s' -- "${1:?}")" || {
    printf '%s\n' 'failed'
    return 1
  }

  if
    test "${_dbf_size:?}" -le 65280 && test "${_dbf_size:?}" -ge 2 &&
      _dbf_tmp_var="$(extract_bytes "${_dbf_first_bytes?}" '0' '1')" &&
      {
        test "${_dbf_tmp_var?}" = 'e9' || test "${_dbf_tmp_var?}" = 'eb' ||
          test "$(extract_bytes "${_dbf_first_bytes?}" '0' '2' || :)" = '81fc'
      }
  then
    # COM - Executable binaries for DOS (.com)

    # To detect COM programs we can check if the first byte of the file could be a valid jump or call opcode (most common: 0xE9 or 0xEB).
    # This is also common: 0x81 + 0xFC.
    # This isn't a safe way to determine wether a file is a COM file or not, but most COM files start with a jump.
    # A COM program can only have a size of less than one segment (64K).
    # The maximum size of the file is 65280 bytes.

    printf '%s\n' '16-bit COM'
    return 0
  fi

  if test "${_dbf_size:?}" = 0; then
    printf '%s\n' 'Empty file'
    return 0
  fi

  case "${1:?}" in
    *'.bat')
      printf '%s\n' 'Bit-independent batch'
      return 0
      ;;
    *) ;;
  esac

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

  if test -n "${1?}" && _shell_exe="${1?}"; then
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

  case "${_shell_name?}" in
    *'ksh'*) _shell_version="${KSH_VERSION-}" ;;     # For new ksh (it does NOT show the version in the help)
    *'zsh'* | *'yash'*) _shell_use_ver_opt='true' ;; # For zsh and yash (they do NOT show the version in the help)
    'bash.exe') _shell_name='bash' ;;                # For old Bash under Windows
    *) ;;
  esac

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
  shell_info="$(get_shell_info "${shell_exe?}" || :)"
  shell_name="$(printf '%s\n' "${shell_info?}" | cut -d ' ' -f '1' || :)"

  if test -n "${shell_exe?}" && shell_bit="$(detect_bitness_of_file "${shell_exe:?}")"; then
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
  elif command 1> /dev/null 2>&1 -v 'wmic.exe' && cpu_bit="$(MSYS_NO_PATHCONV=1 wmic.exe 2> /dev/null cpu get DataWidth /VALUE | cut -d '=' -f '2-' -s | tr -d '\r\n')" && test -n "${cpu_bit?}"; then
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

  printf '%s %s\n' "Shell:" "${shell_name?}"
  if shell_applet="$(get_applet_name "${shell_name?}")"; then
    printf '%s %s\n' "Shell applet:" "${shell_applet:?}"
  fi
  printf '%s %s\n' "Shell version:" "$(printf '%s\n' "${shell_info?}" | cut -d ' ' -f '2-' -s || :)"
  printf '%s %s\n' "Shell path:" "${shell_exe?}"
  printf '%s %s\n' "OS:" "$(get_os_info || :)"
  printf '%s %s\n\n' "Version of uname:" "$(get_version 'uname' || :)"

  printf '%s\n' "Bits of shell: ${shell_bit:?}"
  printf '%s\n' "Bits of OS: ${os_bit:?}"
  printf '%s\n\n' "Bits of CPU: ${cpu_bit:?}"

  printf '%s\n' "Bits of shell 'test' int comparison: ${_shell_test_bit:?}"
  printf '%s\n' "Bits of shell arithmetic: ${_shell_arithmetic_bit:?}"
  printf '%s\n\n' "Bits of shell 'printf': ${_shell_printf_bit:?}"

  printf '%s %s\n' "Version of awk:" "$(get_version 'awk' || :)"
  printf '%s\n' "Bits of awk 'printf': ${_awk_printf_bit:?}"
  printf '%s\n' "Bits of awk 'printf' - signed: ${_awk_printf_signed_bit:?}"
  printf '%s\n\n' "Bits of awk 'printf' - unsigned: ${_awk_printf_unsigned_bit:?}"

  printf '%s %s\n' "Version of date:" "$(get_version 'date' || :)"
  printf '%s%s\n' "Bits of CET-1 'date' timestamp: ${_date_bit:?}" "$(test "${date_timezone_bug:?}" = 'false' || printf ' %s\n' '(with time zone bug)' || true)"
  printf '%s\n' "Bits of 'date -u' timestamp: ${_date_u_bit:?}"
}

main
pause_if_needed
