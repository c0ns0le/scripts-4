#!/bin/bash -x

(
ARCH=`arch`

# Prep release and repos
rpm -Uvh http://download2.clearsdn.com/marketplace/cloud/6/noarch/clearos-release-community-6-current.noarch.rpm
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-ClearOS

# Install and upgrade
yum --enablerepo=* clean all
yum -y install app-base
yum -y install app-marketplace app-users app-groups app-date app-configuration-backup app-disk-usage app-mail-notification app-bandwidth-viewer app-incoming-firewall app-ssh-server
yum -y remove libreport ntsysv at
yum -y upgrade

# Enable firewall
allow-port -p TCP -d 22 -n SSH
allow-port -p TCP -d 81 -n Webconfig
sed -i -e 's/^MODE=.*/MODE="standalone"/' /etc/clearos/network.conf

# Disable SE Linux
echo 0 > /selinux/enforce

# Start webconfig
service webconfig start

) 2>&1 | tee /var/log/clearos-installer.log
