#!/bin/bash
say "Post-installing dArkOSre (as ark) to ${imgname}"

sayin "copy firstrun script"
sudo cp "darkosre-firstrun.sh" "${BootDestMnt}/"
# firstboot.sh is for the multiboot side usually, but we'll keep it if it's there
[[ -f "firstboot.sh" ]] && sudo cp "firstboot.sh" "${BootDestMnt}/"

sayin "copy fstab"
sudo cp --remove-destination "darkosre.fstab" "${RootDestMnt}/etc/fstab"
sudo rm -f "${RootDestMnt}/etc/fstab.ntfs"
sudo cp "ez.service" "${RootDestMnt}/etc/systemd/system/ez.service"

sudo cp "ez.sh" "${RootDestMnt}/usr/local/sbin/ez.sh"
sudo chmod a+x "${RootDestMnt}/usr/local/sbin/ez.sh"

# Note: darkosre.fstab and other files should be in the 'ark' directory (previously 'darkosre')
# which we are currently in when this script runs (invoked from buildimg.sh)

sayin "cleanup mounts"
sync
sudo umount "${BootDestMnt}" || true
sudo umount "${RootDestMnt}" || true

# Note: The source image loop device cleanup is handled in install-os.sh
