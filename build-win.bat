@echo off

REM Author: ale5000

SETLOCAL 2> nul
TITLE Building the flashable ZIP... 2> nul

"%~dp0tools\win\busybox.exe" bash "%~dp0build.sh"

TITLE Done 2> nul
ENDLOCAL 2> nul
PAUSE > nul
