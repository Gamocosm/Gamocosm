#!/bin/bash

if [[ "$1" == "--source" ]]; then
	source "$HOME/.bash_profile"
	shift
fi

source env.sh
rvm use 2.2

if [[ "$RAILS_ENV" == "production" ]] && [[ "$1" != "--bundler" ]]; then
	ruby "$@"
else
	if [[ "$1" == "--bundler" ]]; then
		shift
	fi
	bundle exec "$@"
fi
