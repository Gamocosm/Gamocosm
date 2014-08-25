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
sed -i "0,/listen[[:space:]]*80;/{s/80/8000/}" /opt/nginx/conf/nginx.conf

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

adduser -m http

echo "Run: ssh-keygen -t rsa"
echo "Note: set path to /home/http/.ssh/id_rsa-gamocosm"
echo "Run: exit"
su - http

mkdir /run/http
chown http:http /run/http

mkdir /var/www
cd /var/www
git clone https://github.com/Raekye/Gamocosm.git gamocosm
cd gamocosm
git checkout master
cp config/app.yml.template config/app.yml
mkdir tmp
touch tmp/restart.txt
chown -R http:http .

sudo -u http gem install bundler
su - http -c "cd $(pwd) && bundle install --deployment"

DEVISE_SECRET_KEY="$(su - http -c "cd $(pwd) && bundle exec rake secret")"
echo "Generated devise secret key $DEVISE_SECRET_KEY"
PRODUCTION_SECRET_KEY="$(su - http -c "cd $(pwd) && bundle exec rake secret")"
echo "Generated secret key base $PRODUCTION_SECRET_KEY"
read -p "Enter gamocosm database password: " GAMOCOSM_DATABASE_PASSWORD
read -p "Enter digital ocean access token: " DIGITAL_OCEAN_API_KEY
DIGITAL_OCEAN_PUBLIC_KEY_PATH="\\/home\\/http\\/\\.ssh\\/id_rsa-gamocosm\\.pub"
echo "Found public key path $DIGITAL_OCEAN_PUBLIC_KEY_PATH"
DIGITAL_OCEAN_PRIVATE_KEY_PATH="\\/home\\/http\\/\\.ssh\\/id_rsa-gamocosm"
echo "Found private key path $DIGITAL_OCEAN_PRIVATE_KEY_PATH"
read -p "Enter private key passphrase: " DIGITAL_OCEAN_PRIVATE_KEY_PASSPHRASE
read -p "Enter Sidekiq admin username: " SIDEKIQ_ADMIN_USERNAME
read -p "Enter Sidekiq admin password: " SIDEKIQ_ADMIN_PASSWORD

cp config/app.yml.template config/app.yml
sed -i "s/\$devise_secret_key/$DEVISE_SECRET_KEY/" config/app.yml
sed -i "s/\$secret_key_base/$PRODUCTION_SECRET_KEY/" config/app.yml
sed -i "s/\$gamocosm_database_password/$GAMOCOSM_DATABASE_PASSWORD/" config/app.yml
sed -i "s/\$digital_ocean_api_key/$DIGITAL_OCEAN_API_KEY/" config/app.yml
sed -i "s/\$digital_ocean_ssh_public_key_path/$DIGITAL_OCEAN_PUBLIC_KEY_PATH/" config/app.yml
sed -i "s/\$digital_ocean_ssh_private_key_path/$DIGITAL_OCEAN_PRIVATE_KEY_PATH/" config/app.yml
sed -i "s/\$digital_ocean_ssh_private_key_passphrase/$DIGITAL_OCEAN_PRIVATE_KEY_PASSPHRASE/" config/app.yml
sed -i "s/\$sidekiq_admin_username/$SIDEKIQ_ADMIN_USERNAME/" config/app.yml
sed -i "s/\$sidekiq_admin_password/$SIDEKIQ_ADMIN_PASSWORD/" config/app.yml

su - http -c "cd $(pwd) && RAILS_ENV=production GAMOCOSM_DATABASE_PASSWORD=$GAMOCOSM_DATABASE_PASSWORD bundle exec rake db:setup"

su - http -c "cd $(pwd) && RAILS_ENV=production bundle exec rake assets:precompile"

OUTDOORS_IP_ADDRESS=$(ifconfig | grep -m 1 "inet" | awk "{ print \$2 }")
echo "$OUTDOORS_IP_ADDRESS gamocosm.com" >> /etc/hosts

systemctl start nginx
systemctl start gamocosm-sidekiq

echo "Done!"

# - scripts for: update, assets, restart
# - release branch
