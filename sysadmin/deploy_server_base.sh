#!/bin/bash

set -e

yum -y update

yum -y install ruby nodejs gcc gcc-c++ curl-devel openssl-devel zlib-devel ruby-devel

gem install passenger bundler rails

# - edit iptables
# - edit nginx config
# - setup /var/www/
# - setup rails dependencies
