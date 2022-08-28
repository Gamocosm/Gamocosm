#!/usr/bin/env bash

# last updated: 2022 aug 27 for Fedora 36

# TODO: redis unix socket

set -ex

POSTGRESQL_VERSION=14.5
REDIS_VERSION=7.0

GAMOCOSM_NETWORK=gamocosm-network
GAMOCOSM_IMAGE=gamocosm-image

SWAP=/swapfile
SWAP_SIZE=1g

function release {
	read -p "Hit enter to continue (exit to return to script)... "
	bash
}

echo 'Please enter a new SSH port (will be changed at the very end):'
read SSH_PORT

echo 'Please enter the directory (in the home folder) containing restore files (empty for new setup):'
read -e RESTORE_DIR

echo 'Please enter the timezone file:'
read -e TIMEZONE

SSH_PRIVATE_KEY="$(realpath "$RESTORE_DIR/id_ed25519")"
SSH_PUBLIC_KEY="$SSH_PRIVATE_KEY.pub"
DB_SCRIPT="$(realpath "$RESTORE_DIR/gamocosm_restore.sql")"
ENV_SCRIPT="$(realpath "$RESTORE_DIR/gamocosm.env")"

if [ ! -z "$RESTORE_DIR" ]; then
	echo "Looking for SSH private key in: $SSH_PRIVATE_KEY"
	if [ -f "$SSH_PRIVATE_KEY" ]; then
		echo 'Found.'
	else
		echo 'Not found.'
		exit 1
	fi
	echo "Looking for SSH public key in: $SSH_PUBLIC_KEY"
	if [ -f "$SSH_PUBLIC_KEY" ]; then
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

if [ -z "$TIMEZONE" ]; then
	echo 'Timezone file not found.'
	exit 1
fi

echo 'Updating the system...'
#dnf -y upgrade > >(tee dnf-upgrade.stdout.log) 2> >(tee dnf-upgrade.stderr.log)

echo 'Setting the timezone...'
unlink /etc/localtime
ln -s "$TIMEZONE" /etc/localtime

echo 'Installing basic tools...'
dnf -y install vim tmux git htop
echo 'Installing services...'
dnf -y install firewalld
echo 'Installing podman for containers...'
dnf -y install podman
echo 'Installing nginx and related tools...'
dnf -y install nginx certbot certbot-nginx
echo 'Installing miscellaneous tools (semanage, audit2allow, pg_dump)...'
dnf -y install policycoreutils-python-utils postgresql

echo 'Enabling firewall...'
systemctl enable --now firewalld

echo 'Setting up dotfiles...'
git clone https://github.com/Raekye/dotfiles.git ~/dotfiles
ln -s ~/dotfiles/vim ~/.vim
ln -s ~dotfiles/tmux ~/.tmux.conf
~/.vim/setup.sh

echo 'Creating/copying ssh keys...'
if [ -z "$RESTORE_DIR" ]; then
	ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
else
	cp "$SSH_PRIVATE_KEY" ~/.ssh/id_ed25519
	cp "$SSH_PUBLIC_KEY" ~/.ssh/id_ed25519.pub
fi

echo 'Cloning Gamocosm repository...'
git clone https://github.com/Gamocosm/Gamocosm.git gamocosm

pushd gamocosm

cp ~/.ssh/id_ed25519 id_gamocosm
cp ~/.ssh/id_ed25519.pub id_gamocosm.pub

cp sysadmin/nginx.conf /etc/nginx/conf.d/gamocosm.conf
cp sysadmin/podman@.service /etc/systemd/system/podman@.service
cp sysadmin/daily.service /etc/systemd/system/gamocosm-daily.service
cp sysadmin/daily.timer /etc/systemd/system/gamocosm-daily.timer

if [ -z "$RESTORE_DIR" ]; then
	cp template.env gamocosm.env
	echo "Please update 'gamocosm.env'."
	release
else
	cp "$ENV_SCRIPT" gamocosm.env
fi

source gamocosm.env

mkdir backups

echo 'Creating containers...'
podman network create "$GAMOCOSM_NETWORK"

podman build --tag localhost/gamocosm --file podman/Containerfile .

podman create --name "$DATABASE_HOST" --network "$GAMOCOSM_NETWORK" --publish 127.0.0.1:5433:5432 --env "POSTGRES_USER=$DATABASE_USER" --env "POSTGRES_PASSWORD=$DATABASE_PASSWORD" "docker.io/postgres:$POSTGRESQL_VERSION"

podman create --name "$SIDEKIQ_REDIS_HOST" --network "$GAMOCOSM_NETWORK" "docker.io/redis:$REDIS_VERSION"

podman create --name "$CACHE_REDIS_HOST" --network "$GAMOCOSM_NETWORK" "docker.io/redis:$REDIS_VERSION"

systemctl enable --now "podman@$DATABASE_HOST"
systemctl enable --now "podman@$SIDEKIQ_REDIS_HOST"
systemctl enable --now "podman@$CACHE_REDIS_HOST"

if [ -z "$RESTORE_DIR" ]; then
	podman run --rm --network "$GAMOCOSM_NETWORK" --env-file gamocosm.env --env RAILS_ENV=production localhost/gamocosm rails db:setup
else
	podman run --rm --network "$GAMOCOSM_NETWORK" --env-file gamocosm.env --env RAILS_ENV=production localhost/gamocosm rails db:create
	podman exec "$DATABASE_HOST" psql gamocosm_production < "$DB_SCRIPT"
fi

podman create --name gamocosm-puma --network "$GAMOCOSM_NETWORK" --publish 127.0.0.1:9293:9292 --env-file gamocosm.env --env RAILS_ENV=production localhost/gamocosm puma --config config/puma.rb

podman create --name gamocosm-sidekiq --network "$GAMOCOSM_NETWORK" --env-file gamocosm.env --env RAILS_ENV=production localhost/gamocosm sidekiq --config config/sidekiq.yml

systemctl enable --now "podman@gamocosm-puma"
systemctl enable --now "podman@gamocosm-sidekiq"
systemctl enable --now "gamocosm-daily.timer"

popd

mkdir /usr/share/gamocosm
podman exec --env-file gamocosm.env gamocosm-puma rails assets:precompile
podman cp gamocosm-puma:/gamocosm/public /usr/share/gamocosm/

firewall-cmd --add-service=http
firewall-cmd --add-service=http --permanent
firewall-cmd --add-service=https
firewall-cmd --add-service=https --permanent

pushd /etc/nginx

cp nginx.conf nginx.conf.vanilla
echo "Update default server block in 'nginx.conf'."
release

systemctl enable --now nginx

popd

echo 'Setup letsencrypt/certbot.'
release

echo 'Changing ssh port...'

<< EOF cat > /etc/ssh/sshd_config.d/01-gamocosm.conf
Port $SSH_PORT
PasswordAuthentication no
PermitRootLogin no
EOF

semanage port -a -t ssh_port_t -p tcp "$SSH_PORT"
firewall-cmd "--add-port=$SSH_PORT/tcp"
firewall-cmd "--add-port=$SSH_PORT/tcp" --permanent
systemctl restart sshd

echo 'Done!'
