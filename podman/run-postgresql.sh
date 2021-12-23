#!/usr/bin/env bash

cd "$(dirname "$0")"

source podman.env
podman run --detach --rm --name "$DATABASE_HOST" --network gamocosm-network --env "POSTGRES_USER=$DATABASE_USER" --env "POSTGRES_PASSWORD=$DATABASE_PASSWORD" docker.io/postgres:13.5
