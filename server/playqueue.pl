#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/playqueue.pl,v 1.3 2004/01/01 23:26:17 jukebox Exp $

my $BINDIR ='/home/users/jukebox/Jukebox/thundaural/server';

my $bin_mpg123   = '/usr/bin/mpg321';
my $bin_ogg123   = '/usr/bin/ogg123';
my $bin_cdripper = "$BINDIR/ripdisc.pl";
my $bin_logger   = '/usr/bin/logger';

use strict;
use warnings;
use DBI;

my $db_database = 'jukebox';
my $db_hostname = '127.0.0.1';
my $db_port = 3306;
my $db_user = 'jukebox';
my $db_pass = 'jukebox';

my $db_dsn = "DBI:mysql:database=$db_database;host=$db_hostname;port=$db_port";

my $dbh;

use FindBin();
use File::Basename ();
use File::Spec::Functions;
my $SELFSHORT = File::Basename::basename($0);
my $SELF = catfile $FindBin::Bin, $SELFSHORT;

&con;

my $storagedir = &get_conf('storagedir', 'storage', 1);

&clear_status;

my $verbose = 0;
my $logfile = undef;

$SIG{'CHLD'} = 'IGNORE'; # auto-reap all children

&checkreq;

#$0 = "jukebox-monitor-process";

sub checkreq() {
	my $loops = 0;
	while (1) {
		&check_enqueued_songs() if (($loops % 5) == 0);
		#&check_support_programs();

		sleep 1;
		$loops++;
	}
}

sub check_enqueued_songs() {
	# determine which devices don't have anything playing on them
	my $sth;
	my $e = eval {
		my $q = "select * from status s right join layout d on d.devicename = s.devicename where d.type = 'play' having s.name is null";
		#&logger($q) if ($verbose);
		$sth = $dbh->prepare($q);
		$sth->execute;
	};
	my @do = ();
	if (defined($e)) {
		while (my $i = $sth->fetchrow_hashref) {
			push(@do, $i);
		}
		$sth->finish;
	}

	my @playtracks = ();
	foreach my $i (@do) {
		# get the next track to play from the playhistory queue for this device
		my $ttp = undef;
		my $pth;
		my $e = eval {
			my $q = "select * from playhistory where devicename = ? and action = 'queued' order by requestedat limit 1";
			#&logger($q) if ($verbose);
			$pth = $dbh->prepare($q);
			$pth->execute($i->{devicename});
			$ttp = $pth->fetchrow_hashref;
			$pth->finish;
		};
		if (defined($ttp)) { # found something to play
			push(@playtracks, $ttp);
		}
	}

	if (scalar @playtracks) {
		&dcon;
		foreach my $ttp (@playtracks) {
			if (!fork) {
				# in child
				&play_track($ttp->{playhistoryid}, $ttp->{trackid}, $ttp->{devicename});
				exit;
			}
		}
		&con;

	}
}

sub check_support_programs() {
	# find out if we need to start up one of the support programs
	my $pth;
	my $e = eval {
		my $q = "select * from status where name = 'startrip'";
		#&logger($q) if ($verbose);
		$pth = $dbh->prepare($q);
		$pth->execute;
	};

	my @subprogs = ();
	if (defined($e) && defined($pth)) {
		while(my $dorip = $pth->fetchrow_hashref) {
			push(@subprogs, $dorip);
		}
		$pth->finish;
	}

	if (scalar @subprogs) {
		&dcon;
		foreach my $dorip (@subprogs) {
			if (!fork) {
				# in child
				&rip_cd($dorip->{devicename});
				exit;
			}
		}
		&con;
	}
}

sub rip_cd($) {
	my $devicename = shift;

	&con;

	my $devicefile = &get_conf($devicename, 'read');

	# we're in the child now
	$SIG{'INT'}  = 'DEFAULT'; # reset sigchild handler so we can wait

	eval {
		my $sth = $dbh->prepare("delete from status where devicename = ? and name = ?");
		$sth->execute($devicename, 'startrip');
		$sth->finish;
	};


	my $ripprog = [$bin_cdripper, '--device', $devicefile]; #, '--maxtracks', '1'];

	&dcon;
	my $in_parent = fork;
	if (!$in_parent) {
		&logger("spawning ".join(' ', @$ripprog)) if ($verbose);
		(exec @$ripprog) || logger("unable to spawn ".join(' ', @$ripprog));
		exit;
	}
	my $childpid = $in_parent;
	&logger("waiting for $childpid") if ($verbose);
	my $waitedfor = wait;
	&logger("$waitedfor died (was waiting for $childpid)") if ($verbose);
	exit;
}

sub get_decoder_program($) {
	my($type) = shift;
	my $prog = &get_conf($type, 'command');
	my @prog = split(/\s+/, $prog);
	return \@prog;
}

