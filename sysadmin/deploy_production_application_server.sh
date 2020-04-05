#!/bin/bash

# last updated: 2018 feb 12 for Fedora 27
# not automated:
# - root cron job restart gamocosm and sidekiq
# - root cron job certbot

set -ex

RUBY_VERSION=2.6.5

function release {
	read -p "Hit enter to continue (exit to return to script)... "
	bash -l
}

# timezone
unlink /etc/localtime
ln -s /usr/share/zoneinfo/America/New_York /etc/localtime

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
dnf -y install vim tmux git
# services
dnf -y install memcached postgresql-server postgresql-contrib libpq-devel redis firewalld
# nginx
dnf -y install nginx certbot certbot-nginx util-linux-user
# rvm
dnf install -y patch autoconf automake bison gcc-c++ glibc-headers glibc-devel libffi-devel libtool libyaml-devel make patch readline-devel sqlite-devel zlib-devel openssl-devel
# other
dnf -y install nodejs

echo 'Setup environment (e.g. vim, tmux conf)'
release

systemctl enable firewalld
systemctl start firewalld

systemctl enable redis
systemctl start redis

systemctl enable memcached
systemctl start memcached

# - see https://fedoraproject.org/wiki/PostgreSQL
postgresql-setup --initdb --unit postgresql
systemctl enable postgresql
systemctl start postgresql
su -l postgres -c 'createuser --createdb --pwprompt --superuser gamocosm'
# append after line
sed -i "/^# TYPE[[:space:]]*DATABASE[[:space:]]*USER[[:space:]]*ADDRESS[[:space:]]*METHOD/a local gamocosm_development,gamocosm_test,gamocosm_production gamocosm md5" /var/lib/pgsql/data/pg_hba.conf
echo 'Add database postgres to /var/lib/pgsql/data/pg_hba.conf to user gamocosm if setting up a new database.'
release

cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.vanilla
chsh -s /bin/bash nginx

# which better?
#su -l nginx -c 'gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB'
#su -l nginx -c 'curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -'
su -l nginx -c 'gpg2 --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB'
su -l nginx -c 'curl -sSL https://get.rvm.io | bash -s stable'
su -l nginx -c "rvm install $RUBY_VERSION"
su -l nginx -c "rvm use --default $RUBY_VERSION"

echo 'Please generate or fetch the SSH keys.'
echo "Example: su -l nginx -c 'ssh-keygen -t rsa'"
release

mkdir /var/www
cd /var/www
git clone https://github.com/Gamocosm/Gamocosm.git gamocosm
cd gamocosm
git checkout release
cp sysadmin/nginx.conf /etc/nginx/conf.d/gamocosm.conf
cp sysadmin/puma.service /etc/systemd/system/gamocosm-puma.service
cp sysadmin/sidekiq.service /etc/systemd/system/gamocosm-sidekiq.service
mkdir tmp
touch tmp/restart.txt
mkdir run
cp env.sh.template env.sh
echo 'Please update /var/www/gamocosm/env.sh'
release
chown -R nginx:nginx .

su -l nginx -c 'gem install bundler'
su -l nginx -c 'cd /var/www/gamocosm && bundle config set deployment true && bundle install'

echo 'Please setup the database.'
echo "Example: su -l nginx -c 'cd $(pwd) && RAILS_ENV=production ./run2.sh bundle exec rake db:setup"
release

su -l nginx -c 'cd /var/www/gamocosm && RAILS_ENV=production bundle exec rake assets:precompile'

OUTDOORS_IP_ADDRESS="$(ifconfig | grep -m 1 'inet' | awk '{ print $2 }')"
echo "Please update gamocosm.com entries in /etc/hosts (believe IP address is $OUTDOORS_IP_ADDRESS)."
release

systemctl enable gamocosm-puma
systemctl start gamocosm-puma

systemctl enable gamocosm-sidekiq
systemctl start gamocosm-sidekiq

echo 'Setup letsencrypt/certbot'
release

systemctl enable nginx
systemctl start nginx

echo 'Fix selinux nginx permissions.'
echo '- run curl https://gamocosm.com'
echo '- run grep nginx /var/log/audit/audit.log | audit2allow'
echo '- run grep nginx /var/log/audit/audit.log | audit2allow -m nginx'
echo '- run grep nginx /var/log/audit/audit.log | audit2allow -M nginx'
echo '- run semodule -i nginx.pp'
echo '- repeat until ok'
release

firewall-cmd --add-service=https
firewall-cmd --permanent --add-service=https

SWAP_SIZE=1g
SWAP="/mnt/$SWAP_SIZE.swap"
fallocate -l "$SWAP_SIZE" "$SWAP"
chmod 600 "$SWAP"
mkswap "$SWAP"
swapon "$SWAP"

echo 'Recommended: change ssh port.'
echo '- edit /etc/ssh/sshd_config'
echo '- run semanage port -a -t ssh_port_t -p tcp <port>'
echo '- test semanage port -l | grep ssh'
echo '- run systemctl restart sshd'
release

echo 'Done!'
