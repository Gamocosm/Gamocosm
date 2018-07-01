#!/bin/bash

source env.sh
source "$HOME/.rvm/scripts/rvm"

rvm use 2.5.1

if [[ "$RAILS_ENV" == "production" ]] && [[ "$1" != "--bundler" ]]; then
	ruby "$@"
else
	if [[ "$1" == "--bundler" ]]; then
		shift
	fi
	bundle exec "$@"
	# wait for pid file
	if [[ "$RAILS_ENV" == "production" ]] && [[ "$1" == "sidekiq" ]]; then
		sleep 1
	fi
fi
