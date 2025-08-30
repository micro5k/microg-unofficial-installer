#!/usr/bin/env sh
# SPDX-FileCopyrightText: (c) 2024 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

SCRIPT_NAME='Bits info'
SCRIPT_VERSION='1.5.30'

### CONFIGURATION ###

set -u 2> /dev/null || :

# shellcheck disable=SC3040 # Ignore: In POSIX sh, set option pipefail is undefined
case "$(set 2> /dev/null -o || set || :)" in *'pipefail'*) set -o pipefail || echo 1>&2 'Failed: pipefail' ;; *) ;; esac

# The "obosh" shell does NOT support "command" while the "posh" shell does NOT support "type"
{
  command 1> /dev/null -v ':'
} 2> /dev/null || command()
{
  test "${1:-empty}" = '-v' || exit 255
  shift
  type "${@}"
}

# For "zsh" shell
if command 1> /dev/null 2>&1 -v 'setopt'; then
  setopt SH_WORD_SPLIT || printf 1>&2 '%s\n' 'Failed: setopt'
fi

# Workaround for shells without support for local (example: ksh pbosh obosh)
command 1> /dev/null 2>&1 -v 'local' || {
  eval ' local() { :; } ' || :
  # On some variants of ksh this really works, but leave the function as dummy fallback
  if command 1> /dev/null 2>&1 -v 'typeset'; then alias 'local'='typeset'; fi
}

### SCRIPT ###

convert_max_signed_int_to_bit()
{
  # More info: https://www.netmeister.org/blog/epoch.html

  case "${1}" in
    '32767') printf '%s\n' '16-bit signed' ;;                                                      # Standard 16-bit limit
    '2147480047') printf '%s\n' '32-bit signed - 3600' ;;                                          # Standard 32-bit limit - 3600 for timezone diff. on 'date'
    '2147483647') printf '%s\n' '32-bit signed' ;;                                                 # Standard 32-bit limit
    '32535215999') printf '%s\n' "64-bit signed (with limit: ${1})" ;;                             # 64-bit 'date' limited by the OS (likely under Windows)
    '32535244799') printf '%s\n' '64-bit signed (limited by Windows localtime function)' ;;        # 64-bit 'date' limited by the OS (likely on BusyBox under Windows)
    '67767976233529199') printf '%s\n' '64-bit signed (limited by tzcode bug - 3600)' ;;           # 64-bit 'date' limited by the OS - 3600 for timezone diff. (likely on Bash under Windows)
    '67767976233532799') printf '%s\n' '64-bit signed (limited by tzcode bug)' ;;                  # 64-bit 'date' limited by the OS (likely on Bash under Windows)
    '67768036191673199') printf '%s\n' '64-bit signed (limited by 32-bit tm_year of tm - 3600)' ;; # 64-bit 'date' limited by the OS - 3600 for timezone diff. (likely under Linux)
    '67768036191676799') printf '%s\n' '64-bit signed (limited by 32-bit tm_year of tm)' ;;        # 64-bit 'date' limited by the OS (likely under Linux)
    '9223372036854775807') printf '%s\n' '64-bit signed' ;;                                        # Standard 64-bit limit
    '170141183460469231731687303715884105727') printf '%s\n' '128-bit signed' ;;

    *)
      printf '%s\n' 'unknown'
      return 1
      ;;
  esac

  return 0
}

convert_max_unsigned_int_to_bit()
{
  local bug_suffix
  bug_suffix=''
  test "${2:-false}" = 'true' || bug_suffix=' BUG'

  case "${1}" in
    '32767') printf '%s\n' "16-bit signed${bug_suffix}" ;;
    '65535') printf '%s\n' "16-bit unsigned" ;;
    '256446000') printf '%s\n' "32-bit BROKEN" ;;
    '2147483647') printf '%s\n' "32-bit signed${bug_suffix}" ;; # Bugged unsigned 'printf' of awk (seen on some versions of Bash)
    '2147483648') printf '%s\n' "32-bit signed + 1 BB BUG" ;;   # Bugged unsigned 'printf' of awk (likely on BusyBox)
    '4294967295') printf '%s\n' "32-bit unsigned" ;;
    '9223372036854775807') printf '%s\n' "64-bit signed${bug_suffix}" ;;     # Bugged unsigned 'printf' (seen on Ksh93 / Oils)
    '9223372036854775808') printf '%s\n' "64-bit signed + 1${bug_suffix}" ;; # Bugged unsigned 'printf' (seen on Ksh93)
    '18446744073709551614') printf '%s\n' "64-bit unsigned - 1" ;;
    '18446744073709551615') printf '%s\n' "64-bit unsigned" ;;
    '170141183460469231731687303715884105727') printf '%s\n' "128-bit signed${bug_suffix}" ;;
    '340282366920938463463374607431768211455') printf '%s\n' "128-bit unsigned" ;;

    'unsupported' | 'ignored')
      printf '%s\n' "${1}"
      return 2
      ;;
    *)
      printf '%s\n' 'unknown'
      return 1
      ;;
  esac

  return 0
}

warn_msg()
{
  if test -n "${NO_COLOR-}"; then
    printf 1>&2 '%s\n' "WARNING: ${1}"
  elif test "${CI:-false}" = 'false'; then
    printf 1>&2 '\033[0;33m\r%s\n\033[0m\r    \r' "WARNING: ${1}"
  else
    printf 1>&2 '\033[0;33m%s\033[0m\n' "WARNING: ${1}"
  fi
}

inc_num()
{
  # NOTE: We are going to test integers at (and over) the shell limit so we can NOT use shell arithmetic because it can overflow

  case "${1}" in
    '-1' | '256446000') return 1 ;;
    '32767') printf '%s\n' '32768' ;;
    '65535') printf '%s\n' '65536' ;;
    '2147480047') printf '%s\n' '2147480048' ;;
    '2147483647') printf '%s\n' '2147483648' ;;
    '2147483648') printf '%s\n' '2147483649' ;;
    '4294967295') printf '%s\n' '4294967296' ;;
    '32535215999') printf '%s\n' '32535216000' ;;
    '32535244799') printf '%s\n' '32535244800' ;;
    '67767976233529199') printf '%s\n' '67767976233529200' ;;
    '67767976233532799') printf '%s\n' '67767976233532800' ;;
    '67768036191673199') printf '%s\n' '67768036191673200' ;;
    '67768036191676799') printf '%s\n' '67768036191676800' ;;
    '9223372036854775807') printf '%s\n' '9223372036854775808' ;;
    '9223372036854775808') printf '%s\n' '9223372036854775809' ;;
    '18446744073709551614') printf '%s\n' '18446744073709551615' ;;
    '18446744073709551615') printf '%s\n' '18446744073709551616' ;;

    *)
      warn_msg "Unexpected number => ${1}"
      return 2
      ;;
  esac

  return 0
}

permissively_comparison()
{
  local _comp_list _comp_num

  case "${2}" in
    '') return 1 ;;
    '9223372036854775807') _comp_list="${2} 9223372036854775808 9.22337e+018" ;;
    '9223372036854775808') _comp_list="${2} 9.22337e+018" ;;
    '18446744073709551615') _comp_list="${2} 1.84467e+19 1.84467e+019" ;;
    *) _comp_list="${2}" ;;
  esac

  for _comp_num in ${_comp_list}; do
    if test "${1}" = "${_comp_num}"; then
      return 0
    fi
  done

  return 1
}

is_shell_msys()
{
  local _uname_os

  test -x '/usr/bin/uname' && _uname_os="$(/usr/bin/uname 2> /dev/null -o)" && test "${_uname_os}" = 'Msys'
}

file_getprop()
{
  grep -m 1 -F -e "${1:?}=" -- "${2:?}" | cut -d '=' -f '2-' -s
}

detect_hex_dump_cmd()
{
  if command 1> /dev/null 2>&1 -v 'xxd'; then
    printf '%s\n' 'xxd'
  elif command 1> /dev/null 2>&1 -v 'hexdump' && test "$(printf ' ' | hexdump 2> /dev/null -v -e '/1 "%02x"' || :)" = '20'; then
    printf '%s\n' 'hexdump'
  elif command 1> /dev/null 2>&1 -v 'od'; then
    printf '%s\n' 'od'
  else
    return 1
  fi
  return 0
}

