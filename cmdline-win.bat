@echo off
REM Copyright (C) 2017-2018 ale5000
REM SPDX-License-Identifer: GPL-3.0-or-later

TITLE Command-line 2> nul
SETLOCAL 2> nul

REM Fix the working directory when using "Run as administrator"
IF "%CD%" == "%windir%\system32" CD /D "%~dp0"

IF EXIST "%ProgramFiles(x86)%\GnuWin32\bin" SET "PATH=%ProgramFiles(x86)%\GnuWin32\bin;%PATH%"
IF EXIST "%ProgramFiles%\GnuWin32\bin" SET "PATH=%ProgramFiles%\GnuWin32\bin;%PATH%"
SET "PATH=.;%PATH%"
IF EXIST "%~dp0tools\win" SET "PATH=%~dp0tools\win;%PATH%"

CHCP 858 >nul || ECHO "Changing the codepage failed"
"%~dp0tools\win\busybox.exe" ash -s -c ". ./scripts/common.sh; alias dir=ls; alias 'cd..'='cd ..'; alias 'cd.'='cd .'; alias cls=clear" ash %*

ENDLOCAL 2> nul
TITLE %ComSpec% 2> nul
