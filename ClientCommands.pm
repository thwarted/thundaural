 
package ClientCommands;

use strict;
use warnings;

use IO::Socket::INET;

use Logger;

my $PROTOCOL_VERSION = '4';

sub new {
	my $class = shift;
	my %opts = @_;
	                                                                                                                                                    
	my $this = {};
	bless $this, $class;

	my $server = $opts{-host} || 'localhost';
	my $port = $opts{-port} || 9000;
	$this->{server} = $server;
	$this->{port} = $port;

	$this->{status} = {};
	$this->{lasttrackref} = {};
	$this->{stats} = {};
	$this->{random} = {};
	$this->{clientlabel} = $opts{-clientlabel} || 'unknown';

	$this->{statuslastupdate} = 0;
	$this->{queuedonlastupdate} = 0;
	$this->{deviceslastupdate} = 0;
	$this->{statslastupdate} = 0;
	$this->{randomlastupdate} = 0;

	$this->{errorfunc} = $opts{-errorfunc};
	$this->{recoveredfunc} = $opts{-recoveredfunc};
	$this->{idlefunc} = $opts{-idlefunc};

	$this->_ensureconnect();
	$this->_clearinput();
	return $this;
}

sub _ensureconnect {
	my $this = shift;

	if (!$this->{ihn} || !$this->{ihn}->connected()) {
		my $try = 0;
		eval { $this->{ihn}->shutdown(2); };
		OPENCONNECTION:
		while (1) {
			TRYCONNECT:
			while (1) {
				$try++;
				$this->{ihn} = new IO::Socket::INET(PeerAddr=>$this->{server}, PeerPort=>$this->{port}, proto=>'tcp');
				if ($this->{ihn} && $this->{ihn}->connected()) {
					if ($try > 1 && ref($this->{recoveredfunc}) eq 'CODE') {
						my $f = $this->{recoveredfunc};
						&$f();
					}
					last TRYCONNECT;
				}
				Logger::logger("unable to connect to %s:%s", $this->{server}, $this->{port});
				if (ref($this->{errorfunc}) eq 'CODE') {
					my $f = $this->{errorfunc};
					&$f(sprintf("jukebox server (%s:%s)\nis not responding\n\nPlease wait...\n\ntry $try", 
						$this->{server}, $this->{port}));
				}
				if (ref($this->{idlefunc}) eq 'CODE') {
					my $f = $this->{idlefunc};
					&$f();
				}
			}
			my $h = $this->{ihn};
			my $x;

			# wait for the server to respond
			print $h "noop connectionsync-".time()."\n";
			$x = <$h>;
			next OPENCONNECTION if (!defined($x));

			# verify protocol version
			print $h "version\n";
			$x = <$h>;
			next OPENCONNECTION if (!defined($x));
			($x) = $x =~ m/^200 version (.+)/;
			die("unable to determine server's protocol version\n")
				unless (defined($x));
			die("client/server protocol version mismatch ".
			    "(server reports $x, looking for $PROTOCOL_VERSION)\n") 
				unless ($x eq $PROTOCOL_VERSION);

			# set our client name -- do auth here in the future
			my $me = `/bin/hostname`; chomp $me;
			print $h sprintf('name %s(%d,%s)%s', $me, $$, $this->{clientlabel}, "\n");
			$x = <$h>; # dump response line
			last if defined($x);
		}
	}
	return $this->{ihn};
}

sub _clearinput {
	my $this = shift;
	my $tail = shift || '';
	$tail .= '.' if ($tail);
	$tail .= sprintf('%d.%d', time(), int(rand(999)));

	my $h = $this->_ensureconnect();
        print $h "noop $tail\n";
	my $i;
        do {
                $i = <$h>;
		if (!$i) {
			die("error when connecting, disconnected half way through, aborting");
		}
                chomp $i;
        } while($i !~ m/^200 noop $tail/);
}

