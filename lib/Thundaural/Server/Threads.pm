#!/usr/bin/perl

package Thundaural::Server::Threads;

# $Header: /home/cvs/thundaural/server/Thundaural/Server/Threads.pm,v 1.2 2004/06/10 06:04:11 jukebox Exp $

use strict;
use warnings;

use Data::Dumper;
use Carp;

use threads;
use threads::shared;
use Thread::Queue;

use Thundaural::Server::Settings;
use Thundaural::Logger qw(logger);
use Thundaural::Server::Player;
use Thundaural::Server::Reader;

sub start_periodic {
	my $dblock = shift;
	croak("start_periodic not passed a reference to dblock") if (!ref($dblock));

	my $pstate : shared = '';
	my $periodic = new Thundaural::Server::Periodic(-ref_dblock=>$dblock, -ref_state=>\$pstate);
	my $periodicthr = threads->new(sub { eval { $periodic->run(); }; logger("periodic tasks thread no longer running $@"); } );
	return ($periodic, $periodicthr);
}

sub start_players {
	my $dblock = shift;
	croak("start_players not passed a reference to dblock") if (!ref($dblock));

	my $playdevs = Thundaural::Server::Settings::get_of_type('play');
    # verify accessiblity of the device files
    foreach my $pd (@$playdevs) {
        my $devname = $pd->{devicename};
        my $devfile = Thundaural::Server::Settings::get($devname, 'play');
        if (!-r $devfile || !-w $devfile) {
            my $msg = "$devfile is not accessible";
            logger($msg);
            die("$msg\n");
        }
        my $mixer = Thundaural::Server::Settings::get($devname, 'mixer');
        if (!-r $mixer || !-w $mixer) {
            my $msg = "$mixer is not accessible";
            logger($msg);
            die("$msg\n");
        }
    }
	# we create one thread, and the player object takes care
	# of writing to all the devices. but our reference to the
	# output device needs a name, so use the first one specified
	# in the config -- this name will be used to manipulate all
	# the devices
	my $maindev = $playdevs->[0];
	my $device = $maindev->{devicename};
	my $playerthrs = {};
	$playerthrs->{$device} = &spawn_player($dblock);
	# note that this has only has one element -- this is to
	# make the interface similar both reading and writing
	# devices similar
	return $playerthrs;
}

sub start_readers {
	my $dblock = shift;
	croak("start_readers not passed a reference to dblock") if (!ref($dblock));

	my $readerthrs = {};
	my $readdevs = Thundaural::Server::Settings::get_of_type('read');
    # check access and start up the threads
	foreach my $ro (@$readdevs) {
		my $device = $ro->{devicename};
        my $devfile = Thundaural::Server::Settings::get($device, 'read');
        if (!-r $devfile || !-w $devfile) {
            my $msg = "$devfile is not accessible";
            logger($msg);
            die("$msg\n");
        }
		$readerthrs->{$device} = &spawn_reader($device, $dblock);
	}
	return $readerthrs;
}




sub spawn_player {
	my $dblock = shift;
	croak("spawn_player_thread not passed a reference to dblock") if (!ref($dblock));
	my $stat_state : shared = 'idle';
	my $stat_position : shared = '';
	my $stat_track : shared = '';
	my $player = new Thundaural::Server::Player(-dbfile=>Thundaural::Server::Settings::dbfile(),
				#-device=>$device,
				-ref_state=>\$stat_state,
				-ref_position=>\$stat_position,
				-ref_track=>\$stat_track,
				-ref_dblock=>$dblock,
			);
	# we set this to one here to avoid a race condition, whereby the thread hasn't started yet, and we still read -running as 0
	my $running : shared = 1;
	#my $playerthr = threads->new(sub { $running = 1; eval { $player->run(); }; logger("player thread for $device no longer running $@"); $running = 0; });
	my $playerthr = threads->new(sub { $running = 1; eval { $player->run(); }; logger("player thread no longer running $@"); $running = 0; });
	my $ret = {-thread=>$playerthr, -object=>$player, -running=>\$running};
	return $ret;
}

sub spawn_reader {
	my $device = shift;
	my $dblock = shift;
	croak("spawn_player_thread not passed a reference to dblock") if (!ref($dblock));
	my $stat_state : shared = 'idle';
	my $stat_track : shared = '';
	my $reader = new Thundaural::Server::Reader(-dbfile=>Thundaural::Server::Settings::dbfile(),
				-device=>$device,
				-ref_state=>\$stat_state,
				-ref_track=>\$stat_track,
				-ref_dblock=>$dblock,
			);
	# we set this to one here to avoid a race condition, whereby the thread hasn't started yet, and we still read -running as 0
	my $running : shared = 1; 
	my $readerthr = threads->new(sub { $running = 1; eval { $reader->run(); }; logger("reader thread for $device no longer running $@"); $running = 0; });
	my $ret = {-thread=>$readerthr, -object=>$reader, -running=>\$running};
	return $ret;
}

1;

#    Thundaural Jukebox
#    Copyright (C) 2003-2005  Andrew A. Bakun
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

