#!/bin/bash

repo="southoz/dArkOSRE-R36"
release_body=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.body')
torrent_url=$(echo "$release_body" | grep -oP '(?<=\[Torrent\]\().*?(?=\))' | head -n 1)
mega_url=$(echo "$release_body" | grep -oP '(?<=\[Mega\]\().*?(?=\))' | head -n 1)
gdrive_url=$(echo "$release_body" | grep -oP '(?<=\[(Google|Google Drive|GDrive|Mirror)\]\().*?(?=\))' | head -n 1)

if [[ ! -f "${ThisImgName}" ]]
then
    echo "To download dArkOSRE R36:"
    echo "Latest release: https://github.com/${repo}/releases/latest"
    echo "Torrent: ${torrent_url}"
    echo "Google Drive: ${gdrive_url}"
    echo "Mega: ${mega_url}"
    
    # Priority: 1. GDrive, 2. Mega, 3. Torrent (last resort)
    if [[ -n "$gdrive_url" ]] && command -v gdown >/dev/null 2>&1; then
        echo "Attempting to download via Google Drive (gdown)..."
        gdown "${gdrive_url}" -O "${ThisImgName}.7z"
    elif [[ -n "$mega_url" ]] && command -v megadl >/dev/null 2>&1; then
        echo "Attempting to download via Mega (megadl)..."
        megadl "${mega_url}" --path "${ThisImgName}.7z"
    elif command -v aria2c >/dev/null 2>&1 && [[ -n "$torrent_url" ]]; then
        echo "Attempting to download via aria2c (Torrent - Last Resort)..."
        wget "$torrent_url" -O darkosre.torrent
        # Use --stop-with-process or a timeout to prevent getting stuck if no seeds
        timeout 120s aria2c --seed-time=0 --on-download-complete=exit darkosre.torrent || echo "Torrent download timed out/failed."
        rm darkosre.torrent
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
