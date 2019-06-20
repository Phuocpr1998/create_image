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

### armbian config
#disable zram
sed -i 's|ENABLED=true|# ENABLED=true|g' /etc/default/armbian-zram-config
#setting ramlog
sed -i 's|ENABLED=true|# ENABLED=true|g' /etc/default/armbian-ramlog
sed -i 's/SIZE=.*$/SIZE=10M/g' /etc/default/armbian-ramlog
sed -i 's|USE_RSYNC=true|# USE_RSYNC=true|g' /etc/default/armbian-ramlog

### cron config
rm -rf /etc/cron.d/armbian-updates /etc/cron.d/sysstat /etc/cron.daily/apt-compat /etc/cron.daily/aptitude /etc/cron.daily/bsdmainutils /etc/cron.daily/dpkg /etc/cron.daily/man-db /etc/cron.daily/sysstat /etc/cron.weekly/fstrim /etc/cron.weekly/man-db
rm -rf /etc/cron.daily/logrotate
sed -i 's|    /usr/sbin/logrotate|    # /usr/sbin/logrotate|g' /usr/lib/armbian/armbian-truncate-logs

### apt config

sed -i 's|APT::Periodic::Enable "1";|APT::Periodic::Enable "0";|g' /etc/apt/apt.conf.d/02-armbian-periodic
sed -i 's|APT::Periodic::Update-Package-Lists "1";|APT::Periodic::Update-Package-Lists "0";|g' /etc/apt/apt.conf.d/02-armbian-periodic
sed -i 's|APT::Periodic::Update-Package-Lists "21";|APT::Periodic::Update-Package-Lists "0";|g' /etc/apt/apt.conf.d/02-armbian-periodic
sed -i 's|APT::Periodic::Download-Upgradeable-Packages "1";|APT::Periodic::Download-Upgradeable-Packages "0";|g' /etc/apt/apt.conf.d/02-armbian-periodic
sed -i 's|APT::Periodic::Unattended-Upgrade "1";|APT::Periodic::Unattended-Upgrade "0";|g' /etc/apt/apt.conf.d/02-armbian-periodic


sed -i 's|APT::Periodic::Unattended-Upgrade "1";|APT::Periodic::Unattended-Upgrade "0";|g' /etc/apt/apt.conf.d/20auto-upgrades
sed -i 's|APT::Periodic::Update-Package-Lists "1";|APT::Periodic::Update-Package-Lists "0";|g' /etc/apt/apt.conf.d/20auto-upgrades

### sysctl

sed -i 's/vm.swappiness=.*$/vm.swappiness=5/g' /etc/sysctl.conf

if [ -z $(grep -w "vm.min_free_kbytes" /etc/sysctl.conf ) ]; then
    echo "vm.min_free_kbytes=65536" >> /etc/sysctl.conf
else
	sed -i 's/vm.min_free_kbytes=.*$/vm.min_free_kbytes=65536/g' /etc/sysctl.conf
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

#sed -i 's/vm.min_free_kbytes=.*$/vm.min_free_kbytes=32768/g' /etc/sysctl.conf

echo "blacklist xradio_wlan" > /etc/modprobe.d/xradio_wlan.conf

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

### disable service
systemctl stop apt-daily.timer
systemctl disable apt-daily.timer
systemctl mask apt-daily.timer

systemctl stop apt-daily-upgrade.timer
systemctl disable apt-daily-upgrade.timer
systemctl mask apt-daily-upgrade.timer

systemctl stop apt-daily.service
systemctl disable apt-daily.service
systemctl mask apt-daily.service


systemctl stop apt-daily-upgrade.service
systemctl disable apt-daily-upgrade.service
systemctl mask apt-daily-upgrade.service

systemctl stop rsync.service
systemctl disable rsync.service
systemctl mask rsync.service

systemctl stop rsync.service
systemctl disable rsync.service
systemctl mask rsync.service

systemctl stop unattended-upgrades.service
systemctl mask unattended-upgrades.service
apt remove -y unattended-upgrades