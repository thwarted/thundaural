
package ServerCommands;

use strict;
use warnings;

use threads;
use threads::shared;

use DBI;

use Settings;
use Logger;

# $Header: /home/cvs/thundaural/server/ServerCommands.pm,v 1.4 2004/01/01 23:24:21 jukebox Exp $

my @cmds = sort qw/pause skip tracks queued devices play albums quit help noop volume status who name rip abort/;

sub new {
	my $class = shift;
	my %opts = @_;

	my $this = {};
	bless $this, $class;

	$this->{-dbfile} = $opts{-dbfile};
	die("no dbfile specified") if (!$this->{-dbfile});
	die("unable to location dbfile ".$this->{-dbfile}) if (!-e $this->{-dbfile});

	$this->{-dblock} = $opts{-ref_dblock};
	die("dblock isn't a reference") if (!ref($this->{-dblock}));
	die("dblock isn't a reference to a scalar") if (ref($this->{-dblock}) ne 'SCALAR');
	die("bad dblock passed") if (${$this->{-dblock}} != 0xfef1f0fa);

	$this->{-playerthrs} = $opts{-playerthrs};

	foreach my $device (keys %{$this->{-playerthrs}}) {
		if (!defined($this->{-playerthrs}->{$device}->{-object}->{-cmdqueue}) || 
		    !$this->{-playerthrs}->{$device}->{-object}->{-cmdqueue}->isa('Thread::Queue')) {
			Logger::logger("didn't pass valid cmdqueue, remote control will be disabled for $device");
		} else {
			Logger::logger("$device has a valid playercmds queue");
		}
	}

	$this->{-readerthrs} = $opts{-readerthrs};

	foreach my $device (keys %{$this->{-readerthrs}}) {
		if (!defined($this->{-readerthrs}->{$device}->{-object}->{-cmdqueue}) || 
		    !$this->{-readerthrs}->{$device}->{-object}->{-cmdqueue}->isa('Thread::Queue')) {
			Logger::logger("didn't pass valid cmdqueue, remote control will be disabled for $device")
		} else {
			Logger::logger("$device has a valid readercmds queue");
		}
	}

	$this->{-dbh} = DBI->connect("dbi:SQLite:dbname=".$this->{-dbfile},"","");
	die("unable to open \"".$this->{-dbfile}."\"") if (!$this->{-dbh});
	$this->{-sqlvariables} = {};
	$this->{-dbh}->func('setval', 2, sub { 
			my $name = shift; 
			my $value = shift; 
			$this->{-sqlvariables}->{$name} = $value; 
			Logger::logger("setval($name, $value)");
			return $value; 
		}, 'create_function' );
	$this->{-dbh}->func('nextval', 1, sub { 
			my $name = shift; 
			if (!exists($this->{-sqlvariables}->{$name})) {
				$this->{-sqlvariables}->{$name} = 0;
			}
			my $v = $this->{-sqlvariables}->{$name}++;
			Logger::logger("nextval($name) = $v");
			return $v; 
		}, 'create_function' );

	return $this;
}

sub process {
	my $this = shift;
	my $input = shift;
	my $fh = shift;
	my $connections = shift;

	$input =~ s/^\s+//g;
	$input =~ s/\s+$//g;

	my ($word, $args) = $input =~ m/^(\w+)\s*(.*)$/;

	if ($word) {
		my $c = "\$this->cmd_$word(\$args, \$fh, \$connections);";
		my @ret = eval $c;
		if ($@ =~ m/Can't locate object method/) {
			return (400, ["400 unknown command \"$word\"\n"]);
		}
		return @ret;
	}
	return (400, ["400 unmatched input\n"]);
}

sub cmd_who {
	my $this = shift;
	my $input = shift;
	my $thisclient = shift;
	my $connections = shift;

	if ($input =~ m/^help/) {
		return (200, "200 who - print a list of client connections\n");
	}

	my @r = ();
	my $f = "\%s\t\%s\t\%d\t\%d\n";
	my $x = $f;
	$x =~ s/\%d/\%s/g;
	foreach my $c (keys %$connections) {
		push(@r, sprintf $f, $connections->{$c}->{peername},
			($connections->{$c}->{name} || ''),
			($connections->{$c}->{inputs} || 0),
			($connections->{$c}->{outputs} || 0));
	}
	return $this->_format_list(200, 'client name inputs outputs', [@r]);
}

