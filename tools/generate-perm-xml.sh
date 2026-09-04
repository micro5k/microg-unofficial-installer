#!/usr/bin/env sh
# SPDX-FileCopyrightText: 2025 ale5000
# SPDX-License-Identifier: Apache-2.0 OR GPL-3.0-or-later WITH LicenseRef-Archive-packaging-exception

# @name Android ROM permissions XML generator
# @brief Generate privapp-permissions and default-permissions XML files for Android ROM builds.
# @description Takes one or more Android APK files, reads their declared
# permissions using aapt2 or aapt, cross-references them against the AOSP
# permission database built by dl-perm-list.sh, and emits XML files with
# privapp-permissions or default-permissions declarations for use in custom
# Android ROM builds.
#
# Output is written to the output/ subdirectory.
# @author ale5000

# Get the latest version from here: https://github.com/micro5k/microg-unofficial-installer/tree/main/tools

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

# @section GLOBAL CONSTANTS ----
#region
readonly SCRIPT_NAME='Android ROM permissions XML generator'
readonly SCRIPT_SHORTNAME='PermXmlGen'
readonly SCRIPT_VERSION='0.3.22'
readonly SCRIPT_AUTHOR='ale5000'
readonly SCRIPT_YEAR='2025'

readonly MAX_API='37'

readonly EX_UNAVAILABLE=69
readonly EX_SOFTWARE=70
#endregion

set -u 2> /dev/null || :
# shellcheck disable=SC3040 # IGNORE: In POSIX sh, set option pipefail is undefined
case "$(set -o 2> /dev/null || set || :)" in *'pipefail'*) set -o pipefail || echo 1>&2 'ERROR: pipefail failed' ;; *) echo 1>&2 'WARNING: pipefail not supported' ;; esac
# shellcheck disable=SC3041 # IGNORE: In POSIX sh, set flag -H is undefined
(set +H 2> /dev/null) && set +H || :

# @section UTILITY & UI FUNCTIONS ----
#region
fix_posix_emulation_if_needed()
{
  # Workarounds for shells using Windows-POSIX emulation layers (e.g., Git Bash under Windows)
  if test -f '/usr/bin/cygpath'; then
    # Prioritize POSIX-emulated binaries over Windows natives to prevent hangs and obscure errors
    if test "${USR_BIN_FIXED:-0}" = '0'; then
      case "${PATH-}" in '/usr/bin:'*) ;; *) PATH="/usr/bin:${PATH:-%empty}" ;; esac
    fi

    # Resolve an issue where dragging and dropping a file onto the script inexplicably resets the
    #  working directory to 'C:\WINDOWS\system32'
    # shellcheck disable=SC3028 # IGNORE: In POSIX sh, BASH_SOURCE is undefined
    if test "$(/usr/bin/cygpath -m -- "${PWD:?}" || :)" = "$(/usr/bin/cygpath -m -S || :)" && test -n "${BASH_SOURCE-}"; then
      cd "${BASH_SOURCE:?}/.." || printf 1>&2 '%s\n' 'ERROR: Failed to set the correct working directory'
    fi
  fi
}

set_red_color()
{
  printf 1>&2 '\033[1;31m\r'
}

reset_color()
{
  printf 1>&2 '\033[0m\r'
}

show_status()
{
  printf 1>&2 '\033[1;32m%s\033[0m\n' "${1?}"
}

show_warn()
{
  printf 1>&2 '\033[0;33m%s\033[0m\n' "WARNING: ${1?}"
}

show_error()
{
  printf 1>&2 '\n\033[1;31m%s\033[0m\n' "ERROR: ${1?}"
}

ui_error()
{
  # ToDO: Remove this function
  show_error "${1?}"
  exit 55
}

