@REM SPDX-FileCopyrightText: (c) 2016 ale5000
@REM SPDX-License-Identifier: GPL-3.0-or-later
@REM SPDX-FileType: SOURCE

@echo off
SETLOCAL 2> nul

REM Fix the working directory when using "Run as administrator"
IF "%CD%" == "%windir%\system32" CD /D "%~dp0"

IF NOT EXIST "%~dp0tools\win\busybox.exe" (
  ENDLOCAL 2> nul
  ECHO BusyBox is missing
  EXIT /B 127
)

SET "LANG=en_US.UTF-8"
SET "MAIN_DIR=%~dp0"

IF "%USER_HOME%" == "" (
  IF "%TERM_PROGRAM%" == "mintty" SET "TERM_PROGRAM=mintty-"
  SET "USER_HOME=%USERPROFILE%"
  SET "HOME=%MAIN_DIR%"
)

SET "DO_INIT_CMDLINE=1"
SET "KILL_PPID=1"
SET "STARTED_FROM_BATCH_FILE=1"
SET "IS_PATH_INITIALIZED="
SET "__QUOTED_PARAMS="
SET "__SHELL_EXE=%~dp0tools\win\busybox.exe"

"%__SHELL_EXE%" ash -s -c ". '%~dp0includes\common.sh' || exit ${?}" "ash" %*

ENDLOCAL 2> nul
IF %ERRORLEVEL% NEQ 0 EXIT /B %ERRORLEVEL%
