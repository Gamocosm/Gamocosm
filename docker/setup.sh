#!/bin/bash

rm -rf ./tmp
docker-compose build
docker-compose down
docker-compose run web env.sh && bundle exec rake db:setup