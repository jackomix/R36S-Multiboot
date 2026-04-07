#!/bin/bash

if [[ ! "$1" == "justEZ2" ]]
then
    echo -ne "Setting up EZSTORAGE" >>/dev/tty1
    /bin/bash /boot/u-boot/setup-ezstorage.sh ark /roms /EZSTORAGE || exit 1
fi

IntDev=$(mount |grep "/boot "| cut -d' ' -f1 | cut -dp -f1)

[[ $IntDev == "/dev/mmcblk0" ]] && ExtDev=/dev/mmcblk1
[[ $IntDev == "/dev/mmcblk1" ]] && ExtDev=/dev/mmcblk0

export EZSTwoDevPart=$(blkid |grep EZSTORAGE2 | grep $ExtDev |cut -d: -f1)

if [[ -n "$EZSTwoDevPart" ]]
then
    [[ ! -d /EZSTORAGE2 ]] && mkdir /EZSTORAGE2
    if mount /EZSTORAGE2
    then
        echo -ne "Setting up EZSTORAGE2" >>/dev/tty1
        /bin/bash /boot/u-boot/setup-ezstorage.sh ark /roms2 /EZSTORAGE2 || exit 1
    fi
fi

exit 0