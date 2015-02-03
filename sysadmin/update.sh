#!/bin/bash

set -e

if [[ "$USER" != "http" ]]; then
	echo "Should be run as http"
	exit 1
fi

cd /var/www/gamocosm

git checkout release
git pull origin release

bundle install
RAILS_ENV=production ./run.sh --bundler rake assets:precompile
RAILS_ENV=production ./run.sh --bundler rake db:migrate
RAILS_ENV=test ./run.sh rake db:migrate
./run.sh rake db:migrate

touch tmp/restart.txt

echo "Remember to restart the Gamocosm Sidekiq service!"
