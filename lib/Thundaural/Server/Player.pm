#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/Thundaural/Server/Player.pm,v 1.7 2004/06/06 01:20:32 jukebox Exp $

package Thundaural::Server::Player;

# this implementation of the audio writer handles whatever audio formats
# AudioDecode::Open can return a decoder object for.
# it writes to all devices simultaneously and is able to stream
# songs without any pauses between them

use strict;
use warnings;

use threads;
use threads::shared;
use Thread::Queue;
use Thread::Semaphore;

use File::Basename;

use DBI;
use Data::Dumper;
use Storable qw(freeze thaw);

use Audio::DSP;

use AudioDecode::Open;

use Thundaural::Server::Settings;
use Thundaural::Logger qw(logger);

# spawns an audio device writing thread for each device we are going to write to
#   in thread:
#      wait for audio data to appear in the queue
#      write data to device
#      up() semaphore
# waits for songs to show up in the playhistory table
# opens files
#   adds audio data to the queue
#   wait for down semaphore

sub new {
	my $class = shift;
	my %o = @_;

	my $this = {};
	bless $this, $class;

	$this->{-cmdqueue} = new Thread::Queue;
	$this->dbfile(Thundaural::Server::Settings::dbfile());

	$this->{-queuedsongs} = [];

	my $dblock = $o{-ref_dblock};
	die("dblock isn't a reference") if (!ref($dblock));
	die("dblock isn't a reference to a scalar") if (ref($dblock) ne 'SCALAR');
	die("bad dblock passed") if ($$dblock != 0xfef1f0fa);
	$this->{-dblock} = $dblock;

	$this->{-state} = $o{-ref_state};
	$this->{-position} = $o{-ref_position};
	$this->{-track} = $o{-ref_track};

	$this->{bufsize} = 8192;

	$this->{-storagedir} = Thundaural::Server::Settings::storagedir();

	my $playdevs = Thundaural::Server::Settings::get_of_type('play');
	$this->{ready_sem} = new Thread::Semaphore(0);
	foreach my $po (@$playdevs) {
		my $devicename = $po->{devicename};
		my $ti = $this->spawn_audio_writer($devicename);
		$this->{audiowriters}->{$devicename} = $ti;
	}

        return $this;
}

