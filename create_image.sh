#!/bin/bash
# ./create_image.sh --versionhub 1.2.3 --versionhubctl 1.0.12 --model OPZPLUS512 --interface eth0 --server "http:\/\/api.dev.vcloudcam.vn" --runmode staging --agency vcc

# where is mount image
PATH=mount

while [ -n "$1" ]; do
	case "$1" in
		--versionhub) export VERSIONHUB="$2"; shift;;
		--versionhubctl) export VERSIONHUBCTL="$2"; shift;;
		--model) export MODEL="$2"; shift;;
		--runmode) export RUN="$2"; shift;;
		--agency) export AGENCY="$2"; shift;;
		--server) export SERVER="$2"; shift;;
		--interface) export INTERFACE="$2"; shift;;
		--arch) export ARCH="$2"; shift;;
		-*)
			echo "Invalid option: $1"
			exit 1
		;;
		*) break;;
	esac
	shift;
done


if [ -z "$VERSIONHUB" ]
then
	echo "Missing hub version"
	exit 1
fi

if [ -z "$VERSIONHUBCTL" ]
then
	echo "Missing hubctl version"
	exit 1
fi

if [ -z "$MODEL" ]
then
	echo "Missing model"
	exit 1
fi

if [ -z "$AGENCY" ]
then
	echo "Missing agency"
	exit 1
fi

if [ -z "$SERVER" ]
then
	echo "Missing server"
	exit 1
fi

if [ -z "$INTERFACE" ]
then
	echo "Missing interface"
	exit 1
fi

if [ -z "$RUN" ]
then
	echo "Missing runmode"
	exit 1
fi

if [ -z "$ARCH" ]
then
	ARCH="arm"
fi


# change timezone
echo "==Change timezone"
echo "Asia/Ho_Chi_Minh" | /usr/bin/tee $PATH/etc/timezone
/bin/ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh $PATH/etc/localtime
# change hostname
echo "==Change hostname"
echo "vccoppcplus" | /usr/bin/tee $PATH/etc/hostname

# change armbian-log and rotate log
echo "==Change armbian-log config"
/bin/sed -i "s/^#\?SIZE=.*/SIZE=10M/" $PATH/etc/default/armbian-ramlog
/bin/sed -i "s/^#\?USE_RSYNC=.*/USE_RSYNC=false/" $PATH/etc/default/armbian-ramlog

echo "==Change rotate log config"
/bin/sed -i "s/rotate 7/rotate 1/" $PATH/etc/logrotate.d/rsyslog
/bin/sed -i "s/daily/hourly/" $PATH/etc/logrotate.d/rsyslog

# Add ssh key
echo "==Add ssh key"
/bin/mkdir -p $PATH/home/pi/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8zBBG7a7fVxFyyOAigru08gtDYU2kwQ1ofuvhWKgHiq4/IGEdjXqSTVTh36tpJ3saG1DF5lHQMXF3aqS6Dzw7HVDVZi3N4XLUZ6XdaAXZ7a4RKQftCft2OOsgONBh63qYO7U7CgOzn7W+vyALszC1IcS9a+6oJFwOIqqiloUwnqQopgV1dy58Emmt4DpUrPc9fo7xGQJjnbT2sqHbwI9DkootJmhupOS98VBSVOyw4oPkxuqV3lbvJgMoKna/KIfCKRBEPO42nbMlYFMzB0yKuUFyY4inYRu4126LR12ODzVnD2QPfl1vSO3oXBLAi7xlZ747Z1obmEEdR+XuZ+XLC00I/XW0bJ1WX4DvJv9l/Mk0TPOFQFhJG7LGf69W7yLWKS7+NAcy5rn1CrXe1I4BLLC9Dr0b2Wwi6io1iOl92rkK3DUSttmgvu16eWOCUbu/Zu3OuULZMm3NnMtilVm8Rb7qzptTOAaSxZOQ2azSxqslvE0CHMC50kmOvA3WvqFV/eIwxE0xpzQOqkdyMTQnTRQPgfCfg9ifYo/+peH3h+D6G8x27+OKUgTdbnrprYo8zgxUwvEbgaSnb/IoZ/+Ah8iGHsFsc2LpERpY+76ChKSl9l5XMSbxkPKow0ctQ+IuRhVYqvq6+k0LXIlg3H2/LzhYKGYwks+v0Hy5Ck2YSQ== vcloudcamdev@vng.com.vn" | /usr/bin/tee $PATH/home/pi/.ssh/authorized_keys
/bin/chmod 0644 $PATH/home/pi/.ssh/authorized_keys

