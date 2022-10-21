@REM SPDX-FileCopyrightText: (c) 2016 ale5000
@REM SPDX-License-Identifier: GPL-3.0-or-later
@REM SPDX-FileType: SOURCE

@echo off
SETLOCAL 2> nul

REM Fix the working directory when using "Run as administrator"
IF "%CD%" == "%windir%\system32" CD /D "%~dp0"

SET "LANG=C.UTF-8"

CHCP 65001 >nul || ECHO "Changing the codepage failed"
"%~dp0tools\win\busybox.exe" ash "%~dp0build.sh" %*

ENDLOCAL 2> nul

SET "EXIT_CODE=%ERRORLEVEL%"

IF NOT "%APP_BASE_NAME%" == "gradlew" PAUSE > nul
IF %EXIT_CODE% NEQ 0 EXIT /B %EXIT_CODE%
