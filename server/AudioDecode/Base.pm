#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/AudioDecode/Base.pm,v 1.2 2004/06/10 06:01:40 jukebox Exp $

package AudioDecode::Base;

# base class for the audio decoder abstraction objects

use strict;
use warnings;

use Carp;

sub match_ext {
	confess("derived class didn't override match_ext");
}

sub _setup {
	my $this = shift;
	my %o = @_;

	$this->{file} = $o{file};
	croak("missing file argument") if (!$this->{file});
	$this->{bufsize} = $o{bufsize} || 8192;

	$this->{samplerate} = $o{rate} || 44100;
	$this->{samplesize} = $o{size} || 2; # 16 bit by default
	$this->{samplesigned} = $o{signed} || 1; # signed by default
	if ($o{endian} ne 'BE' && $o{endian} ne 'LE') {
		croak("endian must be 'BE' or 'LE'");
	}
	$this->{sampleendian} = $o{endian} || 'LE';

	$this->_setup_format();
}

sub file {
	my $this = shift;
	return $this->{file};
}

sub bufsize {
	my $this = shift;
	my $newbuf = shift;

	my $oldbuf = $this->{bufsize};
	$this->{bufsize} = $newbuf;
	return $oldbuf;
}

sub samplesize {
	my $this = shift;
	my $newsamp = shift;

	my $old = $this->{samplesize};
	if (defined($newsamp) && $newsamp != $old) {
		$this->{samplesize} = $newsamp;
		$this->_setup_format();
	}
	return $old;
}

sub samplesigned {
	my $this = shift;
	my $newsign = shift;

	my $old = $this->{samplesigned};
	if (defined($newsign) && $newsign != $old) {
		$this->{samplesigned} = $newsign;
		$this->_setup_format();
	}
	return $old;
}

sub sampleendian {
	my $this = shift;
	my $newendian = shift;

	my $old = $this->{sampleendian};
	if (defined($newendian) && $newendian != $old) {
		$this->{sampleendian} = $newendian;
		$this->_setup_format();
	}
	return $old;
}

sub samplerate {
	my $this = shift;
	my $newrate = shift;

	my $old = $this->{samplerate};
	if (defined($newrate) && $newrate != $old) {
		$this->{samplerate} = $newrate;
		$this->_setup_rate();
	}
	return $old;
}

sub read {
	my $this = shift;
	my $bufref = shift;

	confess("derived class didn't override read");
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