dump_hex()
{
  if test "${HEXDUMP_CMD:=$(detect_hex_dump_cmd || :)}" = 'xxd'; then
    xxd -p -s "${2}" -c "${3}" -l "${3}" -- "${1}"
  elif test "${HEXDUMP_CMD?}" = 'hexdump'; then
    hexdump -v -e '/1 "%02x"' -s "${2}" -n "${3}" -- "${1}" && printf '\n'
  elif test "${HEXDUMP_CMD?}" = 'od'; then
    od -v -A 'n' -j "${2}" -N "${3}" -t 'x1' -- "${1}" | tr -d ' \n' && printf '\n'
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

  if test "${3:-false}" = 'true'; then
    if test "${2:?}" -eq 2; then
      _hbti_num="$(switch_endianness_2 "${1}")" || return "${?}"
    elif test "${2:?}" -eq 4; then
      _hbti_num="$(switch_endianness_4 "${1}")" || return "${?}"
    else
      return 9
    fi
  else
    _hbti_num="${1}"
  fi

  printf '%u' "0x${_hbti_num:?}"
}
# Params:
#  $1 Input bytes (hex)
#  $2 Bytes to skip (int)
#  $3 Length in bytes (int)
#  $4 Bytes to compare (hex)
compare_hex_bytes()
{
  test "${3}" -gt 0 || return 2
  set -- "${1}" "$((${2} * 2 + 1))" "$(((${2} + ${3}) * 2))" "${4}" || return 3
  test "$(printf '%s' "${1}" | cut -b "${2}-${3}" || :)" = "${4}"
}

# Params:
#  $1 Input bytes (hex)
#  $2 Bytes to skip (int)
#  $3 Length in bytes (int)
extract_bytes()
{
  test "${3}" -gt 0 || return 2
  set -- "${1}" "$((${2} * 2 + 1))" "$(((${2} + ${3}) * 2))" || return 3
  printf '%s' "${1}" | cut -b "${2}-${3}"
}

# Params:
#  $1 Input bytes (hex)
#  $2 Bytes to skip (int)
#  $3 Length in bytes (int)
#  $4 Need bytes swap (bool)
extract_bytes_and_swap()
{
  test "${3}" -gt 0 || return 2
  set -- "${1}" "$((${2} * 2 + 1))" "$(((${2} + ${3}) * 2))" "${3}" "${4:-false}" || return 3

  if test "${5}" = 'true'; then
    if test "${4}" = 4; then
      switch_endianness_4 "$(printf '%s' "${1}" | cut -b "${2}-${3}" || :)" || return "${?}"
    else
      return 4
    fi
  else
    printf '%s' "${1}" | cut -b "${2}-${3}"
  fi
}

