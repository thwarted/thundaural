#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/AudioDecode/Open.pm,v 1.3 2004/06/10 06:01:40 jukebox Exp $

package AudioDecode::Open;

# this is a wrapper package that will create a decoder that will
# decode the passed file based on its filename extension

use strict;
use warnings;

my @modules = qw( AudioDecode::OggVorbis AudioDecode::MP3 AudioDecode::Wav );

my %exts = ();
my @foundmods = ();

foreach my $mod (@modules) {
	eval "use $mod;";
	if (!$@) {
		my $code = 'return '.$mod.'::match_ext();';
		my $re = eval($code);
		if (!$@ && $re) {
			push(@foundmods, $mod);
			$exts{$mod} = $re;
			next;
		}
	}
	warn("unable to setup $mod\n$@");
}

sub open {
	my %o = @_;
	my $file = $o{file};

	foreach my $mod (@foundmods) {
		my $re = $exts{$mod};
		if ($file =~ m/$re/) {
			return new $mod(%o);
		}
	}
	return undef;
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
