#!/bin/bash
[[ "$ghdebug" == "true" ]] && set -x

function check_deps {
    local DEPS_MISSING=0
    for cmd in aria2c whiptail jq parted mkfs.exfat kpartx; do
        if ! command -v $cmd >/dev/null 2>&1; then
            echo "Missing dependency: $cmd"
            DEPS_MISSING=1
        fi
    done
    
    if [[ $DEPS_MISSING -eq 1 ]]; then
        echo "Attempting to install missing dependencies..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update
            sudo apt-get install -y aria2 whiptail jq parted p7zip-full exfatprogs kpartx
        else
            echo "Please manually install the missing dependencies: aria2, whiptail, jq, parted, p7zip, exfatprogs, kpartx"
            exit 1
        fi
    fi

    # WSL Loop Device check/init
    if [[ ! -e /dev/loop0 ]]; then
        echo "Initializing loop devices for WSL..."
        sudo modprobe loop 2>/dev/null || true
        for i in {0..7}; do
            if [[ ! -e /dev/loop$i ]]; then
                sudo mknod /dev/loop$i b 7 $i 2>/dev/null || true
            fi
        done
    fi
}

check_deps

function say {
    echo
    echo -e "\e[1;32m$@\e[0m"
}
function sayin {
    echo -e "\e[1;34m► $@\e[0m"
}

# --- OS Selection ---
if [[ "$1" == "testoses" ]]; then
    SELECTED_OSES=("amberelec" "ark" "pan4elec" "rocknix" "uos")
