#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/TARipUtil.pm,v 1.1 2004/03/16 08:32:03 jukebox Exp $

package TARipUtil;

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

