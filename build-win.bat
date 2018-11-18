@echo off
REM Copyright (C) 2017-2018 ale5000
REM SPDX-License-Identifer: GPL-3.0-or-later

TITLE Building the flashable ZIP... 2> nul

SETLOCAL 2> nul
"%~dp0tools\win\busybox.exe" bash "%~dp0build.sh"
ENDLOCAL 2> nul
SET "EXIT_CODE=%ERRORLEVEL%"

TITLE Done 2> nul

PAUSE > nul
IF %EXIT_CODE% NEQ 0 EXIT /B %EXIT_CODE%
