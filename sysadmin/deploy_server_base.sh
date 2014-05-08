#!/bin/bash

set -e

yum -y update

yum -y install ruby nodejs gcc gcc-c++ curl-devel openssl-devel zlib-devel ruby-devel memcached

gem install passenger bundler

# - edit iptables
# - edit nginx config
# - setup /var/www/
# - setup rails dependencies
# - postgresql auth
# - services: redis, postgresql, memcached
# - sidekiq