sub cmd_ps {
	my $this = shift;
	my $input = shift;

	if ($input =~ m/^help/) {
		return (200, "200 ps - show process list\n");
	}

	my @x = `/bin/ps auxwf`;
	my $keys = shift @x;
	$keys = lc $keys;
	$keys =~ s/\s+/ /g;
	return $this->_format_list(200, $keys, [@x]);
}

sub cmd_name {
	my $this = shift;
	my $input = shift;
	my $fh = shift;
	my $connections = shift;

	if ($input =~ m/^help/) {
		return (200, "200 name <name> - name your connection <name>\n");
	}

	($input) = $input =~ m/^(.{1,20})/;
	if (!$input) {
		$input = $connections->{$fh}->{name};
	} elsif ($input =~ m/reset/) {
		$input = $connections->{$fh}->{peername};
		$connections->{$fh}->{name} = $input;
	} else {
		$connections->{$fh}->{name} = $input;
	}
	return (200, "200 name set to \"$input\"\n");
}

sub cmd_volume {
	my $this = shift;
	my $input = shift;

	if ($input =~ m/^help/) {
		return (200, "200 volume <device> [<amount>] - print current volume on <device>, or change it to <amount>, which can be relative\n");
	}

	my @x = split(/\s+/, $input);
	my $d = shift @x;
	if (!$d) {
		return (400, "400 must specify devicename\n");
	}
	if (!$this->_is_valid_devicename_for_type($d, 'mixer')) {
		return (400, "401 unknown mixer devicename\n");
	}
	my $qcmd = Settings::get('volumequery', 'command');
	return (400, "400 error occured getting query command configuration\n") if (!$qcmd);
	my $mixer = Settings::get($d, 'mixer');
	return (400, "400 error occured getting mixer configuration\n") if (!$mixer);
	$qcmd =~ s/\${DEVICEFILE}/$mixer/g;

	my $newvol = shift @x;
	if (defined($newvol) && $newvol =~ m/^\d+$/) {
		if ($newvol !~ m/[+-]?\d+/) {
			return (400, "400 invalid volume value \"$newvol\"\n");
		}
		my $scmd = Settings::get('volumeset', 'command');
		if (!$scmd) {
			return (400, "400 error occured getting set command configuration\n");
		}
		$scmd =~ s/\${DEVICEFILE}/$mixer/g;
		$scmd =~ s/\${VOLUME}/$newvol/g;
		my $oldvolsetting = $this->_parse_aumix_output($qcmd);
		@x = `$scmd 2>/dev/null`;
		my $newvolsetting = $this->_parse_aumix_output($qcmd);
		return (200, "200 volume changed from $oldvolsetting to $newvolsetting\n");
	} else {
		my $curvolsetting = $this->_parse_aumix_output($qcmd);
		return $this->_format_list(200, "device volume", ["$d\t$curvolsetting\n"]);
	}
	return 200;
}

sub _parse_aumix_output {
	my $this = shift;
	my $cmd = shift;
	# we only handle aumix here
	die("passed command doesn't reference aumix") if ($cmd !~ m/aumix/);
	my @x = `$cmd 2>/dev/null`;
	chomp @x;
	@x = grep /^vol /, @x; # should only return one line
	my $vs = shift @x; # even if it doesn't, take the first one
	@x = split(/[,\s]+/, $vs);
	shift @x; # vol
	# only handles one channel (left, I think), thats 
	# okay, we only set one, which sets both
	$vs = shift @x; 
	return $vs;
}

