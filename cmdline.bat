@REM SPDX-FileCopyrightText: (c) 2016 ale5000
@REM SPDX-License-Identifier: GPL-3.0-or-later
@REM SPDX-FileType: SOURCE

@echo off
SETLOCAL 2> nul

REM Fix the working directory when using "Run as administrator"
IF "%CD%" == "%windir%\system32" CD /D "%~dp0"

SET "STARTED_FROM_BATCH_FILE=1"
SET "LANG=en_US.UTF-8"

SET "SCRIPT_DIR=%~dp0"
IF NOT "%USERPROFILE%" == "" SET "USER_HOME=%USERPROFILE%"
SET "HOME=%SCRIPT_DIR%"

SET "DO_INIT_CMDLINE=1"
SET "IS_PATH_INITIALIZED="
SET "TERM_PROGRAM="
"%~dp0tools\win\busybox.exe" ash -s -c ". '%~dp0includes\common.sh' || exit ${?}" "ash" %*

ENDLOCAL 2> nul
