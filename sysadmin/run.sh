#!/usr/bin/env bash

PATH="$HOME/.rbenv/bin:$PATH"
PATH="$HOME/.rbenv/shims:$PATH"

source env.sh

exec "$@"
