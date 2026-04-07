#!/bin/bash
say Post-installing ark to ${imgname}

sayin copy firstrun script
sudo cp -vL "firstboot.sh" "${BootDestMnt}"
sudo cp "ark-firstrun.sh" "${BootDestMnt}"
# sudo cp -vL umount-ez.sh "${BootDestMnt}"

sayin copy fstab
sudo cp -vL --remove-destination "ark.fstab" "${RootDestMnt}/etc/fstab"
sudo rm -f "${RootDestMnt}/etc/fstab.ntfs"
sudo cp -vL "ez.service" "${RootDestMnt}/etc/systemd/system/ez.service"
#sudo ln -s "/etc/systemd/system/ez.service" "${RootDestMnt}/etc/systemd/system/multi-user.target.wants/ez.service"

sudo cp -v "ez.sh" "${RootDestMnt}/usr/local/sbin/ez.sh"
sudo chmod a+x "${RootDestMnt}/usr/local/sbin/ez.sh"

cat << EOF | sudo tee "${RootDestMnt}/etc/udev/rules.d/95-udevil-mount.rules" >/dev/null 2>&1
# dont run in "installer" mode
IMPORT{cmdline}="installer"
ENV{installer}=="1", GOTO="exit"

# check for blockdevices, /dev/sd*, /dev/sr* and /dev/mmc*
SUBSYSTEM!="block", KERNEL!="sd*|sr*|mmc*", GOTO="exit"

# check for ez2
IMPORT{builtin}="blkid"
ENV{ID_FS_LABEL}=="EZSTORAGE2", GOTO="eztwo"
GOTO="exit"

# mount EZStorage2
LABEL="eztwo"
ACTION=="add", PROGRAM="/usr/bin/sh -c '/usr/bin/grep -E ^/dev/%k\  /proc/mounts || true'", RESULT=="", RUN+="/usr/bin/bash /usr/local/sbin/ez.sh justEZ2"
GOTO="exit"

# Exit
LABEL="exit"
EOF








sayin cleanup mounts and img dev
sync
sleep 5
sudo umount ${arklodev}p1
sudo umount ${arklodev}p2
sudo umount ${BootDev}
sudo umount ${RootDev}

sync
sudo losetup -d ${arklodev}

[[ "$BuildImgEnv" == "github" ]] && rm ${ThisImgName} || sayin keep ${ThisImgName}