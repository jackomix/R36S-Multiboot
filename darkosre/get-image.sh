#!/bin/bash

# --- dArkOSre (March 2026) ---
OS_NAME="darkosre"
# install-os.sh expects $ThisImgName which buildimg.sh sets to ${OsName}.img
TARGET_IMG="${OS_NAME}.img"
IMAGE_NAME="dArkOSRE_R36_trixie_03082026.img"
MEGA_URL="https://mega.nz/file/k6AgTSTS#RrMGot_xVXyzAr5h_7RDNKFIv2GaKniLYliLSPA3UWc"
GDRIVE_ID="1ONnNxR3cpGAC0d5YefS-xE-Hp1ph7Hm-"

if [[ -f "../${IMAGE_NAME}" ]]; then
    echo "Using local image: ${IMAGE_NAME}"
    cp "../${IMAGE_NAME}" "${TARGET_IMG}"
else
    echo "Downloading ${OS_NAME}..."
    if command -v megadl >/dev/null 2>&1; then
        megadl "${MEGA_URL}" --path .
    else
        echo "megadl not found, trying Google Drive..."
        wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id='${GDRIVE_ID} -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=${GDRIVE_ID}" -O "${IMAGE_NAME}.7z" && rm -rf /tmp/cookies.txt
    fi
fi

# Extract if needed
if [[ -f "${IMAGE_NAME}.7z" ]]; then
    echo "Extracting 7z..."
    7z x "${IMAGE_NAME}.7z" -y
    rm "${IMAGE_NAME}.7z"
elif [[ -f "dArkOSRE_R36_trixie_03082026.7z" ]]; then
    echo "Extracting 7z..."
    7z x "dArkOSRE_R36_trixie_03082026.7z" -y
    rm "dArkOSRE_R36_trixie_03082026.7z"
fi

# Rename to the target name expected by buildimg.sh/install-os.sh
if [[ -f "${IMAGE_NAME}" ]]; then
    mv "${IMAGE_NAME}" "${TARGET_IMG}"
fi

if [[ ! -f "${TARGET_IMG}" ]]; then
    # Fallback: check if it extracted with a slightly different name
    EXTRACTED=$(ls *.img 2>/dev/null | grep -v "${TARGET_IMG}" | head -n 1)
    if [[ -n "$EXTRACTED" ]]; then
        mv "$EXTRACTED" "${TARGET_IMG}"
    fi
fi

if [[ ! -f "${TARGET_IMG}" ]]; then
    echo "Error: Failed to find target image ${TARGET_IMG}"
    ls -la
    exit 1
fi

echo "Image ready: ${TARGET_IMG}"
