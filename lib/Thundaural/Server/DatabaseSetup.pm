#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/Thundaural/Server/DatabaseSetup.pm,v 1.9 2004/06/09 06:49:59 jukebox Exp $

package Thundaural::Server::DatabaseSetup;

use strict;
use warnings;

use DBI;
use File::Basename;
use File::Glob ':glob';
use Data::Dumper;

use Thundaural::Util;
use Thundaural::Server::Settings;
use Thundaural::Logger qw(logger);

my $dbh;
my $dbfile;
my $storagedir;

my $keepdbbackups = 5;
my $performerslist = {}; 

sub init {
	my %o = @_;
	$dbfile = $o{dbfile};
	$storagedir = $o{storagedir};

	die("$storagedir isn't a directory\n") if (! -d $storagedir);

	my $d = File::Basename::dirname($dbfile);
	die("$d isn't a directory\n") if (! -d $d);
	if (!(-r $d && -w $d && -x $d)) {
		die("$d isn't fully accessible, check permissions");
	}

	&backup_database($dbfile);

	$dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","", { RaiseError => 1, PrintError=>0 } );
	die("unable to open/create database $dbfile, check permissions\n") if (!$dbh);

	logger("using SQLite version %s", $dbh->{sqlite_version});

	&create_all_v1_tables() if (&get_db_version() < 1);
	&upgrade_to_version2() if (&get_db_version() < 2);
	&upgrade_to_version3() if (&get_db_version() < 3);
	&upgrade_to_version4() if (&get_db_version() < 4);
	&upgrade_to_version5() if (&get_db_version() < 5);

	die("database contains unknown version number, or an error occurred during database upgrade.\n") if (&get_db_version() != 5);

	&reset_playhistory();

	$dbh->disconnect;

	logger("database $dbfile configured");
}

