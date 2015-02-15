#!/bin/bash

set -e

if [[ "$USER" != "http" ]]; then
	echo "Should be run as http"
	exit 1
fi

cd /var/www/gamocosm

git checkout release
git pull origin release

rvm use 2.2
bundle install
RAILS_ENV=production ./run.sh --bundler rake assets:precompile
RAILS_ENV=production ./run.sh --bundler rake db:migrate
RAILS_ENV=test ./run.sh rake db:migrate
./run.sh rake db:migrate

TIMESTAMP="$(date +'%Y_%m_%d-%H:%M')"
mv log/production.log "log/production.$TIMESTAMP.log"
mv log/sidekiq.log "log/sidekiq.$TIMESTAMP.log"

touch tmp/restart.txt

echo "Remember to restart the Gamocosm Sidekiq service!"