detect_bitness_of_single_file()
{
  local _dbf_first_bytes _dbf_first_2_bytes _dbf_size _dbf_bytes_swap _dbf_pos _header _dbf_exe_type _dbf_cpu_type _dbf_i _dbf_tmp
  local _pe_size_optional_header _pe_size_all_headers _pe_size_initializ_data

  if test ! -f "${1}" || ! _dbf_first_bytes="$(dump_hex "${1}" '0' '64')"; then # Cache bytes at pos 0x00 - 0x40
    printf '%s\n' 'failed'
    return 1
  fi
  _dbf_first_2_bytes="$(extract_bytes "${_dbf_first_bytes}" '0' '2')" || _dbf_first_2_bytes=''

  if test "${_dbf_first_2_bytes}" = '4d5a'; then
    # MZ - Executable binaries for Windows / DOS (.exe) | Offset: 0x00 - Magic: MZ (0x4D 0x5A)
    # More info: https://wiki.osdev.org/MZ

    _dbf_bytes_swap='true'
    _dbf_exe_type=''
    _dbf_pos=''

    # APE - Actually Portable Executables | Offset: 0x00 - Magic: MZ (0x4D 0x5A), qFpD (0x71 0x46 0x70 0x44)
    if compare_hex_bytes "${_dbf_first_bytes}" '2' '4' '71467044'; then _dbf_exe_type='APE '; fi

    # The smallest possible PE file is 97 bytes: http://www.phreedom.org/research/tinype/
    # PE files, to be able to be executed on Windows (it is different under DOS), only need two fields in the MZ header: e_magic (0x00 => 0) and e_lfanew (0x3C => 60)
    if
      _dbf_pos="$(extract_bytes "${_dbf_first_bytes}" '60' '4')" && _dbf_pos="$(hex_bytes_to_int "${_dbf_pos?}" '4' "${_dbf_bytes_swap:?}")" &&
        test "${_dbf_pos:?}" -ge 4 && test "${_dbf_pos:?}" -le 536870912 &&
        _header="$(dump_hex "${1:?}" "${_dbf_pos:?}" '88')"
    then
      :
    else _header=''; fi

    if test -n "${_header}"; then
      if compare_hex_bytes "${_header}" '0' '4' '50450000'; then
        # PE header => PE (0x50 0x45) + 0x00 + 0x00 + Machine field
        # More info: https://www.aldeid.com/wiki/PE-Portable-executable
        # More info: https://learn.microsoft.com/en-us/windows/win32/debug/pe-format

        if
          # SizeOfOptionalHeader => Offset: PE header pos + 0x14 (dec: 20)
          _pe_size_optional_header="$(extract_bytes "${_header?}" '20' '2')" &&
            _pe_size_optional_header="$(hex_bytes_to_int "${_pe_size_optional_header}" '2' "${_dbf_bytes_swap:?}")"
        then

          if
            test "${_pe_size_optional_header}" -ge 64 &&
              # SizeOfHeaders => Offset: PE header pos + 0x54 (dec: 84)
              _pe_size_all_headers="$(extract_bytes "${_header?}" '84' '4')" && _pe_size_all_headers="$(hex_bytes_to_int "${_pe_size_all_headers}" '4' "${_dbf_bytes_swap:?}")" &&
              # SizeOfInitializedData => Offset: PE header pos + 0x20 (dec: 32)
              _pe_size_initializ_data="$(extract_bytes "${_header?}" '32' '4')" && _pe_size_initializ_data="$(hex_bytes_to_int "${_pe_size_initializ_data}" '4' "${_dbf_bytes_swap:?}")"
          then
            # IMPORTANT: Initial code (not compatible with all files)
            if _dbf_tmp="$(dump_hex "${1:?}" "$((_pe_size_all_headers + _pe_size_initializ_data))" '6')" && compare_hex_bytes "${_dbf_tmp}" '0' '6' '377abcaf271c'; then
              _dbf_exe_type="${_dbf_exe_type?}7z "
            fi
          fi

          # PE type magic => Offset: PE header pos + 0x18 (dec: 24)
          if _dbf_tmp="$(extract_bytes "${_header?}" '24' '2')" && _dbf_tmp="$(switch_endianness_2 "${_dbf_tmp?}")"; then
            case "${_dbf_tmp?}" in
              '010b') _dbf_exe_type="${_dbf_exe_type?}PE32" ;;
              '020b') _dbf_exe_type="${_dbf_exe_type?}PE32+" ;;
              '0107') _dbf_exe_type="${_dbf_exe_type?}PE ROM image" ;;
              *) _dbf_exe_type="${_dbf_exe_type?}Unknown PE" ;;
            esac
          fi
        else
          _dbf_exe_type="${_dbf_exe_type?}Invalid PE"
        fi

        _dbf_cpu_type="$(extract_bytes "${_header:?}" '4' '2')" || _dbf_cpu_type=''
        if test "${_dbf_bytes_swap:?}" = 'true'; then
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
        case "${_header}" in
          '4e45'*)
            # NE (New Executable) header => NE (0x4E 0x45)
            printf '%s\n' '16-bit NE'
            return 0
            ;;
          '4c45'*)
            # LE (Linear Executable) header => LE (0x4C 0x45)
            printf '%s\n' '16/32-bit LE'
            return 0
            ;;
          '4c58'*)
            # LX (Linear Executable) header => LX (0x4C 0x58)
            printf '%s\n' '32-bit LX'
            return 0
            ;;
          *) ;;
        esac
      fi

      #printf '\n' && hexdump -v -C -s "${_dbf_pos}" -n '6' -- "${1}" # Debug
    fi

    # The absolute offset to the relocation table is stored at: 0x18 (decimal: 24)
    # The absolute offset to the relocation table of plain MZ files (so not extended ones) must be: > 0x1B (decimal: 27) and < 0x40 (decimal: 64)
    # NOTE: This does NOT apply to PE files as this field is not used on them
    if _dbf_tmp="$(extract_bytes "${_dbf_first_bytes}" '24' '2')" && _dbf_tmp="$(hex_bytes_to_int "${_dbf_tmp?}" '2' "${_dbf_bytes_swap}")"; then
      if
        {
          test "${_dbf_tmp:?}" -gt 27 && test "${_dbf_tmp:?}" -lt 64
        } ||
          {
            test "${_dbf_tmp:?}" = 0 && compare_hex_bytes "${_dbf_first_bytes}" '6' '2' '0000' # Empty relocation table
          }
      then
        printf '%s\n' '16-bit MZ'
        return 0
      fi
    fi

    printf '%s\n' 'unknown-mz-file'
    return 5
  fi

  if compare_hex_bytes "${_dbf_first_bytes}" '0' '4' '7f454c46'; then
    # ELF - Executable binaries for Linux / Android | Offset: 0x00 - Magic: 0x7F, ELF (0x45 0x4C 0x46), 0x01 for 32-bit or 0x02 for 64-bit

    _header="$(extract_bytes "${_dbf_first_bytes}" '4' '1')" || _header=''
    case "${_header}" in
      '02') printf '%s\n' '64-bit ELF' ;;
      '01') printf '%s\n' '32-bit ELF' ;;
      *)
        printf '%s\n' 'unknown-elf-file'
        return 3
        ;;
    esac
    return 0
  fi

  local _dbf_is_mach _dbf_mach_type _dbf_arch_count _dbf_has64 _dbf_has32
  _dbf_is_mach='false'

  if _header="$(extract_bytes "${_dbf_first_bytes}" '0' '4')"; then
    _dbf_is_mach='true'
    _dbf_mach_type=''
    _dbf_bytes_swap='false'

    case "${_header}" in
      'feedface') # MH_MAGIC
        _dbf_mach_type='base'
        ;;
      'cefaedfe') # MH_CIGAM
        _dbf_mach_type='base'
        _dbf_bytes_swap='true'
        ;;
      'feedfacf') # MH_MAGIC_64
        _dbf_mach_type='base'
        ;;
      'cffaedfe') # MH_CIGAM_64
        _dbf_mach_type='base'
        _dbf_bytes_swap='true'
        ;;
      'cafebabe') # FAT_MAGIC
        if _dbf_arch_count="$(extract_bytes "${_dbf_first_bytes}" '4' '4')" && _dbf_arch_count="$(hex_bytes_to_int "${_dbf_arch_count}" '4' 'false')" &&
          test "${_dbf_arch_count}" -le 30; then
          # Both this and Java bytecode have the same magic number (more info: https://opensource.apple.com/source/file/file-80.40.2/file/magic/Magdir/cafebabe.auto.html)
          _dbf_mach_type='fat'
        else
          _dbf_is_mach='false'
          printf '%s\n' 'Bit-independent Java bytecode'
          return 0
        fi
        ;;
      'bebafeca') # FAT_CIGAM
        _dbf_mach_type='fat'
        _dbf_bytes_swap='true'
        ;;
      'cafebabf') # FAT_MAGIC_64
        #_dbf_mach_type='fat'
        ;;
      'bfbafeca') # FAT_CIGAM_64
        #_dbf_mach_type='fat'
        _dbf_bytes_swap='true'
        ;;

      *) _dbf_is_mach='false' ;;
    esac
  fi

  if test "${_dbf_is_mach}" = 'true'; then
    # Mach-O

    if test "${_dbf_mach_type}" = 'base'; then
      # Base Mach-O

      if _dbf_tmp="$(extract_bytes_and_swap "${_dbf_first_bytes}" '4' '4' "${_dbf_bytes_swap}")"; then
        case "${_dbf_tmp}" in
          '01'*) printf '%s\n' '64-bit Mach-O' ;;
          '00'*) printf '%s\n' '32-bit Mach-O' ;;
          *)
            printf '%s\n' 'unknown-base-mach-file'
            return 6
            ;;
        esac

        return 0
      fi
    elif
      test "${_dbf_mach_type}" = 'fat' && _dbf_arch_count="$(extract_bytes "${_dbf_first_bytes}" '4' '4')" &&
        _dbf_arch_count="$(hex_bytes_to_int "${_dbf_arch_count}" '4' "${_dbf_bytes_swap}")" &&
        test "${_dbf_arch_count}" -gt 0 && test "${_dbf_arch_count}" -lt 256
    then
      # FAT Mach-O

      _dbf_has64='false'
      _dbf_has32='false'
      _dbf_pos='8'
      _dbf_i="${_dbf_arch_count:?}"
      while test "$((_dbf_i = _dbf_i - 1))" -ge 0; do
        _dbf_tmp="$(dump_hex "${1:?}" "${_dbf_pos:?}" '4')" || _dbf_tmp=''
        if test "${_dbf_bytes_swap:?}" = 'true'; then
          _dbf_tmp="$(switch_endianness_4 "${_dbf_tmp?}")" || _dbf_tmp=''
        fi
        _dbf_pos="$((_dbf_pos + 20))" || _dbf_tmp='' # Should be pos + 32 on FAT_MAGIC_64 (need test)

        case "${_dbf_tmp?}" in
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
    fi

    printf '%s\n' 'unknown-mach-file'
    return 7
  fi

  if compare_hex_bytes "${_dbf_first_bytes}" '0' '4' 'ffffffff'; then
    # DOS device driver (.dos, .sys, .dev, .bin) | Offset: 0x00 - Magic: 0xFF, 0xFF, 0xFF, 0xFF
    # More info: http://fileformats.archiveteam.org/wiki/DOS_device_driver

    printf '%s\n' '16-bit DOS device driver'
    return 0
  fi

  if compare_hex_bytes "${_dbf_first_bytes}" '0' '8' 'd0cf11e0a1b11ae1'; then
    # CFBF - Compound File Binary Format (.msi / .msp) | Offset: 0x00 - Magic: 0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1

    printf '%s\n' 'Bit-independent CFBF'
    return 0
  fi

  if compare_hex_bytes "${_dbf_first_bytes}" '0' '4' '504b0304'; then
    # PKZip archive (.zip / .jar / .apk) | Offset: 0x00 - Magic: PK (0x50 0x4B), 0x03, 0x04
    # More info: https://users.cs.jmu.edu/buchhofp/forensics/formats/pkzip.html

    printf '%s\n' 'Bit-independent PKZip archive'
    return 0
  fi

  if compare_hex_bytes "${_dbf_first_bytes}" '0' '6' '377abcaf271c'; then
    # 7z archive (.7z) | Offset: 0x00 - Magic: 7z (0x37 0x7A), 0xBC, 0xAF, 0x27, 0x1C
    # More info: https://py7zr.readthedocs.io/en/latest/archive_format.html

    printf '%s\n' 'Bit-independent 7z archive'
    return 0
  fi

  if test "${_dbf_first_2_bytes?}" = '2321'; then
    # Scripts (often shell scripts) | Offset: 0x00 - Magic: #! (0x23 0x21)
    printf '%s\n' 'Bit-independent script'
    return 0
  fi

  if compare_hex_bytes "${_dbf_first_bytes}" '4' '4' '50413330'; then
    # Windows Patch Delta | Offset: 0x04 - Magic: PA30 (0x50 0x41 0x33 0x30)
    # More info: https://wumb0.in/extracting-and-diffing-ms-patches-in-2020.html

    printf '%s\n' 'Bit-independent Windows Patch Delta'
    return 0
  fi

  _dbf_size="$(stat -c '%s' -- "${1}")" || {
    printf '%s\n' 'failed'
    return 1
  }

  if test "${_dbf_size}" = 0; then
    printf '%s\n' 'Empty file'
    return 0
  elif test "${_dbf_size}" -gt 0; then
    : # OK
  else
    # It overflowed, probably the file is too big to be handled by this shell
    printf '%s\n' 'failed'
    return 1
  fi

  if test "${_dbf_size}" -ge 512 && test "$(dump_hex "${1:?}" "$((_dbf_size - 512))" '4' || :)" = '6b6f6c79'; then
    # DMG - Apple Disk Image | Offset: 512 from end - Magic: koly (0x6B 0x6F 0x6C 0x79)
    # More info: https://newosxbook.com/DMG.html

    printf '%s\n' 'Bit-independent DMG'
    return 0
  fi

  if test "${_dbf_size}" -le 65280 && test "${_dbf_size}" -ge 2; then
    _dbf_tmp="$(extract_bytes "${_dbf_first_2_bytes}" '0' '1')" || _dbf_tmp=''
    if test "${_dbf_tmp}" = 'e9' || test "${_dbf_tmp}" = 'eb' || test "${_dbf_first_2_bytes}" = '81fc' || test "${_dbf_first_2_bytes}" = 'b409'; then
      # COM - Executable binaries for DOS (.com)

      # To detect COM programs we can check if the first byte of the file could be a valid jump or call opcode (most common: 0xE9 or 0xEB).
      # This isn't a safe way to determine wether a file is a COM file or not, but most COM files start with a jump.
      # A COM program can only have a size of less than one segment (64K).
      # The maximum size of the file is 65280 bytes.

      printf '%s\n' '16-bit COM'
      return 0
    fi
  fi

  case "${1:?}" in
    *'.sh')
      'Bit-independent script'
      return 0
      ;;
    *'.bat')
      printf '%s\n' 'Bit-independent batch'
      return 0
      ;;
    *) ;;
  esac

  printf '%s\n' 'unknown-file-type'
  return 2
}

