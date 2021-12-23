#!/usr/bin/env bash

cd "$(dirname "$0")"

podman build --file Containerfile --tag localhost/gamocosm ..
