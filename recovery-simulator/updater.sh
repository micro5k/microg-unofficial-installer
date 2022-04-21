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

# Ensure that the overridden commands are preferred over BusyBox applets / This expands when defined, not when used (it is intended)
# shellcheck disable=SC2139
alias mount="$(busybox which mount | busybox xargs busybox realpath)"
# shellcheck disable=SC2139
alias umount="$(busybox which umount | busybox xargs busybox realpath)"
# shellcheck disable=SC2139
alias chown="$(busybox which chown | busybox xargs busybox realpath)"

type mount

# shellcheck source=SCRIPTDIR/../zip-content/META-INF/com/google/android/update-binary.sh
. "${TMPDIR}/update-binary"
