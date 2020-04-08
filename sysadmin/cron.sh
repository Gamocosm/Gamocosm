#!/usr/bin/env bash

systemctl stop gamocosm-puma
logrotate /home/gamocosm/gamocosm/sysadmin/logrotate.conf
systemctl start gamocosm-puma
systemctl restart gamocosm-sidekiq
certbot-3 renew >> "$HOME/certbot/stdout.txt" 2>> "$HOME/certbot/stderr.txt"
systemctl restart nginx
curl -sS https://gamocosm.com > "$HOME/gamocosm/index.html"
