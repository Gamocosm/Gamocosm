#!/usr/bin/env bash

# last updated: 2023 July 14 for Fedora 38

set -ex

POSTGRESQL_VERSION=14.5
REDIS_VERSION=7.0.4

TIMEZONE=America/New_York

function release {
	read -p "Hit enter to continue (exit to return to script)... "
	bash
}

echo 'Please enter a new SSH port (will be changed at the very end):'
read SSH_PORT

echo 'Please enter the directory (in the home folder) containing restore files (empty for new setup):'
read -e RESTORE_DIR

SSH_PRIVATE_KEY="$(realpath "$RESTORE_DIR/id_gamocosm")"
DB_SCRIPT="$(realpath "$RESTORE_DIR/gamocosm_restore.sql")"
ENV_FILE="$(realpath "$RESTORE_DIR/gamocosm.env")"

if [ ! -z "$RESTORE_DIR" ]; then
	echo "Looking for SSH private key in: '$SSH_PRIVATE_KEY'..."
	if [ -f "$SSH_PRIVATE_KEY" ]; then
		echo 'Found.'
	else
		echo 'Not found.'
		exit 1
	fi
	echo "Looking for DB script in: '$DB_SCRIPT'..."
	if [ -f "$DB_SCRIPT" ]; then
		echo 'Found.'
	else
		echo 'Not found.'
		exit 1
	fi
	echo "Looking for env.sh in: '$ENV_FILE'..."
	if [ -f "$ENV_FILE" ]; then
		echo 'Found.'
	else
		echo 'Not found.'
		exit 1
	fi
fi

echo 'Setting the timezone...'
timedatectl set-timezone "$TIMEZONE"

echo 'Updating the system...'
#dnf -y upgrade > >(tee dnf-upgrade.stdout.log) 2> >(tee dnf-upgrade.stderr.log)

echo 'Installing basic tools...'
dnf -y install vim tmux git htop
echo 'Installing services...'
dnf -y install firewalld
echo 'Installing podman for containers...'
dnf -y install podman
echo 'Installing nginx and related tools...'
dnf -y install nginx certbot certbot-nginx
echo 'Installing miscellaneous tools (semanage, audit2allow)...'
dnf -y install policycoreutils-python-utils

echo 'Setting up dotfiles...'
git clone https://github.com/Raekye/dotfiles.git ~/dotfiles
ln -s ~/dotfiles/vim ~/.vim
ln -s ~/dotfiles/tmux ~/.tmux.conf
~/.vim/setup.sh

if [ -z "$RESTORE_DIR" ]; then
	echo 'Creating SSH keys...'
	ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
else
	echo 'Copying SSH keys...'
	cp "$SSH_PRIVATE_KEY" ~/.ssh/id_ed25519
	ssh-keygen -y -f ~/.ssh/id_ed25519
fi

mkdir /usr/share/gamocosm
mkdir /usr/share/gamocosm/public
mkdir /usr/share/gamocosm/blog
mkdir /usr/share/gamocosm/blog.0

echo 'Cloning Gamocosm repository...'
git clone https://github.com/Gamocosm/Gamocosm.git gamocosm

pushd gamocosm

cp sysadmin/nginx.conf /etc/nginx/conf.d/gamocosm.conf
cp sysadmin/daily.service /etc/systemd/system/gamocosm-daily.service
cp sysadmin/daily.timer /etc/systemd/system/gamocosm-daily.timer

if [ -z "$RESTORE_DIR" ]; then
	cp template.env gamocosm.env
	echo "Please update 'gamocosm.env'."
	release
else
	cp "$ENV_FILE" gamocosm.env
fi

source gamocosm.env

echo 'Creating containers...'
podman network create gamocosm-network
podman pod create \
	--network gamocosm-network \
	--publish 127.0.0.1:9293:9292/tcp \
	gamocosm

podman create \
	--name "$DATABASE_HOST" --pod gamocosm \
	--env "POSTGRES_USER=$DATABASE_USER" --env "POSTGRES_PASSWORD=$DATABASE_PASSWORD" \
	"docker.io/postgres:$POSTGRESQL_VERSION"

podman create \
	--name "$SIDEKIQ_REDIS_HOST" --pod gamocosm \
	"docker.io/redis:$REDIS_VERSION"

podman create \
	--name "$CACHE_REDIS_HOST" --pod gamocosm \
	"docker.io/redis:$REDIS_VERSION"

podman secret create gamocosm-ssh-key ~/.ssh/id_ed25519

mkdir "$HOME/backups"

./sysadmin/update.sh

if [ -z "$RESTORE_DIR" ]; then
	podman run --rm --pod gamocosm --env-file gamocosm.env gamocosm-image rails db:setup
else
	podman run --rm --pod gamocosm --env-file gamocosm.env gamocosm-image rails db:create
	podman exec "$DATABASE_HOST" psql gamocosm_production < "$DB_SCRIPT"
fi

systemctl enable pod-gamocosm

systemctl enable --now gamocosm-daily.timer

popd

pushd /etc/nginx

firewall-offline-cmd --add-service=http
firewall-offline-cmd --add-service=https

cp nginx.conf nginx.conf.vanilla
echo "Comment out default server block in 'nginx.conf'."
release

systemctl enable --now nginx

popd

echo 'Setup letsencrypt/certbot (`certbot run --nginx`).'
release

echo 'Changing ssh port...'

<< EOF cat > /etc/ssh/sshd_config.d/01-gamocosm.conf
Port $SSH_PORT
PasswordAuthentication no
EOF

semanage port -a -t ssh_port_t -p tcp "$SSH_PORT"
firewall-offline-cmd "--add-port=$SSH_PORT/tcp"

echo 'Restarting ssh...'
systemctl restart sshd

echo 'Enabling firewall...'
systemctl enable --now firewalld

echo 'Done!'
