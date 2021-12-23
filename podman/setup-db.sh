#!/usr/bin/env bash

cd "$(dirname "$0")"

podman run --rm --network gamocosm-network --env-file podman.env localhost/gamocosm rails db:setup
