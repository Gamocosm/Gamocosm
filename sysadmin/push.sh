#!/usr/bin/env bash

ssh gamocosm 'cd gamocosm && git pull origin master'
ssh gamocosm './gamocosm/sysadmin/update.sh'
