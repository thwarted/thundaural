#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/Thundaural/Server/Reader.pm,v 1.2 2004/05/30 09:17:09 jukebox Exp $

package Thundaural::Server::Reader;

# this is the interface to the audio reader script (ripcdrom.pl)
# it mainly just translates the output from the script to
# the internal format the server uses

use strict;
use warnings;

use threads;
use threads::shared;
use Thread::Queue;

use File::Basename;

use DBI;

use Thundaural::Server::Settings;
use Thundaural::Logger qw(logger);


sub new {
	my $class = shift;
	my %o = @_;

	my $this = {};
	bless $this, $class;

	$this->{-device} = $o{-device};
	die("unknown device passed") if (!$this->{-device});
	$this->{-devicefile} = Thundaural::Server::Settings::get($this->{-device}, 'read');
	die("not a readable device") if (!$this->{-devicefile});

	$this->{-cmdqueue} = new Thread::Queue;
	$this->dbfile($o{-dbfile});

	$this->{-state} = $o{-ref_state};
	$this->{-track} = $o{-ref_track};
	
	my $dblock = $o{-ref_dblock};
	die("dblock isn't a reference") if (!ref($dblock));
	die("dblock isn't a reference to a scalar") if (ref($dblock) ne 'SCALAR');
	die("bad dblock passed") if ($$dblock != 0xfef1f0fa);
	$this->{-dblock} = $dblock;

	return $this;
}

sub dbfile {
	my $this = shift;
	my $db = shift;

	return if (!$db);
	$this->{-dbfile} = $db;
}

sub _dbconnect {
	my $this = shift;

	my $dbfile = $this->{-dbfile};
	if ($dbfile) {
		$this->{-dbh} = DBI->connect("dbi:SQLite:dbname=$dbfile","","");
		logger("dbh is ".$this->{-dbh});
	}
}

sub state {
	my $this = shift;
	my $s = $this->{-state};
	if (ref($s)) {
		$s = $$s;
	}
	$s = '' if (!defined($s) || !$s);
	return $s
}

sub track {
	my $this = shift;
	my $t = $this->{-track};
	if (ref($t)) {
		$t = $$t;
	}
	$t = '' if (!defined($t) || !$t);
	return $t;
}

sub cmdqueue {
	my $this = shift;
	return $this->{-cmdqueue};
}

sub run {
	my $this = shift;

	$this->_dbconnect();
	my $storagedir = Thundaural::Server::Settings::storagedir();

	RUN:
	while ($main::run) {
		# remove any pending commands, so we actually have to wait
		while($this->{-cmdqueue}->pending()) { $this->{-cmdqueue}->dequeue(); } 

		# wait for the command to start reading a disc
		WAITING:
		while(my $cmd = $this->{-cmdqueue}->dequeue()) {
			last WAITING if (!defined($cmd));
			last WAITING if ($cmd =~ m/^startrip$/);
			if ($cmd =~ m/^clearstate$/) {
				${$this->{-track}} = '';
				${$this->{-state}} = 'idle';
				next WAITING;
			}
			if ($cmd =~ m/^abort$/) {
				last RUN;
			}
			logger("reader got \"$cmd\", ignoring");
		}
		last RUN if (!$main::run);

		my $ripcmd = Thundaural::Server::Settings::command('ripcdrom');
		my @ppargs = split(/\s+/, $ripcmd);
		{
			my @x = ();
			my $dbfile = $this->{-dbfile};
			my $devicefile = $this->{-devicefile};
			foreach my $y (@ppargs) {
				$y =~ s/\${DEVICEFILE}/$devicefile/g;
				$y =~ s/\${DBFILE}/$dbfile/g;
				$y =~ s/\${STORAGEDIR}/$storagedir/g;
				push(@x, $y);
			}
			@ppargs = @x;
		}
		@ppargs = (@ppargs, '|');

		my $plread;
		my $rpid = open($plread, join(' ', @ppargs));
		logger("rpid = $rpid");
		if (!$rpid) {
			${$this->{-track}} = "error starting ripper: $@";
			${$this->{-state}} = "idle";
			next RUN;
		}
		logger("started \"".join(' ', @ppargs)."\"");
		my $readthr = threads->new(sub { $this->_read_status($plread, $rpid); } );

		TILLFINISHED:
		while(my $cmd = $this->{-cmdqueue}->dequeue()) {
			if ($cmd =~ m/^abortrip/) {
				logger("got abort, killing $rpid");
				kill 15, $rpid;
				${$this->{-track}} = "user aborted $rpid";
				${$this->{-state}} = 'idle';
				last TILLFINISHED;
			}
			last TILLFINISHED if ($cmd =~ m/^quit/);
		}
		waitpid $rpid, 0;
		my $success = $readthr->join;
		logger("reader thread returned $success");

		# devicename state volume trackref performer name genre length trackid started current percentage
	}

	logger($this->{-device}." reader thread exiting");
}

sub _read_status {
	my $this = shift;
	my $rh = shift;
	my $rpid = shift;

	my $devicefile = $this->{-devicefile};

	my $c = 0;
	while(my $l = <$rh>) {
		chomp $l;
		if ($l =~ m/^$devicefile/) {
			next if (${$this->{-track}} =~ m/^user aborted $rpid$/);
			my @x = split(/\t/, $l);
			shift @x; # remove leading device name
			${$this->{-state}} = shift @x;
			${$this->{-track}} = join("\t", @x);
			if (($c++ % 45) == 0) {
				my $pct = (pop @x) || 0;
				my $corrections = (pop @x) || '0';
				my $vol = (shift @x) || '-';
				my $trkrf = (shift @x) || '-';
				if ((int($pct) % 10) == 0 || $corrections != 0) {
					logger("track $trkrf, $vol, $pct%, $corrections corrections");
				}
			}
		}

		last if ($l =~ m/^$devicefile\tidle/);
		last if (!$main::run);
	}
	close($rh);
	$this->{-cmdqueue}->enqueue('quit');
	return 1;
}

1;

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
