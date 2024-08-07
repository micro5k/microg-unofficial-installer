# SPDX-FileCopyrightText: (c) 2024 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

.POSIX:
.PHONY: all test build cmdline

all: buildota buildotaoss

buildota:
	OPENSOURCE_ONLY='false' "$(CURDIR)/build.sh" $(ARGS)

build: buildotaoss ;
buildotaoss:
	OPENSOURCE_ONLY='true' "$(CURDIR)/build.sh" $(ARGS)

cmdline: ;
