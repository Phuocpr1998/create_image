#!/bin/bash
# sudo ./changeIp.sh --interface eth0 --mode set --ipaddress 172.19.1.235 --gateway 172.19.0.1 --dns 8.8.8.8 --type static --subnetmask 16
# sudo ./changeIp.sh --interface eth0 --mode set --type dynamic
# sudo ./changeIp.sh --interface eth0 --mode get
[[ -n ${SUDO_USER} ]] && SUDO="sudo "

#
# create interface configuration section
#
function create_if_config() {
		address=$(ip -4 addr show dev $1 | awk '/inet/ {print $2}' | cut -d'/' -f1)
		netmask=$(ip -4 addr show dev $1 | awk '/inet/ {print $2}' | cut -d'/' -f2)
		gateway=$(route -n | grep 'UG[ \t]' | awk '{print $2}' | sed -n '1p')
		echo -e "# armbian-config created"
		echo -e "source /etc/network/interfaces.d/*\n"
		if [[ "$3" == "fixed" ]]; then
			echo -e "# Local loopback\nauto lo\niface lo init loopback\n"
			echo -e "# Interface $2\nauto $2\nallow-hotplug $2"
			echo -e "iface $2 inet static\n\taddress $address\n\tnetmask $netmask\n\tgateway $gateway\n\tdns-nameservers 8.8.8.8"
		fi

}

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




#
# edit ip address
# $2 ipaddress $3 gateway $4 dns
function systemd_ip_editor ()
{
	local filename="/etc/systemd/network/10-$1.network"
	if [[ -f $filename ]]; then
		sed -i '/Network/,$d' $filename
		if [[ $? = 0 ]]; then
			echo -e "[Network]" >>$filename
			echo -e "Address=$2" >> $filename
			echo -e "Gateway=$3" >> $filename
			echo -e "DNS=$4" >> $filename
		fi
	fi

}




#
# edit ip address
# $4 ipaddress $5 subnetmas $6 gateway $7
function ip_editor ()
{
	if [[ $? = 0 ]]; then
		echo -e "# armbian-config created\nsource /etc/network/interfaces.d/*\n" >$3
		echo -e "# Local loopback\nauto lo\niface lo inet loopback\n" >> $3
		echo -e "# Interface $2\nauto $2\nallow-hotplug $2\niface $2 inet static\
			\n\taddress $4\n\tnetmask $5\n\tgateway $6\n\tdns-nameservers $7" >> $3
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


	SYSTEMDNET=$(service systemd-networkd status | grep -w active | grep -w running)
	filename="/etc/systemd/network/10-$INTERFACE.network"
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
		
		create_if_config "$DEFAULT_ADAPTER" "$DEFAULT_ADAPTER" "fixed" > /dev/null
		if [[ -n $SYSTEMDNET ]]; then
			systemd_ip_editor "${DEFAULT_ADAPTER}" "$IPADDRESS" "$GATEWAY" "$DNS"
		else
			if [[ -n $(LC_ALL=C nmcli device status | grep $DEFAULT_ADAPTER | grep connected) ]]; then
				nm_ip_editor "$DEFAULT_ADAPTER" "$IPADDRESS" "$SUBNETMASK" "$GATEWAY" "$DNS"
			else
				ip_editor "$DEFAULT_ADAPTER" "$DEFAULT_ADAPTER" "/etc/network/interfaces" "$IPADDRESS" "$SUBNETMASK" "$GATEWAY" "$DNS"
			fi
		fi
	else
		if [[ -n $SYSTEMDNET ]]; then
			filename="/etc/systemd/network/10-${DEFAULT_ADAPTER}.network"
			if [[ -f $filename ]]; then
				sed -i '/Network/,$d' $filename
				echo -e "[Network]" >>$filename
				echo -e "DHCP=ipv4" >>$filename
			fi
			else
			if [[ -n $(LC_ALL=C nmcli device status | grep $DEFAULT_ADAPTER | grep connected) ]]; then
				nmcli connection delete uuid $(LC_ALL=C nmcli -f UUID,DEVICE connection show | grep $DEFAULT_ADAPTER | awk '{print $1}') >/dev/null 2>&1
				nmcli con add con-name "Armbian ethernet" type ethernet ifname $DEFAULT_ADAPTER >/dev/null 2>&1
				nmcli con up "Armbian ethernet" >/dev/null 2>&1
			else
				create_if_config "$DEFAULT_ADAPTER" "$DEFAULT_ADAPTER" "dynamic" > /etc/network/interfaces
			fi
		fi
	fi
else # mode get ip address
	address=$(ip -4 addr show dev $DEFAULT_ADAPTER | awk '/inet/ {print $2}' | cut -d'/' -f1)
	netmask=$(ip -4 addr show dev $DEFAULT_ADAPTER | awk '/inet/ {print $2}' | cut -d'/' -f2)
	gateway=$(route -n | grep 'UG[ \t]' | awk '{print $2}' | sed -n '1p')

	echo $address $netmask $gateway
fi

