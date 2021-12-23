#!/usr/bin/env bash

cd "$(dirname "$0")"

podman run --rm --name gamocosm-tests --network gamocosm-network --env-file podman.env localhost/gamocosm rails test
