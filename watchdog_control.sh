#!/bin/bash

# Enable:  watchdog_control.sh --gateway 172.19.0.1 --timeout 300 --status enable
# Disable: watchdog_control.sh --status diable
[[ -n ${SUDO_USER} ]] && SUDO="sudo "

watchdogFile="/etc/watchdog.conf"
if [ -f "$watchdogFile" ]
then
	echo "$watchdogFile found."
else
	echo "$watchdogFile not found."
    exit -1
fi

while [ -n "$1" ]; do
	case "$1" in
		--gateway) export GATEWAY="$2"; shift;;
		--timeout) export TIMEOUT="$2"; shift;;
		--status)  export STATUS="$2"; shift;;
		-*)
			echo "Invalid option: $1"
			exit 1
		;;
		*) break;;
	esac
	shift;
done

if [[ -z $(grep -w "retry-timeout" $watchdogFile ) ]]; then
    echo >> $watchdogFile # new line
    echo "#retry-timeout" >> $watchdogFile
fi

if [[ -z $(grep -w "ping" $watchdogFile ) ]]; then
    echo >> $watchdogFile # new line
    echo "#ping" >> $watchdogFile
fi

if [ -z "$STATUS" ]
    then
        echo "Missing status of watchdog"
        exit 1
    fi

if [ "$STATUS" = "enable" ]  # enable watch dog
then
    if [ -z "$GATEWAY" ]
    then
        echo "Missing gateway"
        exit 1
    fi


    if [ -z "$TIMEOUT" ]
    then
        echo "Missing timeout"
        exit 1
    fi

     

    /bin/sed -i "s/^#\?ping/#ping/" $watchdogFile
    /bin/sed -i "s/^#\?retry-timeout/#retry-timeout/" $watchdogFile

    /bin/sed -i "s/.*#.*ping.*/ping = $GATEWAY/" $watchdogFile
    /bin/sed -i "s/.*#.*retry-timeout.*/retry-timeout = $TIMEOUT/" $watchdogFile
    systemctl restart watchdog.service
    echo "Start watchdog service"
else   # disable watch dog
    /bin/sed -i "s/^#\?ping/#ping/" $watchdogFile
    /bin/sed -i "s/^#\?retry-timeout/#retry-timeout/" $watchdogFile
    systemctl stop watchdog.service
    echo "Stop watchdog service"
fi
