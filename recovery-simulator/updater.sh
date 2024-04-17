#!/sbin/sh
# SPDX-FileCopyrightText: (c) 2022 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

# Ensure that the overridden commands are preferred over BusyBox applets (and that unsafe commands aren't accessible)
export BB_OVERRIDE_APPLETS='mount umount chown su sudo' || exit 125

# shellcheck source=SCRIPTDIR/inc/configure-overrides.sh
. "${RS_OVERRIDE_SCRIPT:?}" || exit "${?}"

# Note: Bashcov use PS4, LINENO, BASH_XTRACEFD, SHELLOPTS (don't touch them)
# ToDO: Check BASHCOV_BASH_PATH

unset OUR_TEMP_DIR
unset HOSTNAME
unset HOSTTYPE
unset MACHTYPE
unset OSTYPE
unset OPTERR
unset OPTIND

# nosemgrep: IFS change is intended
IFS=' 	
'
PS1='\w \$ '
PS2='> '
if test "${COVERAGE:-false}" = 'false'; then
  PS4='+ '
fi

OSTYPE='linux-androideabi'

# shellcheck source=SCRIPTDIR/../zip-content/META-INF/com/google/android/update-binary.sh
. "${TMPDIR:?}/update-binary" || exit "${?}"
