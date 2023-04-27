@REM SPDX-FileCopyrightText: (c) 2016 ale5000
@REM SPDX-License-Identifier: GPL-3.0-or-later
@REM SPDX-FileType: SOURCE

@echo off
SETLOCAL 2> nul

REM Fix the working directory when using "Run as administrator"
IF "%CD%" == "%windir%\system32" CD /D "%~dp0"

SET "LANG=C.UTF-8"

SET "BB_FIX_BACKSLASH=1"
SET "PATH=.;%PATH%"
SET "PATHEXT=.SH;%PATHEXT%"
SET "HOME=%~dp0"
SET "SCRIPT_DIR=%~dp0"

"%~dp0tools\win\busybox.exe" ash -s -c "unset A5K_FUNCTIONS_INCLUDED; . '%~dp0includes\common.sh' || exit 1; change_title 'Command-line'; unset JAVA_HOME; alias dir=ls; alias 'cd..'='cd ..'; alias 'cd.'='cd .'; alias 'cls'='reset'; alias 'profgen'='profile-generator.sh'" "ash" %*

ENDLOCAL 2> nul
