#!/usr/bin/env bash

# last updated: 2023 July 14 for Fedora 38

set -ex

POSTGRESQL_VERSION=14.5
REDIS_VERSION=7.0.4

TIME_ZONE=America/New_York

function release {
	read -p 'Hit enter to continue (exit to return to script)... '
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
timedatectl set-timezone "$TIME_ZONE"

echo 'Updating the system...'
dnf -y upgrade --refresh > >(tee dnf-upgrade.stdout.log) 2> >(tee dnf-upgrade.stderr.log)

echo 'Installing basic tools...'
dnf -y install vim tmux git htop
echo 'Installing services...'
dnf -y install firewalld
echo 'Installing podman for containers...'
dnf -y install podman
echo 'Installing nginx and related tools...'
dnf -y install nginx certbot certbot-nginx
echo 'Installing miscellaneous tools (semanage, audit2allow, ncat)...'
dnf -y install policycoreutils-python-utils nmap-ncat

echo 'Setting up dotfiles...'
git clone https://github.com/Raekye/dotfiles.git ~/dotfiles
ln -s ~/dotfiles/vim ~/.vim
ln -s ~/dotfiles/tmux ~/.tmux.conf
~/.vim/setup.sh

echo 'Creating swapfile...'
# https://btrfs.readthedocs.io/en/latest/Swapfile.html
btrfs filesystem mkswap --size 1G /swapfile
swapon /swapfile
echo '/swapfile none swap defaults 0 0' >> /etc/fstab
systemctl daemon-reload

if [ -z "$RESTORE_DIR" ]; then
	echo 'Creating SSH keys...'
	ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
else
	echo 'Copying SSH keys...'
	cp "$SSH_PRIVATE_KEY" ~/.ssh/id_ed25519
	ssh-keygen -y -f ~/.ssh/id_ed25519
fi

echo 'Creating some directories in advance...'
mkdir "$HOME/backups"
mkdir /usr/share/gamocosm
mkdir /usr/share/gamocosm/public
mkdir /usr/share/gamocosm/blog

echo 'Cloning Gamocosm repository...'
git clone https://github.com/Gamocosm/Gamocosm.git gamocosm

pushd gamocosm

echo 'Symlinking systemd units...'
ln -s "$(pwd)/sysadmin/daily.service" /etc/systemd/system/gamocosm-daily.service
ln -s "$(pwd)/sysadmin/daily.timer" /etc/systemd/system/gamocosm-daily.timer
ln -s "$(pwd)/sysadmin/dns-tcp.service" /etc/systemd/system/gamocosm-dns-tcp.service
ln -s "$(pwd)/sysadmin/dns-udp.service" /etc/systemd/system/gamocosm-dns-udp.service

echo 'Symlinking local scripts...'
ln -s "$(pwd)/sysadmin/backup.sh" /usr/local/bin/gamocosm-backup
ln -s "$(pwd)/sysadmin/console.sh" /usr/local/bin/gamocosm-console

echo 'Setting up gamocosm.env...'
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

pushd /etc/containers/systemd

ln -s ~/gamocosm/sysadmin/gamocosm-database.container
mkdir gamocosm-database.container.d
cat > gamocosm-database.container.d/50-hostname.conf << EOF
[Container]
HostName=$DATABASE_HOST

Environment=POSTGRES_USER='$DATABASE_USER' POSTGRES_PASSWORD='$DATABASE_PASSWORD'
EOF

ln -s ~/gamocosm/sysadmin/gamocosm-redis.container
mkdir gamocosm-redis.container.d
cat > gamocosm-redis.container.d/50-hostname.conf << EOF
[Container]
HostName=$REDIS_HOST
EOF

popd

systemctl enable --now "$DATABASE_HOST" "container-$REDIS_HOST"

podman secret create gamocosm-ssh-key ~/.ssh/id_ed25519

podman build --tag gamocosm-image:latest .

if [ -z "$RESTORE_DIR" ]; then
	podman run --rm --network gamocosm-network --env-file gamocosm.env gamocosm-image rails db:setup
else
	podman run --rm --network gamocosm-network --env-file gamocosm.env gamocosm-image rails db:create
	podman exec "$DATABASE_HOST" pg_restore gamocosm_production < "$DB_SCRIPT"
fi

./sysadmin/update.sh --skip-load
# update.sh already starts these following services.
systemctl enable container-gamocosm-puma container-gamocosm-sidekiq

popd

echo 'Copying main nginx configuration...'
cp ~/gamocosm/sysadmin/nginx.conf /etc/nginx/conf.d/gamocosm.conf

echo 'Starting nginx...'
nginx -t
systemctl enable --now nginx

echo 'Setting up TLS certificates...'
certbot run --nginx

echo 'Copying catchall nginx configuration and restarting nginx...'
# This must be done after running certbot and obtaining certificate;
# see the comment in the following file(s) for more information.
cp ~/gamocosm/sysadmin/nginx-catchall.conf /etc/nginx/conf.d/catchall.conf
nginx -t
systemctl restart nginx

echo 'Enabling dns port proxying...'
systemctl enable --now gamocosm-dns-tcp
systemctl enable --now gamocosm-dns-udp

echo 'Daily services...'
# certbot-renew.{service,timer} is provided by the certbot package and enabled by default.
systemctl start certbot-renew.timer
systemctl enable --now gamocosm-daily.timer

echo 'Changing ssh port...'
cat > /etc/ssh/sshd_config.d/01-gamocosm.conf << EOF
Port $SSH_PORT
PasswordAuthentication no
EOF

semanage port -a -t ssh_port_t -p tcp "$SSH_PORT"

echo 'Restarting ssh...'
systemctl restart sshd

echo 'Adding firewall rules...'
firewall-offline-cmd --add-forward-port=port=53:toport=5354:proto=udp
firewall-offline-cmd --add-forward-port=port=53:toport=5354:proto=tcp
firewall-offline-cmd --add-service=http
firewall-offline-cmd --add-service=https
firewall-offline-cmd "--add-port=$SSH_PORT/tcp"

echo 'Enabling firewall...'
systemctl enable --now firewalld

echo 'Done!'