detect_bitness_of_single_file_caller()
{
  local _dbsfc_ret_code _dbsfc_lcall

  _dbsfc_lcall="${LC_ALL-unset}"
  LC_ALL='C' # We only use bytes and not characters
  export LC_ALL

  _dbsfc_ret_code=0
  detect_bitness_of_single_file "${1}" || _dbsfc_ret_code="${?}"

  if test "${_dbsfc_lcall}" = 'unset'; then unset LC_ALL; else LC_ALL="${_dbsfc_lcall}"; fi

  return "${_dbsfc_ret_code}"
}

detect_bitness_of_files()
{
  local _dbof_ret_code _dbof_file_list _dbof_filename _dbof_lcall

  # With a single file it returns the specific error code otherwise if there are multiple files it returns the number of files that were not recognized.
  # If the number is greater than 125 then it returns 125.
  _dbof_ret_code=0

  if is_shell_msys; then
    # We must do this in all cases with Bash under Windows using this POSIX layer otherwise we may run into freezes, obscure errors and unknown infinite loops!!!
    PATH="/usr/bin:${PATH:-%empty}"
  fi

  # Detect usable utility
  : "${HEXDUMP_CMD:=$(detect_hex_dump_cmd || :)}"

  if test "${1:-empty}" = '-' && test "${#}" -eq 1; then

    (
      _dbof_file_list="$(cat | tr -- '\0' '\n')" || _dbof_file_list=''

      IFS="$(printf '\nx')" IFS="${IFS%x}"
      # shellcheck disable=SC2030 # Intended: Modification of LC_ALL is local (to subshell)
      LC_ALL='C' # We only use bytes and not characters
      export LC_ALL

      if test -n "${_dbof_file_list}"; then
        for _dbof_filename in ${_dbof_file_list}; do
          printf '%s: ' "${_dbof_filename}"
          detect_bitness_of_single_file "${_dbof_filename}" || _dbof_ret_code="$((_dbof_ret_code + 1))"
        done
      else
        _dbof_ret_code=1
      fi
      printf '\nUnidentified files: %s\n' "${_dbof_ret_code}"

      test "${_dbof_ret_code}" -le 125 || return 125
      return "${_dbof_ret_code}"
    ) ||
      _dbof_ret_code="${?}"

  else

    # shellcheck disable=SC2031
    _dbof_lcall="${LC_ALL-unset}"
    LC_ALL='C' # We only use bytes and not characters
    export LC_ALL

    if test "${#}" -le 1; then
      detect_bitness_of_single_file "${1-}" || _dbof_ret_code="${?}"
    else
      test -n "${1}" || shift
      while test "${#}" -gt 0; do
        printf '%s: ' "$1"
        detect_bitness_of_single_file "$1" || _dbof_ret_code="$((_dbof_ret_code + 1))"
        shift
      done
      printf '\nUnidentified files: %s\n' "${_dbof_ret_code}"
    fi

    if test "${_dbof_lcall}" = 'unset'; then unset LC_ALL; else LC_ALL="${_dbof_lcall}"; fi

  fi

  test "${_dbof_ret_code}" -le 125 || return 125
  return "${_dbof_ret_code}"
}

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

get_shell_info()
{
  local _shell_use_ver_opt _shell_exe _shell_name _shell_version _shell_is_ksh _tmp_var

  _shell_use_ver_opt='false'
  _shell_exe="${1-}"
  _shell_name=''
  _shell_version=''
  _shell_is_ksh='false'

  if test -n "${_shell_exe}"; then
    _shell_name="$(basename "${_shell_exe}" | tr -d ' ')" || _shell_name=''
    _shell_name="${_shell_name%'.exe'}" # For shells under Windows
  fi

  if test -z "${_shell_name}"; then
    printf '%s\n' 'not-found unknown'
    return 1
  fi

  case "${_shell_exe}" in
    *'/bosh/'*'/sh' | *'/bosh/sh') _shell_name='bosh' ;;
    *'/oils-for-unix' | *'/oil.ovm') _shell_name='oils' ;;
    *) ;;
  esac

  case "${_shell_name}" in
    *'ksh'*) _shell_is_ksh='true' ;;
    'bash' | 'zsh' | 'yash' | 'oils' | 'bosh' | 'pbosh' | 'obosh' | 'tcsh' | 'fish') _shell_use_ver_opt='true' ;;
    *'\bash') # For bugged versions of Bash under Windows
      _shell_use_ver_opt='true'
      _shell_name='bash'
      ;;
    *) ;;
  esac

  # Various shells doesn't support '--version' and in addition some bugged versions of BusyBox open
  # an interactive shell when the '--version' option is used, so use it only when really needed.

  if test "${_shell_use_ver_opt}" = 'true' && _shell_version="$("${_shell_exe}" 2>&1 --version)" && test -n "${_shell_version}"; then
    :
  else
    # NOTE: "sh --help" of BusyBox may return failure but still print the correct output although it may be printed to STDERR
    _shell_version="$("${_shell_exe}" 2> /dev/null -Wversion || "${_shell_exe}" 2>&1 --help || :)"
  fi
  _shell_version="$(printf '%s\n' "${_shell_version}" | head -n 1)" || return "${?}"

  case "${_shell_version}" in
    '' | *'Usage'* | *'invalid option'* | *'unrecognized option'* | *[Uu]'nknown option'* | *[Ii]'llegal option'* | *'not an option'* | *'bad option'* | *'command not found'* | *'No such file or directory'*)
      if test "${_shell_is_ksh}" = 'true' && test -n "${KSH_VERSION-}" && _shell_version="${KSH_VERSION}"; then
        : # For ksh (include also variants like mksh)
      elif test "${_shell_name}" = 'dash' && test -n "${DASH_VERSION-}" && _shell_version="${DASH_VERSION}"; then
        : # For dash (possibly supported in the future)
      elif test "${_shell_name}" = 'dash' && command 1> /dev/null 2>&1 -v 'dpkg' && _shell_version="$(dpkg -s 'dash' | grep -m 1 -F -e 'Version:' | cut -d ':' -f '2-' -s)" && test -n "${_shell_version}"; then
        : # For dash under Linux
      elif test "${_shell_name}" = 'dash' && command 1> /dev/null 2>&1 -v 'brew' && _shell_version="$(NO_COLOR=1 brew 2> /dev/null info 'dash' | head -n 1 | grep -m 1 -F -e 'dash:' | cut -d ':' -f '2-' -s | cut -d ',' -f '1')" && test -n "${_shell_version}"; then
        : # For dash under macOS
        _shell_version="${_shell_version# }"
        _shell_version="${_shell_version#stable }"
      elif test "${_shell_name}" = 'dash' && command 1> /dev/null 2>&1 -v 'apt-cache' && _shell_version="$(apt-cache policy 'dash' | grep -m 1 -F -e 'Installed:' | cut -d ':' -f '2-' -s)" && test -n "${_shell_version}"; then
        : # For dash under Linux (it is slow)
      elif test "${_shell_name}" = 'posh' && test -n "${POSH_VERSION-}" && _shell_version="${POSH_VERSION}"; then
        : # For posh
      elif _shell_version="$(\eval 2> /dev/null ' echo "${.sh.version}" ' || :)" && test -n "${_shell_version}"; then
        : # Fallback for old ksh and bosh
      elif test -n "${version-}" && _shell_version="${version}"; then
        : # Fallback for tcsh and fish (NOTE: although this variable would show the version unfortunately the code cannot be run on tcsh and fish due to syntax difference)
      else
        _shell_version=''
      fi
      ;;
    *) ;;
  esac

  case "${_shell_version}" in
    'BusyBox '*) _shell_name='busybox' ;;
    *' bash,'*) _shell_name='bash' ;; # Sometimes "sh" isn't just a symlink to "bash" but it is really called "sh" so we have to correct this
    '93u+'* | *' 93u+'*) test "${_shell_name}" != 'ksh' || _shell_name='ksh93' ;;
    *) ;;
  esac

  _shell_version="${_shell_version#*[Vv]ersion }"
  case "${_shell_name}" in
    'busybox') _shell_version="${_shell_version#BusyBox}" ;;
    'mksh') _shell_version="${_shell_version#*MIRBSD KSH}" ;;
    'pdksh' | 'oksh') _shell_version="${_shell_version#*PD KSH}" ;;
    'oils') _shell_version="$(printf '%s\n' "${_shell_version#Oils}" | cut -f '1')" ;;
    '') ;;
    *) _shell_version="${_shell_version#"${_shell_name}"}" ;;
  esac
  _shell_version="${_shell_version# }"
  _shell_version="${_shell_version#v}"

  printf '%s %s\n' "${_shell_name:-unknown}" "${_shell_version:-unknown}"
}

