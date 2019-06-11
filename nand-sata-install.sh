#!/bin/bash
#
# Custom from nand-sata-install.sh
#

# Target sata drive
[[ -f /usr/lib/u-boot/platform_install.sh ]] && source /usr/lib/u-boot/platform_install.sh

# script configuration
CWD="/usr/lib/nand-sata-install"
EX_LIST="${CWD}/exclude.txt"
[ -f /etc/default/openmediavault ] && echo '/srv/*' >> "${EX_LIST}"
logfile="/var/log/nand-sata-install.log"

# read in board info
[[ -f /etc/armbian-release ]] && source /etc/armbian-release

emmcdevice="/dev/mmcblk1"
if cat /proc/cpuinfo | grep -q 'sun4i'; then DEVICE_TYPE="a10"; else DEVICE_TYPE="a20"; fi 	# Determine device
BOOTLOADER="${CWD}/${DEVICE_TYPE}/bootloader"							# Define bootloader
case ${LINUXFAMILY} in
        rk3328|rk3399|rockchip64)
                FIRSTSECTOR=32768
                ;;
        *)
                FIRSTSECTOR=8192
                ;;
esac

#recognize_root
root_uuid=$(sed -e 's/^.*root=//' -e 's/ .*$//' < /proc/cmdline)
root_partition=$(blkid | tr -d '":' | grep "${root_uuid}" | awk '{print $1}')
root_partition_device="${root_partition::-2}"
emmccheck=$(ls -d -1 /dev/mmcblk* | grep -w 'mmcblk[0-9]' | grep -v "$root_partition_device");						# check eMMC
logfile="/var/log/nand-sata-install.log"

eMMCFilesystemChoosen=ext4

mountopts='defaults,noatime,nodiratime,commit=600,errors=remount-ro,x-gvfs-hide   0       1'

