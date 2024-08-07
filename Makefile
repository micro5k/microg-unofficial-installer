# SPDX-FileCopyrightText: (c) 2024 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

.POSIX:
.PHONY: all clean test build cmdline

all: buildota buildotaoss

buildota:
	OPENSOURCE_ONLY=false NO_PAUSE=1 "$(CURDIR)/build.sh" $(ARGS)

build: buildotaoss ;
buildotaoss:
	OPENSOURCE_ONLY=true NO_PAUSE=1 "$(CURDIR)/build.sh" $(ARGS)

cmdline: ;
