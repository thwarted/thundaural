#!/usr/bin/perl

package Statistics;

# $Header: /home/cvs/thundaural/server/Statistics.pm,v 1.2 2004/01/09 07:19:01 jukebox Exp $

use strict;
use warnings;

use threads;
use threads::shared;
use Thread::Queue;

use File::Basename;

use DBI;

use Settings;
use Logger;

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

	$this->dbfile($o{-dbfile});

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

sub run {
	my $this = shift;

	$this->_dbconnect();
	my $storagedir = Settings::storagedir();

	my $lasttime = time();
	my $lastphid = 0;
	while ($main::run) {

		if (($lasttime + 80) < time()) {
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
			if ($thisphid != $lastphid) {
				my $start = time();
				eval {
					$this->_update_track_ranks();
				};
				Logger::logger($@) if ($@);
				my $end = time();
				Logger::logger("calculated track rankings in ".($end-$start)." seconds");
				$lasttime = time();
				$lastphid = $thisphid;
			}
		}
		sleep 1;
	}

	Logger::logger("exiting statistics");
}

sub _update_track_ranks {
	my $this = shift;

	lock(${$this->{-dblock}});

	# get total of how many tracks have been played
	my $q = "select count(1) from playhistory where action = ?";
	my $sth = $this->{-dbh}->prepare($q);
	$sth->execute('played');
	my($t) = $sth->fetchrow_array();
	$sth->finish;
	$t = 0 if (!$t);
	$t = sprintf('%.2f', $t);

	my $viewname = "ranks$$";
	$this->{-dbh}->do("create temporary table $viewname as select count(1) as cnt, trackid from playhistory where action = 'played' group by 2");
	$q = "select cnt, round(cnt/$t, 7), trackid from $viewname order by 1 desc";
	$sth = $this->{-dbh}->prepare($q);
	$sth->execute();
	my @ret = ();
	my $rank = 0;
	eval {
		lock(${$this->{-dblock}});
		$this->{-dbh}->begin_work();
		my $lastpop = -1;
		while(my($cnt, $pop, $trackid) = $sth->fetchrow_array()) {
			$rank++ if ($pop != $lastpop);
			my $q = "update tracks set popularity = $pop, rank = $rank where trackid = $trackid";
			$this->{-dbh}->do($q);
			$lastpop = $pop;
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

