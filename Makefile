# SPDX-FileCopyrightText: (c) 2024 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

.POSIX:
.PHONY: all clean test build cmdline

all: buildota buildotaoss ;

buildota:
	BUILD_TYPE=full NO_PAUSE=1 "$(CURDIR)/build.sh" $(ARGS)

build: buildotaoss ;
buildotaoss:
	BUILD_TYPE=oss NO_PAUSE=1 "$(CURDIR)/build.sh" $(ARGS)

cmdline: ;