prefer_included_utilities_if_requested()
{
  local _piu_applet _piu_pathsep _piu_dir
  if test "${1}" = 0 || test -z "${2}"; then return 0; fi

  _piu_pathsep=':'
  if test "${3}" = 'busybox'; then
    if test "$(uname 2> /dev/null -o || :)" = 'MS/Windows'; then _piu_pathsep=';'; fi

    for _piu_applet in test printf uname awk cut date; do
      # Check if it does NOT already run the internal applet by default
      if test "$(command 2> /dev/null -v "${_piu_applet}" || :)" != "${_piu_applet}"; then
        \eval " ${_piu_applet}() { '${2}' '${_piu_applet}' \"\${@}\"; } " || : # Force internal applet
      fi
    done
  fi

  if _piu_dir="$(dirname "${2}")" && test -n "${_piu_dir}"; then
    PATH="${_piu_dir}${_piu_pathsep}${PATH:-%empty}"
    export PATH
  fi
}

get_applet_name()
{
  local _shell_cmdline _gan_applet _gan_backup_ifs _gan_sep

  case "${1}" in
    'busybox' | 'oils')
      if test -r "/proc/${$}/cmdline" && _shell_cmdline="$(tr -- '\n\0' ' \n' 0< "/proc/${$}/cmdline")" && test -n "${_shell_cmdline}"; then
        _gan_sep="$(printf '\nx')" _gan_sep="${_gan_sep%x}"

        _gan_backup_ifs="${IFS-unset}"
        IFS="${_gan_sep}"
        # shellcheck disable=SC2086 # Ignore: Double quote to prevent globbing and word splitting
        set -- ${_shell_cmdline} || set -- || return 126
        if test "${_gan_backup_ifs}" = 'unset'; then unset IFS; else IFS="${_gan_backup_ifs}"; fi
      elif _shell_cmdline="$(ps 2> /dev/null -p "${$}" -o 'args=')" && test -n "${_shell_cmdline}"; then
        set -- "${_shell_cmdline}" || set -- || return 126
      else
        set -- || return 126
      fi

      # We cover two cases:
      # - /bin/busybox ash
      # - /bin/ash

      if test "${#}" -gt 0; then
        for _gan_applet in bash lash msh hush ash osh ysh oil sh; do
          if test "${2:-empty}" = "${_gan_applet}"; then
            : # Found
          else
            case "${1:-empty}" in
              *"/${_gan_applet}"* | *" ${_gan_applet}"*) ;; # Found
              *) continue ;;                                # Not found yet
            esac
          fi

          printf '%s\n' "${_gan_applet}"
          return 0
        done
      fi
      ;;
    *)
      return 2 # NOT an applet
      ;;
  esac

  printf '%s\n' 'unknown'
  return 0
}

retrieve_bitness_from_uname()
{
  # IMPORTANT: Typically it should return the bitness of the OS, but in some cases it just returns the bitness of the shell (use it only as last resort)

  case "$(uname 2> /dev/null -m || :)" in
    x86_64 | ia64 | arm64 | aarch64 | mips64) printf '%s\n' '64-bit' ;;
    x86 | i686 | i586 | i486 | i386 | armv7* | mips) printf '%s\n' '32-bit' ;;
    *)
      printf '%s\n' 'unknown'
      return 1
      ;;
  esac
  return 0
}

get_os_info()
{
  local _os_name _os_version

  # Bugged versions of uname may return errors on STDOUT when used with unsupported options
  _os_name="$(uname 2> /dev/null -o)" || _os_name="$(uname 2> /dev/null)" || _os_name=''
  _os_version=''

  case "${_os_name}" in
    'MS/Windows')
      _os_version="$(uname -r -v | tr -- ' ' '.' || :)"
      ;;
    'Msys')
      _os_name='MS/Windows'
      _os_version="$(uname | cut -d '-' -f '2-' -s | tr -- '-' '.' || :)"
      ;;
    'Windows_NT') # Bugged versions of uname: it doesn't support uname -o and it is unable to retrieve the correct version of Windows
      _os_name='MS/Windows'
      ;;
    'GNU/Linux')
      if _os_version="$(getprop 2> /dev/null 'ro.build.version.release')" && test -n "${_os_version}"; then
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
  local _version

  if ! command 1> /dev/null 2>&1 -v "${1}"; then
    printf '%s\n' 'missing'
    return 1
  fi

  # NOTE: "cut --version" of GNU textutils 1.5 return failure but still print the correct output although it is printed to STDERR
  _version="$("${1}" 2> /dev/null -Wversion || "${1}" 2>&1 --version || :)"
  case "${_version}" in *'CENIT Advanced Logfile Adapter'*) printf '%s\n' 'CENIT' && return 0 ;; *) ;; esac
  _version="$(printf '%s\n' "${_version}" | head -n 1)" || _version=''

  case "${_version}" in
    '' | *[Uu]'sage'* | *'invalid option'* | *'unrecognized option'* | *[Uu]'nknown option'* | *[Ii]'llegal option'* | *'not an option'* | *'bad option'*)

      # NOTE: "date --help" and "awk --help" of old BusyBox return failure but still print the correct output although it may be printed to STDERR
      _version="$("${1}" 2>&1 --help || :)"
      _version="$(printf '%s\n' "${_version}" | head -n 1)" || _version=''
      case "${_version}" in
        '' | *[Uu]'sage'* | *'invalid option'* | *'unrecognized option'* | *[Uu]'nknown option'* | *[Ii]'llegal option'* | *'not an option'* | *'bad option'*)
          printf '%s\n' 'unknown'
          return 2
          ;;
        *) ;;
      esac
      ;;

    *) ;;
  esac

  printf '%s\n' "${_version}"
}

get_max_unsigned_int_of_shell_printf()
{
  # Some shells do NOT allow this, so we hide the errors
  printf 2> /dev/null '%s\n' "$(printf '%u\n' '-1')"
}

test_seed_of_random()
{
  RANDOM="${1}"
}

