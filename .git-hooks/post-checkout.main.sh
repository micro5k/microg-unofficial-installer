#!/usr/bin/env sh
# SPDX-FileCopyrightText: NONE
# SPDX-License-Identifier: CC0-1.0

#PREVIOUS_REF="${1:?}"
#CURRENT_REF="${2:?}"
CHECKOUT_TYPE="${3:?}"

if test "${CHECKOUT_TYPE:?}" = '1'; then
  REMOTE_NAME='origin'
  TARGET_TAG='nightly'
  LOCAL_HASH="$(git 2> /dev/null rev-parse --verify "refs/tags/${TARGET_TAG:?}")" || LOCAL_HASH=''

  if test -n "${LOCAL_HASH?}"; then
    REMOTE_HASH="$(git ls-remote "${REMOTE_NAME:?}" "refs/tags/${TARGET_TAG:?}" | cut -f 1 -s || :)"

    if test -n "${REMOTE_HASH?}" && test "${LOCAL_HASH:?}" != "${REMOTE_HASH:?}"; then
      git update-ref "refs/tags/${TARGET_TAG:?}" "${REMOTE_HASH:?}" || exit "${?}"
      printf '%s\n' "[Hook] Local tag '${TARGET_TAG?}' updated to ${REMOTE_HASH?}"
    fi
  fi
fi
