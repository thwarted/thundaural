#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/DatabaseSetup.pm,v 1.8 2004/03/21 05:02:37 jukebox Exp $

package DatabaseSetup;

use strict;
use warnings;

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

	Logger::logger("using SQLite version %s", $dbh->{sqlite_version});

	&backup_database($dbfile);
	&create_all_v1_tables() if (&get_db_version() < 1);
	&upgrade_to_version2() if (&get_db_version() < 2);
	&upgrade_to_version3() if (&get_db_version() < 3);

	die("database contains unknown version number\n") if (&get_db_version() != 3);

	&reset_playhistory();

	$dbh->disconnect;

	Logger::logger("database $dbfile configured");
}

sub reset_playhistory {
	# reset the playhistory, in case we were abort before
	my $q = "update playhistory set action = ? where action = ?";
	my $sth = $dbh->prepare($q);
	my $rv = $sth->execute('queued', 'playing');
	$sth->finish;
	if ($rv) {
		$rv += 0;
		Logger::logger("reset $rv queued songs");
	}
}

sub backup_database {
	my $dbfile = shift;

	return if (!-s $dbfile); # don't bother to backup an empty database

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

	my $foundtables = 0;
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

sub create_all_v1_tables {
	my %tables = (
		'creating table albums'=>
'create table albums (
  albumid integer,
  performer varchar(128) default NULL,
  name varchar(128) NOT NULL default \'\',
  cddbid varchar(8) NOT NULL default \'\',
  length int(11) default NULL,
  riptime int(11) default NULL,
  tracks int(11) NOT NULL default \'0\',
  coverartfile varchar(128) default NULL,
  primary key (albumid)
)',
		'creating table genres'=>
'create table genres (
  genreid integer,
  genre varchar(64) NOT NULL default \'\',
  primary key (genreid),
  unique (genre)
)',
		'creating table playhistory'=>
'create table playhistory (
  playhistoryid integer primary key,
  trackid int(11) NOT NULL default \'0\',
  devicename char(32) NOT NULL default \'\',
  requestedat int(11) default NULL,
  action varchar(32) default \'queued\',
  actedat int(11) default NULL
)',
		'creating table tracks'=>
'create table tracks (
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
  primary key (trackid)
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
	eval { $dbh->do($q); };
	die($@) if ($@);

	$q = "insert into meta (name, value) values ('dbversion', '2')";
	eval { $dbh->do($q); };
	die($@) if ($@);
}

sub upgrade_to_version3 {
	Logger::logger("upgrading database to version 3");

	$dbh->begin_work();
	&v3_albumimages();
	&v3_performers();
	&v3_playhistory();
	&v3_albums();
	&v3_trackattributes();
	&v3_tracks();
	$dbh->commit();

	my $q = "update meta set value = ? where name = ?";
	my $sth = $dbh->prepare($q);
	eval { $sth->execute(3, 'dbversion'); };
	die($@) if ($@);
	$sth->finish;
}

sub v3_albumimages {
	# create images table
	my $q = "create table albumimages (\n".
		"  albumid int(11),\n".
		"  label varchar(32) NOT NULL, \n".
		"  preference int(6) not null default 1,\n".
		"  filename varchar(128)\n".
		")";
	eval { $dbh->do($q); };
	die($@) if ($@);

	$q = "insert into albumimages select albumid, 'front cover', 1, coverartfile from albums where coverartfile is not null";
	eval { $dbh->do($q); };
	die($@) if ($@);
}

sub v3_performers {
	my $q = "create table performers (\n".
		"  performerid integer,\n".
		"  name varchar(128) not NULL,\n".
		"  sortname varchar(128) not NULL,\n".
		"  primary key (performerid),\n".
		"  unique (name)\n".
		")";
	eval { $dbh->do($q); };
	die($@) if ($@);

	$q = "insert into performers (performerid, name, sortname) values (NULL, 'Various Artists', 'Various Artists')";
	eval { $dbh->do($q); };
	die($@) if ($@);

	$q = "insert or ignore into performers (performerid, name, sortname) values (?, ?, ?)";
	my $ith = $dbh->prepare($q);

	$q = "select distinct performer from albums";
	my $sth = $dbh->prepare($q);
	eval { $sth->execute; };
	die($@) if ($@);
	while(my($name) = $sth->fetchrow_array()) {
		my $sortname = lc $name;
		$sortname = "$2, $1" if ($sortname =~ m/^(an?|the)\s+(.+)$/i);
		eval { $ith->execute(undef, $name, lc($sortname)); };
		print "$@\n" if ($@);
	}
	$sth->finish;

	$q = "select distinct performer from tracks";
	$sth = $dbh->prepare($q);
	eval { $sth->execute; };
	die($@) if ($@);
	while(my($name) = $sth->fetchrow_array()) {
		my $sortname = lc $name;
		$sortname = "$2, $1" if ($sortname =~ m/^(an?|the)\s+(.+)$/);
		eval { $ith->execute(undef, $name, $sortname); };
		print "$@\n" if ($@);
	}
	$sth->finish;
	$ith->finish;
}

