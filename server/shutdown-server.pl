#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/shutdown-server.pl,v 1.3 2004/06/10 06:02:02 jukebox Exp $

use strict;
use warnings;

use IO::Socket;
use IO::Socket::INET;

use Thundaural::Server::Settings;

my $host = Thundaural::Server::Settings::listenhost();
$host = "0.0.0.0" if (!$host); # doesn't work on all systems!
my $port = Thundaural::Server::Settings::listenport();
die("no port specified\n") if (!$port);

# should have some kind of authentication here -- anyone could shutdown the server
# even remotely
my $conn = new IO::Socket::INET(PeerAddr=>$host, PeerPort=>$port, proto=>'tcp') or die("$!\n");
if ($conn->connected()) {
	print $conn "shut\n";
	sleep 1;
}
close($conn);

#    Thundaural Jukebox
#    Copyright (C) 2003-2004  Andrew A. Bakun
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