elif [[ $# -gt 0 ]]; then
    SELECTED_OSES=("$@")
else
    echo "No OS selected. Usage: ./buildimg.sh andr36oid darkosre"
    exit 1
fi

say "Building image with OSes: ${SELECTED_OSES[@]}"

# --- Build Phase ---

PART_INDEX=0

function refreshBuildimg {
    sync
    echo "► refreshing partition maps with kpartx"
    sudo kpartx -av "${BuildingImgFullPath}" || true
    sudo udevadm settle || true
}

function newpart {
    local start=$nextpartstart
    local partsize=$1
    local ptype
    
    if [[ $PART_INDEX -eq 0 ]]; then
        ptype=primary
        PART_INDEX=1
    else
        ptype=logical
        # Add 1MiB offset for Logical partitions
        start=$((start + 1))
        if [[ $PART_INDEX -lt 5 ]]; then
            PART_INDEX=5
        else
            PART_INDEX=$((PART_INDEX + 1))
        fi
    fi

    local end=$((start + partsize))
    echo "► creating partition ${PART_INDEX} (${ptype}) from ${start}MiB to ${end}MiB"
    [[ "$2" == "fat" ]] && local type=fat32 || local type=$2
    [[ "$2" == "exfat" ]] && type=fat32

    sudo parted -s "${BuildingImgFullPath}" mkpart $ptype $type ${start}MiB ${end}MiB || true
    refreshBuildimg
    
    local loop_base=$(basename "${ImgLodev}")
    local target_dev="/dev/mapper/${loop_base}p${PART_INDEX}"
    
    # Export for sourced scripts
    partcount=$PART_INDEX
    LATEST_PART_DEV=$target_dev

    # Wait for device node
    for i in {1..10}; do
        if [[ -e "${target_dev}" ]]; then break; fi
        sudo kpartx -av "${BuildingImgFullPath}" >/dev/null
        sleep 1
    done

    echo "► formatting ${target_dev}"
    nextpartstart=${end}

    if [[ "$2" == "fat" ]]
    then
        local fat_label="${3:-boot}"
        sudo mkfs.vfat -F 32 -n "${fat_label}" "${target_dev}"
    fi

    if [[ "$2" == "exfat" ]]
    then
        sudo mkfs.exfat -L "${3:-storage}" "${target_dev}"
    fi

    if [[ "$2" == "ext4" ]]
    then
        sudo mkfs.ext4 -L "${3:-root}" "${target_dev}"
    fi
    sync
}

u=$(id -u)
g=$(id -g)
imgname=R36S-Multiboot

StartDir=$(pwd)
BuildingImgFullPath=${StartDir}/building.img
[[ -f "$BuildingImgFullPath" ]] && rm "$BuildingImgFullPath"

for mp in $(mount | grep "$(pwd)" |cut -d' ' -f1)
do
    sudo umount "${mp}" || true
done

mkdir -p tmp

nextpartstart=16
bootsize=48
imgsizereq=32
storagesize=24

for arg in "${SELECTED_OSES[@]}"; do
    thissizereq=0
    [[ -f "$arg/bootsizereq" ]] && thissizereq=$(cat "$arg/bootsizereq" | tr -d '\r\n ') && imgsizereq=$((imgsizereq + thissizereq))
    [[ -f "$arg/sizereq" ]] && thissizereq=$(cat "$arg/sizereq" | tr -d '\r\n ') && imgsizereq=$((imgsizereq + thissizereq))
done

imgsizereq=$((storagesize + imgsizereq))
imgsize=$((bootsize + imgsizereq + 128))

say "make base image ${imgsize}MiB"
truncate -s ${imgsize}M ${BuildingImgFullPath}

ImgLodev=$(sudo losetup -f --show ${BuildingImgFullPath})

if [[ ! -d u-boot ]]
then
    mkdir u-boot
    cd u-boot
    wget https://github.com/R36S-Stuff/R36S-u-boot-builder/releases/download/v1/u-boot-r36s.tar
    cd ..
fi
cd u-boot
if [[ ! -d "sd_fuse" ]]
then
    mkdir sd_fuse
    tar xf u-boot-r36s.tar -C sd_fuse
fi
cd sd_fuse
sudo ./sd_fusing.sh ${ImgLodev} >/dev/null 2>&1
cd "${StartDir}"

sudo parted -s "${BuildingImgFullPath}" mklabel msdos

say "create boot partition"
newpart ${bootsize} fat boot
ImgBootMnt="${StartDir}/tmp/boot.tmpmnt"
mkdir -p "${ImgBootMnt}"
loop_base=$(basename "${ImgLodev}")
sudo mount "/dev/mapper/${loop_base}p1" "${ImgBootMnt}"

say "fill boot partition"
sudo cp -R commonbootfiles/* "${ImgBootMnt}/"
sudo cp "${StartDir}/EZ/EZStorage_all.tar" "${ImgBootMnt}/EZStorage_all.tar"
sudo cp "${StartDir}/EZ/setup-ezstorage.sh" "${ImgBootMnt}/setup-ezstorage.sh"

function bootiniadd {
    echo "$@" | sudo tee --append "${ImgBootMnt}/boot.ini" >/dev/null
}

bootiniadd odroidgoa-uboot-config
bootiniadd ""
bootiniadd "setenv boot2 ${SELECTED_OSES[0]}"
bootiniadd ""
bootiniadd 'if env exist Stickyboot2'
bootiniadd 'then'
bootiniadd '    setenv boot2 ${Stickyboot2}'
bootiniadd 'fi'
bootiniadd ""
for arg in "${SELECTED_OSES[@]}"; do
    if [[ -f "$arg/bootbutton" ]]; then
        thisbtn=$(cat "$arg/bootbutton" | tr -d '\r\n ')
        bootiniadd "if gpio input $thisbtn"
        bootiniadd "then"
        bootiniadd "    setenv boot2 $arg"
        bootiniadd "fi"
        bootiniadd ""
    fi
done

bootiniadd 'if gpio input c4'
bootiniadd 'then'
bootiniadd '    setenv Stickyboot2 ${boot2}'
bootiniadd '    saveenv'
bootiniadd 'fi'
bootiniadd ""
bootiniadd 'echo booting ${boot2}'
bootiniadd 'mw.b 0x00800800 0 0x1000'
bootiniadd 'load mmc 1:1 0x00800800 boot.${boot2}.ini'
bootiniadd source 0x00800800

sudo parted -s "${BuildingImgFullPath}" mkpart extended ${nextpartstart}MiB 100%
refreshBuildimg

for arg in "${SELECTED_OSES[@]}"; do
    OsName=${arg}
    ThisImgName=${OsName}.img
    tmpmnts="${StartDir}/tmp/${OsName}.tmpmnts"
    mkdir -p "$tmpmnts"
    OSDir="${StartDir}/${OsName}"
    cd "${OSDir}"
    chmod a+x ./*.sh
    for step in get-image pre-install install-os post-install
    do
        [[ -f "./${step}.sh" ]] && source ./${step}.sh || true
    done
    sync
    cd "${StartDir}"
done

say "create storage partition"
newpart 8 exfat EZSTORAGE

say "finalize image"
sync
sudo umount "${ImgBootMnt}" || true
sudo kpartx -dv "${BuildingImgFullPath}" || true
sudo losetup -d "${ImgLodev}" || true

if [[ "$BuildImgEnv" == "github" ]]; then
    OutImgNameNoExt=${imgname}-$(echo "${SELECTED_OSES[@]}" |sed 's| |-|g')-$GH_build_date
else
    OutImgNameNoExt=${imgname}-$(echo "${SELECTED_OSES[@]}" |sed 's| |-|g')-$(TZ=America/New_York date +%Y-%m-%d-%H%M)
fi

OutImg=${StartDir}/${OutImgNameNoExt}.img
OutImgXZ=${StartDir}/${OutImgNameNoExt}.img.xz
OutImg7z=${StartDir}/${OutImgNameNoExt}.img.xz.7z

mv "${BuildingImgFullPath}" "${OutImg}"
sync

if [[ "$BuildImgEnv" == "github" ]]
then
    fallocate --dig-holes "${OutImg}"
    xz -z -1 -T0 "${OutImg}"
    7z a -mx0 -v2000m "${OutImg7z}" "${OutImgXZ}"
fi
sync