sub v3_playhistory {
	# copy to temporary table
	my $q = "create table playhistoryold as select * from playhistory";
	eval { $dbh->do($q); };
	die($@) if ($@);

	# drop old table
	$q = "drop table playhistory";
	eval { $dbh->do($q); };
	die($@) if ($@);

	# create new table
	$q = "create table playhistory (\n".
	     "  playhistoryid integer,\n".
	     "  trackid int(11) NOT NULL default '0',\n".
	     "  devicename char(32) NOT NULL default '',\n".
	     "  requestedat int(11) default NULL,\n".
	     "  source varchar(32) default NULL,\n".
	     "  action varchar(32) default 'queued',\n".
	     "  actedat int(11) default NULL,\n".
	     "  primary key (playhistoryid)\n".
	     ")\n";
	eval { $dbh->do($q); };
	die($@) if ($@);

	# copy data from temporary table to new playhistory table
	$q = "insert into playhistory select playhistoryid, trackid, devicename,".
	      " requestedat, 'client', action, actedat from playhistoryold";
	eval { $dbh->do($q); };
	die($@) if ($@);

	$q = "drop table playhistoryold";
	eval { $dbh->do($q); };
	die($@) if ($@);
}

sub v3_albums {

	# copy albums to temporary table
	my $q = "create table albumsold as select * from albums";
	eval { $dbh->do($q); };
	die($@) if ($@);

	# drop albums
	$q = "drop table albums";
	eval { $dbh->do($q); };
	die($@) if ($@);

	# create an SQLite function to make it easier to populate the performerid column
	$q = "select performerid, name from performers";
	my $sth = $dbh->prepare($q);
	$sth->execute();
	my $performerslist = {};
	while(my($id, $n) = $sth->fetchrow_array()) {
		$performerslist->{$n} = $id;
	}
	$dbh->func('perfid', 1, sub { my $name = shift; return $performerslist->{$name}; }, 'create_function' );

	# create new albums table
	$q = "create table albums (\n".
		"  albumid integer,\n".
		"  performerid int(11) default NULL,\n".
		"  name varchar(128) NOT NULL default '',\n".
		"  cdindexid varchar(35) default NULL,\n".
		"  cddbid varchar(8) NOT NULL default '',\n".
		"  length int(11) default NULL,\n".
		"  riptime int(11) default NULL,\n".
		"  tracks int(11) NOT NULL default '0',\n".
		"  source varchar(32) default NULL,\n".
		"  primary key (albumid)\n".
		")\n";
	eval { $dbh->do($q); };
	die($@) if ($@);

	# copy data from temporary table to new albums table
	$q = "insert into albums select albumid, perfid(performer), name, NULL, 
	cddbid, length, riptime, tracks, 'freedb' from albumsold";
	eval { $dbh->do($q); };
	die($@) if ($@);

	# drop temporary table
	$q = "drop table albumsold";
	eval { $dbh->do($q); };
	die($@) if ($@);
}

sub v3_trackattributes {
	my $q = "create table trackattributes (\n".
		"  trackid int(11),\n".
		"  attribute varchar(32) not null,\n".
		"  value varchar(32) not null\n".
		")\n";
	eval { $dbh->do($q); };
	die($@) if ($@);

	$q = "insert into trackattributes select trackid, 'genre', genre 
	from tracks t left join genres g on g.genreid = t.genreid";
	eval { $dbh->do($q); };
	die($@) if ($@);
}


sub v3_tracks {
	# copy albums to temporary table
	my $q = "create table tracksold as select * from tracks";
	eval { $dbh->do($q); };
	die($@) if ($@);

	# drop albums
	$q = "drop table tracks";
	eval { $dbh->do($q); };
	die($@) if ($@);

	# create new tracks table
	$q = "create table tracks (\n".
		"  trackid integer,\n".
		"  albumid int(11) NOT NULL default '0',\n".
		"  performerid int(11) NOT NULL default '0',\n".
		"  length int(11) default NULL,\n".
		"  name varchar(128) NOT NULL default '',\n".
		"  albumorder int(11) NOT NULL default '0',\n".
		"  popularity float default NULL,\n".
		"  rank int(11) default NULL,\n".
		"  filename varchar(128) NOT NULL default '',\n".
		"  riperrors varchar(24) default NULL,\n".
		"  primary key (trackid)\n".
		")\n";
	eval { $dbh->do($q); };
	die($@) if ($@);

	# copy data from temporary table to new albums table
	$q = "insert into tracks select trackid, albumid, perfid(performer), length, name, 
	albumorder, popularity, rank, filename, riperrors from tracksold";
	eval { $dbh->do($q); };
	die($@) if ($@);

	# drop temporary table
	$q = "drop table tracksold";
	eval { $dbh->do($q); };
	die($@) if ($@);
}

1;

