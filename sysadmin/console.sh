#!/usr/bin/env bash

set -e

cd "$(dirname "$(realpath "$0")")"
cd ..

exec podman run \
	--rm --interactive --tty \
	--network gamocosm-network \
	--env-file gamocosm.env \
	--secret gamocosm-ssh-key,type=mount,target=/gamocosm/id_gamocosm,mode=0400 \
	gamocosm-image:latest \
	bundle exec rails c
