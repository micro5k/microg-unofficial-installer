#!/sbin/sh
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

if test -z "${OVERRIDE_DIR:-}" || test -z "${BB_OVERRIDE_APPLETS:-}"; then
  echo 'Failed to configure overrides!!!'
  exit 124
fi

rs_function_exists()
{
  # shellcheck disable=SC2312
  LC_ALL=C type -- "${1:?}" 2>/dev/null | grep -Fq -- 'is a function'
  return "${?}"
}

rs_override_command()
{
  if rs_function_exists "${1:?}"; then return 0; fi
  if test ! -e "${OVERRIDE_DIR:?}/${1:?}"; then return 1; fi
  eval " ${1:?}() { '${OVERRIDE_DIR:?}/${1:?}' \"\${@}\"; }"  # The folder expands when defined, not when used
  return "${?}"
}

for _rs_cur_override_applet in ${BB_OVERRIDE_APPLETS:?}; do
  rs_override_command "${_rs_cur_override_applet:?}" || exit 125
done
unset _rs_cur_override_applet

unset -f rs_override_command
unset -f rs_function_exists