# Create boot and root file system "$1" = boot, "$2" = root (Example: create_armbian "/dev/nand1" "/dev/sda3")
create_armbian()
{
        # create mount points, mount and clean
        TempDir=$(mktemp -d /mnt/${0##*/}.XXXXXX || exit 2)
        sync && mkdir -p "${TempDir}"/bootfs "${TempDir}"/rootfs
        [[ -n $2 ]] && ( mount -o compress-force=zlib "$2" "${TempDir}"/rootfs 2> /dev/null || mount "$2" "${TempDir}"/rootfs )
        mount "$1" "${TempDir}"/bootfs
        rm -rf "${TempDir}"/bootfs/* "${TempDir}"/rootfs/*

        # write information to log
        echo -e "\nOld UUID:  ${root_uuid}" >> $logfile
        echo "eMMC UUID: $emmcuuid $eMMCFilesystemChoosen" >> $logfile
        echo "Boot: \$1 $1 $eMMCFilesystemChoosen" >> $logfile
        echo "Root: \$2 $2 $FilesystemChoosen" >> $logfile

        # calculate usage and see if it fits on destination
        USAGE=$(df -BM | grep ^/dev | head -1 | awk '{print $3}' | tr -cd '[0-9]. \n')
        DEST=$(df -BM | grep ^/dev | grep "${TempDir}"/rootfs | awk '{print $4}' | tr -cd '[0-9]. \n')
        if [[ $USAGE -gt $DEST ]]; then
                echo "Partition too small.\Zn Needed: $USAGE MB Avaliable: $DEST MB"
                umount_device "$1"; umount_device "$2"
                exit 3
        fi

        if [[ $1 == *nand* ]]; then
                # creating nand boot. Copy precompiled uboot
                rsync -aqc $BOOTLOADER/* "${TempDir}"/bootfs
        fi

        # write information to log
        echo "Usage: $USAGE" >> $logfile
        echo -e "Dest: $DEST\n\n/etc/fstab:" >> $logfile
        cat /etc/fstab >> $logfile
        echo -e "\n/etc/mtab:" >> $logfile
        grep '^/dev/' /etc/mtab | grep -E -v "log2ram|folder2ram" | sort >> $logfile

        # stop running services
        echo -e "\nFiles currently open for writing:" >> $logfile
        lsof / | awk 'NR==1 || $4~/[0-9][uw]/' | grep -v "^COMMAND" >> $logfile
        echo -e "\nTrying to stop running services to minimize open files:\c" >> $logfile
        stop_running_services "nfs-|smbd|nmbd|winbind|ftpd|netatalk|monit|cron|webmin|rrdcached" >> $logfile
        stop_running_services "fail2ban|ramlog|folder2ram|postgres|mariadb|mysql|postfix|mail|nginx|apache|snmpd" >> $logfile
        pkill dhclient 2>/dev/null
        LANG=C echo -e "\n\nChecking again for open files:" >> $logfile
        lsof / | awk 'NR==1 || $4~/[0-9][uw]/' | grep -v "^COMMAND" >> $logfile

        # count files is needed for progress bar
        TODO=$(rsync -ahvrltDn --delete --stats --exclude-from=$EX_LIST / "${TempDir}"/rootfs | grep "Number of files:"|awk '{print $4}' | tr -d '.,')
        echo "Copying ${TODO} files to $2. \c" >> $logfile

        # creating rootfs
        # Speed copy increased x10
         # Variables for interfacing with rsync progress
        nsi_conn_path="${TempDir}/nand-sata-install"
        nsi_conn_done="${nsi_conn_path}/done"
        mkdir -p "${nsi_conn_path}"
        echo no >"${nsi_conn_done}"

         # Launch rsync in background
        { \
        rsync -avrltD --delete --exclude-from=$EX_LIST / "${TempDir}"/rootfs | \
        nl;
         # save exit code from rsync
        echo  ${PIPESTATUS[0]} >"${nsi_conn_done}"
        } &> /dev/null &

         # while variables
        echo "Transferring rootfs to $2 ($USAGE MB). This will take approximately $(( $((USAGE/300)) * 1 )) minutes to finish. Please wait!"
        rsync_copy_finish=0
        rsync_done=""
        while [ "${rsync_copy_finish}" -eq 0 ]; do
                # finish the while if the rsync is finished
                rsync_done=$(cat ${nsi_conn_done})
                if [[ "${rsync_done}" != "no" ]]; then
                        if [[ ${rsync_done} -eq 0 ]]; then
                                rm -rf "${nsi_conn_path}"
                                rsync_copy_finish=1
                        else
                                # if rsync return error
                                echo "Error: could not copy rootfs files, exiting"
                                exit 4
                        fi
                else
                        sleep 0.5
                fi

        done

        # run rsync again to silently catch outstanding changes between / and "${TempDir}"/rootfs/
        echo "Cleaning up ... Almost done."
        rsync -avrltD --delete --exclude-from=$EX_LIST / "${TempDir}"/rootfs >/dev/null 2>&1

        # creating fstab from scratch
        rm -f "${TempDir}"/rootfs/etc/fstab
        mkdir -p "${TempDir}"/rootfs/etc "${TempDir}"/rootfs/media/mmcboot "${TempDir}"/rootfs/media/mmcroot

        # Restore TMP and swap
        echo "# <file system>                                   <mount point>   <type>  <options>
                <dump>  <pass>" > "${TempDir}"/rootfs/etc/fstab
        echo "tmpfs                                             /tmp            tmpfs   defaults,nosuid
                0       0" >> "${TempDir}"/rootfs/etc/fstab
        grep swap /etc/fstab >> "${TempDir}"/rootfs/etc/fstab

        # Boot from eMMC, root = eMMC or SATA / USB
        #
        if [[ $2 == ${emmccheck}p* || $1 == ${emmccheck}p* ]]; then
                local targetuuid=$emmcuuid
                local choosen_fs=$eMMCFilesystemChoosen
                echo "Finishing full install to eMMC." >> $logfile

                # fix that we can have one exlude file
                cp -R /boot "${TempDir}"/bootfs
                # old boot scripts
                sed -e 's,root='"$root_uuid"',root='"$targetuuid"',g' -i "${TempDir}"/bootfs/boot/boot.cmd
                # new boot scripts
                if [[ -f "${TempDir}"/bootfs/boot/armbianEnv.txt ]]; then
                        sed -e 's,rootdev=.*,rootdev='"$targetuuid"',g' -i "${TempDir}"/bootfs/boot/armbianEnv.txt
                else
                        sed -e 's,setenv rootdev.*,setenv rootdev '"$targetuuid"',g' -i "${TempDir}"/bootfs/boot/boot.cmd
                        [[ -f "${TempDir}"/bootfs/boot/boot.ini ]] && sed -e 's,^setenv rootdev.*$,setenv rootdev "'"$targetuuid"'",' -i "${TempDir}"/bootfs/boot/boot.ini
                        [[ -f "${TempDir}"/rootfs/boot/boot.ini ]] && sed -e 's,^setenv rootdev.*$,setenv rootdev "'"$targetuuid"'",' -i "${TempDir}"/rootfs/boot/boot.ini
                fi
                mkimage -C none -A arm -T script -d "${TempDir}"/bootfs/boot/boot.cmd "${TempDir}"/bootfs/boot/boot.scr                                                                             >/dev/null 2>&1 || (echo 'Error while creating U-Boot loader image with mkimage' >&2 ; exit 5)

                # fstab adj
                if [[ "$1" != "$2" ]]; then
                        echo "$emmcbootuuid     /media/mmcboot  ext4    ${mountopts}" >> "${TempDir}"/rootfs/etc/fstab
                        echo "/media/mmcboot/boot                               /boot           none    bind
                                0       0" >> "${TempDir}"/rootfs/etc/fstab
                fi
                # if the rootfstype is not defined as cmdline argument on armbianEnv.txt
                if ! grep -qE '^rootfstype=.*' "${TempDir}"/bootfs/boot/armbianEnv.txt; then
                        # Add the line of type of the selected rootfstype to the file armbianEnv.txt
                        echo "rootfstype=$choosen_fs" >> "${TempDir}"/bootfs/boot/armbianEnv.txt
                fi

                sed -e 's,rootfstype=.*,rootfstype='$choosen_fs',g' -i "${TempDir}"/bootfs/boot/armbianEnv.txt
                echo "$targetuuid       /               $choosen_fs     ${mountopts}" >> "${TempDir}"/rootfs/etc/fstab

                if [[ $(type -t write_uboot_platform) != function ]]; then
                        echo "Error: no u-boot package found, exiting"
                        exit 6
                fi
                write_uboot_platform "$DIR" $emmccheck
        fi

        # recreate OMV mounts at destination if needed
        grep -q ' /srv/' /etc/fstab
        if [ $? -eq 0 -a -f /etc/default/openmediavault ]; then
                echo -e '# >>> [openmediavault]' >> "${TempDir}"/rootfs/etc/fstab
                grep ' /srv/' /etc/fstab | while read ; do
                        echo "${REPLY}" >> "${TempDir}"/rootfs/etc/fstab
                        mkdir -p -m700 "${TempDir}/rootfs$(awk -F" " '{print $2}' <<<"${REPLY}")"
                done
                echo -e '# <<< [openmediavault]' >> "${TempDir}"/rootfs/etc/fstab
        fi

        echo -e "\nChecking again for open files:" >> $logfile
        lsof / | awk 'NR==1 || $4~/[0-9][uw]/' | grep -v "^COMMAND" >> $logfile
        LANG=C echo -e "\n$(date): Finished\n\n" >> $logfile
        cat $logfile > "${TempDir}"/rootfs${logfile}
        sync

        umount "${TempDir}"/rootfs
        [[ $1 != "spi" ]] && umount "${TempDir}"/bootfs
} # create_armbian

# Accept device as parameter: for example /dev/sda unmounts all their mounts
umountdevice() {
	if [ -n "$1" ]; then
		device=$1; 		
		for n in ${device}*; do
			if [ "${device}" != "$n" ]; then
				if mount|grep -q ${n}; then
					umount -l $n >/dev/null 2>&1
				fi
			fi
		done
	fi
} # umountdevice

# try to stop running services
stop_running_services()
{
        systemctl --state=running | awk -F" " '/.service/ {print $1}' | sort -r | \
                grep -E -e "$1" | while read ; do
                echo -e "\nStopping ${REPLY} \c"
                systemctl stop ${REPLY} 2>&1
        done
}


# Formatting eMMC [device] example /dev/mmcblk1
formatemmc() {
	# deletes all partitions
	dd bs=1 seek=446 count=64 if=/dev/zero of=$1 >/dev/null 2>&1
	# calculate capacity and reserve some unused space to ease cloning of the installation
	# to other media 'of the same size' (one sector less and cloning will fail)
	QUOTED_DEVICE=$(echo "${1}" | sed 's:/:\\\/:g')
	CAPACITY=$(parted ${1} unit s print -sm | awk -F":" "/^${QUOTED_DEVICE}/ {printf (\"%0d\", \$2 / ( 1024 / \$4 ))}")
	if [ ${CAPACITY} -lt 4000000 ]; then
		# Leave 2 percent unpartitioned when eMMC size is less than 4GB (unlikely)
		LASTSECTOR=$(( 32 * $(parted ${1} unit s print -sm | awk -F":" "/^${QUOTED_DEVICE}/ {printf (\"%0d\", ( \$2 * 98 / 3200))}") -1 ))
	else
		# Leave 1 percent unpartitioned
		LASTSECTOR=$(( 32 * $(parted ${1} unit s print -sm | awk -F":" "/^${QUOTED_DEVICE}/ {printf (\"%0d\", ( \$2 * 99 / 3200))}") -1 ))
	fi

	parted -s $1 -- mklabel msdos
	parted -s $1 -- mkpart primary ext4 2048s ${LASTSECTOR}s
	partprobe $1
	# create fs
	mkfs.ext4 -qF $1"p1" >/dev/null 2>&1
        emmcuuid=$(blkid -o export "$1"'p1' | grep -w UUID)
        emmcbootuuid=$emmcuuid
} # formatemmc

main() {
	export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

	# This tool must run under root

	if [[ ${EUID} -ne 0 ]]; then 
		echo "This tool must run as root. Exiting ..."
		exit 1
	fi

	# Check if we run it from SD card
	if [[ "$(sed -n 's/^DEVNAME=//p' /sys/dev/block/$(mountpoint -d /)/uevent)" != mmcblk* ]]; then
		echo "This tool must run from SD-card!"
		exit 1
	fi

	ichip='eMMC';
        dest_boot=$emmccheck'p1'
        dest_root=$emmccheck'p1'

	command="Power off"
	umountdevice "/dev/mmcblk1" 
	echo "Formating /dev/mmcblk1"
	formatemmc "/dev/mmcblk1"		
	echo "Create boot in /dev/mmcblk1"
	create_armbian "$dest_boot" "$dest_root"

	if [ $? -eq 0 ]; then "$(echo ${command,,} | sed 's/ //')"; fi
} # main

main "$@" 