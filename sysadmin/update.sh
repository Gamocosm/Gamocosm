#!/bin/bash

set -e

if [[ "$USER" != "http" ]]; then
	echo "Should be run as http"
	exit 1
fi

cd /var/www/gamocosm

git checkout release
git pull origin release

RAILS_ENV=production ./env.sh --bundler rake assets:precompile db:migrate

touch tmp/restart.txt