sub cmd_status {
	my $this = shift;
	my $input = shift;

	if ($input =~ m/^help/) {
		return (200, "200 status - display current track being played, volume and cd ripping info\n");
	}

	my @r = ();
	my @keys = qw/devicename type state volume trackref performer name genre popularity rank length trackid started current percentage/;
	my $outputs = Settings::get_of_type('play');

	foreach my $o (@$outputs) {
		my(@v, $c, $l, $p, $t, $a, $r, $tr);
		my $dev = $o->{devicename};
		my $pvo = $this->{-playerthrs}->{$dev}->{-object};

		my $qcmd = Settings::get('volumequery', 'command');
		return (400, "400 error occured getting query command configuration\n") if (!$qcmd);
		my $mixer = Settings::get($dev, 'mixer');
		return (400, "400 error occured getting mixer configuration\n") if (!$mixer);
		$qcmd =~ s/\${DEVICEFILE}/$mixer/g;
		my $curvolsetting = $this->_parse_aumix_output($qcmd);

		if (my $x = $pvo->position()) {
			($c, $l, $p) = split(/\t/, $x);
		}
		if (!$c || !$l || !$p) {
			($c, $l, $p) = ('', '', '');
		}
		my $x = $pvo->track();
		if ($x) {
			($t, $a) = split(/\t/, $x);
			lock(${$this->{-dblock}});
			my $q = "select * from tracks t left join genres g on t.genreid = g.genreid where trackid = ? limit 1";
			my $sth = $this->{-dbh}->prepare($q);
			$sth->execute($t);
			$r = $sth->fetchrow_hashref();
			$sth->finish();
			$tr = sprintf("%d/%d", $r->{albumid}, $r->{albumorder});
		} else {
			($t, $a) = ('', '');
			$tr = '';
			$r = {performer=>'', name=>'', genre=>''};
		}
		@v = (
			$dev,
			'play',
			$pvo->state(),
			$curvolsetting,
			$tr,
			$r->{performer},
			$r->{name},
			$r->{genre},
			sprintf('%.7f', ($r->{popularity} || 0)),
			($r->{rank} || 0),
			$l,
			$t,
			$a,
			$c,
			$p,
		);
		push(@r, join("\t", @v)."\n");
	}

	my $inputs = Settings::get_of_type('read');
	foreach my $i (@$inputs) {
		my(@v, $c, $l, $p, $t, $a, $r, $tr);
		my $dev = $i->{devicename};
		my $rvo = $this->{-readerthrs}->{$dev}->{-object};
		my $x = $rvo->track();
		my @x;
		if ($x) {
			@x = split(/\t/, $x);
		} else {
			@x = ('', '', '', '', '', '', '', '', '', '', '', '');
		}

		@v = ($dev, 'read', $rvo->state(), @x);
		push(@r, join("\t", @v)."\n");

	}

	return $this->_format_list(200, join(' ', @keys), [@r]);
}

sub cmd_rip {
	my $this = shift;
	my $input = shift;

	if ($input =~ m/^help/) {
		return (200, "200 rip <devicename> - start ripping from <devicename>\n");
	}

	my @x = split(/\s+/, $input);
	my $devicename = shift @x;
	return (400, "400 missing devicename\n") if (!$devicename);

	if (exists $this->{-readerthrs}->{$devicename}) {
		my $rvo = $this->{-readerthrs}->{$devicename}->{-object};
		my $state = $rvo->state();
		if ($state eq 'idle') {
			if (ref($rvo->cmdqueue()) eq 'Thread::Queue') {
				$rvo->cmdqueue()->enqueue('startrip');
				return (200, "200 starting rip\n");
			} else {
				return (500, "500 internal error, $devicename reader doesn't have a valid command queue\n");
			}
		} else {
			return (400, "400 $devicename is busy\n");
		}
	} else {
		return (400, "400 unknown devicename $devicename\n");
	}
}

sub cmd_abort {
	my $this = shift;
	my $input = shift;

	if ($input =~ m/^help/) {
		return (200, "200 abort <devicename> - abort current rip operation on <devicename>\n");
	}

	my @x = split(/\s+/, $input);
	my $devicename = shift @x;
	return (400, "400 missing devicename\n") if (!$devicename);

	if (exists $this->{-readerthrs}->{$devicename}) {
		my $rvo = $this->{-readerthrs}->{$devicename}->{-object};
		my $state = $rvo->state();
		if ($state ne 'idle') {
			if (ref($rvo->cmdqueue()) eq 'Thread::Queue') {
				$rvo->cmdqueue()->enqueue('abort');
				return (200, "200 aborting rip\n");
			} else {
				return (500, "500 internal error, $devicename reader doesn't have a valid command queue\n");
			}
		} else {
			return (400, "400 $devicename is not ripping\n");
		}
	} else {
		return (400, "400 unknown devicename $devicename\n");
	}
}

sub cmd_pause {
	my $this = shift;
	my $input = shift;

	if ($input =~ m/^help/) {
		return (200, "200 pause <devicename> - pause the currently play song\n");
	}

	my @x = split(/\s+/, $input);
	my $devicename = shift @x;
	return (400, "400 missing devicename\n") if (!$devicename);

	if (exists $this->{-playerthrs}->{$devicename}) {
		my $pvo = $this->{-playerthrs}->{$devicename}->{-object};
		my $state = $pvo->state();
		if ($state ne 'idle') {
			if (ref($pvo->cmdqueue()) eq 'Thread::Queue') {
				$pvo->cmdqueue()->enqueue('pause');
				return (200, "200 paused $devicename\n");
			} else {
				return (500, "500 internal error, $devicename player doesn't have a valid command queue\n");
			}
		} else {
			return (400, "400 $devicename is not in a pausable state, currently $state\n");
		}
	} else {
		return (400, "400 unknown devicename $devicename\n");
	}
}

