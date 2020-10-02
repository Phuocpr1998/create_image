cd /tmp
wget http://mirrors.kernel.org/ubuntu/pool/main/c/cloud-initramfs-tools/overlayroot_0.40ubuntu1_all.deb
apt install busybox-static -y
dpkg -i overlayroot_0.40ubuntu1_all.deb
apt-get install -f -y
sed -i "s/overlayroot=\"\"*/overlayroot=\"tmpfs\"/" /etc/overlayroot.conf