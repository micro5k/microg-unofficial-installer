@echo off
title Building the flashable ZIP... 2> nul
"%CD%\tools\win\busybox" bash "%CD%\build.sh"
title Done 2> nul
pause > nul
