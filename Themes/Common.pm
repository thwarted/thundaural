#!/usr/bin/perl

package Themes::Common;

use strict;
use warnings;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(sectotime english_rank);

sub sectotime {
    my $sec = shift || 0;
    my $short = shift || 0;

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
        push(@ret, "$hrs hours") if ($hrs);
        push(@ret, "$min minutes") if ($min);
        push(@ret, "$sec seconds") if ($sec);
        return join(' and ', @ret);
    }
}

sub english_rank {
    my $rank = shift;

    # note that "never played" is the longest string
    return 'never played' if (!$rank);

    return 'first' if ($rank == 1);
    return 'second' if ($rank == 2);
    return 'third' if ($rank == 3);
    return 'fourth' if ($rank == 4);
    return 'fifth' if ($rank == 5);
    return 'sixth' if ($rank == 6);
    return 'seventh' if ($rank == 7);
    return 'eighth' if ($rank == 8);
    return 'ninth' if ($rank == 9);
    return 'tenth' if ($rank == 10);
    return 'eleventh' if ($rank == 11);
    return 'twelveth' if ($rank == 12);
    return 'thirteenth' if ($rank == 13);
    return 'fourteenth' if ($rank == 14);
    return $rank.'st' if ($rank =~ m/1$/);
    return $rank.'nd' if ($rank =~ m/2$/);
    return $rank.'rd' if ($rank =~ m/3$/);
    return $rank.'th';
}

1;
