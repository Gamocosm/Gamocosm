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

sed -i "/^# TYPE[[:space:]]*DATABASE[[:space:]]*USER[[:space:]]*ADDRESS[[:space:]]*METHOD/a host gamocosm_development,gamocosm_test,gamocosm_production gamocosm ::1/32 md5" /var/lib/pgsql/data/pg_hba.conf
systemctl restart postgresql

firewall-cmd --add-port=5432/tcp
firewall-cmd --permanent --add-port=5432/tcp
firewall-cmd --add-port=6379/tcp
firewall-cmd --permanent --add-port=6379/tcp

echo "Done!"