sub cmd_skip {
	my $this = shift;
	my $input = shift;

	if ($input =~ m/^help/) {
		return (200, "200 skip <devicename> - skip the current song\n");
	}

	my @x = split(/\s+/, $input);
	my $devicename = shift @x;
	return (400, "400 missing devicename\n") if (!$devicename);
	# at this point, we'll have to determine which command queue it goes into

	if (exists $this->{-playerthrs}->{$devicename}) {
		my $pvo = $this->{-playerthrs}->{$devicename}->{-object};
		my $state = $pvo->state();
		if ($state eq 'playing' || $state eq 'paused') {
			if (ref($pvo->cmdqueue()) eq 'Thread::Queue') {
				$pvo->cmdqueue()->enqueue('skip');
				return (200, "200 skipped on $devicename\n");
			} else {
				return (500, "500 internal error, $devicename player doesn't have a valid command queue\n");
			}
		} else {
			return (400, "400 $devicename is not playing, currently $state\n");
		}
	} else {
		return (400, "400 unknown devicename $devicename\n");
	}
}

sub cmd_track {
	my $this = shift;
	my $input = shift;

	if ($input =~ m/^help/) {
		return (200, "200 track <t> - info about track <t>, trackid or trackref");
	}

	my @x = split(/\s+/, $input);
	my $t = shift @x;
	my $where = '';
	my @a = ();
	if ($t =~ m/^\d+$/) {
		@a = ($t);
		$where = 'trackid = ?';
	} elsif (my($a,$t) = $t =~ m/^(\d+)\/(\d+)$/) {
		@a = ($a, $t);
		$where = 'albumid = ? and albumorder = ?';
	} else {
		return (401, "401 missing or misformed <track>\n");
	}
	my @r = ();
	my $a;
	{
		lock(${$this->{-dblock}});
		my $q = "select * ".
			"from tracks t left join genres g on t.genreid = g.genreid ".
			"where $where limit 1";
		my $sth = $this->{-dbh}->prepare($q);
		$sth->execute(@a);
		$a = $sth->fetchrow_hashref();
		$sth->finish;
	}
	my $x = sprintf("%d/%d\t%s\t%s\t".
			"%s\t%d\t%d\t".
			"%.7f\t%d\t%d\t%d\t%d\t%d\n", 
			$a->{albumid}, $a->{albumorder}, $a->{performer}, $a->{name}, 
			$a->{genre}, $a->{length}, $a->{trackid},
			($a->{popularity} || 0), ($a->{rank} || 0), time(), time(), 1, 0);
	push (@r, $x);
	return $this->_format_list(200, "trackref performer name genre length trackid".
			" popularity rank last-played last-queued times-played times-skipped", [@r]);
}

sub cmd_rankupdate {
	my $this = shift;
	my $input = shift;

	if ($input =~ m/^help/) {
		return (200, "200 rankupdate - update the play rankings for all tracks\n");
	}

	my $start = time();
	$this->_update_track_ranks();
	my $end = time();
	return (200, "200 done in ".($end-$start)." seconds\n");
}


sub cmd_tracks {
	my $this = shift;
	my $input = shift;

	if ($input =~ m/^help/) {
		return (200, "200 tracks <albumid> - tracks on album <albumid>\n");
	}

	my @x = split(/\s+/, $input);
	my $albumid = shift @x;
	return (401, "401 missing <albumid>\n") if (!$albumid);

	my @r = ();
	{
		lock(${$this->{-dblock}});
		my $q = "select * ". # trackid, performer, name, length, albumorder, genre ".
			"from tracks t left join genres g on t.genreid = g.genreid ".
			"where albumid = ? order by albumorder";
		my $sth = $this->{-dbh}->prepare($q);
		$sth->execute($albumid);
		while(my $a = $sth->fetchrow_hashref()) {
			my $x = sprintf("%d/%d\t".
					"%s\t%s\t%s\t%d\t%d\t".
					"%.7f\t%d\n",
					$albumid, $a->{albumorder}, 
					$a->{performer}, $a->{name}, $a->{genre}, $a->{length}, $a->{trackid}, 
					($a->{popularity} || 0), ($a->{rank} || 0));
			push(@r, $x);
		}
		$sth->finish;
	}
	return $this->_format_list(200, "trackref performer name genre length trackid popularity rank", [@r]);
}

