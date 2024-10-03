#!/usr/bin/env sh

# SPDX-FileCopyrightText: (c) 2024 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck enable=all

if test -z "${MODULE_NAME-}" || test -z "${MAIN_DIR-}" || test -z "${PLATFORM-}" || test -z "${IS_BUSYBOX-}"; then
  echo 'ERROR: You must first run cmdline.sh or cmdline.bat and then you can type: help'
  exit 1
fi

aligned_print()
{
  printf '%-15s %s\n' "${@}"
}

printf '%s\n' "${MODULE_NAME:?} help"
printf '%s\n\n' 'Licensed under GPLv3+'

aligned_print 'COMMAND' 'DESCRIPTION'
aligned_print '-------' '-----------'
printf '\n'

aligned_print 'help' 'Show this help'
aligned_print 'shellhelp' 'Show the original help of the shell'
printf '\n'

aligned_print 'build' 'Build the flashable OTA zip (set the BUILD_TYPE env var to choose what to build)'
aligned_print 'make' 'Execute "make" of your PC (on Windows it fallback to internal "pdpmake" if no make is found)'
if test "${PLATFORM:?}" = 'win'; then
  aligned_print 'pdpmake' 'Execute the internal "pdpmake"'
else
  aligned_print 'pdpmake' 'Execute "pdpmake" of your PC'
fi
aligned_print 'gradlew' 'Execute the Gradle wrapper'
aligned_print 'cmdline' 'Execute our command-line (if you are already inside, then it will be executed in a subshell)'
printf '\n'

exit 0
