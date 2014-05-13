#!/bin/bash

set -e

yum -y update

yum -y install ruby nodejs gcc gcc-c++ curl-devel openssl-devel zlib-devel ruby-devel memcached git postgresql-server postgresql-contrib postgresql-devel tmux redis

gem install passenger

passenger-install-nginx-module

wget -O /etc/systemd/system/nginx.service https://raw.githubusercontent.com/Raekye/Gamocosm/master/sysadmin/nginx.service
wget -O /etc/systemd/system/gamocosm-sidekiq.service https://raw.githubusercontent.com/Raekye/Gamocosm/master/sysadmin/sidekiq.service

sed -i "1s/^/user http;\\n/" /opt/nginx/conf/nginx.conf
sed -i "$ s/}/include \\/opt\\/nginx\\/sites-enabled\\/\\*.conf;\\n}/" /opt/nginx/conf/nginx.conf

mkdir /opt/nginx/sites-enabled;
mkdir /opt/nginx/sites-available;

wget -O /opt/nginx/sites-available/gamocosm.conf https://raw.githubusercontent.com/Raekye/Gamocosm/master/sysadmin/nginx.conf
ln -s /opt/nginx/sites-available/gamocosm.conf /opt/nginx/sites-enabled/gamocosm.conf

systemctl enable nginx
systemctl enable memcached
systemctl enable redis
systemctl enable postgresql
systemctl enable gamocosm-sidekiq

postgresql-setup initdb

systemctl start postgresql
systemctl start redis
systemctl start memcached

echo "Run: createuser --createdb --pwprompt --superuser gamocosm"
echo "Run: psql"
echo "Run: \\password postgres"
echo "Run: \\q"
echo "Run: exit"
su - postgres

sed -i "/^# TYPE[[:space:]]*DATABASE[[:space:]]*USER[[:space:]]*ADDRESS[[:space:]]*METHOD/a local all gamocosm md5" /var/lib/pgsql/data/pg_hba.conf
systemctl restart postgresql

iptables -I INPUT -p tcp --dport 80 -j ACCEPT
iptables-save

adduser http

echo "Run: ssh-keygen -t rsa"
echo "Run: exit"
su - http

mkdir /run/http
chown http:http /run/http

mkdir /var/www
cd /var/www
git clone https://github.com/Raekye/Gamocosm.git gamocosm
cp gamocosm/config/app.yml.template gamocosm/config/app.yml
mkdir gampcosm/tmp
touch gamocosm/tmp/restart.txt
chown -R http:http gamocosm

DEVISE_SECRET_KEY=$(ruby -e "require 'securerandom'; puts(SecureRandom.hex(64))")

PRODUCTION_SECRET_KEY=$(ruby -e "require 'securerandom'; puts(SecureRandom.hex(64))")

echo "Set database password"
read -n 1 -p "Press anything to continue... "
vi /var/www/gamocosm/config/database.yml

echo "Edit app.yml"
read -n 1 -p "Press anything to continue... "
vi /var/www/gamocosm/config/app.yml

cd gamocosm
sudo -u http gem install bundler
su - http -c "cd $(pwd) && bundle install --deployment"

su - http -c "cd $(pwd) && RAILS_ENV=production bundle exec rake db:setup"

su - http -c "cd $(pwd) && RAILS_ENV=production bundle exec rake assets:precompile"

systemctl start nginx
systemctl start gamocosm-sidekiq

# - hosts file?
# - scripts for: update, assets, restart
# - release branch
# - rails envs
