#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"
cd ..

podman build --tag gamocosm-image:latest .

podman image prune --force

podman image save --format oci-archive gamocosm-image:latest \
	| gzip \
	| ( echo 'Sending over SSH; check auth...'; ssh gamocosm "/opt/gamocosm/sysadmin/update.sh $1" )