sub reset_playhistory {
	# reset the playhistory, in case we were abort before
	my $q = "update playhistory set action = ? where action = ?";
	my $sth = $dbh->prepare($q);
	my $rv = $sth->execute('queued', 'playing');
	$sth->finish;
	if ($rv) {
		$rv += 0;
		logger("reset $rv queued songs");
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
	logger("backed up database as $dbfilebackup");

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
	my($res, $q, $vv);

	my $foundtables = 0;
	foreach my $table (qw/ albums genres playhistory tracks/) {
		$q = "select * from $table limit 1";
		eval { 
		    my $sth = $dbh->prepare($q);
            $sth->execute(); 
		    $sth->finish();
        };
		$res = $@;
		$foundtables++ if (!$res);
	}
	return 0 if ($foundtables < 4); # create new database

	$q = "select value from meta where name = ? limit 1";
	eval { 
	    my $sth = $dbh->prepare($q);
		$sth->execute('dbversion'); 
		($vv) = $sth->fetchrow_array();
	    $sth->finish();
	};
	$res = $@;
	return 1 if ($@ =~ m/no such table: meta/); # version 1 database
	return $vv;
}

sub set_db_version {
	my $v = shift;

	my $q = "update meta set value = ? where name = ?";
	my $sth = $dbh->prepare($q);
	eval { $sth->execute($v, 'dbversion'); };
	die($@) if ($@);
	$sth->finish;
}

sub tag_files_with_tracknum {
	my %o = @_;
	my $limit = $o{limit} || 0;
	my $pause = $o{pause} || 0;
	my $loose = exists($o{loose});
	my $dryrun = exists($o{dryrun});
	my $albums = $o{albums};
	my $skipiflooksdone = exists($o{skipiflooksdone});

        # bah -- I can't believe I left this out!
	my $vorbiscomment = Thundaural::Server::Settings::program('vorbiscomment');
	die("specify path to vorbiscomment on command line with ".
		"\"--prog vorbiscomment:/the/path/vorbiscomment\"\n") 
		if (!defined($vorbiscomment));

	croak("::init must be called before ::tag_files_with_tracknum")
		if (! -d $storagedir || ! -s $dbfile);
	$dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","", { RaiseError => 1, PrintError=>0 } );
	die("unable to open/create database $dbfile, check permissions\n") if (!$dbh);

        # for each file in the tracks table
       	#   if the file exists
        #     extract the vorbis comments using vorbiscomment -l
       	#     we originally created this file, assume it's safe to manipulate
        #     add a tracknumber=(albumorder) to X1
        #     set the comments on the ogg file using vorbiscomment -w -c X1
        #     rename the file to
        #         performername - albumname - albumorder - trackname.ogg
        #         sprintf("%s - %s - %02d - %s.ogg", $artist, $album, $albumorder, $title);

	my $andalbums;
	if ($albums) {
		my @albums = split(/,/, $albums);
		@albums = grep(/^\d+$/, @albums);
		$andalbums = "and t.albumid in (".join(',', @albums).")";
	}
	my $q = "select t.trackid, 
			t.filename,
			p.name as performername, 
			a.name as albumname, 
			a.cdindexid as cdindexid,
			a.cddbid as cddbid,
			a.source as metasource,
			t.albumorder, 
			t.name as trackname
		from tracks t, 
			performers p, 
			albums a
		where t.albumid = a.albumid 
			and t.performerid = p.performerid
			$andalbums
		order by t.albumid, t.albumorder
			";
	my $sth = $dbh->prepare($q);
	eval {
		$sth->execute();
	};
	if ($@) {
		logger($@);
		exit;
	}
	my @tracks = ();
	while(my $t = $sth->fetchrow_hashref()) {
		push(@tracks, $t);
	}
	$sth->finish;
	logger("found ".scalar(@tracks)." tracks to convert");
	my $handled = 0;
	foreach my $t (@tracks) {
		my $filename = sprintf('%s/%s', $storagedir, $t->{filename});
		my $pat = sprintf(' (-|::) %02d (-|::) ', $t->{albumorder});
		if ($skipiflooksdone && $filename =~ /$pat/) {
			if (!$dryrun) {
				logger("skipping $filename, filename already contains the album number");
				next;
			} else {
				print "skipping $filename, filename already contains the album number\n";
			}
		}
		if (-e $filename && -f $filename && -s $filename) {
			my @comments = ();
			my $ourfile = $loose ? 1 : 0;
			print("found file \"$filename\"\n") if ($dryrun);
			if (open(VCC, '-|', $vorbiscomment, '-l', $filename)) {
				while(my $l = <VCC>) {
					$ourfile++ if ($l =~ m/^RIPPER=Thundaural/);
					push(@comments, $l);
				}
				close(VCC);
			}
			if ($ourfile) {
				# add the cdindexid, if we have it and it's not already in the comments
				if ($t->{cdindexid} && (! grep(/^ALBUMCDINDEXID=/, @comments) ) )  {
					unshift(@comments, sprintf("ALBUMCDINDEXID=%s\n", $t->{cdindexid}) );
				}
				# add the cddbid, if we have it and it's not already in the comments
				if ($t->{cddbid} && (! grep(/^ALBUMCDDBID=/, @comments) ) ) {
					unshift(@comments, sprintf("ALBUMCDDBID=%s\n", $t->{cddbid}) );
				}
				# add the metadata source, if we have it and it's not already in the comments
				if ($t->{metasource} && (! grep(/^METASOURCE=/, @comments) ) ) {
					unshift(@comments, sprintf("METASOURCE=%s\n", $t->{metasource}) );
				}

				# if we're being loose, take responsiblity for this file and add a 
				# RIPPER tag, if one isn't already there
				if (! grep (/^RIPPER=/, @comments) ) {
					unshift(@comments, "RIPPER=Thundaural Audio Ripper\n");
				}

				# replace the tracknumber outright
				my @others = grep(!/^tracknumber=/, @comments);
				push(@others, sprintf('tracknumber=%d%s', $t->{albumorder}, "\n") );
				my $cf = Thundaural::Util::mymktempname($storagedir, 'rename'.(int(rand(9999))), 'vorbiscom');
				print("comments file is $cf\n") if ($dryrun);
				if (!$dryrun) {
					open(CF, ">$cf");
					print CF @others;
					close(CF);
				} else {
					print "Adding the following comments:\n----------\n".join('', @comments)."----------\n";
					print("wrote ".(scalar @others)." comments\n");
				}
				my $newfilename = sprintf('%s/%s :: %s :: %02d :: %s.ogg', File::Basename::dirname($t->{filename}),
					&unslash($t->{performername}), &unslash($t->{albumname}), $t->{albumorder}, &unslash($t->{trackname}));
				my $fullpathnewfile = sprintf('%s/%s', $storagedir, $newfilename);
                                if ($filename eq $fullpathnewfile) {
                                        $fullpathnewfile .= ".new";
                                }
    			        my @cmd = ($vorbiscomment, '-w', '-c', $cf, $filename, $fullpathnewfile);
				if (!$dryrun) {
					my @db = @cmd;
					$db[4] = "'".$db[4]."'";
					$db[5] = "'".$db[5]."'";
					logger(join(' ', @db));
					if (system(@cmd) == 0) {
						if (-s $fullpathnewfile) {
							my $qu = sprintf('update tracks set filename = %s where trackid = %d', 
									$dbh->quote($newfilename), $t->{trackid});
							print "$qu\n";
							my $rows = $dbh->do($qu);
							if ($rows) {
								print "update succeeded, deleting old file\n";
								unlink(sprintf('%s/%s', $storagedir, $t->{filename}));
                                                                if ($fullpathnewfile =~ m/\.new$/) {
                                                                        my $x = $fullpathnewfile;
                                                                        $x =~ s/\.new$//;
                                                                        rename $fullpathnewfile, $x;
                                                                }
							} else {
								print "update failed, deleting new file\n";
								unlink($fullpathnewfile);
							}
						}
					}
					sleep $pause if ($pause);
					unlink $cf;
				} else {
					$cmd[4] = "'".$cmd[4]."'";
					$cmd[5] = "'".$cmd[5]."'";
					print(join(' ', @cmd)."\n");
					print "old track filename is '".$t->{filename}."'\n";
					print "new track filename is '".$newfilename."'\n";
					print "===================================\n\n";
				}
				$handled++;
				last if ($limit && $handled >= $limit);
			}
		} else {
			logger("unable to locate file $filename for track ".$t->{trackid}."\n");
		}
	}

	$dbh->disconnect;
}

sub unslash {
	my $x = shift;
	$x =~ s!/!-!g;
	return $x;
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
		logger($t);
		my $q = $tables{$t};
		eval {
			$dbh->do($q);
		};
		die($@) if ($@);
	}

}

