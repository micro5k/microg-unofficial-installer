#!/sbin/sh

# SPDX-FileCopyrightText: (c) 2016-2019, 2021 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileType: SOURCE

unset OUR_TEMP_DIR
unset BB_GLOBBING
unset FUNCNAME
unset HOSTNAME
unset LINENO
unset OPTIND
unset OLDPWD

IFS=' 	
'
PS1='\w \$ '
PS2='> '
PS4='+ '

# Ensure that the overridden commands are preferred over BusyBox applets
alias mount='/usr/bin/env mount'
alias umount='/usr/bin/env umount'
alias chown='/usr/bin/env chown'

# shellcheck source=SCRIPTDIR/../zip-content/META-INF/com/google/android/update-binary.sh
. "${TMPDIR}/update-binary"