pause_if_needed()
{
  # shellcheck disable=SC3028 # Ignore: In POSIX sh, SHLVL is undefined
  if test "${NO_PAUSE:-0}" = '0' && test "${no_pause:-0}" = '0' && test "${CI:-false}" = 'false' && test "${TERM_PROGRAM:-none}" != 'vscode' && test "${SHLVL:-1}" = '1' && test -t 0 && test -t 1 && test -t 2; then
    if test -n "${NO_COLOR-}"; then
      printf 1>&2 '\n%s' 'Press any key to exit... ' || :
    else
      printf 1>&2 '\n\033[1;32m\r%s' 'Press any key to exit... ' || :
    fi
    # shellcheck disable=SC3045 # Ignore: In POSIX sh, read -s / -n is undefined
    IFS='' read 2> /dev/null 1>&2 -r -s -n1 _ || IFS='' read 1>&2 -r _ || :
    if test -n "${NO_COLOR-}"; then printf 1>&2 '\n' || :; else printf 1>&2 '\n\033[0m\r    \r' || :; fi
  fi
  unset no_pause
  return "${1:-0}"
}
#endregion

# @section CORE FUNCTIONS ----
#region
set_android_sdk_path_if_unset()
{
  test -z "${ANDROID_HOME-}" || return

  # Set the path of Android SDK if not already set
  if test -n "${LOCALAPPDATA-}" && test -d "${LOCALAPPDATA?}/Android/Sdk"; then
    ANDROID_HOME="${LOCALAPPDATA?}/Android/Sdk" # Windows
  elif test -n "${HOME-}" && test -d "${HOME?}/Library/Android/sdk"; then
    ANDROID_HOME="${HOME?}/Library/Android/sdk" # macOS
  elif test -n "${HOME-}" && test -d "${HOME?}/.local/share/android/sdk"; then
    ANDROID_HOME="${HOME?}/.local/share/android/sdk" # Linux (XDG)
  elif test -n "${HOME-}" && test -d "${HOME?}/Android/Sdk"; then
    ANDROID_HOME="${HOME?}/Android/Sdk" # Linux (Standard)
  elif test -d '/usr/lib/android-sdk'; then
    ANDROID_HOME='/usr/lib/android-sdk' # Linux (APT)
  fi
}

find_android_build_tool()
{
  local __fn_tool_path

  if __fn_tool_path="$(
    unalias "${1:?}" 2> /dev/null
    command 2> /dev/null -v "${1:?}"
  )" && test -n "${__fn_tool_path?}"; then
    :
  elif test -n "${ANDROID_HOME-}" && test -d "${ANDROID_HOME?}/build-tools" && __fn_tool_path="$(find "${ANDROID_HOME?}/build-tools" -maxdepth 2 -iname "${1:?}*" | sort -V -r | head -n 1)" && test -n "${__fn_tool_path?}"; then
    :
  else
    return 1
  fi

  printf '%s\n' "${__fn_tool_path:?}"
}

find_data_dir()
{
  local _path

  # shellcheck disable=SC3028 # Ignore: In POSIX sh, BASH_SOURCE is undefined
  if test -n "${TOOLS_DATA_DIR-}" && _path="${TOOLS_DATA_DIR:?}" && test -d "${_path:?}"; then
    :
  elif test -n "${BASH_SOURCE-}" && _path="$(dirname "${BASH_SOURCE:?}")/data" && test -d "${_path:?}"; then
    : # It is expected: expanding an array without an index gives the first element
  elif test -n "${0-}" && _path="$(dirname "${0:?}")/data" && test -d "${_path:?}"; then
    :
  elif _path='./data' && test -d "${_path:?}"; then
    :
  else
    return 1
  fi

  _path="$(realpath 2> /dev/null "${_path:?}" || readlink -f "${_path:?}")" || return 1
  printf '%s\n' "${_path:?}"
}

