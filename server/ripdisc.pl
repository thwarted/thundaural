#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/ripdisc.pl,v 1.13 2004/03/21 06:00:02 jukebox Exp $

use strict;
use warnings;

use TAProgramLocations;

use Data::Dumper;

$| = 1;

# order is important here.  They'll be queried in the order specified
# and the first one to succeed will be used.
my $cdinfo_modules = ['MusicBrainzRemote', 'FreeDB'];
#my $cdinfo_modules = ['FreeDB'];

my $sx = {};
my $taversion = "Thundaural v1.5 Audio Ripper";
my $accepteddbversion = 3;
my $bin_rm = TAProgramLocations::rm();
my $bin_getcoverart = './getcoverart.php';

use TARipUtil;
use DBI;
my $dbh;

&parse_command_line(@ARGV);
&verify_settings;
&cleanup;

my $cdinfo = &get_audiocd_info;

	if (!defined($cdinfo)) {
		&dumpstatus("idle", "unable to get album information from disc");
		exit;
	}

	# do we already have this album ?
	if (&already_have_album($cdinfo)) {
		&dumpstatus('idle', sprintf('already have album %s - %s', $cdinfo->{album}->{performer}, $cdinfo->{album}->{albumname}));
		exit;
	}

	$SIG{HUP} = \&abortus;
	$SIG{TERM} = \&abortus;

	# get the coverart
	my($catemp, $coverartfile);
	{
		$catemp = TARipUtil::mymktempname(
			$sx->{storagedir},
			$sx->{cddevice},
			sprintf('disc%s.coverart.jpg', $cdinfo->{cddbid})
		);

		#$coverartfile = sprintf("coverart/$sortdir/$artist - $albumtitle - $cddbid - coverart.jpg";
		my $cadir = sprintf('coverart/%s', &get_sort_dir($cdinfo->{album}->{performersort}));
		mkdir(sprintf('%s/coverart', $sx->{storagedir}), 0777);
		mkdir(sprintf('%s/%s', $sx->{storagedir}, $cadir), 0777);
		$coverartfile = sprintf('%s/%s - %s - coverart.jpg', 
					$cadir,
					$cdinfo->{album}->{performer}, 
					$cdinfo->{album}->{albumname}
				);

		my $artist = $cdinfo->{album}->{performer};
		$artist =~ s/"//g;
		my $albumtitle = $cdinfo->{album}->{albumname};
		$albumtitle =~ s/"//g;
		my $cmd = "$bin_getcoverart \"$artist\" \"$albumtitle\" $catemp >/tmp/xx1 2>&1";
		&dumpstatus('busy', "finding cover art for \"$artist - $albumtitle\"");
		system($cmd);

		open(W, ">>$catemp");
		close(W);
	}

	my $ripstart = time();
	&rip_tracks($cdinfo);
	my $riptime = time() - $ripstart;

	#print Dumper($cdinfo);

	my $q;

	$dbh->begin_work();

	my $undorenames = {};
	my $failed = 0;
	TRANSACTION:
	while (1) { 
		my $e;

		# add album
		my $perf = $cdinfo->{album}->{performer};
		my $perfsort = $cdinfo->{album}->{performersort};
		my $perfid;
		eval {
			$perfid = &performer_id($perf, $perfsort);
		};
		if ($@) { $failed = $@; last TRANSACTION; }
		my $q = "insert into albums 
			(albumid, performerid, name, cdindexid, cddbid, length, riptime, tracks, source)
			values 
			(NULL,    ?,           ?,    ?,         ?,      ?,      ?,       ?,      ?)";
		$q =~ s/\s+/ /g;
		my $sth = $dbh->prepare($q);
		eval {
			$sth->execute(
				$perfid,
				$cdinfo->{'album'}->{'albumname'},
				$cdinfo->{'cdindexid'},
				$cdinfo->{'cddbid'},
				$cdinfo->{'totaltime'},
				$riptime,
				$cdinfo->{'numtracks'},
				$cdinfo->{'source'}
			);
		};
		$e = $@;
		$sth->finish;
		if ($e) { $failed = "database update: $e"; last TRANSACTION; }
		$q = "select last_insert_rowid()";
		$sth = $dbh->prepare($q);
		my $albumid;
		eval { 
			$sth->execute();
			($albumid) = $sth->fetchrow_array();
		};
		$e = $@;
		$sth->finish;
		if ($e) { $failed = "database update: $e"; last TRANSACTION; }

		# do the cover art
		if (-s $catemp) {
			my $newcafile = sprintf('%s/%s', $sx->{storagedir}, $coverartfile);
			if (!(rename($catemp, $newcafile))) {
				$failed = "renaming cover art failed: $!";
				last TRANSACTION;
			} else {
				$undorenames->{$newcafile} = $catemp;
				my $q = "insert into albumimages (albumid, label, preference, filename) values (?, ?, ?, ?)";
				my $sth = $dbh->prepare($q);
				eval { $sth->execute($albumid, 'front', 1, $coverartfile); };
				my $e = $@;
				$sth->finish;
				if ($e) {
					$failed = "adding cover art to database: $e";
					last TRANSACTION;
				}
			}
		}

		# add each track
		my $albumorder = 1;
		foreach my $track (@{$cdinfo->{tracks}}) {
			if (!$track->{filename} || !$track->{sortdir}) {
				next;
				#$failed = "missing track file for track $albumorder";
				#last TRANSACTION;
			}
			my $sortdir = $track->{sortdir};
			my $destdir = sprintf('%s/%s', $sx->{storagedir}, $sortdir);
			mkdir($destdir, 0777);
			if (!-d $destdir) {
				$failed = "creation of sortdir \"$sortdir\" failed";
				last TRANSACTION;
			}
			my $newfile = sprintf('%s/%s', $destdir, $track->{finalfilename});
			#printf STDERR "renaming\n\t%s\nto\n\t%s\n", $track->{filename}, $newfile;
			if (-e $newfile) {
				$failed = "renaming track to existing file";
				last TRANSACTION;
			}
			if (!(rename($track->{filename}, $newfile))) {
				$failed = "file rename failed: $!";
				last TRANSACTION;
			}
			$undorenames->{$newfile} = $track->{filename};
			my $perf = $track->{performer};
			my $perfsort = $track->{performersort};
			eval {
				$perfid = &performer_id($perf, $perfsort);
			};
			if ($@) { $failed = $@; last TRANSACTION; }
			my $q = "insert into tracks 
					(trackid, albumid, performerid, length, name, albumorder, popularity, rank, filename, riperrors)
				 values
				 	(NULL,    ?,       ?,           ?,      ?,    ?,          NULL,       NULL, ?,        NULL)";
			$q =~ s/\s+/ /g;
			my $sth = $dbh->prepare($q);
			eval {
				$sth->execute(
					$albumid, 
					$perfid, 
					$track->{'length'}, 
					$track->{trackname}, 
					$albumorder, 
					# filename in the database is relative to the storage dir
					sprintf('%s/%s', $sortdir, $track->{finalfilename})
				);
			};
			$e = $@;
			$sth->finish;
			if ($e) { $failed = $e; last TRANSACTION; }
			$albumorder++;
		}

		last TRANSACTION; # we only want to execute this loop once
	}

	if ($failed) {
		$dbh->rollback();
		foreach my $utr (keys %{$undorenames}) {
			rename $utr, $undorenames->{$utr};
		}
		&dumpstatus('idle', sprintf('ripping "%s - %s" failed with error "%s"', $cdinfo->{album}->{performer}, $cdinfo->{album}->{albumname}, $failed));
	} else {
		$dbh->commit();
		&dumpstatus('idle', sprintf('ripping "%s - %s" successful', $cdinfo->{album}->{performer}, $cdinfo->{album}->{albumname}));
	}

