#!/bin/bash

set -e

if [[ "$USER" != gamocosm ]]; then
	echo 'Should be run as gamocosm'
	exit 1
fi

cd "$HOME/gamocosm"

git checkout release
git pull origin release

RAILS_ENV=production ./sysadmin/run.sh bundle instasll
RAILS_ENV=production ./sysadmin/run.sh bundle exec rake assets:precompile
RAILS_ENV=production ./sysadmin/run.sh bundle exec rake db:migrate

rm -rf /usr/share/gamocosm/public
cp -r public /usr/share/gamocosm/public

echo "Remember to restart the Gamocosm Puma and Sidekiq service!"