get_apk_cert_sha256()
{
  local __fn_cert_sha256=''

  if test -n "${APKSIGNER_PATH?}"; then
    show_status 'Using apksigner...'
    set_red_color
    __fn_cert_sha256="$("${APKSIGNER_PATH?}" verify --min-sdk-version 24 --print-certs -- "${1:?}" | grep -m 1 -o -i -e 'certificate SHA-256 digest:.*' | cut -d ':' -f '2' -s | tr -d -- ' ' | tr -- '[:lower:]' '[:upper:]')" || return "${?}"
  else
    show_status 'Using keytool...'
    set_red_color
    # IMPORTANT: This is slow and limited to v1 signatures
    __fn_cert_sha256="$(LC_ALL=C "${KEYTOOL_PATH:?}" -printcert -jarfile "${1:?}" | grep -m 1 -F -e 'SHA256:' | cut -d ':' -f '2-' -s | tr -d -- ' :')" || return "${?}"
  fi

  # IMPORTANT: This is faster but limited to v1 RSA signatures
  # WARNING: Will fail if the META-INF folder contains an EC signature file instead of RSA
  # __fn_cert_sha256="$(unzip -p "${1:?}" 'META-INF/*.RSA' | openssl pkcs7 -inform 'DER' -print_certs -quiet | openssl x509 -noout -sha256 -fingerprint | cut -d '=' -f '2' -s | tr -d -- ':')" || return "${?}"

  test "${#__fn_cert_sha256}" -eq 64 || {
    show_error "Extracted SHA-256 hash length is invalid (got ${#__fn_cert_sha256} chars, expected 64)"
    return "${EX_SOFTWARE?}"
  }

  printf '%s\n' "${__fn_cert_sha256?}" | sed -e 's/../&:/g; s/:$//'
}

is_system_permission()
{
  case "${1:?}" in
    # https://android.googlesource.com/platform/frameworks/base/+/HEAD/core/res/AndroidManifest.xml
    com.android.vending.*) return 1 ;;
    android.permission.* | com.android.permission.* | com.android.*.permission.*) return 0 ;;
    android.intent.category.MASTER_CLEAR.permission.C2D_MESSAGE) return 0 ;;

    # https://android.googlesource.com/platform/packages/services/Car/+/HEAD/service/AndroidManifest.xml
    android.car.permission.*) return 0 ;;
    *) ;;
  esac
  return 1
}

map_permission_group_to_label()
{
  # Info:
  # - https://android.googlesource.com/platform/cts/+/ed6a170ab0d5e0365bc494a8004ee9ac50318892/tests/tests/permission3/src/android/permission3/cts/BaseUsePermissionTest.kt
  # - https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/res/res/values/strings.xml

  case "${1?}" in
    '' | 'android.permission-group.UNDEFINED') printf '%s\n' 'Undefined' ;;
    'android.permission-group.CALENDAR') printf '%s\n' 'Calendar' ;;
    'android.permission-group.CALL_LOG') printf '%s\n' 'Call logs' ;;
    'android.permission-group.CAMERA') printf '%s\n' 'Camera' ;;
    'android.permission-group.CONTACTS') printf '%s\n' 'Contacts / Accounts' ;;
    'android.permission-group.LOCATION') printf '%s\n' 'Location' ;;
    'android.permission-group.MICROPHONE') printf '%s\n' 'Microphone' ;;
    'android.permission-group.NEARBY_DEVICES') printf '%s\n' 'Nearby devices' ;;
    'android.permission-group.NOTIFICATIONS') printf '%s\n' 'z)Notifications' ;;
    'android.permission-group.PHONE') printf '%s\n' 'Phone' ;;
    'android.permission-group.SENSORS') printf '%s\n' 'Body sensors' ;;
    'android.permission-group.SMS') printf '%s\n' 'SMS' ;;
    'android.permission-group.STORAGE') printf '%s\n' 'Storage / Files' ;;

    *) printf '%s\n' "${1:?}" ;;
  esac
}

get_permission_declaration()
{
  grep -m 1 -F -e "android:name=\"${1:?}\"" -- "${DATA_DIR:?}/perms/base-permissions-api-${2:?}.xml" || return 1
}

