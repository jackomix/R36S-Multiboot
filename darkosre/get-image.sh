#!/bin/bash

repo="southoz/dArkOSRE-R36"
release_body=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.body')
torrent_url=$(echo "$release_body" | grep -oP '(?<=\[Torrent\]\().*?(?=\))' | head -n 1)
mega_url=$(echo "$release_body" | grep -oP '(?<=\[Mega\]\().*?(?=\))' | head -n 1)
gdrive_url=$(echo "$release_body" | grep -oP '(?<=\[Google Drive\]\().*?(?=\))' | head -n 1)

if [[ ! -f "${ThisImgName}" ]]
then
    echo "To download dArkOSRE R36:"
    echo "Latest release: https://github.com/${repo}/releases/latest"
    echo "Torrent: ${torrent_url}"
    echo "Google Drive: ${gdrive_url}"
    echo "Mega: ${mega_url}"
    
    # Try GDrive first since Torrent is often unseeded
    if [[ -n "$gdrive_url" ]] && command -v gdown >/dev/null 2>&1; then
        echo "Attempting to download via Google Drive (gdown)..."
        gdown "${gdrive_url}" -O "${ThisImgName}.7z"
    elif command -v aria2c >/dev/null 2>&1 && [[ -n "$torrent_url" ]]; then
        echo "Attempting to download via aria2c (Torrent)..."
        wget "$torrent_url" -O darkosre.torrent
        aria2c --seed-time=0 darkosre.torrent
        rm darkosre.torrent
    else
        echo "Automatic download failed. No seeded torrent or GDrive link found."
        echo "Please download the image manually from the Mega/GDrive links above"
        echo "and place it in this directory as ${ThisImgName}"
        exit 1
    fi

    # Post-download processing (Shared between methods)
    archive=$(find . -maxdepth 1 -name "*.7z")
    if [[ -n "$archive" ]]; then
        echo "Extracting dArkOSRE..."
        7z x "$archive"
        img=$(find . -maxdepth 1 -name "*.img")
        mv "$img" "${ThisImgName}"
        rm "$archive"
    fi
    sync
fi
