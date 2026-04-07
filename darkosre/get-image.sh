#!/bin/bash

# Updated Mega link for dArkOSRE
mega_url="https://mega.nz/file/k6AgTSTS#RrMGot_xVXyzAr5h_7RDNKFIv2GaKniLYliLSPA3UWc"

if [[ ! -f "${ThisImgName}" ]]
then
    echo "To download dArkOSRE R36:"
    echo "Mega: ${mega_url}"
    
    if command -v megadl >/dev/null 2>&1; then
        echo "Attempting to download via Mega (megadl)..."
        megadl "${mega_url}" --path "${ThisImgName}.7z"
    else
        echo "Error: megadl not found. Cannot download from Mega."
        exit 1
    fi

    # Post-download processing
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
