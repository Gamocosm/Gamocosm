#!/usr/bin/env bash

ssh gamocosm 'cd gamocosm && git pull origin master && ./sysadmin/update.sh'
