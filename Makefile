#!/usr/bin/env -S make -f
# SPDX-FileCopyrightText: 2024 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

.POSIX:

# --- 1. Performance optimizations & global config ---
# Disable the default inference rule for .sh files early to speed up parsing
.sh:
	@:

# --- 2. Target descriptions (for help logic) ---
DESCRIPTION_TARGET_BUILDOTA    = Build the flashable OTA zip
DESCRIPTION_TARGET_BUILDOTAOSS = Build the flashable OTA zip (open-source components only)
DESCRIPTION_TARGET_INSTALLTEST = Emulate an Android recovery on your PC and run the flashable zip file inside it to see the result
DESCRIPTION_TARGET_CLEAN       = Remove build artifacts
DESCRIPTION_TARGET_HELP        = List available targets

# --- 3. Primary targets ---
.PHONY: all buildota buildotaoss installtest clean help
all: buildota buildotaoss ;

buildota:
	BUILD_TYPE=full "$(CURDIR)/build.sh" --no-default-build-type --no-pause $(ARGS)

buildotaoss:
	BUILD_TYPE=oss "$(CURDIR)/build.sh" --no-default-build-type --no-pause $(ARGS)

installtest:
	"$(CURDIR)/recovery-simulator/recovery.sh" "$(CURDIR)"/output/*.zip

clean:
	rm -f "$(CURDIR)"/output/*.zip
	rm -f "$(CURDIR)"/output/*.zip.md5
	rm -f "$(CURDIR)"/output/*.zip.sha256

# --- 4. Aliases & compatibility ---
.PHONY: build test check distcheck
build: buildotaoss ;
test: installtest ;
check: test ;
distcheck: test ;

# --- 5. Help system ---
# Hide specific targets from the help list
.hide: build test check distcheck

help:
	@"$(MAKE)" 2>/dev/null -qnrp | awk \
		'/^DESCRIPTION_TARGET_[A-Z][A-Z0-9_]*[[:space:]]*=[[:space:]]*/{ desc[tolower(substr($$1,20))]=substr($$0,index($$0,"=")+2) } \
		 /^\.hide:/{ n=split(substr($$0,7),a); for(i=1;i<=n;i++) hide[a[i]]=1 } \
		 /^[a-zA-Z_][a-zA-Z0-9_-]*:/{ t=substr($$0,1,index($$0,":")-1); if(tolower(t)!="makefile") tgt[t]=1 } \
		 END{ for(t in tgt){ if(t in hide) continue; if(t in desc) printf "%-20s %s\n",t,desc[t]|"sort"; else print t|"sort" } }'
