#!/bin/perl

use strict;
use POSIX;

my @http_pwnam = POSIX::getpwnam("http");
my $executable = "/var/www/gamocosm/sysadmin/update.sh";
my @command = ("bash", $executable);

if ($< != $http_pwnam[2]) {
	@command = (("sudo", "--login", "-u", "http"), @command);
}

exec(@command);
