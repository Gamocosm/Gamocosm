#!/usr/bin/env bash

URL='https://cache.ruby-lang.org/pub/ruby/3.0/ruby-3.0.3.tar.gz'

curl -Lo ruby.tar.gz "$URL"

mkdir ruby

tar -x -f ruby.tar.gz --strip-components=1 -C ruby

cd ruby

mkdir build
cd build

../configure --disable-install-doc
make
make install
