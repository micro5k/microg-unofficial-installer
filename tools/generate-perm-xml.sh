#!/usr/bin/env sh
# @name Generate perm XML files
# @brief Generate XML files for Android default and privileged permissions
# @author ale5000
# Get the latest version from here: https://github.com/micro5k/microg-unofficial-installer/tree/main/tools

# SPDX-FileCopyrightText: (c) 2025 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

readonly SCRIPT_NAME='Generate perm XML files'
readonly SCRIPT_SHORTNAME='GenPermXml'
readonly SCRIPT_VERSION='0.1.2'
readonly SCRIPT_AUTHOR='ale5000'

set -u
# shellcheck disable=SC3040,SC3041,SC2015
{
  # Unsupported set options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue
  (set +H 2> /dev/null) && set +H || true
  (set -o pipefail 2> /dev/null) && set -o pipefail || true
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
  printf 1>&2 '\033[1;31m%s\033[0m\n' "ERROR: ${1?}"
}

ui_error()
{
  # ToDO: Remove this function
  show_error "${1?}"
  exit 55
}

readonly MAX_API='36'

readonly NL='
'

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

  _path="$(realpath "${_path:?}")" || return 1

  printf '%s\n' "${_path:?}"
}

get_permission_declaration()
{
  grep -m 1 -F -e "android:name=\"${1:?}\"" -- "${DATA_DIR:?}/perms/base-permissions-api-${2:?}.xml" || return 1
}

is_system_permission()
{
  case "${1:?}" in
    'android.permission.'* | 'com.android.'*) return 0 ;;
    *) ;;
  esac
  return 1
}

begin_xml()
{
  printf '%s\n' '<?xml version="1.0" encoding="utf-8"?>'
  printf '%s\n' '<!--'
  printf '%s\n' '    SPDX-FileCopyrightText: NONE'
  printf '%s\n' '    SPDX-License-Identifier: CC0-1.0'
  printf '%s\n' "    Generated by ${SCRIPT_SHORTNAME:?} v${SCRIPT_VERSION:?} of ${SCRIPT_AUTHOR:?}"
  printf '%s\n\n' '-->'

  if test "${3:?}" = 'privapp-permissions'; then
    printf '%s\n' '<permissions>'
    printf '%s\n' "    <privapp-permissions package=\"${1:?}\" sha256-cert-digest=\"${2:?}\">"
  elif test "${3:?}" = 'default-permissions'; then
    printf '%s\n' '<exceptions>'
    printf '%s\n' "    <exception package=\"${1:?}\" sha256-cert-digest=\"${2:?}\">"
  else
    return 1
  fi
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

append_perm_to_xml()
{
  local _xml_compat_info

  case "${2:?}" in '23') _xml_compat_info='' ;; *) _xml_compat_info=" <!-- MinApi: ${2:?} -->" ;; esac

  if test -n "${4?}"; then
    if test "${4:?}" != "${LAST_PERM_GROUP?}" && LAST_PERM_GROUP="${4:?}"; then printf '%s\n' "        <!-- ${4#"z)"} -->"; fi
  fi

  if test "${3:?}" = 'privapp-permissions'; then
    printf '%s\n' "        <permission name=\"${1:?}\" />${_xml_compat_info?}"
  elif test "${3:?}" = 'default-permissions'; then
    if test "${5?}" = 'true'; then
      printf '%s\n' "        <permission name=\"${1:?}\" fixed=\"false\" whitelisted=\"true\" />${_xml_compat_info?}"
    else
      printf '%s\n' "        <permission name=\"${1:?}\" fixed=\"false\" />${_xml_compat_info?}"
    fi
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
  _cert_sha256="${3:?}"

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
        show_warn "Failed to the parse protection level of '${_perm?}' on API ${_api?}"
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

      case "${_perm_type_found?}" in 'true') ;; *) show_warn "Unknown protection level for '${_perm?}' on API ${_api?}" ;; esac
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
      begin_xml "${_pkg_name:?}" "${_cert_sha256:?}" 'privapp-permissions'
      printf '%s' "${_privileged_perm_list:?}" | while IFS='|' read -r NAME MIN_API; do
        append_perm_to_xml "${NAME:?}" "${MIN_API:?}" 'privapp-permissions' '' '' || ui_error "Failed to append the '${NAME?}' permission on '${_filename?}'"
      done
      terminate_xml 'privapp-permissions'
    } 1> "${BASE_DIR:?}/output/${_filename:?}"
  fi
  if test -n "${_dangerous_perm_list?}"; then
    _filename="default-permissions-${_base_name:?}.xml"
    {
      begin_xml "${_pkg_name:?}" "${_cert_sha256:?}" 'default-permissions'
      LAST_PERM_GROUP=''
      printf '%s' "${_dangerous_perm_list:?}" | LC_ALL=C sort | while IFS='|' read -r GROUP _ NAME WHITELIST MIN_API; do
        append_perm_to_xml "${NAME:?}" "${MIN_API:?}" 'default-permissions' "${GROUP:?}" "${WHITELIST:?}" || ui_error "Failed to append the '${NAME?}' permission on '${_filename?}'"
      done
      unset LAST_PERM_GROUP
      terminate_xml 'default-permissions'
    } 1> "${BASE_DIR:?}/output/${_filename:?}"
  fi
}

