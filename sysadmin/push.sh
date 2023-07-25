#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"
cd ..

podman build --tag gamocosm-image:latest .

podman image prune --force

if [ "$1" == '--pull' ]; then
	podman image save --format oci-archive gamocosm-image:latest | gzip | ssh gamocosm 'zcat | podman image load && cd gamocosm && git pull origin master && ./sysadmin/update.sh'
else
	podman image save --format oci-archive gamocosm-image:latest | gzip | ssh gamocosm 'zcat | podman image load && cd gamocosm && ./sysadmin/update.sh'
fi
