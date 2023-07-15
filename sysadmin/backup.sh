#!/usr/bin/env bash

set -e

cd "$HOME/backups"

podman run --rm --pod gamocosm \
	postgres:14.5 \
	pg_dump --host ${DATABASE_HOST} --port ${DATABASE_PORT} --user ${DATABASE_USER} --password ${DATABASE_PASSWORD} --format custom gamocosm_production \
	> gamocosm-latest.dump

mv gamocosm-latest.dump "gamocosm-$(date '+%Y-%m-%d.%H-%M-%S').dump"

find . -type f -printf '%T+ %p\n' | sort -r | awk 'NR > 30' | xargs -L1 rm
