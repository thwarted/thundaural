#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/shutdown-server.pl,v 1.1 2004/03/20 23:06:06 jukebox Exp $

use strict;
use warnings;

use IO::Socket;
use IO::Socket::INET;

my $host = 'localhost';
my $port = 9000;

while (@ARGV) {
	my $a = shift @ARGV;
	if ($a =~ m/^--host/) {
		$host = shift @ARGV;
		next;
	}
	if ($a =~ m/^--?p(ort)?/) {
		$port = shift @ARGV;
		next;
	}
}

# should have some kind of authentication here -- anyone could shutdown the server
# even remotely
my $conn = new IO::Socket::INET(PeerAddr=>$host, PeerPort=>$port, proto=>'tcp') or die("$!\n");
if ($conn->connected()) {
	print $conn "shut\n";
	sleep 1;
}
close($conn);
