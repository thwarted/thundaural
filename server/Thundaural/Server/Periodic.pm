#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/Thundaural/Server/Periodic.pm,v 1.3 2004/05/31 08:23:10 jukebox Exp $

package Thundaural::Server::Periodic;

use strict;
use warnings;

use threads;
use threads::shared;
use Thread::Queue;

use File::Basename;
use Data::Dumper;

$Data::Dumper::Indent = 0;
$Data::Dumper::Sortkeys = 1;

use DBI;

use Thundaural::Server::Settings;
use Thundaural::Logger qw(logger);

# runs periodic tasks, like updating stats

sub new {
	my $class = shift;
	my %o = @_;

	my $this = {};
	bless $this, $class;

	$this->dbfile(Thundaural::Server::Settings::dbfile());

	$this->{-cmdqueue} = new Thread::Queue;

	$this->{-trackstotal} = 0;
	$this->{-tracksplayed} = 0;

	$this->{-state} = $o{-ref_state};

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

sub randomized_play_end {
	my $this = shift;

	my $x = ${$this->{-state}};
	if ($x) {
		# damn Data::Dumper doesn't honor use strict, and I can't figure out to make it
		my $y = eval "my $x";
		return $y;
	}
	return {};
}

sub cmdqueue {
	my $this = shift;
	return $this->{-cmdqueue};
}

sub run {
	my $this = shift;

	$this->_dbconnect();
	my $storagedir = Thundaural::Server::Settings::storagedir();

	my $statsupdatefreq = 60 * 3;

	my $laststatstime = time() - $statsupdatefreq;
	my $laststatsphid = 0;
	my $randomplayend = {};
	while ($main::run) {

		if (($laststatstime + $statsupdatefreq) < time()) {
			my $thisphid;
			{
				lock(${$this->{-dblock}});
				my $q = "select max(playhistoryid) from playhistory where action = ?";
				my $sth = $this->{-dbh}->prepare($q);
				$sth->execute('played');
				($thisphid) = $sth->fetchrow_array();
				$thisphid = 0 if (!defined($thisphid));
				$sth->finish;
			}
			if ($thisphid != $laststatsphid) {
				my $start = time();
				eval {
					$this->_update_track_ranks();
				};
				logger($@) if ($@);
				my $end = time();
				logger("calculated track rankings in ".($end-$start)." seconds");
				$laststatstime = time();
				$laststatsphid = $thisphid;
			}
		}

		if ($this->{-cmdqueue}->pending()) {
			my $cmd = $this->{-cmdqueue}->dequeue_nb();
			logger("got cmd $cmd");
			if ($cmd && (my($seconds, $reqdev) = $cmd =~ m/^random (\d+) on (\w+)$/)) {
				if ($this->{-trackstotal} > 20 && $this->{-tracksplayed} > 20) {
					if (Thundaural::Server::Settings::get($reqdev, 'play')) {
						if ($seconds) {
							# put random songs in the queue for device $reqdev for $seconds
							$randomplayend->{$reqdev} = time() + $seconds;
							logger("starting random play on $reqdev -- will end in $seconds at "
									.localtime($randomplayend->{$reqdev}));
						} else {
							delete($randomplayend->{$reqdev});
							logger("aborting random play on $reqdev");
							
						}
						my $x = Dumper($randomplayend);
						${$this->{-state}} = $x;
					}
				}
			}
		}

		foreach my $d (keys %$randomplayend) {
			if (time() < $randomplayend->{$d}) {
				eval {
					$this->enqueue_random_song($d) if( ! $this->something_is_playing_on($d) );
				};
				logger($@) if ($@);
			} else {
				delete($randomplayend->{$d});
				my $x = Dumper($randomplayend);
				${$this->{-state}} = $x;
			}
		}

		sleep 1;
	}

	logger("periodic thread exiting");
}

sub enqueue_random_song {
	my $this = shift;
	my $devicename = shift;

	lock(${$this->{-dblock}});

	# pick a random track that isn't in the last 20 tracks played
	my $q = "select trackid from tracks where trackid not in 
		(select distinct trackid from playhistory where devicename = ? order by playhistoryid desc limit 20)
		order by random() limit 1";
	my $sth = $this->{-dbh}->prepare($q);
	$sth->execute($devicename);
	my($trackid) = $sth->fetchrow_array();

	logger("random play, enqueueing track $trackid");

	$q = "insert into playhistory (playhistoryid, trackid, devicename, requestedat, source, action) values (NULL, ?, ?, ?, ?, ?)";
	$sth = $this->{-dbh}->prepare($q);
	$sth->execute($trackid, $devicename, time(), 'random', 'queued');
	$sth->finish;
}

sub something_is_playing_on {
	my $this = shift;
	my $dev = shift;

	lock(${$this->{-dblock}});
	my $q = 'select count(1) from playhistory where devicename = ? and action = ?';
	my $sth = $this->{-dbh}->prepare($q);
	$sth->execute($dev, 'playing');
	my($c) = $sth->fetchrow_array();
	return $c;
}

sub _update_track_ranks {
	my $this = shift;

	my($q, $sth, $t);

	lock(${$this->{-dblock}});

	# get total of how many tracks are in the database
	$q = "select count(1) from tracks";
	$sth = $this->{-dbh}->prepare($q);
	$sth->execute();
	($t) = $sth->fetchrow_array();
	$t = 0 if (!$t);
	$t += 0;
	$this->{-trackstotal} = $t;

	# get total of how many tracks have been played
	$q = "select count(1) from playhistory where action = ?";
	$sth = $this->{-dbh}->prepare($q);
	$sth->execute('played');
	($t) = $sth->fetchrow_array();
	$sth->finish;
	$t = 0 if (!$t);
	$t += 0;
	$this->{-tracksplayed} = $t;
	$t = sprintf('%.2f', $t);

	my $viewname = "ranks$$";
	$this->{-dbh}->do("create temporary table $viewname as select count(1) as cnt, trackid from playhistory where action = 'played' group by 2");
	$q = "select cnt, round(cnt/$t, 7), trackid from $viewname order by 1 desc";
	$sth = $this->{-dbh}->prepare($q);
	$sth->execute();
	my @ret = ();
	my $rank = 0;
	my $seensongs = 0;
	eval {
		$this->{-dbh}->begin_work();
		$this->{-dbh}->do("update tracks set popularity = 0, rank = NULL");
		my $lastpop = -1;
		while(my($cnt, $pop, $trackid) = $sth->fetchrow_array()) {
			$seensongs++;
			$rank = $seensongs if ($pop != $lastpop);
			$lastpop = $pop;
			my $q = "update tracks set popularity = $pop, rank = $rank where trackid = $trackid";
			$this->{-dbh}->do($q);
		}
	};
	if ($@) {
		$this->{-dbh}->rollback();
	} else {
		$this->{-dbh}->commit();
	}
	$sth->finish;
	$this->{-dbh}->do("drop table $viewname");
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