get_cert_sha256()
{
  if test -n "${APKSIGNER_PATH-}"; then
    "${APKSIGNER_PATH:?}" verify --min-sdk-version 24 --print-certs -- "${1:?}" | grep -m 1 -F -e 'certificate SHA-256 digest:' | cut -d ':' -f '2-' -s | tr -d -- ' ' | tr -- '[:lower:]' '[:upper:]' | sed -e 's/../&:/g;s/:$//'
  elif test -n "${KEYTOOL_PATH-}"; then
    "${KEYTOOL_PATH:?}" -printcert -jarfile "${1:?}" | grep -m 1 -F -e 'SHA256:' | cut -d ':' -f '2-' -s | tr -d -- ' '
  else
    return 255
  fi
}

find_android_build_tool()
{
  local _tool_path

  if _tool_path="$(command -v "${1:?}")" && test -n "${_tool_path?}"; then
    :
  elif test -n "${ANDROID_SDK_ROOT-}" && test -d "${ANDROID_SDK_ROOT:?}/build-tools" && _tool_path="$(find "${ANDROID_SDK_ROOT:?}/build-tools" -maxdepth 2 -iname "${1:?}*" | LC_ALL=C sort -V -r | head -n 1)" && test -n "${_tool_path?}"; then
    :
  else
    return 1
  fi

  printf '%s\n' "${_tool_path:?}"
}

main()
{
  local base_name cmd_output pkg_name perm_list cert_sha256

  test -n "${1-}" || {
    show_error "You must pass the filename of the file to be processed."
    return 3
  }

  DATA_DIR="$(find_data_dir)" || return 4
  # Avoid a strange issue on Bash under Windows
  if command 1> /dev/null -v 'cygpath' && test "$(cygpath -m -- "${PWD:?}" || :)" = "$(cygpath -m -S || :)"; then cd "${DATA_DIR:?}/.." || return 5; fi
  BASE_DIR="$(realpath .)" || return 6
  test -d "${DATA_DIR:?}/perms" || return 7
  test -d "${BASE_DIR:?}/output" || mkdir -p -- "${BASE_DIR:?}/output" || return 8

  if test -n "${AAPT_PATH-}" || AAPT_PATH="$(find_android_build_tool 'aapt2' || find_android_build_tool 'aapt')"; then
    :
  else
    return 255
  fi

  if test -n "${APKSIGNER_PATH-}" || APKSIGNER_PATH="$(command -v 'apksigner' || command -v 'apksigner.bat')"; then
    :
  elif test -n "${KEYTOOL_PATH-}" || KEYTOOL_PATH="$(command -v 'keytool')"; then
    :
  else
    show_error "Neither apksigner nor keytool were found. You must set either APKSIGNER_PATH or KEYTOOL_PATH"
    return 255
  fi

  while test "${#}" -gt 0; do
    base_name="$(basename "${1:?}" || printf '%s\n' 'unknown')"
    printf 1>&2 '%s\n' "${base_name?}"
    cmd_output="$("${AAPT_PATH:?}" dump permissions "${1:?}" | grep -F -e 'package: ' -e 'uses-permission: ')" || return 9
    pkg_name="$(printf '%s\n' "${cmd_output:?}" | grep -F -e 'package: ' | cut -d ':' -f '2-' -s | cut -b '2-')" || return 10
    perm_list="$(printf '%s\n' "${cmd_output:?}" | grep -F -e 'uses-permission: ' | cut -d "'" -f '2' -s | LC_ALL=C sort)" || return 11
    cmd_output=''
    printf 1>&2 '\033[1;31m\r'
    cert_sha256="$(get_cert_sha256 "${1:?}")" || return 12
    printf 1>&2 '\033[0m\r'

    printf '%s\n' "${perm_list:?}" | parse_perms_and_generate_xml_files "${base_name:?}" "${pkg_name:?}" "${cert_sha256:?}" || return "${?}"
    printf 1>&2 '\n'

    shift
  done
}

STATUS=0
SCRIPT_VERBOSE='false'
execute_script='true'

while test "${#}" -gt 0; do
  case "${1?}" in
    -V | --version)
      printf '%s\n' "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?}"
      printf '%s\n' "Copy""right (c) 2025 ${SCRIPT_AUTHOR:?}"
      printf '%s\n' 'License GPLv3+'
      execute_script='false'
      ;;

    -v) SCRIPT_VERBOSE='true' ;;

    --)
      shift
      break
      ;;

    --*)
      printf 1>&2 '%s\n' "${SCRIPT_SHORTNAME?}: unrecognized option '${1}'"
      execute_script='false'
      STATUS=2
      ;;

    -*)
      printf 1>&2 '%s\n' "${SCRIPT_SHORTNAME?}: invalid option -- '${1#-}'"
      execute_script='false'
      STATUS=2
      ;;

    *)
      break
      ;;
  esac

  shift
done

if test "${execute_script:?}" = 'true'; then
  show_status "${SCRIPT_NAME:?} v${SCRIPT_VERSION:?} by ${SCRIPT_AUTHOR:?}"

  if test "${#}" -eq 0; then set -- ''; fi
  main "${@}" || STATUS="${?}"
fi

pause_if_needed "${STATUS:?}"
exit "${?}"
