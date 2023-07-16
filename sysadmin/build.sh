#!/usr/bin/env bash

cd "$(dirname "$0")"

cd ..

source load_env.sh

podman build \
	--tag gamocosm-image:latest \
	--env "GIT_HEAD=$(git rev-parse HEAD)" \
	--env "GIT_HEAD_TIMESTAMP=$(git show --no-patch --format=%ct HEAD)" \
	--build-arg "secret_key_base=$SECRET_KEY_BASE" \
	--secret id=gamocosm-ssh-key,src=id_gamocosm \
	.