sub _populate_status {
	my $this = shift;
	return if (exists($this->{statuslastupdate}) && $this->{statuslastupdate}+1 > time());
	my $st = $this->_do_cmd('status');
	if (ref($st) eq 'ARRAY') {
		$this->{status} = {};
		my $ltr = '';
		foreach my $x (@$st) {
			my $dn = $x->{devicename};
			$this->{status}->{$dn} = $x;
			$ltr .= "-".(defined($x->{trackref}) ? $x->{trackref} : 'none');
		}
		$this->{statuslastupdate} = time();
		if ($ltr ne $this->{lasttrackref}) {
			$this->{queuedonlastupdate} = 0;
		}
		$this->{lasttrackref} = $ltr;
	} else {	
		Logger::logger("unable to get status, result was $st");
		$this->{status} = {};
	}
}

sub _populate_top {
	my $this = shift;
	my $type = shift;
	return if (exists($this->{"toplastupdate$type"}) && $this->{"toplastupdate$type"}+300 > time());
	my $st = $this->_do_cmd("top 150 $type");
	if (ref($st) eq 'ARRAY') {
		$this->{"top$type"} = $st;
	} else {
		Logger::logger("unable to get top $type, result was $st");
		$this->{"top$type"} = {};
	}
	$this->{"toplastupdate$type"} = time();
}

sub _populate_random {
	my $this = shift;
	return if (exists($this->{randomlastupdate}) && $this->{randomlastupdate}+5 > time());
	my $st = $this->_do_cmd('randomize');
	if (ref($st) eq 'ARRAY') {
		$this->{random} = {};
		foreach my $x (@$st) {
			my $dn = $x->{devicename};
			$this->{random}->{$dn} = $x->{endtime};
		}
		$this->{randomlastupdate} = time();
	} else {
		Logger::logger("unable to get randomization, result was $st");
		$this->{random} = {};
	}
}

sub _populate_queuedon {
	my $this = shift;
	return if ($this->{queuedonlastupdate}+120 > time());
	my $qo = $this->_do_cmd('queued');
	if (ref($qo) eq 'ARRAY') {
		$this->{queuedon} = {};
		foreach my $x (@$qo) {
			my $dn = $x->{devicename};
			if (!defined($this->{queuedon}->{$dn})) {
				$this->{queuedon}->{$dn} = [];
			}
			push(@{$this->{queuedon}->{$dn}}, $x);
		}
		$this->{queuedonlastupdate} = time();
	} else {
		Logger::logger("unable to get queued track list, result was $qo");
		$this->{queuedon} = {};
	}
}

sub _populate_devices {
	my $this = shift;
	return if ($this->{deviceslastupdate}+600 > time());
	my $d = $this->_do_cmd('devices');
	if (ref($d) eq 'ARRAY') {
		$this->{devices} = {};
		foreach my $x (@$d) {
			my $dt = $x->{type};
			if (!defined($this->{devices}->{$dt})) {
				$this->{devices}->{$dt} = [];
			}
			push(@{$this->{devices}->{$dt}}, $x);
		}
		$this->{deviceslastupdate} = time();
	} else {
		Logger::logger("unable to get device list from server, result was $d");
		$this->{devices} = {};
	}
}

sub _populate_stats {
	my $this = shift;
	return if ($this->{statslastupdate}+10 > time());
	my $x = $this->_do_cmd('stats');
	if (ref($x) eq 'ARRAY') {
		$this->{stats} = {};
		foreach my $l (@$x) {
			$this->{stats}->{$l->{key}} = $l->{value};
		}
		$this->{statslastupdate} = time();
	} else {
		Logger::logger("unable to get stat info from server, result was $x");
		$this->{stats} = {};
	}
}

sub top_rankings {
	my $this = shift;
	my $type = shift;
	
	$this->_populate_top($type);
	my $x = $this->{"top$type"};
	if (ref($x) ne 'ARRAY') {
		return [];
	}
	return [@{$x}]; # duplicate it
}

