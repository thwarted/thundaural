#!/usr/bin/perl

package Thundaural::Util;

# just some common routines

use strict;
use warnings;

sub tmpnameprefix {
    my $storagedir = shift;
    my $device = shift;

    my $cddx = $device;
    $cddx =~ s/\W/_/g;
    return sprintf('%s/newrip.device%s.', $storagedir, $cddx);
}

sub mymktempname {
    my $storagedir = shift;
    my $device = shift;
    my $purpose = shift;

    $purpose = "rand".int(rand(99999)) unless $purpose;

    return sprintf('%spid%d.%s', &tmpnameprefix($storagedir, $device), $$, $purpose);
}

sub strcleanup {
    my $str = shift;

    $str =~ s/^\s+//g;
    $str =~ s/\s+$//g;
    $str =~ s/\s+/ /g;
    return $str;
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
