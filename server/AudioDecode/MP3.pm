#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/AudioDecode/MP3.pm,v 1.2 2004/06/10 06:01:40 jukebox Exp $

package AudioDecode::MP3;

# abstracted interface to decoding MP3s

use strict;
use warnings;

use Carp;
use Data::Dumper;

use Audio::Mad qw(:all);
use MP3::Info; # Why can't Mad give us this stuff?
use IO::File;

use base 'AudioDecode::Base';

sub match_ext {
	return '\\.mpe?g?3$';
}

sub new {
	my $class = shift;
	my %o = @_;

	my $this = {};
	bless $this, $class;

	# settings
	$this->{readsize} = 8192 * 5;

	# setup
	$this->{stream}   = new Audio::Mad::Stream(MAD_OPTION_IGNORECRC);
	$this->{frame}    = new Audio::Mad::Frame();
	$this->{synth}    = new Audio::Mad::Synth();
	$this->{timer}    = new Audio::Mad::Timer();
	$this->{resample} = new Audio::Mad::Resample();
	$this->{dither}   = new Audio::Mad::Dither(MAD_DITHER_S16_LE);
	$this->{frames} = 0;
	$this->{buffer} = '';
	$this->{output} = '';
	$this->{buflen} = length($this->{buffer});
	$this->{stream}->buffer($this->{buffer});
	$this->{output} = '';

	$this->_setup(%o);

	# open
	$this->{mp3info} = MP3::Info::get_mp3info($this->{file});
	$this->{fh} = new IO::File;
	if (!($this->{fh}->open("<".$this->{file}) ) ) {
		croak("unable to open file: $@");
	}
	$this->{eof} = 0;

	return $this;
}

sub _setup_rate {
	# nothing to do - we take care of it inline below
}

sub _setup_format {
	my $this = shift;
	my $dt = 'a'; # reasonable default

	my $signed = $this->{samplesigned};
	my $size = $this->{samplesize};
	my $endian = $this->{sampleendian};

	if ($size == 1) {
		if ($signed) {
			$dt = MAD_DITHER_S8;
		} else {
			$dt = MAD_DITHER_U8;
		}
	}

	if ($size == 2) {
		if ($signed) {
			if ($endian eq 'LE') {
				$dt = MAD_DITHER_S16_LE;
			} else {
				$dt = MAD_DITHER_S16_BE;
			}
		}
	}

	if ($dt eq 'a') {
		# we don't support these
		# MAD_DITHER_S24_LE         MAD_DITHER_S24_BE
		# MAD_DITHER_S32_LE         MAD_DITHER_S32_BE
		croak("unsupported sign ($signed), size ($size), and endian ($endian)");
	}

	$this->{dither}->init($dt);
}


sub info {
	my $this = shift;

	croak("decoder not properly initialized") 
		if (!$this->{mp3info});
	my %x = %{$this->{mp3info}};
	$x{channels} = ($this->{mp3info}->{STEREO} == 1 ? 2 : 1);
	$x{rate} = ($this->{mp3info}->{FREQUENCY}*1000);
	$x{seconds} = $this->{mp3info}->{SECS};
	$x{bytes} = $this->{mp3info}->{SIZE} * $this->{mp3info}->{BITRATE};
	return \%x;
}

sub tell_percentage {
	my $this = shift;

	my $secs = $this->{mp3info}->{SECS};
	my $pos = $this->{timer}->count(MAD_UNITS_SECONDS);
	$pos /= $secs;
	return $pos;
}

sub tell_time {
	my $this = shift;

	return $this->{timer}->count(MAD_UNITS_SECONDS);
}

sub read {
	my $this = shift;
	my $bufref = shift;

	croak("decoder not properly initialized") if (!$this->{stream});
	croak("not a reference to a scalar") if (!ref($bufref));

	while (!$this->{eof} && length($this->{output}) < $this->{bufsize}) {
		$this->_decode_more();
	}
	my $d = substr $this->{output}, 0, $this->{bufsize};
	if ($this->{bufsize} < length($this->{output})) {
		$this->{output} = substr($this->{output}, $this->{bufsize});
	} else {
		$this->{output} = '';
	}
	$this->{readbytes} += length($d);
	${$bufref} = $d;
	return length($d);
}

sub _decode_more {
	my $this = shift;

	my $loops = 0;
	# this is in a loop so we can restart it
	while(1) {
		$loops++;
		my $framelen = $this->{stream}->next_frame() - $this->{stream}->this_frame();
		# bah, Audio::Mad doesn't allow you to clear the error -- how the hell is this supposed to work?
		# Can't use $stream->error() == MAD_ERROR_BUFLEN to mirror the code from madlld
		if ($this->{stream}->next_frame() >= $this->{buflen} 
		 || $this->{stream}->next_frame() + $framelen >= $this->{buflen}) {
			if ($this->{stream}->next_frame() > 0) {
				$this->{buffer} = substr($this->{buffer}, $this->{stream}->next_frame());
			} else {
				$this->{buffer} = '';
				$this->{buflen} = 0;
			}
			my $new = '';
			my $ReadSize = $this->{fh}->read($new, $this->{readsize});
			if ($ReadSize <= 0) {
				croak("read error: $!\n");
			}
			$this->{buffer} .= $new;
			if ($this->{fh}->eof()) {
				# madlld says buffer guard is 8, but we'll
				# be on the safe side here and add 16
				$this->{buffer} .= pack('x16');
				$this->{eof} = 1;
			}
			$this->{stream}->buffer($this->{buffer});
			$this->{buflen} = length($this->{buffer});
		}

		if ($this->{frame}->decode($this->{stream})) {
			if ($this->{stream}->err_ok() # recover from recoverable errors
			 || $this->{stream}->error() == MAD_ERROR_BUFLEN) { # also recoverable
			 	print "restarting loop\n";
			 	next;
			}
			# bah, just ignore other errors also and try to continue on
		}

		$this->{frames}++;

		$this->{timer}->add($this->{frame}->duration());

		$this->{synth}->synth($this->{frame});
		my @s = $this->{synth}->samples();
		$this->{resample}->init($this->{frame}->samplerate(), $this->{samplerate});
		my @r = $this->{resample}->mode() == 2 ? @s : $this->{resample}->resample(@s);
		$this->{output} .= $this->{dither}->dither(@r);

		last; # we only want to execute this loop once, unless there's an error
	}
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

