#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/server.pl,v 1.11 2004/01/30 09:43:25 jukebox Exp $

use strict;
use warnings;

use threads;
use threads::shared;
use Thread::Queue;

use File::Basename;

my $home = File::Basename::dirname($0);
$ENV{HOME} = $home;
chdir $home;

use IPC::Open2;
use Socket;
use IO::Socket;
use IO::Socket::INET;
use IO::Select;

use Settings;
use ServerCommands;
use Logger;
use Player;
use Reader;
use Periodic;

use DatabaseSetup;

use DBI;

my $port = Settings::listenport();
my $dbfile = Settings::dbfile();
while (@ARGV) {
	my $a = shift @ARGV;
	if ($a =~ m/^--?p(ort)?/) {
		$port = shift @ARGV;
		next;
	}
	if ($a =~ m/^--?db(file)?/) {
		$dbfile = shift @ARGV;
		next;
	}
}

DatabaseSetup::init($dbfile);

my $listener = new IO::Socket::INET(Listen => 5, LocalPort => $port, Proto => 'tcp', ReuseAddr => 1);
die if ($@);

our $run : shared = 1;

my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","",""); # for this thread
die if (!$dbh);
# reset the playhistory, in case we were abort before
{
	my $q = "update playhistory set action = ? where action = ?";
	my $sth = $dbh->prepare($q);
	my $rv = $sth->execute('queued', 'playing');
	$sth->finish;
	if ($rv) {
		$rv += 0;
		Logger::logger("reset $rv queued songs");
	}
}
$dbh->disconnect();

my $storagedir = Settings::storagedir();
my $dblock : shared = 0xfef1f0fa;

my $periodic;
my $periodicthr;
{
	my $pstate : shared = '';
	$periodic = new Periodic(-dbfile=>$dbfile, 
				-ref_dblock=>\$dblock,
				-ref_state=>\$pstate,
			);
	$periodicthr = threads->new(sub { eval { $periodic->run(); }; Logger::logger("periodic tasks thread no longer running: $@"); } );
}

my $playerthrs = {};
{
	my $playdevs = Settings::get_of_type('play');
	foreach my $po (@$playdevs) {
		my $device = $po->{devicename};
		$playerthrs->{$device} = &spawn_player_thread($device);
	}
}
my $readerthrs = {};
{
	my $readdevs = Settings::get_of_type('read');
	foreach my $ro (@$readdevs) {
		my $device = $ro->{devicename};
		$readerthrs->{$device} = &spawn_reader_thread($device);
	}
}
sleep 3; # give everything a chance to initialize
my $serverthr = threads->new(\&server);
$serverthr->join;
undef $serverthr;

exit;

sub spawn_player_thread {
	my $device = shift;
	my $stat_state : shared = 'idle';
	my $stat_position : shared = '';
	my $stat_track : shared = '';
	my $player = new Player(-dbfile=>$dbfile,
				-device=>$device,
				-ref_state=>\$stat_state,
				-ref_position=>\$stat_position,
				-ref_track=>\$stat_track,
				-ref_dblock=>\$dblock,
			);
	# we set this to one here to avoid a race condition, whereby the thread hasn't started yet, and we still read -running as 0
	my $running : shared = 1;
	my $playerthr = threads->new(sub { $running = 1; eval { $player->run(); }; Logger::logger("player thread for $device no longer running: $@"); $running = 0; });
	my $ret = {-thread=>$playerthr, -object=>$player, -running=>\$running};
	return $ret;
}

sub spawn_reader_thread {
	my $device = shift;
	my $stat_state : shared = 'idle';
	my $stat_track : shared = '';
	my $reader = new Reader(-dbfile=>$dbfile,
				-device=>$device,
				-ref_state=>\$stat_state,
				-ref_track=>\$stat_track,
				-ref_dblock=>\$dblock
			);
	# we set this to one here to avoid a race condition, whereby the thread hasn't started yet, and we still read -running as 0
	my $running : shared = 1; 
	my $readerthr = threads->new(sub { $running = 1; eval { $reader->run(); }; Logger::logger("reader thread for $device no longer running: $@"); $running = 0; });
	my $ret = {-thread=>$readerthr, -object=>$reader, -running=>\$running};
	return $ret;
}

