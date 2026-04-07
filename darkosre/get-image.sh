#!/bin/bash

# --- dArkOSre (March 2026) ---
OS_NAME="darkosre"
IMAGE_NAME="dArkOSRE_R36_trixie_03082026.img"
MEGA_URL="https://mega.nz/file/k6AgTSTS#RrMGot_xVXyzAr5h_7RDNKFIv2GaKniLYliLSPA3UWc"
GDRIVE_ID="1ONnNxR3cpGAC0d5YefS-xE-Hp1ph7Hm-"

if [[ -f "../${IMAGE_NAME}" ]]; then
    echo "Using local image: ${IMAGE_NAME}"
    cp "../${IMAGE_NAME}" .
else
    echo "Downloading ${OS_NAME}..."
    if command -v megadl >/dev/null 2>&1; then
        megadl "${MEGA_URL}" --path .
    else
        echo "megadl not found, trying Google Drive..."
        # Using a simple wget strategy for GDrive files (works for public files under 100MB usually, 
        # but for larger ones we need to handle the confirmation cookie)
        wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id='${GDRIVE_ID} -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=${GDRIVE_ID}" -O "${IMAGE_NAME}" && rm -rf /tmp/cookies.txt
    fi
fi

if [[ ! -f "${IMAGE_NAME}" ]]; then
    echo "Error: Failed to download ${IMAGE_NAME}"
    exit 1
fi

echo "Image downloaded: ${IMAGE_NAME}"
