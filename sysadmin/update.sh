#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"

cd ..

git pull origin master

systemctl stop container-gamocosm-puma container-gamocosm-sidekiq || true

podman rm --ignore gamocosm-puma
podman rm --ignore gamocosm-sidekiq

podman build --tag gamocosm-image:latest .

podman image prune

podman create \
	--name gamocosm-puma --network gamocosm-network
	--env-file gamocosm.env \
	--env "GIT_HEAD=$(git rev-parse HEAD)" \
	--env "GIT_HEAD_TIMESTAMP=$(git show --no-patch --format=%ct HEAD)" \
	--secret gamocosm-ssh-key,type=mount,target=/gamocosm/id_gamocosm \
	--publish 127.0.0.1:9293:9292/tcp \
	gamocosm-image:latest \
	puma --config config/puma.rb

podman create \
	--name gamocosm-sidekiq --network gamocosm-network \
	--env-file gamocosm.env \
	--secret gamocosm-ssh-key,type=mount,target=/gamocosm/id_gamocosm \
	gamocosm-image:latest \
	sidekiq --config config/sidekiq.yml

rm -rf /usr/share/gamocosm/public
podman cp gamocosm-puma:/gamocosm/public/. /usr/share/gamocosm/public

pushd /etc/systemd/system
podman generate systemd --name --restart-policy always --restart-sec 8 --files gamocosm-puma
podman generate systemd --name --restart-policy always --restart-sec 8 --files gamocosm-sidekiq
popd

podman image prune

systemctl start container-gamocosm-puma container-gamocosm-sidekiq || true