get_custom_permission_declaration()
{
  grep -H -F -e "android:name=\"${1:?}\"" 0<< 'EOF'
    # packages/providers/DownloadProvider
    <permission android:name="android.permission.DOWNLOAD_WITHOUT_NOTIFICATION" android:permissionGroup="android.permission-group.NETWORK" android:protectionLevel="normal"/>
    # GSF
    <permission android:name="com.google.android.c2dm.permission.RECEIVE" android:protectionLevel="normal"/>
    <permission android:name="com.google.android.c2dm.permission.SEND" android:protectionLevel="signatureOrSystem"/>
    <permission android:name="com.google.android.googleapps.permission.GOOGLE_AUTH" android:protectionLevel="signature"/>
    <permission android:name="com.google.android.googleapps.permission.GOOGLE_AUTH.mail" android:protectionLevel="signature"/>
    <permission android:name="com.google.android.providers.gsf.permission.READ_GSERVICES" android:protectionLevel="normal"/>
    <permission android:name="com.google.android.providers.gsf.permission.WRITE_GSERVICES" android:protectionLevel="signature"/>
    <permission android:name="com.google.android.providers.settings.permission.READ_GSETTINGS" android:protectionLevel="signature"/>
    <permission android:name="com.google.android.providers.settings.permission.WRITE_GSETTINGS" android:protectionLevel="signature"/>
    # GM
    <permission android:name="com.google.android.gm.email.permission.ACCESS_PROVIDER" android:protectionLevel="signature"/>
    <permission android:name="com.google.android.gm.email.permission.GET_WIDGET_UPDATE" android:protectionLevel="signature"/>
    <permission android:name="com.google.android.gm.email.permission.READ_ATTACHMENT" android:permissionGroup="android.permission-group.MESSAGES" android:protectionLevel="signature"/>
    <permission android:name="com.google.android.gm.email.permission.UPDATE_AUTH_NOTIFICATION" android:protectionLevel="signature"/>
    <permission android:name="com.google.android.gm.permission.AUTO_SEND" android:permissionGroup="android.permission-group.MESSAGES" android:protectionLevel="signature"/>
    <permission android:name="com.google.android.gm.permission.BROADCAST_INTERNAL" android:protectionLevel="signature"/>
    <permission android:name="com.google.android.gm.permission.READ_CONTENT_PROVIDER" android:permissionGroup="android.permission-group.MESSAGES" android:protectionLevel="dangerous"/>
    <permission android:name="com.google.android.gm.permission.READ_GMAIL" android:permissionGroup="android.permission-group.MESSAGES" android:protectionLevel="signature"/>
    <permission android:name="com.google.android.gm.permission.WRITE_GMAIL" android:permissionGroup="android.permission-group.MESSAGES" android:protectionLevel="signature"/>
EOF

  # <permission-tree android:name="com.google.android.googleapps.permission.GOOGLE_AUTH"/>
}

begin_xml()
{
  local __fn_cert_digest=''

  # REUSE-IgnoreStart
  printf '%s\n' '<?xml version="1.0" encoding="utf-8"?>'
  printf '%s\n' '<!--'
  printf '%s\n' '    SPDX-FileCopyrightText: NONE'
  printf '%s\n' '    SPDX-License-Identifier: CC0-1.0'
  printf '%s\n' "    Generated by ${SCRIPT_SHORTNAME:?} of ${SCRIPT_AUTHOR:?}"
  printf '%s\n\n' '-->'
  # REUSE-IgnoreEnd

  if test "${NO_CERT_DIGEST:?}" = 'false'; then
    __fn_cert_digest=" sha256-cert-digest=\"${2:?}\""
  fi

  if test "${3:?}" = 'privapp-permissions'; then
    printf '%s\n' '<permissions>'
    printf '%s\n' "    <privapp-permissions package=\"${1:?}\"${__fn_cert_digest?}>"
  elif test "${3:?}" = 'default-permissions'; then
    printf '%s\n' '<exceptions>'
    printf '%s\n' "    <exception package=\"${1:?}\"${__fn_cert_digest?}>"
  else
    return 1
  fi
}

