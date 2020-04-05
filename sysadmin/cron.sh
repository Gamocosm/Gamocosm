#!/usr/bin/env bash

systemctl restart gamocosm-puma
systemctl restart gamocosm-sidekiq
curl -sS https://gamocosm.com
