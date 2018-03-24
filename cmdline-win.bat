@echo off

SETLOCAL 2> nul
TITLE Command-line 2> nul

REM Fix the working directory when using "Run as administrator"
IF "%CD%" == "%windir%\system32" CD /D "%~dp0"

IF EXIST "%ProgramFiles(x86)%\GnuWin32\bin" SET "PATH=%ProgramFiles(x86)%\GnuWin32\bin;%PATH%"
IF EXIST "%ProgramFiles%\GnuWin32\bin" SET "PATH=%ProgramFiles%\GnuWin32\bin;%PATH%"
IF EXIST "%~dp0tools\win" SET "PATH=%~dp0tools\win;%PATH%"

"%~dp0tools\win\busybox.exe" ash -s -c "alias dir=ls; alias 'cd..'='cd ..'; alias 'cd.'='cd .'; alias cls=clear"

TITLE 2> nul
ENDLOCAL 2> nul
