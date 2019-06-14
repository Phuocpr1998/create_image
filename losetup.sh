#!/bin/bash
sudo losetup -f vcc_opz_1.4.1.img
sudo kpartx -av /dev/loop30
mkdir /mnt/mount
sudo mount -t ext4 /dev/mapper/loop30p0 /mnt/mount

rm -rf hub-latest-linux-arm
wget "https://uvcloudcam:yUEq4Dy1=7SjPXkkd4Dydq3Q7RE0ukkdq3Q@repo.vcloudcam.vn/download/hub/hub-latest-linux-arm"
chmod +x hub-latest-linux-arm
cp hub-latest-linux-arm /mnt/tmp1/home/pi/hub/hub

rm -rf hub-controller-latest-linux-arm

wget "https://uvcloudcam:yUEq4Dy1=7SjPXkkd4Dydq3Q7RE0ukkdq3Q@repo.vcloudcam.vn/download/hub/hub-controller-latest-linux-arm"
chmod +x hub-controller-latest-linux-arm

cp hub-controller-latest-linux-arm /mnt/tmp1/home/pi/hub/hubctl

sudo umount /mnt/tmp1
sudo kpartx -dv /dev/loop30
sudo losetup -d /dev/loop30