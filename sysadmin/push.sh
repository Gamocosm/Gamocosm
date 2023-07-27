#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"
cd ..

podman build --tag gamocosm-image:latest .

podman image prune --force

podman image save --format oci-archive gamocosm-image:latest | gzip | ssh gamocosm "./gamocosm/sysadmin/update.sh $1"
