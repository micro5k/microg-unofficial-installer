@REM SPDX-FileCopyrightText: (c) 2016 ale5000
@REM SPDX-License-Identifier: GPL-3.0-or-later
@REM SPDX-FileType: SOURCE

@echo off
SETLOCAL 2> nul

REM Fix the working directory when using "Run as administrator"
IF "%CD%" == "%windir%\system32" CD /D "%~dp0"

SET "LANG=C.UTF-8"

SET "PATH=.;%PATH%"
IF EXIST "%~dp0tools\win" SET "PATH=%~dp0tools\win;%PATH%"
SET "PATHEXT=.SH;%PATHEXT%"
SET "HOME=%~dp0"
SET "SCRIPT_DIR=%~dp0"

SET "BASH_VERSION=5.0.17(1)-release"
SET "BASH_VERSINFO=5"

CHCP 65001 1> nul || ECHO "Changing the codepage failed"
"%~dp0tools\win\busybox.exe" ash -s -c ". '%~dp0scripts\common.sh' || exit 1; change_title 'Command-line'; unset JAVA_HOME; alias dir=ls; alias 'cd..'='cd ..'; alias 'cd.'='cd .'; alias cls=reset" "%~f0" %*

ENDLOCAL 2> nul
