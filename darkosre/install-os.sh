#!/bin/bash
set -e
say Installing darkosre to ${imgname}

npsz=$(cat bootsizereq)
sayin new $((npsz/1024))GiB partition
newpart $npsz fat darkosboot
ThisBootPartNum=${partcount}
BootDev=${LATEST_PART_DEV}
sayin new dev is ${BootDev} 

npsz=$(cat sizereq)
sayin new $((npsz/1024))GiB partition
newpart $npsz ext4 $OsName
ThisRootPartNum=${partcount}
RootDev=${LATEST_PART_DEV}
sayin new dev is ${RootDev} 

sayin setup mounts
darkosreBootMnt=${tmpmnts}/boot
darkosreRootMnt=${tmpmnts}/root
[[ ! -d "${darkosreBootMnt}" ]] && mkdir -p "${darkosreBootMnt}"
[[ ! -d "${darkosreRootMnt}" ]] && mkdir -p "${darkosreRootMnt}"

darkosrelodev=$(sudo losetup -f --show -P ${ThisImgName})

sudo mount ${darkosrelodev}p1 "${darkosreBootMnt}" || exit 1
sudo mount ${darkosrelodev}p2 "${darkosreRootMnt}" || exit 1
sync

BootDestMnt=${tmpmnts}/${imgname}-darkosreboot
sayin copy boot files to ${BootDestMnt}
sayin mount ${RootDev} "${BootDestMnt}"
mkdir -p "${BootDestMnt}" || exit 1
sudo mount ${BootDev} "${BootDestMnt}" || exit 1
sayin copy boot to ${imgname}
sudo rsync -aHAX --no-compress ${darkosreBootMnt}/ ${BootDestMnt} >/dev/null 2>&1
sudo mkdir ${BootDestMnt}/u-boot
sync

sayin copy boot files to ${ImgBootMnt}
sudo cp -R "boot.${OsName}.ini" "${ImgBootMnt}/"
ThisBootPartNumHex=$(printf '%x\n' ${ThisBootPartNum})
sudo sed -i "s|###bootPartNum###|${ThisBootPartNumHex}|g" "${ImgBootMnt}/boot.${OsName}.ini"

RootDestMnt=${tmpmnts}/${imgname}-darkosre
sayin mount ${RootDev} "${RootDestMnt}"
mkdir -p "${RootDestMnt}" || exit 1
sudo mount ${RootDev} "${RootDestMnt}" || exit 1
sayin copy root to ${imgname}
sudo rsync -aHAX --no-compress ${darkosreRootMnt}/ ${RootDestMnt} >/dev/null 2>&1
sync
