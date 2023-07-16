#!/usr/bin/env bash

cd "$(dirname "$0")"

cd ..

podman build \
	--tag gamocosm-image:latest \
	--env "GIT_HEAD=$(git rev-parse HEAD)" \
	--env "GIT_HEAD_TIMESTAMP=$(git show --no-patch --format=%ct HEAD)" \
	.
