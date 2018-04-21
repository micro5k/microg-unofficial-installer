#!/usr/bin/env bash

files_to_download()
{
cat <<EOF
PlayStore-recent.apk|zip-content/files/variants|6c60fa863dd7befef49082c0dcf6278947a09333|https://www.apkmirror.com/wp-content/themes/APKMirror/download.php?id=137220
PlayStore-legacy.apk|zip-content/files/variants|d78b377db43a2bc0570f37b2dd0efa4ec0b95746|https://www.apkmirror.com/wp-content/themes/APKMirror/download.php?id=2911
EOF
}

export NAME='microG-unofficial-installer-ale5000'
