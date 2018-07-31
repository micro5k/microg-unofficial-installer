@echo off
REM Copyright (C) 2017-2018 ale5000
REM SPDX-License-Identifer: GPL-3.0-or-later

SETLOCAL 2> nul
TITLE Building the flashable ZIP... 2> nul

"%~dp0tools\win\busybox.exe" bash "%~dp0build.sh"

TITLE Done 2> nul
ENDLOCAL 2> nul
PAUSE > nul