seed_and_get_random()
{
  RANDOM="${1}"
  # shellcheck disable=SC3028 # In POSIX sh, RANDOM is undefined
  printf '%s\n' "${RANDOM}"
}

validate_num_for_cut_b()
{
  if test "${2}" = 'mac'; then
    case "${1}" in
      '4294967296') # This number can make the "cut" of macOS freeze forever
        printf '%s\n' '4294967297'
        return 0
        ;;
      *) ;;
    esac
  fi

  printf '%s\n' "${1}"
}

detect_bits_of_cut_b()
{
  local _dbcb_max _dbcb_num _dbcb_tmp

  _dbcb_max='-1'
  for _dbcb_num in ${1}; do
    if _dbcb_tmp="$(: | cut 2> /dev/null -b "${_dbcb_num}")"; then
      _dbcb_max="${_dbcb_num}"
    else
      if _dbcb_num="$(inc_num "${_dbcb_max}")" && _dbcb_num="$(validate_num_for_cut_b "${_dbcb_num}" "${2}")" && _dbcb_tmp="$(: | cut 2> /dev/null -b "${_dbcb_num}")"; then
        if test "${2}" = 'mac'; then
          warn_msg 'Detection of cut -b was inconclusive!!!'
        else
          warn_msg 'Detection of cut -b was inconclusive, please report it to the author!!!'
        fi
      fi
      break
    fi
  done

  printf '%s\n' "${_dbcb_max}"
}

code_timeout()
{
  local _func_name _sec_limit _pid _bg_status

  _func_name="${1}"
  _sec_limit="${2}"
  shift 2

  "${_func_name}" 2>&3 "${@}" &
  _pid="${!}"
  if test -z "${_pid}" || test "${_pid}" = "${$}" || test "${_pid}" -le 1; then return 126; fi # Seriously broken shell

  while test "$((_sec_limit = _sec_limit - 1))" -ge 0; do
    sleep 1
    if kill 2> /dev/null 1>&2 -0 "${_pid}"; then
      : # Still running
    else
      _bg_status=0
      wait 1>&3 2>&3 "${_pid}" || _bg_status="${?}"
      test "${_bg_status}" != 127 || return 0 # On some shells "wait" misbehave and return 127 even on success
      return "${_bg_status}"
    fi
  done

  kill 2> /dev/null 1>&2 -9 "${_pid}" || :
  return 124
}

list_available_shells()
{
  if chsh 2> /dev/null -l; then
    :
  elif test -r '/etc/shells' && grep -v -e '^#' -- '/etc/shells' | sort -u; then
    :
  elif getent 2> /dev/null 1>&2 'shells' && getent 'shells'; then # On OpenBSD / NetBSD
    :
  else
    return 3
  fi
}

clear_env()
{
  test "${prefer_included_utilities}" != '1' || unset ASH_STANDALONE
  if test "${backup_posix}" = 'unset'; then unset POSIXLY_CORRECT; else POSIXLY_CORRECT="${backup_posix}"; fi
  unset SCRIPT_NAME SCRIPT_VERSION HEXDUMP_CMD backup_posix backup_path execute_script prefer_included_utilities
}

pause_if_needed()
{
  # shellcheck disable=SC3028 # Ignore: In POSIX sh, SHLVL is undefined
  if test "${NO_PAUSE:-0}" = '0' && test "${no_pause:-0}" = '0' && test "${CI:-false}" = 'false' && test "${TERM_PROGRAM:-unknown}" != 'vscode' && test "${SHLVL:-1}" = '1' && test -t 0 && test -t 1 && test -t 2; then
    if test -n "${NO_COLOR-}"; then
      printf 1>&2 '\n%s' 'Press any key to exit... ' || :
    else
      printf 1>&2 '\n\033[1;32m\r%s' 'Press any key to exit... ' || :
    fi
    # shellcheck disable=SC3045 # Ignore: In POSIX sh, read -s / -n is undefined
    IFS='' read 2> /dev/null 1>&2 -r -s -n1 _ || IFS='' read 1>&2 -r _ || :
    printf 1>&2 '\n' || :
    test -n "${NO_COLOR-}" || printf 1>&2 '\033[0m\r    \r' || :
  fi
  unset no_pause || :
  return "${1:-0}"
}

