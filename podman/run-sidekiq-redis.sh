#!/usr/bin/env bash

cd "$(dirname "$0")"

source podman.env
podman run --detach --rm --name "$SIDEKIQ_REDIS_HOST" --network gamocosm-network docker.io/redis:6.2.6