sub upgrade_to_version2 {
	logger("upgrading database to version 2");

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
	logger("upgrading database to version 3");

    # can't create a function while inside a transaction with SQLite3 (DBD::SQLite 1.x)
    # so create it here.  Note that it references a global variable
	$dbh->func('perfid', 1, sub { my $name = shift; return $performerslist->{$name}; }, 'create_function' );

	$dbh->begin_work();
	&v3_albumimages();
	&v3_performers();
	&v3_playhistory();
	&v3_albums();
	&v3_trackattributes();
	&v3_tracks();
	$dbh->commit();

	&set_db_version(3);
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

	$q = "insert into performers (performerid, name, sortname) values (NULL, 'Various Artists', 'various artists')";
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
	while(my($id, $n) = $sth->fetchrow_array()) {
		$performerslist->{$n} = $id;
	}
    $sth->finish();

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

sub upgrade_to_version4 {
	logger("upgrading database to version 4");

	$dbh->begin_work();
	&v4_create_views();
	$dbh->commit();

	&set_db_version(4);
}

sub v4_create_views {
	my $q = "create view performer_ranking as select count(1) as tracksplayed, ".
		"p.performerid as performerid, p.name as name from playhistory ph left ".
		"join tracks t on t.trackid = ph.trackid left join performers p on ".
		"p.performerid = t.performerid where ph.action = 'played' group by 2";
	eval { $dbh->do($q); };
	die($@) if ($@);
}

sub upgrade_to_version5 {
    # oh bother -- the size of the filename field isn't big enough
    # recreate the tracks table, making it bigger
    # then look for files in the database that don't end with a known
    # extension (versions before 5 only support ogg, so we're good there)
    # then glob to search for a matching filename.  If we find a single match,
    # update the database with the full path.  If we find more than one (or none,
    # but finding no matches should be impossible unless the database and/or
    # filesystem changed out from under us) then emit a warning and continue.
    logger("upgrading database to version 5");

    $dbh->begin_work();
    &v5_set_proper_various_artists_sortname();
    &v5_create_larger_tracksfilename_column();
    &v5_expand_filenames();
    &v5_set_proper_front_cover_string();
    $dbh->commit();

    &set_db_version(5);
}

sub v5_set_proper_various_artists_sortname {
    my $q = "update performers set sortname = 'various artists' where name = 'Various Artists'";
	eval { $dbh->do($q); };
	die($@) if ($@);
}

sub v5_create_larger_tracksfilename_column {
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
		"  filename varchar(255) NOT NULL default '',\n".
		"  riperrors varchar(24) default NULL,\n".
		"  primary key (trackid)\n".
		")\n";
	eval { $dbh->do($q); };
	die($@) if ($@);

	# copy data from temporary table to new albums table
	$q = "insert into tracks select trackid, albumid, performerid, length, name, 
	albumorder, popularity, rank, filename, riperrors from tracksold";
	eval { $dbh->do($q); };
	die($@) if ($@);

	# drop temporary table
	$q = "drop table tracksold";
	eval { $dbh->do($q); };
	die($@) if ($@);
}

sub v5_expand_filenames {
	my @i = ();
	my $q = "select trackid, filename from tracks where filename not like '%.ogg'";
	my $sth = $dbh->prepare($q);
	$sth->execute();
	while(my($trackid, $filename) = $sth->fetchrow_array()) {
		push(@i, [$trackid, $filename]);
	}
	$sth->finish;
	while (@i) {
		my $row = shift @i;
		my($trackid, $filename) = @{$row};
		my $p = sprintf('%s/%s*.ogg', $storagedir, quotemeta($filename));
		my @list = bsd_glob($p);
		my $count = scalar @list;
		if ($count == 1) {
			my $newfilename = shift @list;
			# we had to glob the full path, remove the storagedir
			$newfilename =~ s!^$storagedir/!!g;
			logger("found short track filename for track $trackid, expanding to:");
			logger($newfilename);
			$q = "update tracks set filename = ? where trackid = ?";
			$sth = $dbh->prepare($q);
			$sth->execute($newfilename, $trackid);
			$sth->finish;
		} else {
			logger("more than one match found for track $trackid, not updating");
			foreach my $x (@list) {
				logger($x);
			}
		}
	}
}

sub v5_set_proper_front_cover_string {
    my $q = "update albumimages set label = 'front cover' where label = 'front'";
    $dbh->do($q);
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
