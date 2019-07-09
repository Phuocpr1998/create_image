#!/bin/bash
apt-get install initramfs-tools -y
cd /tmp
wget "https://gist.githubusercontent.com/Phuocpr1998/bea3d54799a8e7b28df81e4277ee7fc5/raw/4b002a1fc37083b8c82315fdb55c72a3178a72d2/root-ro"
chmod +x root-ro
cp root-ro /etc/initramfs-tools/scripts/init-bottom/root-ro
echo "overlay" >> /etc/initramfs-tools/modules
mkinitramfs -o /boot/initrd
echo "root-ro-driver=overlay" >> /boot/cmdline.txt
echo "" >> /boot/config.txt
echo "initramfs initrd followkernel" >> /boot/config.txt
echo "" >> /boot/config.txt
echo "ramfsfile=initrd" >> /boot/config.txt
echo "" >> /boot/config.txt
echo "ramfsaddr=-1" >> /boot/config.txt