#!/bin/bash

# last updated: 2020 apr 06 for Fedora 31

# TODO: firewalld cockpit service
#       - see https://bugzilla.redhat.com/show_bug.cgi?id=1171114
# TODO: redis unix socket
# TODO: certbot

set -ex

RUBY_VERSION=2.6.5
SWAP_SIZE=1g
SWAP=/swapfile

function release {
	read -p "Hit enter to continue (exit to return to script)... "
	bash -l
}

cd "$HOME"

# timezone
unlink /etc/localtime
ln -s /usr/share/zoneinfo/America/New_York /etc/localtime

dnf -y upgrade

# see https://wiki.archlinux.org/index.php/Swap
fallocate -l "$SWAP_SIZE" "$SWAP"
chmod 600 "$SWAP"
mkswap "$SWAP"
swapon "$SWAP"
echo "$SWAP none swap defaults,pri=0 0 0" >> /etc/fstab

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

git clone https://github.com/Raekye/dotfiles.git
ln -s "$(pwd)/dotfiles/vim" "$HOME/.vim"
ln -s "$(pwd)/dotfiles/tmux" "$HOME/.tmux.conf"

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
pushd /var/lib/pgsql/data
echo 'Add database postgres to /var/lib/pgsql/data/pg_hba.conf to user gamocosm if setting up a new database.'
release
popd
systemctl restart postgresql

cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.vanilla

adduser gamocosm
cp -r "$HOME/.ssh" /home/gamocosm/.ssh
chown -R gamocosm:gamocosm /home/gamocosm/.ssh
su -l gamocosm -c 'cd $HOME && git clone https://github.com/Raekye/dotfiles.git'
su -l gamocosm -c 'ln -s "$HOME/dotfiles/vim" "$HOME/.vim"'
su -l gamocosm -c 'ln -s "$HOME/dotfiles/tmux" "$HOME/.tmux.conf"'

echo 'Please generate or fetch the SSH keys.'
echo "Example: su -l gamocosm -c 'ssh-keygen -t rsa'"
release

# which better?
#su -l gamocosm -c 'gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB'
#su -l gamocosm -c 'curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -'
su -l gamocosm -c 'gpg2 --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB'
su -l gamocosm -c 'curl -sSL https://get.rvm.io | bash -s stable'
su -l gamocosm -c "rvm install $RUBY_VERSION"
su -l gamocosm -c "rvm use --default $RUBY_VERSION"

pushd /home/gamocosm
git clone https://github.com/Gamocosm/Gamocosm.git gamocosm
pushd gamocosm
#git checkout release
cp sysadmin/nginx.conf /etc/nginx/conf.d/gamocosm.conf
cp sysadmin/run.sh /usr/local/bin/gamocosm-run.sh
cp sysadmin/puma.service /etc/systemd/system/gamocosm-puma.service
cp sysadmin/sidekiq.service /etc/systemd/system/gamocosm-sidekiq.service
cp env.sh.template env.sh
echo "Please update $(pwd)/env.sh"
release
chown -R gamocosm:gamocosm .

su -l gamocosm -c 'gem install bundler'
su -l gamocosm -c "cd $(pwd) && bundle config set deployment true && bundle install"

echo 'Please setup the database.'
echo "Example: su -l gamocosm -c 'cd $(pwd) && RAILS_ENV=production ./sysadmin/run.sh bundle exec rake db:setup'"
release

su -l gamocosm -c "cd $(pwd) && RAILS_ENV=production ./sysadmin/run.sh bundle exec rake assets:precompile"
mkdir /usr/share/gamocosm
chown gamocosm:gamocosm /usr/share/gamocosm
su -l gamocosm -c "cp -r $(pwd)/public /usr/share/gamocosm/public"

mkdir /var/run/gamocosm
chown gamocosm:gamocosm /var/run/gamocosm

mkdir "$HOME/gamocosm"
echo "0 6 * * * $(pwd)/sysadmin/cron.sh > $HOME/gamocosm/cron.stdout.txt 2> $HOME/gamocosm/cron.stderr.txt" | crontab -

POSTGRES_HOME="$(su -l postgres -c 'echo $HOME')"
POSTGRES_CRON="$POSTGRES_HOME/gamocosm/cron.sh"
mkdir "$POSTGRES_HOME/gamocosm"
cp sysadmin/postgres.cron.sh "$POSTGRES_CRON"
chown postgres:postgres "$POSTGRES_CRON"
su -l postgres -c "echo '0 0 * * 0 $POSTGRES_CRON' | crontab -"

popd
popd

OUTDOORS_IP_ADDRESS="$(ifconfig | grep -m 1 'inet' | awk '{ print $2 }')"
echo "Please update gamocosm.com entries in /etc/hosts (believe IP address is $OUTDOORS_IP_ADDRESS)."
release

systemctl enable gamocosm-puma
systemctl start gamocosm-puma

systemctl enable gamocosm-sidekiq
systemctl start gamocosm-sidekiq

firewall-cmd --add-service=http
firewall-cmd --add-service=http --permanent
firewall-cmd --add-service=https
firewall-cmd --add-service=https --permanent

systemctl enable nginx
systemctl start nginx

echo 'Setup letsencrypt/certbot'
release

mkdir selinux
pushd selinux

if false; then

mkdir 1
pushd 1
curl http://gamocosm.com
grep nginx /var/log/audit/audit.log | audit2allow
grep nginx /var/log/audit/audit.log | audit2allow -m nginx
grep nginx /var/log/audit/audit.log | audit2allow -M nginx
semodule -i nginx.pp
popd

mkdir 2
pushd 2
curl http://gamocosm.com
grep nginx /var/log/audit/audit.log | audit2allow
grep nginx /var/log/audit/audit.log | audit2allow -m nginx
grep nginx /var/log/audit/audit.log | audit2allow -M nginx
semodule -i nginx.pp
popd

fi

echo 'Fix selinux.'
release

popd

echo 'Recommended: change ssh port.'
echo '- edit /etc/ssh/sshd_config'
echo '- run semanage port -a -t ssh_port_t -p tcp <port>'
echo '- test semanage port -l | grep ssh'
echo '- run firewall-cmd --add-port=<port>/tcp'
echo '- run firewall-cmd --add-port=<port>/tcp --permanent'
echo '- run systemctl restart sshd'
release

echo 'Done!'
