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

sub sectotime {
    my $sec = shift || 0;
    my %o = @_;
    my $short = $o{short};
    my $round = $o{round};

    my $min = int($sec / 60);
    $sec = $sec % 60;
    my $hrs = int($min / 60);
    $min = $min % 60;

    if ($short) {
        my @ret = ();
        push(@ret, $hrs) if ($hrs);
        push(@ret, sprintf("%02d", $min));
        push(@ret, sprintf("%02d", $sec));
        return join(":", @ret);
    } else {
        my @ret = ();
        push(@ret, sprintf('%d hour%s', $hrs, $hrs == 1 ? '':'s')) if ($hrs);
        push(@ret, sprintf('%d minute%s', $min, $min == 1 ? '':'s')) if ($min);
        push(@ret, sprintf('%d second%s', $sec, $sec == 1 ? '':'s')) if ($sec);
        if ((scalar @ret) > 1) {
            my $xl = pop @ret;
            my $xs = pop @ret;
            push(@ret, "$xs and $xl");
        }
        return join(', ', @ret);
    }
}

1;

#    Thundaural Jukebox
#    Copyright (C) 2003-2005  Andrew A. Bakun
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
