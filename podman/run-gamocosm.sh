#!/usr/bin/env bash

cd "$(dirname "$0")"

podman run --rm --interactive --tty --network gamocosm-network --env-file podman.env localhost/gamocosm "$@"
