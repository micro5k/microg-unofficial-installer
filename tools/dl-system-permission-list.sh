#!/usr/bin/env sh
# @name Android permissions retriever
# @brief Retrieve the Android system permissions list
# @author ale5000
# Get the latest version from here: https://github.com/micro5k/microg-unofficial-installer/tree/main/utils

# SPDX-FileCopyrightText: (c) 2025 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck enable=all
# shellcheck disable=SC3043 # In POSIX sh, local is undefined

set -u
# shellcheck disable=SC3040,SC3041,SC2015
{
  # Unsupported set options may cause the shell to exit (even without set -e), so first try them in a subshell to avoid this issue
  (set -o posix 2> /dev/null) && set -o posix || true
  (set +H 2> /dev/null) && set +H || true
  (set -o pipefail 2> /dev/null) && set -o pipefail || true
}

readonly SCRIPT_NAME='Android permissions retriever'
readonly SCRIPT_SHORTNAME='DlPermList'
readonly SCRIPT_VERSION='0.1'

# shellcheck disable=SC2034
{
  readonly TAG_API_23='android-6.0.1_r81'  # Android 6
  readonly TAG_API_24='android-7.0.0_r36'  # Android 7.0
  readonly TAG_API_25='android-7.1.2_r39'  # Android 7.1
  readonly TAG_API_26='android-8.0.0_r51'  # Android 8.0
  readonly TAG_API_27='android-8.1.0_r81'  # Android 8.1
  readonly TAG_API_28='android-9.0.0_r61'  # Android 9
  readonly TAG_API_29='android-10.0.0_r47' # Android 10
  readonly TAG_API_30='android-11.0.0_r48' # Android 11
  readonly TAG_API_31='android-12.0.0_r34' # Android 12.0
  readonly TAG_API_32='android-12.1.0_r27' # Android 12.1
  readonly TAG_API_33='android-13.0.0_r84' # Android 13
  readonly TAG_API_34='android-14.0.0_r75' # Android 14
  readonly TAG_API_35='android-15.0.0_r36' # Android 15
  readonly TAG_API_36='android-16.0.0_r2'  # Android 16
}

readonly MAX_API='36'

readonly WGET_CMD='wget'
readonly DL_UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0'
readonly DL_ACCEPT_HEADER='Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
readonly DL_ACCEPT_LANG_HEADER='Accept-Language: en-US,en;q=0.5'

dl()
{
  "${WGET_CMD:?}" -q -O "${2:?}" -U "${DL_UA:?}" --header "${DL_ACCEPT_HEADER:?}" --header "${DL_ACCEPT_LANG_HEADER:?}" --no-cache -- "${1:?}" || return "${?}"
}

download_and_parse_permissions()
{
  dl "https://android.googlesource.com/platform/frameworks/base/+/refs/tags/${2:?}/core/res/AndroidManifest.xml?format=text" '-' |
    base64 -d |
    tr -s '\n' ' ' |
    sed -- 's/>/>\n/g' |
    grep -F -e '<permission' 1> "./data/base-permissions-api-${1:?}.xml" || return "${?}"
}

main()
{
  local api tag

  for api in $(seq 23 "${MAX_API:?}"); do
    tag="$(eval " printf '%s\n' \"\${TAG_API_${api:?}:?}\" ")" || printf '%s\n' "Failed to get tag for API ${api?}"
    echo "${api:?}: ${tag:?}"
    download_and_parse_permissions "${api:?}" "${tag:?}"
  done
}

main