sub random_play {
	my $this = shift;
	my $minutes = shift;
	my $devicename = shift;

	return 0 if (!$devicename);
	return 0 if ($minutes !~ m/^\d+$/);
	$minutes += 0;

	$this->{random} = {};
	$this->{randomlastupdate} = -10;
	$this->_do_cmd("randomize $devicename for $minutes");
}

sub will_random_play_until {
	my $this = shift;
	my $dn = shift;

	$this->_populate_random();
	return (exists($this->{random}->{$dn}) ? $this->{random}->{$dn} : undef);
}

sub tracks {
	my $this = shift;
	my $alir = shift;

	return [] if (!$alir);
	my $to = $this->_do_cmd('tracks', $alir);
	if (ref($to) eq 'ARRAY') {
		return $to;
	}
	return [];
}

sub devices {
	my $this = shift;
	my $type = shift;

	$this->_populate_devices();
	return [] if (!$type);
	my @ret = (); 
	foreach my $d (@{$this->{devices}->{$type}}) {
		my $dn = $d->{devicename};
		push(@ret, $dn);
	}
	return [@ret];
}

sub time {
	my $this = shift;

	my $h = $this->_ensureconnect();
	print $h "time\n";
	my $input = <$h>;
	my ($result, $time) = split(/\s+/, $input);
	return int($time);
}

sub volume {
	my $this = shift;
	my $channel = shift;
	my $newvol = shift;

	if (defined($newvol)) {
		$this->_do_cmd('volume', $channel, $newvol);
		$this->{statuslastupdate} = 0;
	}

	$this->_populate_status();
	if (!$channel) { return 0; }
	return $this->{status}->{$channel}->{volume};
}

sub status_of {
	my $this = shift;
	return $this->playing_on(@_);
}

sub player_active {
	my $this = shift;
	foreach my $k (keys %{$this->{status}}) {
		my $x = $this->{status}->{$k};
		return 1 if ($x->{type} eq 'play' && $x->{state} ne 'idle')
	}
	return 0;
}

sub reader_active {
	my $this = shift;
	foreach my $k (keys %{$this->{status}}) {
		my $x = $this->{status}->{$k};
		return 1 if ($x->{type} eq 'read' && $x->{state} ne 'idle')
	}
	return 0;
}

sub playing_on {
	my $this = shift;
	my $channel = shift;

	$this->_populate_status();
	if (!$channel) {
		return $this->{status};
	}

	my $x = $this->{status}->{$channel};
	if (ref($x) ne 'HASH') {
		$x = {};
	}
	return $x;
}

sub stats {
	my $this = shift;

	$this->_populate_stats();
	return $this->{stats};
}

sub queued_on {
	my $this = shift;
	my $channel = shift;

	$this->_populate_queuedon();
	if (!$channel) {
		return $this->{queuedon};
	}

	my $x = $this->{queuedon}->{$channel};
	if (ref($x) ne 'ARRAY') {
		$x = [];
	}
	return $x;
}

sub playing_trackperformer {
	my $this = shift;
	my $channel = shift;
	$this->_populate_status();
	return $this->{status}->{$channel}->{performer};
}

sub playing_trackname {
	my $this = shift;
	my $channel = shift;
	$this->_populate_status();
	return $this->{status}->{$channel}->{name};
}

sub playing_trackgenre {
	my $this = shift;
	my $channel = shift;
	$this->_populate_status();
	return $this->{status}->{$channel}->{genre};
}

sub playing_total {
	my $this = shift;
	my $channel = shift;
	$this->_populate_status();
	return $this->{status}->{$channel}->{total};
}

sub playing_percentage {
	my $this = shift;
	my $channel = shift;

	$this->_populate_status();
	my $x = $this->{status}->{$channel}->{percentage};
	return $x;
}

sub pauseable {
	my $this = shift;
	my $channel = shift;

	$this->_populate_status();
	return ($this->{status}->{$channel}->{state} eq 'playing' ? 1 : 0);
}

