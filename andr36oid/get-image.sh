#!/bin/bash

# Updated link for Andr36oid
asset_url="https://github.com/andr36oid/release_uploads/raw/refs/heads/main/lineage-18.1-20260316-1753-r36s-android.img.zip"

if [[ ! -f "${ThisImgName}" ]]
then
    echo "Downloading Andr36oid..."
    curl -L "$asset_url" -o "${ThisImgName}.zip"

    unzip "${ThisImgName}.zip"
    rm -f "${ThisImgName}.zip"
    dlf=$(find . -maxdepth 1 -name "lineage-*-r36s-android.img")
    mv "$dlf" "${ThisImgName}"
    sync
fi