sub cmd_queued {
	my $this = shift;
	my $input = shift;

	if ($input =~ m/^help/) {
		return (200, "200 queued [<devicename>] - list songs queued on <devicename>, or all devices\n");
	}

	my @x = split(/\s+/, $input);
	my $devicename = shift @x;
	my @a = ();
	if ($devicename) {
		if (!$this->_is_valid_devicename_for_type($devicename, 'play')) {
			return (400, "401 unknown play devicename\n");
		}
		@a = ($devicename);
	}
	my $q = "select * from playhistory ph 
	             left join tracks t on ph.trackid = t.trackid 
		     left join genres g on g.genreid = t.genreid 
		  where ph.action = ?";
	if ($devicename) {
		$q .= " and devicename = ?";
	}
	$q .= " order by requestedat, devicename";
	lock(${$this->{-dblock}});
	my $sth = $this->{-dbh}->prepare($q);
	$sth->execute('queued', @a);
	my $total = 0;
	my @r = ();
	while (my $a = $sth->fetchrow_hashref()) {
		my $x = sprintf("%s\t%d/%d\t%s\t%s\t%s\t%d\t%s\t%d\t%.7f\t%d\n", $a->{devicename}, $a->{albumid}, 
				$a->{albumorder}, $a->{performer}, $a->{name}, $a->{genre}, $a->{length}, 
				$a->{trackid}, $a->{requestedat}, ($a->{popularity} || 0), ($a->{rank} || 0));
		push(@r, $x);
		$total++;
	}
	$sth->finish;
	return $this->_format_list(200, "devicename trackref performer name genre length trackid requestedat popularity rank", [@r]);
}

sub _is_valid_devicename_for_type($$) {
	my $this = shift;
	my $devicename = shift;
	my $type = shift;

	return Settings::get($devicename, $type);
}

sub _default_playdevice {
	my $this = shift;

	return Settings::default_play_device();
}

sub cmd_devices {
	my $this = shift;
	my $input = shift;

	if ($input =~ m/^help/) {
		return (200, "200 devices [<type>] - print the devices, filter on <type>\n");
	}

	my @x = split(/\s+/, $input);
	my $type = shift @x;

	my $r = Settings::get_of_type($type);
	my $total = 0;
	my @r = ();
	foreach my $rx (@$r) {
		if ($rx->{type} ne 'command' && $rx->{type} !~ m/^_/) {
			# don't print commands, we should keep those private
			push(@r, sprintf("%s\t%s\n", $rx->{devicename}, $rx->{type}));
		}
		$total++;
	}
	return $this->_format_list(200, "device-name type", [@r]);
}

sub cmd_play {
	my $this = shift;
	my $input = shift;

	if ($input =~ m/^help/) {
		return (200, "200 play <t> [<devicename>] - queue track <t>, where <t> is a ".
			  "trackref or a trackid, <devicename> defaults to ".
			  "the default device\n");
	}

	my @x = split(/\s+/, $input);
	my $ttp = shift @x;
	if (!$ttp) {
		return (401, "401 error, missing track and destination device\n");
	}
	my $devicename = shift @x;
	if ($devicename) {
		if (!$this->_is_valid_devicename_for_type($devicename, 'play')) {
			return (401, "401 invalid device $devicename\n");
		}
	} else {
		$devicename = $this->_default_playdevice();
	}
	my $trackid;
	if (my($albumid, $tracknum) = $ttp =~ m/^(\d+)\/(\d+)$/) {
		my $q = "select trackid from tracks where albumid = ? and albumorder = ? limit 1";
		lock(${$this->{-dblock}});
		my $sth = $this->{-dbh}->prepare($q);
		$sth->execute($albumid, $tracknum);
		($trackid) = $sth->fetchrow_array();
		$sth->finish;
	} elsif ($ttp =~ m/^\d+$/) {
		$trackid = $ttp;
	} else {
		return (401, "401 invalid track\n");
	}
	$trackid += 0;
	if ($trackid) {
		my $q = "insert into playhistory (playhistoryid, trackid, devicename, requestedat, action) values (NULL, ?, ?, ?, ?)";
		lock(${$this->{-dblock}});
		my $sth = $this->{-dbh}->prepare($q);
		$sth->execute($trackid, $devicename, time(), 'queued');
		$sth->finish;
		return (200, "200 queued $trackid on $devicename\n");
	} else {
		return (404, "404 track $ttp doesn't exist\n");
	}
	return (500, "500 internal error in play function\n"); # should never get here
}

