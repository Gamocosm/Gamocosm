#!/bin/bash

set -e

yum -y update

yum -y install ruby nodejs gcc gcc-c++ curl-devel openssl-devel zlib-devel ruby-devel memcached git postgresql-server postgresql-contrib postgresql-devel tmux redis

gem install passenger

passenger-install-nginx-module

wget -O /etc/systemd/system/nginx.service https://raw.githubusercontent.com/Gamocosm/Gamocosm/release/sysadmin/nginx.service
wget -O /etc/systemd/system/gamocosm-sidekiq.service https://raw.githubusercontent.com/Gamocosm/Gamocosm/release/sysadmin/sidekiq.service

sed -i "1s/^/user http;\\n/" /opt/nginx/conf/nginx.conf
sed -i "$ s/}/include \\/opt\\/nginx\\/sites-enabled\\/\\*.conf;\\n}/" /opt/nginx/conf/nginx.conf
sed -i "0,/listen[[:space:]]*80;/{s/80/8000/}" /opt/nginx/conf/nginx.conf

mkdir /opt/nginx/sites-enabled;
mkdir /opt/nginx/sites-available;

wget -O /opt/nginx/sites-available/gamocosm.conf https://raw.githubusercontent.com/Gamocosm/Gamocosm/release/sysadmin/nginx.conf
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

sed -i "/^# TYPE[[:space:]]*DATABASE[[:space:]]*USER[[:space:]]*ADDRESS[[:space:]]*METHOD/a host gamocosm_development,gamocosm_test,gamocosm_production gamocosm ::1/32 md5" /var/lib/pgsql/data/pg_hba.conf
systemctl restart postgresql

firewall-cmd --add-port=80/tcp
firewall-cmd --permanent --add-port=80/tcp

adduser -m http

echo "Run: ssh-keygen -t rsa"
echo "Run: exit"
su - http

mkdir /run/http
chown http:http /run/http

mkdir /var/www
cd /var/www
git clone https://github.com/Gamocosm/Gamocosm.git gamocosm
cd gamocosm
git checkout release
mkdir tmp
touch tmp/restart.txt
cp env.sh.template env.sh
chmod u+x env.sh
chown -R http:http .

sudo -u http gem install bundler
su - http -c "cd $(pwd) && bundle install --deployment"

SECRET_KEY_BASE="$(su - http -c "cd $(pwd) && bundle exec rake secret")"
echo "Generated secret key base $SECRET_KEY_BASE"
DEVISE_SECRET_KEY="$(su - http -c "cd $(pwd) && bundle exec rake secret")"
echo "Generated Devise secret key $DEVISE_SECRET_KEY"
read -p "Please fill in the information in env.sh (press any key to continue)... "

vi env.sh
# no more sed -i "/SIDEKIQ_ADMIN_PASSWORD/ s/=.*$/=$SIDEKIQ_ADMIN_PASSWORD/" env.sh :(

su - http -c "cd $(pwd) && RAILS_ENV=production ./env.sh --bundler rake db:setup"

su - http -c "cd $(pwd) && RAILS_ENV=production ./env.sh --bundler rake assets:precompile"

OUTDOORS_IP_ADDRESS=$(ifconfig | grep -m 1 "inet" | awk "{ print \$2 }")
echo "$OUTDOORS_IP_ADDRESS gamocosm.com" >> /etc/hosts

systemctl start nginx
systemctl start gamocosm-sidekiq

echo "Done!"

# - scripts for: update, assets, restart
