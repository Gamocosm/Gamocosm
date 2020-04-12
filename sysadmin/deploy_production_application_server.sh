#!/usr/bin/env bash

# last updated: 2020 apr 11 for Fedora 31

# TODO: redis unix socket

set -ex

RUBY_VERSION=2.6.5
SWAP_SIZE=1g
SWAP=/swapfile

function release {
	read -p "Hit enter to continue (exit to return to script)... "
	bash -l
}

cd "$HOME"

# make sure cron is installed
crontab -V

echo 'Please enter a new SSH port (will be changed at the very end):'
read SSH_PORT

echo 'Please enter the directory (in the home folder) containing restore files (empty for new setup):'
read RESTORE_DIR

SSH_PUBLIC_KEY="$HOME/$RESTORE_DIR/id_rsa.pub"
SSH_PRIVATE_KEY="$HOME/$RESTORE_DIR/id_rsa"
DB_SCRIPT="$HOME/$RESTORE_DIR/gamocosm_restore.sql"
ENV_SCRIPT="$HOME/$RESTORE_DIR/env.sh"

if [ ! -z "$RESTORE_DIR" ]; then
	echo "Looking for SSH public key in: $SSH_PUBLIC_KEY"
	if [ -f "$SSH_PUBLIC_KEY" ]; then
		echo 'Found.'
	else
		echo 'Not found.'
		exit 1
	fi
	echo "Looking for SSH private key in: $SSH_PRIVATE_KEY"
	if [ -f "$SSH_PRIVATE_KEY" ]; then
		echo 'Found.'
	else
		echo 'Not found.'
		exit 1
	fi
	echo "Looking for DB script in: $DB_SCRIPT"
	if [ -f "$DB_SCRIPT" ]; then
		echo 'Found.'
	else
		echo 'Not found.'
		exit 1
	fi
	echo "Looking for env.sh in: $ENV_SCRIPT"
	if [ -f "$ENV_SCRIPT" ]; then
		echo 'Found.'
	else
		echo 'Not found.'
		exit 1
	fi
fi

# timezone
unlink /etc/localtime
ln -s /usr/share/zoneinfo/America/New_York /etc/localtime

dnf -y upgrade > >(tee dnf-upgrade.stdout.log) 2> >(tee dnf-upgrade.stderr.log)

# see https://wiki.archlinux.org/index.php/Swap
fallocate -l "$SWAP_SIZE" "$SWAP"
chmod 600 "$SWAP"
mkswap "$SWAP"
swapon "$SWAP"
echo "$SWAP none swap defaults,pri=0 0 0" >> /etc/fstab

# basic tools
dnf -y install vim tmux git htop
# services
dnf -y install memcached postgresql-server postgresql-contrib libpq-devel redis firewalld
# nginx
dnf -y install nginx certbot certbot-nginx
# rvm
#dnf install -y patch autoconf automake bison gcc-c++ glibc-headers glibc-devel libffi-devel libtool libyaml-devel make patch readline-devel sqlite-devel zlib-devel openssl-devel
# rbenv
dnf -y install gcc gcc-c++ make openssl-devel readline-devel zlib-devel
# other
dnf -y install nodejs
# for audit2allow
dnf -y install policycoreutils-python-utils

systemctl daemon-reload

git clone https://github.com/Raekye/dotfiles.git
"$(pwd)/dotfiles/vim/setup.sh"
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
NEEDS_POSTGRES=''
if [ -z "$RESTORE_DIR" ]; then
	NEEDS_POSTGRES='postgres,'
fi
sed -i "/^# TYPE[[:space:]]*DATABASE[[:space:]]*USER[[:space:]]*ADDRESS[[:space:]]*METHOD/a local ${NEEDS_POSTGRES}gamocosm_development,gamocosm_test,gamocosm_production gamocosm md5" /var/lib/pgsql/data/pg_hba.conf
systemctl restart postgresql

cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.vanilla

adduser gamocosm
cp -r "$HOME/.ssh" /home/gamocosm/.ssh
if [ -z "$RESTORE_DIR" ]; then
	chown -R gamocosm:gamocosm /home/gamocosm/.ssh
	su -P -l gamocosm -c 'ssh-keygen -t rsa'
else
	cp "$SSH_PUBLIC_KEY" /home/gamocosm/.ssh/id_rsa.pub
	cp "$SSH_PRIVATE_KEY" /home/gamocosm/.ssh/id_rsa
	chown -R gamocosm:gamocosm /home/gamocosm/.ssh
fi
su -l gamocosm -c 'cd $HOME && git clone https://github.com/Raekye/dotfiles.git'
su -l gamocosm -c 'cd $HOME/dotfiles && ./vim/setup.sh'
su -l gamocosm -c 'ln -s "$HOME/dotfiles/vim" "$HOME/.vim"'
su -l gamocosm -c 'ln -s "$HOME/dotfiles/tmux" "$HOME/.tmux.conf"'

