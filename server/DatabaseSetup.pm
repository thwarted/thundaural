#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/DatabaseSetup.pm,v 1.3 2004/01/31 08:40:37 jukebox Exp $

package DatabaseSetup;

use DBI;
use File::Basename;

use Logger;

my $dbh;

my $keepdbbackups = 5;

sub init {
	my $dbfile = shift;

	my $d = File::Basename::dirname($dbfile);
	die("$d isn't a directory\n") if (! -d $d);
	if (!(-r $d && -w $d && -x $d)) {
		die("$d isn't fully accessible, check permissions");
	}

	$dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","", { RaiseError => 1, PrintError=>0 } );
	die("unable to open/create database $dbfile, check permissions\n") if (!$dbh);

	&backup_database($dbfile);
	&create_all_tables if (&get_db_version() < 1);
	&upgrade_to_version2() if (&get_db_version() < 2);
	die("database contains unknown version number\n") if (&get_db_version() != 2);

	$dbh->disconnect;

	Logger::logger("database $dbfile configured");
}

sub backup_database {
	my $dbfile = shift;

	my $dbfilebackup = sprintf("%s.backup.%012d.%d", $dbfile, time(), $$);
	open(NEW, ">$dbfilebackup") || die ("unable to make backup of $dbfile");
	open(OLD, "<$dbfile");
	while(!eof(OLD)) {
		my $x = '';
                read(OLD, $x, 10240);
		print NEW $x;
	}
	close(OLD);
	close(NEW);
	Logger::logger("backed up database as $dbfilebackup");

	my $d = File::Basename::dirname($dbfile);
	my $f = File::Basename::basename($dbfile);
	opendir(DIR, $d) || die "can’t opendir $d: $!"; # huh?
	my @f = sort grep { /^$f\.backup\./ && -f "$d/$_" } readdir(DIR);
	closedir DIR;

	while((scalar @f) > $keepdbbackups) {
		my $todelete = shift @f;
		unlink "$d/$todelete";
	}
}

sub get_db_version {
	my($res, $q, $sth, $vv);

	foreach my $table (qw/ albums genres playhistory tracks/) {
		$q = "select * from $table limit 1";
		$sth = $dbh->prepare($q);
		eval { $sth->execute(); };
		$res = $@;
		$sth->finish();
		$foundtables++ if (!$res);
	}
	return 0 if ($foundtables < 4); # create new database

	$q = "select value from meta where name = ? limit 1";
	$sth = $dbh->prepare($q);
	eval { 
		$sth->execute('dbversion'); 
		($vv) = $sth->fetchrow_array();
	};
	$res = $@;
	$sth->finish();
	return 1 if ($@ =~ m/no such table: meta/); # version 1 database
	return $vv;
}

sub create_all_tables {
	my %tables = (
		'creating table albums'=>
'CREATE TABLE albums (
  albumid integer,
  performer varchar(128) default NULL,
  name varchar(128) NOT NULL default \'\',
  cddbid varchar(8) NOT NULL default \'\',
  length int(11) default NULL,
  riptime int(11) default NULL,
  tracks int(11) NOT NULL default \'0\',
  coverartfile varchar(128) default NULL,
  PRIMARY KEY  (albumid)
)',
		'creating table genres'=>
'CREATE TABLE genres (
  genreid integer,
  genre varchar(64) NOT NULL default \'\',
  PRIMARY KEY  (genreid),
  UNIQUE (genre)
)',
		'creating table playhistory'=>
'CREATE TABLE playhistory (
  playhistoryid integer primary key,
  trackid int(11) NOT NULL default \'0\',
  devicename char(32) NOT NULL default \'\',
  requestedat int(11) default NULL,
  action varchar(32) default \'queued\',
  actedat int(11) default NULL
)',
		'creating table tracks'=>
'CREATE TABLE tracks (
  trackid integer,
  albumid int(11) NOT NULL default \'0\',
  performer varchar(128) NOT NULL default \'\',
  length int(11) default NULL,
  name varchar(128) NOT NULL default \'\',
  albumorder int(11) NOT NULL default \'0\',
  genreid int(11) default NULL,
  popularity float default NULL,
  rank int(11) default NULL,
  filename varchar(128) NOT NULL default \'\',
  riperrors varchar(24) default NULL,
  PRIMARY KEY  (trackid)
)'
	);

	foreach my $t (keys %tables) {
		Logger::logger($t);
		my $q = $tables{$t};
		eval {
			$dbh->do($q);
		};
		die($@) if ($@);
	}

}

sub upgrade_to_version2 {
	Logger::logger("upgrading database to version 2");
	my $q = << "EOF"
create table meta (
  name varchar(32),
  value varchar(32)
)
EOF
;
	my $sth = $dbh->prepare($q);
	eval { $sth->execute(); };
	die($@) if ($@);
	$sth->finish;

	$q = "insert into meta (name, value) values ('dbversion', '2')";
	$sth = $dbh->prepare($q);
	eval { $sth->execute(); };
	die($@) if ($@);
	$sth->finish;
}

1;