sub run {
	my $this = shift;

	$this->_dbconnect();

	my $samplesize = 2;
	my $samplesigned = 1;
	my $bufsize = $this->{bufsize};

	WAITINGFORSONGS:
	while ($main::run) {
		$this->find_another_song(0)
			unless (scalar @{$this->{-queuedsongs}} );

		# have we been told to exit?
		if ($this->{-cmdqueue}->pending()) {
			my $c = $this->{-cmdqueue}->dequeue();
			last WAITINGFORSONGS if (!defined($c));
			last WAITINGFORSONGS if ($c eq 'abort');
			# no other command makes sense in this context
		}
		${$this->{-state}} = 'idle';
		${$this->{-track}} = undef;
		${$this->{-position}} = undef;
		# wait for more songs to enter the queue
		($this->usleep(1.5), next) if (! scalar @{$this->{-queuedsongs}} );

		# get next song
		my $qs = shift @{$this->{-queuedsongs}};

		# setup some local variables to make access easier
		my $playtrack = $qs->{playtrack};
		my $filename = $qs->{filename};
		my $decoder = $qs->{decoder};
		my $info = $qs->{info};

		${$this->{-track}} = freeze( { trackid=>$playtrack->{trackid}, started=>time() } );

		# mark the track as being played
		$this->playhistory_action($playtrack->{playhistoryid}, 'playing');
		${$this->{-state}} = 'playing';

		# tell the device writing threads the output format they should use
		$this->update_output_sampleformat($info, $bufsize);

		my $playedthroughend = 0;
		my $buffer;
		my $next_is_same_format = undef;
		my $pausebefore = Thundaural::Server::Settings::pause_between_songs();
		$decoder->bufsize($bufsize);
		my $totalseconds = $info->{seconds};
		my $paused = 0;
		PLAYAUDIO:
		while($main::run) {
			my $len;
			$buffer = '';
			eval {
				# get some decoded audio data
				$len = $decoder->read(\$buffer);
			};
			# reached the end of the audio data?
			if ($len <= 0) {
				$playedthroughend = 1;
				sleep($pausebefore) if ($pausebefore);
				last;
			} elsif ($len < $bufsize) {
				# we got a partial buffer
				my $diff = $bufsize - $len;
				if ($next_is_same_format && !$pausebefore) {
					# fill the buffer with data from the next song
					my $nextdecoder = $this->{-queuedsongs}->[0]->{decoder};
					if (defined($nextdecoder)) {
						my $nextbuf = '';
						$nextdecoder->bufsize($diff);
						if (my $nextlen = $nextdecoder->read(\$nextbuf)) {
							$buffer .= $nextbuf;
						}
					}
				} else {
					# the next song isn't the same format, so just fill
					# the rest of the current buffer with silence
					$buffer .= pack("x$diff");
				}
			}

			$this->queue_audiodata(bits=>$buffer);
			# while the writer threads are playing the audio data...

			# ... we have a moment to do other things
			if ($totalseconds) {
				my $c = $decoder->tell_time();
				${$this->{-position}} = freeze( {
					'current'=>$c, 
					'length'=>$totalseconds,
					'percentage'=>(($c / $totalseconds)*100)
					} );
			} else {
				${$this->{-position}} = undef;
			}

			# start queueing up the next song if one exists
			if ($decoder->tell_percentage() > 0.94 && !(scalar @{$this->{-queuedsongs}}) ) {
				$this->find_another_song($playtrack->{trackid});
				if (!defined($next_is_same_format) && defined($this->{-queuedsongs}->[0])) {
					$next_is_same_format = &is_same_format(
								$decoder, 
								$this->{-queuedsongs}->[0]->{decoder});
					$pausebefore = $this->{-queuedsongs}->[0]->{pausebefore};
				}
			}

			# wait for the device writer threads to signal they are ready for more data
			$this->{ready_sem}->down(scalar keys %{$this->{audiowriters}});

			# have we been asked to pause or skip this song?
			while($this->{-cmdqueue}->pending()) {
				PAUSING:
				my $c = $this->{-cmdqueue}->dequeue();
				last PLAYAUDIO if ($c =~ m/^skip/);
				last WAITINGFORSONGS if ($c eq 'abort');
				last WAITINGFORSONGS if (!defined($c));
				if ($c =~ m/^pause/) {
					$paused = !$paused;
					${$this->{-state}} = $paused ? 'paused' : 'playing';
					logger("we are now ".(${$this->{-state}}));
					if ($paused) {
						#$this->queue_audiodata(silence=>1);
						#$this->{ready_sem}->down(scalar keys %{$this->{audiowriters}});
						goto PAUSING;
					} else {
						last;
					}
				}
				logger("received unknown command \"$c\" (only valid commands while paused are 'skip', 'abort', and 'pause')");
			}

		}
		$this->playhistory_action($playtrack->{playhistoryid}, $playedthroughend ? 'played' : 'skipped');
	}
	$this->kill_audiowriters();
	logger("player thread exiting");
}

sub queue_audiodata {
	my $this = shift;
	my %o = @_;
	my $buffer = $o{bits};
	my $silence = $o{silence};
	if ($silence) {
		my $bs = $this->{bufsize};
		logger("creating $bs bytes of silence");
		$buffer = pack("x$bs");
	}
	# give the writer threads the audio data
	foreach my $dn ( keys %{$this->{audiowriters}} ) {
		$this->{audiowriters}->{$dn}->{buffer}->enqueue($buffer);
	}
}

sub is_same_format {
	my $dec1 = shift;
	my $dec2 = shift;

	return 0 if (!$dec2); # most likely
	return 0 if (!$dec1);

	my $info1 = $dec1->info();
	my $info2 = $dec2->info();

	return ( $info1->{channels} == $info2->{channels}
		&& $info1->{rate} == $info2->{rate} ) ? 1 : 0;
}

