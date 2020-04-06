#!/usr/bin/env bash

systemctl stop gamocosm-puma
logrotate /usr/share/nginx/gamocosm/sysadmin/logrotate.conf
systemctl start gamocosm-puma
systemctl restart gamocosm-sidekiq
curl -sS https://gamocosm.com
