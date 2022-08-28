#!/usr/bin/env bash

set -e

if [[ "$USER" != gamocosm ]]; then
	echo 'Should be run as gamocosm.'
	exit 1
fi

cd ~/gamocosm

git checkout release
git pull origin release

RAILS_ENV=production ./sysadmin/run.sh bundle install
rbenv rehash
RAILS_ENV=production ./sysadmin/run.sh bundle exec rails db:migrate
RAILS_ENV=production ./sysadmin/run.sh bundle exec rails assets:precompile

rm -rf /usr/share/gamocosm/public
cp -r public /usr/share/gamocosm/public

echo "Remember to restart the Gamocosm Puma and Sidekiq service!"