sub update_output_sampleformat {
	my $this = shift;
	my $info = shift;
	my $bufsize = shift;

	my $channels = $info->{channels};
	my $rate = $info->{rate};
	foreach my $dn ( keys %{$this->{audiowriters}} ) {
		$this->{audiowriters}->{$dn}->{buffer}->enqueue('c', $channels, $rate, $bufsize);
	}
}

sub find_another_song {
	my $this = shift;
	my $nowtrackid = shift;
	
	my $playtrack;
	{
		lock(${$this->{-dblock}});
		my $q = "select * from playhistory where devicename = ? and action = ? order by requestedat, playhistoryid limit 1";
		my $sth = $this->{-dbh}->prepare($q);
		$sth->execute('main', 'queued');
		$playtrack = $sth->fetchrow_hashref();
		$sth->finish;
	}

	return if (!$playtrack);

	my $devicefile = Thundaural::Server::Settings::get($playtrack->{devicename}, 'play');
	my $track = $this->trackinfo($playtrack->{trackid});

	my $filename = $this->{-storagedir}."/".$track->{filename};
	logger("found track file $filename");
	if (!-s $filename) {
		$this->playhistory_action($playtrack->{playhistoryid}, 'no file');
		return;
	}

	my $decoder;
	eval {
		$decoder = AudioDecode::Open::open(file=>$filename, signed=>1, size=>2, endian=>'LE');
	};
	if (defined($decoder) && !$@) {
		my $pb = 0;
		my $inseq =  $this->tracks_in_sequence_p($nowtrackid, $playtrack->{trackid});
		#if (! $this->tracks_in_sequence_p($nowtrackid, $playtrack->{trackid}) ) {
			# pause for four seconds between tracks that are no in sequence
		if (! $inseq) {
			$pb = Thundaural::Server::Settings::pause_between_songs();
		}
		my $e = {playtrack=>$playtrack, filename=>$filename, decoder=>$decoder, info=>$decoder->info(), pausebefore=>$pb};
		push(@{$this->{-queuedsongs}}, $e);
	} else {
		logger("unable to create decoder: $@");
		$this->playhistory_action($playtrack->{playhistoryid}, 'unknowntype');
	}
	return;
}

sub tracks_in_sequence_p {
	my $this = shift;
	my($now, $next) = @_;
	# determines if the next song immediately follows the currently playing
	# song on the same album.

	return 0 if (!$now); # nothing is currently playing

	# I think this query might be SQLite specific
	my $q = "select case (a.albumid == b.albumid) 
			when 1 
			then (case (a.albumorder + 1 == b.albumorder) 
			      when 1 
			      then 'in order' 
			      else 'on same album' end) 
			else 'on different albums'
			end 
			from tracks a, tracks b
			where a.trackid = ? and b.trackid = ?";
	my $sth = $this->{-dbh}->prepare($q);
	$sth->execute($now, $next);
	my($x) = $sth->fetchrow_array();
	$sth->finish;
	logger("tracks $now and $next are $x");
	return ( $x eq 'in order' ? 1 : 0 );
}

sub kill_audiowriters {
	my $this = shift;

	foreach my $devicename ( keys %{$this->{audiowriters}} ) {
		my $bitbuffer = $this->{audiowriters}->{$devicename}->{buffer};
		while($bitbuffer->pending()) {
			# dump all the pending audio
			$bitbuffer->dequeue();
		}
		$bitbuffer->enqueue('e');
		$bitbuffer->enqueue(undef);
		$this->{audiowriters}->{$devicename}->{thr}->join();
		delete $this->{audiowriters}->{$devicename};
	}
}

sub spawn_audio_writer {
	my $this = shift;
	my $devicename = shift;

	my $devicefile = Thundaural::Server::Settings::get($devicename, 'play');
	my $bitbuffer = new Thread::Queue();
	my $running : shared = 1;
	my $thr = threads->new(\&audio_writer, $this, $devicefile, $this->{ready_sem}, $bitbuffer, \$running);
	my $ti = {thr=>$thr, devicename=>$devicename, running=>\$running, buffer=>$bitbuffer};
	logger("spawned audio writer thread for $devicefile");
	return $ti;
}

