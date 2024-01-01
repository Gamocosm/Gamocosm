#!/usr/bin/env bash

set -e

OLD_HASH="$(md5sum < "$0")"

if [ "$1" == '--skip-load' ]; then
	shift
else
	echo 'Loading image...'
	zcat | podman image load
	echo 'Loaded image.'
fi

cd "$(dirname "$0")"

cd ..

if [ "$1" == '--pull' ]; then
	shift
	git pull origin master
	NEW_HASH="$(md5sum < sysadmin/update.sh)"
	if [ "$OLD_HASH" != "$NEW_HASH" ]; then
		echo 'Update script changed; please rerun.'
		exit 0
	fi
else
	echo 'Skipping pulling from git.'
fi

echo 'Stopping services...'
systemctl stop gamocosm-puma.service gamocosm-sidekiq.service gamocosm-dns.service || true

echo 'Creating `git.env`...'
echo "GIT_HEAD=$(git rev-parse HEAD)" > git.env
echo "GIT_HEAD_TIMESTAMP=$(git show --no-patch --format=%ct HEAD)" >> git.env

echo 'Running migrations...'
podman run --rm \
	--network gamocosm-network \
	--env-file gamocosm.env \
	gamocosm-image:latest \
	bundle exec rails db:migrate

echo 'Getting public assets...'
TMP_PUBLIC="tmp.public"
trap "rm -rf '$TMP_PUBLIC'" exit
mkdir "$TMP_PUBLIC"
# The trailing dot on the source directory means "copy the contents of... into the destination directory".
podman cp gamocosm-puma:/gamocosm/public/. "$TMP_PUBLIC"
# The trailing slash on the source directory means "copy the contents of... into the destination directory".
rsync -r "$TMP_PUBLIC/" /usr/share/gamocosm/public

echo 'Pruning images...'
podman image prune --force

echo 'Restarting services...'
systemctl daemon-reload
systemctl start gamocosm-puma.service gamocosm-sidekiq.service gamocosm-dns.service

systemctl restart nginx

echo 'Pinging server...'
curl https://gamocosm.com > /dev/null
echo 'Done update.'
