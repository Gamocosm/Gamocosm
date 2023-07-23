#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"

cd ..

systemctl stop container-gamocosm-puma container-gamocosm-sidekiq container-gamocosm-dns || true

podman rm --ignore gamocosm-puma
podman rm --ignore gamocosm-sidekiq
podman rm --ignore gamocosm-dns

podman create \
	--name gamocosm-puma --network gamocosm-network \
	--env-file gamocosm.env \
	--env "GIT_HEAD=$(git rev-parse HEAD)" \
	--env "GIT_HEAD_TIMESTAMP=$(git show --no-patch --format=%ct HEAD)" \
	--secret gamocosm-ssh-key,type=mount,target=/gamocosm/id_gamocosm,mode=0400 \
	--publish 127.0.0.1:9293:9292/tcp \
	gamocosm-image:latest \
	bundle exec puma --config config/puma.rb

podman create \
	--name gamocosm-sidekiq --network gamocosm-network \
	--env-file gamocosm.env \
	--secret gamocosm-ssh-key,type=mount,target=/gamocosm/id_gamocosm,mode=0400 \
	gamocosm-image:latest \
	bundle exec sidekiq --config config/sidekiq.yml

podman create \
	--name gamocosm-dns --network gamocosm-network \
	--env-file gamocosm.env \
	--publish 127.0.0.1:5353:5353/tcp \
	--publish 127.0.0.1:5353:5353/udp \
	gamocosm-image:latest \
	bundle exec rails runner scripts/dns.rb

rm -rf /usr/share/gamocosm/public
podman cp gamocosm-puma:/gamocosm/public/. /usr/share/gamocosm/public

podman image prune --force

pushd /etc/systemd/system
podman generate systemd --name --restart-policy always --restart-sec 8 --files gamocosm-puma
podman generate systemd --name --restart-policy always --restart-sec 8 --files gamocosm-sidekiq
podman generate systemd --name --restart-policy always --restart-sec 8 --files gamocosm-dns
popd

systemctl daemon-reload
systemctl start container-gamocosm-puma container-gamocosm-sidekiq container-gamocosm-dns

systemctl restart nginx