sub play_track($$$) {
	my $playhistoryid = shift;
	my $trackid = shift;
	my $devicename = shift;

	&con;

	# we're in the child now
	$SIG{'INT'}  = 'DEFAULT'; # reset sigchild handler so we can wait

	my $devicefile = &get_conf($devicename, 'play');
	my $track = &trackinfo($trackid);

	if (!$track->{filename}) {
		&logger("unable to get track info for track $trackid");
		die("unable to get track info for $trackid") 
	}

	my $filename = "$storagedir/$track->{filename}";
	my $decodeprg;
	if ($track->{filename} =~ m/\.ogg$/i) {
		$decodeprg = &get_decoder_program('oggplayer');
		#$decodeprg = [$bin_ogg123, '--quiet', '--nth', 5, '-d', 'oss', '-o', "dsp:$devicefile", $filename];
	} elsif ($track->{filename} =~ m/\.mp(e?g)?3$/i) {
		$decodeprg = &get_decoder_program('mp3player');
		#$decodeprg = [$bin_mpg123, '--quiet', '-o','oss', '-a', $devicefile, $filename];
	} else {
		# record this track as failed in playhistory and return
		&playhistory_action($playhistoryid, 'failed');
		exit; # we're in a child
	}

	# do substitutions on the player command
	my $x = [];
	foreach my $y (@$decodeprg) {
		$y =~ s/\${DEVICEFILE}/$devicefile/g;
		$y =~ s/\${FILENAME}/$filename/g;
		push(@$x, $y);
	}
	$decodeprg = $x;

	# log that we started playing it
	&log_current_play($trackid, $devicename);
	&playhistory_action($playhistoryid, 'playing');

	&dcon;
	my $in_parent = fork;
	if (!$in_parent) {
		&logger("spawning ".join(' ', @$decodeprg)) if ($verbose);
		(exec @$decodeprg) || &logger("unable to spawn ".join(' ', @$decodeprg));
		exit -1;
	}

	my $childpid = $in_parent;
	&logger("waiting for $childpid") if ($verbose);
	my $waitedfor = wait;
	my $stat = $? >> 8;
	&logger("$waitedfor died (was waiting for $childpid)") if ($verbose);
	&con;
	&playhistory_action($playhistoryid, ($stat == 0 ? 'played' : 'failed'));
	&log_current_play(undef, $devicename);
	&dcon;
	exit;
}

sub dcon() {
	my ($package, $filename, $line) = caller;
	&logger("dcon from $filename:$line");
	eval {
		$dbh->disconnect;
	};
	#&logger("disconnected") if ($verbose);
}

sub con() {
	my $trace_level = 1;
	my $waittime = 2;
	my ($package, $filename, $line) = caller;
	&logger("con from $filename:$line");
	while (!defined($dbh)) {
		$dbh = DBI->connect($db_dsn, $db_user, $db_pass, {'RaiseError' => 1, 'PrintError'=>1});
#		$dbh->trace($trace_level);
		(print "unable to connect!\n"), last if (defined($dbh));
		&logger("unable to connect to database, waiting for $waittime");
		sleep $waittime;
		$waittime *= 2;
		$waittime = 4 if ($waittime > 40);
	}
	#&logger("connected") if ($verbose);
}

sub playhistory_action($$) {
	my $playhistoryid = shift;
	my $action = shift;

	eval {
		my $q = "update playhistory set action = ?, actedat = now() where playhistoryid = ?";
		my $sth = $dbh->prepare($q);
		$sth->execute($action, $playhistoryid);
		$sth->finish;
	};
}

sub trackinfo($) {
	my $trackid = shift;
	my $track = {};
	eval {
		my $q = "select * from tracks where trackid = ?";
		my $sth = $dbh->prepare($q);
		&logger("getting track info for track $trackid") if ($verbose);
		$sth->execute($trackid);
		$track = $sth->fetchrow_hashref;
		$sth->finish;
	};
	return $track;
}


sub get_conf($) {
	my $name = shift;
	my $type = shift;
	my $die = shift;

	my $df = undef;
	my $e = eval {
		my $q = "select devicefile from layout where devicename = ? and type = ?";
		my $sth = $dbh->prepare($q);
		$sth->execute($name, $type);
		($df) = $sth->fetchrow_array;
		$sth->finish;
	};
	if(!defined($e) || !$df) {
		my $msg = "$0: unable to find $name:$type in layout table";
		&logger("unable to find $name:$type in layout");
		if ($die) {
			die("$$: $msg");
		} else {
			warn("$$: $msg");
		}
	} else {
		&logger("layout: finding $name:$type = $df");
	}
	return $df;
}
																										    
sub log_current_play($$) {
	my $track = shift;
	my $device = shift;
	my($q, $sth);
	if (defined($track)) {
		$q = "insert into status (name, devicename, at, value) values (?, ?, now(), ?)";
		eval {
			$sth = $dbh->prepare($q);
			$sth->execute('trackplaying', $device, $track);
			$sth->finish;
		};
	} else {
		$q = "delete from status where name = ? and devicename = ?";
		eval {
			$sth = $dbh->prepare($q);
			$sth->execute('trackplaying', $device);
			$sth->finish;
		};
	}
}

sub clear_status() {
	eval {
		$dbh->do("delete from status where name = 'trackplaying'");
	};
	eval {
		$dbh->do("update playhistory set action = 'queued' where action = 'playing'");
	};
}

sub parse_cmdline() {
	my $a;
	while (@ARGV) {
		$a = shift @ARGV;
		if ($a =~ m/^--verbose/) {
			$verbose++;
			next;
		}
		if ($a =~ m/^--logfile/) {
			$logfile = shift @ARGV;
			die("$0: missing argument to --logfile\n") if (!$logfile);
			next;
		}
		die("Usage: $0 [--verbose] [--logfile <f>]\n");
	}
}

sub open_log_file {
	return if (!$logfile);
	close(LOG);
	open(LOG, ">$logfile");
}

sub logger($) {
	my $msg = shift;
	my $tag = $SELFSHORT;
	$tag .= "[$$]";
	#my $x = `$bin_logger -t "$tag" -- '$msg'`;
	print STDERR "$tag $msg\n";
}

