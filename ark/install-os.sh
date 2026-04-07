#!/bin/bash
set -e
say "Installing dArkOSre (as ark) to ${imgname}"

npsz=$(cat bootsizereq)
sayin "new $((npsz/1024))GiB partition"
newpart $npsz fat arkboot
ThisBootPartNum=${partcount}
BootDev=${LATEST_PART_DEV}
sayin "new dev is ${BootDev}"

npsz=$(cat sizereq)
sayin "new $((npsz/1024))GiB partition"
newpart $npsz ext4 ark
ThisRootPartNum=${partcount}
RootDev=${LATEST_PART_DEV}
sayin "new dev is ${RootDev}"

sayin "setup mounts"
arkBootMnt=${tmpmnts}/boot
arkRootMnt=${tmpmnts}/root
[[ ! -d "${arkBootMnt}" ]] && mkdir -p "${arkBootMnt}"
[[ ! -d "${arkRootMnt}" ]] && mkdir -p "${arkRootMnt}"

# The get-image.sh now renames dArkOSRE to ark.img
ThisImgName="ark.img"
arklodev=$(sudo losetup -f --show -P ${ThisImgName})

sudo mount ${arklodev}p1 "${arkBootMnt}" || exit 1
sudo mount ${arklodev}p2 "${arkRootMnt}" || exit 1
sync

BootDestMnt=${tmpmnts}/${imgname}-arkboot
sayin "copy boot files to ${BootDestMnt}"
mkdir -p "${BootDestMnt}" || exit 1
sudo mount ${BootDev} "${BootDestMnt}" || exit 1
sayin "copy boot to ${imgname}"
sudo rsync -aHAX --no-compress ${arkBootMnt}/ ${BootDestMnt} >/dev/null 2>&1
sudo mkdir -p ${BootDestMnt}/u-boot
sync

sayin "copy boot files to ${ImgBootMnt}"
sudo cp -R "boot.ark.ini" "${ImgBootMnt}/"
ThisBootPartNumHex=$(printf '%x\n' ${ThisBootPartNum})
sudo sed -i "s|###bootPartNum###|${ThisBootPartNumHex}|g" "${ImgBootMnt}/boot.ark.ini"

RootDestMnt=${tmpmnts}/${imgname}-ark
sayin "mount ${RootDev} ${RootDestMnt}"
mkdir -p "${RootDestMnt}" || exit 1
sudo mount ${RootDev} "${RootDestMnt}" || exit 1
sayin "copy root to ${imgname}"
sudo rsync -aHAX --no-compress ${arkRootMnt}/ ${RootDestMnt} >/dev/null 2>&1
sync

# Cleanup loop for the source image
sudo umount "${arkBootMnt}" || true
sudo umount "${arkRootMnt}" || true
sudo losetup -d "${arklodev}" || true