# Enalble ssh from public key
echo "==Enalble ssh from public key"
/bin/sed -i "s/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/" $PATH/etc/ssh/sshd_config
MergeParameter="publickey keyboard-interactive "
/bin/sed -i -n '/and ChallengeResponseAuthentication to/{p;:a;N;/UsePAM yes/!ba;s/.*\n/AuthenticationMethods '"$MergeParameter"'\n/};p' $PATH/etc/ssh/sshd_config
# Disable login ssh with password
echo "==Disable login ssh with password"
/bin/sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" $PATH/etc/ssh/sshd_config
/bin/sed -i "s/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/" $PATH/etc/ssh/sshd_config
/bin/sed -i "s/^\@include common-auth/\#@include common-auth/" $PATH/etc/pam.d/sshd

# Change sysctl.conf
echo "==Change sysctl.conf"
/bin/sed -i "s/^#\?vm.swappiness=.*/vm.swappiness=5/" $PATH/etc/sysctl.conf
echo "vm.min_free_kbytes=65536" >> $PATH/etc/sysctl.conf

# Disable service
echo "==Disable service apt-daily"
/bin/rm -f $PATH/etc/systemd/system/apt-daily.timer.service
/bin/rm -f $PATH/etc/systemd/system/multi-user.target.wants/apt-daily.timer.service
/bin/rm -f $PATH/etc/systemd/system/timers.target.wants/apt-daily.timer

echo "==Disable service apt-daily-upgrade"
/bin/rm -f $PATH/etc/systemd/system/apt-daily-upgrade.timer.service
/bin/rm -f $PATH/etc/systemd/system/multi-user.target.wants/apt-daily-upgrade.timer.service
/bin/rm -f $PATH/etc/systemd/system/timers.target.wants/apt-daily-upgrade.timer

# Disable ZRAM
echo "==Disable ZRAM"
/bin/sed -i "s/^#\?ENABLED/#ENABLED/" $PATH/etc/default/armbian-zram-config

# Copy service hub
echo "==Hub service install"
/bin/cp -rf hub/ $PATH/home/pi/
/bin/rm $PATH/home/pi/hub/hub
/bin/rm $PATH/home/pi/hub/hubctl

echo "==Download hub binary"
/usr/bin/wget -O $PATH/home/pi/hub/hub "https://uvcloudcam:yUEq4Dy1=7SjPXkkd4Dydq3Q7RE0ukkdq3Q@repo.vcloudcam.vn/download/hub/hub-$VERSIONHUB-linux-$ARCH"
/usr/bin/wget -O $PATH/home/pi/hub/hubctl "https://uvcloudcam:yUEq4Dy1=7SjPXkkd4Dydq3Q7RE0ukkdq3Q@repo.vcloudcam.vn/download/hub/hub-controller-$VERSIONHUBCTL-linux-$ARCH"
/bin/chmod +x $PATH/home/pi/hub/hub
/bin/chmod +x $PATH/home/pi/hub/hubctl

echo "==Edit config"
/bin/sed -i "s/\"model\".*/\"model\": \"$MODEL\",/" $PATH/home/pi/hub/config.json
/bin/sed -i "s/\"agency\".*/\"agency\": \"$AGENCY\",/" $PATH/home/pi/hub/config.json
/bin/sed -i "s/\"interface\":.*/\"interface\": \"$INTERFACE\",/" $PATH/home/pi/hub/config.json
/bin/sed -i "s/\"server\":.*/\"server\": \"$SERVER\",/" $PATH/home/pi/hub/config.json
/bin/sed -i "s/\"run\".*,/\"run\": \"$RUN\",/" $PATH/home/pi/hub/config.json

echo "==Enable service"
/bin/cp -rf $PATH/home/pi/hub/hub.service $PATH/lib/systemd/system/
/bin/cp -rf $PATH/home/pi/hub/hub-controller.service $PATH/lib/systemd/system/

/bin/ln -s /lib/systemd/system/hub.service $PATH/etc/systemd/system/
/bin/ln -s /lib/systemd/system/hub-controller.service $PATH/etc/systemd/system/
/bin/ln -s /lib/systemd/system/hub.service $PATH/etc/systemd/system/multi-user.target.wants/hub.service
/bin/ln -s /lib/systemd/system/hub-controller.service $PATH/etc/systemd/system/multi-user.target.wants/hub-controller.service

echo "==Done=="