append_perm_to_xml()
{
  local _xml_compat_info

  case "${2:?}" in '23') _xml_compat_info='' ;; *) _xml_compat_info=" <!-- MinApi: ${2:?} -->" ;; esac
  if test -n "${4?}" && test "${4:?}" != "${LAST_PERM_GROUP?}" && LAST_PERM_GROUP="${4:?}"; then printf '%s\n' "        <!-- ${4#"z)"} -->"; fi

  case "${3:?}" in
    'privapp-permissions')
      if test "${1:?}" = 'android.permission.FAKE_PACKAGE_SIGNATURE' && test "${PLACEHOLDERS:?}" = 'true'; then
        printf '%s\n' "        <!-- %${1#"android.permission."}% -->${_xml_compat_info?}"
      else
        printf '%s\n' "        <permission name=\"${1:?}\" />${_xml_compat_info?}"
      fi
      ;;
    'default-permissions')
      if {
        test -n "${_xml_compat_info?}" || test "${1:?}" = 'android.permission.FAKE_PACKAGE_SIGNATURE'
      } && test "${PLACEHOLDERS:?}" = 'true'; then
        printf '%s\n' "        <!-- %${1#"android.permission."}% -->${_xml_compat_info?}"
      elif test "${5?}" = 'true'; then
        printf '%s\n' "        <permission name=\"${1:?}\" fixed=\"false\" whitelisted=\"true\" />${_xml_compat_info?}"
      else
        printf '%s\n' "        <permission name=\"${1:?}\" fixed=\"false\" />${_xml_compat_info?}"
      fi
      ;;
    *) return 1 ;;
  esac
}

terminate_xml()
{
  if test "${1:?}" = 'privapp-permissions'; then
    printf '%s\n' '    </privapp-permissions>'
    printf '%s\n' '</permissions>'
  elif test "${1:?}" = 'default-permissions'; then
    printf '%s\n' '    </exception>'
    printf '%s\n' '</exceptions>'
  else
    return 1
  fi
}