$dbh->disconnect;

sub performer_id {
	my $perf = shift;
	my $perfsort = shift;

	my $perfid;
	if ($perfid = &performer_id_lookup($perf)) {
		return $perfid;
	}
	if ($perfid = &performer_id_add($perf, $perfsort)) {
		return $perfid;
	}
	die("unable to add performer\n");
}

sub performer_id_lookup {
	my $perf = shift;
	my $e;

	my $q = "select performerid from performers where name = ? order by performerid limit 1";
	my $sth = $dbh->prepare($q);
	my $perfid;
	eval {
		$sth->execute($perf);
		($perfid) = $sth->fetchrow_array();
	};
	$e = $@;
	$sth->finish;
	die($e) if ($e);
	return $perfid ? $perfid : undef;
}

sub performer_id_add {
	my $perf = shift;
	my $perfsort = shift;

	my $e;
	my $q = "insert into performers (performerid, name, sortname) values (NULL, ?, ?)";
	my $sth = $dbh->prepare($q);
	eval {
		$sth->execute($perf, $perfsort);
	};
	$e = $@;
	$sth->finish;
	die($e) if ($e);
	$q = "select last_insert_rowid()";
	$sth = $dbh->prepare($q);
	my $perfid;
	eval {
		$sth->execute();
		($perfid) = $sth->fetchrow_array();
	};
	$e = $@;
	$sth->finish;
	die($e) if ($e);
	return $perfid ? $perfid : undef;
}

