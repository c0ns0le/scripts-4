#!/bin/bash -x

(
ARCH=`arch`

# Prep release and repos
rpm -Uvh http://download2.clearsdn.com/marketplace/cloud/7/noarch/clearos-release-7-current.noarch.rpm
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-ClearOS-7

# Install and upgrade
yum --enablerepo=* clean all
yum -y install app-base
service webconfig stop
yum -y --enablerepo=clearos-centos,clearos-centos-updates install app-accounts app-configuration-backup app-date app-dns app-edition app-events app-incoming-firewall app-groups app-language app-log-viewer app-mail app-marketplace app-process-viewer app-software-updates app-ssh-server app-support app-user-profile app-users

# Default networking
yum -y remove NetworkManager
echo "DEVICE=eth0" > /etc/sysconfig/network-scripts/ifcfg-eth0
echo "TYPE=\"Ethernet\"" >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo "ONBOOT=\"yes\"" >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo "USERCTL=\"no\"" >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo "BOOTPROTO=\"dhcp\"" >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo "PEERDNS=\"no\"" >> /etc/sysconfig/network-scripts/ifcfg-eth0

echo "nameserver 8.8.8.8" > /etc/resolv-peerdns.conf
echo "nameserver 8.8.4.4" >> /etc/resolv-peerdns.conf

sed -i -e 's/^EXTIF=.*/EXTIF="eth0"/' /etc/clearos/network.conf

service syswatch restart

# Enable firewall
allow-port -p TCP -d 22 -n SSH
allow-port -p TCP -d 81 -n Webconfig
sed -i -e 's/^MODE=.*/MODE="standalone"/' /etc/clearos/network.conf

# Disable SE Linux
echo 0 > /selinux/enforce

# Start webconfig
service webconfig start

# One last upgrade
yum -y --enablerepo=clearos-centos,clearos-centos-updates upgrade
) 2>&1 | tee /var/log/clearos-installer.log