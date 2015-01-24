#!/bin/bash

set -e

if [[ "$USER" != "http" ]]; then
	echo "Should be run as http"
	exit 1
fi

cd /var/www/gamocosm

git checkout release
git pull origin release

RAILS_ENV=production ./env.sh --bundler rake assets:precompile
RAILS_ENV=production ./env.sh --bundler rake db:migrate
RAILS_ENV=test ./env.sh rake db:migrate
./env.sh rake db:migrate

touch tmp/restart.txt

echo "Remember to restart the Gamocosm Sidekiq service!"