su -l gamocosm -c 'git clone https://github.com/rbenv/rbenv.git "$HOME/.rbenv"'
su -l gamocosm -c 'git clone https://github.com/rbenv/ruby-build.git "$HOME/.rbenv/plugins/ruby-build"'
su -l gamocosm -c "echo 'PATH=\"\$HOME/.rbenv/bin:\$PATH\"' >> \$HOME/.bash_profile"
su -l gamocosm -c "echo 'PATH=\"\$HOME/.rbenv/shims:\$PATH\"' >> \$HOME/.bash_profile"
su -l gamocosm -c "rbenv install $RUBY_VERSION"

pushd /home/gamocosm
git clone https://github.com/Gamocosm/Gamocosm.git gamocosm
pushd gamocosm
#git checkout release
cp sysadmin/nginx.conf /etc/nginx/conf.d/gamocosm.conf
cp sysadmin/run.sh /usr/local/bin/gamocosm-run.sh
cp sysadmin/puma.service /etc/systemd/system/gamocosm-puma.service
cp sysadmin/sidekiq.service /etc/systemd/system/gamocosm-sidekiq.service
if [ -z "$RESTORE_DIR" ]; then
	cp env.sh.template env.sh
	echo "Please update $(pwd)/env.sh"
	release
else
	cp "$ENV_SCRIPT" env.sh
fi
chmod 600 env.sh
chown -R gamocosm:gamocosm .

su -l gamocosm -c "cd $(pwd) && gem install bundler"
su -l gamocosm -c "cd $(pwd) && bundle config set deployment true && bundle install"

POSTGRES_HOME="$(su -l postgres -c 'echo $HOME')"
POSTGRES_GAMOCOSM="$POSTGRES_HOME/gamocosm"
POSTGRES_RESTORE="$POSTGRES_GAMOCOSM/gamocosm_restore.$(date +'%Y-%m-%d').sql"
mkdir "$POSTGRES_GAMOCOSM"
chown postgres:postgres "$POSTGRES_GAMOCOSM"
if [ -z "$RESTORE_DIR" ]; then
	su -l gamocosm -c "cd $(pwd) && RAILS_ENV=production ./sysadmin/run.sh bundle exec rake db:setup"
else
	cp "$DB_SCRIPT" "$POSTGRES_RESTORE"
	chown postgres:postgres "$POSTGRES_RESTORE"
	su -l postgres -c 'psql -c "create database gamocosm_production owner gamocosm;"'
	su -l postgres -c "psql gamocosm_production < $POSTGRES_RESTORE"
fi

su -l gamocosm -c "cd $(pwd) && RAILS_ENV=production ./sysadmin/run.sh bundle exec rake assets:precompile"
mkdir /usr/share/gamocosm
chown gamocosm:gamocosm /usr/share/gamocosm
su -l gamocosm -c "cp -r $(pwd)/public /usr/share/gamocosm/public"

mkdir "$HOME/gamocosm"
mkdir "$HOME/certbot"
echo "0 6 * * * $(pwd)/sysadmin/cron.sh >> $HOME/gamocosm/cron.stdout.txt 2>> $HOME/gamocosm/cron.stderr.txt" | crontab -

POSTGRES_CRON="$POSTGRES_GAMOCOSM/cron.sh"
cp sysadmin/postgres.cron.sh "$POSTGRES_CRON"
chown postgres:postgres "$POSTGRES_CRON"
su -l postgres -c "echo '0 0 * * 0 $POSTGRES_CRON >> $POSTGRES_GAMOCOSM/cron.stdout.txt 2>> $POSTGRES_GAMOCOSM/cron.stderr.txt' | crontab -"

popd
popd

OUTDOORS_IP_ADDRESS="$(ifconfig | grep -m 1 'inet' | awk '{ print $2; }')"
OUTDOORS_IPV6_ADDRESS="$(ifconfig | grep -m 1 'inet6.*global' | awk '{ print $2; }')"
echo "Believe IP addresses are $OUTDOORS_IP_ADDRESS (v4) and $OUTDOORS_IPV6_ADDRESS (v6)."
sed -i '/127.0.0.1 gamocosm.com gamocosm/ s/^/#/' /etc/hosts
sed -i '/::1 gamocosm.com gamocosm/ s/^/#/' /etc/hosts
echo "$OUTDOORS_IP_ADDRESS gamocosm.com" >> /etc/hosts
echo "$OUTDOORS_IPV6_ADDRESS gamocosm.com" >> /etc/hosts

systemctl enable gamocosm-puma
systemctl start gamocosm-puma

systemctl enable gamocosm-sidekiq
systemctl start gamocosm-sidekiq

systemctl enable nginx
systemctl start nginx

mkdir selinux
pushd selinux

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

popd

pushd /etc/nginx
echo 'Update default server block from /etc/nginx/nginx.conf'
release
popd
systemctl restart nginx

firewall-cmd --add-service=http
firewall-cmd --add-service=http --permanent
firewall-cmd --add-service=https
firewall-cmd --add-service=https --permanent

echo 'Setup letsencrypt/certbot.'
release

systemctl enable crond
systemctl start crond

sed -i "/^#Port 22/a Port $SSH_PORT" /etc/ssh/sshd_config
semanage port -a -t ssh_port_t -p tcp "$SSH_PORT"
semanage port -l | grep ssh
firewall-cmd "--add-port=$SSH_PORT/tcp"
firewall-cmd "--add-port=$SSH_PORT/tcp" --permanent
systemctl restart sshd

echo 'Done!'
