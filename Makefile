#!/usr/bin/env -S make -f
# SPDX-FileCopyrightText: 2024 ale5000
# SPDX-License-Identifier: GPL-3.0-or-later

.POSIX:

# --- Performance optimizations & global config ---
# Disable the default inference rule for .sh files early to speed up parsing
.sh:
	@:

# --- Configurations && shell commands ---
GET_PROJECT_NAME = (git 2> /dev/null rev-parse --show-toplevel | xargs 2> /dev/null basename) || basename '$(CURDIR)'
OUTPUT_DIR       = output

REUSE_TOOL       = reuse

# --- Target descriptions (for help logic) ---
DESCRIPTION_TARGET_BUILDOTA    = Build the flashable OTA zip
DESCRIPTION_TARGET_BUILDOTAOSS = Build the flashable OTA zip (open-source components only)
DESCRIPTION_TARGET_INSTALLTEST = Emulate an Android recovery on your PC and run the flashable zip file inside it
DESCRIPTION_TARGET_CLEAN       = Remove build artifacts
DESCRIPTION_TARGET_REUSE_LINT  = Verify license and copyright compliance (REUSE)
DESCRIPTION_TARGET_SPDX        = Generate the SBOM in SPDX format
DESCRIPTION_TARGET_HELP        = Display this help

# --- Primary targets ---
.PHONY: all buildota buildotaoss installtest clean help

all: buildota buildotaoss ;

buildota:
	BUILD_TYPE=full '$(CURDIR)/build.sh' --no-default-build-type --no-pause $(ARGS)

buildotaoss:
	BUILD_TYPE=oss '$(CURDIR)/build.sh' --no-default-build-type --no-pause $(ARGS)

installtest:
	@'$(CURDIR)/recovery-simulator/recovery.sh' '$(CURDIR)'/output/*.zip

clean:
	rm -f '$(CURDIR)'/output/*.zip
	rm -f '$(CURDIR)'/output/*.zip.md5
	rm -f '$(CURDIR)'/output/*.zip.sha256

# --- Compliance targets ---
.PHONY: reuse-lint spdx

reuse-lint:
	@echo 'Checking REUSE compliance...'
	@'$(REUSE_TOOL)' lint

spdx: reuse-lint
	@echo ''
	@PROJECT_NAME="$$( $(GET_PROJECT_NAME) )"; \
	echo 'Generating SPDX SBOM at $(OUTPUT_DIR)/'"$${PROJECT_NAME:?}.spdx..."; \
	'$(REUSE_TOOL)' spdx --creator-person ale5000 --add-license-concluded -o '$(CURDIR)/$(OUTPUT_DIR)/'"$${PROJECT_NAME:?}.spdx"
	@echo 'Done.'

# --- Aliases & compatibility ---
.PHONY: build test check distcheck sbom
build: buildotaoss ;
test: installtest ;
check: test ;
distcheck: test ;
sbom: spdx ;

# --- Help system ---
# Hide specific targets from the help list
.hide: build test check distcheck sbom

help:
	@'$(MAKE)' 2>/dev/null -qnrp | awk \
		'/^DESCRIPTION_TARGET_[A-Z0-9_]+[[:space:]]*=/{ k=tolower(substr($$1,20)); gsub(/_/,"-",k); desc[k]=substr($$0,index($$0,"=")+2) } \
		/^\.hide:/{ n=split(substr($$0,7),a); for(i=1;i<=n;i++) hide[a[i]]=1 } \
		/^[a-zA-Z_][a-zA-Z0-9_-]*:/{ t=substr($$0,1,index($$0,":")-1); if(tolower(t)!="makefile") tgt[t]=1 } \
		END{ for(t in tgt){ if(t in hide) continue; if(t in desc) printf "%-15s %s\n",t,desc[t]|"sort"; else print t|"sort" } }'
