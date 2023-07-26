#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"

function finally() {
	echo 'Cleaning up...'
	podman stop gamocosm_test
	echo 'Done cleanup.'
}

podman build --tag gamocosm-test:latest --file tests.Containerfile .

podman image prune --force

podman run --detach --rm --name gamocosm_test \
	--publish 127.0.0.1:2022:22 \
	--publish 127.0.0.1:4022:4022 \
	--publish 127.0.0.1:5000:5000 \
	--publish 127.0.0.1:25565:25565 \
	gamocosm-test:latest

trap finally exit

echo 'Testing...'
TEST_WITH_CONTAINER=true bundle exec rails test "$@"
echo 'Done testing.'
