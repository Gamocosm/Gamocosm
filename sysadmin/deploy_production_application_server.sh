#!/bin/bash

# last updated: 2018 feb 12 for Fedora 27
# not automated:
# - root cron job restart gamocosm and sidekiq
# - root cron job certbot

set -e

RUBY_VERSION=2.4

# timezone
unlink /etc/localtime
ln -s /usr/share/zoneinfo/America/New_York /etc/localtime

# TODO: swap
# TODO: firewalld cockpit service
#       - see https://bugzilla.redhat.com/show_bug.cgi?id=1171114
# TODO: rails database unix socket
# TODO: redis unix socket
# TODO: cron
# TODO: vim?
# TODO: still need to modify /etc/hosts ?
# TODO: certbot

dnf -y upgrade

# basic tools
dnf -y install vim tmux git wget
# services
dnf -y install memcached postgresql-server postgresql-contrib redis firewalld certbot
# needed for passenger
dnf -y install gcc gcc-c++ libcurl-devel openssl-devel zlib-devel ruby-devel
# needed for some compilations
dnf -y install redhat-rpm-config
# needed for rvm
dnf -y install patch libffi-devel bison libyaml-devel autoconf readline-devel automake libtool sqlite-devel
# other
dnf -y install nodejs

# databases
# - see https://fedoraproject.org/wiki/PostgreSQL
postgresql-setup --initdb --unit postgresql

# append after line
sed -i "/^# TYPE[[:space:]]*DATABASE[[:space:]]*USER[[:space:]]*ADDRESS[[:space:]]*METHOD/a local postgres,gamocosm_development,gamocosm_test,gamocosm_production gamocosm md5" /var/lib/pgsql/data/pg_hba.conf

systemctl enable redis
systemctl start redis

systemctl enable memcached
systemctl start memcached

systemctl enable postgresql
systemctl start postgresql

echo "Run: createuser --createdb --pwprompt --superuser gamocosm"
echo "Run: psql"
echo "Run: \\password postgres"
echo "Run: \\q"
echo "Run: exit"
su - postgres

# no ri (ruby index) or RDoc (ruby documentation)
gem install passenger --no-rdoc --no-ri

# nginx
passenger-install-nginx-module

# only modify 1st line
sed -i "1s/^/user http;\\n/" /opt/nginx/conf/nginx.conf
# umm...
sed -i "$ s/}/include \\/opt\\/nginx\\/sites-enabled\\/\\*.conf;\\n}/" /opt/nginx/conf/nginx.conf
# only modify 1st occurence
sed -i "0,/listen[[:space:]]*80;/{s/80/8000/}" /opt/nginx/conf/nginx.conf

mkdir /opt/nginx/sites-enabled;
mkdir /opt/nginx/sites-available;

wget -O /opt/nginx/sites-available/gamocosm.conf https://raw.githubusercontent.com/Gamocosm/Gamocosm/release/sysadmin/nginx.conf
ln -s /opt/nginx/sites-available/gamocosm.conf /opt/nginx/sites-enabled/gamocosm.conf

wget -O /etc/systemd/system/nginx.service https://raw.githubusercontent.com/Gamocosm/Gamocosm/release/sysadmin/nginx.service
wget -O /etc/systemd/system/gamocosm-sidekiq.service https://raw.githubusercontent.com/Gamocosm/Gamocosm/release/sysadmin/sidekiq.service

adduser -m http

# which better?
#su -l http -c 'gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB'
su -l http -c 'curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -'
su -l http -c 'curl -sSL https://get.rvm.io | bash -s stable'
su -l http -c "rvm install $RUBY_VERSION"
su -l http -c "rvm use --default $RUBY_VERSION"

su -l http -c 'ssh-keygen -t rsa'

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
chown -R http:http .

sudo -u http gem install bundler
su - http -c "cd $(pwd) && bundle install --deployment"

SECRET_KEY_BASE="$(su - http -c "cd $(pwd) && bundle exec rake secret")"
echo "Generated secret key base $SECRET_KEY_BASE"
DEVISE_SECRET_KEY="$(su - http -c "cd $(pwd) && bundle exec rake secret")"
echo "Generated Devise secret key $DEVISE_SECRET_KEY"
read -p "Please fill in the information in env.sh (press any key to continue)... "

sed -i "/SECRET_KEY_BASE/ s/=.*$/=$SECRET_KEY_BASE/" env.sh
sed -i "/DEVISE_SECRET_KEY/ s/=.*$/=$DEVISE_SECRET_KEY/" env.sh
vi env.sh

su - http -c "cd $(pwd) && RAILS_ENV=production ./run.sh --bundler rake db:setup"

su - http -c "cd $(pwd) && RAILS_ENV=production ./run.sh --bundler rake assets:precompile"

#OUTDOORS_IP_ADDRESS=$(ifconfig | grep -m 1 "inet" | awk "{ print \$2 }")
#echo "$OUTDOORS_IP_ADDRESS gamocosm.com" >> /etc/hosts

systemctl enable gamocosm-sidekiq
systemctl start gamocosm-sidekiq

systemctl enable nginx
systemctl start nginx

systemctl start firewalld

firewall-cmd --add-service=http
firewall-cmd --add-service=https
firewall-cmd --permanent --add-service=https

# let's encrypt
# - see https://certbot.eff.org/#fedora24-other
certbot certonly

echo "Done!"