parse_perms_and_generate_xml_files()
{
  local _backup_ifs _filename _base_name _pkg_name _cert_sha256 _input _perm _api
  local _perm_decl_all _perm_decl _perm_prot_level _perm_flags _perm_whitelist _no_api_difference _perm_group _perm_after _perm_min_api
  local _perm_is_privileged _perm_is_dangerous _perm_type_found _perm_fake_sign
  local _privileged_perm_list _dangerous_perm_list

  _base_name="${1%".apk"}"
  _pkg_name="${2:?}"
  _cert_sha256="${3?}"

  test ! -t 0 || ui_error "Failed to retrieve the permissions list"
  _input="$(cat)" || ui_error "Failed to retrieve the permissions list"

  _backup_ifs="${IFS-}"
  IFS="${NL:?}"

  set -f || :
  # shellcheck disable=SC2086 # Word splitting is intended
  set -- ${_input:?} || ui_error "Failed expanding \${_input} inside parse_perms_and_generate_xml_files()"
  set +f || :

  IFS="${_backup_ifs?}"

  # Info:
  # - https://developer.android.com/guide/topics/manifest/permission-element?hl=en
  # - https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/java/android/permission/Permissions.md
  # - https://developer.android.com/reference/android/R.attr#protectionLevel

  _privileged_perm_list=''
  _dangerous_perm_list=''
  _perm_fake_sign='false'

  for _perm in "${@}"; do
    _perm_min_api=''
    _perm_is_privileged='false'
    _perm_is_dangerous='false'
    _perm_whitelist='false'

    test "${SCRIPT_VERBOSE:?}" = 'false' || printf 1>&2 '%s\n' "${_perm?}:"

    case "${_perm:?}" in
      *'.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION')
        continue
        ;;
      'android.permission.FAKE_PACKAGE_SIGNATURE')
        _perm_fake_sign='true'
        continue
        ;;
      *) ;;
    esac

    _no_api_difference='false'
    if _perm_decl_all="$(grep -r -H -m 1 -F -e "android:name=\"${_perm:?}\"" -- "${DATA_DIR:?}/perms")"; then
      :
    elif _perm_decl_all="$(get_custom_permission_declaration "${_perm:?}")"; then
      _no_api_difference='true'
    else
      show_warn "Unknown permission: ${_perm?}" # The permission cannot be found in any API, skip it
      continue
    fi

    for _api in $(seq -- 23 "${MAX_API:?}"); do
      _perm_decl="$(printf '%s\n' "${_perm_decl_all:?}" | grep -F -e "perms/base-permissions-api-${_api:?}.xml:" -e '(standard input):')" || {
        test "${SCRIPT_VERBOSE:?}" = 'false' || show_warn "The '${_perm?}' permission cannot be found on API ${_api?}"
        continue
      }
      : "${_perm_min_api:=${_api:?}}" # Set min API for this permission
      _perm_prot_level="$(printf '%s\n' "${_perm_decl:?}" | grep -o -e 'android:protectionLevel="[^"]*"' | cut -d '"' -f '2' -s)" || {
        show_error "Failed to the parse protection level of '${_perm?}' on API ${_api?}"
        continue
      }

      _perm_type_found='false'
      case "|${_perm_prot_level?}|" in *'|normal|'* | *'|preinstalled|'*) _perm_type_found='true' ;; *) ;; esac

      case "|${_perm_prot_level?}|" in *'|privileged|'* | *'|system|'* | *'|signatureOrSystem|'*)
        _perm_type_found='true'
        # The XML files for privileged permissions only exist from API 26 onwards, so if a permission is only privileged in older versions, we exclude it.
        if test "${_api:?}" -ge 26 || test "${_no_api_difference:?}" = 'true'; then _perm_is_privileged='true'; fi
        ;;
      *) ;;
      esac

      case "|${_perm_prot_level?}|" in *'|dangerous|'*)
        _perm_type_found='true'
        _perm_is_dangerous='true'

        _perm_flags="$(printf '%s\n' "${_perm_decl:?}" | grep -o -e 'android:permissionFlags="[^"]*"' | cut -d '"' -f '2' -s)" || _perm_flags=''
        case "|${_perm_flags?}|" in *'|hardRestricted|'* | *'|softRestricted|'*) _perm_whitelist='true' ;; *) ;; esac
        ;;
      *) ;;
      esac

      case "${_perm_type_found?}" in
        'true') ;;
        *) show_warn "Unknown protection level for '${_perm?}'$(test "${_no_api_difference:?}" = 'true' || printf '%s\n' " on API ${_api?}" || :)$(test "${SCRIPT_VERBOSE:?}" = 'false' || printf '%s\n' " => ${_perm_prot_level?}" || :)" ;;
      esac
      test "${_no_api_difference:?}" = 'false' || break
    done

    test "${SCRIPT_VERBOSE:?}" = 'false' || printf 1>&2 '%s\n' "Min API ${_perm_min_api?}"

    if test "${_perm_is_privileged?}" = 'true' && is_system_permission "${_perm:?}"; then
      _privileged_perm_list="${_privileged_perm_list?}${_perm:?}|${_perm_min_api:?}${NL:?}"
    fi

    if test "${_perm_is_dangerous?}" = 'true'; then
      _perm_decl="$(get_permission_declaration "${_perm:?}" 28)" || _perm_decl=''
      _perm_group="$(printf '%s\n' "${_perm_decl?}" | grep -o -e 'android:permissionGroup="[^"]*"' | cut -d '"' -f '2' -s)" || _perm_group=''
      if test -z "${_perm_group?}"; then
        case "${_perm:?}" in
          'android.permission.ACCESS_BACKGROUND_LOCATION') _perm_group='android.permission-group.LOCATION' ;;
          'android.permission.BLUETOOTH_ADVERTISE' | 'android.permission.BLUETOOTH_CONNECT' | 'android.permission.BLUETOOTH_SCAN') _perm_group='android.permission-group.NEARBY_DEVICES' ;;
          'android.permission.POST_NOTIFICATIONS') _perm_group='android.permission-group.NOTIFICATIONS' ;;
          *) ;;
        esac
      fi
      _perm_group="$(map_permission_group_to_label "${_perm_group?}" || :)"
      case "${_perm:?}" in
        'android.permission.ACCESS_BACKGROUND_LOCATION') _perm_after='android.permission.ACCESS_FINE_LOCATION+' ;;
        *) _perm_after="${_perm:?} " ;;
      esac
      _dangerous_perm_list="${_dangerous_perm_list?}${_perm_group:?}|${_perm_after:?}|${_perm:?}|${_perm_whitelist:?}|${_perm_min_api:?}${NL:?}"
    fi
  done

  if test "${_perm_fake_sign:?}" = 'true'; then
    _privileged_perm_list="${_privileged_perm_list?}android.permission.FAKE_PACKAGE_SIGNATURE|23${NL:?}"
    _dangerous_perm_list="${_dangerous_perm_list?}z)Signature spoofing||android.permission.FAKE_PACKAGE_SIGNATURE|false|23${NL:?}"
  fi

  if test -n "${_privileged_perm_list?}"; then
    _filename="privapp-permissions-${_base_name:?}.xml"
    {
      begin_xml "${_pkg_name:?}" "${_cert_sha256?}" 'privapp-permissions'
      printf '%s' "${_privileged_perm_list:?}" | while IFS='|' read -r NAME MIN_API; do
        append_perm_to_xml "${NAME:?}" "${MIN_API:?}" 'privapp-permissions' '' '' || ui_error "Failed to append the '${NAME?}' permission on '${_filename?}'"
      done
      terminate_xml 'privapp-permissions'
    } 1> "${OUTPUT_DIR:?}/${_filename:?}"
  fi
  if test -n "${_dangerous_perm_list?}"; then
    _filename="default-permissions-${_base_name:?}.xml"
    {
      begin_xml "${_pkg_name:?}" "${_cert_sha256?}" 'default-permissions'
      LAST_PERM_GROUP=''
      printf '%s' "${_dangerous_perm_list:?}" | LC_ALL='C.UTF-8' sort | while IFS='|' read -r GROUP _ NAME WHITELIST MIN_API; do
        append_perm_to_xml "${NAME:?}" "${MIN_API:?}" 'default-permissions' "${GROUP:?}" "${WHITELIST:?}" || ui_error "Failed to append the '${NAME?}' permission on '${_filename?}'"
      done
      unset LAST_PERM_GROUP
      terminate_xml 'default-permissions'
    } 1> "${OUTPUT_DIR:?}/${_filename:?}"
  fi
}
#endregion

