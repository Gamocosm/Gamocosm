#!/usr/bin/env bash

eval "$("$HOME/.rbenv/bin/rbenv" init -)"

source env.sh

exec "$@"
