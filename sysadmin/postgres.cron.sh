#!/usr/bin/env bash

cd "$HOME/backups"
pg_dump gamocosm_production > "gamocosm_production.backup.$(date '+%Y-%m-%d.%H-%M').sql"