main()
{
  local prefer_included_utilities shell_is_msys shell_exe shell_exe_original date_timezone_bug limits limits_date limits_u limits_rnd_u limits_s_u _max _num tmp_var
  local random_val previous_random_val next_random_val
  local shell_info shell_name shell_applet os_info operative_system shell_bit os_bit cpu_bit
  local shell_test_bit shell_arithmetic_bit shell_printf_bit shell_printf_unsigned_bit shell_printf_signed_bit shell_printf_max_u shell_random_seed_bit
  local awk_printf_bit awk_printf_unsigned_bit awk_printf_signed_bit cut_version cut_b_bit date_bit date_u_bit

  prefer_included_utilities="${1}"
  date_timezone_bug='false'

  limits='32767 2147483647 9223372036854775807'
  limits_date='32767 2147480047 2147483647 32535215999 32535244799 67767976233529199 67767976233532799 67768036191673199 67768036191676799 9223372036854775807'

  limits_u='65535 2147483647 2147483648 4294967295 9223372036854775807 9223372036854775808 18446744073709551615'
  limits_rnd_u='65535 4294967295 18446744073709551615'

  limits_s_u='32767 65535 256446000 2147483647 4294967295 9223372036854775807 18446744073709551614 18446744073709551615'

  shell_is_msys='false'
  if is_shell_msys; then
    shell_is_msys='true'
    # We must do this in all cases with Bash under Windows using this POSIX layer otherwise we may run into freezes, obscure errors and unknown infinite loops!!!
    PATH="/usr/bin:${PATH:-%empty}"
  fi

  shell_exe="$(get_shell_exe || :)"
  shell_exe_original="${shell_exe}"
  if test "${shell_is_msys}" = 'true' && command 1> /dev/null 2>&1 -v 'cygpath'; then shell_exe="$(cygpath -m -a -l -- "${shell_exe}" || :)"; fi
  shell_info="$(get_shell_info "${shell_exe}" || :)"
  shell_name="$(printf '%s\n' "${shell_info}" | cut -d ' ' -f '1' || :)"
  prefer_included_utilities_if_requested "${prefer_included_utilities}" "${shell_exe_original}" "${shell_name}"
  os_info="$(get_os_info || :)"

  operative_system='other'
  case "${os_info}" in 'MS/Windows'*) operative_system='win' ;; 'Darwin'*) operative_system='mac' ;; *) ;; esac

  printf '%s\n' "${SCRIPT_NAME} v${SCRIPT_VERSION}"

  shell_bit='unknown'
  if test -n "${shell_exe}" && shell_bit="$(detect_bitness_of_single_file_caller "${shell_exe}")"; then
    :
  elif test "${operative_system}" = 'win' && shell_bit="${PROCESSOR_ARCHITECTURE-}" && test -n "${shell_bit}"; then
    # On Windows 2000+ / ReactOS
    case "${shell_bit}" in
      AMD64 | ARM64 | IA64) shell_bit='64-bit' ;;
      x86) shell_bit='32-bit' ;;
      *) shell_bit='unknown' ;;
    esac
  else
    shell_bit="$(retrieve_bitness_from_uname || :)" # Use it only as last resort (almost never happens)
  fi

  os_bit='unknown'
  if test "${operative_system}" = 'win' && os_bit="${PROCESSOR_ARCHITEW6432:-${PROCESSOR_ARCHITECTURE-}}" && test -n "${os_bit}"; then
    # On Windows 2000+ / ReactOS
    case "${os_bit}" in
      AMD64 | ARM64 | IA64) os_bit='64-bit' ;;
      x86) os_bit='32-bit' ;;
      *) os_bit='unknown' ;;
    esac
  fi
  if test "${os_bit}" = 'unknown'; then
    if os_bit="$(getconf 2> /dev/null 'LONG_BIT')" && test -n "${os_bit}"; then
      os_bit="${os_bit}-bit"
    elif test -r '/system/build.prop'; then
      # On Android
      case "$(file_getprop 'ro.product.cpu.abi' '/system/build.prop' || :)" in
        'x86_64' | 'arm64-v8a' | 'mips64' | 'riscv64') os_bit='64-bit' ;;
        'x86' | 'armeabi-v7a' | 'armeabi' | 'mips') os_bit='32-bit' ;;
        *) os_bit='unknown' ;;
      esac
    else
      os_bit="$(retrieve_bitness_from_uname || :)" # Use it only as last resort (almost never happens)
    fi
  fi

  cpu_bit='unknown'
  if test -r '/proc/cpuinfo' && tmp_var="$(grep -e '^flags[[:space:]]*:' -- '/proc/cpuinfo' | cut -d ':' -f '2-' -s)" && test -n "${tmp_var}"; then
    if printf '%s\n' "${tmp_var}" | grep -m 1 -q -w -e '[[:lower:]]\{1,\}_lm'; then
      cpu_bit='64-bit'
    else
      cpu_bit='32-bit'
    fi
  elif command 1> /dev/null 2>&1 -v 'sysctl' && tmp_var="$(sysctl 2> /dev/null hw.cpu64bit_capable | cut -d ':' -f '2-' -s)" && tmp_var="${tmp_var# }" && test -n "${tmp_var}"; then
    # On macOS
    case "${tmp_var}" in
      '1') cpu_bit='64-bit' ;;
      '0') cpu_bit='32-bit' ;;
      *) cpu_bit='unknown' ;;
    esac
  elif command 1> /dev/null 2>&1 -v 'wmic.exe' && cpu_bit="$(wmic.exe 2> /dev/null cpu get 'DataWidth' | grep -v -F -e 'DataWidth' | tr -d ' \r\n')" && test -n "${cpu_bit}"; then
    # On Windows / ReactOS (if WMIC is present)
    case "${cpu_bit}" in
      '64' | '32') cpu_bit="${cpu_bit}-bit" ;;
      *) cpu_bit='unknown' ;;
    esac
  elif command 1> /dev/null 2>&1 -v 'powershell.exe' && cpu_bit="$(powershell.exe 2> /dev/null -NoProfile -ExecutionPolicy 'Bypass' -c 'gwmi Win32_Processor | select -ExpandProperty DataWidth')" && test -n "${cpu_bit}"; then
    # On Windows (if PowerShell is installed - it is slow)
    case "${cpu_bit}" in
      '64' | '32') cpu_bit="${cpu_bit}-bit" ;;
      *) cpu_bit='unknown' ;;
    esac
  else
    cpu_bit='unknown'
  fi

  _max='-1'
  for _num in ${limits}; do
    if test 2> /dev/null "${_num}" -gt 0; then
      _max="${_num}"
    else
      if _num="$(inc_num "${_max}")" && test 2> /dev/null "${_num}" -gt 0; then
        warn_msg 'Detection of shell test int comparison was inconclusive, please report it to the author!!!'
      fi
      break
    fi
  done
  shell_test_bit="$(convert_max_signed_int_to_bit "${_max}")" || shell_test_bit='unknown'

  _max='-1'
  for _num in ${limits}; do
    if test "$((_num))" = "${_num}"; then
      _max="${_num}"
    else
      if _num="$(inc_num "${_max}")" && test "$((_num))" = "${_num}"; then
        warn_msg 'Detection of shell arithmetic was inconclusive, please report it to the author!!!'
      fi
      break
    fi
  done
  shell_arithmetic_bit="$(convert_max_signed_int_to_bit "${_max}")" || shell_arithmetic_bit='unknown'

  tmp_var="$(get_max_unsigned_int_of_shell_printf)" || tmp_var='unknown'
  shell_printf_bit="$(convert_max_unsigned_int_to_bit "${tmp_var}" || :)"

  _max='-1'
  # We hide the errors otherwise it will display an error on old Bash under Windows (or a ValueError on Oils) when an overflow occurs
  for _num in ${limits_u}; do
    if tmp_var="$(printf 2> /dev/null "%u\n" "${_num}")" && test "${tmp_var}" = "${_num}"; then
      _max="${_num}"
    else
      if _num="$(inc_num "${_max}")" && tmp_var="$(printf 2> /dev/null "%u\n" "${_num}")" && test "${tmp_var}" = "${_num}"; then
        warn_msg 'Detection of unsigned shell printf was inconclusive, please report it to the author!!!'
      fi
      break
    fi
  done
  shell_printf_unsigned_bit="$(convert_max_unsigned_int_to_bit "${_max}")" || shell_printf_unsigned_bit='unknown'
  shell_printf_max_u='unknown'
  test "${_max}" = '-1' || shell_printf_max_u="${_max}"

  _max='-1'
  # We hide the errors otherwise it will display an error on old Bash under Windows when an overflow occurs
  for _num in ${limits}; do
    if tmp_var="$(printf 2> /dev/null "%d\n" "${_num}")" && test "${tmp_var}" = "${_num}"; then
      _max="${_num}"
    else
      if _num="$(inc_num "${_max}")" && tmp_var="$(printf 2> /dev/null "%d\n" "${_num}")" && test "${tmp_var}" = "${_num}"; then
        warn_msg 'Detection of signed shell printf was inconclusive, please report it to the author!!!'
      fi
      break
    fi
  done
  shell_printf_signed_bit="$(convert_max_signed_int_to_bit "${_max}")" || shell_printf_signed_bit='unknown'

  _max='-1'
  random_val='-1'
  # shellcheck disable=SC3028 # In POSIX sh, RANDOM is undefined
  if RANDOM='1234' && test "${RANDOM}" = '1234'; then
    _max='unsupported' # $RANDOM is NOT supported
    unset RANDOM
  elif test "$(seed_and_get_random '1234' || :)" != "$(seed_and_get_random '1234' || :)"; then
    _max='ignored' # $RANDOM is supported but the seed is ignored
  else
    for _num in ${limits_rnd_u}; do
      if tmp_var="$(test_seed_of_random 2>&1 "${_num}")" && test -z "${tmp_var}"; then
        : # OK
      else
        break # Assigning an integer that is too large causes an error message to be displayed on zsh
      fi

      tmp_var="$(seed_and_get_random "${_num}")"
      # All the overflowed RANDOM seeds produce the same random numbers (sometimes the repetition is every 2 seed values)
      # IMPORTANT: This check is NOT always reliable because shells may break differently at overflow
      if test "${random_val}" != "${tmp_var}"; then
        _max="${_num}"
        random_val="${tmp_var}"
      else
        if
          _num="$(inc_num "${_max}")" && next_random_val="$(seed_and_get_random "${_num}")" && test "${next_random_val}" != "${random_val}" &&
            _num="$((_max - 1))" && previous_random_val="$(seed_and_get_random "${_num}")" && test "${next_random_val}" != "${previous_random_val}"
        then
          warn_msg 'Detection of RANDOM seed was inconclusive, please report it to the author!!!'
        fi
        break
      fi
    done
  fi
  shell_random_seed_bit="$(convert_max_unsigned_int_to_bit "${_max}" || :)"

  tmp_var="$(awk -- 'BEGIN { printf "%u\n", "-1" }' || :)"
  awk_printf_bit="$(convert_max_unsigned_int_to_bit "${tmp_var}" || :)"

  # IMPORTANT: For very big integer numbers GNU Awk may return the exponential notation or an imprecise number
  _max='-1'
  for _num in ${limits_u}; do
    if tmp_var="$(awk -v n="${_num}" -- 'BEGIN { printf "%u\n", n }')" && permissively_comparison "${tmp_var}" "${_num}"; then
      _max="${_num}"
    else
      if _num="$(inc_num "${_max}")" && tmp_var="$(awk -v n="${_num}" -- 'BEGIN { printf "%u\n", n }')" && permissively_comparison "${tmp_var}" "${_num}"; then
        warn_msg 'Detection of unsigned awk printf was inconclusive, please report it to the author!!!'
      fi
      break
    fi
  done
  awk_printf_unsigned_bit="$(convert_max_unsigned_int_to_bit "${_max}")" || awk_printf_unsigned_bit='unknown'

  _max='-1'
  for _num in ${limits}; do
    if tmp_var="$(awk -v n="${_num}" -- 'BEGIN { printf "%d\n", n }')" && permissively_comparison "${tmp_var}" "${_num}"; then
      _max="${_num}"
    else
      if _num="$(inc_num "${_max}")" && tmp_var="$(awk -v n="${_num}" -- 'BEGIN { printf "%d\n", n }')" && permissively_comparison "${tmp_var}" "${_num}"; then
        warn_msg 'Detection of signed awk printf was inconclusive, please report it to the author!!!'
      fi
      break
    fi
  done
  awk_printf_signed_bit="$(convert_max_signed_int_to_bit "${_max}")" || awk_printf_signed_bit='unknown'

  cut_version="$(get_version 'cut' || :)"

  _max='-1'
  case "${cut_version}" in
    # The "cut" of "GNU textutils 1.5" does NOT freeze (so no timeout needed) but shells that come with this old "cut" may NOT support background processes
    *'GNU textutils'*) _max="$(detect_bits_of_cut_b "${limits_s_u}" "${operative_system}")" || _max='-1' ;;
    *) _max="$(code_timeout 3>&2 2> /dev/null detect_bits_of_cut_b 8 "${limits_s_u}" "${operative_system}")" || _max='-1' ;;
  esac
  cut_b_bit="$(convert_max_unsigned_int_to_bit "${_max}" 'true' || :)"

  _max='-1'
  for _num in ${limits_date}; do
    if tmp_var="$(TZ='CET-1' date 2> /dev/null -d "@${_num}" -- '+%s')" && test "${tmp_var}" = "${_num}"; then
      _max="${_num}"
    else
      if test "${tmp_var}" = "$((_num - 14400))"; then
        date_timezone_bug='true'
        _max="${_num}"
      else
        if _num="$(inc_num "${_max}")" && tmp_var="$(TZ='CET-1' date 2> /dev/null -d "@${_num}" -- '+%s')" && test "${tmp_var}" = "${_num}"; then
          warn_msg 'Detection of date timestamp was inconclusive, please report it to the author!!!'
        fi
        break
      fi
    fi
  done
  date_bit="$(convert_max_signed_int_to_bit "${_max}")" || date_bit='unknown'

  _max='-1'
  for _num in ${limits_date}; do
    if tmp_var="$(TZ='CET-1' date 2> /dev/null -u -d "@${_num}" -- '+%s')" && test "${tmp_var}" = "${_num}"; then
      _max="${_num}"
    else
      if _num="$(inc_num "${_max}")" && tmp_var="$(TZ='CET-1' date 2> /dev/null -u -d "@${_num}" -- '+%s')" && test "${tmp_var}" = "${_num}"; then
        warn_msg 'Detection of date -u timestamp was inconclusive, please report it to the author!!!'
      fi
      break
    fi
  done
  date_u_bit="$(convert_max_signed_int_to_bit "${_max}")" || date_u_bit='unknown'

  printf '\n%s %s\n' "Shell:" "${shell_name}"
  if shell_applet="$(get_applet_name "${shell_name}")"; then
    printf '%s %s\n' "Shell applet:" "${shell_applet}"
  fi
  printf '%s %s\n' "Shell version:" "$(printf '%s\n' "${shell_info}" | cut -d ' ' -f '2-' -s || :)"
  printf '%s %s\n\n' "Shell path:" "${shell_exe:-unknown}"

  printf '%s %s\n' "OS:" "${os_info}"
  printf '%s %s\n\n' "Version of uname:" "$(get_version 'uname' || :)"

  printf '%s\n' "Bits of shell: ${shell_bit}"
  printf '%s\n' "Bits of OS: ${os_bit}"
  printf '%s\n\n' "Bits of CPU: ${cpu_bit}"

  printf '%s\n' "Bits of shell 'test' int comparison: ${shell_test_bit}"
  printf '%s\n\n' "Bits of shell arithmetic: ${shell_arithmetic_bit}"

  printf '%s\n' "Bits of shell 'printf': ${shell_printf_bit}"
  printf '%s\n' "Bits of shell 'printf' (unsigned): ${shell_printf_unsigned_bit} (0-${shell_printf_max_u})"
  printf '%s\n' "Bits of shell 'printf' (signed): ${shell_printf_signed_bit}"
  printf '%s %s\n\n' "Bits of \$RANDOM seed:" "${shell_random_seed_bit}"

  printf '%s %s\n' "Version of awk:" "$(get_version 'awk' || :)"
  printf '%s\n' "Bits of awk 'printf': ${awk_printf_bit}"
  printf '%s\n' "Bits of awk 'printf' (unsigned): ${awk_printf_unsigned_bit}"
  printf '%s\n\n' "Bits of awk 'printf' (signed): ${awk_printf_signed_bit}"

  printf '%s %s\n' "Version of cut:" "${cut_version}"
  printf '%s\n\n' "Bits of 'cut -b': ${cut_b_bit}"

  printf '%s %s\n' "Version of date:" "$(get_version 'date' || :)"
  printf '%s%s\n' "Bits of 'TZ=CET-1 date' timestamp: ${date_bit}" "$(test "${date_timezone_bug}" = 'false' || printf ' %s\n' '(with time zone BUG)' || :)"
  printf '%s\n' "Bits of 'date -u' timestamp: ${date_u_bit}"
}