sub already_have_album {
	my $cdinfo = shift;
	my($id, $albumid);

	# check cdindexid
	if (defined($id = $cdinfo->{cdindexid})) {
		my $q = "select albumid from albums where cdindexid = ? limit 1";
		my $sth = $dbh->prepare($q);
		$sth->execute($id);
		($albumid) = $sth->fetchrow_array();
		$sth->finish;
	}
	return $albumid if ($albumid);

	# check cddbid
	if (defined($id = $cdinfo->{cddbid})) {
		my $q = "select albumid from albums where cddbid = ? limit 1";
		my $sth = $dbh->prepare($q);
		$sth->execute($id);
		($albumid) = $sth->fetchrow_array();
		$sth->finish;
	}
	return $albumid if ($albumid);

	return undef;
}

sub rip_tracks {
	my $cdinfo = shift;

	# determine which extractor to use
	my $ripperprg = &find_audio_ripper;
	my $encodeprg = &find_audio_encoder;

	my $tracknum = 0;
	my $totaltracks = scalar @{$cdinfo->{tracks}};
	foreach my $track (@{$cdinfo->{tracks}}) {
		$tracknum++;

		my $dorip = $ripperprg;
		$dorip =~ s/\$cddevice/$sx->{cddevice}/g;
		$dorip =~ s/\$track/$tracknum/g;

		my $outfile = TARipUtil::mymktempname(
				$sx->{storagedir}, 
				$sx->{cddevice}, 
				sprintf('disc%s.track%02d.ogg', $cdinfo->{cddbid}, $tracknum)
			);
	
		my $doenc = $encodeprg;
		$doenc =~ s/\$outfile/$outfile/g;
		$doenc =~ s/\$track/$tracknum/g;

		my $artist = $track->{performer};
		my $title = $track->{trackname};
		my $idtype = $cdinfo->{idtype};
		my $cddbid = $cdinfo->{cddbid};
		my $cdindexid = $cdinfo->{cdindexid};
		my $album = $cdinfo->{album}->{albumname};
		my $tracklen = $track->{sectors} / 75; # in seconds
		if (int($tracklen) != $tracklen) {
			$tracklen = int($tracklen);
			$tracklen++; # final second is not a whole second, just add one
		}
		$doenc =~ s/\$artist\b/$artist/g;
		$doenc =~ s/\$title\b/$title/g;
		$doenc =~ s/\$album\b/$album/g;
		$doenc =~ s/\$taversion\b/$taversion/g;
		$doenc =~ s/\$cdindexid\b/$cdindexid/g;
		$doenc =~ s/\$cddbid\b/$cddbid/g;

		#print "\nrunning\n\t$dorip\n\t$doenc\n";
		my $cmd = "( $dorip 2>/dev/null ) | ( $doenc 2>&1 ) |";
		my $startat = time();
		open(RIP, $cmd);
		my $oldsep = $/;
		$/ = "\cM";
		my $oldpct = 0;
		while(my $line = <RIP>) {
			# [  3.8%] [ 0m45s remaining]
			if (my($pct, $rem) = $line =~ m/\[\s*(\d+\.\d+)%\]\s+\[\s*(\d+m\d+s)\s+remaining\]/) {
				$pct = int($pct);
				if ($pct ne $oldpct) {
					my $speed = &calc_speed($tracklen, $startat, $pct);
					&dumpstatus('ripping', '', "$tracknum/$totaltracks", $artist, $title, 0, $speed, $tracklen, '?', $startat, 0, $pct);
					$oldpct = $pct;
				}
			}
		}
		$/ = $oldsep;
		close(RIP);
		my $runtime = time() - $startat;
		$track->{filename} = $outfile;
		$track->{sortdir} = &get_sort_dir($track->{performersort});
		$track->{finalfilename} = sprintf("%s - %s - %s.ogg", $artist, $album, $title);
	}
}