sub audio_writer {
	my(
		$this,
		$devicefile,
		$ready_sem,
		$bitbuffer,
		$running
	) = @_;

	my $inited = 0;
	my $warned = 0;
	my $lastrate = -1;
	my $lastchannels = -1;
	my $lastbufsize = -1;

	eval {
		my $adsp = new Audio::DSP;
		my $d;
		while($d = $bitbuffer->dequeue()) {
			if ($d eq 'e') {
				last;
			}
			if ($d eq 'c') {
				my $channels = $bitbuffer->dequeue();
				my $rate = $bitbuffer->dequeue();
				my $bufsize = $bitbuffer->dequeue();
				if ( ($lastrate != $rate) ||
			     	     ($lastchannels != $channels) ||
			     	     ($lastbufsize != $bufsize) ) {
					$adsp->close() if ($inited);
					if ($adsp->init(device=>$devicefile,
							buffer=>$bufsize,
							rate=>$rate,
							channels=>$channels,
							format=>AFMT_S16_LE)) {
						logger('%s configured (buffer=%d, rate=%d, channels=%d)', $devicefile, $bufsize, $rate, $channels);
						$lastchannels = $channels;
						$lastrate = $rate;
						$lastbufsize = $bufsize;
						$inited = 1;
					} else {
                        logger("unable to initialize audio device: ".$adsp->errstr());
                    }
				}
				next;
			}
			if (!$inited) {
				logger("$devicefile not initialized before data received")
					unless($warned);
				$warned = 1;
				next;
			}
			$adsp->datacat($d);
			$adsp->write();
			$adsp->clear();
			$ready_sem->up();
		}
		$adsp->close();
		$inited = 0;
		logger("$devicefile writer exiting");
	};
	logger("$devicefile writer died: $@") if ($@);
	${$running} = 0;
}

sub state {
	my $this = shift;
	my $s = ${$this->{-state}};
	$s = '' if (!defined($s) || !$s);
	return $s;
}

sub position {
	my $this = shift;
	my $p = ${$this->{-position}};
	$p = freeze({current=>'', length=>'', percentage=>''})
		if (!defined($p) || !$p);
	return $p;
}

sub track {
	my $this = shift;
	my $t = ${$this->{-track}};
	$t = '' if (!defined($t) || !$t);
	return $t;
}

sub cmdqueue {
	my $this = shift;
	return $this->{-cmdqueue};
}

sub _dbconnect {
	my $this = shift;

	my $dbfile = $this->{-dbfile};
	if ($dbfile) {
		$this->{-dbh} = DBI->connect("dbi:SQLite:dbname=$dbfile","","");
		logger("dbh is ".$this->{-dbh});
	}
}

sub usleep($) {
	my $this = shift;
	my $duration = shift;
	select(undef, undef, undef, $duration);
	return 0;
}

sub playhistory_action($$) {
	my $this = shift;
	my $playhistoryid = shift;
	my $action = shift;

	eval {
		lock(${$this->{-dblock}});
		my $q = "update playhistory set action = ?, actedat = ? where playhistoryid = ?";
		my $sth = $this->{-dbh}->prepare($q);
		$sth->execute($action, time(), $playhistoryid);
		$sth->finish;
	};
}

sub trackinfo($) {
	my $this = shift;
	my $trackid = shift;
	my $track = {};
	eval {
		lock(${$this->{-dblock}});
		my $q = "select * from tracks where trackid = ?";
		my $sth = $this->{-dbh}->prepare($q);
		#logger("getting track info for track $trackid");
		$sth->execute($trackid);
		$track = $sth->fetchrow_hashref;
		$sth->finish;
	};
	return $track;
}

sub dbfile {
	my $this = shift;
	my $db = shift;

	return if (!$db);
	$this->{-dbfile} = $db;
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