sub server {
	my $cmdhandler = new ServerCommands(
				-dbfile=>$dbfile, 
				-playerthrs=>$playerthrs,
				-readerthrs=>$readerthrs,
				-periodic=>$periodic,
				-ref_dblock=>\$dblock, 
			);

	my $selreaders = new IO::Select($listener);
	my $selwriters = new IO::Select();
	my $connections = {};
	my $pendingwrites = {};
	my $lastmsg = '';
	my $lastname = '';
	my $lastcount = 0;

	READLOOP:
	while(my ($rs, $ws, $es) = IO::Select->select($selreaders, $selwriters, undef)) {
		foreach my $fh (@$ws) {
			my $line = shift @{$pendingwrites->{$fh}};
			print $fh $line if ($line);
			if (!(scalar @{$pendingwrites->{$fh}})) {
				$selwriters->remove($fh);
			}
		}
		foreach my $fh (@$rs) {
			if ($fh == $listener) {
				my $newsock = $listener->accept();
				my $peer = $newsock->peerhost().":".$newsock->peerport();
				Logger::logger("connection from $peer");
				$selreaders->add($newsock);
				$connections->{$newsock} = {peername=>$peer, name=>$peer};
			} else {
				my $input = <$fh>;
				my $discon = 0;
				if (defined($input)) {
					$input =~ s/\r?\n$//;
					$input = ('noop '.time()) if ($input =~ m/^$/);

					# unfortuantely, some commands can't be implemented in ServerCommands.pm
					last READLOOP if ($input =~ m/^shut/);

					# the following if was added to test player/reader thread restarting upon death
					# it will eventually be removed
					if ($input =~ m/^exit (\w+)$/) {
						my $dv = $1;
						if (exists($playerthrs->{$dv})) {
							$playerthrs->{$dv}->{-object}->cmdqueue()->enqueue('abort');
							$playerthrs->{$dv}->{-object}->cmdqueue()->enqueue(undef); # get the player thread to exit
							print $fh "200 told $dv to abort\n";
						} else {
							print $fh "300 unknown play device $dv\n";
						}
						next;
					}

					my ($result, $output) = eval { $cmdhandler->process($input, $fh, $connections); };
					Logger::logger($@, 'server') if ($@);
					if (ref($output) ne 'ARRAY') {
						$output = [$output];
					}
					$discon = 1 if (!$result);
					my $outputlines = scalar @$output;
					$connections->{$fh}->{inputs} += 1;
					$connections->{$fh}->{outputs} += $outputlines;
					my $msg = sprintf("%5d %4d \"%s\"", $result, $outputlines, $input);
					if ($msg eq $lastmsg && $connections->{$fh}->{name} eq $lastname) {
						$lastcount++;
					} else {
						if ($lastcount) {
							Logger::logger("last message repeated $lastcount times", $lastname);
						}
						Logger::logger($msg, $connections->{$fh}->{name});
						$lastmsg = $msg;
						$lastname = $connections->{$fh}->{name};
						$lastcount = 0;
					}
					if ($outputlines) {
						push(@{$pendingwrites->{$fh}}, @$output);
						$selwriters->add($fh);
					}
				}
				if (!defined($input) || $discon) {
					if ($lastcount) {
						Logger::logger("last message repeated $lastcount times", $lastname);
						$lastmsg = '';
						$lastname = '';
						$lastcount = 0;
					}
					Logger::logger("disconnecting from ".$connections->{$fh}->{name});
					delete($connections->{$fh});
					delete $pendingwrites->{$fh};
					$selreaders->remove($fh);
					$selwriters->remove($fh);
					close($fh);
				}
			}
		}
		foreach my $p (keys %$pendingwrites) {
			my $amt = scalar @{$pendingwrites->{$p}};
			if (!$amt) { $selwriters->remove($p); }
		}
		foreach my $dv (keys %$playerthrs) {
			if (! ${$playerthrs->{$dv}->{-running}}) {
				Logger::logger("player thread for $dv seems to have died, creating new");
				$playerthrs->{$dv}->{-thread}->join();
				$playerthrs->{$dv} = &spawn_player_thread($dv);
			}
		}
		foreach my $dv (keys %$readerthrs) {
			if (! ${$readerthrs->{$dv}->{-running}}) {
				Logger::logger("reader thread for $dv seems to have died, creating new");
				$readerthrs->{$dv}->{-thread}->join();
				$readerthrs->{$dv} = &spawn_reader_thread($dv);
			}
		}

		# commands have been pushed in to the queue that won't be used
		# avoid filling up memory with these commands
#		foreach my $dv (keys %$playerthrs) {
#			my $c = 0;
#			my $pvo = $playerthrs->{$dv}->{-object};
#			while(${$pvo->state()} eq 'idle' && $pvo->cmdqueue()->pending()) { 
#				my $x = $pvo->cmdqueue()->dequeue(); 
#				Logger::logger("   $dv: removed \"$x\"", 'mainloop');
#				$c++;
#			} 
#			Logger::logger("cleared $dv player command queue of $c entries", 'mainloop') if ($c);
#		}
	}
	$run = 0;

	foreach my $dv (keys %$playerthrs) {
		$playerthrs->{$dv}->{-object}->cmdqueue()->enqueue('abort');
		$playerthrs->{$dv}->{-object}->cmdqueue()->enqueue(undef); # get the player thread to exit
		threads->yield();
	}
	foreach my $dv (keys %$readerthrs) {
		$readerthrs->{$dv}->{-object}->cmdqueue()->enqueue('abort');
		$readerthrs->{$dv}->{-object}->cmdqueue()->enqueue(undef); # get the reader thread to exit
		threads->yield();
	}
	foreach my $fh (keys %$connections) {
		Logger::logger("shutdown, closing ".$connections->{$fh}->{name});
		close($fh);
	}
	close($listener);

	sleep 2; # wait for other threads to exit
	threads->yield();
}