sub parse_command_line {
	while(@_) {
		my $a = shift @_;
		if ($a =~ m/^--device/) {
			$sx->{cddevice} = shift @_;
			die("$0: missing argument to --device\n")
				unless ($sx->{cddevice});
			next;
		}
		if ($a =~ m/^--storagedir/) {
			$sx->{storagedir} = shift @_;
			die("$0: missing argument to --storagedir\n")
				unless ($sx->{storagedir});
			next;
		}
		if ($a =~ m/^--dbfile/) {
			$sx->{sqlitedb} = shift @_;
			die("$0: missing argument to --dbfile\n")
				unless ($sx->{sqlitedb});
			next;
		}
		die("Usage: $0 --device <cdrom device> --storagedir <storagedir> --dbfile <path to database>\n");
	}
}

sub verify_settings {
	die("$0: missing --storagedir argument\n") unless ($sx->{storagedir});
	die("$0: specified storagedir (".$sx->{storagedir}.") is not an accessible directory.\n")
		unless( -d $sx->{storagedir} &&
			-r $sx->{storagedir} &&
			-w $sx->{storagedir});

	die("$0: missing --device argument\n") unless ($sx->{cddevice});
	die("$0: specified cdrom device (".$sx->{cddevice}.") is not readable\n")
		unless (-r $sx->{cddevice});

	die("$0: missing --sqlitedb argument\n") unless ($sx->{sqlitedb});
	die("$0: database (".$sx->{sqlitedb}.") has zero size\n") unless (-s $sx->{sqlitedb});

	# bind to database
	$dbh = DBI->connect("dbi:SQLite:dbname=".$sx->{sqlitedb},'','',{RaiseError=>1, PrintError=>0, AutoCommit=>1})
		or die(sprintf('%s: unable to bind to database: %s%s', $0, $DBI::errstr, "\n"));

	my $q = "select value from meta where name = 'dbversion'";
	my $sth = $dbh->prepare($q);
	my $dbversion;
	eval {
		$dbversion = 0;
		$sth->execute();
		($dbversion) = $sth->fetchrow_array();
	};
	$sth->finish;
	die("$0: database version ($dbversion) is not $accepteddbversion\n")
		unless ($dbversion == $accepteddbversion);

	#$dbh->trace(2);

	$sx->{devname} = $sx->{cddevice};
	$sx->{devname} =~ s/\W/_/g;
	$sx->{devname} =~ s/_+/_/g;
}

sub get_audiocd_info {
	# get cd information
	#    import module
	#    call lookup method
	#    fail, try next module
	&dumpstatus('busy', 'reading CD info');
	foreach my $module (@$cdinfo_modules) {
		&dumpstatus('busy', "looking up CD info using $module");
		sleep 2;
		$module = sprintf('TARipLookup%s', $module);
		eval "use $module;";
		if ($@) {
			my $x = $@;
			chomp $x;
			&dumpstatus('busy', "including $module: $x");
			sleep 2;
			next;
		}
		my $album;
		eval {
			my $o = new $module(cddevice=>$sx->{cddevice}, storagedir=>$sx->{storagedir});
			$album = $o->lookup();
		};
		if ($@) {
			my $x = $@;
			chomp $x;
			&dumpstatus('busy', $x);
			sleep 2;
			next;
		}
		if (ref($album) eq 'HASH') {
			my $pvtemp = TARipUtil::mymktempname($sx->{storagedir}, $sx->{cddevice}, 'discinfo.pv');
			open(X, ">$pvtemp");
			print X Dumper($album)."\n";
			close(X);
			&dumpstatus('busy', "$module succeeded");
			sleep 1;
			return $album;
		}
	}
	return undef;
}

