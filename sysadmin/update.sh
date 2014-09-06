#!/bin/bash

set -e

PATH="$PATH:$HOME/bin"

cd /var/www/gamocosm

git pull origin release
chown -R http:http .

RAILS_ENV=production bundle exec rake assets:precompile

touch tmp/restart.txt