sub cmd_album {
	my $this = shift;
	my $input = shift;

	return $this->xcmd_albums($input);
}

sub cmd_albums {
	my $this = shift;
	my $input = shift;

	if ($input =~ m/^help/) {
		return (200, "200 album[s] [<albumid>] - list all albums\n");
	}

	my @albumids = split(/\s+/, $input);

	lock(${$this->{-dblock}});
	my $q = "select albumid, performer, name, length, tracks, coverartfile from albums";
	if (@albumids) {
		my @x = ();
		foreach my $y (@albumids) {
			if ($y =~ m/^\d+$/) {
				$y += 0;
				push(@x, $y) if ($y);
			}
		}
		$q .= " where albumid in (".join(',', @x).")";
	}
	$q .= " order by performer, name";
	my $sth = $this->{-dbh}->prepare($q);
	$sth->execute;
	my @r = ();
	while(my $a = $sth->fetchrow_hashref()) {
		my $caf = '';
		if ($a->{coverartfile}) {
			$caf = $a->{coverartfile};
		}
		my $x = sprintf "%d\t%s\t%s\t%d\t%d\t%s\n", $a->{albumid}, $a->{performer}, $a->{name}, $a->{length}, $a->{tracks}, $caf;
		push(@r, $x);
	}
	$sth->finish;
	return $this->_format_list(200, "albumid performer name length tracks coverartfile", [@r]);
}

sub cmd_quit {
	my $this = shift;

	return (0, "200 goodbye\n");
	# the goodbye line won't be printed
}

sub cmd_help {
	my $this = shift;
	my $input = shift;

	if ($input =~ m/^help/) {
		return (200, "200 help [<command>] - show list of commands or description of <command>\n");
	}

	my ($word, $args) = $input =~ m/^(\w+)\s*(.*)$/;
	if ($word) {
		my $c = "\$this->cmd_$word('help');";
		my @ret = eval $c;
		if ($@ =~ m/Can't locate object method/) {
			return (400, "400 unknown command \"$word\"\n");
		}
		return @ret;
	}

	my @r = ();
	foreach my $c (@cmds) {
		my $c = "\$this->cmd_$c('help');";
		my($ret, $lines) = eval $c;
		next if ($ret > 299);
		if (ref($lines) ne 'ARRAY') {
			push(@r, $lines);
		} else {
			push(@r, @$lines);
		}
	}
	return $this->_format_list(200, "", [@r]);
}

sub cmd_noop {
	my $this = shift;
	my $input = shift;

	if ($input =~ m/^help/) {
		return (200, ["200 noop [<string>] - no operation, use this to sync up with the output, will print the optional <string>\n"]);
	}

	$input = " $input" if ($input);

	return (200, ["200 noop$input\n"]);
}

sub cmd_time {
	my $this = shift;
	my $input = shift;

	if ($input =~ m/^help/) {
		return (200, "200 time - display the server's idea of the current time\n");
	}
	return (200, "200 ".time()."\n");
}

sub _format_list {
	my $this = shift;
	my $rescode = shift;
	my $format = shift;
	my $lines = shift;

	$rescode += 0;
	my $c = scalar @$lines;
	my $headerline = "$rescode count $c ($format)\n";
	return ($rescode, [$headerline, @$lines, ".\n"]);
}

sub _update_track_ranks {
	my $this = shift;

	# get total of how many tracks have been played
	my $q = "select count(1) from playhistory where action = ?";
	my $sth = $this->{-dbh}->prepare($q);
	$sth->execute('played');
	my($t) = $sth->fetchrow_array();
	$sth->finish;
	$t = 0 if (!$t);
	$t = sprintf('%.2f', $t);

	my $viewname = "ranks$$";
	$this->{-dbh}->do("create temporary view $viewname as select count(1) as cnt, trackid from playhistory where action = 'played' group by 2");
	#$this->{-dbh}->do("select setval('rank', 0)");
	$q = "select cnt, round(cnt/$t, 7), trackid from $viewname order by 1 desc";
	Logger::logger($q);
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
	$this->{-dbh}->do("drop view $viewname");
}

1;
