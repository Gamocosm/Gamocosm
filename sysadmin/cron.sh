#!/usr/bin/env bash

systemctl stop gamocosm-puma
logrotate /home/gamocosm/gamocosm/sysadmin/logrotate.conf
systemctl start gamocosm-puma
systemctl restart gamocosm-sidekiq
curl -sS https://gamocosm.com
