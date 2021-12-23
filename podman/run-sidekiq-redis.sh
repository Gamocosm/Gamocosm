#!/usr/bin/env bash

podman run --detach --rm --name gamocosm-sidekiq-redis --network gamocosm-network docker.io/redis:6.2.6