sub rip {
	my $this = shift;
	my $device = shift;

	my $result = $this->_do_cmd('rip', $device);
	return (200 <= $result && $result <= 299) ? 1 : 0;
}

sub abort_rip {
	my $this = shift;
	my $device = shift;

	my $result = $this->_do_cmd('abort', $device);
	return (200 <= $result && $result <= 299) ? 1 : 0;
}

sub play {
	my $this = shift;
	my $track = shift;
	my $channel = shift;

	my @args = ('play', $track);
	push(@args, $channel) if ($channel);
	my $result = $this->_do_cmd(@args);
	$this->{queuedonlastupdate} = 0;
	return (200 <= $result && $result <= 299) ? 1 : 0;
}

sub pause {
	my $this = shift;
	my $channel = shift;

	my @args = ('pause');
	push(@args, $channel) if ($channel);
	my $result = $this->_do_cmd(@args);
	return (200 <= $result && $result <= 299) ? 1 : 0;
}

sub skip {
	my $this = shift;
	my $channel = shift;

	my @args = ('skip');
	push(@args, $channel) if ($channel);
	my $result = $this->_do_cmd(@args);
	$this->{queuedonlastupdate} = 0;
	return (200 <= $result && $result <= 299) ? 1 : 0;
}

sub coverart {
	my $this = shift;
	my $albumid = shift;
	my $outputfile = shift;

	my $bytes = $this->_do_cmd("coverart $albumid");
	if (!$bytes || $bytes =~ m/^\d{3}$/) {
		Logger::logger('no data received for cover art');
		$bytes = '';
		#return undef;
	}

        open(F, ">$outputfile");
        print F $bytes;
        close(F);

	return $outputfile;
}

sub _do_cmd {
	my $this = shift;
	my $cmd = join(' ', @_);

	my($input, $rescode, $more, @x, $rl, $h, $keylist, @keys, @results, $k, $v); 

	RECONNECT:
	while (1) {
		$h = $this->_ensureconnect();
		print $h "$cmd\n";
		$input = <$h>;
		next if (!defined($input));
		chomp $input;
		#print "input = \"$input\"\n";
		($rescode, $more) = $input =~ m/^(\d{3}) (count|(\d+) bytes follow)?/;
		$rescode = 0 if !defined($rescode);
		if ($rescode == 202) { # binary data
			my($size) = $more =~ m/^(\d+) bytes/;
			if (!$size) {
				# verify that there is no data
				$input = <$h>;
				next RECONNECT if (!defined($input));
				chomp $input;
				next RECONNECT if ($input !~ m/^\.$/);
				return '';
			}
			my $bytes = '';
			while(length($bytes) < $size) {
				my $i = '';
				my $x = read($h, $i, 1);
				next RECONNECT if (!defined($x) || $x != 1);
				$bytes .= $i;
			}
			$input = <$h>; 
			next RECONNECT if (!defined($input));
			chomp $input;
			next RECONNECT if ($input !~ m/^\.$/);
			return $bytes;
		}
		if (200 <= $rescode && $rescode <= 299) {
			# 202 has already been handled, we're really handling 200 and 201 here
			last RECONNECT if (!defined($more));
			($keylist) = $input =~ m/\(([^()]+)\)/;
			@keys = split(/\s+/, $keylist);
			@results = ();
			MORE:
			while (1) {
				$input = <$h>;
				next RECONNECT if (!defined($input));
				chomp $input;
				#print "input = \"$input\"\n";
				last MORE if ($input =~ m/^\.$/);
				@x = split(/\t/, $input);
				$rl = {};
				foreach $k (@keys) {
					$v = shift @x;
					$rl->{$k} = $v;
				}
				push(@results, $rl);
			}
			return \@results;
		} else {
			return $rescode;
		}
	}
	return $rescode;
}

sub getlist($) {
	my $this = shift;

	return $this->_do_cmd(@_);
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
