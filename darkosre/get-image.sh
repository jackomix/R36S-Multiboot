#!/bin/bash

repo="southoz/dArkOSRE-R36"
release_body=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.body')
torrent_url=$(echo "$release_body" | grep -oP '(?<=\[Torrent\]\().*?(?=\))' | head -n 1)
mega_url=$(echo "$release_body" | grep -oP '(?<=\[Mega\]\().*?(?=\))' | head -n 1)

if [[ ! -f "${ThisImgName}" ]]
then
    echo "To download dArkOSRE R36:"
    echo "Latest release: https://github.com/${repo}/releases/latest"
    echo "Torrent: ${torrent_url}"
    echo "Mega: ${mega_url}"
    
    if command -v aria2c >/dev/null 2>&1; then
        echo "Attempting to download via aria2c..."
        wget "$torrent_url" -O darkosre.torrent
        aria2c darkosre.torrent
        # Note: Extraction might require 7z and renaming the .img file.
        # This part depends on the torrent contents.
        archive=$(find . -name "*.7z")
        7z x "$archive"
        img=$(find . -name "*.img")
        mv "$img" "${ThisImgName}"
        rm darkosre.torrent "$archive"
    else
        echo "Please download the image manually and place it in this directory as ${ThisImgName}"
        exit 1
    fi
fi
