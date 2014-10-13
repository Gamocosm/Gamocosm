#!/bin/bash

set -e

yum -y update

yum -y install postgresql-server postgresql-contrib tmux redis

systemctl enable redis
systemctl enable postgresql

postgresql-setup initdb

systemctl start postgresql
systemctl start redis

echo "Run: createuser --createdb --pwprompt --superuser gamocosm"
echo "Run: psql"
echo "Run: \\password postgres"
echo "Run: \\q"
echo "Run: exit"
su - postgres

PRIVATE_NETWORKING_IP_ADDRESS=$(ifconfig | grep -m 4 "inet" | tail -n 1 | awk "{ print \$2 }")
sed -i "/^# TYPE[[:space:]]*DATABASE[[:space:]]*USER[[:space:]]*ADDRESS[[:space:]]*METHOD/a host postgres,gamocosm_development,gamocosm_test,gamocosm_production gamocosm $PRIVATE_NETWORKING_IP_ADDRESS/24 md5" /var/lib/pgsql/data/pg_hba.conf
sed -i "/#listen_addresses/i listen_addresses = 'localhost,$PRIVATE_NETWORKING_IP_ADDRESS'" /var/lib/pgsql/data/postgresql.conf
systemctl restart postgresql

# redis 2.8+ supports multiple bind ips, currently fedora repo has 2.6
#sed -i "/^bind/ s/\$/ $PRIVATE_NETWORKING_IP_ADDRESS/" /etc/redis.conf
sed -i "/^bind/ s/127.0.0.1/$PRIVATE_NETWORKING_IP_ADDRESS/" /etc/redis.conf
systemctl restart redis

firewall-cmd --add-port=5432/tcp
firewall-cmd --permanent --add-port=5432/tcp
firewall-cmd --add-port=6379/tcp
firewall-cmd --permanent --add-port=6379/tcp

echo "Done!"
