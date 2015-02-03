#!/bin/bash

source env.sh

if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
	PATH="$PATH:$HOME/bin"
fi

if [[ "$RAILS_ENV" == "production" ]] && [[ "$1" != "--bundler" ]]; then
	ruby "$@"
else
	if [[ "$1" == "--bundler" ]]; then
		shift
	fi
	bundle exec "$@"
fi
