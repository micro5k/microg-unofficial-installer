#!/usr/bin/env bash
# SPDX-FileCopyrightText: none
# SPDX-License-Identifier: CC0-1.0
# SPDX-FileType: SOURCE

files_to_download()
{
cat <<'EOF'
PlayStore-recent.apk|files/variants|6c60fa863dd7befef49082c0dcf6278947a09333|https://www.apkmirror.com/wp-content/themes/APKMirror/download.php?id=137220||https://www.apkmirror.com/apk/google-inc/google-play-store/google-play-store-7-1-25-release/google-play-store-7-1-25-i-all-0-pr-137772785-android-apk-download/download/
PlayStore-legacy.apk|files/variants|d78b377db43a2bc0570f37b2dd0efa4ec0b95746|https://www.apkmirror.com/wp-content/themes/APKMirror/download.php?id=2911||
AndroidAuto.apk|files/variants|70ca5318fc24b462f1da045e7639260c63db252e|https://www.apkmirror.com/wp-content/themes/APKMirror/download.php?id=3683192||https://www.apkmirror.com/apk/google-inc/android-auto/android-auto-1-2-512930-stub-release/android-auto-1-2-512930-stub-android-apk-download/
EOF
}
