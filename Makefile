#!/usr/bin/env -S make -f

# SPDX-FileCopyrightText: (c) 2024 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

.POSIX:

all: buildota buildotaoss ;

.PHONY: all build clean test cmdline

buildota:
	BUILD_TYPE=full "$(CURDIR)/build.sh" --no-default-build-type --no-pause $(ARGS)

buildotaoss:
	BUILD_TYPE=oss "$(CURDIR)/build.sh" --no-default-build-type --no-pause $(ARGS)
build: buildotaoss ;

clean:
	rm -f "$(CURDIR)/output/"*.zip
	rm -f "$(CURDIR)/output/"*.zip.md5
	rm -f "$(CURDIR)/output/"*.zip.sha256

cmdline: ;
