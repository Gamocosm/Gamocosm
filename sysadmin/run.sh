#!/usr/bin/env bash

source "$HOME/.rvm/scripts/rvm"
rvm use 2.6.5

source env.sh

exec "$@"
