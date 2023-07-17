#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"
cd ..
source gamocosm.env

cd "$HOME/backups"

podman exec "$DATABASE_HOST" \
	pg_dump --username "$DATABASE_USER" --format custom gamocosm_production \
	> gamocosm-latest.dump

mv gamocosm-latest.dump "gamocosm.$(date '+%Y-%m-%d.%H-%M-%S').dump"

find . -type f -printf '%T+ %p\n' | sort -r | awk 'NR > 30' | xargs -L1 --no-run-if-empty rm
