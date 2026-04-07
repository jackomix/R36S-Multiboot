#!/bin/bash

if [[ ! -f "$ThisImgName" ]]
then
    ArkOSdl=https://github.com/AeolusUX/ArkOS-R3XS/releases/download/ArkOS.V2.0.06302025/ArkOS_R35S-R36S_v2.0_06302025_MultiPanel.img.7z
    [[ -f "ArkOS_R35S-R36S.img.7z.001" ]] && rm ArkOS_R35S-R36S.img.7z.001 || echo >/dev/null 2>&1
    [[ -f "ArkOS_R35S-R36S.img.7z" ]] && rm ArkOS_R35S-R36S.img.7z || echo >/dev/null 2>&1
    [[ -f "ArkOS_R35S-R36S.img" ]] && rm ArkOS_R35S-R36S.img || echo >/dev/null 2>&1
    rm ArkOS_R35S-R36S_*.img || true
    ArkOSdl1=${ArkOSdl}.001
    #echo $ArkOSdl1
    echo "Downloading ArkOS R35S-R36S image..."
    wget --no-verbose --quiet -OArkOS_R35S-R36S.img.7z.001 "$ArkOSdl1"

    [[ -f "ArkOS_R35S-R36S.img.7z.002" ]] && rm ArkOS_R35S-R36S.img.7z.002
    ArkOSdl2=${ArkOSdl}.002
    #echo $ArkOSdl2
    wget --no-verbose --quiet -OArkOS_R35S-R36S.img.7z.002 "$ArkOSdl2"
    7z x -aoa ArkOS_R35S-R36S.img.7z.001
    rm ArkOS_R35S-R36S.img.7z.001 ArkOS_R35S-R36S.img.7z.002
    sync
    arkImg=$(find . |grep "ArkOS_R35S-R36S")
    unxz -T0 --force --decompress $arkImg
    arkImg=$(find . |grep "ArkOS_R35S-R36S")
    mv ${arkImg} ${ThisImgName}
fi
