#!/bin/bash

[[ -f /EZSTORAGE/.DontModify/storagewasexpanded ]] && notExpanded=0 || notExpanded=1

sudo chmod 666 /dev/tty1
export TERM=linux
height="15"
width="55"
sudo setfont /usr/share/consolefonts/Lat7-Terminus20x10.psf.gz
height="20"
width="60"

# [ $notExpanded -eq 1 ] && \
#   dialog --infobox "debug expand file found" $height $width 2>&1 > /dev/tty1 || \
#   dialog --infobox "debug expand file not found" $height $width 2>&1 > /dev/tty1
# sleep 15

export EZSDevPart=$(sudo blkid |grep EZSTORAGE | grep -v EZSTORAGE2 |cut -d: -f1)
export EZSPartNum=$(echo ${EZSDevPart} | cut -dp -f2)
export EZSDev=$(echo ${EZSDevPart} | cut -dp -f1)
echo EZSTORAGE partition device is ${EZSDevPart};echo EZSTORAGE device is ${EZSDev} ;echo EZSTORAGE partition number is ${EZSPartNum}

if [ $notExpanded -eq 1 ]
then
  /bin/bash /boot/u-boot/umount-ez.sh

  if [ ! -f /boot/doneit ]; then
    sudo echo ", +" | sudo sfdisk -N 2 --force ${EZSDev}
    sudo echo ", +" | sudo sfdisk -N ${EZSPartNum} --force ${EZSDev}
    sudo touch "/boot/doneit"
    sleep 10
    dialog --infobox "EASYSTORAGE expansion in progress...\n  The device will now reboot to continue the process..." $height $width 2>&1 > /dev/tty1
    sleep 5
    sudo reboot
  fi

  mkfs.exfat -n EZSTORAGE ${EZSDevPart} || sleep 300
  sync
  sleep 10
  sudo mount -w ${EZSDevPart} /EZSTORAGE
  exitcode=$?
  sleep 10
  mkdir /EZSTORAGE/.DontModify
  sudo touch "/EZSTORAGE/.DontModify/storagewasexpanded"

fi

[[ -z "$exitcode" ]] && exitcode=0

sudo sed -i 's|##pre-firstrun##||' /etc/fstab
sudo mount -a
sleep 2
sudo systemctl start ez.service
sleep 5
mount

sudo tar --no-same-permissions --no-same-owner -xvf /roms.tar -C /
sync

sudo rm -rf -v /roms/themes/es-theme-nes-box/
sudo mv -f -v /tempthemes/* /roms/themes
sync
sleep 1
sudo rm -rf -v /tempthemes

sudo rm -f /boot/doneit*

sudo rm -f /boot/fstab.*

sudo systemctl enable ssh
if [ $exitcode -eq 0 ]; then
  dialog --infobox "Completed expansion of EZSTORAGE. The system will now reboot" $height $width 2>&1 > /dev/tty1 | sleep 10
  systemctl disable firstboot.service
  sudo systemctl disable firstboot.service
  sudo systemctl enable ez.service
  #sudo rm -v /boot/ark/firstboot.sh
  #sudo rm -v /boot/ark-firstrun.sh
  sudo mv /boot/ark/firstboot.sh{,.ran}
  #sudo rm -v -- "$0"
  sleep 5
  reboot
else
  dialog --infobox "EZSTORAGE partition expansion failed for an unknown reason.  Please expand the partition using an alternative tool such as Minitool Partition Wizard.  System will reboot and load ArkOS now." $height $width 2>&1 > /dev/tty1 | sleep 10
  systemctl disable firstboot.service
  sudo systemctl disable firstboot.service
  #sudo rm -v /boot/ark/firstboot.sh
  sudo mv /boot/ark/firstboot.sh{,.failed}
  #sudo rm -v -- "$0"
  reboot
fi
