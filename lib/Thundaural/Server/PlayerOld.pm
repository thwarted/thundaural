#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/Thundaural/Server/PlayerOld.pm,v 1.1 2004/05/22 06:40:24 jukebox Exp $

package Thundaural::Server::PlayerOld;

# this implementation of the audio writer can be instanced multiple times, once
# for each device you want to write to.  Different audio streams can be written
# to each device -- it does not support writing one stream to multiple devices
# because it uses external programs (the remote interface on mpg321 and 
# ogg123 + a patch) to actually play the audio file.  Because of this, it suffers
# from (fixable, but not worth fixing) unacceptable pauses between songs
#
# it is being included for future reference

use strict;
use warnings;

use threads;
use threads::shared;
use Thread::Queue;

use File::Basename;
use IPC::Open2;
use DBI;

use Thundaural::Server::Settings;
use Thundaural::Logger;

# music player
#   - reads next song out of queue
#   - plays song
#       starts writer thread to send commands
#       starts reader thread to read status

sub new {
	my $class = shift;
	my %o = @_;

	my $this = {};
	bless $this, $class;

	$this->{-device} = $o{-device};
	die("unknown device passed") if (!$this->{-device});

	$this->{-cmdqueue} = new Thread::Queue;
	$this->dbfile($o{-dbfile});

	$this->{-state} = $o{-ref_state};
	$this->{-position} = $o{-ref_position};
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
		Logger::logger("dbh is ".$this->{-dbh});
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

sub position {
	my $this = shift;
	my $p = $this->{-position};
	if (ref($p)) {
		$p = $$p;
	}
	$p = '' if (!defined($p) || !$p);
	return $p;
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
	my $storagedir = Settings::storagedir();

	while ($main::run) {

		my $playtrack;
		{
			lock(${$this->{-dblock}});
			my $q = "select * from playhistory where devicename = ? and action = ? order by requestedat limit 1";
			my $sth = $this->{-dbh}->prepare($q);
			$sth->execute($this->{-device}, 'queued');
			$playtrack = $sth->fetchrow_hashref();
			$sth->finish;
		}
		if ($this->{-cmdqueue}->pending()) {
			my $c = $this->{-cmdqueue}->dequeue();
			last if ($c eq 'abort');
			last if (!defined($c));
		}
		($this->usleep(0.5), next) if (!$playtrack);

		my $devicefile = Settings::get($playtrack->{devicename}, 'play');
		my $track = $this->trackinfo($playtrack->{trackid});

		my $filename = "$storagedir/".$track->{filename};
		if (!-s $filename) {
			$this->playhistory_action($playtrack->{playhistoryid}, 'no file');
			next;
		}
		my @ppargs;
		if ($filename =~ m/\.ogg$/i) {
			my $playerprg = Settings::get('oggremote', 'command');
			@ppargs = split(/\s+/, $playerprg);
		} else {
			# should support other filetypes here
			$this->playhistory_action($playtrack->{playhistoryid}, 'unknowntype');
			next;
		}
		# avoid starting it via sh by passing the options as individual args
		my @x = ();
		foreach my $y (@ppargs) {
			$y =~ s/\${DEVICEFILE}/$devicefile/g;
			push(@x, $y);
		}
		@ppargs = @x;

		$this->playhistory_action($playtrack->{playhistoryid}, 'playing');
		my($plread, $plwrite);
		my $pid = open2($plread, $plwrite, @ppargs);
		my $c = 0;
		while($this->{-cmdqueue}->pending()) { $this->{-cmdqueue}->dequeue(); $c++;} # empty the cmdqueue
		Logger::logger("cleared player command queue of $c entries");
		$this->{-cmdqueue}->enqueue("load $filename");
		Logger::logger("loading \"$filename\"");
		${$this->{-track}} = sprintf("%d\t%d", $playtrack->{trackid}, time());
		Logger::logger("set track to \"".${$this->{-track}}."\"");
		my($readthr, $writethr);
		$readthr = threads->new(sub { $this->_read_status($plread); } );
		$writethr = threads->new(sub { $this->_write_cmds($plwrite); } );
		waitpid $pid, 0;
		$readthr->join;
		my $success = $writethr->join;
		if ($success >= 0) {
			$this->playhistory_action($playtrack->{playhistoryid}, $success ? 'played' : 'skipped');
		}
		${$this->{-track}} = undef;
	}

	Logger::logger($this->{-device}." exiting");
}

# note that this is specific to ogg123 and mpg321, but has only been tested with ogg123
# also note that a custom ogg123 is needed that doesn't go into an infinite loop on
# stdin close
sub _read_status {
	my $this = shift;
	my $rh = shift;

	my $c = 0;
	while(my $l = <$rh>) {
		chomp $l;
		if ($l =~ m/^\@F /) {
			#@F 0 0 4.62 266.82 91
			my(undef, undef, undef, $upto, $left, undef) = split(/\s+/, $l);
			$upto = sprintf('%.2f', $upto);
			$left = sprintf('%.2f', $left);
			my $total = sprintf('%.1f', $upto + $left);
			my $pct;
			if ($total > 0) {
				$pct = sprintf("%s\t%s\t%.2f", $upto, $total, ($upto/$total*100));
				${$this->{-state}} = 'playing';
			} else {
				$pct = '';
				${$this->{-state}} = 'idle';
			}
			${$this->{-position}} = $pct;
			if (($c++ % 45) == 0) {
				Logger::logger($l);
			}
			next;
		}
		if ($l =~ m/^\@P 1/) {
			${$this->{-state}} = 'paused';
		}
		if ($l =~ m/^\@P 2/) {
			${$this->{-state}} = 'playing';
		}

		last if ($l =~ m/^\@P 0 EOF/);
		last if ($l =~ m/^\@Q/);
	}
	close($rh);
	${$this->{-position}} = '';
	${$this->{-state}} = 'idle';
	$this->{-cmdqueue}->enqueue('quit');
	${$this->{-position}} = '';
	${$this->{-state}} = 'idle';
}

sub _write_cmds {
	my $this = shift;
	my $wh = shift;

	my $success = 1;
	while (my $cmd = $this->{-cmdqueue}->dequeue) {
		#Logger::logger($cmd);
		if ($cmd =~ m/^abort/) {
			print $wh "quit\n";
			close($wh);
			$success = -1;
			last;
		}
		if ($cmd =~ m/^skip/) {
			print $wh "quit\n";
			close($wh);
			$success = 0;
			last;
		}
		print $wh "$cmd\n";
		if ($cmd =~ m/^quit/) {
			close($wh);
			$success = 1;
			last;
		}
	}
	return $success;
}

sub trackinfo($) {
	my $this = shift;
	my $trackid = shift;
	my $track = {};
	eval {
		lock(${$this->{-dblock}});
		my $q = "select * from tracks where trackid = ?";
		my $sth = $this->{-dbh}->prepare($q);
		#Logger::logger("getting track info for track $trackid");
		$sth->execute($trackid);
		$track = $sth->fetchrow_hashref;
		$sth->finish;
	};
	return $track;
}

sub playhistory_action($$) {
	my $this = shift;
	my $playhistoryid = shift;
	my $action = shift;
		                                                                                                                                            
	eval {
		lock(${$this->{-dblock}});
		my $q = "update playhistory set action = ?, actedat = ? where playhistoryid = ?";
		my $sth = $this->{-dbh}->prepare($q);
		$sth->execute($action, time(), $playhistoryid);
		$sth->finish;
	};
}

sub usleep {
	my $this = shift;
	my $duration = shift;
	select(undef, undef, undef, $duration);
	return 0;
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
