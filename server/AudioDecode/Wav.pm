#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/AudioDecode/Wav.pm,v 1.2 2004/06/10 06:01:40 jukebox Exp $

package AudioDecode::Wav;

# abstracted interface for decoding WAV files

use strict;
use warnings;

use Carp;
use Audio::Wav;

use base 'AudioDecode::Base';

sub match_ext {
	return '\\.wav$';
}

sub new {
	my $class = shift;
	my %o = @_;

	my $this = {};
	bless $this, $class;

	$this->_setup(%o);

	$this->{wav} = new Audio::Wav;
	$this->{decoder} = $this->{wav}->read($this->{file});
	if (!$this->{decoder}) {
		croak("unable to open file: $@");
	}

	return $this;
}

sub _setup_format {
        # we can't change the format on the fly when reading WAVs
	return 1;
}

sub info {
	my $this = shift;

	croak("decoder not properly initialized") if (!$this->{decoder});
	my %g = %{$this->{decoder}->details()};
	$g{rate} = $g{sample_rate};
	$g{seconds} = $g{length};
	return \%g;
}

sub tell_percentage {
	my $this = shift;
	return ($this->{decoder}->position() / $this->{decoder}->length());
}

sub tell_time {
	my $this = shift;
	return ($this->{decoder}->position() / $this->{decoder}->details()->{bytes_sec});
}

sub read {
	my $this = shift;
	my $bufref = shift;

	croak("decoder not properly initialized") if (!$this->{decoder});
	croak("not a reference to a scalar") if (ref($bufref) ne 'SCALAR');
	${$bufref} = $this->{decoder}->read_raw($this->{bufsize});
	#my $len = $this->{decoder}->read($$bufref, $this->{bufsize}, $this->{samplesize}, $this->{samplesigned});
	return -1 if (!defined(${$bufref}));
	return length(${$bufref});
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

