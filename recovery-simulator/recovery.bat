@REM SPDX-FileCopyrightText: (c) 2022 ale5000
@REM SPDX-License-Identifier: GPL-3.0-or-later
@REM SPDX-FileType: SOURCE

@echo off

SETLOCAL 2> nul
"%~dp0..\tools\win\busybox.exe" ash "%~dp0recovery.sh" %*
ENDLOCAL 2> nul
SET "EXIT_CODE=%ERRORLEVEL%"

IF NOT "%APP_BASE_NAME%" == "gradlew" PAUSE > nul

IF %EXIT_CODE% NEQ 0 EXIT /B %EXIT_CODE%
SET "EXIT_CODE="
