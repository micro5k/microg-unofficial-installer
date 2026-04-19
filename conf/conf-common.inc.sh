#!/usr/bin/env sh
# SPDX-FileCopyrightText: NONE
# SPDX-License-Identifier: CC0-1.0

conf_is_oss_only_build_enabled()
{ # 0 => true, 1 => false
  return 0
}

conf_common_should_skip_license()
{
  case "${1:?}" in
    'Info-ZIP' | 'LGPL-3.0-or-later' | 'Unlicense') return 0 ;; # Skipped from the generated zip
    *) ;;
  esac

  return 1
}

conf_oss_files_to_download()
{
  cat << 'EOF'
EOF
}