backup_posix="${POSIXLY_CORRECT-unset}"
POSIXLY_CORRECT='y'
export POSIXLY_CORRECT

execute_script='true'
prefer_included_utilities=0
no_pause=0
STATUS=0

while test "${#}" -gt 0; do
  case "${1}" in
    -V | --version)
      execute_script='false'
      no_pause=1
      printf '%s\n' "${SCRIPT_NAME} v${SCRIPT_VERSION}"
      printf '%s\n' "Copy""right (c) 2024 ale5000"
      printf '%s\n' 'License GPLv3+'
      ;;
    -h | --help | '-?')
      execute_script='false'
      no_pause=1
      printf '%s\n' "${SCRIPT_NAME} v${SCRIPT_VERSION}"

      printf '\n%s\n\n' 'Coming soon...'

      if test -n "${0-}" && script_filename="$(basename "${0}")"; then
        :
      else
        exit 1
      fi

      printf '%s\n' 'Notes:'
      printf '%s\n' 'If a single parameter is given, then it returns the specific error code, otherwise if there are multiple files, it returns the number of files that were not recognized.'
      printf '%s\n\n' 'If the number is greater than 125 then it returns 125.'

      printf '%s\n' 'Examples:'
      printf '%s\n' "${script_filename}"
      printf '%s\n' "${script_filename} -- './dir_to_test/file_to_test.ext'"
      printf '%s\n' "find './dir_to_test' -type f -print0 | xargs -0 -- '${script_filename}' -- ''"
      printf '%s\n' "find './dir_to_test' -type f | ${script_filename} -"
      ;;
    -i | --prefer-included-utilities)
      # Enable code to prefer utilities that are in the same directory of the shell
      prefer_included_utilities=1

      # Prefer internal applets over external utilities (only BusyBox under Windows)
      unset BB_OVERRIDE_APPLETS
      # Prefer internal applets over external utilities (only some versions of BusyBox under Android)
      ASH_STANDALONE='1'
      export ASH_STANDALONE
      ;;
    --no-pause)
      no_pause=1
      ;;

    -l | --list-available-shells)
      execute_script='false'
      no_pause=1
      list_available_shells || STATUS="${?}"
      ;;

    --)
      shift
      break
      ;;

    -) # Get file list from STDIN
      break
      ;;

    --*)
      execute_script='false'
      printf 1>&2 '%s\n' "${SCRIPT_NAME}: unrecognized option '${1}'"
      STATUS=2
      ;;
    -*)
      execute_script='false'
      printf 1>&2 '%s\n' "${SCRIPT_NAME}: invalid option -- '${1#-}'"
      STATUS=2
      ;;

    *) break ;;
  esac

  shift
done || :

if test "${execute_script}" = 'true'; then
  backup_path="${PATH-unset}"

  if test "${#}" -eq 0; then
    main "${prefer_included_utilities}" || STATUS="${?}"
  else
    detect_bitness_of_files "${@}" || STATUS="${?}"
  fi

  if test "${backup_path}" = 'unset'; then unset PATH; else PATH="${backup_path}"; fi
fi

clear_env
pause_if_needed "${STATUS?}"
