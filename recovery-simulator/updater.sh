#!/sbin/sh
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# Ensure that the overridden commands are preferred over BusyBox applets (and that unsafe commands aren't accessible)
export BB_OVERRIDE_APPLETS='mount umount chown su sudo' || exit 125

# shellcheck source=SCRIPTDIR/inc/configure-overrides.sh
. "${RS_OVERRIDE_SCRIPT:?}" || exit "${?}"

unset OUR_TEMP_DIR
unset HOSTNAME
unset HOSTTYPE
unset MACHTYPE
unset OSTYPE
unset OPTERR
unset OPTIND

IFS=' 	
'
PS1='\w \$ '
PS2='> '
if test "${COVERAGE:-false}" = 'false'; then
  PS4='+ '
fi

# shellcheck source=SCRIPTDIR/../zip-content/META-INF/com/google/android/update-binary.sh
. "${TMPDIR:?}/update-binary" || exit "${?}"
