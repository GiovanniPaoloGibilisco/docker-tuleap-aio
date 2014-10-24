#!/bin/bash

set -ex

function generate_passwd {
   cat /dev/urandom | tr -dc "a-zA-Z0-9" | fold -w 15 | head -1
}

mkdir -p /data/etc/httpd/
mkdir -p /data/home
mkdir -p /data/lib
mkdir -p /data/etc/logrotate.d
mkdir -p /data/root && chmod 700 /data/root

pushd . > /dev/null
cd /var/lib
mv /var/lib/mysql /data/lib && ln -s /data/lib/mysql mysql
[ -d /var/lib/gitolite ] && mv /var/lib/gitolite /data/lib && ln -s /data/lib/gitolite gitolite
popd > /dev/null

# Apply codendi patches (should be temporary until integrated upstream)
pushd . > /dev/null
cd /usr/share/codendi
/bin/ls /root/app/patches/*.patch | while read patch; do
    patch -p1 -i $patch
done
popd > /dev/null

# Install codendi
bash ./setup.sh --disable-selinux --sys-default-domain=$VIRTUAL_HOST --sys-org-name=tuleap --sys-long-org-name=tuleap

# Setting root password
root_passwd=$(generate_passwd)
echo "root:$root_passwd" |chpasswd
echo "root: $root_passwd" >> /root/.codendi_passwd

# Place for post install stuff
./boot-postinstall.sh

# Create fake file to avoid error below when moving
touch /etc/aliases.codendi

# Ensure system will be synchronized ASAP
/usr/share/codendi/src/utils/php-launcher.sh /usr/share/codendi/src/utils/launch_system_check.php

service mysqld stop
service httpd stop
service crond stop

### Move all generated files to persistant storage ###

# Conf
mv /etc/httpd/conf            /data/etc/httpd
mv /etc/httpd/conf.d          /data/etc/httpd
mv /etc/codendi                /data/etc
mv /etc/aliases               /data/etc
mv /etc/aliases.codendi       /data/etc
mv /etc/logrotate.d/httpd     /data/etc/logrotate.d
mv /etc/libnss-mysql.cfg      /data/etc
mv /etc/libnss-mysql-root.cfg /data/etc
mv /etc/my.cnf                /data/etc
mv /etc/nsswitch.conf         /data/etc
mv /etc/crontab               /data/etc
mv /etc/passwd                /data/etc
mv /etc/shadow                /data/etc || true
mv /etc/group                 /data/etc
mv /root/.codendi_passwd       /data/root || true

# Data
mv /home/codendiadm /data/home
mv /home/groups    /data/home
mv /home/users     /data/home
mv /var/lib/codendi /data/lib

# Will be restored by boot-fixpath.sh later
[ -h /var/lib/mysql ] && rm /var/lib/mysql
[ -h /var/lib/gitolite ] && rm /var/lib/gitolite
