#!/bin/bash
[[ "$ghdebug" == "true" ]] && set -x

function check_deps {
    local DEPS_MISSING=0
    for cmd in aria2c whiptail jq parted mkfs.exfat; do
        if ! command -v $cmd >/dev/null 2>&1; then
            echo "Missing dependency: $cmd"
            DEPS_MISSING=1
        fi
    done

    if [[ $DEPS_MISSING -eq 1 ]]; then
        echo "Attempting to install missing dependencies..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update
            sudo apt-get install -y aria2 whiptail jq parted p7zip-full exfatprogs
        else
            echo "Please manually install the missing dependencies: aria2, whiptail, jq, parted, p7zip, exfatprogs"
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

    # Check for Windows-mounted drive (DrvFs)
    if pwd | grep -q "^/mnt/"; then
        echo -e "\e[1;33mWarning: You are running this from a Windows-mounted drive (/mnt/...). \e[0m"
        echo -e "\e[1;33mLoop devices in WSL often fail on NTFS/FAT drives with 'No such device or address'.\e[0m"
        echo -e "\e[1;33mIf this fails, please move the project to your Linux home directory (e.g., ~/r36smultiboot).\e[0m"
        echo
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

# --- TUI Configuration Phase ---

# Find available OSes (directories with get-image.sh or bootbutton)
AVAILABLE_OSES=()
for d in */ ; do
    if [[ -f "${d}get-image.sh" || -f "${d}bootbutton" ]]; then
        OS_NAME=$(basename "$d")
        AVAILABLE_OSES+=("$OS_NAME")
    fi
done

if [[ "$1" == "testoses" ]]; then
    SELECTED_OSES=("amberelec" "ark" "pan4elec" "rocknix" "uos")
elif [[ $# -gt 0 ]]; then
    SELECTED_OSES=("$@")
elif [[ ! -t 0 ]]; then
    # Non-interactive terminal with no args: default to standard OSes
    SELECTED_OSES=("andr36oid" "darkosre")
else
    # Whiptail Checklist for OS Selection
    CHECKLIST_ARGS=()
    for os in "${AVAILABLE_OSES[@]}"; do
        CHECKLIST_ARGS+=("$os" "Include $os" "OFF")
    done

    SELECTED_CSV=$(whiptail --title "R36S Multiboot Builder" \
        --checklist "Select the OSes to include in the image:" 20 60 12 \
        "${CHECKLIST_ARGS[@]}" 3>&1 1>&2 2>&3)

    if [[ -z "$SELECTED_CSV" ]]; then
        echo "No OS selected. Exiting."
        exit 0
    fi
    # Parse CSV into array (whiptail returns "os1" "os2")
    eval "SELECTED_OSES=($SELECTED_CSV)"
fi

# Define available buttons
BUTTONS=(
    "b12" "Up"
    "b13" "Down"
    "b15" "Right"
    "b14" "Left"
    "b7" "X (North)"
    "b6" "Y (West)"
    "b2" "A (East)"
    "b5" "B (South)"
    "d12" "Start (+)"
    "d9" "Select (-)"
)

# Configuration Phase for Buttons
if [[ $# -eq 0 && "$1" != "testoses" && -t 0 ]]; then
    for os in "${SELECTED_OSES[@]}"; do
        # Current button
        CURRENT_BTN="b7"
        if [[ -f "$os/bootbutton" ]]; then
            CURRENT_BTN=$(cat "$os/bootbutton" | tr -d '\r\n ')
        fi

        MENU_ARGS=()
        for ((i=0; i<${#BUTTONS[@]}; i+=2)); do
            if [[ "${BUTTONS[i]}" == "$CURRENT_BTN" ]]; then
                MENU_ARGS+=("${BUTTONS[i]}" "${BUTTONS[i+1]}" "ON")
            else
                MENU_ARGS+=("${BUTTONS[i]}" "${BUTTONS[i+1]}" "OFF")
            fi
        done

        SELECTED_BTN=$(whiptail --title "Button Configuration" \
            --radiolist "Select boot button for $os:" 20 60 12 \
            "${MENU_ARGS[@]}" 3>&1 1>&2 2>&3)

        if [[ -n "$SELECTED_BTN" ]]; then
            echo "$SELECTED_BTN" | tr -d '"\r\n' > "$os/bootbutton"
        fi
    done
fi

say "Building image with OSes: ${SELECTED_OSES[@]}"

# --- Build Phase ---

u=$(id -u)
g=$(id -g)
imgname=R36S-Multiboot

StartDir=$(pwd)
BuildingImgFullPath=${StartDir}/building.img
[[ -f "$BuildingImgFullPath" ]] && rm "$BuildingImgFullPath"

for mp in $(mount | grep "$(pwd)" |cut -d' ' -f1)
do
    sudo umount "${mp}" && echo "${mp} was still mounted" || exit 1
done

[[ -d tmp ]] && rm -rf tmp || true
[[ -d tmp ]] && exit 1

for ld in $(sudo losetup -a | grep "$(pwd)" |cut -d: -f1)
do
    echo
    sudo losetup -d ${ld} && echo "${ld} was still attached to an image" || exit 1
done

mkdir tmp

partcount=0
nextpartstart=16
bootsize=48
imgsizereq=32
storagesize=24

# shrink armbian sizes if building the big one
if [[ "$BuildImgEnv" == "github" ]]
then
    if echo "${SELECTED_OSES[@]}" | grep -qE "bookworm|jammy|noble|pluck"; then
        say "Building the big one, reducing size requirements"
        echo 5120 > bookworm/sizereq
    fi
fi

for arg in "${SELECTED_OSES[@]}"; do
    thissizereq=0
    if [[ -f "$arg/bootsizereq" ]]
    then
        thissizereq=$(cat "$arg/bootsizereq" | tr -d '\r\n ')
        imgsizereq=$((imgsizereq + thissizereq))
    fi
    if [[ -f "$arg/sizereq" ]]
    then
        thissizereq=$(cat "$arg/sizereq" | tr -d '\r\n ')
        imgsizereq=$((imgsizereq + thissizereq))
    fi
done

imgsizereq=$((storagesize + imgsizereq))
imgsize=$((bootsize + imgsizereq + 16))

echo "imgsize is $imgsize"
echo "bootsize is $bootsize"

set -e

say "make base image ${imgsize}MiB (sparse)"

# Use truncate instead of fallocate to create a sparse file (saves disk space in CI)
truncate -s ${imgsize}M ${BuildingImgFullPath}

# Use --show to get the device name while attaching
ImgLodev=$(sudo losetup -f --show -P ${BuildingImgFullPath})
echo "Attached to $ImgLodev"

function refreshBuildimg {
    sync
    echo "► refreshing partitions on ${ImgLodev}"
    sudo partprobe "${ImgLodev}" || true
    sudo udevadm settle || true
    sleep 2
}

function newpart {
    local start=$nextpartstart
    local partsize=$1
    local end=$((start + partsize))
    local ptype=notset
    echo "► create from ${start}MiB to ${end}MiB"
    [[ "$2" == "fat" ]] && local type=fat32 || true
    [[ "$2" == "ext4" ]] && local type=ext4 || true
    [[ "$2" == "exfat" ]] && local type=fat32 || true

    [[ $partcount == 0 ]] && ptype=primary || ptype=logical
    sudo parted -s ${ImgLodev} mkpart $ptype $type ${start}MiB ${end}MiB || true
    
    refreshBuildimg
    
    # Dynamically find the newest partition device
    local target_dev=$(lsblk -nlp -o NAME "${ImgLodev}" | tail -n 1)
    # Get just the number for partcount (e.g., from /dev/loop0p5 get 5)
    partcount=$(echo "${target_dev}" | grep -oP '\d+$' | tail -n 1)

    echo "► detected new partition: ${target_dev} (number: ${partcount})"

    nextpartstart=${end}
    [[ "$ptype" == "logical" ]] && nextpartstart=$((nextpartstart+1)) || true

    if [[ "$2" == "fat" ]]
    then
        # FAT labels are limited to 11 characters
        local fat_label="${3:-boot}"
        fat_label="${fat_label:0:11}"
        echo "► format as fat with label ${fat_label}"
        sudo mkfs.vfat -F 32 -n "${fat_label}" "${target_dev}"
    fi

    if [[ "$2" == "exfat" ]]
    then
        echo "► format as exfat with label ${3:-storage}"
        sudo mkfs.exfat ${3:+-L "$3"} "${target_dev}"
    fi

    if [[ "$2" == "ext4" ]]
    then
        echo "► format as ext4 with label ${3:-root}"
        sudo mkfs.ext4 ${3:+-L "$3"} "${target_dev}"
    fi
    sync
    [[ "$3" == "returndev" ]] && return "${target_dev}" || true
}

if [[ ! -d u-boot ]]
then
    say "get u-boot"
    mkdir u-boot
    cd u-boot
    wget https://github.com/R36S-Stuff/R36S-u-boot-builder/releases/download/v1/u-boot-r36s.tar
    cd ..
fi
cd u-boot
if [[ ! -f u-boot-r36s.tar ]]
then
    echo "u-boot-r36s.tar not found!"
    exit 1
fi
say "add uboot"
if [[ ! -d "sd_fuse" ]]
then
    mkdir sd_fuse
    tar xf u-boot-r36s.tar -C sd_fuse
fi
cd sd_fuse
chmod a+x ./sd_fusing.sh
./sd_fusing.sh ${ImgLodev} >/dev/null 2>&1
cd "${StartDir}"

say "create partition table"
sudo parted -s ${ImgLodev} mklabel msdos

say "create boot partition"
newpart ${bootsize} fat boot
ImgBootMnt="${StartDir}/tmp/boot.tmpmnt"
mkdir -p "${ImgBootMnt}"
sudo mount ${ImgLodev}p${partcount} "${ImgBootMnt}"
sleep 3

say "fill boot partition"
sudo cp -R commonbootfiles/* "${ImgBootMnt}"

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
        thisbtn=$(cat "$arg/bootbutton")
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

echo
cat "${ImgBootMnt}/boot.ini"

# Setup Extended partition
say "setup extended partition"
sudo parted -s ${ImgLodev} mkpart extended ${nextpartstart}MiB 100%
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
        echo
        [[ -f "./${step}.sh" ]] && echo "Start: ${OsName}: ${step}" || echo "skipping ${step}..."
        echo
        [[ -f "./${step}.sh" ]] && echo "source ./${step}.sh"  || continue
        echo
        source ./${step}.sh
        echo "End: ${OsName}: ${step}"
        echo
    done
    sync
    cd "${StartDir}"
done


say "create storage partition"
newpart 8 exfat EZSTORAGE
Storagemount="${StartDir}/tmp/storage.tmpmnt"

say "finalize image"
sync
sudo umount "${ImgBootMnt}"
[[ -d commonStoragefiles ]] && sudo umount "${Storagemount}" || true
sudo losetup -d ${ImgLodev}
sync

if [[ "$BuildImgEnv" == "github" ]]; then
    OutImgNameNoExt=${imgname}-$(echo "${SELECTED_OSES[@]}" |sed 's| |-|g')-$GH_build_date
else
    OutImgNameNoExt=${imgname}-$(echo "${SELECTED_OSES[@]}" |sed 's| |-|g')-$(TZ=America/New_York date +%Y-%m-%d-%H%M)
fi

OutImg=${StartDir}/${OutImgNameNoExt}.img
OutImgXZ=${StartDir}/${OutImgNameNoExt}.img.xz
OutImg7z=${StartDir}/${OutImgNameNoExt}.img.xz.7z

echo "${OutImg}"

mv ${BuildingImgFullPath} ${OutImg}
sync

if [[ "$BuildImgEnv" == "github" ]]
then
    fallocate --dig-holes ${OutImg}
    sayin "compressing with xz"
    xz -z -7 -T0 ${OutImg}
    sayin "splitting with 7z"
    7z a -mx9 -md512m -mfb273 -mmt2 -v2000m ${OutImg7z} ${OutImgXZ}
    ls ${StartDir}/${imgname}-*
fi

sync
