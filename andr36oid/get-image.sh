#!/bin/bash

# Fetch the latest lineage-*-r36s-android.img.zip from andr36oid/release_uploads
# Handling Git LFS: we need to get the file via the media-type header for large blobs
file_data=$(curl -s "https://api.github.com/repos/andr36oid/release_uploads/contents/" \
  | jq -r 'map(select(.name | test("r36s-android.img.zip$"))) | sort_by(.name) | reverse | .[0]')

asset_url=$(echo "$file_data" | jq -r '.download_url')
file_sha=$(echo "$file_data" | jq -r '.sha')

if [[ ! -f "${ThisImgName}" ]]
then
    if [[ -z "$asset_url" ]] || [[ "$asset_url" == "null" ]]; then
        echo "Error: Could not find latest Andr36oid image."
        exit 1
    fi
    
    echo "Downloading Andr36oid (LFS Handling)..."
    # To get the actual LFS file content from GitHub's raw link if it's LFS, 
    # we sometimes need to hit the Git Data API or use the specialized download link.
    # However, for large files in the repo root, the 'download_url' is usually correct 
    # IF we don't use the 'raw' prefix. We'll try the object API which is more robust for LFS.
    
    wget --header="Accept: application/vnd.github.v3.raw" \
         "https://api.github.com/repos/andr36oid/release_uploads/git/blobs/${file_sha}" \
         -O "${ThisImgName}.zip"

    # If the above fails (blobs have a size limit), we fall back to the LFS-aware download
    if [[ $(stat -c%s "${ThisImgName}.zip") -lt 1000 ]]; then
        echo "Blob API limit reached or failed. Trying direct LFS download..."
        # This is a trick to get the real LFS file from GitHub
        curl -L "https://github.com/andr36oid/release_uploads/raw/main/$(echo "$file_data" | jq -r '.name')" -o "${ThisImgName}.zip"
    fi

    unzip "${ThisImgName}.zip"
    rm -f "${ThisImgName}.zip"
    dlf=$(find -name "lineage-*-r36s-android.img")
    mv $dlf "${ThisImgName}"
    sync
fi