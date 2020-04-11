#!/bin/bash

set -e

if [[ "$USER" != gamocosm ]]; then
	echo 'Should be run as gamocosm.'
	exit 1
fi

PATH="$HOME/.rbenv/bin:$PATH"
PATH="$HOME/.rbenv/shims:$PATH"

cd "$HOME/gamocosm"

git checkout release
git pull origin release

RAILS_ENV=production ./sysadmin/run.sh bundle install
rbenv rehash
RAILS_ENV=production ./sysadmin/run.sh bundle exec rake db:migrate
RAILS_ENV=production ./sysadmin/run.sh bundle exec rake assets:precompile

rm -rf /usr/share/gamocosm/public
cp -r public /usr/share/gamocosm/public

echo "Remember to restart the Gamocosm Puma and Sidekiq service!"