# @section MAIN FUNCTION ----
#region
main()
{
  local status backup_ifs base_name cmd_output pkg_name perm_list cert_sha256=''

  fix_posix_emulation_if_needed

  # BEGIN: Global config (overridable via env)
  export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  set_android_sdk_path_if_unset
  export AAPT_PATH="${AAPT_PATH:-$(find_android_build_tool 'aapt2' || find_android_build_tool 'aapt' || :)}"
  export APKSIGNER_PATH="${APKSIGNER_PATH-}"
  export KEYTOOL_PATH="${KEYTOOL_PATH-}"

  export OUTPUT_DIR="${OUTPUT_DIR-}"
  # END: Global config

  if test -z "${AAPT_PATH?}"; then
    show_error 'Neither "aapt2" nor "aapt" could be found. You need to set AAPT_PATH'
    return "${EX_UNAVAILABLE?}"
  fi

  if test "${NO_CERT_DIGEST:?}" = 'false'; then
    if test -n "${APKSIGNER_PATH?}" || APKSIGNER_PATH="$(find_android_build_tool 'apksigner' || command 2> /dev/null -v 'apksigner.bat')"; then
      :
    elif test -n "${KEYTOOL_PATH?}" || KEYTOOL_PATH="$(command 2> /dev/null -v 'keytool')"; then
      :
    else
      show_error 'Neither "apksigner" nor "keytool" could be found. You need to set either APKSIGNER_PATH or KEYTOOL_PATH'
      return "${EX_UNAVAILABLE?}"
    fi
  fi

  if DATA_DIR="$(find_data_dir)" && test -f "${DATA_DIR:?}/perms/.completed"; then
    :
  else
    show_error 'Required data not found. Please execute "dl-perm-list.sh" before running this script'
    return 4
  fi

  test -n "${1-}" || {
    show_error 'Missing required argument. Please specify one or more APK file paths to process'
    return 3
  }

  readonly NL='
'

  test "${1:?}" != '-' || {
    backup_ifs="${IFS-}"
    IFS="${NL:?}"

    set -f || :
    # shellcheck disable=SC2046 # Word splitting is intended
    set -- $(cat | sort || :) || ui_error 'Failed expanding stdin inside main()'
    set +f || :

    IFS="${backup_ifs?}"
  }

  BASE_DIR="$(realpath 2> /dev/null . || readlink 2> /dev/null -f .)" || return 7

  test -n "${OUTPUT_DIR?}" || OUTPUT_DIR="${BASE_DIR:?}/output"
  test -d "${OUTPUT_DIR:?}" || mkdir -p -- "${OUTPUT_DIR:?}" || return 8

  printf 1>&2 '%s\n' "Output dir: ${OUTPUT_DIR:?}"

  status=0
  while test "$#" -gt 0; do
    base_name="$(basename "${1:?}" || printf '%s\n' 'unknown')"
    printf 1>&2 '\n%s\n' "Filename: ${base_name:?}"

    show_status 'Using aapt...'
    set_red_color
    cmd_output="$("${AAPT_PATH:?}" dump permissions "${1:?}" | grep -F -e 'package: ' -e 'uses-permission: ')" || {
      status=9
      show_error "aapt failed"
      shift
      continue
    }

    pkg_name="$(printf '%s\n' "${cmd_output:?}" | grep -F -e 'package: ' | cut -d ':' -f '2-' -s | cut -b '2-')" || return 10
    perm_list="$(printf '%s\n' "${cmd_output:?}" | grep -F -e 'uses-permission: ' | cut -d "'" -f '2' -s | LC_ALL='C.UTF-8' sort)" || return 11
    cmd_output=''

    if test "${NO_CERT_DIGEST:?}" = 'false'; then
      cert_sha256="$(get_apk_cert_sha256 "${1:?}")" || {
        status=12
        show_error "get_apk_cert_sha256() failed"
        shift
        continue
      }
    fi

    show_status 'Parsing...'
    printf '%s\n' "${perm_list:?}" | parse_perms_and_generate_xml_files "${base_name:?}" "${pkg_name:?}" "${cert_sha256?}" || {
      status="${?}"
      show_error "Parsing failed"
    }

    shift
  done

  return "${status:?}"
}
#endregion

