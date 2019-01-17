@echo off
REM Copyright (C) 2017-2018 ale5000
REM SPDX-License-Identifer: GPL-3.0-or-later

TITLE Building the flashable OTA zip... 2> nul
SETLOCAL 2> nul
"%~dp0tools\win\busybox.exe" ash "%~dp0build.sh"
ENDLOCAL 2> nul
SET "EXIT_CODE=%ERRORLEVEL%"
TITLE Done 2> nul

IF NOT "%~1" == "Gradle" PAUSE > nul

TITLE %ComSpec% 2> nul
IF %EXIT_CODE% NEQ 0 EXIT /B %EXIT_CODE%
SET "EXIT_CODE="
