#!/usr/bin/env bash

set -e

cd ~/gamocosm

git pull origin master

systemctl stop pod-gamocosm || true

podman rm --ignore gamocosm-puma
podman rm --ignore gamocosm-sidekiq

./sysadmin/build.sh

podman create \
	--name gamocosm-puma --pod gamocosm
	--env-file gamocosm.env \
	--secret gamocosm-ssh-key,type=mount,target=/gamocosm/id_gamocosm \
	gamocosm-image:latest \
	puma --config config/puma.rb

podman create \
	--name gamocosm-sidekiq --pod gamocosm \
	--env-file gamocosm.env \
	--secret gamocosm-ssh-key,type=mount,target=/gamocosm/id_gamocosm \
	gamocosm-image:latest \
	sidekiq --config config/sidekiq.yml

rm -rf /usr/share/gamocosm/public
podman cp gamocosm-puma:/gamocosm/public/. /usr/share/gamocosm/public

pushd /etc/systemd/system
podman generate systemd --name --restart-policy always --restart-sec 8 --files gamocosm
popd

podman image prune

systemctl start pod-gamocosm
