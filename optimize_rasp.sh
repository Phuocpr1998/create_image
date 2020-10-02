# parse options
while [ -n "$1" ]; do
	case "$1" in
		--hostname) export HOSTNAME="$2"; shift;;
		-*)
			echo "Invalid option: $1"
			exit 1
		;;
		*) break;;
	esac
	shift;
done


if [ -z "$HOSTNAME" ]
then
	echo "Missing hostname"
	exit 1
fi

# change timezone
echo "Asia/Ho_Chi_Minh" > /etc/timezone
ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
# change hostname
echo $HOSTNAME > /etc/hostname
echo "127.0.1.1    $HOSTNAME" > /etc/hosts

### sysctl

sed -i 's/vm.swappiness=.*$/vm.swappiness=5/g' /etc/sysctl.conf

if [ -z $(grep -w "vm.min_free_kbytes" /etc/sysctl.conf ) ]; then
    echo "vm.min_free_kbytes=262144" >> /etc/sysctl.conf
else
	sed -i 's/vm.min_free_kbytes=.*$/vm.min_free_kbytes=262144/g' /etc/sysctl.conf
fi

if [ -z $(grep -w "kernel.panic_on_rcu_stall" /etc/sysctl.conf ) ]; then
    echo "kernel.panic_on_rcu_stall=1" >> /etc/sysctl.conf
else
	sed -i 's/kernel.panic_on_rcu_stall=.*$/kernel.panic_on_rcu_stall=1/g' /etc/sysctl.conf
fi

if [ -z $(grep -w "kernel.panic_on_oops" /etc/sysctl.conf ) ]; then
    echo "kernel.panic_on_oops=1" >> /etc/sysctl.conf
else
	sed -i 's/kernel.panic_on_oops=.*$/kernel.panic_on_oops=1/g' /etc/sysctl.conf
fi

# Add ssh key
mkdir -p /home/pi/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8zBBG7a7fVxFyyOAigru08gtDYU2kwQ1ofuvhWKgHiq4/IGEdjXqSTVTh36tpJ3saG1DF5lHQMXF3aqS6Dzw7HVDVZi3N4XLUZ6XdaAXZ7a4RKQftCft2OOsgONBh63qYO7U7CgOzn7W+vyALszC1IcS9a+6oJFwOIqqiloUwnqQopgV1dy58Emmt4DpUrPc9fo7xGQJjnbT2sqHbwI9DkootJmhupOS98VBSVOyw4oPkxuqV3lbvJgMoKna/KIfCKRBEPO42nbMlYFMzB0yKuUFyY4inYRu4126LR12ODzVnD2QPfl1vSO3oXBLAi7xlZ747Z1obmEEdR+XuZ+XLC00I/XW0bJ1WX4DvJv9l/Mk0TPOFQFhJG7LGf69W7yLWKS7+NAcy5rn1CrXe1I4BLLC9Dr0b2Wwi6io1iOl92rkK3DUSttmgvu16eWOCUbu/Zu3OuULZMm3NnMtilVm8Rb7qzptTOAaSxZOQ2azSxqslvE0CHMC50kmOvA3WvqFV/eIwxE0xpzQOqkdyMTQnTRQPgfCfg9ifYo/+peH3h+D6G8x27+OKUgTdbnrprYo8zgxUwvEbgaSnb/IoZ/+Ah8iGHsFsc2LpERpY+76ChKSl9l5XMSbxkPKow0ctQ+IuRhVYqvq6+k0LXIlg3H2/LzhYKGYwks+v0Hy5Ck2YSQ== vcloudcamdev@vng.com.vn" > /home/pi/.ssh/authorized_keys
chmod 0644 /home/pi/.ssh/authorized_keys

# Enalble ssh from public key
sed -i "s/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
MergeParameter="publickey keyboard-interactive "
sed -i -n '/and ChallengeResponseAuthentication to/{p;:a;N;/UsePAM yes/!ba;s/.*\n/AuthenticationMethods '"$MergeParameter"'\n/};p' /etc/ssh/sshd_config
# Disable login ssh with password
sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
sed -i "s/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/" /etc/ssh/sshd_config
sed -i "s/^\@include common-auth/\#@include common-auth/" /etc/pam.d/sshd

# disable swap
sudo dphys-swapfile swapoff
sudo dphys-swapfile uninstall 
sudo update-rc.d dphys-swapfile disable

# install armbian-ramlog
cd /tmp
curl -Lo armbian-ramlog.tar.gz https://github.com/Phuocpr1998/armbian-ramlog/archive/master.tar.gz
tar xf armbian-ramlog.tar.gz
cd armbian-ramlog-master
chmod +x install.sh && sudo ./install.sh