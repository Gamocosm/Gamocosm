#!/usr/bin/env bash

cd ~

YEAR_MONTH="$(date '+%Y-%m')"

DB_BACKUP_DIR="gamocosm/backup/$YEAR_MONTH"
sudo --user gamocosm --login mkdir -p "$DB_BACKUP_DIR"
sudo --user gamocosm --login bash -c "pg_dump --host localhost --port 5433 --username gamocosm --no-password --format custom gamocosm_production > '$DB_BACKUP_DIR/gamocosm_production.$(date '+%Y-%m-%d.%H-%M-%S').dump'"

certbot-3 renew >> "certbot/certbot.$YEAR_MONTH.stdout.log" 2>> "certbot/certbot.$YEAR_MONTH.stderr.log"

systemctl restart gamocosm-puma
systemctl restart gamocosm-sidekiq
systemctl restart nginx

curl --silent --show-error https://gamocosm.com > /dev/null
