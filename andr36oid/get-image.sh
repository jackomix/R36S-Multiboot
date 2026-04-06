#!/bin/bash

# Fetch the latest lineage-*-r36s-android.img.zip from the root of andr36oid/release_uploads
asset_url=$(curl -s "https://api.github.com/repos/andr36oid/release_uploads/contents/" \
  | jq -r '[.[]] | select(.name | test("r36s-android.img.zip$")) | sort_by(.name) | reverse | .[0].download_url' \
  | head -n 1)

if [[ ! -f "${ThisImgName}" ]]
then
    if [[ -z "$asset_url" ]] || [[ "$asset_url" == "null" ]]; then
        echo "Error: Could not find latest Andr36oid image."
        exit 1
    fi
    echo "Downloading Andr36oid: ${asset_url}"
    wget "$asset_url" -O"${ThisImgName}.zip"
    unzip "${ThisImgName}.zip"
    rm -f "${ThisImgName}.zip"
    dlf=$(find -name "lineage-*-r36s-android.img")
    mv $dlf "${ThisImgName}"
    sync
fi