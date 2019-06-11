#!/bin/bash
# sudo ./setupbox.sh --interface eth0 --mode set --ipaddress 172.19.1.235 --gateway 172.19.0.1 --dns 8.8.8.8 --type static --subnetmask 16
# sudo ./setupbox.sh --interface eth0 --mode set --type dynamic
# sudo ./setupbox.sh --interface eth0 --mode get
[[ -n ${SUDO_USER} ]] && SUDO="sudo "

#
# edit ip address within network manager
#$2 ipaddress $3 subnetmasK $4 gateway $5 dns
function nm_ip_editor ()
{
	if [[ $? = 0 ]]; then
		localuuid=$(LC_ALL=C nmcli -f UUID,DEVICE connection show | grep $1 | awk '{print $1}')
		nmcli con mod $localuuid ipv4.method manual ipv4.addresses "$2/$3" >/dev/null 2>&1
		nmcli con mod $localuuid ipv4.method manual ipv4.gateway  "$4" >/dev/null 2>&1
		nmcli con mod $localuuid ipv4.dns "$5,$4" >/dev/null 2>&1
		nmcli con down $localuuid >/dev/null 2>&1
		sleep 2
		nmcli con up $localuuid >/dev/null 2>&1
	fi
}

while [ -n "$1" ]; do
	case "$1" in
		--interface) export INTERFACE="$2"; shift;;
		--mode) export MODE="$2"; shift;;
		--type) export TYPE="$2"; shift;;
		--ipaddress) export IPADDRESS="$2"; shift;;
		--subnetmask) export SUBNETMASK="$2"; shift;;
		--gateway) export GATEWAY="$2"; shift;;
		--dns) export DNS="$2"; shift;;
		-*)
			echo "Invalid option: $1"
			exit 1
		;;
		*) break;;
	esac
	shift;
done

if [ -z "$MODE" ]
then
	echo "Missing mode"
	exit 1
fi

if [ -z "$INTERFACE" ]
then
	echo "Missing interface"
	exit 1
fi

DEFAULT_ADAPTER="$INTERFACE"

if [ "$MODE" = "set" ]  # mode set ip address
then

	if [ -z "$TYPE" ]
	then
		echo "Missing type"
		exit 1
	fi

	if [ "$TYPE" = "static" ] 
	then
		if [ -z "$IPADDRESS" ]
		then
			echo "Missing ip address"
			exit 1
		fi

		if [ -z "$GATEWAY" ]
		then
			echo "Missing default gateway"
			exit 1
		fi

		if [ -z "$SUBNETMASK" ]
		then
			echo "Missing subnet mask"
			exit 1
		fi

		if [ -z "$DNS" ]
		then
			echo "Missing dns"
			exit 1
		fi

		nm_ip_editor "$DEFAULT_ADAPTER" "$IPADDRESS" "$SUBNETMASK" "$GATEWAY" "$DNS"
	else
		nmcli connection delete uuid $(LC_ALL=C nmcli -f UUID,DEVICE connection show | grep $DEFAULT_ADAPTER | awk '{print $1}') >/dev/null 2>&1
		nmcli con add con-name "Armbian ethernet" type ethernet ifname $DEFAULT_ADAPTER >/dev/null 2>&1
		nmcli con up "Armbian ethernet" >/dev/null 2>&1
	fi
else # mode get ip address
	localuuid=$(LC_ALL=C nmcli -f UUID,DEVICE connection show | grep $DEFAULT_ADAPTER | awk '{print $1}')
	address=$(ip -4 addr show dev $DEFAULT_ADAPTER | awk '/inet/ {print $2}' | cut -d'/' -f1)
	netmask=$(ip -4 addr show dev $DEFAULT_ADAPTER | awk '/inet/ {print $2}' | cut -d'/' -f2)
	gateway=$(sudo route -n | grep $DEFAULT_ADAPTER | grep 'UG[ \t]' | awk '{print $2}')
	dns=$(nmcli conn show $localuuid | grep "IP4.DNS\[1\]:" | awk '{print $2}')

	echo {\"address\": \"$address\", \"netmask\": $netmask, \"gateway\": \"$gateway\", \"dns\": \"$dns\"}
fi

