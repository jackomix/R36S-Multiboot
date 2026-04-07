#!/bin/bash
set -e
say Installing ark to ${imgname}

npsz=$(cat bootsizereq)
sayin new $((npsz/1024))GiB partition
newpart $npsz fat ${OsName}boot
ThisBootPartNum=${partcount}
BootDev=${ImgLodev}p${ThisBootPartNum}
sayin new dev is ${RootDev} 

npsz=$(cat sizereq)
sayin new $((npsz/1024))GiB partition
newpart $npsz ext4 $OsName
RootDev=${ImgLodev}p${partcount}
sayin new dev is ${RootDev} 

sayin setup mounts
arkBootMnt=${tmpmnts}/boot
arkRootMnt=${tmpmnts}/root
[[ ! -d "${arkBootMnt}" ]] && mkdir -p "${arkBootMnt}"
[[ ! -d "${arkRootMnt}" ]] && mkdir -p "${arkRootMnt}"

arklodev=$(losetup -f)
sudo losetup -P ${arklodev} ${ThisImgName}

sudo mount ${arklodev}p1 "${arkBootMnt}" || exit 1
sudo mount ${arklodev}p2 "${arkRootMnt}" || exit 1
sync

BootDestMnt=${tmpmnts}/${imgname}-arkboot
sayin copy boot files to ${BootDestMnt}
sayin mount ${RootDev} "${BootDestMnt}"
mkdir -p "${BootDestMnt}" || exit 1
sudo mount ${BootDev} "${BootDestMnt}" || exit 1
sayin copy boot to ${imgname}
sudo rsync -aHAX --no-compress ${arkBootMnt}/ ${BootDestMnt} >/dev/null 2>&1
sudo mkdir ${BootDestMnt}/u-boot
sync

sayin copy boot files to ${ImgBootMnt}
sudo cp -R "boot.${OsName}.ini" "${ImgBootMnt}/"
ThisBootPartNumHex=$(printf '%x\n' ${ThisBootPartNum})
sudo sed -i "s|###bootPartNum###|${ThisBootPartNumHex}|g" "${ImgBootMnt}/boot.${OsName}.ini"

# sudo cp "${arkBootMnt}/Image" "${ImgBootMnt}/"
# sudo cp "${arkBootMnt}/uInitrd" "${ImgBootMnt}/"

# sudo cp -R "boot.ark.ini" "${ImgBootMnt}/"

# sudo mkdir -p "${ImgBootMnt}/ark"
# for i in 0 1 2 3 4
# do
#     sudo mkdir -p "${ImgBootMnt}/ark/ScreenFiles/Panel $i"
#     sudo cp "${arkBootMnt}/ScreenFiles/Panel $i/rk3326-r35s-linux.dtb" "${ImgBootMnt}/ark/ScreenFiles/Panel $i"
# done

RootDestMnt=${tmpmnts}/${imgname}-ark
sayin mount ${RootDev} "${RootDestMnt}"
mkdir -p "${RootDestMnt}" || exit 1
sudo mount ${RootDev} "${RootDestMnt}" || exit 1
sayin copy root to ${imgname}
sudo rsync -aHAX --no-compress ${arkRootMnt}/ ${RootDestMnt} >/dev/null 2>&1
sync