sub find_audio_ripper {
	# order of priority, gotta have one of these
	my @progs = qw/
		dagrab
		cdda2wav
		cdparanoia
	/;
	my $progopts = {
		dagrab=>'-d $cddevice $track -J -f -',
		cdda2wav=>'--no-infofile --device $cddevice --track $track+$track --output-format wav -',
		cdparanoia=>'--force-cdrom-device $cddevice --stderr-progress --output-wav $track -',
	};

	foreach my $p (@progs) {
		my $px = `which $p 2>/dev/null`;
		if ($px) {
			chomp $px;
			my $px = sprintf('%s %s', $px, $progopts->{$p});
			return $px;
		}
	}
	&dumpstatus("idle", "unable to find an audio ripper (".join(', ', @progs).") in path");
	exit;
}

sub find_audio_encoder {
	my @opts = (
		'--tracknum "$track"',
		'--artist "$artist"',
		'--title "$title"',
		'--album "$album"',
		'-c "RIPPER=$taversion"',
		'-c "CDINDEXID=$cdindexid"',
		'-c "CDDBID=$cddbid"',
		'--output="$outfile"',
		'-'
	);
	my $opts = join(' ', @opts);
	my $px = TAProgramLocations::oggenc();
	if ($px && -x $px) {
		my $px = sprintf('%s %s', $px, $opts);
		return $px;
	}
	&dumpstatus('idle', 'unable to find audio encoder oggenc');
	exit;
}

sub abortus {
	my $ripchild = &pid_using_device($sx->{cddevice});
	if (defined($ripchild) && $ripchild) {
		kill 15, $ripchild;
	}
	exit;
};

sub pid_using_device($) {
	my $d = shift;

	my $p = TAProgramLocations::fuser();
	return undef unless ($p);
	my @x = `$p $d`;
	if (@x) {
		my $x = shift @x;
		my(undef, $p) = split(/\s+/, $x);
		return ($p+0) if ($p =~ m/^\d+f?$/);
	}
	return undef;
}

sub get_sort_dir {
	my $a = shift;

	$a =~ s/^\s+//;
	$a =~ s/^(An?\W|The\W|\W+)//i;
	($a) = $a =~ m/^(\w)/;
	$a = lc $a;
	$a = 'x' if (!$a);
	return $a;
}

sub cleanup {
	&dumpstatus("cleanup");
	my $pattern = TARipUtil::tmpnameprefix($sx->{storagedir}, $sx->{cddevice}).'*';
	`$bin_rm -f $pattern`;
	sleep 2;
}

sub dumpstatus {
	my($state, $volume, $trackref, $performer, $name, $popularity, $rank, $length, $trackid, $started, $current, $percentage) = @_;
	push(@_, '', '', '', '', '', '', '', '', '', '', '', '', '');
	my @x = @_[0..11];
	print $sx->{cddevice}."\t".join("\t", @x)."\n";
	#print "$cddevice\t$state\t$volume\t$tracknum\t$artist\t$trackname\t$pct\t$corrections\n";
}

# dagrab can calculate this for us, but we're using oggenc's output 
# to keep track of progress, since that's a constant (and we might not have
# dagrab, but rather using cdda2wav or cdparanoia)
sub calc_speed($$) {
	my($length, $started, $pct) = @_;
	$pct /= 100;
	my $now = time();
	my $x1 = $now - $started;
	my $xc = $length * $pct;
	my $speed;
	eval { $speed = $xc / $x1; };
	$speed = 0 if ($@);
	$speed = sprintf("%.5f", $speed);
	return $speed;
}