# @section CLI ARGUMENTS PARSING ----
#region
execute_script='true'
STATUS=0
SCRIPT_VERBOSE='false'
PLACEHOLDERS='false'
NO_CERT_DIGEST='false'

while test "$#" -gt 0; do
  case "${1?}" in
    -V | --version)
      execute_script='false'
      # REUSE-IgnoreStart
      printf '%s\n' "${SCRIPT_NAME:?}, version ${SCRIPT_VERSION:?}"
      printf '%s\n' "Copyright (C) ${SCRIPT_YEAR:?} ${SCRIPT_AUTHOR:?}"
      printf '%s\n\n' 'License Apache-2.0 or GPLv3+ with APE.'
      printf '%s\n' 'There is NO WARRANTY, to the extent permitted by law.'
      # REUSE-IgnoreEnd
      ;;

    -v) SCRIPT_VERBOSE='true' ;;
    --use-placeholders) PLACEHOLDERS='true' ;;
    --no-cert-digest) NO_CERT_DIGEST='true' ;;

    -) # Read from STDIN (implies end of options)
      break
      ;;
    --) # End of options / Positional arguments follow
      shift
      break
      ;;
    --*)
      execute_script='false'
      STATUS=2
      printf 1>&2 '%s\n' "${SCRIPT_SHORTNAME?}: unrecognized option '${1}'"
      ;;
    -*)
      execute_script='false'
      STATUS=2
      printf 1>&2 '%s\n' "${SCRIPT_SHORTNAME?}: invalid option -- '${1#-}'"
      ;;
    *) break ;;
  esac

  shift
done
#endregion

# @section EXECUTION ENTRY POINT ----
#region
if test "${execute_script:?}" = 'true'; then
  show_status "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?} by ${SCRIPT_AUTHOR:?}"

  test "$#" -ne 0 || set -- ''
  main "${@}" || STATUS="${?}"
  reset_color
fi

pause_if_needed "${STATUS:?}"
exit "${?}"
#endregion
