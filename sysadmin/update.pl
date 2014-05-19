#!/bin/perl

use strict;
use POSIX;

my $username = $ENV{USER};
my @http_pwnam = POSIX::getpwnam("http");

if ($< == 0) {
	POSIX::setuid($http_pwnam[2]);
	POSIX::setpgid($http_pwnam[3]);
}
if ($< != $http_pwnam[2]) {
	print("This should be run as root or http");
	exit(1);
}

exec("bash", "/var/www/gamocosm/sysadmin/update.sh");
