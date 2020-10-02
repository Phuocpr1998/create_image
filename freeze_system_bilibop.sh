apt install bilibop -y

echo "BILIBOP_LOCKFS=\"true\"" >> "/etc/bilibop/bilibop.conf"
echo "BILIBOP_LOCKFS_POLICY=\"soft\"" >> /etc/bilibop/bilibop.conf
echo "BILIBOP_LOCKFS_WHITELIST=\"\"" >> /etc/bilibop/bilibop.conf
echo "BILIBOP_LOCKFS_SWAP_POLICY=\"\""	>> /etc/bilibop/bilibop.conf
echo "BILIBOP_LOCKFS_SIZE=\"\"" >> /etc/bilibop/bilibop.conf
echo "BILIBOP_LOCKFS_NOTIFY_POLICY=\"\"" >> /etc/bilibop/bilibop.conf